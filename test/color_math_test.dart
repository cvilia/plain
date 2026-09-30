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

  group('composite', () {
    test('alpha=0 equals bg', () {
      final fg = 0xFFFF0000;
      final bg = 0xFF112233;
      expect(composite(fg, 0.0, bg), bg);
    });
    test('alpha=1 equals fg', () {
      final fg = 0xFFFF0000;
      final bg = 0xFF112233;
      expect(composite(fg, 1.0, bg), fg);
    });
    test('matches mix(bg, fg, alpha) bit-for-bit', () {
      final fg = 0xFF47B8A1;
      final bg = 0xFFFFFFFF;
      for (final a in [0.0, 0.1, 0.16, 0.26, 0.5, 0.8, 1.0]) {
        expect(composite(fg, a, bg), mix(bg, fg, a));
      }
    });
  });

  group('inkForLayers', () {
    test('hits target on all three distinct bases', () {
      final fg = 0xFF71AA46;
      final bases = <int>[0xFFFFFFFF, 0xFFF5F8F5, 0xFFE9EFEA];
      final result = inkForLayers(fg, bases, 4.5);
      for (final bg in bases) {
        expect(contrast(result, bg) >= 4.5, true,
            reason: 'contrast on ${hexString(bg)} = '
                '${contrast(result, bg).toStringAsFixed(2)}');
      }
    });

    test('card + page-base combo (regression: 19 misses)', () {
      // Light-mode trap: page bg darker than card → dark ink loses contrast.
      final fg = 0xFF47B8A1; // qingci light primary
      final surface = 0xFFFFFFFF;
      final pageBg = 0xFFE9EFEA;
      final softOnSurface = composite(fg, 0.16, surface);
      final softOnBg = composite(fg, 0.16, pageBg);
      final bases = <int>[softOnSurface, softOnBg, surface, pageBg];
      final result = inkForLayers(fg, bases, 4.5);
      for (final bg in bases) {
        expect(contrast(result, bg) >= 4.5, true,
            reason: 'miss on ${hexString(bg)} = '
                '${contrast(result, bg).toStringAsFixed(2)}');
      }
    });

    test('dark-mode high-alpha tint on bright base (regression)', () {
      final fg = 0xFF9FD0C6; // qingci dark primary
      final surface = 0xFF2B3733;
      final softOnSurface = composite(fg, 0.26, surface);
      final bases = <int>[softOnSurface, surface, 0xFF141A18];
      final result = inkForLayers(fg, bases, 4.5);
      for (final bg in bases) {
        expect(contrast(result, bg) >= 4.5, true);
      }
    });

    test('returns fg unchanged when already sufficient on every base', () {
      final fg = 0xFF000000;
      final bases = <int>[0xFFFFFFFF, 0xFFE9EFEA, 0xFFF5F8F5];
      expect(inkForLayers(fg, bases, 4.5), fg);
    });
  });
}
