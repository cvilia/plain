/// 投影三档 · 真值 ui-kit/00-foundation/tokens.json 的 `elevation`。
///
/// ⚠️ 亮态是**暖黑** rgba(48,41,30,·)，不是纯黑。既有的 tokens.shadow1/2/3
/// 是旧值（纯黑），新组件一律用本文件。
library;

import 'package:flutter/painting.dart';

abstract final class AppShadows {
  // ── 亮态：暖黑 ──
  /// 卡片、按钮 —— 规格图上的「0 1px 2px shadow-1」。
  static const BoxShadow light1 = BoxShadow(
      color: Color.fromRGBO(48, 41, 30, 0.05), offset: Offset(0, 1), blurRadius: 2);
  /// 浮起的卡片、下拉。
  static const BoxShadow light2 = BoxShadow(
      color: Color.fromRGBO(48, 41, 30, 0.08), offset: Offset(0, 4), blurRadius: 14);
  /// 弹层、模态。
  static const BoxShadow light3 = BoxShadow(
      color: Color.fromRGBO(48, 41, 30, 0.14), offset: Offset(0, 18), blurRadius: 44);

  // ── 暗态：纯黑加深 ──
  static const BoxShadow dark1 = BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.22), offset: Offset(0, 1), blurRadius: 2);
  static const BoxShadow dark2 = BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.34), offset: Offset(0, 4), blurRadius: 14);
  static const BoxShadow dark3 = BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.46), offset: Offset(0, 18), blurRadius: 44);

  // ── 品牌色投影 tint（Hero 卡 / 主按钮）──
  static const Color tintAccentLight = Color.fromRGBO(249, 115, 22, 0.16);
  static const Color tintPrimaryLight = Color.fromRGBO(52, 44, 32, 0.14);
  static const Color tintAccentDark = Color.fromRGBO(249, 115, 22, 0.22);
  static const Color tintPrimaryDark = Color.fromRGBO(0, 0, 0, 0.42);

  /// 按亮度取档。参数用 `bool isDark` —— 与 color_math.dart 的
  /// `chartTrack(..., bool isDark)` 等保持同一套约定。
  static BoxShadow level1(bool isDark) => isDark ? dark1 : light1;
  static BoxShadow level2(bool isDark) => isDark ? dark2 : light2;
  static BoxShadow level3(bool isDark) => isDark ? dark3 : light3;

  /// 按亮度取品牌色 tint。
  static Color tintAccent(bool isDark) => isDark ? tintAccentDark : tintAccentLight;
  static Color tintPrimary(bool isDark) => isDark ? tintPrimaryDark : tintPrimaryLight;
}
