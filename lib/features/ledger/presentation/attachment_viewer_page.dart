/// STORY-1.5 附件查看页。
///
/// 图片可缩放查看；pdf / 解不开的格式给一张卡片 + 系统分享（离线，不引插件）。
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:plain/app/theme/app_colors.dart';
import 'package:plain/app/theme/design_tokens.dart';
import 'package:plain/app/theme/typography.dart';
import 'package:plain/design_system/plain_icons_v3.dart';
import 'package:plain/design_system/plain_ui.dart';
import 'package:share_plus/share_plus.dart';

/// 查看项（由调用方把附件解析成绝对路径后传入）。
class AttachmentView {
  const AttachmentView({
    required this.path,
    required this.isImage,
    required this.label,
    required this.sizeLabel,
  });

  final String path;
  final bool isImage;
  final String label;
  final String sizeLabel;
}

class AttachmentViewerPage extends StatefulWidget {
  const AttachmentViewerPage({super.key, required this.views, this.initialIndex = 0});

  final List<AttachmentView> views;
  final int initialIndex;

  @override
  State<AttachmentViewerPage> createState() => _AttachmentViewerPageState();
}

class _AttachmentViewerPageState extends State<AttachmentViewerPage> {
  late final PageController _controller = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.views.length;
    return Scaffold(
      backgroundColor: context.colors.surface,
      appBar: PlainTopBar(
        title: total <= 1 ? '附件' : '附件 ${_index + 1}/$total',
        showBack: true,
        actions: [
          PlainTopBarAction(
            icon: PlainIconData.share,
            tooltip: '分享',
            onTap: _share,
          ),
        ],
      ),
      body: total == 0
          ? const Center(child: Text('附件已不存在'))
          : PageView.builder(
              controller: _controller,
              itemCount: total,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (ctx, i) {
                final v = widget.views[i];
                if (!v.isImage) return _card(v);
                return InteractiveViewer(
                  maxScale: 5,
                  child: Center(
                    child: Image.file(
                      File(v.path),
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => _card(v),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _share() async {
    if (widget.views.isEmpty) return;
    final v = widget.views[_index.clamp(0, widget.views.length - 1)];
    final f = File(v.path);
    if (!f.existsSync()) return;
    await Share.shareXFiles([XFile(v.path)], text: '素记附件');
  }

  Widget _card(AttachmentView v) {
    final colors = context.colors;
    return Center(
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        margin: const EdgeInsets.symmetric(horizontal: 32),
        decoration: BoxDecoration(
          color: colors.surfaceCard,
          borderRadius: BorderRadius.circular(Radii.r3),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PlainIcon(PlainIconData.receipt, size: 24, color: colors.inkTertiary),
            const SizedBox(height: Spacing.sm),
            Text(
              '这个格式没法内嵌预览',
              style: TextStyle(
                fontSize: 14,
                height: designLineHeight(14),
                fontWeight: FontWeight.w500,
                color: colors.ink,
              ),
            ),
            const SizedBox(height: Spacing.xs),
            Text(
              v.sizeLabel,
              style: TextStyle(fontSize: 12, height: designLineHeight(12), color: colors.inkTertiary),
            ),
            const SizedBox(height: Spacing.md),
            FilledButton(
              onPressed: _share,
              child: const Text('用其它应用打开'),
            ),
          ],
        ),
      ),
    );
  }
}
