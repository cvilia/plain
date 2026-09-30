/// Theme resolver: resolveBrightness, resolveTokens, buildThemeData + 20-entry cache.
/// ThemeData must be cached — never compute colors inside build(). See 需求变更.md §6.4.
library;

import 'package:flutter/material.dart';
import 'package:plain/app/theme/color_math.dart' as cm;
import 'package:plain/app/theme/theme_registry.dart';
import 'package:plain/app/theme/tokens.dart';

/// Resolve platform brightness + user preference → effective Brightness.
Brightness resolveBrightness(ThemeMode mode, Brightness platform) {
  return switch (mode) {
    ThemeMode.system => platform,
    ThemeMode.light => Brightness.light,
    ThemeMode.dark => Brightness.dark,
  };
}

/// Resolve full 46-token set from a ThemeSpec × Brightness. Result should be cached.
AppTokens resolveTokens(ThemeSpec spec, Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final tone = toneOf(spec.tone, isDark);
  final brand = isDark ? spec.dark : spec.light;

  // ── Derived: on-primary / on-accent (§4.6 ②)
  final onPrimary = cm.pickOn(brand.p, tone.ink, 4.5);
  final onAccent = cm.pickOn(brand.a, tone.ink, 4.5);

  // ── Derived: colored ink on tint backgrounds (§4.6 ①)
  final primaryInk = cm.inkFor(brand.p, brand.pt, 4.5);
  final accentInk = cm.inkFor(brand.a, brand.as_, 4.5);

  // ── Income ink (on incomeSoft)
  final incomeBase = semColor('income', isDark);
  final incomeSoftInt = semColor('incomeSoft', isDark);
  final incomeSoft = Color(incomeSoftInt);
  final incomeLine = Color(semColor('incomeLine', isDark));
  final incomeInk = cm.inkFor(incomeBase, incomeSoftInt, 4.5);

  // ── Status inks (on respective soft backgrounds)
  final okSoftBase = semColor('okSoft', isDark);
  final okBase = semColor('okBase', isDark);
  final okInk = cm.inkFor(okBase, okSoftBase, 4.5);

  final warnSoftBase = semColor('warnSoft', isDark);
  final warnInkBase = semColor('warnInk', isDark);

  final dnBgBase = semColor('dnBg', isDark);
  final dnBase = semColor('dnBase', isDark);
  final dnInk = cm.inkFor(dnBase, dnBgBase, 4.5);

  // ── Hero gradient endpoints (§4.6 ④) — always white text
  final hero0 = cm.heroSafe(brand.hero0);
  final hero1 = cm.heroSafe(brand.hero1);

  // ── Charts (§4.6 ⑤)
  final chartTrack = Color(cm.chartTrack(tone.surface2, brand.p, isDark));
  final barFill = Color(cm.barFill(tone.appBg, brand.p, isDark));
  final dash = Color(cm.dashColor(tone.line, tone.muted));

  // ── Glow / shadow alphas
  final glowAlpha = isDark ? 0.12 : 0.08;
  final shadowAlpha = isDark ? 0.18 : 0.10;

  // ── Accent gradient (§4.6 ③)
  final sheen = cm.accentSheen(brand.a, onAccent);

  return AppTokens(
    bg: Color(tone.bg), appBg: Color(tone.appBg),
    surface: Color(tone.surface), surface2: Color(tone.surface2),
    ink: Color(tone.ink), ink2: Color(tone.ink2),
    muted: Color(tone.muted), faint: Color(tone.faint),
    line: Color(tone.line), lineSoft: Color(tone.lineSoft),

    primary: Color(brand.p), primaryDeep: Color(brand.pd),
    primarySoft: Color(brand.ps), primaryTint: Color(brand.pt),

    accent: Color(brand.a), accentDeep: Color(brand.ad), accentSoft: Color(brand.as_),
    accentGrad: linearGradient(Color(sheen), Color(brand.a)),

    onPrimary: Color(onPrimary), onAccent: Color(onAccent),
    primaryInk: Color(primaryInk), accentInk: Color(accentInk),

    income: Color(incomeBase), incomeSoft: incomeSoft,
    incomeLine: incomeLine, incomeInk: Color(incomeInk),

    okSoft: Color(okSoftBase), okInk: Color(okInk),
    warnSoft: Color(warnSoftBase), warnInk: Color(warnInkBase),
    dnBg: Color(dnBgBase), dnInk: Color(dnInk),

    heroGrad0: Color(hero0), heroGrad1: Color(hero1),
    heroDarkGrad0: Color(brand.heroDark0), heroDarkGrad1: Color(brand.heroDark1),
    frame: Color(brand.frame),

    chartTrack: chartTrack, barFill: barFill, dash: dash,

    glowPrimary: Color.fromRGBO(
      (brand.p >> 16) & 0xFF, (brand.p >> 8) & 0xFF, brand.p & 0xFF, glowAlpha),
    glowAccent: Color.fromRGBO(
      (brand.a >> 16) & 0xFF, (brand.a >> 8) & 0xFF, brand.a & 0xFF, glowAlpha),
    shadowPrimary: Color.fromRGBO(
      (brand.p >> 16) & 0xFF, (brand.p >> 8) & 0xFF, brand.p & 0xFF, shadowAlpha),
    shadowAccent: Color.fromRGBO(
      (brand.a >> 16) & 0xFF, (brand.a >> 8) & 0xFF, brand.a & 0xFF, shadowAlpha),
    toastBg: Color(isDark ? 0xFFE4EBE6 : 0xFF2E3B36),
    shadow1: Color.fromRGBO(0, 0, 0, isDark ? 0.20 : 0.06),
    shadow2: Color.fromRGBO(0, 0, 0, isDark ? 0.28 : 0.10),
    shadow3: Color.fromRGBO(0, 0, 0, isDark ? 0.36 : 0.14),
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
      contentTextStyle: TextStyle(color: brightness == Brightness.dark ? tokens.appBg : tokens.surface),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      bodyLarge: TextStyle(color: tokens.ink, fontSize: 16),
      bodyMedium: TextStyle(color: tokens.ink, fontSize: 14),
      bodySmall: TextStyle(color: tokens.ink2, fontSize: 12),
      titleLarge: TextStyle(color: tokens.ink, fontSize: 22, fontWeight: FontWeight.w600),
      titleMedium: TextStyle(color: tokens.ink, fontSize: 16, fontWeight: FontWeight.w600),
      titleSmall: TextStyle(color: tokens.ink, fontSize: 14, fontWeight: FontWeight.w600),
      labelLarge: TextStyle(color: tokens.ink, fontSize: 14, fontWeight: FontWeight.w500),
      labelMedium: TextStyle(color: tokens.ink2, fontSize: 12),
      labelSmall: TextStyle(color: tokens.muted, fontSize: 11),
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
  );
}

// ─── Cache: 20 entries (10 themes × 2 brightness) ────────────────────────────

final Map<String, (AppTokens, ThemeData)> _cache = {};

/// Get cached tokens + ThemeData for a theme × brightness. Builds once.
(AppTokens, ThemeData) themeDataFor(ThemeId id, Brightness brightness) {
  final key = '${id.id}_${brightness.name}';
  return _cache.putIfAbsent(key, () {
    final spec = themeSpecOf(id);
    final tokens = resolveTokens(spec, brightness);
    final data = buildThemeData(tokens, brightness);
    return (tokens, data);
  });
}
