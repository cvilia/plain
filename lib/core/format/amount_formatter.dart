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

/// Format an amount in yuan, respecting hide mode.
///
/// Integer arithmetic only (int64 cents → yuan string); never uses double.
/// Returns '****' when hidden, otherwise formatted string like `-12.50`.
String formatAmount(int cents, {bool hide = false}) {
  if (hide) return '****';
  final neg = cents < 0;
  final abs = cents.abs();
  final s = '${abs ~/ 100}.${(abs % 100).toString().padLeft(2, '0')}';
  return neg ? '-$s' : s;
}

/// Format amount with currency symbol.
String formatAmountYuan(int cents, {bool hide = false}) {
  if (hide) return '¥****';
  final sign = cents < 0 ? '-' : '';
  return '$sign¥${formatAmount(cents)}';
}
