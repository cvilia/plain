/// 长按气泡：展示描述文案，松手不消失，轻触屏幕任意处消失。
library;

import 'package:flutter/material.dart';
import 'package:plain/app/theme/app_colors.dart';

/// 显示一个持久气泡，返回 dismiss 回调。
VoidCallback showPersistentBubble(
  BuildContext context,
  String text, {
  required Offset targetPosition,
}) {
  final overlay = Overlay.of(context);
  late OverlayEntry entry;

  entry = OverlayEntry(
    builder: (_) => _BubbleOverlay(
      text: text,
      targetPosition: targetPosition,
      onDismiss: () => entry.remove(),
    ),
  );
  overlay.insert(entry);
  return () {
    if (entry.mounted) entry.remove();
  };
}

class _BubbleOverlay extends StatelessWidget {
  const _BubbleOverlay({
    required this.text,
    required this.targetPosition,
    required this.onDismiss,
  });

  final String text;
  final Offset targetPosition;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    const bubbleMaxWidth = 260.0;

    // 气泡位置：目标点上方 12px，水平居中，限制在屏幕内
    final bubbleWidth = bubbleMaxWidth.clamp(120.0, screen.width - 32);
    double left = targetPosition.dx - bubbleWidth / 2;
    left = left.clamp(16.0, screen.width - bubbleWidth - 16);
    double top = targetPosition.dy - 12 - 60; // 估算气泡高度

    return GestureDetector(
      onTap: onDismiss,
      behavior: HitTestBehavior.translucent,
      child: Stack(
        children: [
          // 全屏透明层捕获点击
          Positioned.fill(
            child: Container(color: Colors.transparent),
          ),
          // 气泡
          Positioned(
            left: left,
            top: top < 60 ? targetPosition.dy + 24 : top,
            width: bubbleWidth,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: context.colors.ink.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 包裹可长按的条目，长按显示气泡。
class BubbleOnLongPress extends StatelessWidget {
  const BubbleOnLongPress({
    super.key,
    required this.bubbleText,
    required this.child,
    this.onLongPress,
  });

  /// 气泡内容（描述文案）。
  final String? bubbleText;
  final Widget child;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (details) {
        onLongPress?.call();
        if (bubbleText != null && bubbleText!.isNotEmpty) {
          showPersistentBubble(context, bubbleText!, targetPosition: details.globalPosition);
        }
      },
      child: child,
    );
  }
}
