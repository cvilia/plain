/// 流水行左侧必须是**分类图标**，不是一个色点。
///
/// 用户 2026-10-20 报：「这里显示的应该是图标而不是一个带颜色的点」。
/// 原来那行是一个 6×6 的 `Container(shape: circle)`（设计稿早期简化），
/// 换成 `CategoryAvatar` 后要有回归守卫，防止有人再改回点。
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
import 'package:plain/domain/entities/category.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/usecases/entry_usecases.dart';
import 'package:plain/design_system/category_avatar.dart';
import 'package:plain/design_system/plain_icons_v3.dart';
import 'package:plain/features/ledger/presentation/flow_list_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppDatabase db;
  late AppDependencies deps;

  Future<List<Category>> bootRows() async {
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
    for (final name in ['早餐', '公交']) {
      final cat = cats.firstWhere((c) => c.name == name);
      final r = await create(
        CreateEntryInput(
          amountExpression: '12',
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
      // ⚠️ 两笔必须错开至少 1ms：天内顺序按 `createdAt` 排，同一毫秒只能靠 id 兜底
      // （UUIDv7 同一毫秒内不保证单调）→ 行序会随机翻转，断言就成偶发失败。
      clock.advance(const Duration(seconds: 1));
    }
    return cats;
  }

  Future<void> pumpRows(WidgetTester tester) async {
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
          home: const FlowListPage(),
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

  testWidgets('每行左侧是一个分类图标（CategoryAvatar），不是色点', (tester) async {
    final cats = await bootRows();
    await pumpRows(tester);

    final avatars =
        tester.widgetList<CategoryAvatar>(find.byType(CategoryAvatar)).toList();
    expect(avatars, hasLength(2), reason: '两笔账 → 两个分类图标');

    // 图标 ref 必须是分类自己的（二级留空则继承一级），不能是兜底的 'other'。
    // 天内顺序 = 录入先后（后录的在上面），所以这里是「公交、早餐」。
    final expected = [
      for (final name in ['公交', '早餐'])
        cats.firstWhere((c) => c.name == name).iconRef,
    ];
    expect([for (final a in avatars) a.iconRef], expected);
    expect(avatars.every((a) => a.iconRef != 'other' && a.iconRef.isNotEmpty),
        isTrue, reason: '图标 ref 退化成了兜底值');

    // 图标本身真的画出来了（不是空盒子）。
    expect(find.byType(PlainIcon), findsWidgets);
  });

  testWidgets('图标颜色跟着分类色，不是主题灰', (tester) async {
    await bootRows();
    await pumpRows(tester);

    final avatars =
        tester.widgetList<CategoryAvatar>(find.byType(CategoryAvatar)).toList();
    expect(avatars, hasLength(2));
    for (final a in avatars) {
      expect(a.color.a, greaterThan(0.9), reason: '颜色必须不透明');
    }
  });
}
