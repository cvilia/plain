/// 统一的「加载失败」态（审计走查 2026-10-15）。
///
/// 收口前全库有 10 处写成 `Center(child: Text('加载失败: $e'))`：把异常对象
/// 直接拼给用户看，而且**没有重试入口**——用户除了退出重进没别的办法。
/// 统一成一句话 + 可选重试，异常细节不上屏。
library;

import 'package:flutter/material.dart';
import 'package:plain/design_system/app_empty_state.dart';
import 'package:plain/design_system/plain_icons_v3.dart';

class AppErrorState extends StatelessWidget {
  const AppErrorState({
    super.key,
    required this.error,
    this.onRetry,
    this.title = '加载失败',
    this.subtitle = '数据还在本机，重试一下就好。',
  });

  /// 原始异常只用于日志排查，**不上屏**。
  final Object error;

  /// 为空则不显示重试按钮（调用方拿不到 refresh 时）。
  final VoidCallback? onRetry;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: PlainIconData.cloudDownload,
      title: title,
      subtitle: subtitle,
      action: onRetry == null
          ? null
          : FilledButton.icon(
              onPressed: onRetry,
              icon: const PlainIcon(PlainIconData.cloudDownload),
              label: const Text('重试'),
            ),
    );
  }

  /// 需要排查时用：出错时把异常打到调试日志，但界面只显示友好文案。
  static AppErrorState of(
    Object error, {
    VoidCallback? onRetry,
    String title = '加载失败',
    String subtitle = '数据还在本机，重试一下就好。',
  }) {
    assert(() {
      debugPrint('[AppErrorState] $error');
      return true;
    }());
    return AppErrorState(
      error: error,
      onRetry: onRetry,
      title: title,
      subtitle: subtitle,
    );
  }
}
