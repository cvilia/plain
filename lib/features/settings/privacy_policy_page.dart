/// 隐私政策（STORY-4.3 / F8.3 产品宪法）。
library;

import 'package:flutter/material.dart';
import 'package:plain/app/l10n/app_strings.dart';
import 'package:plain/app/l10n/strings_settings_a.dart';
import 'package:plain/app/theme/app_colors.dart';
import 'package:plain/app/theme/design_tokens.dart';
import 'package:plain/design_system/plain_ui.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final sections = s.privacySections;
    return Scaffold(
      appBar: PlainTopBar(title: s.privacyPolicy, showBack: true),
      body: ListView(
        padding: const EdgeInsets.all(Spacing.lg),
        children: [
          Text(
            s.privacyTitle,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            s.privacyUpdatedAt,
            style: TextStyle(fontSize: 12, color: context.colors.inkTertiary),
          ),
          const SizedBox(height: Spacing.lg),
          for (final (title, body) in sections) ...[
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: Spacing.xs),
            Text(
              body,
              style: TextStyle(fontSize: 14, height: 1.6, color: context.colors.inkSecondary),
            ),
            const SizedBox(height: Spacing.lg),
          ],
        ],
      ),
    );
  }
}
