/// 交叉分析页：矩阵表卡片必须有 16 的内边距（四边）。
///
/// 用户 2026-10-20 报：表格内容贴着卡片边框，和其他页面的边距不一致。
/// 根因是 `PlainPanel` 默认 `padding: EdgeInsets.zero`，这里忘了传。
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plain/app/bootstrap.dart';
import 'package:plain/app/l10n/app_strings.dart';
import 'package:plain/app/l10n/strings_core.dart';
import 'package:plain/app/theme/theme_registry.dart';
import 'package:plain/app/theme/theme_resolver.dart';
import 'package:plain/core/time/clock.dart';
import 'package:plain/data/db/database.dart';
import 'package:plain/data/seed/default_account.dart';
import 'package:plain/data/seed/preset_categories.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/usecases/entry_usecases.dart';
import 'package:plain/design_system/plain_ui.dart';
import 'package:plain/features/reports/cross_analysis_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppDatabase db;
  late AppDependencies deps;

  Future<void> boot() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.inMemory();
    addTearDown(db.close);
    db.raw.execute(
      "INSERT OR REPLACE INTO app_meta (key,value,updated_at) "
      "VALUES ('device.id','dev-1',0)",
    );
    final clock = FixedClock(DateTime(2026, 10, 20, 16, 50).toUtc());
    deps = buildDependencies(
      db: db,
      deviceId: 'dev-1',
      bookId: 'book-1',
      clock: clock,
    );
    await seedPresetCategories(db, clock);
    final accId = await seedDefaultAccount(db, clock) ?? 'acc-1';
    final cats = (await deps.categoryRepository.listAll()).successOrNull!;
    final create = CreateEntryUseCase(
      repository: deps.ledgerRepository,
      clock: clock,
      idGen: deps.idGen,
    );
    // 两笔不同类型的账，保证矩阵不是空态（空态不画表格）。
    for (final (name, cents) in [('餐饮', '30'), ('交通', '6')]) {
      final cat = cats.firstWhere((c) => c.name == name);
      final r = await create(
        CreateEntryInput(
          amountExpression: cents,
          type: EntryType.expense,
          categoryId: cat.id,
          accountId: accId,
          occurredAt: clock.now(),
          bookId: 'book-1',
          deviceId: 'dev-1',
        ),
        s: kDefaultAppStrings,
      );
      expect(r.isSuccess, isTrue);
    }
  }

  Future<void> pumpPage(WidgetTester tester) async {
    tester.view.devicePixelRatio = 2.0;
    tester.view.physicalSize = const Size(786, 1704);
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [appDependenciesProvider.overrideWithValue(deps)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('zh', 'CN'),
          localizationsDelegates: const [
            AppStrings.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppStrings.supportedLocales,
          theme: themeDataFor(ThemeId.qingci, Brightness.light).$2,
          home: const CrossAnalysisPage(),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  testWidgets('矩阵表卡片的内边距是 16（四边），表格不再贴边', (tester) async {
    await boot();
    await pumpPage(tester);

    // 装矩阵表的那块面板：以「行列维度 + 热力图开关」之后的那块为准，
    // 用「含矩阵表头」的条件定位，避免误取底部「保存报表」面板。
    final panels = find.byType(PlainPanel);
    expect(panels, findsWidgets);
    final matrixPanel = panels.evaluate().firstWhere((e) {
      final w = e.widget as PlainPanel;
      final p = w.padding;
      return p is EdgeInsets && p.left == 16 && p.top == 16;
    }, orElse: () => throw StateError('没有找到内边距为 16 的面板'));

    final panelBox = matrixPanel.renderObject! as RenderBox;
    final panelRect = panelBox.localToGlobal(Offset.zero) & panelBox.size;

    // 表头「分类 \ 月份」是面板里的第一个 Text，它的左/上边缘离卡片边框 = 1(描边) + 16。
    final header = find.textContaining(r'\').first;
    final headerBox = tester.renderObject<RenderBox>(header);
    final headerTopLeft = headerBox.localToGlobal(Offset.zero);
    expect(headerTopLeft.dx - panelRect.left, closeTo(17, 0.6),
        reason: '左边距应为 1 描边 + 16 内边距');
    expect(headerTopLeft.dy - panelRect.top, closeTo(17, 0.6),
        reason: '上边距应为 1 描边 + 16 内边距');
  });

  testWidgets('表格内容不超出卡片右边缘（横向滚动被夹在卡片内）', (tester) async {
    await boot();
    await pumpPage(tester);

    final panel = find.byType(PlainPanel).evaluate().firstWhere((e) {
      final w = e.widget as PlainPanel;
      final p = w.padding;
      return p is EdgeInsets && p.left == 16;
    });
    final panelBox = panel.renderObject! as RenderBox;
    final panelRect = panelBox.localToGlobal(Offset.zero) & panelBox.size;

    final scrollables = find.descendant(
      of: find.byType(PlainPanel),
      matching: find.byType(SingleChildScrollView),
    );
    expect(scrollables, findsWidgets);
    final box = tester.renderObject<RenderBox>(scrollables.first);
    final scrollRect = box.localToGlobal(Offset.zero) & box.size;
    expect(scrollRect.right, lessThanOrEqualTo(panelRect.right - 16 + 0.6));
  });
}
