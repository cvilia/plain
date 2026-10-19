/// 金额符号与负号的相对位置契约。
///
/// 产品口径：**负号写在货币符号之后**（`¥-1,786.00`），不是 `-¥1,786.00`。
/// 纯数字（无符号）仍是前置 `-`，两套口径别混。
///
/// 背景：负余额 / 净值为负时，`AmountDisplay` 以前会把负号整个丢掉
/// （`formatAmountParts` 只取绝对值，sign 只看 isExpense/isIncome 标志），
/// 于是「当前净值 -1786」被渲染成 `¥1,786.00`。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plain/app/theme/theme_registry.dart';
import 'package:plain/app/theme/theme_resolver.dart';
import 'package:plain/core/format/amount_formatter.dart';
import 'package:plain/design_system/amount_display.dart';

ThemeData _theme() => buildThemeData(
      resolveTokens(themeSpecOf(ThemeId.subai), Brightness.light),
      Brightness.light,
    );

void main() {
  group('formatter', () {
    test('负数：符号在前，负号紧跟符号', () {
      expect(formatAmountYuan(-178600), '¥-1,786.00');
      expect(formatAmountYuan(178600), '¥1,786.00');
      expect(formatAmountYuan(0), '¥0.00');
    });

    test('外币同样把负号放在符号之后', () {
      expect(formatAmountCurrency(-1250, currencyCode: 'USD'), '\$-12.50');
      expect(formatAmountCurrency(1250, currencyCode: 'USD'), '\$12.50');
    });

    test('无符号的纯数字仍是前置负号', () {
      expect(formatAmount(-1250), '-12.50');
    });

    test('隐藏金额不受影响', () {
      expect(formatAmountYuan(-178600, hide: true), '¥****');
      expect(formatAmountCurrency(-1250, currencyCode: 'USD', hide: true),
          '\$****');
    });
  });

  group('AmountDisplay', () {
    Future<String> render(WidgetTester tester, int cents) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: _theme(),
            home: Scaffold(body: AmountDisplay(cents: cents, fontSize: 34)),
          ),
        ),
      );
      await tester.pump();
      return tester.widget<RichText>(find.byType(RichText)).text.toPlainText();
    }

    testWidgets('负余额渲染出负号，且落在货币符号之后', (tester) async {
      expect(await render(tester, -178600), '¥-1,786.00');
    });

    testWidgets('正数不带负号', (tester) async {
      expect(await render(tester, 178600), '¥1,786.00');
    });

    testWidgets('方向性符号也排在货币符号之后（支出 / 收入）', (tester) async {
      Future<String> render(AmountDisplay w) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: _theme(),
              home: Scaffold(body: w),
            ),
          ),
        );
        await tester.pump();
        return tester
            .widget<RichText>(find.byType(RichText))
            .text
            .toPlainText();
      }

      expect(
        await render(const AmountDisplay(
            cents: 1250, fontSize: 15, showSign: true, isExpense: true)),
        '¥-12.50',
      );
      expect(
        await render(const AmountDisplay(
            cents: 0, fontSize: 15, showSign: true, isIncome: true)),
        '¥+0.00',
        reason: '收入 0 元也保留 + 号',
      );
    });

    testWidgets('showValueSign：结余正数带 +，负数带 -', (tester) async {
      Future<String> render(int cents) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: _theme(),
              home: Scaffold(
                body: AmountDisplay(
                  cents: cents,
                  fontSize: 34,
                  showValueSign: true,
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        return tester
            .widget<RichText>(find.byType(RichText))
            .text
            .toPlainText();
      }

      expect(await render(384200), '¥+3,842.00');
      expect(await render(-384200), '¥-3,842.00');
    });
  });
}
