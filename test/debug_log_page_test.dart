/// 诊断日志页的冒烟测试：环形缓冲 → 列表渲染 → 清空。
///
/// 只覆盖「页面能不能把缓冲里的东西显示出来」这一件事：数据来源用
/// [logBufferProvider] 注入，不碰数据库与依赖容器。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plain/app/bootstrap.dart';
import 'package:plain/app/theme/theme_registry.dart';
import 'package:plain/app/theme/theme_resolver.dart';
import 'package:plain/core/logging/app_log.dart';
import 'package:plain/features/settings/debug_log_page.dart';

ThemeData _theme() => buildThemeData(
      resolveTokens(themeSpecOf(ThemeId.subai), Brightness.light),
      Brightness.light,
    );

Widget _host(RingBufferSink buffer) => ProviderScope(
      overrides: [logBufferProvider.overrideWithValue(buffer)],
      child: MaterialApp(theme: _theme(), home: const DebugLogPage()),
    );

void main() {
  testWidgets('空缓冲显示空态', (tester) async {
    final buffer = RingBufferSink();

    await tester.pumpWidget(_host(buffer));
    await tester.pump();

    expect(find.text('还没有日志'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('缓冲里的事件按最新在上渲染', (tester) async {
    final buffer = RingBufferSink();
    final log = AppLog(sink: buffer);
    log.info('entry.save_start');
    log.error('db.insert_failed', errorCode: 'db.insert_failed');

    await tester.pumpWidget(_host(buffer));
    await tester.pump();

    expect(find.text('entry.save_start'), findsOneWidget);
    expect(find.text('db.insert_failed'), findsOneWidget);
    expect(find.text('2 条事件'), findsOneWidget);

    final first = tester.getTopLeft(find.text('db.insert_failed')).dy;
    final second = tester.getTopLeft(find.text('entry.save_start')).dy;
    expect(first, lessThan(second), reason: '最新的事件在上面');

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('级别筛选只留 warn 以上', (tester) async {
    final buffer = RingBufferSink();
    final log = AppLog(sink: buffer);
    log.debug('only_debug');
    log.warn('kept_warn');

    await tester.pumpWidget(_host(buffer));
    await tester.pump();

    await tester.tap(find.text('警告+'));
    await tester.pump();

    expect(find.text('kept_warn'), findsOneWidget);
    expect(find.text('only_debug'), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('清空按钮把缓冲与列表一起清掉', (tester) async {
    final buffer = RingBufferSink();
    AppLog(sink: buffer).info('to_be_cleared');

    await tester.pumpWidget(_host(buffer));
    await tester.pump();
    expect(find.text('to_be_cleared'), findsOneWidget);

    await tester.tap(find.text('清空'));
    await tester.pump();

    expect(buffer.events, isEmpty);
    expect(find.text('还没有日志'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });
}
