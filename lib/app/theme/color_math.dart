/// Pure-Dart color math for theme derivation. No Flutter dependency (CI-friendly).
/// Implements WCAG 2.1 contrast + derivation rules from 04-技术架构设计.md §16.1.
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

/// HSL → ARGB。[h] 0–360，[s]/[l] 0–1。
int hsl(double h, double s, double l) {
  final hh = h % 360;
  final c = (1 - (2 * l - 1).abs()) * s;
  final x = c * (1 - ((hh / 60) % 2 - 1).abs());
  final m = l - c / 2;
  final (double r, double g, double b) = switch (hh ~/ 60) {
    0 => (c, x, 0),
    1 => (x, c, 0),
    2 => (0, c, x),
    3 => (0, x, c),
    4 => (x, 0, c),
    _ => (c, 0, x),
  };
  int q(double v) => ((v + m) * 255).round().clamp(0, 255);
  return 0xFF000000 | (q(r) << 16) | (q(g) << 8) | q(b);
}

/// 取 [c] 的色相/饱和度，把亮度换到「相对亮度 ≈ [target]」的那一档。
///
/// 用途：暗色页面纸色。直接 `mix(appBg, 品牌色, α)` 会把纸色提亮 —— 品牌色在暗色档
/// 是一支亮色（`#79BFC8`），叠完页面比卡片还亮，层级直接反过来（实测 20 个组合里
/// 16 个倒挂）。而「先压暗 N% 再叠」又会把彩度压没（`#72313A` 压 55% 只剩近黑，
/// 纸色等于没染色，ΔE 0.78）。
///
/// 所以改成：色相/饱和度照抄品牌色（彩度保住），亮度通过搜索对齐到目标相对亮度
/// （层级顺序保住）。两步都能落到纸色上，只影响色温。
int atLuminance(int c, double target) {
  final r = ((c >> 16) & 0xFF) / 255.0;
  final g = ((c >> 8) & 0xFF) / 255.0;
  final b = (c & 0xFF) / 255.0;
  final maxC = math.max(r, math.max(g, b));
  final minC = math.min(r, math.min(g, b));
  final l = (maxC + minC) / 2;
  final d = maxC - minC;
  final s = d == 0 ? 0.0 : d / (1 - (2 * l - 1).abs());
  double h;
  if (d == 0) {
    h = 0;
  } else if (maxC == r) {
    h = ((g - b) / d) % 6;
  } else if (maxC == g) {
    h = (b - r) / d + 2;
  } else {
    h = (r - g) / d + 4;
  }
  h *= 60;

  var best = c;
  var bestDiff = double.infinity;
  for (var i = 0; i <= 100; i++) {
    final candidate = hsl(h, s, i / 100);
    final diff = (lum(candidate) - target).abs();
    if (diff < bestDiff) {
      bestDiff = diff;
      best = candidate;
    }
  }
  return best;
}

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

// ─── Layer compositing + multi-background ink (§4.1 / §4.6 ①′) ───────────────

/// Composite [fg] at [alpha] over [bg], returning an opaque result.
/// Linear interpolation in sRGB component space — bit-identical to browser
/// and Flutter source-over compositing. Do NOT switch to linear-light mixing:
/// the contrast gate must validate the color that actually renders.
int composite(int fg, double alpha, int bg) => mix(bg, fg, alpha);

/// ①′ inkForLayers: text color that hits [target] contrast against **every**
/// background in [backgrounds].
///
/// Direction is decided by black/white endpoints (same rule as [inkFor]),
/// never a mid-gray probe. Theme tint layers share a polarity, so pure black
/// or pure white always resolves — the function must not report "not found".
int inkForLayers(int fg, List<int> backgrounds, double target) {
  if (backgrounds.isEmpty) return fg;
  bool ok(int c) => backgrounds.every((bg) => contrast(c, bg) >= target);
  if (ok(fg)) return fg;

  // Hardest base for the original fg — used only to pick the push direction.
  final hardest = backgrounds.reduce(
      (a, b) => contrast(fg, a) < contrast(fg, b) ? a : b);
  final toBlack = contrast(_black, hardest) > contrast(_white, hardest);
  final primaryEnd = toBlack ? _black : _white;
  final fallbackEnd = toBlack ? _white : _black;

  for (final endpoint in [primaryEnd, fallbackEnd]) {
    for (var t = 0.05; t <= 1.0; t += 0.05) {
      final c = mix(fg, endpoint, t);
      if (ok(c)) return c;
    }
    if (ok(endpoint)) return endpoint;
  }
  // Same-polarity layers: the preferred endpoint always clears 4.58:1.
  return primaryEnd;
}
