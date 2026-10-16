/// STORY-1.5 附件元数据仓储。
///
/// 文件本体由 `AttachmentStore` 负责，这里只管表。
///
/// **同步口径（STORY-8.1 AC6）**：只同步**元数据**——另一端要知道「这笔账单
/// 挂了什么附件」才能把它标成「未同步（仅在原设备）」；**字节永远不出设备**
/// （PRD 8.1 表：账单附件不同步）。因此这里写 change_log，
/// 而文件上传/下载路径完全不存在。
library;

import 'package:plain/core/result/result.dart';
import 'package:plain/core/time/clock.dart';
import 'package:plain/data/db/database.dart';
import 'package:plain/data/db/row_x.dart';
import 'package:plain/data/sync/change_log_writer.dart';
import 'package:plain/domain/entities/attachment.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/repositories/repositories.dart';

class AttachmentRepositoryImpl implements AttachmentRepository {
  AttachmentRepositoryImpl({
    required AppDatabase db,
    Clock? clock,
    ChangeLogWriter? changeLogWriter,
    String deviceId = '',
  })  : _db = db,
        _clock = clock ?? SystemClock(),
        _changeLog = changeLogWriter,
        _deviceId = deviceId;

  final AppDatabase _db;
  final Clock _clock;
  final ChangeLogWriter? _changeLog;
  final String _deviceId;

  @override
  Future<Result<List<Attachment>>> listByEntry(String entryId,
      {bool includeDeleted = false}) async {
    try {
      final rows = _db.raw.select(
        'SELECT * FROM attachments WHERE entry_id = ? '
        '${includeDeleted ? '' : 'AND deleted_at IS NULL '}'
        'ORDER BY sort_order, created_at',
        [entryId],
      );
      return ok([for (final r in rows) _fromRow(r)]);
    } on Exception catch (e) {
      return err(StorageFailure('db.query_failed', e.toString(), isRetryable: true));
    }
  }

  @override
  Future<Result<int>> countByEntry(String entryId) async {
    try {
      final rows = _db.raw.select(
        'SELECT COUNT(*) AS c FROM attachments WHERE entry_id = ? AND deleted_at IS NULL',
        [entryId],
      );
      return ok((rows.first['c'] as int?) ?? 0);
    } on Exception catch (e) {
      return err(StorageFailure('db.query_failed', e.toString(), isRetryable: true));
    }
  }

  @override
  Future<Result<Attachment>> getById(String id) async {
    try {
      final rows = _db.raw.select('SELECT * FROM attachments WHERE id = ?', [id]);
      if (rows.isEmpty) {
        return err<Attachment>(const NotFoundFailure('attachment.not_found', 'nf'));
      }
      return ok(_fromRow(rows.first));
    } on Exception catch (e) {
      return err(StorageFailure('db.query_failed', e.toString(), isRetryable: true));
    }
  }

  @override
  Future<Result<Attachment>> create(Attachment attachment) async {
    try {
      _db.raw.execute(
        'INSERT INTO attachments (id,entry_id,book_id,stored_name,thumbnail_name,mime,'
        'size_bytes,width,height,is_orphan,orphaned_at,sort_order,created_at,updated_at,'
        'deleted_at,revision,device_id,base_revision) '
        'VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
        [
          attachment.id, attachment.entryId, attachment.bookId,
          attachment.storedName, attachment.thumbnailName, attachment.mime,
          attachment.sizeBytes, attachment.width, attachment.height,
          attachment.isOrphan ? 1 : 0,
          attachment.orphanedAt?.millisecondsSinceEpoch,
          attachment.sortOrder,
          attachment.createdAt.millisecondsSinceEpoch,
          attachment.updatedAt.millisecondsSinceEpoch,
          attachment.deletedAt?.millisecondsSinceEpoch,
          attachment.revision, attachment.deviceId, attachment.baseRevision,
        ],
      );
      _changeLog?.write(
        entityType: EntityType.attachment,
        entityId: attachment.id,
        op: ChangeOp.insert,
        deviceId: _deviceId.isEmpty ? attachment.deviceId : _deviceId,
        baseRevision: 0,
        before: const {},
        after: _payload(attachment),
      );
      return ok(attachment);
    } on Exception catch (e) {
      return err(StorageFailure('db.insert_failed', e.toString(), isRetryable: true));
    }
  }

  @override
  Future<Result<void>> softDelete(String id) async {
    try {
      final rows = _db.raw.select('SELECT * FROM attachments WHERE id = ?', [id]);
      if (rows.isEmpty) {
        return err<void>(const NotFoundFailure('attachment.not_found', 'nf'));
      }
      final now = _clock.now();
      _db.raw.execute(
        'UPDATE attachments SET deleted_at = ?, updated_at = ? WHERE id = ?',
        [now.millisecondsSinceEpoch, now.millisecondsSinceEpoch, id],
      );
      final row = _db.raw.select('SELECT * FROM attachments WHERE id = ?', [id]);
      if (row.isNotEmpty) {
        _changeLog?.write(
          entityType: EntityType.attachment,
          entityId: id,
          op: ChangeOp.delete,
          deviceId: _deviceId.isEmpty ? (_fromRow(row.first).deviceId) : _deviceId,
          baseRevision: _fromRow(row.first).revision,
          before: _payload(_fromRow(row.first)),
          after: const {},
          changedAt: now,
        );
      }
      return ok(null);
    } on Exception catch (e) {
      return err(StorageFailure('db.delete_failed', e.toString(), isRetryable: true));
    }
  }

  @override
  Future<Result<int>> markOrphanedByEntry(String entryId, DateTime at) async {
    try {
      final count = (await countByEntry(entryId)).successOrNull ?? 0;
      // 先取「改动前」的行，日志才能给出三方合并用的祖先值
      final before = _rowsByEntry(entryId, orphanValue: 0);
      _db.raw.execute(
        'UPDATE attachments SET is_orphan = 1, orphaned_at = ?, updated_at = ? '
        'WHERE entry_id = ? AND deleted_at IS NULL',
        [at.millisecondsSinceEpoch, at.millisecondsSinceEpoch, entryId],
      );
      // 账单删除 → 附件标孤儿：这条要跨端，否则对端永远显示「已同步的附件」
      for (final row in before) {
        _logUpdate(row, at);
      }
      return ok(count);
    } on Exception catch (e) {
      return err(StorageFailure('db.update_failed', e.toString(), isRetryable: true));
    }
  }

  @override
  Future<Result<int>> restoreByEntry(String entryId) async {
    try {
      final rows = _db.raw.select(
        'SELECT COUNT(*) AS c FROM attachments '
        'WHERE entry_id = ? AND deleted_at IS NULL AND is_orphan = 1',
        [entryId],
      );
      final count = (rows.first['c'] as int?) ?? 0;
      final now = _clock.now();
      final before = _rowsByEntry(entryId, orphanValue: 1);
      _db.raw.execute(
        'UPDATE attachments SET is_orphan = 0, orphaned_at = NULL, updated_at = ? '
        'WHERE entry_id = ? AND deleted_at IS NULL',
        [now.millisecondsSinceEpoch, entryId],
      );
      // 回收站恢复账单 → 孤儿标记清除：同样要跨端（AC2）
      for (final row in before) {
        _logUpdate(row, now);
      }
      return ok(count);
    } on Exception catch (e) {
      return err(StorageFailure('db.update_failed', e.toString(), isRetryable: true));
    }
  }

  @override
  Future<Result<List<Attachment>>> listExpiredOrphans(DateTime cutoff) async {
    try {
      final rows = _db.raw.select(
        'SELECT * FROM attachments WHERE is_orphan = 1 AND deleted_at IS NULL '
        'AND orphaned_at IS NOT NULL AND orphaned_at < ?',
        [cutoff.millisecondsSinceEpoch],
      );
      return ok([for (final r in rows) _fromRow(r)]);
    } on Exception catch (e) {
      return err(StorageFailure('db.query_failed', e.toString(), isRetryable: true));
    }
  }

  @override
  Future<Result<void>> hardDelete(String id) async {
    try {
      final rows = _db.raw.select('SELECT * FROM attachments WHERE id = ?', [id]);
      if (rows.isEmpty) return ok(null);
      final old = _fromRow(rows.first);
      _db.raw.execute('DELETE FROM attachments WHERE id = ?', [id]);
      // 巡检清掉超期孤儿后，对端不能永远留一条「幽灵附件」——
      // attachments 有 deleted_at，因此这里是软删语义的 delete 变更。
      _changeLog?.write(
        entityType: EntityType.attachment,
        entityId: id,
        op: ChangeOp.delete,
        deviceId: _deviceId.isEmpty ? old.deviceId : _deviceId,
        baseRevision: old.revision,
        before: _payload(old),
        after: const {},
        changedAt: _clock.now(),
      );
      return ok(null);
    } on Exception catch (e) {
      return err(StorageFailure('db.delete_failed', e.toString(), isRetryable: true));
    }
  }

  /// 某笔账单当前**未删**、且 `is_orphan = [orphanValue]` 的附件行。
  ///
  /// 只取真正会被这次改动碰到的行——日志不写「改了等于没改」的变更。
  List<Map<String, Object?>> _rowsByEntry(String entryId, {required int orphanValue}) =>
      _db.raw
          .select(
            'SELECT * FROM attachments WHERE entry_id = ? AND deleted_at IS NULL '
            'AND is_orphan = ?',
            [entryId, orphanValue],
          )
          .toList();

  /// 孤儿标记变更的 `update` 日志（after 取改完后的那一行）。
  void _logUpdate(Map<String, Object?> beforeRow, DateTime at) {
    final afterRows =
        _db.raw.select('SELECT * FROM attachments WHERE id = ?', [beforeRow['id']]);
    if (afterRows.isEmpty) return;
    final before = _fromRow(beforeRow);
    final after = _fromRow(afterRows.first);
    _changeLog?.write(
      entityType: EntityType.attachment,
      entityId: after.id,
      op: ChangeOp.update,
      deviceId: _deviceId.isEmpty ? after.deviceId : _deviceId,
      baseRevision: before.revision,
      before: _payload(before),
      after: _payload(after),
      changedAt: at,
    );
  }

  Attachment _fromRow(Map<String, Object?> row) => Attachment(
        id: row['id']! as String,
        entryId: row['entry_id']! as String,
        bookId: row['book_id']! as String,
        storedName: row['stored_name']! as String,
        thumbnailName: row['thumbnail_name'] as String?,
        mime: row['mime']! as String,
        sizeBytes: row.intOr('size_bytes', 0),
        width: row['width'] as int?,
        height: row['height'] as int?,
        isOrphan: row.intOr('is_orphan', 0) == 1,
        orphanedAt: row.nullableDateTime('orphaned_at'),
        sortOrder: row.intOr('sort_order', 0),
        createdAt: row.dateTime('created_at'),
        updatedAt: row.dateTime('updated_at'),
        deletedAt: row.nullableDateTime('deleted_at'),
        revision: row.intOr('revision', 1),
        deviceId: row['device_id']! as String,
        baseRevision: row.intOr('base_revision', 0),
      );

  /// 同步 payload（列形态）。⚠️ 只含元数据：`stored_name` / `thumbnail_name`
  /// 是**文件名**，对端拿到会指向一个不存在的文件 → 界面据此标「未同步」。
  Map<String, Object?> _payload(Attachment a) => {
        'id': a.id,
        'entry_id': a.entryId,
        'book_id': a.bookId,
        'stored_name': a.storedName,
        'thumbnail_name': a.thumbnailName,
        'mime': a.mime,
        'size_bytes': a.sizeBytes,
        'width': a.width,
        'height': a.height,
        'is_orphan': a.isOrphan ? 1 : 0,
        'orphaned_at': a.orphanedAt?.millisecondsSinceEpoch,
        'sort_order': a.sortOrder,
        'created_at': a.createdAt.millisecondsSinceEpoch,
        'updated_at': a.updatedAt.millisecondsSinceEpoch,
        'deleted_at': a.deletedAt?.millisecondsSinceEpoch,
        'revision': a.revision,
        'device_id': a.deviceId,
        'base_revision': a.baseRevision,
      };
}
