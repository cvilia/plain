/// Quiet Ledger signature amount: currency 0.62em muted + integer 700 ink
/// + decimal 0.62em muted, with tabular figures.
/// See redesign-v3/02-TYPE-SYSTEM.md § amount scale.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plain/app/theme/app_colors.dart';
import 'package:plain/app/theme/typography.dart';
import 'package:plain/core/constants/app_constants.dart';
import 'package:plain/core/format/amount_formatter.dart';

/// Four-part amount display — the product's visual signature.
///
/// 默认按设计稿 `.amt` 系列渲染（行高比值 + `-.02em` tracking，见 [amountLineHeight]）。
/// ⚠️ 非 `.amt` 的场合（如环形图中心 `.dn-*`，`line-height:normal` 且 `letter-spacing:normal`）
/// 要显式传 `letterSpacing: 0`，行高则自然走 [amountLineHeight] 的兜底分支。
class AmountDisplay extends ConsumerStatefulWidget {
  const AmountDisplay({
    super.key,
    required this.cents,
    this.fontSize = 15,
    this.integerWeight = FontWeight.w700,
    this.color,
    this.decorationColor,
    this.showSign = false,
    this.isExpense = false,
    this.isIncome = false,
    this.currency = '¥',
    this.letterSpacing,
  });

  final int cents;
  final double fontSize;
  final FontWeight integerWeight;
  final Color? color;
  final Color? decorationColor;
  final bool showSign;
  final bool isExpense;
  final bool isIncome;
  final String currency;

  /// 传 `null`（默认）走 `.amt` 的 `-.02em`；非 `.amt` 场合传 `0`。
  final double? letterSpacing;

  @override
  ConsumerState<AmountDisplay> createState() => _AmountDisplayState();
}

class _AmountDisplayState extends ConsumerState<AmountDisplay> {
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
    _revealTimer = Timer(UiDurations.revealBalance, () {
      if (mounted) setState(() => _revealed = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final hideAmounts = ref.watch(hideAmountsProvider);
    final isHidden = hideAmounts && !_revealed;

    final parsed = formatAmountParts(widget.cents, hide: isHidden);
    final sign = widget.showSign
        ? (widget.isExpense ? '-' : widget.isIncome ? '+' : '')
        : '';

    final main = widget.color ??
        (widget.isExpense
            ? context.colors.expense
            : widget.isIncome
                ? context.colors.income
                : context.colors.ink);
    // 语义色（支出红 / 收入绿）下，设计稿 `.tone-*` 让**四段全取主色**，只把
    // `cur` / `dec` 压到 70% 不透明：
    //   `.tone-income .int,.tone-income .pnt{color:var(--income)}`
    //   `.tone-income .cur,.tone-income .dec{color:var(--income);opacity:.7}`
    // 中性金额才是「int/pnt 墨色 + cur/dec muted」。
    // 实测吻合：红色行四段 `col` 全是 `rgb(220,38,38)`（opacity 不进计算色）。
    //
    // 判定用「**渲染出来的主色是不是语义色**」，而不是「调用方有没有传 color」：
    // 设计里首页流水的「支出」split 是**墨色**（`.hs` 注释：支出 ink），只有「收入」是红。
    // 按 color 判会把支出也当成 toned，cur/dec 错成 70% 墨色而非 muted。
    final isToned =
        main == context.colors.expense || main == context.colors.income;
    final quiet = widget.decorationColor ??
        (isToned ? main.withValues(alpha: 0.7) : context.colors.inkTertiary);

    final base = widget.fontSize;
    final small = base * 0.62;
    // ⚠️ 四段**都必须带 height 与 letterSpacing**，且四段**共用主字号的两个返回值**。
    //
    // 不写 height 就静默继承 `Material` 注入的 `DefaultTextStyle`
    // （`AppTextStyles.body`）—— 34px 金额的行盒会从设计稿的 39.44 涨到 53.4，
    // 整块金额区跟着长高。见 [amountLineHeight]。
    //
    // 货币符与小数位是 `0.62em` 派生（21.08px），**不要**按 21.08 另查表：
    // `.amt` 用的是**无单位比值**，CSS 的无单位 `line-height` 是比值继承 ——
    // 实测该段行盒 24.4528 = 21.08 × 1.16，用的正是 34 档的比值。
    // `designLineHeight()` 那套（`normal` 关键字）才是按各段自身字号重算，**两套别混**。
    //
    // `letterSpacing` 同理：CSS 的 `em` 在计算值阶段就解析成 px，继承的是计算值，
    // 所以四段拿到的**是同一个绝对像素**（实测 34 档四段都是 -0.68px）。
    final lh = amountLineHeight(base);
    final ls = widget.letterSpacing ?? amountLetterSpacing(base);

    // ⚠️ s 档（15px）的小数位**与整数同号同色** —— `.amt.s .dec{font-size:1em;color:inherit}`。
    // 其余档才是 `0.62em` + muted。s 档是列表行金额，用量最大，别漏这一条。
    // 显式传 `decorationColor` 仍然优先（它是 escape hatch，别让它被静默吞掉）。
    final decFollowsBase = amountDecimalsFollowBase(base);
    final decSize = decFollowsBase ? base : small;
    final decColor = widget.decorationColor ?? (decFollowsBase ? main : quiet);

    return GestureDetector(
      onTap: _toggleReveal,
      child: Text.rich(
        TextSpan(
          children: [
            if (sign.isNotEmpty)
              TextSpan(
                text: sign,
                style: TextStyle(
                  fontSize: base,
                  height: lh,
                  letterSpacing: ls,
                  fontWeight: widget.integerWeight,
                  color: main,
                  fontFeatures: kTabularFigures,
                ),
              ),
            TextSpan(
              text: widget.currency,
              style: TextStyle(
                fontSize: small,
                height: lh,
                letterSpacing: ls,
                fontWeight: FontWeight.w600,
                color: quiet,
                fontFeatures: kTabularFigures,
              ),
            ),
            TextSpan(
              text: parsed.intPart,
              style: TextStyle(
                fontSize: base,
                height: lh,
                letterSpacing: ls,
                fontWeight: widget.integerWeight,
                color: main,
                fontFeatures: kTabularFigures,
              ),
            ),
            TextSpan(
              text: '.',
              style: TextStyle(
                fontSize: base,
                height: lh,
                letterSpacing: ls,
                fontWeight: widget.integerWeight,
                color: main,
                fontFeatures: kTabularFigures,
              ),
            ),
            TextSpan(
              text: parsed.decPart,
              style: TextStyle(
                fontSize: decSize,
                height: lh,
                letterSpacing: ls,
                fontWeight: FontWeight.w600,
                color: decColor,
                fontFeatures: kTabularFigures,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
