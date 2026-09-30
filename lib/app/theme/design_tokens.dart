/// Design tokens and theme. See 06-E1, 05-C2.
/// BrandColors now reads from the active theme tokens (dynamic).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plain/app/theme/theme_resolver.dart';
import 'package:plain/app/theme/theme_registry.dart';
import 'package:plain/app/theme/tokens.dart';

/// Current theme tokens — updated on every theme/mode change.
/// All [BrandColors] getters read from this, so existing UI follows the theme globally.
AppTokens? _activeTokens;

/// Must be called before first frame and on every theme/mode change.
void setActiveTheme(ThemeId id, Brightness brightness) {
  final (tokens, _) = themeDataFor(id, brightness);
  _activeTokens = tokens;
}

AppTokens get _t {
  // Fallback to qingci light if not yet initialized (e.g. hot restart).
  if (_activeTokens == null) {
    final (tokens, _) = themeDataFor(ThemeId.qingci, Brightness.light);
    _activeTokens = tokens;
  }
  return _activeTokens!;
}

class BrandColors {
  BrandColors._();

  // Primary
  static Color get primary => _t.primary;
  static Color get primaryLight => _t.primarySoft;
  static Color get primaryDark => _t.primaryDeep;
  static Color get onPrimary => _t.onPrimary;

  // Accent
  static Color get accent => _t.accent;

  // Semantic — old code: expense=red, income=green
  static Color get expense => _t.income;       // red-ish (income token is the red semantic)
  static Color get income => _t.dnInk;         // green-ish (dn token is the green semantic)
  static Color get transfer => _t.primary;

  // Neutrals (always use light-style naming; dark mode swaps via _activeTokens)
  static Color get ink => _t.ink;
  static Color get inkSecondary => _t.ink2;
  static Color get inkTertiary => _t.muted;
  static Color get surface => _t.appBg;
  static Color get surfaceCard => _t.surface;
  static Color get surfaceMuted => _t.surface2;
  static Color get border => _t.line;
  static Color get divider => _t.lineSoft;

  // Dark aliases (for code that explicitly picks dark values)
  static Color get darkInk => _t.ink;
  static Color get darkInkSecondary => _t.ink2;
  static Color get darkInkTertiary => _t.muted;
  static Color get darkSurface => _t.appBg;
  static Color get darkSurfaceCard => _t.surface;
  static Color get darkSurfaceMuted => _t.surface2;
  static Color get darkBorder => _t.line;
  static Color get darkDivider => _t.lineSoft;
}

class Spacing {
  Spacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

class Radii {
  Radii._();
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double pill = 999;
}

/// Theme mode option for settings UI (legacy enum kept for compatibility).
enum ThemeModeOption { system, light, dark }

ThemeModeOption _legacyMode = ThemeModeOption.system;

class ThemeModeNotifier extends Notifier<ThemeModeOption> {
  @override
  ThemeModeOption build() => _legacyMode;

  void set(ThemeModeOption option) {
    _legacyMode = option;
    state = option;
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeModeOption>(ThemeModeNotifier.new);

ThemeMode toFlutterThemeMode(ThemeModeOption option) {
  return switch (option) {
    ThemeModeOption.system => ThemeMode.system,
    ThemeModeOption.light => ThemeMode.light,
    ThemeModeOption.dark => ThemeMode.dark,
  };
}
