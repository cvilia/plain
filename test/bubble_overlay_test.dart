/// 长按气泡（BubbleOnLongPress / showPersistentBubble）回归契约。
///
/// 气泡挂在 Overlay 上、不属于任何路由。修过的问题：在分类管理页长按分类
/// 弹出气泡后按系统返回，页面退了、气泡还飘在上一页 —— 因为 OverlayEntry
/// 不随宿主路由 pop 自动移除。修复后：宿主路由退场（animation reverse）时
/// 气泡一并撤掉。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plain/app/theme/theme_registry.dart';
import 'package:plain/app/theme/theme_resolver.dart';
import 'package:plain/design_system/bubble_overlay.dart';

/// 气泡用 `context.colors`（AppColors ThemeExtension），
/// 装置必须挂上应用主题，否则取色断言直接炸。
ThemeData _theme() => buildThemeData(
      resolveTokens(themeSpecOf(ThemeId.subai), Brightness.light),
      Brightness.light,
    );

void main() {
  testWidgets('宿主页面 pop 时气泡一并消失，不飘到上一页', (tester) async {
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navKey,
      theme: _theme(),
      home: const Scaffold(body: Center(child: Text('首页'))),
    ));

    navKey.currentState!.push(MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        body: Center(
          child: BubbleOnLongPress(
            bubbleText: '气泡备注内容',
            child: const SizedBox(
              width: 120,
              height: 44,
              child: Center(child: Text('长按我')),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.longPress(find.text('长按我'));
    await tester.pumpAndSettle();
    expect(find.text('气泡备注内容'), findsOneWidget, reason: '长按后应出现气泡');

    navKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('首页'), findsOneWidget, reason: '应已回到首页');
    expect(find.text('气泡备注内容'), findsNothing,
        reason: '宿主路由退场后气泡必须移除 —— 否则会飘在上一页关不掉');
  });

  testWidgets('轻触屏幕任意处可关闭气泡', (tester) async {
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navKey,
      theme: _theme(),
      home: Scaffold(
        body: Center(
          child: BubbleOnLongPress(
            bubbleText: '气泡备注内容',
            child: const SizedBox(
              width: 120,
              height: 44,
              child: Center(child: Text('长按我')),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.longPress(find.text('长按我'));
    await tester.pumpAndSettle();
    expect(find.text('气泡备注内容'), findsOneWidget);

    await tester.tap(find.text('长按我'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('气泡备注内容'), findsNothing, reason: '气泡的全屏捕获层应吞掉这次点击并关闭');
  });
}
