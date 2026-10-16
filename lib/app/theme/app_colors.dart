/// AppColors ThemeExtension — single source of truth for brand/semantic colors.
///
/// Replaces the old `BrandColors` static facade over a mutable module global.
/// Values live on `ThemeData.extensions`, so Flutter rebuilds dependents when
/// the theme changes — no `watchBrandTheme` convention required.
///
/// Access via `context.colors` (see [AppColorsX]).
library;

import 'package:flutter/material.dart';
import 'package:plain/app/theme/tokens.dart';

@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    // ── existing 26 (semantics locked — do not change) ──
    required this.primary,
    required this.primaryLight,
    required this.primaryDark,
    required this.onPrimary,
    required this.accent,
    required this.expense,
    required this.income,
    required this.transfer,
    required this.ink,
    required this.inkSecondary,
    required this.inkTertiary,
    required this.inkFaint,
    required this.surface,
    required this.surfaceCard,
    required this.surfaceMuted,
    required this.border,
    required this.divider,
    required this.heroStart,
    required this.heroEnd,
    required this.heroDarkStart,
    required this.heroDarkEnd,
    required this.barFill,
    required this.chartTrack,
    required this.dash,
    required this.fabBg,
    required this.fabFg,
    // ── v3 bridge: 38 additional AppTokens fields ──
    required this.lineStrong,
    required this.lineStrongSoft,
    required this.focusRing,
    required this.surfaceInset,
    required this.disabledFg,
    required this.disabledBg,
    required this.overlay,
    required this.skeleton,
    required this.primaryPressed,
    required this.accentPressed,
    required this.frame,
    required this.fabIc,
    required this.toastBg,
    required this.primaryTint,
    required this.primaryInk,
    required this.onAccent,
    required this.accentSoft,
    required this.accentDeep,
    required this.accentInk,
    required this.incomeSoft,
    required this.incomeLine,
    required this.incomeInk,
    required this.okSoft,
    required this.okInk,
    required this.warnSoft,
    required this.warnInk,
    required this.dnBg,
    required this.shadow1,
    required this.shadow2,
    required this.shadow3,
    required this.shadowAccent,
    required this.shadowPrimary,
    required this.glowPrimary,
    required this.glowAccent,
    required this.heroCard0,
    required this.heroCard1,
    required this.accentGrad,
  });

  /// Build from the resolved token set for a ThemeSpec × Brightness.
  factory AppColors.fromTokens(AppTokens t) => AppColors(
        primary: t.primary,
        primaryLight: t.primarySoft,
        primaryDark: t.primaryDeep,
        onPrimary: t.onPrimary,
        accent: t.accent,
        // Semantic note: token `income` is the expense/red semantic and
        // `dnInk` is the income/green semantic (historical naming flip).
        expense: t.income,
        income: t.dnInk,
        transfer: t.primary,
        ink: t.ink,
        inkSecondary: t.ink2,
        inkTertiary: t.muted,
        inkFaint: t.faint,
        surface: t.appBg,
        surfaceCard: t.surface,
        surfaceMuted: t.surface2,
        border: t.line,
        divider: t.lineSoft,
        heroStart: t.heroGrad0,
        heroEnd: t.heroGrad1,
        heroDarkStart: t.heroDarkGrad0,
        heroDarkEnd: t.heroDarkGrad1,
        barFill: t.barFill,
        chartTrack: t.chartTrack,
        dash: t.dash,
        fabBg: t.fabBg,
        fabFg: t.fabFg,
        // ── v3 bridge ──
        lineStrong: t.lineStrong,
        lineStrongSoft: t.lineStrongSoft,
        focusRing: t.focusRing,
        surfaceInset: t.surfaceInset,
        disabledFg: t.disabledFg,
        disabledBg: t.disabledBg,
        overlay: t.overlay,
        skeleton: t.skeleton,
        primaryPressed: t.primaryPressed,
        accentPressed: t.accentPressed,
        frame: t.frame,
        // fabIc 恒等于 onAccent（设计 gen_tokens.py 的 FAB 段直接复用，不是算的）。
        fabIc: t.fabIc,
        toastBg: t.toastBg,
        primaryTint: t.primaryTint,
        primaryInk: t.primaryInk,
        onAccent: t.onAccent,
        accentSoft: t.accentSoft,
        accentDeep: t.accentDeep,
        accentInk: t.accentInk,
        incomeSoft: t.incomeSoft,
        incomeLine: t.incomeLine,
        incomeInk: t.incomeInk,
        okSoft: t.okSoft,
        okInk: t.okInk,
        warnSoft: t.warnSoft,
        warnInk: t.warnInk,
        dnBg: t.dnBg,
        shadow1: t.shadow1,
        shadow2: t.shadow2,
        shadow3: t.shadow3,
        shadowAccent: t.shadowAccent,
        shadowPrimary: t.shadowPrimary,
        glowPrimary: t.glowPrimary,
        glowAccent: t.glowAccent,
        heroCard0: t.heroCard0,
        heroCard1: t.heroCard1,
        accentGrad: t.accentGrad,
      );

  // ── existing 26 ──
  final Color primary;
  final Color primaryLight;
  final Color primaryDark;
  final Color onPrimary;
  final Color accent;
  final Color expense;
  final Color income;
  final Color transfer;
  final Color ink;
  final Color inkSecondary;
  final Color inkTertiary;
  final Color inkFaint;
  final Color surface;
  final Color surfaceCard;
  final Color surfaceMuted;
  final Color border;
  final Color divider;
  final Color heroStart;
  final Color heroEnd;
  final Color heroDarkStart;
  final Color heroDarkEnd;
  final Color barFill;
  final Color chartTrack;
  final Color dash;
  final Color fabBg;
  final Color fabFg;

  // ── v3 bridge ──
  final Color lineStrong;
  final Color lineStrongSoft;
  final Color focusRing;
  final Color surfaceInset;
  final Color disabledFg;
  final Color disabledBg;
  final Color overlay;
  final Color skeleton;
  final Color primaryPressed;
  final Color accentPressed;
  final Color frame;
  final Color fabIc;
  final Color toastBg;
  final Color primaryTint;
  final Color primaryInk;
  final Color onAccent;
  final Color accentSoft;
  final Color accentDeep;
  final Color accentInk;
  final Color incomeSoft;
  final Color incomeLine;
  final Color incomeInk;
  final Color okSoft;
  final Color okInk;
  final Color warnSoft;
  final Color warnInk;
  final Color dnBg;
  final Color shadow1;
  final Color shadow2;
  final Color shadow3;
  final Color shadowAccent;
  final Color shadowPrimary;
  final Color glowPrimary;
  final Color glowAccent;
  final Color heroCard0;
  final Color heroCard1;
  final Gradient accentGrad;

  @override
  AppColors copyWith({
    Color? primary,
    Color? primaryLight,
    Color? primaryDark,
    Color? onPrimary,
    Color? accent,
    Color? expense,
    Color? income,
    Color? transfer,
    Color? ink,
    Color? inkSecondary,
    Color? inkTertiary,
    Color? inkFaint,
    Color? surface,
    Color? surfaceCard,
    Color? surfaceMuted,
    Color? border,
    Color? divider,
    Color? heroStart,
    Color? heroEnd,
    Color? heroDarkStart,
    Color? heroDarkEnd,
    Color? barFill,
    Color? chartTrack,
    Color? dash,
    Color? fabBg,
    Color? fabFg,
    Color? lineStrong,
    Color? lineStrongSoft,
    Color? focusRing,
    Color? surfaceInset,
    Color? disabledFg,
    Color? disabledBg,
    Color? overlay,
    Color? skeleton,
    Color? primaryPressed,
    Color? accentPressed,
    Color? frame,
    Color? fabIc,
    Color? toastBg,
    Color? primaryTint,
    Color? primaryInk,
    Color? onAccent,
    Color? accentSoft,
    Color? accentDeep,
    Color? accentInk,
    Color? incomeSoft,
    Color? incomeLine,
    Color? incomeInk,
    Color? okSoft,
    Color? okInk,
    Color? warnSoft,
    Color? warnInk,
    Color? dnBg,
    Color? shadow1,
    Color? shadow2,
    Color? shadow3,
    Color? shadowAccent,
    Color? shadowPrimary,
    Color? glowPrimary,
    Color? glowAccent,
    Color? heroCard0,
    Color? heroCard1,
    Gradient? accentGrad,
  }) {
    return AppColors(
      primary: primary ?? this.primary,
      primaryLight: primaryLight ?? this.primaryLight,
      primaryDark: primaryDark ?? this.primaryDark,
      onPrimary: onPrimary ?? this.onPrimary,
      accent: accent ?? this.accent,
      expense: expense ?? this.expense,
      income: income ?? this.income,
      transfer: transfer ?? this.transfer,
      ink: ink ?? this.ink,
      inkSecondary: inkSecondary ?? this.inkSecondary,
      inkTertiary: inkTertiary ?? this.inkTertiary,
      inkFaint: inkFaint ?? this.inkFaint,
      surface: surface ?? this.surface,
      surfaceCard: surfaceCard ?? this.surfaceCard,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      border: border ?? this.border,
      divider: divider ?? this.divider,
      heroStart: heroStart ?? this.heroStart,
      heroEnd: heroEnd ?? this.heroEnd,
      heroDarkStart: heroDarkStart ?? this.heroDarkStart,
      heroDarkEnd: heroDarkEnd ?? this.heroDarkEnd,
      barFill: barFill ?? this.barFill,
      chartTrack: chartTrack ?? this.chartTrack,
      dash: dash ?? this.dash,
      fabBg: fabBg ?? this.fabBg,
      fabFg: fabFg ?? this.fabFg,
      lineStrong: lineStrong ?? this.lineStrong,
      lineStrongSoft: lineStrongSoft ?? this.lineStrongSoft,
      focusRing: focusRing ?? this.focusRing,
      surfaceInset: surfaceInset ?? this.surfaceInset,
      disabledFg: disabledFg ?? this.disabledFg,
      disabledBg: disabledBg ?? this.disabledBg,
      overlay: overlay ?? this.overlay,
      skeleton: skeleton ?? this.skeleton,
      primaryPressed: primaryPressed ?? this.primaryPressed,
      accentPressed: accentPressed ?? this.accentPressed,
      frame: frame ?? this.frame,
      fabIc: fabIc ?? this.fabIc,
      toastBg: toastBg ?? this.toastBg,
      primaryTint: primaryTint ?? this.primaryTint,
      primaryInk: primaryInk ?? this.primaryInk,
      onAccent: onAccent ?? this.onAccent,
      accentSoft: accentSoft ?? this.accentSoft,
      accentDeep: accentDeep ?? this.accentDeep,
      accentInk: accentInk ?? this.accentInk,
      incomeSoft: incomeSoft ?? this.incomeSoft,
      incomeLine: incomeLine ?? this.incomeLine,
      incomeInk: incomeInk ?? this.incomeInk,
      okSoft: okSoft ?? this.okSoft,
      okInk: okInk ?? this.okInk,
      warnSoft: warnSoft ?? this.warnSoft,
      warnInk: warnInk ?? this.warnInk,
      dnBg: dnBg ?? this.dnBg,
      shadow1: shadow1 ?? this.shadow1,
      shadow2: shadow2 ?? this.shadow2,
      shadow3: shadow3 ?? this.shadow3,
      shadowAccent: shadowAccent ?? this.shadowAccent,
      shadowPrimary: shadowPrimary ?? this.shadowPrimary,
      glowPrimary: glowPrimary ?? this.glowPrimary,
      glowAccent: glowAccent ?? this.glowAccent,
      heroCard0: heroCard0 ?? this.heroCard0,
      heroCard1: heroCard1 ?? this.heroCard1,
      accentGrad: accentGrad ?? this.accentGrad,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      primary: Color.lerp(primary, other.primary, t)!,
      primaryLight: Color.lerp(primaryLight, other.primaryLight, t)!,
      primaryDark: Color.lerp(primaryDark, other.primaryDark, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      expense: Color.lerp(expense, other.expense, t)!,
      income: Color.lerp(income, other.income, t)!,
      transfer: Color.lerp(transfer, other.transfer, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkSecondary: Color.lerp(inkSecondary, other.inkSecondary, t)!,
      inkTertiary: Color.lerp(inkTertiary, other.inkTertiary, t)!,
      inkFaint: Color.lerp(inkFaint, other.inkFaint, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceCard: Color.lerp(surfaceCard, other.surfaceCard, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      border: Color.lerp(border, other.border, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      heroStart: Color.lerp(heroStart, other.heroStart, t)!,
      heroEnd: Color.lerp(heroEnd, other.heroEnd, t)!,
      heroDarkStart: Color.lerp(heroDarkStart, other.heroDarkStart, t)!,
      heroDarkEnd: Color.lerp(heroDarkEnd, other.heroDarkEnd, t)!,
      barFill: Color.lerp(barFill, other.barFill, t)!,
      chartTrack: Color.lerp(chartTrack, other.chartTrack, t)!,
      dash: Color.lerp(dash, other.dash, t)!,
      fabBg: Color.lerp(fabBg, other.fabBg, t)!,
      fabFg: Color.lerp(fabFg, other.fabFg, t)!,
      lineStrong: Color.lerp(lineStrong, other.lineStrong, t)!,
      lineStrongSoft: Color.lerp(lineStrongSoft, other.lineStrongSoft, t)!,
      focusRing: Color.lerp(focusRing, other.focusRing, t)!,
      surfaceInset: Color.lerp(surfaceInset, other.surfaceInset, t)!,
      disabledFg: Color.lerp(disabledFg, other.disabledFg, t)!,
      disabledBg: Color.lerp(disabledBg, other.disabledBg, t)!,
      overlay: Color.lerp(overlay, other.overlay, t)!,
      skeleton: Color.lerp(skeleton, other.skeleton, t)!,
      primaryPressed: Color.lerp(primaryPressed, other.primaryPressed, t)!,
      accentPressed: Color.lerp(accentPressed, other.accentPressed, t)!,
      frame: Color.lerp(frame, other.frame, t)!,
      fabIc: Color.lerp(fabIc, other.fabIc, t)!,
      toastBg: Color.lerp(toastBg, other.toastBg, t)!,
      primaryTint: Color.lerp(primaryTint, other.primaryTint, t)!,
      primaryInk: Color.lerp(primaryInk, other.primaryInk, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      accentDeep: Color.lerp(accentDeep, other.accentDeep, t)!,
      accentInk: Color.lerp(accentInk, other.accentInk, t)!,
      incomeSoft: Color.lerp(incomeSoft, other.incomeSoft, t)!,
      incomeLine: Color.lerp(incomeLine, other.incomeLine, t)!,
      incomeInk: Color.lerp(incomeInk, other.incomeInk, t)!,
      okSoft: Color.lerp(okSoft, other.okSoft, t)!,
      okInk: Color.lerp(okInk, other.okInk, t)!,
      warnSoft: Color.lerp(warnSoft, other.warnSoft, t)!,
      warnInk: Color.lerp(warnInk, other.warnInk, t)!,
      dnBg: Color.lerp(dnBg, other.dnBg, t)!,
      shadow1: Color.lerp(shadow1, other.shadow1, t)!,
      shadow2: Color.lerp(shadow2, other.shadow2, t)!,
      shadow3: Color.lerp(shadow3, other.shadow3, t)!,
      shadowAccent: Color.lerp(shadowAccent, other.shadowAccent, t)!,
      shadowPrimary: Color.lerp(shadowPrimary, other.shadowPrimary, t)!,
      glowPrimary: Color.lerp(glowPrimary, other.glowPrimary, t)!,
      glowAccent: Color.lerp(glowAccent, other.glowAccent, t)!,
      heroCard0: Color.lerp(heroCard0, other.heroCard0, t)!,
      heroCard1: Color.lerp(heroCard1, other.heroCard1, t)!,
      // Gradient lerp: keep ours (cross-fade of gradients is not meaningful
      // for theme switching — both sides snap at the same frame).
      accentGrad: t < 0.5 ? accentGrad : other.accentGrad,
    );
  }
}

/// Ergonomic access: `context.colors.primary`.
extension AppColorsX on BuildContext {
  AppColors get colors {
    final c = Theme.of(this).extension<AppColors>();
    assert(c != null, 'AppColors ThemeExtension missing from ThemeData');
    return c!;
  }
}
