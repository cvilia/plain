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
  });

  /// Build from the resolved 46-token set for a ThemeSpec × Brightness.
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
      );

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
