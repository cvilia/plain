/// STORY-1.5 账单附件区（详情页与编辑态共用）。
///
/// 五张上限、单张 10MB、jpg/png/heic/pdf；超限时提示，空间不足时可仅存缩略图。
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plain/app/bootstrap.dart';
import 'package:plain/app/theme/app_colors.dart';
import 'package:plain/app/theme/design_tokens.dart';
import 'package:plain/app/theme/typography.dart';
import 'package:plain/core/constants/app_constants.dart';
import 'package:plain/data/platform/file_picker_bridge.dart';
import 'package:plain/design_system/app_toast.dart';
import 'package:plain/design_system/plain_icons_v3.dart';
import 'package:plain/domain/entities/attachment.dart';
import 'package:plain/domain/services/attachment_service.dart';
import 'package:plain/features/ledger/presentation/attachment_viewer_page.dart';

class EntryAttachmentsSection extends ConsumerStatefulWidget {
  const EntryAttachmentsSection({super.key, required this.entryId});

  final String entryId;

  @override
  ConsumerState<EntryAttachmentsSection> createState() => _EntryAttachmentsSectionState();
}

class _EntryAttachmentsSectionState extends ConsumerState<EntryAttachmentsSection> {
  List<Attachment> _items = const [];
  bool _loading = true;
  bool _busy = false;

  /// STORY-8.1 AC6：附件**元数据**会同步，文件不会。对端拿到的行指向一个
  /// 本地不存在的文件 → 标记为「未同步（仅在原设备）」而不是报「无法预览」。
  final Map<String, bool> _presentLocal = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final deps = ref.read(appDependenciesProvider);
    final res = await deps.attachmentService.list(widget.entryId);
    final items = res.successOrNull ?? const <Attachment>[];
    final present = <String, bool>{};
    for (final a in items) {
      final f = await deps.attachmentStore.fileOf(a.storedName);
      present[a.id] = f.existsSync();
    }
    if (!mounted) return;
    setState(() {
      _items = items;
      _presentLocal
        ..clear()
        ..addAll(present);
      _loading = false;
    });
  }

  int get _missingCount => _items.where((a) => _presentLocal[a.id] == false).length;

  bool _isPresent(Attachment a) => _presentLocal[a.id] ?? true;

  Future<File> _fileOf(Attachment a) => ref.read(appDependenciesProvider).attachmentStore.fileOf(a.thumbnailName ?? a.storedName);

  Future<void> _add() async {
    final deps = ref.read(appDependenciesProvider);
    if (_items.length >= AttachmentRules.maxPerEntry) {
      showAppToast(context, AttachmentService.messageFor(AttachmentRejection.tooMany));
      return;
    }
    final path = await FilePickerBridge.pickFile(
      mime: '*/*',
      mimeTypes: AttachmentRules.allowedTypes.values.toSet().toList(),
    );
    if (path == null || !mounted) return;

    // 前置校验：非图片超 10MB 直接拦；图片交给导入时压缩后再复检
    final length = await File(path).length();
    final rejection = AttachmentService.validate(
      existingCount: _items.length,
      sizeBytes: length,
      fileName: path,
    );
    if (rejection != null) {
      if (mounted) showAppToast(context, AttachmentService.messageFor(rejection));
      return;
    }

    setState(() => _busy = true);
    final res = await deps.attachmentService.add(
      entryId: widget.entryId,
      bookId: deps.bookId,
      deviceId: deps.deviceId,
      sourcePath: path,
    );
    if (!mounted) return;
    setState(() => _busy = false);

    final failure = res.failureOrNull;
    if (failure != null) {
      final code = failure.code;
      if (code.startsWith('attachment.storage_full')) {
        await _offerThumbnailOnly(path);
      } else if (code == 'attachment.too_large') {
        showAppToast(context, AttachmentService.messageFor(AttachmentRejection.tooLarge));
      } else if (code == 'attachment.unsupported_type') {
        showAppToast(context, AttachmentService.messageFor(AttachmentRejection.unsupportedType));
      } else {
        showAppToast(context, '附件保存失败，请重试');
      }
      return;
    }
    await _load();
    if (mounted) showAppToast(context, '已添加附件');
  }

  /// 空间不足 → PRD 给的退路：只存缩略图。
  Future<void> _offerThumbnailOnly(String path) async {
    final deps = ref.read(appDependenciesProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('剩余空间不足'),
        content: const Text('可以只保存缩略图，原图不落盘。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('仅保存缩略图')),
        ],
      ),
    );
    if (ok != true) return;
    final res = await deps.attachmentService.add(
      entryId: widget.entryId,
      bookId: deps.bookId,
      deviceId: deps.deviceId,
      sourcePath: path,
      thumbnailOnly: true,
    );
    if (!mounted) return;
    if (res.isFailure) {
      showAppToast(context, '缩略图也没存下，换个文件试试');
      return;
    }
    await _load();
    if (mounted) showAppToast(context, '已保存缩略图');
  }

  Future<void> _remove(Attachment a) async {
    final deps = ref.read(appDependenciesProvider);
    final res = await deps.attachmentService.remove(a.id);
    if (!mounted) return;
    if (res.isFailure) {
      showAppToast(context, '移除失败，请重试');
      return;
    }
    await _load();
    if (mounted) showAppToast(context, '已移除附件');
  }

  Future<void> _open(int index) async {
    final deps = ref.read(appDependenciesProvider);
    final views = <AttachmentView>[];
    for (final a in _items) {
      final file = await deps.attachmentStore.fileOf(a.storedName);
      views.add(AttachmentView(
        path: file.path,
        isImage: a.isImage,
        label: a.storedName,
        sizeLabel: a.sizeLabel,
      ));
    }
    if (!mounted) return;
    Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => AttachmentViewerPage(views: views, initialIndex: index)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (_loading) {
      return const SizedBox(
        height: 68,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            PlainIcon(PlainIconData.attachment, size: 16, color: colors.inkFaint),
            const SizedBox(width: 6),
            Text(
              '附件 ${_items.length}/${AttachmentRules.maxPerEntry}',
              style: TextStyle(
                fontSize: 14,
                height: designLineHeight(14),
                fontWeight: FontWeight.w500,
                color: colors.inkSecondary,
              ),
            ),
            const Spacer(),
            if (_busy)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              TextButton.icon(
                onPressed: _add,
                icon: const PlainIcon(PlainIconData.plus, size: 16),
                label: const Text('添加'),
              ),
          ],
        ),
        const SizedBox(height: Spacing.sm),
        if (_items.isEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: Spacing.md),
            child: Text(
              '拍张小票存着，报销和回忆都有凭证',
              style: TextStyle(fontSize: 12, height: designLineHeight(12), color: colors.inkFaint),
            ),
          )
        else ...[
          Wrap(
            spacing: Spacing.sm,
            runSpacing: Spacing.sm,
            children: [
              for (var i = 0; i < _items.length; i++) _tile(_items[i], i),
            ],
          ),
          if (_missingCount > 0)
            Padding(
              padding: const EdgeInsets.only(left: 2, top: Spacing.sm),
              child: Text(
                // AC6：元数据同步、图片不同步，说明清楚而不是让人以为文件丢了
                '$_missingCount 张未同步（仅在原设备）',
                style: TextStyle(fontSize: 12, height: designLineHeight(12), color: colors.inkTertiary),
              ),
            ),
        ],
        const SizedBox(height: Spacing.md),
      ],
    );
  }

  Widget _tile(Attachment a, int index) {
    final colors = context.colors;
    return SizedBox(
      width: 76,
      height: 76,
      child: Stack(
        children: [
          Positioned.fill(
            child: InkWell(
              onTap: () => _open(index),
              borderRadius: BorderRadius.circular(Radii.md),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(Radii.md),
                  border: Border.all(color: colors.border),
                  color: colors.surface,
                ),
                clipBehavior: Clip.antiAlias,
                child: !_isPresent(a)
                    ? _notSynced()
                    : a.isImage
                        ? FutureBuilder<File>(
                            future: _fileOf(a),
                            builder: (ctx, snap) {
                              final f = snap.data;
                              if (f == null) return const SizedBox.shrink();
                              return Image.file(
                                f,
                                fit: BoxFit.cover,
                                // 网格只按目标尺寸解码，避免整张原图进内存
                                cacheWidth: (76 * MediaQuery.devicePixelRatioOf(ctx)).round(),
                                errorBuilder: (_, _, _) => _fallback(a),
                              );
                            },
                          )
                        : _fallback(a),
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: InkWell(
              onTap: () => _remove(a),
              customBorder: const CircleBorder(),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: colors.overlay,
                  shape: BoxShape.circle,
                ),
                child: const PlainIcon(PlainIconData.close, size: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// AC6：元数据在、文件不在 → 「未同步（仅在原设备）」。
  Widget _notSynced() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PlainIcon(PlainIconData.cloudDownload, size: 18, color: context.colors.inkFaint),
            const SizedBox(height: 2),
            Text(
              '未同步',
              style: TextStyle(fontSize: 12, height: designLineHeight(12), color: context.colors.inkTertiary),
            ),
          ],
        ),
      );

  Widget _fallback(Attachment a) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PlainIcon(
              a.mime == 'application/pdf' ? PlainIconData.receipt : PlainIconData.image,
              size: 20,
              color: context.colors.inkTertiary,
            ),
            const SizedBox(height: 2),
            Text(
              a.mime == 'application/pdf' ? 'PDF' : '无法预览',
              style: TextStyle(fontSize: 12, height: designLineHeight(12), color: context.colors.inkTertiary),
            ),
          ],
        ),
      );
}
