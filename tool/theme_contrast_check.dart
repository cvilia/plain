/// CI contrast gate: 10 themes × 2 brightness × 22 checks = 440.
/// Run: dart run tool/theme_contrast_check.dart
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
      final appBg = tone.appBg;

      // Neutral: ink / ink2 / muted on bg & surface
      check('$tag ink×bg', tone.ink, bg, 4.5);
      check('$tag ink×surface', tone.ink, surface, 4.5);
      check('$tag ink2×bg', tone.ink2, bg, 4.5);
      check('$tag ink2×surface', tone.ink2, surface, 4.5);
      check('$tag muted×bg', tone.muted, bg, 4.5);
      check('$tag muted×surface', tone.muted, surface, 4.5);

      // Primary/accact ink on tint backgrounds AND on bg/surface
      final primaryInk = inkFor(brand.p, brand.pt, 4.5);
      check('$tag primaryInk×pt', primaryInk, brand.pt, 4.5);
      check('$tag primaryInk×bg', primaryInk, bg, 4.5);
      check('$tag primaryInk×surface', primaryInk, surface, 4.5);
      final accentInk = inkFor(brand.a, brand.as_, 4.5);
      check('$tag accentInk×as', accentInk, brand.as_, 4.5);
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

      // Accent gradient endpoints
      final sheen = accentSheen(brand.a, onAccent);
      check('$tag sheen×onAccent', onAccent, sheen, 4.5);
      check('$tag accent×onAccent', onAccent, brand.a, 4.5);

      // Hero gradient × white text (target 4.6)
      final hero0 = heroSafe(brand.hero0);
      final hero1 = heroSafe(brand.hero1);
      check('$tag hero0×white', 0xFFFFFFFF, hero0, 4.6);
      check('$tag hero1×white', 0xFFFFFFFF, hero1, 4.6);

      // Status colors on soft backgrounds
      final okSoft = semColor('okSoft', isDark);
      final okBase = semColor('okBase', isDark);
      final okInk = inkFor(okBase, okSoft, 4.5);
      check('$tag okInk×okSoft', okInk, okSoft, 4.5);

      final warnSoft = semColor('warnSoft', isDark);
      final warnInk = semColor('warnInk', isDark);
      check('$tag warnInk×warnSoft', warnInk, warnSoft, 4.5);

      final dnBg = semColor('dnBg', isDark);
      final dnBase = semColor('dnBase', isDark);
      final dnInk = inkFor(dnBase, dnBg, 4.5);
      check('$tag dnInk×dnBg', dnInk, dnBg, 4.5);

      // AppBg text
      check('$tag ink×appBg', tone.ink, appBg, 4.5);
      check('$tag ink2×appBg', tone.ink2, appBg, 4.5);
      check('$tag muted×appBg', tone.muted, appBg, 4.5);
    }
  }

  // ── INV-1: CATCOL invariant across themes (spot-check)
  final catColors = CATCOL.values.toSet();
  assert(catColors.length == 12, 'CATCOL must have exactly 12 unique colors');

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
