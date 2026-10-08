/// CI contrast gate: validates **rendered** values (soft layers composited),
/// not declared swatches. Run: dart run tool/theme_contrast_check.dart
/// Failure count must be 0 (AC5 / INV-2).
library;

import 'dart:io';

import 'package:plain/app/theme/color_math.dart';
import 'package:plain/app/theme/theme_registry.dart';

void main() {
  var pass = 0;
  var fail = 0;
  final failures = <String>[];

  void check(String name, int fg, int bg, double target) {
    final ratio = contrast(fg, bg);
    if (ratio >= target) {
      pass++;
    } else {
      fail++;
      failures.add('FAIL $name: ${ratio.toStringAsFixed(2)}:1 < $target (fg=${hexString(fg)} bg=${hexString(bg)})');
    }
  }

  for (final themeId in ThemeId.values) {
    for (final isDark in [false, true]) {
      final spec = themeSpecOf(themeId);
      final tone = toneOf(spec.tone, isDark);
      final brand = isDark ? spec.dark : spec.light;
      final tag = '${themeId.name}/${isDark ? "dark" : "light"}';

      final bg = tone.bg;
      final surface = tone.surface;
      final surface2 = tone.surface2;
      final appBg = tone.appBg;

      final softA = isDark ? kSoftAlphaDark : kSoftAlphaLight;
      final tintA = isDark ? kTintAlphaDark : kTintAlphaLight;
      final aSoftA = isDark ? kASoftAlphaDark : kASoftAlphaLight;

      // Rendered soft-layer hosts (B-scheme: alpha composited at paint time).
      final hosts = <int>[surface, surface2, bg, appBg];
      final pSoft = <int>[for (final h in hosts) composite(brand.p, softA, h)];
      final pTint = <int>[for (final h in hosts) composite(brand.p, tintA, h)];
      final aSoft = <int>[for (final h in hosts) composite(brand.a, aSoftA, h)];

      // Neutral: ink / ink2 / muted on bg & surface
      check('$tag ink×bg', tone.ink, bg, 4.5);
      check('$tag ink×surface', tone.ink, surface, 4.5);
      check('$tag ink2×bg', tone.ink2, bg, 4.5);
      check('$tag ink2×surface', tone.ink2, surface, 4.5);
      check('$tag muted×bg', tone.muted, bg, 4.5);
      check('$tag muted×surface', tone.muted, surface, 4.5);

      // Primary ink must clear 4.5 on every soft/tint host and naked bases.
      final primaryInk = inkForLayers(
        brand.p,
        <int>[...pSoft, ...pTint, surface, bg],
        4.5,
      );
      for (var i = 0; i < hosts.length; i++) {
        check('$tag primaryInk×pSoft@${hexString(hosts[i])}', primaryInk, pSoft[i], 4.5);
        check('$tag primaryInk×pTint@${hexString(hosts[i])}', primaryInk, pTint[i], 4.5);
      }
      check('$tag primaryInk×bg', primaryInk, bg, 4.5);
      check('$tag primaryInk×surface', primaryInk, surface, 4.5);

      // Accent ink on every accent-soft host and naked bases.
      final accentInk = inkForLayers(
        brand.a,
        <int>[...aSoft, surface, bg],
        4.5,
      );
      for (var i = 0; i < hosts.length; i++) {
        check('$tag accentInk×aSoft@${hexString(hosts[i])}', accentInk, aSoft[i], 4.5);
      }
      check('$tag accentInk×bg', accentInk, bg, 4.5);
      check('$tag accentInk×surface', accentInk, surface, 4.5);

      // Income on surface (for amounts)
      final income = semColor('income', isDark);
      check('$tag income×surface', income, surface, 4.5);

      // on-primary / on-accent for solid buttons
      final onPrimary = pickOn(brand.p, tone.ink, 4.5);
      check('$tag onPrimary×primary', onPrimary, brand.p, 4.5);
      final onAccent = pickOn(brand.a, tone.ink, 4.5);
      check('$tag onAccent×accent', onAccent, brand.a, 4.5);

      // Accent gradient endpoints (sheen → accent), both vs onAccent
      final sheen = accentSheen(brand.a, onAccent);
      check('$tag sheen×onAccent', onAccent, sheen, 4.5);
      check('$tag accent×onAccent', onAccent, brand.a, 4.5);

      // Hero gradient × white text (target 4.6). heroDark included (was blind).
      final hero0 = heroSafe(brand.hero0);
      final hero1 = heroSafe(brand.hero1);
      final heroDark0 = heroSafe(brand.heroDark0);
      final heroDark1 = heroSafe(brand.heroDark1);
      check('$tag hero0×white', 0xFFFFFFFF, hero0, 4.6);
      check('$tag hero1×white', 0xFFFFFFFF, hero1, 4.6);
      check('$tag heroDark0×white', 0xFFFFFFFF, heroDark0, 4.6);
      check('$tag heroDark1×white', 0xFFFFFFFF, heroDark1, 4.6);

      // Status colors on soft backgrounds + naked page bases
      final okSoft = semColor('okSoft', isDark);
      final okBase = semColor('okBase', isDark);
      final okInk = inkForLayers(okBase, <int>[okSoft, surface, bg, appBg], 4.5);
      check('$tag okInk×okSoft', okInk, okSoft, 4.5);
      check('$tag okInk×surface', okInk, surface, 4.5);

      final warnSoft = semColor('warnSoft', isDark);
      final warnInk = semColor('warnInk', isDark);
      check('$tag warnInk×warnSoft', warnInk, warnSoft, 4.5);

      final dnBg = semColor('dnBg', isDark);
      final dnBase = semColor('dnBase', isDark);
      final dnInk = inkForLayers(dnBase, <int>[dnBg, surface, bg, appBg], 4.5);
      check('$tag dnInk×dnBg', dnInk, dnBg, 4.5);
      check('$tag dnInk×surface', dnInk, surface, 4.5);

      // Income ink on incomeSoft + naked bases
      final incomeSoft = semColor('incomeSoft', isDark);
      final incomeInk =
          inkForLayers(income, <int>[incomeSoft, surface, bg, appBg], 4.5);
      check('$tag incomeInk×incomeSoft', incomeInk, incomeSoft, 4.5);
      check('$tag incomeInk×surface', incomeInk, surface, 4.5);

      // AppBg text
      check('$tag ink×appBg', tone.ink, appBg, 4.5);
      check('$tag ink2×appBg', tone.ink2, appBg, 4.5);
      check('$tag muted×appBg', tone.muted, appBg, 4.5);
    }
  }

  // ── INV-1: categoryColorMap invariant across themes (spot-check)
  final catColors = categoryColorMap.values.toSet();
  if (catColors.length != 12) {
    stderr.writeln('INV-1 violated: categoryColorMap must have exactly 12 unique colors, got ${catColors.length}');
    exit(1);
  }

  stdout.writeln('=== Theme Contrast Check ===');
  stdout.writeln('Passed: $pass / ${pass + fail}');
  if (fail > 0) {
    stdout.writeln('FAILED: $fail');
    for (final f in failures) {
      stdout.writeln(f);
    }
    exit(1);
  }
  stdout.writeln('All $pass checks passed ✓');
}
