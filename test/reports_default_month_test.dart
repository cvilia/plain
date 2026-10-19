/// 回归：报表页默认打开的必须是**当前记账月**，不是自然月（G-1）。
///
/// 场景（真机上实测到的那个 bug）：月起始日设成 26 号、今天是 10 月 16 日。
/// 按 G-1，当前记账月是 2026-09（期 = 2026-09-26 ~ 2026-10-25），10-12 的账单属于它。
/// 此前 `SelectedMonthNotifier` 取的是自然月 2026-10（期 = 10-26 ~ 11-25，
/// 一个还没有账单的期），于是流水页照常有数据、报表页却是空态「本月还没有记录」。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plain/app/bootstrap.dart';
import 'package:plain/app/l10n/strings_core.dart';
import 'package:plain/app/settings/ledger_settings.dart';
import 'package:plain/app/theme/theme_registry.dart';
import 'package:plain/app/theme/theme_resolver.dart';
import 'package:plain/core/id/uuid_v7.dart';
import 'package:plain/core/time/clock.dart';
import 'package:plain/data/db/database.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/usecases/entry_usecases.dart';
import 'package:plain/features/reports/reports_page.dart';

void main() {
  testWidgets('月起始日 26 号 · 今天 10-16 → 报表默认落在记账月 2026-09', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // 起始日在 bootstrap 里从 app_meta 预载，测试里直接给。
    preloadLedgerSettings(26);

    final db = AppDatabase.inMemory();
    addTearDown(db.close);

    // 「今天」= 2026-10-16：日号 16 < 起始日 26 → 当前记账月是 2026-09。
    // 取 UTC 当日，任何时区下本机日号都是 15 或 16，都小于 26，结论不受时区影响。
    final clock = FixedClock(DateTime.utc(2026, 10, 16, 4));
    final deps = buildDependencies(
      db: db,
      deviceId: 'dev-1',
      bookId: 'book-1',
      clock: clock,
    );

    final created = await CreateEntryUseCase(
      repository: deps.ledgerRepository,
      clock: clock,
      idGen: UuidV7(),
    )(CreateEntryInput(
      amountExpression: '25',
      type: EntryType.expense,
      categoryId: 'preset_food_lunch',
      accountId: 'default_cash',
      bookId: 'book-1',
      deviceId: 'dev-1',
      occurredAt: DateTime.utc(2026, 10, 12, 4),
    ), s: kDefaultAppStrings);
    expect(created.isSuccess, true, reason: '前置账单没写进去，后面测的就不是报表了');

    await tester.pumpWidget(ProviderScope(
      overrides: [appDependenciesProvider.overrideWithValue(deps)],
      child: MaterialApp(
        theme: buildThemeData(
          resolveTokens(themeSpecOf(ThemeId.subai), Brightness.light),
          Brightness.light,
        ),
        home: const ReportsPage(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(
      find.text('本月还没有记录'),
      findsNothing,
      reason: '账单落在当前记账月里，报表不该是空态 —— 默认月份又按自然月取了',
    );
    expect(find.textContaining('共 1 笔'), findsOneWidget);
  });

  testWidgets('月起始日 1 号时默认仍是当自然月（不要为此把默认值改坏）', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    preloadLedgerSettings(1);

    final db = AppDatabase.inMemory();
    addTearDown(db.close);

    final clock = FixedClock(DateTime.utc(2026, 10, 16, 4));
    final deps = buildDependencies(
      db: db,
      deviceId: 'dev-1',
      bookId: 'book-1',
      clock: clock,
    );

    await CreateEntryUseCase(
      repository: deps.ledgerRepository,
      clock: clock,
      idGen: UuidV7(),
    )(CreateEntryInput(
      amountExpression: '25',
      type: EntryType.expense,
      categoryId: 'preset_food_lunch',
      accountId: 'default_cash',
      bookId: 'book-1',
      deviceId: 'dev-1',
      occurredAt: DateTime.utc(2026, 10, 12, 4),
    ), s: kDefaultAppStrings);

    await tester.pumpWidget(ProviderScope(
      overrides: [appDependenciesProvider.overrideWithValue(deps)],
      child: MaterialApp(
        theme: buildThemeData(
          resolveTokens(themeSpecOf(ThemeId.subai), Brightness.light),
          Brightness.light,
        ),
        home: const ReportsPage(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('本月还没有记录'), findsNothing);
    expect(find.textContaining('共 1 笔'), findsOneWidget);
  });
}
