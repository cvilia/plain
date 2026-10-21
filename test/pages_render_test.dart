/// 全页面渲染巡检：每个页面都要能在**真实依赖**（内存库 + 预置分类 + 一笔账单）
/// 下建起来，不抛异常。
///
/// 为什么需要：单元测试只覆盖用例层，页面级的崩溃（空数据 / `initState` 里取
/// `Localizations` / 依赖没初始化）全在真机上才暴露。历史上 `SavingsGoalsPage`
/// 就在 `initState` 里取 `AppStrings.of(context)` 崩过。
///
/// 断言口径：建页 → 让异步加载跑完 → 不抛异常 + 有 Scaffold。
/// 不校验内容（各页的字段级断言在各自的测试里）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plain/app/bootstrap.dart';
import 'package:plain/app/l10n/app_strings.dart';
import 'package:plain/app/theme/theme_registry.dart';
import 'package:plain/app/theme/theme_resolver.dart';
import 'package:plain/core/time/clock.dart';
import 'package:plain/data/db/database.dart';
import 'package:plain/data/seed/default_account.dart';
import 'package:plain/data/seed/preset_categories.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/usecases/entry_usecases.dart';
import 'package:plain/features/accounts/account_entries_page.dart';
import 'package:plain/features/accounts/accounts_page.dart';
import 'package:plain/features/accounts/credit_reconcile_page.dart';
import 'package:plain/features/accounts/reconcile_mode_page.dart';
import 'package:plain/features/assets/debt_optimize_page.dart';
import 'package:plain/features/assets/investment_page.dart';
import 'package:plain/features/assets/loan_page.dart';
import 'package:plain/features/assets/net_worth_page.dart';
import 'package:plain/features/family/family_page.dart';
import 'package:plain/features/ledger/presentation/advanced_filter_page.dart';
import 'package:plain/features/ledger/presentation/category_picker_page.dart';
import 'package:plain/features/ledger/presentation/entry_detail_page.dart';
import 'package:plain/features/ledger/presentation/entry_input_page.dart';
import 'package:plain/features/ledger/presentation/flow_list_page.dart';
import 'package:plain/features/ledger/presentation/split_editor_page.dart';
import 'package:plain/features/reports/cross_analysis_page.dart';
import 'package:plain/features/reports/money_age_page.dart';
import 'package:plain/features/reports/reports_page.dart';
import 'package:plain/features/reports/sankey_page.dart';
import 'package:plain/features/reports/tax_report_page.dart';
import 'package:plain/features/reports/weekly_report_page.dart';
import 'package:plain/features/settings/achievements_page.dart';
import 'package:plain/features/settings/action_log_page.dart';
import 'package:plain/features/settings/automation_rules_page.dart';
import 'package:plain/features/settings/backup_page.dart';
import 'package:plain/features/settings/budget_page.dart';
import 'package:plain/features/settings/card_opacity_page.dart';
import 'package:plain/features/settings/category_manage_page.dart';
import 'package:plain/features/settings/conflict_center_page.dart';
import 'package:plain/features/settings/currency_rate_page.dart';
import 'package:plain/features/settings/debug_log_page.dart';
import 'package:plain/features/settings/home_layout_page.dart';
import 'package:plain/features/settings/import_page.dart';
import 'package:plain/features/settings/more_settings_page.dart';
import 'package:plain/features/settings/privacy_policy_page.dart';
import 'package:plain/features/settings/recurring_page.dart';
import 'package:plain/features/settings/reimburse_center_page.dart';
import 'package:plain/features/settings/reminders_page.dart';
import 'package:plain/features/settings/savings_goals_page.dart';
import 'package:plain/features/settings/settings_page.dart';
import 'package:plain/features/settings/sync_page.dart';
import 'package:plain/features/settings/theme_page.dart';
import 'package:plain/features/settings/trash_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppDatabase db;
  late AppDependencies deps;
  late String accountId;
  late String accountName;
  late String entryId;
  var booted = false;

  /// 启动一次，供所有页面复用（页面之间只读，不改库）。
  Future<void> boot() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.inMemory();    // 预置分类 / 默认账户的播种在 main() 的 post-frame 回调里；
    // `seedPresetCategories` 还要求 app_meta 里有 device.id（空则静默跳过）。
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
    accountId = await seedDefaultAccount(db, clock) ?? 'acc-1';
    final accounts = (await deps.accountRepository.listAll()).successOrNull;
    accountName = accounts == null || accounts.isEmpty
        ? '默认账户'
        : accounts.first.name;

    final create = CreateEntryUseCase(
      repository: deps.ledgerRepository,
      clock: clock,
      idGen: deps.idGen,
    );
    final cats = (await deps.categoryRepository.listAll()).successOrNull ?? const [];
    final catId = cats.isEmpty ? 'cat-food' : cats.first.id;
    final r = await create(
      CreateEntryInput(
        amountExpression: '28.5',
        type: EntryType.expense,
        categoryId: catId,
        accountId: accountId,
        note: '午餐 · 公司楼下',
        occurredAt: clock.now(),
        bookId: 'book-1',
        deviceId: 'dev-1',
      ),
      s: AppStrings(const Locale('zh', 'CN')),
    );
    entryId = r.successOrNull?.id ?? 'no-such-entry';
    booted = true;
  }

  tearDown(() {
    if (!booted) return;
    db.close();
  });

  /// 建页 → 跑完异步加载 → 不抛异常。
  Future<void> expectPageOK(
    WidgetTester tester,
    String name,
    Widget page,
  ) async {
    final container = ProviderContainer(
      overrides: [appDependenciesProvider.overrideWithValue(deps)],
    );
    addTearDown(container.dispose);
    // 真机尺寸：默认 800×600 会让长列表页在测试里「假溢出」。
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
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
          home: page,
        ),
      ),
    );
    // 页面的首屏数据是异步查库的：必须给真实事件循环，fake async 推不动 sqflite。
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 120)),
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    final error = tester.takeException();
    expect(error, isNull, reason: '页面「$name」建页抛异常：$error');
    expect(
      find.byType(Scaffold),
      findsWidgets,
      reason: '页面「$name」没有渲染出 Scaffold',
    );
    // 卸掉页面，避免它的 Timer/动画渗到下一条。
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }

  testWidgets('四个主页面', (tester) async {
    await boot();
    await expectPageOK(tester, '流水', const FlowListPage());
    await expectPageOK(tester, '报表', const ReportsPage());
    await expectPageOK(tester, '资产', const AccountsPage());
    await expectPageOK(tester, '我的', const SettingsPage());
  });

  testWidgets('记账与账单页', (tester) async {
    await boot();
    await expectPageOK(tester, '记一笔', const EntryInputPage());
    await expectPageOK(tester, '编辑一笔', EntryInputPage(editEntryId: entryId));
    await expectPageOK(tester, '账单详情', EntryDetailPage(entryId: entryId));
    await expectPageOK(tester, '分类选择', const CategoryPickerPage());
    await expectPageOK(tester, '高级筛选', const AdvancedFilterPage());
    await expectPageOK(tester, '拆分账单', const SplitEditorPage());
  });

  testWidgets('账户与资产页', (tester) async {
    await boot();
    await expectPageOK(
      tester,
      '单账户账单',
      AccountEntriesPage(accountId: accountId, accountName: accountName),
    );
    await expectPageOK(tester, '信用卡对账', CreditReconcilePage(accountId: accountId));
    await expectPageOK(
      tester,
      '余额校准',
      ReconcileModePage(accountId: accountId, accountName: accountName),
    );
    await expectPageOK(tester, '净值追踪', const NetWorthPage());
    await expectPageOK(tester, '债务优化', const DebtOptimizePage());
    await expectPageOK(tester, '贷款', LoanPage(accountId: accountId));
    await expectPageOK(tester, '投资持仓', InvestmentPage(accountId: accountId));
    await expectPageOK(tester, '成员', const FamilyPage());
  });

  testWidgets('报表页', (tester) async {
    await boot();
    await expectPageOK(tester, '交叉分析', const CrossAnalysisPage());
    await expectPageOK(tester, '桑基图', const SankeyPage());
    await expectPageOK(tester, '税负报表', const TaxReportPage());
    await expectPageOK(tester, '周报', const WeeklyReportPage());
    await expectPageOK(tester, '资金占用', const MoneyAgePage());
  });

  testWidgets('设置页与全部二级页', (tester) async {
    await boot();
    await expectPageOK(tester, '更多设置', const MoreSettingsPage());
    await expectPageOK(tester, '外观', const ThemePage());
    await expectPageOK(tester, '卡片透明度', const CardOpacityPage());
    await expectPageOK(tester, '首页布局', const HomeLayoutPage());
    await expectPageOK(tester, '分类管理', const CategoryManagePage());
    await expectPageOK(tester, '预算', const BudgetPage());
    await expectPageOK(tester, '周期记账', const RecurringPage());
    await expectPageOK(tester, '储蓄目标', const SavingsGoalsPage());
    await expectPageOK(tester, '还款提醒', const RemindersPage());
    await expectPageOK(tester, '报销中心', const ReimburseCenterPage());
    await expectPageOK(tester, '自动化规则', const AutomationRulesPage());
    await expectPageOK(tester, '导入导出', const ImportPage());
    await expectPageOK(tester, '备份恢复', const BackupPage());
    await expectPageOK(tester, '回收站', const TrashPage());
    await expectPageOK(tester, '汇率', const CurrencyRatePage());
    await expectPageOK(tester, '成就', const AchievementsPage());
    await expectPageOK(tester, '操作日志', const ActionLogPage());
    await expectPageOK(tester, '同步', const SyncPage());
    await expectPageOK(tester, '冲突中心', const ConflictCenterPage());
    await expectPageOK(tester, '调试日志', const DebugLogPage());
    await expectPageOK(tester, '隐私政策', const PrivacyPolicyPage());
  });
}
