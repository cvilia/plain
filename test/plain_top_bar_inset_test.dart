/// PlainTopBar 的顶部安全区契约。
///
/// 背景：`Scaffold` 给 `appBar` 的是 **loose 约束** —— 高度完全由 appBar 自身决定
/// （`_ScaffoldLayout`：`appBarHeight = layoutChild(_ScaffoldSlot.appBar, ...).height`）。
/// 标准 `AppBar` 正是自己把 `MediaQuery.paddingOf(context).top` 加进高度的。
/// `PlainTopBar` 若不自算，这 56pt 的前 47pt 会压在系统状态栏下面。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plain/app/theme/theme_registry.dart';
import 'package:plain/app/theme/theme_resolver.dart';
import 'package:plain/design_system/plain_ui.dart';

const double _kStatusBar = 47;

ThemeData _theme() => buildThemeData(
  resolveTokens(themeSpecOf(ThemeId.subai), Brightness.light),
  Brightness.light,
);

void _phone(WidgetTester tester) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(393, 852);
  tester.view.padding = const FakeViewPadding(top: _kStatusBar);
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('作为 Scaffold.appBar：自身高度含状态栏，标题不被遮', (tester) async {
    _phone(tester);

    await tester.pumpWidget(
      MaterialApp(
        theme: _theme(),
        home: Scaffold(
          appBar: PlainTopBar(title: '账单详情'),
          body: const SizedBox.expand(),
        ),
      ),
    );

    final bar = tester.getRect(find.byType(PlainTopBar));
    expect(bar.top, 0, reason: '顶栏从屏幕物理顶边开始');
    expect(bar.height, _kStatusBar + 56, reason: '状态栏 47 + 内容 56');

    final title = tester.getRect(find.text('账单详情'));
    expect(
      title.top,
      greaterThanOrEqualTo(_kStatusBar),
      reason: '标题必须完全落在系统状态栏之下',
    );
    expect(title.bottom, lessThanOrEqualTo(_kStatusBar + 56));
  });

  testWidgets('primary: false：不吃状态栏，供页内自管顶距', (tester) async {
    _phone(tester);

    await tester.pumpWidget(
      MaterialApp(
        theme: _theme(),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.only(top: _kStatusBar),
            child: SizedBox(
              height: 56,
              child: PlainTopBar(primary: false, title: '记一笔'),
            ),
          ),
        ),
      ),
    );

    final bar = tester.getRect(find.byType(PlainTopBar));
    expect(bar.height, 56, reason: '不自算状态栏，外层 Padding 已承担');
    expect(bar.top, _kStatusBar);
  });

  testWidgets('body 在顶栏之下开始，不被顶栏覆盖', (tester) async {
    _phone(tester);

    await tester.pumpWidget(
      MaterialApp(
        theme: _theme(),
        home: Scaffold(
          appBar: PlainTopBar(title: '标题'),
          body: const SizedBox.expand(key: ValueKey('body')),
        ),
      ),
    );

    final body = tester.getRect(find.byKey(const ValueKey('body')));
    expect(body.top, _kStatusBar + 56);
  });
}
