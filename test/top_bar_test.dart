/// PlainTopBar 防退化：长标题 + 宽文字动作不得重叠。
///
/// 历史坑：动作宽度按 64 估、且只认裸 `Text`（对账页是
/// `SizedBox > Center > Padding > Text`），估窄 → 误判可居中 →
/// Stack 居中标题压在「已对账至 10-19」状态文本上。
/// 现在动作递归解包 + TextPainter 实测；标题放不下就退回非居中布局。
///
/// 取文案用 kDefaultAppStrings（测试约定）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plain/app/l10n/strings_accounts.dart';
import 'package:plain/app/l10n/strings_core.dart';
import 'package:plain/app/theme/theme_registry.dart';
import 'package:plain/app/theme/theme_resolver.dart';
import 'package:plain/design_system/plain_ui.dart';

ThemeData _theme() => buildThemeData(
      resolveTokens(themeSpecOf(ThemeId.subai), Brightness.light),
      Brightness.light,
    );

Future<(Rect, Rect)> pumpBar(
    WidgetTester tester, String title, String action) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: _theme(),
      home: Scaffold(
        appBar: PlainTopBar(
          title: title,
          showBack: true,
          actions: [
            // 与 reconcile_mode_page 同构：SizedBox > Center > Padding > Text
            SizedBox(
              height: 44,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Text(action,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500)),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final titleRect = tester.getRect(find.text(title));
  final actionRect = tester.getRect(find.text(action));
  return (titleRect, actionRect);
}

void _phone(WidgetTester tester) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(393, 852);
  tester.view.padding = const FakeViewPadding(top: 47);
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('长标题 + 宽状态文本：两段文字水平不相交', (tester) async {
    _phone(tester);
    final s = kDefaultAppStrings;
    // 对账页的真实组合：账号名较长 + 状态文本「已对账至 10-19」
    final (t, a) = await pumpBar(
        tester, s.reconcileWithName('现金每月工资'), s.reconciledUpTo('10-19'));
    final overlap = t.left < a.right && a.left < t.right;
    expect(overlap, isFalse,
        reason: '标题(${t.left}-${t.right}) 与状态文本(${a.left}-${a.right}) 重叠');
  });

  testWidgets('短标题 + 文字动作：仍可居中且不相交', (tester) async {
    _phone(tester);
    final s = kDefaultAppStrings;
    final (t, a) = await pumpBar(tester, '设置', s.reconciledUpTo('10-19'));
    final overlap = t.left < a.right && a.left < t.right;
    expect(overlap, isFalse);
  });
}
