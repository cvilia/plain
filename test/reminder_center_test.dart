/// STORY-6.3 提醒中心：九类产生 / 逐项开关 / 全部静音 / 同类去重 /
/// 夜间降级与次日 08:00 汇总 / 近 90 天历史。
library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plain/core/constants/app_constants.dart';
import 'package:plain/core/id/uuid_v7.dart';
import 'package:plain/core/money/money.dart';
import 'package:plain/core/time/clock.dart';
import 'package:plain/data/db/database.dart';
import 'package:plain/data/repositories/account_repository.dart';
import 'package:plain/data/repositories/app_meta_repository.dart';
import 'package:plain/data/repositories/budget_repository.dart';
import 'package:plain/data/repositories/category_repository.dart';
import 'package:plain/data/repositories/ledger_repository.dart';
import 'package:plain/data/repositories/recurring_repository.dart';
import 'package:plain/data/repositories/reminder_repository.dart';
import 'package:plain/data/repositories/savings_goal_repository.dart';
import 'package:plain/data/sync/change_log_writer.dart';
import 'package:plain/domain/entities/budget.dart';
import 'package:plain/domain/entities/category.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/entities/recurring_rule.dart';
import 'package:plain/domain/entities/reminder.dart';
import 'package:plain/domain/entities/savings_goal.dart';
import 'package:plain/domain/services/accounting_calendar.dart';
import 'package:plain/domain/services/reminder_prefs_store.dart';
import 'package:plain/domain/services/reminder_service.dart';
import 'package:plain/domain/services/sync_scope.dart';
import 'package:plain/domain/usecases/entry_usecases.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 记账月首日（会计日历默认 1 号）当天的上午 10 点——九类都能凑齐的时刻。
DateTime get _dayOne => DateTime(2026, 6, 1, 10);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late FixedClock clock;
  late ChangeLogWriter changeLog;
  late LedgerRepositoryImpl ledgerRepo;
  late AccountRepositoryImpl accountRepo;
  late BudgetRepositoryImpl budgetRepo;
  late RecurringRepositoryImpl recurringRepo;
  late SavingsGoalRepositoryImpl goalRepo;
  late CategoryRepositoryImpl categoryRepo;
  late ReminderRepositoryImpl reminderRepo;
  late AppMetaRepository appMetaRepo;
  late CreateEntryUseCase createEntry;
  late ReminderService service;

  const bookId = 'book-1';
  const deviceId = 'dev-1';

  setUp(() {
    db = AppDatabase.inMemory();
    clock = FixedClock(_dayOne);
    changeLog = ChangeLogWriter(db, clock: clock);
    ledgerRepo = LedgerRepositoryImpl(
      db: db,
      changeLogWriter: changeLog,
      clock: clock,
    );
    accountRepo = AccountRepositoryImpl(
      db: db,
      changeLogWriter: changeLog,
      clock: clock,
    );
    budgetRepo = BudgetRepositoryImpl(
      db: db,
      changeLogWriter: changeLog,
      clock: clock,
    );
    recurringRepo = RecurringRepositoryImpl(
      db: db,
      changeLogWriter: changeLog,
      clock: clock,
    );
    goalRepo = SavingsGoalRepositoryImpl(
      db: db,
      changeLogWriter: changeLog,
      now: () => clock.now(),
    );
    categoryRepo = CategoryRepositoryImpl(
      db: db,
      changeLogWriter: changeLog,
      clock: clock,
    );
    reminderRepo = ReminderRepositoryImpl(db: db);
    appMetaRepo = AppMetaRepository(db: db);
    createEntry = CreateEntryUseCase(
      repository: ledgerRepo,
      clock: clock,
      idGen: UuidV7(),
    );
    service = ReminderService(
      ledgerRepository: ledgerRepo,
      accountRepository: accountRepo,
      budgetRepository: budgetRepo,
      recurringRepository: recurringRepo,
      savingsGoalRepository: goalRepo,
      categoryRepository: categoryRepo,
      reminderRepository: reminderRepo,
      appMetaRepository: appMetaRepo,
      calendar: AccountingCalendar(clock: clock),
      clock: clock,
      idGen: UuidV7(),
    );
  });

  tearDown(() => db.close());

  // ── 造数 ──

  Future<void> seedCategory({
    required String id,
    required String name,
    String? parentId,
    int sort = 0,
  }) async {
    await categoryRepo.create(Category(
      id: id,
      parentId: parentId,
      name: name,
      kind: CategoryKind.expense,
      iconRef: 'food',
      sortOrder: sort,
      createdAt: clock.now(),
      updatedAt: clock.now(),
      deviceId: deviceId,
    ));
  }

  Future<void> seedAccount({
    required String id,
    required String name,
    AccountType type = AccountType.cash,
    int creditLimitCents = 0,
    int creditDebtCents = 0,
    int? billDay,
    int? dueDay,
  }) async {
    await accountRepo.create(Account(
      id: id,
      name: name,
      type: type,
      currency: 'CNY',
      openingBalance: 0,
      sortOrder: 0,
      creditLimitCents: creditLimitCents,
      creditDebtCents: creditDebtCents,
      billDay: billDay,
      dueDay: dueDay,
      createdAt: clock.now(),
      updatedAt: clock.now(),
      deviceId: deviceId,
    ));
  }

  Future<void> seedBudget({
    required String id,
    String? categoryId,
    required int cents,
  }) async {
    await budgetRepo.create(Budget(
      id: id,
      bookId: bookId,
      scope: categoryId == null ? BudgetScope.total : BudgetScope.category,
      categoryId: categoryId,
      amount: Money(cents),
      createdAt: clock.now(),
      updatedAt: clock.now(),
      deviceId: deviceId,
    ));
  }

  Future<void> seedRecurring({
    required String id,
    required int cents,
    required DateTime nextRunAt,
    int generatedCount = 0,
    bool autoConfirm = true,
    RecurringFrequency frequency = RecurringFrequency.monthly,
    String name = '周期',
  }) async {
    await recurringRepo.create(RecurringRule(
      id: id,
      bookId: bookId,
      name: name,
      frequency: frequency,
      anchorDay: 1,
      autoConfirm: autoConfirm,
      generatedCount: generatedCount,
      nextRunAt: nextRunAt,
      entryType: EntryType.expense,
      amount: Money(cents),
      categoryId: 'cat-hist',
      accountId: 'acc-cash',
      createdAt: clock.now(),
      updatedAt: clock.now(),
      deviceId: deviceId,
    ));
  }

  Future<void> spend(String cents, {DateTime? at, String category = 'cat-hist'}) async {
    final result = await createEntry(CreateEntryInput(
      amountExpression: cents,
      type: EntryType.expense,
      categoryId: category,
      accountId: 'acc-cash',
      occurredAt: at,
      bookId: bookId,
      deviceId: deviceId,
    ));
    expect(result.isSuccess, isTrue, reason: '造账单失败：${result.failureOrNull}');
  }

  /// 九类全部凑齐的数据集（每类都有真实数据源）：
  ///   ① 信用卡：一张 4 号还款（今天距到期 3 天）、一张 1 号还款（今天到期）
  ///   ② 订阅：连续扣款 3 次、下次扣款为 3 天后
  ///   ③ 预算：一个 85%（预警）、一个 100%（超支）
  ///   ④ 余额不足：现金账户被花成负数 + 有预算 → 安全可花为负
  ///   ⑤ 异常支出：同分类近 90 天 6 笔 ¥100，今天一笔 ¥1000（> P90×2）；
  ///      今日合计 ¥1950 也高于近 30 天日均
  ///   ⑥ 周期已入账：一条免确认且已到期的规则
  ///   ⑦ 对账：记账月首日 + 有未对账账单
  ///   ⑧ 储蓄目标：未达成、有截止日 → 每月需存 > 0
  ///   ⑨ 备份：上次备份在 40 天前
  Future<void> seedAllNine() async {
    await seedCategory(id: 'cat-food', name: '餐饮');
    await seedCategory(id: 'cat-lunch', name: '午餐', parentId: 'cat-food');
    await seedCategory(id: 'cat-shop', name: '购物', sort: 1);
    await seedCategory(id: 'cat-hist', name: '历史', sort: 2);

    await seedAccount(id: 'acc-cash', name: '现金');
    await seedAccount(
      id: 'acc-card-ahead',
      name: '信用卡 A',
      type: AccountType.credit,
      creditLimitCents: 100000,
      creditDebtCents: 50000,
      billDay: 25,
      dueDay: 4,
    );
    await seedAccount(
      id: 'acc-card-today',
      name: '信用卡 B',
      type: AccountType.credit,
      creditLimitCents: 100000,
      creditDebtCents: 1000,
      billDay: 20,
      dueDay: 1,
    );

    await seedBudget(id: 'bud-food', categoryId: 'cat-food', cents: 100000);
    await seedBudget(id: 'bud-shop', categoryId: 'cat-shop', cents: 10000);

    // 预算 85%（含子分类）+ 预算 100%
    await spend('850', category: 'cat-lunch');
    await spend('100', category: 'cat-shop');

    // 异常支出：近 90 天 6 笔 ¥100（上个月，不落在本月预算周期内）
    for (var i = 5; i <= 10; i++) {
      await spend('100', at: DateTime(2026, 5, i, 12), category: 'cat-hist');
    }
    await spend('1000', category: 'cat-hist');

    // 订阅（连续扣款 3 次，下次扣款 6/4）+ 免确认已到期规则
    await seedRecurring(
      id: 'rule-sub',
      name: '视频会员',
      cents: 5000,
      nextRunAt: DateTime(2026, 6, 4, 10),
      generatedCount: 3,
    );
    await seedRecurring(
      id: 'rule-posted',
      name: '房租',
      cents: 50000,
      nextRunAt: DateTime(2026, 6, 1, 9),
      generatedCount: 1,
    );

    await goalRepo.create(SavingsGoal(
      id: 'goal-1',
      bookId: bookId,
      name: '年度旅行',
      targetCents: 1200000,
      savedCents: 0,
      accountId: 'acc-cash',
      dueAt: DateTime(2026, 12, 31),
      createdAt: clock.now(),
      updatedAt: clock.now(),
      deviceId: deviceId,
    ));

    appMetaRepo.markBackedUpAt(clock.now().subtract(const Duration(days: 40)));
  }

  Set<ReminderKind> kindsOf(List<AppReminder> items) =>
      items.map((r) => r.kind).toSet();

  // ── 级别表 ──

  test('PRD 级别表：前四类响铃，后五类静默', () {
    expect(ReminderKind.values.length, 9);
    const ring = {
      ReminderKind.creditDue,
      ReminderKind.subscription,
      ReminderKind.budgetWarn,
      ReminderKind.lowBalance,
    };
    for (final k in ReminderKind.values) {
      expect(k.rings, ring.contains(k), reason: '${k.wire} 的级别与 PRD 表不一致');
      expect(k.level,
          ring.contains(k) ? ReminderLevel.ring : ReminderLevel.silent);
    }
  });

  // ── ① 九类都产生 ──

  test('九类提醒全部产生，且各归各级别', () async {
    await seedAllNine();
    final items = await service.collect(bookId: bookId, prefs: const ReminderPrefs());

    expect(kindsOf(items), ReminderKind.values.toSet(),
        reason: '缺：${ReminderKind.values.toSet().difference(kindsOf(items)).map((k) => k.wire)}');

    // 前四类响铃（10 点不在夜间免打扰时段，不被降级）
    for (final kind in ReminderKind.values) {
      final of = items.where((r) => r.kind == kind).toList();
      expect(of, isNotEmpty, reason: '${kind.wire} 没产生');
      for (final r in of) {
        expect(r.level, kind.level, reason: '${kind.wire} 的级别不对');
        expect(r.wasQuietDowngraded, isFalse);
      }
    }

    // 单笔异常 + 当日合计异常 → 异常支出至少两条
    expect(items.where((r) => r.kind == ReminderKind.anomalySpend).length,
        greaterThanOrEqualTo(2));
    // 预算 85% 与 100% 各一条
    expect(items.where((r) => r.kind == ReminderKind.budgetWarn).length, 2);
    // 还款日「前 3 天」与「当天」各一条
    expect(items.where((r) => r.kind == ReminderKind.creditDue).length, 2);
  });

  test('取不到数据的种类不产生（无还款日信用卡 / 未达阈值 / 从没备份）', () async {
    await seedCategory(id: 'cat-food', name: '餐饮');
    await seedCategory(id: 'cat-hist', name: '历史', sort: 1);
    // 有信用卡但没有还款日与欠款
    await seedAccount(
      id: 'acc-card',
      name: '信用卡',
      type: AccountType.credit,
      creditLimitCents: 100000,
    );
    await seedAccount(id: 'acc-cash', name: '现金');

    final items = await service.collect(bookId: bookId, prefs: const ReminderPrefs());
    expect(items, isEmpty, reason: '没有数据就该一条都不产生');
  });

  // ── ② 逐项开关 ──

  test('逐项开关：关掉某一类后该类不再产生，其余不受影响', () async {
    await seedAllNine();
    final baseline = await service.collect(
      bookId: bookId,
      prefs: const ReminderPrefs(),
      persist: false,
    );
    expect(kindsOf(baseline), ReminderKind.values.toSet());

    for (final kind in ReminderKind.values) {
      final items = await service.collect(
        bookId: bookId,
        prefs: ReminderPrefs(disabled: {kind}),
        persist: false,
      );
      expect(items.where((r) => r.kind == kind), isEmpty,
          reason: '关掉 ${kind.wire} 后仍然产生了');
      expect(items, isNotEmpty, reason: '关掉 ${kind.wire} 把别的种类也关掉了');
    }
  });

  test('提醒开关持久化到 SharedPreferences（键在同步白名单内）', () async {
    SharedPreferences.setMockInitialValues({});
    const key = ReminderRules.kPrefReminder;
    // 键名必须与 PRD 8.1「可同步设置」白名单一致
    expect(kSyncedSettingKeys.contains(key), isTrue);

    var prefs = const ReminderPrefs().toggle(ReminderKind.anomalySpend);
    prefs = prefs.copyWith(allMuted: true);
    await ReminderPrefsStore.save(prefs);

    final loaded = await ReminderPrefsStore.load();
    expect(loaded.allMuted, isTrue);
    // 全静音时**所有**类型都不产生（不是只看逐项开关）
    expect(loaded.isEnabled(ReminderKind.anomalySpend), isFalse);
    expect(loaded.isEnabled(ReminderKind.budgetWarn), isFalse);
    // 解开全静音后，只有被逐项关掉的那类仍是关的
    final unmuted = loaded.copyWith(allMuted: false);
    expect(unmuted.isEnabled(ReminderKind.budgetWarn), isTrue);
    expect(unmuted.isEnabled(ReminderKind.anomalySpend), isFalse);

    final sp = await SharedPreferences.getInstance();
    expect(sp.getString(key), isNotNull);
  });

  // ── ③ 全部静音不推系统通知 ──

  test('全部静音：不产生提醒、不推任何系统通知；逐项响铃/静默走对通道', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('app/notification'),
            (call) async {
      calls.add(call);
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel('app/notification'), null);
    });

    await seedAllNine();

    // 正常：响铃项 silent=false、静默项 silent=true
    final items = await service.collect(
      bookId: bookId,
      prefs: const ReminderPrefs(),
      persist: false,
    );
    await service.pushToSystem(items);
    final shown = calls.where((c) => c.method == 'show').toList();
    expect(shown.length, items.length);
    Map<Object?, Object?> argsOf(MethodCall c) =>
        c.arguments as Map<Object?, Object?>;
    final ringPushed =
        shown.where((c) => argsOf(c)['silent'] == false);
    final silentPushed =
        shown.where((c) => argsOf(c)['silent'] == true);
    expect(ringPushed.length, items.where((r) => r.kind.rings).length,
        reason: '响铃项没走响铃通道');
    expect(silentPushed.length, items.where((r) => !r.kind.rings).length,
        reason: '静默项没走静默通道');

    // 全部静音：collect 空 + 推出去 0 条（PRD AC5）
    calls.clear();
    final muted = await service.collect(
      bookId: bookId,
      prefs: const ReminderPrefs(allMuted: true),
      persist: false,
    );
    expect(muted, isEmpty);
    await service.pushToSystem(muted);
    expect(calls.where((c) => c.method == 'show'), isEmpty,
        reason: '全部静音时仍然推了系统通知');
  });

  // ── ④ 同类去重 ──

  test('同类去重：同一预算周期的同一分类只出一次，第二轮全量不再重复', () async {
    await seedAllNine();

    final first = await service.collect(bookId: bookId, prefs: const ReminderPrefs());
    expect(first.where((r) => r.kind == ReminderKind.budgetWarn).length, 2);
    expect(kindsOf(first), ReminderKind.values.toSet());

    // 同一时刻再扫：全部已被历史去重挡掉（含预算 80%/100%、异常单笔、还款日）
    final second = await service.collect(bookId: bookId, prefs: const ReminderPrefs());
    expect(second, isEmpty, reason: '去重失效：${second.map((r) => r.dedupKey)}');
  });

  test('预算 80% 与 100% 是两条不同的去重键（不会互相顶掉）', () async {
    await seedCategory(id: 'cat-shop', name: '购物');
    await seedAccount(id: 'acc-cash', name: '现金');
    await seedBudget(id: 'bud-shop', categoryId: 'cat-shop', cents: 100000);
    await spend('800', category: 'cat-shop');

    final warn = await service.collect(bookId: bookId, prefs: const ReminderPrefs());
    final warnKeys = warn
        .where((r) => r.kind == ReminderKind.budgetWarn)
        .map((r) => r.dedupKey)
        .toList();
    expect(warnKeys.length, 1);
    expect(warnKeys.first.endsWith(':80'), isTrue);

    // 再花 300 → 合计 110% → 这一次该出 100%
    await spend('300', category: 'cat-shop');
    final over = await service.collect(bookId: bookId, prefs: const ReminderPrefs());
    final overKeys = over
        .where((r) => r.kind == ReminderKind.budgetWarn)
        .map((r) => r.dedupKey)
        .toList();
    expect(overKeys.length, 1);
    expect(overKeys.first.endsWith(':100'), isTrue);
  });

  // ── ⑤ 夜间降级与次日 08:00 汇总 ──

  test('夜间 23:30：响铃降级为静默，次日 08:00 汇总（含已入账笔数与预算预警）', () async {
    await seedAllNine();
    clock.set(DateTime(2026, 6, 1, 23, 30));

    final night = await service.collect(bookId: bookId, prefs: const ReminderPrefs());
    expect(kindsOf(night), ReminderKind.values.toSet());

    // 原本响铃的四类全部降级为静默，并记得「曾经想响铃」
    for (final kind in ReminderKind.values.where((k) => k.rings)) {
      final of = night.where((r) => r.kind == kind).toList();
      expect(of, isNotEmpty);
      for (final r in of) {
        expect(r.requestedLevel, ReminderLevel.ring);
        expect(r.level, ReminderLevel.silent, reason: '${kind.wire} 夜间没降级');
        expect(r.wasQuietDowngraded, isTrue);
      }
    }
    // 静默类保持静默（不是「降级」）
    for (final r in night.where((r) => !r.kind.rings)) {
      expect(r.level, ReminderLevel.silent);
      expect(r.wasQuietDowngraded, isFalse);
    }

    // 夜间不汇总
    expect(await service.buildDigest(bookId: bookId), isNull);

    // 次日 08:00 → 一条汇总
    clock.set(DateTime(2026, 6, 2, 8, 0));
    final digest = await service.buildDigest(bookId: bookId);
    expect(digest, isNotNull);
    expect(digest!.postedCount, greaterThanOrEqualTo(1));
    expect(digest.budgetWarnCount, greaterThanOrEqualTo(1));
    expect(digest.downgradedCount, greaterThanOrEqualTo(1));
    expect(digest.body, contains('已入账'));
    expect(digest.body, contains('预算预警'));
    expect(digest.level, ReminderLevel.ring, reason: '含预算跨阈值应升级为响铃');

    // 汇总只发一次
    expect(await service.buildDigest(bookId: bookId), isNull);
  });

  test('全部静音时不推夜间汇总', () async {
    await seedAllNine();
    clock.set(DateTime(2026, 6, 1, 23, 30));
    await service.collect(bookId: bookId, prefs: const ReminderPrefs());
    clock.set(DateTime(2026, 6, 2, 8, 0));

    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('app/notification'),
            (call) async {
      calls.add(call);
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel('app/notification'), null);
    });

    await service.pushDigestIfDue(
      bookId: bookId,
      prefs: const ReminderPrefs(allMuted: true),
    );
    expect(calls, isEmpty);
    // 没有推出去的汇总不该被标记为已汇总
    final digest = await service.buildDigest(bookId: bookId);
    expect(digest, isNotNull);
  });

  // ── ⑥ 近 90 天历史 ──

  test('历史近 90 天可查：含已读/未读与触发时间，超期被 GC', () async {
    await seedAllNine();
    final items = await service.collect(bookId: bookId, prefs: const ReminderPrefs());
    expect(items, isNotEmpty);

    final now = clock.now();
    final history = await reminderRepo.listRecent(
      bookId: bookId,
      sinceMs: now.subtract(ReminderRules.historyTtl).millisecondsSinceEpoch,
      limit: 200,
    );
    final rows = history.successOrNull!;
    expect(rows.length, items.length);
    expect(kindsOf(rows), ReminderKind.values.toSet());
    for (final r in rows) {
      expect(r.read, isFalse);
      expect(r.triggeredAt.millisecondsSinceEpoch,
          now.millisecondsSinceEpoch);
    }

    // 已读
    await reminderRepo.markRead(id: rows.first.id, read: true);
    final after = await reminderRepo.listRecent(
      bookId: bookId,
      sinceMs: now.subtract(ReminderRules.historyTtl).millisecondsSinceEpoch,
      limit: 200,
    );
    expect(after.successOrNull!.where((r) => r.read).length, 1);

    // 90 天窗口内查得到；超出窗口查不到；GC 清超期
    final noneYet = await reminderRepo.listRecent(
      bookId: bookId,
      sinceMs: now.add(const Duration(days: 1)).millisecondsSinceEpoch,
      limit: 200,
    );
    expect(noneYet.successOrNull, isEmpty);

    final purged = await reminderRepo.gc(
      before: now.add(const Duration(minutes: 1)),
    );
    expect(purged.successOrNull, items.length);
    final empty = await reminderRepo.listRecent(
      bookId: bookId,
      sinceMs: now.subtract(ReminderRules.historyTtl).millisecondsSinceEpoch,
      limit: 200,
    );
    expect(empty.successOrNull, isEmpty);
  });

  // ── ⑦ schema v24：提醒历史表进得了还原清单 ──

  test('reminders 表与索引已建立（schema v24）', () async {
    expect(kSchemaVersion, 24);
    final tables = db.raw
        .select("SELECT name FROM sqlite_master WHERE type='table'")
        .map((r) => r['name'] as String)
        .toSet();
    expect(tables.contains('reminders'), isTrue);
    final indexes = db.raw
        .select("SELECT name FROM sqlite_master WHERE type='index'")
        .map((r) => r['name'] as String)
        .toSet();
    expect(indexes.contains('idx_reminder_dedup'), isTrue);
    expect(indexes.contains('idx_reminder_book_time'), isTrue);
  });

  // ── ⑧ 口径收口（2026-10-15）：异常支出跨天补报 / 对账只看上一个记账月 ──

  test('异常支出跨天补报：昨天的大额支出，今天启动也要报出来', () async {
    await seedAccount(id: 'acc-cash', name: '现金');
    // 近 90 天垫 6 笔同分类日常样本（不足 5 笔不触发阈值反馈）
    for (var i = 5; i <= 10; i++) {
      await spend('100', at: DateTime(2026, 5, i, 12), category: 'cat-hist');
    }
    // 大额那笔落在**昨天**（2026-05-31），不是今天
    await spend('1000', at: DateTime(2026, 5, 31, 12), category: 'cat-hist');

    final items = await service.collect(bookId: bookId, prefs: const ReminderPrefs());
    expect(items.any((r) => r.kind == ReminderKind.anomalySpend), isTrue,
        reason: '只看当天会漏报：那天没打开 App，这笔异常就永远不提醒');
  });

  test('对账提醒只看上一个记账月：更早的欠账不提醒', () async {
    await seedAccount(id: 'acc-cash', name: '现金');
    // 时钟是 2026-06-01 → 上一个记账月是 5 月；这笔落在 4 月
    await spend('50', at: DateTime(2026, 4, 20, 12), category: 'cat-hist');

    final items = await service.collect(bookId: bookId, prefs: const ReminderPrefs());
    expect(items.any((r) => r.kind == ReminderKind.reconcile), isFalse,
        reason: '对账是对上个月的账，不是清历史欠账');
  });

  test('对账提醒：上一个记账月有未核对账单时会提醒', () async {
    await seedAccount(id: 'acc-cash', name: '现金');
    await spend('50', at: DateTime(2026, 5, 20, 12), category: 'cat-hist');

    final items = await service.collect(bookId: bookId, prefs: const ReminderPrefs());
    final reconcile = items.where((r) => r.kind == ReminderKind.reconcile).toList();
    expect(reconcile, isNotEmpty);
    expect(reconcile.first.body.contains('2026-05'), isTrue,
        reason: '文案要说明是哪个记账月，不能让用户以为是全部欠账');
  });

  // ── ⑨ 订阅提醒的一键处理（PRD：可一键标记不再需要 + 取消路径指引） ──

  test('订阅提醒带规则引用与取消路径指引，其余种类不给动作', () async {
    await seedAccount(id: 'acc-cash', name: '现金');
    await seedRecurring(
      id: 'rule-sub',
      name: '视频会员',
      cents: 5000,
      nextRunAt: DateTime(2026, 6, 4, 10),
      generatedCount: 3,
    );
    appMetaRepo.markBackedUpAt(clock.now().subtract(const Duration(days: 40)));

    final items = await service.collect(bookId: bookId, prefs: const ReminderPrefs());
    final sub = items.where((r) => r.kind == ReminderKind.subscription).firstOrNull;
    expect(sub, isNotNull, reason: '连续扣款 3 次、下次扣款 3 天后 → 应产生订阅提醒');
    expect(sub!.actionRef, 'rule-sub', reason: '卡片要据此停用那条周期规则');
    expect(sub.actionLabel, '不再需要');
    expect(sub.body.contains('取消自动续费'), isTrue,
        reason: '只能关本机规则，原扣款渠道要用户自己去取消，必须说清');

    // 其余种类不该出现动作按钮（避免到处是看不懂的按钮）
    final others = items.where((r) => r.kind != ReminderKind.subscription);
    for (final r in others) {
      expect(r.actionLabel, isNull, reason: '${r.kind.wire} 不该有动作');
    }
  });
}
