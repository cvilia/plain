/// Shared confirm dialog. Replaces the copy-pasted AlertDialog + 取消/确认 template.
library;

import 'package:plain/app/l10n/app_strings.dart';
import 'package:plain/app/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Shows a yes/no confirm dialog.
///
/// Returns `true` when the user confirms, `false` when cancelled or dismissed.
/// Set [destructive] for irreversible actions (delete/overwrite) — the confirm
/// button is tinted with the expense color.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String? confirmLabel,
  String? cancelLabel,
  bool destructive = false,
}) async {
  final s = AppStrings.of(context);
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(cancelLabel ?? s.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: context.colors.expense)
              : null,
          child: Text(confirmLabel ?? s.ok),
        ),
      ],
    ),
  );
  return result ?? false;
}
