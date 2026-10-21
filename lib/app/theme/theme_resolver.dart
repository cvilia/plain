/// Theme resolver: resolveBrightness, resolveTokens, buildThemeData + 20-entry cache.
/// ThemeData must be cached — never compute colors inside build(). See 04-技术架构设计.md §16.1.
library;

import 'package:flutter/material.dart';
import 'package:plain/app/theme/color_math.dart' as cm;
import 'package:plain/app/theme/theme_registry.dart';
import 'package:plain/app/theme/app_colors.dart';
import 'package:plain/app/theme/tokens.dart';
import 'package:plain/app/theme/typography.dart';

/// Resolve platform brightness + user preference → effective Brightness.
Brightness resolveBrightness(ThemeMode mode, Brightness platform) {
  return switch (mode) {
    ThemeMode.system => platform,
    ThemeMode.light => Brightness.light,
    ThemeMode.dark => Brightness.dark,
  };
}

/// 方框底色的默认「白色占比」：0.60 = 白 60% × 纸色 40%（产品口径，2026-10-20）。
/// 用户可在「主题 → 卡片透明度」里覆盖（存 `pref.theme.cardOpacity`）。
const double kCardOpacityDefault = 0.60;

/// Resolve full 46-token set from a ThemeSpec × Brightness. Result should be cached.
///
/// [cardOpacity] 是方框底里白色所占比例（0–1）。默认 [kCardOpacityDefault]，
/// 传 1.0 = 纯白实心，0.0 = 与页面同色（方框消失）。
AppTokens resolveTokens(
  ThemeSpec spec,
  Brightness brightness, {
  double cardOpacity = kCardOpacityDefault,
}) {
  final isDark = brightness == Brightness.dark;
  final tone = toneOf(spec.tone, isDark);
  final brand = isDark ? spec.dark : spec.light;

  // ── 页面纸色：中性纸 × 品牌主色 wash ──────────────────────────────────────
  //
  // `surface`（卡片）保持中性，只让 `bg` / `appBg` 带主题色。这样「卡片浮在带色
  // 页面上」靠明度分层，而不是旧版「页面纯白 + 卡片纯白」纯靠边框。
  //
  // 亮色：直接 `mix(纸, 品牌色, wash)` —— 品牌色比纸深，叠完是「淡彩纸」。
  // 暗色：不能直接叠。品牌色在暗色档是一支亮色（青瓷 `#79BFC8`），叠上去页面
  //   比卡片还亮，20 个组合里 16 个层级倒挂；改成「先压暗再叠」又会把彩度压没
  //   （绯樱 `#72313A` 压 55% 只剩近黑，ΔE 0.78 等于没染）。最终用 `atLuminance`：
  //   色相/饱和度照抄品牌色，亮度对齐到「纸色与卡片之间 42% 处」，色温和层级都不丢。
  //   混合比例用 `0.45 + washDark`，让每支主题的染色强度仍由 washDark 控制。
  //
  // 不变量（`theme_gates_test.dart` 有断言）：`lum(bg) < lum(appBg) < lum(surface)`。
  int darkPaper(int base, double fraction) => cm.mix(
        base,
        cm.atLuminance(
            brand.p, cm.lum(base) + fraction * (cm.lum(tone.surface) - cm.lum(base))),
        0.45 + spec.washDark,
      );
  final appBgInt = isDark
      ? darkPaper(tone.appBg, 0.42)
      : cm.mix(tone.appBg, brand.p, spec.washLight);
  final bgInt = isDark
      ? darkPaper(tone.bg, 0.22)
      : cm.mix(tone.bg, brand.p, spec.washLight + 0.03);
  // 暗色卡片也要摻一点品牌色：中性层是「冷灰」，放在靛蓝（紫）或豆绿（黄）的
  // 页面上会显出绿灰/灰蓝，正是「配色互相打架」。亮度对齐到原卡片亮度，
  // 所以「卡片比页面亮」这条不变量不受影响。
  final surfaceBaseInt = isDark
      ? cm.mix(tone.surface, cm.atLuminance(brand.p, cm.lum(tone.surface)), 0.16)
      : 0xFFFFFFFF;
  // 卡片底「预混」（2026-10-20 用户口径，最终版）：
  // **所有方框 = 白色 60% 透明** —— 即「60% 纯白 + 40% 页面纸色」的实色。
  // 亮色直接用纯白做基色（用户口径就是「白色 60%」，不掺暖白）；
  // 暗色仍走「卡片色 × 60%」（纯白 60% 在深底上会变灰白，反而不像卡）。
  //
  // 用预混实色而不是真 alpha：
  //   ① 弹层/菜单/toast 也用这支色，实心底文字可读性不受影响；
  //   ② 暗色下半透明浅色会被深底吃掉（卡片消失），预混天然适配明暗两档；
  //   ③ 不存在「两层各带 alpha 叠乘」的坑（流水页 0.8×0.8=0.96 的教训）。
  // 卡片在页面上的最终渲染值与真透明完全一致（它下面就是 appBg）。
  final opacity = cardOpacity.isNaN ? kCardOpacityDefault : cardOpacity.clamp(0.0, 1.0);
  final surfaceInt = cm.mix(appBgInt, surfaceBaseInt, opacity);
  // 描边也掺 5% 品牌色，否则纯灰线放在彩色纸上一眼「没调过」。
  final lineInt = cm.mix(tone.line, brand.p, 0.05);
  final lineSoftInt = cm.mix(tone.lineSoft, brand.p, 0.04);
  // surface2（键帽 / 输入框 / 幽灵 chip 等次级面）**与 surface 完全同色**：
  // 用户要求「所有这些方框的背景色全部改成白色 60% 透明度」，不再保留
  // 25% 的层级差（记一笔页 chip vs 键帽曾差一档，反复被指出来）。
  // 层级改由 1px 描边与留白表达（Quiet Ledger 本来就不靠填充分层）。
  final surface2Int = surfaceInt;

  // v3 附加令牌：旧的 `tokens_v3_data.dart` 是按老品牌色生成的，全表只有
  // lineStrong / surfaceInset / disabledFg / disabledBg 4 个在用，且都是中性灰。
  // 改成从纸色推导，颜色温度自动跟着主题走。
  final lineStrongInt = cm.mix(lineInt, tone.ink, 0.34);
  final lineStrongSoftInt = cm.mix(lineInt, tone.ink, 0.18);
  final surfaceInsetInt = cm.mix(appBgInt, tone.ink, 0.035);
  final disabledBgInt = cm.mix(appBgInt, tone.ink, 0.05);
  final disabledFgInt = cm.mix(appBgInt, tone.muted, 0.45);
  final focusRingInt = brand.p;

  // Soft-layer alphas (global constants, §4.1).
  final softA = isDark ? kSoftAlphaDark : kSoftAlphaLight;
  final tintA = isDark ? kTintAlphaDark : kTintAlphaLight;
  final aSoftA = isDark ? kASoftAlphaDark : kASoftAlphaLight;

  int argb(int color, int shift) => (color >> shift) & 0xFF;
  Color softOf(int base, double alpha) => Color.fromRGBO(
      argb(base, 16), argb(base, 8), argb(base, 0), alpha);

  // ── Derived: on-primary / on-accent (§4.6 ②)
  final onPrimary = cm.pickOn(brand.p, tone.ink, 4.5);
  final onAccent = cm.pickOn(brand.a, tone.ink, 4.5);

  // Composite soft/tint over every possible host base (rendered values).
  final hosts = <int>[surfaceInt, surface2Int, bgInt, appBgInt];
  final pSoftOver = <int>[for (final host in hosts) cm.composite(brand.p, softA, host)];
  final pTintOver = <int>[for (final host in hosts) cm.composite(brand.p, tintA, host)];
  final aSoftOver = <int>[for (final host in hosts) cm.composite(brand.a, aSoftA, host)];

  // Colored small-text inks must clear 4.5:1 on every host, not just one.
  final primaryInk = cm.inkForLayers(
    brand.p,
    <int>[...pSoftOver, ...pTintOver, surfaceInt, bgInt, appBgInt],
    4.5,
  );
  final accentInk = cm.inkForLayers(
    brand.a,
    <int>[...aSoftOver, surfaceInt, bgInt, appBgInt],
    4.5,
  );

  // ── Income ink (opaque soft layer + naked bases)
  final incomeBase = semColor('income', isDark);
  final incomeSoftInt = semColor('incomeSoft', isDark);
  final incomeSoft = Color(incomeSoftInt);
  final incomeLine = Color(semColor('incomeLine', isDark));
  final incomeInk = cm.inkForLayers(
    incomeBase,
    <int>[incomeSoftInt, surfaceInt, bgInt, appBgInt],
    4.5,
  );

  // ── Status inks (opaque soft layers + naked bases)
  final okSoftBase = semColor('okSoft', isDark);
  final okBase = semColor('okBase', isDark);
  final okInk = cm.inkForLayers(
    okBase,
    <int>[okSoftBase, surfaceInt, bgInt, appBgInt],
    4.5,
  );

  final warnSoftBase = semColor('warnSoft', isDark);
  final warnInkBase = semColor('warnInk', isDark);

  final dnBgBase = semColor('dnBg', isDark);
  final dnBase = semColor('dnBase', isDark);
  final dnInk = cm.inkForLayers(
    dnBase,
    <int>[dnBgBase, surfaceInt, bgInt, appBgInt],
    4.5,
  );

  // ── Hero gradient endpoints (§4.6 ④) — always white text
  final hero0 = cm.heroSafe(brand.hero0);
  final hero1 = cm.heroSafe(brand.hero1);
  // heroDark0/1 are design-locked for white text; heroSafe is the safety net.
  final heroDark0 = cm.heroSafe(brand.heroDark0);
  final heroDark1 = cm.heroSafe(brand.heroDark1);

  // ── Charts (§4.6 ⑤)
  final chartTrack = Color(cm.chartTrack(surface2Int, brand.p, isDark));
  final barFill = Color(cm.barFill(appBgInt, brand.p, isDark));
  final dash = Color(cm.dashColor(lineInt, tone.muted));

  // ── Hero card（与主题无关，见 theme_registry.dart 的常量）──
  final heroCard0 = isDark ? kHeroCardDark0 : kHeroCardLight0;
  final heroCard1 = isDark ? kHeroCardDark1 : kHeroCardLight1;

  // ── Glow / shadow alphas
  final glowAlpha = isDark ? 0.12 : 0.08;
  final shadowAlpha = isDark ? 0.18 : 0.10;

  // ── FAB：底色 = 导航选中色（`primaryInk`），图标 = 它的可读前景 ──────────
  //
  // 产品口径（2026-10-20 用户明确）：底栏那个「记一笔」方块，颜色必须和右边
  // 被选中的导航项一致 —— 它是同一套「当前主题可操作色」的两个呈现，不是两个色。
  // 导航项 `_NavItem` 选中时用 `primaryInk`（`home_shell.dart`），所以这里也用它。
  //
  // `primaryInk` 是「品牌色被反推成 4.5:1 文字级色」的结果：亮色主题是一支压深的
  // 品牌色（`青瓷 #236270`），暗色主题是一支提亮的品牌色（`青瓷 #AFD9DE`）。
  // 于是 FAB 天然是「亮主题深底白图标 / 暗主题浅底深图标」，不需要按亮度分支。
  //
  // ⚠️ 图标色不能直接复用 `onAccent`（那是 accent 的前景），也不用 `inkFor(...3.0)`：
  // 3.0 的兜底会在 `contrast(fg,bg) ≥ 3.0` 时**直接返回前景本身**，出现「同色画同色」。
  // `pickOn(底, 中性深/浅, 4.5)` 是先判深底用白、浅底用深，够不上才追色。
  final fabBgInt = primaryInk;
  final fabIconInt = cm.pickOn(primaryInk, surfaceInt, 4.5);
  final fabFgInt = fabIconInt;
  final fabIcInt = fabIconInt;

  // ── Accent gradient (§4.6 ③)
  final sheen = cm.accentSheen(brand.a, onAccent);

  return AppTokens(
    bg: Color(bgInt), appBg: Color(appBgInt),
    surface: Color(surfaceInt), surface2: Color(surface2Int),
    ink: Color(tone.ink), ink2: Color(tone.ink2),
    muted: Color(tone.muted), faint: Color(tone.faint),
    line: Color(lineInt), lineSoft: Color(lineSoftInt),

    primary: Color(brand.p), primaryDeep: Color(brand.pd),
    // Soft layers stay translucent — Flutter composites them at paint time
    // (B-scheme "airiness"): same token reads slightly different on each host.
    primarySoft: softOf(brand.p, softA),
    primaryTint: softOf(brand.p, tintA),

    accent: Color(brand.a), accentDeep: Color(brand.ad),
    accentSoft: softOf(brand.a, aSoftA),
    accentGrad: linearGradient(Color(sheen), Color(brand.a)),

    onPrimary: Color(onPrimary), onAccent: Color(onAccent),
    primaryInk: Color(primaryInk), accentInk: Color(accentInk),

    income: Color(incomeBase), incomeSoft: incomeSoft,
    incomeLine: incomeLine, incomeInk: Color(incomeInk),

    okSoft: Color(okSoftBase), okInk: Color(okInk),
    warnSoft: Color(warnSoftBase), warnInk: Color(warnInkBase),
    dnBg: Color(dnBgBase), dnInk: Color(dnInk),

    heroGrad0: Color(hero0), heroGrad1: Color(hero1),
    heroDarkGrad0: Color(heroDark0), heroDarkGrad1: Color(heroDark1),
    frame: Color(brand.frame),
    heroCard0: Color(heroCard0), heroCard1: Color(heroCard1),
    fabBg: Color(fabBgInt), fabFg: Color(fabFgInt), fabIc: Color(fabIcInt),

    chartTrack: chartTrack, barFill: barFill, dash: dash,

    glowPrimary: Color.fromRGBO(
      (brand.p >> 16) & 0xFF, (brand.p >> 8) & 0xFF, brand.p & 0xFF, glowAlpha),
    glowAccent: Color.fromRGBO(
      (brand.a >> 16) & 0xFF, (brand.a >> 8) & 0xFF, brand.a & 0xFF, glowAlpha),
    shadowPrimary: Color.fromRGBO(
      (brand.p >> 16) & 0xFF, (brand.p >> 8) & 0xFF, brand.p & 0xFF, shadowAlpha),
    // FAB 阴影：FAB 底色改成 `primaryInk` 后，阴影跟着底色走（唯一使用点就是 FAB）。
    shadowAccent: Color.fromRGBO(
      (fabBgInt >> 16) & 0xFF, (fabBgInt >> 8) & 0xFF, fabBgInt & 0xFF, shadowAlpha),
    // Toast is a decorative layer: inverted ink, never a hard-coded hex.
    toastBg: Color(tone.ink),
    // v3: warm-black shadows in light (not pure black); dark keeps black.
    shadow1: isDark
        ? const Color.fromRGBO(0, 0, 0, 0.22)
        : const Color.fromRGBO(48, 41, 30, 0.05),
    shadow2: isDark
        ? const Color.fromRGBO(0, 0, 0, 0.34)
        : const Color.fromRGBO(48, 41, 30, 0.08),
    shadow3: isDark
        ? const Color.fromRGBO(0, 0, 0, 0.46)
        : const Color.fromRGBO(48, 41, 30, 0.14),
    lineStrong: Color(lineStrongInt),
    lineStrongSoft: Color(lineStrongSoftInt),
    focusRing: Color(focusRingInt),
    surfaceInset: Color(surfaceInsetInt),
    disabledFg: Color(disabledFgInt),
    disabledBg: Color(disabledBgInt),
    overlay: Color.fromRGBO(0, 0, 0, isDark ? 0.56 : 0.32),
    skeleton: Color(surface2Int),
    primaryPressed: Color(cm.mix(brand.p, 0xFF000000, isDark ? 0.0 : 0.10)),
    accentPressed: Color(cm.mix(brand.a, 0xFF000000, isDark ? 0.0 : 0.10)),
  );
}

// ─── ThemeData construction (§4.7) ───────────────────────────────────────────

ThemeData buildThemeData(AppTokens tokens, Brightness brightness) {
  final scheme = ColorScheme(
    brightness: brightness,
    primary: tokens.primary,
    onPrimary: tokens.onPrimary,
    primaryContainer: tokens.primarySoft,
    onPrimaryContainer: tokens.primaryInk,
    secondary: tokens.accent,
    onSecondary: tokens.onAccent,
    secondaryContainer: tokens.accentSoft,
    onSecondaryContainer: tokens.accentInk,
    tertiary: tokens.accent,
    onTertiary: tokens.onAccent,
    surface: tokens.surface,
    onSurface: tokens.ink,
    surfaceContainerLowest: tokens.appBg,
    surfaceContainerLow: tokens.surface2,
    surfaceContainer: tokens.bg,
    surfaceContainerHigh: tokens.surface2,
    surfaceContainerHighest: tokens.surface2,
    surfaceDim: tokens.surface2,
    surfaceBright: tokens.surface,
    onSurfaceVariant: tokens.ink2,
    outline: tokens.line,
    outlineVariant: tokens.lineSoft,
    error: tokens.income,
    onError: tokens.onAccent,
    errorContainer: tokens.incomeSoft,
    onErrorContainer: tokens.incomeInk,
    inverseSurface: tokens.ink,
    onInverseSurface: tokens.surface,
    inversePrimary: tokens.primarySoft,
    shadow: tokens.shadow1,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: brightness,
    fontFamily: kFontFamily,
    fontFamilyFallback: kFontFallback,
    scaffoldBackgroundColor: tokens.appBg,
    appBarTheme: AppBarTheme(
      backgroundColor: tokens.appBg,
      foregroundColor: tokens.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
    ),
    cardTheme: CardThemeData(
      color: tokens.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: tokens.line),
      ),
      margin: EdgeInsets.zero,
    ),
    dividerTheme: DividerThemeData(color: tokens.lineSoft, thickness: 1, space: 1),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: tokens.toastBg,
      contentTextStyle: TextStyle(color: brightness == Brightness.dark ? tokens.appBg : tokens.surface, fontSize: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: tokens.primary,
        foregroundColor: tokens.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return tokens.primary;
        return tokens.faint;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return tokens.primarySoft;
        return tokens.surface2;
      }),
    ),
    textTheme: TextTheme(
      bodyLarge: AppTextStyles.body.copyWith(color: tokens.ink),
      bodyMedium: AppTextStyles.body.copyWith(color: tokens.ink),
      bodySmall: AppTextStyles.meta.copyWith(color: tokens.ink2),
      titleLarge: AppTextStyles.titleLg.copyWith(color: tokens.ink),
      titleMedium: AppTextStyles.titleSm.copyWith(color: tokens.ink),
      titleSmall: AppTextStyles.bodyStrong.copyWith(color: tokens.ink),
      labelLarge: AppTextStyles.bodyStrong.copyWith(color: tokens.ink),
      labelMedium: AppTextStyles.meta.copyWith(color: tokens.ink2),
      labelSmall: AppTextStyles.eyebrow.copyWith(color: tokens.muted),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: tokens.surface2,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: tokens.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: tokens.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: tokens.primary, width: 1.5),
      ),
    ),
    extensions: [AppColors.fromTokens(tokens)],
  );
}

// ─── Cache: bounded 40 entries (20 themes × 2 brightness + 拖动中的临时档) ────

final Map<String, (AppTokens, ThemeData)> _cache = {};

/// 拖动透明度滑杆会连续生成新分档（最多 201 档 × 20 组合），
/// ThemeData 不小，必须设上限，否则拖一次就留下几十 MB。
/// 淘汰时优先扔「非默认透明度」的临时档，20 个基础档常驻。
const int _kCacheMax = 40;

String _defaultBucketSuffix() => '_${(kCardOpacityDefault * 200).round()}';

void _evictThemeCacheIfNeeded() {
  if (_cache.length < _kCacheMax) return;
  final suffix = _defaultBucketSuffix();
  String? victim;
  for (final k in _cache.keys) {
    if (!k.endsWith(suffix)) {
      victim = k;
      break;
    }
  }
  _cache.remove(victim ?? _cache.keys.first);
}

/// Get cached tokens + ThemeData for a theme × brightness. Builds once.
(AppTokens, ThemeData) themeDataFor(
  ThemeId id,
  Brightness brightness, {
  double cardOpacity = kCardOpacityDefault,
}) {
  // 缓存键必须带透明度：否则拖动滑杆时命中旧 ThemeData，界面不刷新。
  // 量化到 0.5%（滑杆本身就是连续的，缓存只需大致分档）。
  final bucket = (cardOpacity.clamp(0.0, 1.0) * 200).round();
  final key = '${id.id}_${brightness.name}_$bucket';
  final hit = _cache[key];
  if (hit != null) return hit;
  _evictThemeCacheIfNeeded();
  final spec = themeSpecOf(id);
  final tokens = resolveTokens(spec, brightness, cardOpacity: cardOpacity);
  final data = buildThemeData(tokens, brightness);
  return _cache[key] = (tokens, data);
}
