import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plain/app/theme/theme_registry.dart';
import 'package:plain/app/theme/theme_resolver.dart';
import 'package:plain/app/theme/typography.dart';

void main() {
  test('全部 10 主题 × 亮暗 的 textTheme 都挂上 MiSans', () {
    for (final id in ThemeId.values) {
      for (final b in Brightness.values) {
        final (_, theme) = themeDataFor(id, b);
        for (final style in <TextStyle?>[
          theme.textTheme.bodyLarge, theme.textTheme.bodyMedium,
          theme.textTheme.bodySmall, theme.textTheme.titleLarge,
          theme.textTheme.titleMedium, theme.textTheme.titleSmall,
          theme.textTheme.labelLarge, theme.textTheme.labelMedium,
          theme.textTheme.labelSmall,
        ]) {
          expect(style?.fontFamily, kFontFamily,
              reason: '$id/$b 的 textTheme 有样式没挂 MiSans');
        }
      }
    }
  });

  test('金额类样式必须启用表格数字', () {
    for (final s in <TextStyle>[
      AppTextStyles.display, AppTextStyles.amountInput, AppTextStyles.amountHero,
      AppTextStyles.amountL, AppTextStyles.amountM, AppTextStyles.amountS,
    ]) {
      expect(s.fontFeatures, contains(const FontFeature.tabularFigures()),
          reason: '金额样式缺 tabularFigures，小数点会对不齐');
    }
  });

  test('回退链非空且首项不是 MiSans 自身', () {
    expect(kFontFallback, isNotEmpty);
    expect(kFontFallback, isNot(contains(kFontFamily)));
  });
}
