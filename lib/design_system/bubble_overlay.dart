/// 长按气泡：展示描述文案，松手不消失，轻触屏幕任意处消失。
library;

import 'package:flutter/material.dart';
import 'package:plain/app/theme/app_colors.dart';

/// 显示一个持久气泡，返回 dismiss 回调。
///
/// 气泡挂在 Overlay 上、不属于任何路由：页面被系统返回键 pop 时 OverlayEntry
/// 不会自动移除，气泡会飘到上一页。因此这里监听宿主路由的状态——路由开始
/// 退场（reverse）就一并撤掉气泡；手动 dismiss 时也把监听摘掉，避免泄漏。
VoidCallback showPersistentBubble(
  BuildContext context,
  String text, {
  required Offset targetPosition,
}) {
  final overlay = Overlay.of(context);
  final hostRoute = ModalRoute.of(context);
  late OverlayEntry entry;
  AnimationStatusListener? routeListener;

  void dismiss() {
    if (routeListener != null) {
      hostRoute?.animation?.removeStatusListener(routeListener!);
      routeListener = null;
    }
    if (entry.mounted) entry.remove();
  }

  entry = OverlayEntry(
    builder: (_) => _BubbleOverlay(
      text: text,
      targetPosition: targetPosition,
      onDismiss: dismiss,
    ),
  );
  final routeAnim = hostRoute?.animation;
  if (routeAnim != null) {
    routeListener = (AnimationStatus status) {
      // forward / completed 是正常浏览；reverse / dismissed 说明宿主页在退场。
      if (status != AnimationStatus.forward &&
          status != AnimationStatus.completed) {
        dismiss();
      }
    };
    routeAnim.addStatusListener(routeListener!);
  }
  overlay.insert(entry);
  return dismiss;
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
    final screen = MediaQuery.sizeOf(context);
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
            child: Container(color: const Color(0x00000000)),
          ),
          // 气泡
          Positioned(
            left: left,
            top: top < 60 ? targetPosition.dy + 24 : top,
            width: bubbleWidth,
            child: Material(
              type: MaterialType.transparency,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: context.colors.ink.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 14,
                    color: context.colors.surface,
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
