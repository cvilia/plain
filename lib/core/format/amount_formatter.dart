/// Hide amounts mode. See PRD STORY-2.1 AC4.
/// When enabled, all amounts display as **** instead of values.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Global hide-amounts toggle.
class HideAmountsNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle(bool value) => state = value;
}

final hideAmountsProvider = NotifierProvider<HideAmountsNotifier, bool>(HideAmountsNotifier.new);

/// Format an amount, respecting hide mode.
/// Returns '****' when hidden, otherwise formatted string.
String formatAmount(int cents, {bool hide = false}) {
  if (hide) return '****';
  final sign = cents < 0 ? '-' : '';
  final abs = cents.abs();
  return '$sign${(abs / 100).toStringAsFixed(2)}';
}

/// Format amount with currency symbol.
String formatAmountYuan(int cents, {bool hide = false}) {
  if (hide) return '\u00a5****';
  final sign = cents < 0 ? '-' : '';
  final abs = cents.abs();
  return '$sign\u00a5${(abs / 100).toStringAsFixed(2)}';
}
