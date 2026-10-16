/// Shared empty-state block: icon + title + optional subtitle/action.
library;

import 'package:plain/app/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:plain/app/theme/design_tokens.dart';
import 'package:plain/design_system/plain_icons_v3.dart';

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  final PlainIconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          PlainIcon(icon, size: 80, color: context.colors.inkTertiary),
          const SizedBox(height: Spacing.lg),
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: context.colors.inkSecondary),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: Spacing.sm),
            Text(
              subtitle!,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: context.colors.inkTertiary),
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: Spacing.xl),
            action!,
          ],
        ],
      ),
    );
  }
}
