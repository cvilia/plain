/// Amount display widget with hide mode + tap-to-reveal (5s).
/// See PRD STORY-2.1 AC4.
library;

import 'package:plain/app/theme/app_colors.dart';
import 'package:plain/app/theme/typography.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plain/core/constants/app_constants.dart';
import 'package:plain/core/format/amount_formatter.dart';

/// Displays an amount. When hide mode is on, shows ****.
/// Tap to temporarily reveal for 5 seconds.
class AmountText extends ConsumerStatefulWidget {
  const AmountText({
    super.key,
    required this.cents,
    this.fontSize = 15,
    this.fontWeight = FontWeight.w600,
    this.color,
    this.showSign = false,
    this.isExpense = false,
    this.isIncome = false,
  });

  final int cents;
  final double fontSize;
  final FontWeight fontWeight;
  final Color? color;
  final bool showSign;
  final bool isExpense;
  final bool isIncome;

  @override
  ConsumerState<AmountText> createState() => _AmountTextState();
}

class _AmountTextState extends ConsumerState<AmountText> {
  Timer? _revealTimer;
  bool _revealed = false;

  @override
  void dispose() {
    _revealTimer?.cancel();
    super.dispose();
  }

  void _toggleReveal() {
    final hideAmounts = ref.read(hideAmountsProvider);
    if (!hideAmounts) return; // Not hidden, nothing to reveal

    setState(() => _revealed = true);
    _revealTimer?.cancel();
    _revealTimer = Timer(UiDurations.revealBalance, () {
      if (mounted) {
        setState(() => _revealed = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final hideAmounts = ref.watch(hideAmountsProvider);
    final isHidden = hideAmounts && !_revealed;

    final text = formatAmount(widget.cents, hide: isHidden);
    final sign = widget.showSign
        ? (widget.isExpense ? '-' : widget.isIncome ? '+' : '')
        : '';
    final display = '$sign$text';

    final color = widget.color ??
        (widget.isExpense
            ? context.colors.expense
            : widget.isIncome
                ? context.colors.income
                : context.colors.ink);

    return GestureDetector(
      onTap: _toggleReveal,
      child: Text(
        display,
        style: TextStyle(
          fontSize: widget.fontSize,
          // ⚠️ 不写 height 会静默继承 DefaultTextStyle（见 amountLineHeight）。
          // 这是**金额**，走 `.amt` 那套比值 + tracking，不用 designLineHeight。
          height: amountLineHeight(widget.fontSize),
          letterSpacing: amountLetterSpacing(widget.fontSize),
          fontWeight: widget.fontWeight,
          color: color,
          fontFeatures: kTabularFigures,
        ),
      ),
    );
  }
}

/// Currency symbol + amount with hide mode + tap-to-reveal (5s).
class AmountWithCurrency extends ConsumerStatefulWidget {
  const AmountWithCurrency({
    super.key,
    required this.cents,
    this.fontSize = 15,
    this.fontWeight = FontWeight.w600,
    this.color,
    this.showSign = false,
    this.isExpense = false,
    this.isIncome = false,
  });

  final int cents;
  final double fontSize;
  final FontWeight fontWeight;
  final Color? color;
  final bool showSign;
  final bool isExpense;
  final bool isIncome;

  @override
  ConsumerState<AmountWithCurrency> createState() => _AmountWithCurrencyState();
}

class _AmountWithCurrencyState extends ConsumerState<AmountWithCurrency> {
  Timer? _revealTimer;
  bool _revealed = false;

  @override
  void dispose() {
    _revealTimer?.cancel();
    super.dispose();
  }

  void _toggleReveal() {
    final hideAmounts = ref.read(hideAmountsProvider);
    if (!hideAmounts) return;
    setState(() => _revealed = true);
    _revealTimer?.cancel();
    // G-7 语义 1–3：单点显示、5 秒自动遮回、连点刷新计时
    _revealTimer = Timer(UiDurations.revealBalance, () {
      if (mounted) setState(() => _revealed = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final hideAmounts = ref.watch(hideAmountsProvider);
    final isHidden = hideAmounts && !_revealed;
    final valueNeg = widget.cents < 0;
    // 符号统一排在货币符号之后（`¥-12.50` / `¥+12.50`）；隐藏金额时不显示符号。
    final String mark;
    if (isHidden) {
      mark = '';
    } else if (valueNeg) {
      mark = '-';
    } else if (widget.showSign) {
      mark = widget.isExpense ? '-' : (widget.isIncome ? '+' : '');
    } else {
      mark = '';
    }
    final display = isHidden
        ? '¥****'
        : '¥$mark${formatAmount(widget.cents.abs())}';

    final displayColor = widget.color ??
        (widget.isExpense
            ? context.colors.expense
            : widget.isIncome
                ? context.colors.income
                : context.colors.ink);

    return GestureDetector(
      onTap: _toggleReveal,
      child: Text(
        display,
        style: TextStyle(
          fontSize: widget.fontSize,
          // ⚠️ 不写 height 会静默继承 DefaultTextStyle（见 amountLineHeight）。
          height: amountLineHeight(widget.fontSize),
          letterSpacing: amountLetterSpacing(widget.fontSize),
          fontWeight: widget.fontWeight,
          color: displayColor,
          fontFeatures: kTabularFigures,
        ),
      ),
    );
  }
}
