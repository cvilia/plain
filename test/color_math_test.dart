/// Color math unit tests. Verify WCAG functions + derivation rules.
import 'package:flutter_test/flutter_test.dart';
import 'package:plain/app/theme/color_math.dart';

void main() {
  group('hx / hexString', () {
    test('parses #RRGGBB', () {
      expect(hx('#FF0000'), 0xFFFF0000);
      expect(hx('#46746A'), 0xFF46746A);
    });
    test('parses without #', () {
      expect(hx('FFFFFF'), 0xFFFFFFFF);
    });
    test('parses 0x prefix', () {
      expect(hx('0xFF808080'), 0xFF808080);
    });
    test('hexString round-trips', () {
      expect(hexString(hx('#46746A')), '#46746A');
    });
  });

  group('lum', () {
    test('white luminance = 1.0', () {
      expect(lum(0xFFFFFFFF), closeTo(1.0, 0.001));
    });
    test('black luminance = 0.0', () {
      expect(lum(0xFF000000), closeTo(0.0, 0.001));
    });
  });

  group('contrast', () {
    test('white/black = 21:1', () {
      expect(contrast(0xFFFFFFFF, 0xFF000000), closeTo(21.0, 0.01));
    });
    test('same color = 1:1', () {
      expect(contrast(0xFF808080, 0xFF808080), closeTo(1.0, 0.001));
    });
    test('symmetric', () {
      expect(contrast(0xFF123456, 0xFFABCDEF), contrast(0xFFABCDEF, 0xFF123456));
    });
  });

  group('mix', () {
    test('t=0 returns a', () {
      expect(mix(0xFFFF0000, 0xFF00FF00, 0.0), 0xFFFF0000);
    });
    test('t=1 returns b', () {
      expect(mix(0xFFFF0000, 0xFF00FF00, 1.0), 0xFF00FF00);
    });
    test('t=0.5 midpoint', () {
      final c = mix(0xFF000000, 0xFFFFFFFF, 0.5);
      expect((c >> 16) & 0xFF, 128);
    });
  });

  group('inkFor', () {
    test('returns fg when already sufficient contrast', () {
      final fg = 0xFF000000;
      final bg = 0xFFFFFFFF;
      expect(inkFor(fg, bg, 4.5), fg);
    });
    test('darkens fg on light bg when insufficient', () {
      final fg = 0xFFB0B0B0;
      final bg = 0xFFFFFFFF;
      final result = inkFor(fg, bg, 4.5);
      expect(contrast(result, bg) >= 4.5, true);
    });
    test('lightens fg on dark bg when insufficient', () {
      final fg = 0xFF808080;
      final bg = 0xFF111111;
      final result = inkFor(fg, bg, 4.5);
      expect(contrast(result, bg) >= 4.5, true);
    });
  });

  group('pickOn', () {
    test('returns deep when deep has enough contrast', () {
      final deep = 0xFF000000;
      final bg = 0xFF8FC3B7;
      expect(pickOn(bg, deep, 4.5), deep);
    });
    test('returns white when white has enough contrast', () {
      final deep = 0xFF46746A;
      final bg = 0xFF2C5D68;
      final result = pickOn(bg, deep, 4.5);
      expect(result, anyOf(0xFFFFFFFF, predicate((c) => contrast(c as int, bg) >= 4.5)));
    });
  });

  group('heroSafe', () {
    test('returns c unchanged when white text is sufficient', () {
      final c = 0xFF2C5D68;
      expect(heroSafe(c), c);
    });
    test('darkens when white text insufficient', () {
      final c = 0xFF8FC3B7;
      final result = heroSafe(c);
      expect(contrast(0xFFFFFFFF, result) >= 4.6, true);
    });
  });

  group('accentSheen', () {
    test('darkens accent when onAccent is white', () {
      final accent = 0xFFE97E4F;
      final sheen = accentSheen(accent, 0xFFFFFFFF);
      expect(lum(sheen) < lum(accent), true);
    });
    test('lightens accent when onAccent is dark', () {
      final accent = 0xFF46746A;
      final sheen = accentSheen(accent, 0xFF000000);
      expect(lum(sheen) > lum(accent), true);
    });
  });
}
