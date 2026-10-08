/// Section header label used across settings/import/sync pages.
library;

import 'package:plain/app/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:plain/app/theme/design_tokens.dart';

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: color ?? context.colors.inkSecondary,
      ),
    );
  }
}

/// Section title with the standard outer padding used in settings lists.
class PaddedSectionTitle extends StatelessWidget {
  const PaddedSectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.lg, Spacing.lg, Spacing.sm),
      child: SectionTitle(text),
    );
  }
}
