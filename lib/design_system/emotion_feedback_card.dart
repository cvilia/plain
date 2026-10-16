/// STORY-5.4 情绪反馈卡片：toast 之后显示，可滑动关闭。
library;

import 'package:flutter/material.dart';
import 'package:plain/app/theme/app_colors.dart';
import 'package:plain/app/theme/design_tokens.dart';
import 'package:plain/app/theme/typography.dart';
import 'package:plain/design_system/plain_icons_v3.dart';
import 'package:plain/domain/services/emotion_feedback_service.dart';
import 'package:plain/core/constants/app_constants.dart';

class EmotionFeedbackCard extends StatelessWidget {
  const EmotionFeedbackCard({super.key, required this.feedback, required this.onDismiss});
  final EmotionFeedback feedback;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (bg, icon, iconColor) = switch (feedback.kind) {
      EmotionKind.positive => (colors.surface, PlainIconData.mood, colors.income),
      EmotionKind.large => (colors.surface, PlainIconData.trendUp, colors.accent),
      EmotionKind.monthFirst => (colors.surface, PlainIconData.sun, colors.accent),
      EmotionKind.goalAchieved => (colors.surface, PlainIconData.celebration, colors.income),
    };

    return Dismissible(
      key: ValueKey('emotion-${feedback.kind}-${feedback.message}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: Spacing.lg),
        color: colors.surfaceMuted,
        child: PlainIcon(PlainIconData.close, color: colors.inkTertiary),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.xs),
        child: Material(
          type: MaterialType.transparency,
          child: Container(
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.md),
              child: Row(
                children: [
                  PlainIcon(icon, size: 22, color: iconColor),
                  const SizedBox(width: Spacing.md),
                  Expanded(
                    child: Text(
                      feedback.message,
                      // 原值 `1.4`（= 19.6px）不在设计稿任何档位上。
                      // 设计稿 14px 的行盒只有 19（`normal`）/ 21 / 23.1 / 23.8 —— 取 19。
                      style: TextStyle(
                        fontSize: 14,
                        color: colors.inkSecondary,
                        height: designLineHeight(14),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: onDismiss,
                    child: Text('关闭', style: TextStyle(fontSize: 12, color: colors.inkTertiary)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 显示反馈卡片（叠加在页面底部）。
void showEmotionFeedback(BuildContext context, EmotionFeedback feedback, VoidCallback onDismiss) {
  final overlay = Overlay.of(context);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => Positioned(
      left: 0,
      right: 0,
      bottom: 100,
      child: EmotionFeedbackCard(
        feedback: feedback,
        onDismiss: () {
          entry.remove();
          onDismiss();
        },
      ),
    ),
  );
  overlay.insert(entry);
  // 自动消失
  Future.delayed(EmotionFeedbackRules.cardDuration, () {
    if (entry.mounted) entry.remove();
  });
}
