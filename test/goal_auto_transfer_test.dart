/// STORY-7.1 AC6 + STORY-7.3：储蓄目标自动按月划拨走统一周期引擎。
library;
import 'package:flutter_test/flutter_test.dart';
import 'package:plain/app/l10n/strings_core.dart';
import 'package:plain/core/id/uuid_v7.dart';
import 'package:plain/core/time/clock.dart';
import 'package:plain/data/db/database.dart';
import 'package:plain/data/repositories/account_repository.dart';
import 'package:plain/data/repositories/ledger_repository.dart';
import 'package:plain/data/repositories/recurring_repository.dart';
import 'package:plain/data/repositories/savings_goal_repository.dart';
import 'package:plain/data/sync/change_log_writer.dart';
import 'package:plain/domain/entities/category.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/entities/savings_goal.dart';
import 'package:plain/domain/usecases/goal_usecases.dart';
import 'package:plain/domain/usecases/recurring_usecases.dart';

void main() {
  late AppDatabase db;
  late FixedClock clock;
  late LedgerRepositoryImpl ledgerRepo;
  late AccountRepositoryImpl accountRepo;
  late SavingsGoalRepositoryImpl goalRepo;
  late RecurringRepositoryImpl recurringRepo;
  late SetGoalAutoTransferUseCase setAuto;
  late GenerateDueRecurringUseCase generateDue;

  const bookId = 'book-1';
  const deviceId = 'dev-1';
  const monthStartDay = 5;

  setUp(() async {
    db = AppDatabase.inMemory();
    clock = FixedClock(DateTime.utc(2026, 1, 15, 12));
    final idGen = UuidV7();
    final changeLog = ChangeLogWriter(db, clock: clock);
    ledgerRepo = LedgerRepositoryImpl(db: db, changeLogWriter: changeLog, clock: clock);
    accountRepo = AccountRepositoryImpl(db: db, changeLogWriter: changeLog, clock: clock);
    goalRepo = SavingsGoalRepositoryImpl(db: db, changeLogWriter: changeLog, now: clock.now);
    recurringRepo = RecurringRepositoryImpl(db: db, changeLogWriter: changeLog, clock: clock);

    setAuto = SetGoalAutoTransferUseCase(
      goalRepository: goalRepo,
      accountRepository: accountRepo,
      recurringRepository: recurringRepo,
      clock: clock,
      idGen: idGen,
    );
    generateDue = GenerateDueRecurringUseCase(
      recurringRepository: recurringRepo,
      ledgerRepository: ledgerRepo,
      clock: clock,
      idGen: idGen,
      savingsGoalRepository: goalRepo,
    );

    await accountRepo.create(Account(
      id: 'acc-cash', name: '现金', type: AccountType.cash,
      currency: 'CNY', openingBalance: 1000000, sortOrder: 0,
      createdAt: clock.now(), updatedAt: clock.now(), deviceId: deviceId,
    ));
    await goalRepo.create(SavingsGoal(
      id: 'g1', bookId: bookId, name: '车险',
      targetCents: 300000, savedCents: 0,
      dueAt: DateTime.utc(2026, 12, 31),
      accountId: 'acc-cash',
      createdAt: clock.now(), updatedAt: clock.now(), deviceId: deviceId,
    ));
  });

  tearDown(() => db.close());

  test('enabling creates a monthly savingsTransfer rule anchored on 记账月首日', () async {
    final r = await setAuto(goalId: 'g1', enabled: true, monthStartDay: monthStartDay);
    expect(r.isSuccess, true, reason: r.failureOrNull?.toString() ?? '');
    expect(r.successOrNull!.autoTransfer, true);

    final rules = (await recurringRepo.listByBook(bookId)).successOrNull!;
    expect(rules, hasLength(1));
    final rule = rules.first;
    expect(rule.kind, RecurringKind.savingsTransfer);
    expect(rule.goalId, 'g1');
    expect(rule.frequency, RecurringFrequency.monthly);
    expect(rule.anchorDay, monthStartDay);
    // 划拨是内部转账 → G-2 不计入收支
    expect(rule.entryType, EntryType.transfer);
    // 转入端是目标的虚拟账户
    final goal = (await goalRepo.getById('g1')).successOrNull!;
    expect(rule.toAccountId, goal.goalAccountId);
    expect(rule.accountId, 'acc-cash');
    // 1 月 15 日开启 → 首次落在 2 月 5 日（1 月 5 日已过）
    expect(rule.nextRunAt, DateTime.utc(2026, 2, 5));
  });

  test('enabling without a linked account is rejected', () async {
    await goalRepo.create(SavingsGoal(
      id: 'g2', bookId: bookId, name: '无账户目标',
      targetCents: 100000, savedCents: 0,
      createdAt: clock.now(), updatedAt: clock.now(), deviceId: deviceId,
    ));
    final r = await setAuto(goalId: 'g2', enabled: true, monthStartDay: monthStartDay);
    expect(r.isFailure, true);
    expect(r.failureOrNull!.code, 'goal.account_required');
  });

  test('a due rule generates the transfer and credits the goal', () async {
    await setAuto(goalId: 'g1', enabled: true, monthStartDay: monthStartDay);
    // 把规则提前到已到期，模拟走到 2 月 5 日
    final rule = (await recurringRepo.listByBook(bookId)).successOrNull!.first;
    await recurringRepo.update(rule.copyWith(
      nextRunAt: DateTime.utc(2026, 2, 5),
      revision: rule.revision + 1,
      updatedAt: clock.now(),
    ));
    clock.set(DateTime.utc(2026, 2, 5, 9));

    final gen = await generateDue(s: kDefaultAppStrings);
    expect(gen.isSuccess, true, reason: gen.failureOrNull?.toString() ?? '');
    expect(gen.successOrNull!.created, hasLength(1));

    final goal = (await goalRepo.getById('g1')).successOrNull!;
    // 3000 / 12 = 250
    expect(goal.savedCents, 25000);

    // 钱真的进了虚拟账户，转出端同步减少
    final bucket = await accountRepo.balanceOf(goal.goalAccountId!);
    expect(bucket.successOrNull!.balanceCents, 25000);
    final cash = await accountRepo.balanceOf('acc-cash');
    expect(cash.successOrNull!.balanceCents, 1000000 - 25000);

    // 转账不计入收支（AC3 同源）
    final stats = db.raw.select(
        "SELECT COALESCE(SUM(expense_cents),0) AS e, COALESCE(SUM(income_cents),0) AS i "
        "FROM daily_stats WHERE book_id = '$bookId'");
    expect(stats.first['e'], 0);
    expect(stats.first['i'], 0);
  });

  test('disabling stops the rule without deleting history', () async {
    await setAuto(goalId: 'g1', enabled: true, monthStartDay: monthStartDay);
    final r = await setAuto(goalId: 'g1', enabled: false, monthStartDay: monthStartDay);
    expect(r.isSuccess, true);
    expect(r.successOrNull!.autoTransfer, false);

    final rules = (await recurringRepo.listByBook(bookId)).successOrNull!;
    expect(rules, hasLength(1));
    // 规则保留但停用（暂停不删除）
    expect(rules.first.isEnabled, false);
    expect(rules.first.kind, RecurringKind.savingsTransfer);
  });

  test('legacy rules default to kind=recurring', () async {
    // 模拟 v12 老库升级后写入的规则（无 kind 值，走默认）
    db.raw.execute(
      'INSERT INTO recurring_rules (id,book_id,name,frequency,interval_n,'
      'skip_strategy,auto_confirm,end_type,generated_count,next_run_at,'
      'entry_type,amount_cents,is_enabled,created_at,updated_at,revision,'
      "device_id,base_revision) VALUES ('rr-old','$bookId','房租','monthly',1,"
      "'clamp',1,'never',0,0,'expense',150000,1,0,0,1,'$deviceId',0)",
    );
    final rules = (await recurringRepo.listByBook(bookId)).successOrNull!;
    expect(rules, hasLength(1));
    expect(rules.first.kind, RecurringKind.recurring);
    expect(rules.first.goalId, isNull);
  });
}
