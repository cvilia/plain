/// Pure-Dart color math for theme derivation. No Flutter dependency (CI-friendly).
/// Implements WCAG 2.1 contrast + derivation rules from 需求变更.md §4.6.
library;

import 'dart:math' as math;

// ─── Core WCAG functions ─────────────────────────────────────────────────────

/// Parse hex color to ARGB int. Accepts `#RRGGBB`, `#AARRGGBB`, `RRGGBB`, `0xFFRRGGBB`.
int hx(String s) {
  var t = s.replaceFirst('#', '');
  if (t.startsWith('0x') || t.startsWith('0X')) t = t.substring(2);
  if (t.length == 6) t = 'FF$t';
  return int.parse(t, radix: 16);
}

/// Pack ARGB int to `#RRGGBB` string.
String hexString(int argb) {
  final v = argb.toRadixString(16).padLeft(8, '0').toUpperCase();
  return '#${v.substring(2)}';
}

/// RGBA constructor from components (0–255).
int rgba(int r, int g, int b, double a) {
  final aa = (a.clamp(0.0, 1.0) * 255).round();
  return (aa << 24) | (r << 16) | (g << 8) | b;
}

/// Relative luminance (WCAG 2.1). Input ARGB int, returns 0.0–1.0.
double lum(int argb) {
  final r = _srgbToLinear(((argb >> 16) & 0xFF) / 255.0);
  final g = _srgbToLinear(((argb >> 8) & 0xFF) / 255.0);
  final b = _srgbToLinear((argb & 0xFF) / 255.0);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

double _srgbToLinear(double c) =>
    c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

/// WCAG contrast ratio between two ARGB colors. Returns ≥ 1.0.
double contrast(int a, int b) {
  final la = lum(a);
  final lb = lum(b);
  final maxL = la > lb ? la : lb;
  final minL = la > lb ? lb : la;
  return (maxL + 0.05) / (minL + 0.05);
}

/// Linear interpolation in sRGB between two ARGB colors. t ∈ [0, 1].
int mix(int a, int b, double t) {
  final tt = t.clamp(0.0, 1.0);
  final r = (((a >> 16) & 0xFF) * (1 - tt) + ((b >> 16) & 0xFF) * tt).round();
  final g = (((a >> 8) & 0xFF) * (1 - tt) + ((b >> 8) & 0xFF) * tt).round();
  final bl = ((a & 0xFF) * (1 - tt) + (b & 0xFF) * tt).round();
  return 0xFF000000 | (r << 16) | (g << 8) | bl;
}

// ─── Derivation rules (§4.6) ─────────────────────────────────────────────────

const int _black = 0xFF000000;
const int _white = 0xFFFFFFFF;

/// ① inkFor: find a color near [fg] that contrasts ≥ [target] against [bg].
/// Direction is decided by comparing black vs white endpoints (NOT mid-gray probe).
int inkFor(int fg, int bg, double target) {
  if (contrast(fg, bg) >= target) return fg;
  final toBlack = contrast(_black, bg) > contrast(_white, bg);
  final endpoint = toBlack ? _black : _white;
  for (var t = 0.05; t <= 1.0; t += 0.05) {
    final c = mix(fg, endpoint, t);
    if (contrast(c, bg) >= target) return c;
  }
  return endpoint;
}

/// ② pickOn: foreground for solid [bg] blocks. Prefer [deep] (theme ink) → white → inkFor.
int pickOn(int bg, int deep, double target) {
  if (contrast(deep, bg) >= target) return deep;
  if (contrast(_white, bg) >= target) return _white;
  return inkFor(_white, bg, target);
}

/// ③ accentSheen: gradient endpoint. Sheen = mix(accent, opposite-of-onAccent, 0.12).
int accentSheen(int accent, int onAccent) {
  final toward = (onAccent == _white) ? _black : _white;
  return mix(accent, toward, 0.12);
}

/// ④ heroSafe: darken hero gradient endpoint so white text hits ≥ 4.6:1.
int heroSafe(int c) {
  const target = 4.6;
  if (contrast(_white, c) >= target) return c;
  for (var t = 0.05; t <= 1.0; t += 0.05) {
    final darkened = mix(c, _black, t);
    if (contrast(_white, darkened) >= target) return darkened;
  }
  return _black;
}

/// ⑤ chart-track: mix(surface2, p, 0.10 light / 0.18 dark)
int chartTrack(int surface2, int primary, bool isDark) =>
    mix(surface2, primary, isDark ? 0.18 : 0.10);

/// ⑥ bar-fill: mix(appBg, p, 0.36 light / 0.42 dark)
int barFill(int appBg, int primary, bool isDark) =>
    mix(appBg, primary, isDark ? 0.42 : 0.36);

/// ⑦ dash: mix(line, muted, 0.42)
int dashColor(int line, int muted) => mix(line, muted, 0.42);
