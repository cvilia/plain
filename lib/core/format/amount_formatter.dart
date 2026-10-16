/// Hide amounts mode. See PRD STORY-2.1 AC4.
/// When enabled, all amounts display as **** instead of values.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plain/core/constants/app_constants.dart';

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
  final s = '${_grouped(abs ~/ 100)}.${(abs % 100).toString().padLeft(2, '0')}';
  return neg ? '-$s' : s;
}

/// Integer with thousand separators: 1234567 → 1,234,567.
String _grouped(int n) {
  final s = n.toString();
  if (s.length <= 3) return s;
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

/// Split amount into integer and decimal parts for four-part typography.
/// Returns `intPart` with thousand separators (e.g. `3,420`) and `decPart`
/// (e.g. `50`). Hidden mode yields `****`.
({String intPart, String decPart}) formatAmountParts(int cents, {bool hide = false}) {
  if (hide) return (intPart: '****', decPart: '');
  final abs = cents.abs();
  return (
    intPart: _grouped(abs ~/ 100),
    decPart: (abs % 100).toString().padLeft(2, '0'),
  );
}

/// Format amount with currency symbol.
String formatAmountYuan(int cents, {bool hide = false}) {
  if (hide) return '¥****';
  final sign = cents < 0 ? '-' : '';
  return '$sign¥${formatAmount(cents)}';
}

/// 按币种代码格式化（STORY-9.3）。
String formatAmountCurrency(
  int cents, {
  String currencyCode = 'CNY',
  bool hide = false,
}) {
  final sym = CurrencyRules.symbolOf(currencyCode);
  if (hide) return '$sym****';
  final sign = cents < 0 ? '-' : '';
  return '$sign$sym${formatAmount(cents)}';
}

/// 双币显示（STORY-9.3）：原币 + 折算本位币。
/// [originalCents] 原币金额，[convertedCents] 折算后本位币金额。
/// 返回如 `$12.50 ≈ ¥89.00`，同币种时只显示一个。
String formatDualCurrency({
  required int originalCents,
  required int convertedCents,
  required String fromCurrency,
  String toCurrency = 'CNY',
  bool hide = false,
}) {
  final from = formatAmountCurrency(originalCents, currencyCode: fromCurrency, hide: hide);
  if (fromCurrency == toCurrency) return from;
  final to = formatAmountCurrency(convertedCents, currencyCode: toCurrency, hide: hide);
  return '$from ≈ $to';
}
