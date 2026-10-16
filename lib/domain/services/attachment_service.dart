/// STORY-1.5 附件服务：限额校验 + 落盘协调 + 孤儿生命周期。
///
/// 口径来自 PRD：单笔最多 5 张、单张 ≤ 10MB、仅 jpg/png/heic/pdf；
/// 删除账单后附件标记孤儿，30 天内随回收站恢复，超期由巡检物理清理。
library;

import 'package:plain/core/constants/app_constants.dart';
import 'package:plain/core/id/uuid_v7.dart';
import 'package:plain/core/result/result.dart';
import 'package:plain/core/time/clock.dart';
import 'package:plain/data/platform/attachment_store.dart';
import 'package:plain/domain/entities/attachment.dart';
import 'package:plain/domain/repositories/repositories.dart';

/// 附件被拒绝的原因（码值与界面提示一一对应）。
enum AttachmentRejection {
  /// 已达单笔上限。
  tooMany,

  /// 单张超过 10MB（且不是可压缩的图片）。
  tooLarge,

  /// 格式不在白名单。
  unsupportedType,

  /// 空文件 / 读不到。
  emptyFile,
}

class AttachmentService {
  AttachmentService({
    required AttachmentRepository repository,
    required AttachmentStore store,
    required UuidV7 idGen,
    required Clock clock,
  })  : _repository = repository,
        _store = store,
        _idGen = idGen,
        _clock = clock;

  final AttachmentRepository _repository;
  final AttachmentStore _store;
  final UuidV7 _idGen;
  final Clock _clock;

  /// 纯校验（不落盘，便于单测与前置拦截）。
  ///
  /// [fileName] 用于判格式，[sizeBytes] 是待入库的字节数。
  static AttachmentRejection? validate({
    required int existingCount,
    required int sizeBytes,
    required String fileName,
  }) {
    if (existingCount >= AttachmentRules.maxPerEntry) {
      return AttachmentRejection.tooMany;
    }
    if (sizeBytes <= 0) return AttachmentRejection.emptyFile;
    final mime = AttachmentRules.mimeOf(fileName);
    if (mime == null) return AttachmentRejection.unsupportedType;
    // 图片可以在导入时压缩，所以大小上限放在导入后复检
    if (sizeBytes > AttachmentRules.maxBytes && !AttachmentRules.isImage(mime)) {
      return AttachmentRejection.tooLarge;
    }
    return null;
  }

  static String messageFor(AttachmentRejection r) => switch (r) {
        AttachmentRejection.tooMany => '最多 ${AttachmentRules.maxPerEntry} 张',
        AttachmentRejection.tooLarge => '单张不能超过 10MB',
        AttachmentRejection.unsupportedType => '仅支持 jpg / png / heic / pdf',
        AttachmentRejection.emptyFile => '文件为空，换一张试试',
      };

  /// 读取某笔账单的附件。
  Future<Result<List<Attachment>>> list(String entryId) =>
      _repository.listByEntry(entryId);

  /// 从选择器给的临时路径新增一张附件。
  ///
  /// [thumbnailOnly] 供「存储空间不足 → 仅保存缩略图」分支使用。
  Future<Result<Attachment>> add({
    required String entryId,
    required String bookId,
    required String deviceId,
    required String sourcePath,
    bool thumbnailOnly = false,
  }) async {
    final fileName = sourcePath.split(RegExp(r'[/\\]')).last;
    final mime = AttachmentRules.mimeOf(fileName);
    if (mime == null) {
      return err(const ValidationFailure(
          'attachment.unsupported_type', 'jpg/png/heic/pdf only'));
    }
    final count = (await _repository.countByEntry(entryId)).successOrNull ?? 0;
    if (count >= AttachmentRules.maxPerEntry) {
      return err(const ValidationFailure('attachment.too_many', 'max 5'));
    }

    final id = _idGen.generate();
    final StoredAttachmentFile stored;
    try {
      stored = await _store.importFile(
        sourcePath: sourcePath,
        id: id,
        mime: mime,
        thumbnailOnly: thumbnailOnly,
      );
    } on AttachmentStorageException catch (e) {
      return err(StorageFailure(e.code, e.code, isRetryable: true));
    }
    if (stored.sizeBytes > AttachmentRules.maxBytes) {
      await _store.delete(stored.storedName);
      return err(const ValidationFailure('attachment.too_large', 'max 10MB'));
    }

    final now = _clock.now();
    final attachment = Attachment(
      id: id,
      entryId: entryId,
      bookId: bookId,
      storedName: stored.storedName,
      thumbnailName: stored.thumbnailName,
      mime: mime,
      sizeBytes: stored.sizeBytes,
      width: stored.width,
      height: stored.height,
      sortOrder: count,
      createdAt: now,
      updatedAt: now,
      deviceId: deviceId,
    );
    final res = await _repository.create(attachment);
    if (res.isFailure) {
      // 行没写成，文件不能留下
      await _store.delete(stored.storedName);
      await _store.delete(stored.thumbnailName);
      return err(res.failureOrNull!);
    }
    return ok(attachment);
  }

  /// 按 id 移除（先查元数据拿到文件名，再删文件与行）。
  Future<Result<void>> remove(String id) async {
    final loaded = await _repository.getById(id);
    if (loaded.isFailure) return err(loaded.failureOrNull!);
    final a = loaded.requireValue;
    await _store.delete(a.storedName);
    await _store.delete(a.thumbnailName);
    return _repository.softDelete(id);
  }

  /// 第 1 步：账单被删 → 标记孤儿（AC2 的 30 天窗口起点）。
  Future<Result<int>> markOrphaned(String entryId) =>
      _repository.markOrphanedByEntry(entryId, _clock.now());

  /// 第 2 步：账单从回收站恢复 → 清除孤儿标记（AC2）。
  Future<Result<int>> restoreForEntry(String entryId) =>
      _repository.restoreByEntry(entryId);

  /// 第 3 步：巡检 — 清理超期孤儿附件（AC3）。返回清理张数。
  Future<Result<int>> purgeExpiredOrphans() async {
    final cutoff = _clock.now().subtract(AttachmentRules.orphanTtl);
    final expired = await _repository.listExpiredOrphans(cutoff);
    if (expired.isFailure) return err(expired.failureOrNull!);
    var purged = 0;
    for (final a in expired.requireValue) {
      await _store.delete(a.storedName);
      await _store.delete(a.thumbnailName);
      final res = await _repository.hardDelete(a.id);
      if (res.isSuccess) purged++;
    }
    return ok(purged);
  }
}
