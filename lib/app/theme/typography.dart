/// 素记 Plain · 字体与字阶（Quiet Ledger v3）。
///
/// 字体族唯一：MiSans（4 字重）。金额一律 tabularFigures。
/// 8 级封闭字阶：amount-input 44 / amount-xl 34 / amount-l 22 / amount-s 15
///              title 20 / heading 15 / body 14 / caption 12
/// 见 redesign-v3/02-TYPE-SYSTEM.md。
library;

import 'package:flutter/painting.dart';

/// 唯一字体族名 —— 必须与 pubspec.yaml 的 `fonts.family` 逐字一致。
const String kFontFamily = 'MiSans';

/// 缺字回退链。
const List<String> kFontFallback = <String>[
  'PingFang SC',
  'HarmonyOS Sans SC',
  'Noto Sans CJK SC',
  'Source Han Sans SC',
  'Microsoft YaHei',
];

/// 表格数字 —— 金额对齐的唯一手段。MiSans '1' 只有 '0' 的 63% 宽。
const List<FontFeature> kTabularFigures = <FontFeature>[
  FontFeature.tabularFigures(),
];

/// 字阶令牌。全部为编译期常量，**禁止在 build() 内构造**。
class AppTextStyles {
  AppTextStyles._();

  static TextStyle tabular(TextStyle base) =>
      base.copyWith(fontFeatures: kTabularFigures);

  // ── 金额四档（44 / 34 / 22 / 15）────────────────────────────────────────
  /// 记账页输入金额。《02-TYPE-SYSTEM》字阶第 1 行 / 设计稿 `.amt.input`：
  /// `font-size:44 · weight:600 · line-height:1.12 · letter-spacing:-.03em`。
  ///
  /// 行高用**无单位比值**（等价于 CSS `line-height:1.12`），随 fontSize 一起缩放，
  /// 字号档（0.9/1.0/1.15）与系统放大下不会裁字。原值 `52/44` = 1.1818 → 52px，
  /// 比设计稿的 49 高 3px；字重也误写成 700。
  static const TextStyle amountInput = TextStyle(
    fontFamily: kFontFamily,
    fontSize: 44,
    height: 1.12,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.03 * 44,
    fontFeatures: kTabularFigures,
  );

  /// 首页结余 / 净资产 / 详情主金额。
  ///
  /// ⚠️ 行高 `39.44/34`（= 1.16）来自 `spec.json` 实测：屏 2/4/14/18/20/21/22 的
  /// 金额元素一律是 `font-size:34 · line-height:39.44px · weight:700 · ls:-0.68px`，
  /// 且 `-0.68 / 34 = -0.02em`。原值 `42/34` 比设计稿高 2.56px、`ls` 也误写成 `-0.025em`。
  ///
  /// 行高一律用**无单位比值**（等价 CSS 无单位 `line-height`）：字号档
  /// （0.9/1.0/1.15）与系统字体缩放下行盒等比缩放，不会裁字。
  static const TextStyle amountXl = TextStyle(
    fontFamily: kFontFamily,
    fontSize: 34,
    height: 39.44 / 34,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.02 * 34,
    fontFeatures: kTabularFigures,
  );

  /// 卡片主数字。设计稿 `.amt.l`：`line-height:1.24`。
  ///
  /// ⚠️ 别用 `designLineHeight(22)`（= 29/22，那是 CSS `normal` 的值）：
  /// `.amt.l` 写的是**显式 1.24**，比 `normal` 矮 1.7px。
  static const TextStyle amountL = TextStyle(
    fontFamily: kFontFamily,
    fontSize: 22,
    height: 1.24,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.02 * 22,
    fontFeatures: kTabularFigures,
  );

  /// 列表行金额。设计稿 `.amt.s`：`line-height:1.34 · letter-spacing:-.01em`。
  ///
  /// 实测 `spec.json`：int 段 `size:15 · lh:20.1px · ls:-0.15px`，
  /// `.cur/.dec` 派生段 `size:9.3 · lh:12.462px · ls:-0.15px`。
  static const TextStyle amountS = TextStyle(
    fontFamily: kFontFamily,
    fontSize: 15,
    height: 1.34,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.01 * 15,
    fontFeatures: kTabularFigures,
  );

  // ── 文排四档（20 / 15 / 14 / 12）───────────────────────────────────────
  /// 顶栏 / 页面标题。
  ///
  /// 真值来自 `spec.json` 全 29 屏：顶栏标题一律 `size:20 · lh:normal · wt:600 · 行盒 27`。
  /// 原 `28/20` + `w700` 两处都不符（行盒 28 vs 27；字重 700 vs 600）。
  static const TextStyle title = TextStyle(
    fontFamily: kFontFamily,
    fontSize: 20,
    height: 27 / 20,
    fontWeight: FontWeight.w600,
  );

  /// 列表行主文本 / 区块标题。
  static const TextStyle heading = TextStyle(
    fontFamily: kFontFamily,
    fontSize: 15,
    height: 20 / 15,
    fontWeight: FontWeight.w500,
  );

  /// 正文。
  ///
  /// ⚠️ 这个令牌会被 `theme_resolver` 注入成 `textTheme.bodyLarge / bodyMedium`，
  /// 即**全站未显式写 style 的 `Text` 的默认行高**。原值 `22/14 = 1.5714`
  /// 正是「布局总比设计稿胖一圈」的根源 —— 设计稿 14px 是 `normal`，行盒 19（1.357）。
  static const TextStyle body = TextStyle(
    fontFamily: kFontFamily,
    fontSize: 14,
    height: 19 / 14,
    fontWeight: FontWeight.w400,
  );

  /// 分组 eyebrow / 次要信息 / 标签。
  static const TextStyle caption = TextStyle(
    fontFamily: kFontFamily,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.08 * 12,
  );

  /// 次要信息（无 tracking）。
  static const TextStyle meta = TextStyle(
    fontFamily: kFontFamily,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w400,
  );

  // ── 兼容别名 ───────────────────────────────────────────────────────────
  static const TextStyle displayXl = title;
  static const TextStyle display = amountXl;
  static const TextStyle amountHero = amountInput;
  static const TextStyle amountM = amountL;
  static const TextStyle titleLg = title;
  static const TextStyle titleSm = heading;
  static const TextStyle eyebrow = caption;
  static const TextStyle bodyStrong = heading;
  static const TextStyle label = caption;
}

/// CSS `line-height: normal` 的行高比值 —— **内联 `TextStyle` 补 `height` 的唯一依据**。
///
/// 为什么必须有这个函数：
/// `Text` 不写 `height` 时，会静默 merge `Material` 注入的 `DefaultTextStyle`
/// （= `textTheme.bodyMedium` = [AppTextStyles.body]）。修复前那个令牌是 `22/14 = 1.5714`，
/// 于是所有未显式指定行高的文本行盒都比设计稿**大一截**，且字号越大偏得越多：
/// 34px 金额实际占 53.4px，设计稿只有 39.44px。
///
/// `normal` = MiSans 自然行高（hhea 1044 / −282 = 1.326），**再按浏览器规则取整到整数像素**。
/// 实测（`redesign-v3/_build/spec.json`，真浏览器渲染，29 屏全量元素）逐一吻合：
///
/// | 字号 | 设计稿行盒 | 比值 | 取整校验（fontSize × 1.326） |
/// | ---- | ---------- | ---- | ---------------------------- |
/// | 44 | 58 | 1.318 | 58.344 → 58 |
/// | 34 | 45 | 1.324 | 45.084 → 45 |
/// | 22 | 29 | 1.318 | 29.172 → 29 |
/// | 20 | 27 | 1.350 | 26.520 → 27 |
/// | 15 | 20 | 1.333 | 19.890 → 20 |
/// | 14 | 19 | 1.357 | 18.564 → 19 |
/// | 12 | 16 | 1.333 | 15.912 → 16 |
///
/// 所以这里写「整数像素 ÷ 字号」，比写 1.326 更忠实于设计稿的实际占位。
///
/// ⚠️ **金额（`.amt` 系列）不要用这个函数** —— 那四档写的是**显式比值**，不是 `normal`。
/// 见 [amountLineHeight]。用错档：34 会算成 45（应为 39.44）、22 会算成 29（应为 27.28）。
///
/// ⚠️ **`normal` 是关键字，不是比值**：它按**各元素自身的 font-size** 重算，
/// 所以派生段（如预算页 hero 的 `0.62em` 段）要**用派生后的字号重新查表**。
/// 这与 [amountLineHeight] 的比值继承**恰好相反**，别弄混：
/// 实测预算页 `.hero-amt` 34 → 45、其派生段 21.08 → **28**（21.08 × 1.326 = 27.95）。
double designLineHeight(double fontSize) {
  return switch (fontSize) {
    44 => 58 / 44,
    34 => 45 / 34,
    22 => 29 / 22,
    20 => 27 / 20,
    15 => 20 / 15,
    14 => 19 / 14,
    12 => 16 / 12,
    _ => 1.326,
  };
}

/// `.amt` 金额系列的行高比值 —— 与 [designLineHeight] **不是一套**。
///
/// CSS（`redesign-v3/_build/gen_screens.py`）：
/// ```css
/// .amt     { letter-spacing:-.02em }
/// .amt.xl  { font-size:34px; line-height:1.16 }   /* 首页结余 / 净资产 / 详情主金额 */
/// .amt.l   { font-size:22px; line-height:1.24 }   /* 卡片主数字 */
/// .amt.s   { font-size:15px; line-height:1.34; letter-spacing:-.01em }  /* 列表行金额 */
/// .amt.input{font-size:44px; line-height:1.12; letter-spacing:-.03em }  /* 记账页输入 */
/// ```
/// 实测：
/// - 34 档 → `39.44px`；派生段 21.08 → `24.4528 = 21.08 × 1.16` ✓
/// - 44 档 → `49.28px`；派生段 27.28 → `30.5536 = 27.28 × 1.12` ✓
/// - 15 档 → `20.1px`；派生段 9.3 → `12.462 = 9.3 × 1.34` ✓
///
/// ⚠️ 这些是**无单位比值**，所以 [amountDisplaySegments] 里**四段共用主字号的返回值**，
/// 不要拿派生后的字号再查一次。
double amountLineHeight(double fontSize) {
  return switch (fontSize) {
    44 => 1.12,
    34 => 1.16,
    22 => 1.24,
    15 => 1.34,
    _ => designLineHeight(fontSize),
  };
}

/// `.amt` 金额系列的 `letter-spacing`（**绝对像素**）。
///
/// CSS 里写的是 `em`，但 `em` 在**计算值阶段**就解析成 px，而 `letter-spacing`
/// 继承的是**计算值** → 四段拿到的是**同一个绝对像素值**，不随各段字号变化。
///
/// 实测反推完全吻合（`spec.json`，四段 ls 逐段相等）：
///
/// | 档 | 主段 | 派生段 | 反推 CSS |
/// | --- | --- | --- | --- |
/// | 44 | `-1.32px` | `-1.32px` | `-1.32 / 44 = -.03em` ✓ |
/// | 34 | `-0.68px` | `-0.68px` | `-0.68 / 34 = -.02em` ✓ |
/// | 15 | `-0.15px` | `-0.15px` | `-0.15 / 15 = -.01em` ✓ |
///
/// ⚠️ 所以派生段**不要重算**（`-0.02em × 21.08` 是错的），直接把主字号的返回值原样传下去。
double amountLetterSpacing(double fontSize) {
  return switch (fontSize) {
    44 => -0.03 * 44,
    22 => -0.02 * 22,
    15 => -0.01 * 15,
    _ => -0.02 * fontSize,
  };
}

/// `.amt.s` 的小数位**与整数同号同色** —— 只有 15 档这样。
///
/// CSS：`.amt.s .dec{font-size:1em;color:inherit}`。其余档是
/// `.amt .dec{font-size:.62em;color:var(--muted)}`。
///
/// 实测吻合（`spec.json`）：
/// - s 档：`dec` = `size:15 · col:rgb(16,16,18)`，与 `int` 完全一致 ✓
/// - xl 档：`dec` = `size:21.08 · col:rgb(94,94,101)`，与 `int` 的 ink 不同 ✓
///
/// ⚠️ s 档（15px）是列表行金额，用量最大（29 屏里 116+ 处），别漏。
bool amountDecimalsFollowBase(double fontSize) => fontSize == 15;
