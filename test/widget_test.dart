/// Smoke tests: app shell actually builds and shows primary navigation.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plain/app/bootstrap.dart';
import 'package:plain/data/db/database.dart';
import 'package:plain/main.dart';

Widget _app({required bool onboarding}) {
  final db = AppDatabase.inMemory();
  final deps = buildDependencies(
    db: db,
    deviceId: 'test-device',
    bookId: 'test-book',
  );
  return ProviderScope(
    overrides: [appDependenciesProvider.overrideWithValue(deps)],
    child: PlainApp(
      showOnboarding: onboarding,
      appLockInitiallyEnabled: false,
    ),
  );
}

void main() {
  testWidgets('PlainApp smoke: phone shell + bottom nav render', (tester) async {
    // App 默认「跟随系统」；CI/开发机的系统 locale 可能是英文，
    // 冒烟断言的是中文 nav 文案，这里把测试 locale 钉到 zh-CN。
    // 注意必须改 locales 列表 —— MaterialApp 的 locale 解析读的是列表，
    // 只改 `localeTestValue` 单值不会参与解析。
    tester.platformDispatcher.localesTestValue = const [Locale('zh', 'CN')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    // Phone portrait so compact layout (Quiet Ledger bottom nav) is used.
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_app(onboarding: false));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Quiet Ledger nav: 流水 / 报表 / ＋ / 资产 / 我的
    expect(find.text('流水'), findsAtLeastNWidgets(1));
    expect(find.text('报表'), findsOneWidget);
    expect(find.text('资产'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);
    // topbar month title
    expect(find.textContaining('年'), findsAtLeastNWidgets(1));
  });

  testWidgets('PlainApp smoke: wide shell uses NavigationRail', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_app(onboarding: false));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(NavigationRail), findsOneWidget);
  });

  testWidgets('二级页不显示底部导航', (tester) async {
    // 四个主页面在 StatefulShellRoute 的 branch 里，branch 自带嵌套 Navigator。
    // 一旦有人把二级页的 `rootNavigator: true` 去掉，页面会盖在 body 上、
    // 底部导航条留在原地 —— 这条断言就是防这个回归。
    tester.platformDispatcher.localesTestValue = const [Locale('zh', 'CN')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_app(onboarding: false));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('资产'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('净值追踪'), findsOneWidget);
    // 主页面有底部导航
    expect(find.text('流水'), findsAtLeastNWidgets(1));

    await tester.tap(find.text('净值追踪'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.pump(const Duration(milliseconds: 200));
    // 二级页整屏：底部导航（流水/报表）不再可见。
    // 注意别断言「净值追踪」消失 —— 那是新页标题，与入口按钮同名。
    expect(find.text('流水'), findsNothing);
    expect(find.text('报表'), findsNothing);
  });

  testWidgets('PlainApp smoke: onboarding replaces shell chrome', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_app(onboarding: true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(NavigationRail), findsNothing);
  });
}
