/// STORY-5.4 情绪反馈卡片：toast 之后显示，可滑动关闭。
library;

import 'package:flutter/material.dart';
import 'package:plain/app/theme/app_colors.dart';
import 'package:plain/app/theme/design_tokens.dart';
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
      EmotionKind.positive => (colors.surface, Icons.sentiment_satisfied_alt_outlined, colors.income),
      EmotionKind.large => (colors.surface, Icons.trending_up_outlined, colors.accent),
      EmotionKind.monthFirst => (colors.surface, Icons.wb_sunny_outlined, colors.accent),
      EmotionKind.goalAchieved => (colors.surface, Icons.celebration_outlined, colors.income),
    };

    return Dismissible(
      key: ValueKey('emotion-${feedback.kind}-${feedback.message}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: Spacing.lg),
        color: colors.surfaceMuted,
        child: Icon(Icons.close, color: colors.inkTertiary),
      ),
      child: Card(
        color: bg,
        margin: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.xs),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.md),
          child: Row(
            children: [
              Icon(icon, size: 22, color: iconColor),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: Text(
                  feedback.message,
                  style: TextStyle(fontSize: 13, color: colors.inkSecondary, height: 1.4),
                ),
              ),
              TextButton(
                onPressed: onDismiss,
                child: Text('关闭', style: TextStyle(fontSize: 11, color: colors.inkTertiary)),
              ),
            ],
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
