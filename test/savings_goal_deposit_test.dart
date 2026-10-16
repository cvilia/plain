/// STORY-7.1 沉淀基金：存入 = 内部转账（G-2 不计入收支）。
library;
import 'package:flutter_test/flutter_test.dart';
import 'package:plain/core/id/uuid_v7.dart';
import 'package:plain/core/time/clock.dart';
import 'package:plain/data/db/database.dart';
import 'package:plain/data/repositories/account_repository.dart';
import 'package:plain/data/repositories/ledger_repository.dart';
import 'package:plain/data/repositories/savings_goal_repository.dart';
import 'package:plain/data/sync/change_log_writer.dart';
import 'package:plain/domain/entities/category.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/entities/savings_goal.dart';
import 'package:plain/domain/usecases/goal_usecases.dart';

void main() {
  late AppDatabase db;
  late FixedClock clock;
  late LedgerRepositoryImpl ledgerRepo;
  late AccountRepositoryImpl accountRepo;
  late SavingsGoalRepositoryImpl goalRepo;
  late DepositToGoalUseCase deposit;

  const bookId = 'book-1';
  const deviceId = 'dev-1';

  setUp(() async {
    db = AppDatabase.inMemory();
    clock = FixedClock(DateTime.utc(2026, 1, 15, 12));
    final changeLog = ChangeLogWriter(db, clock: clock);
    ledgerRepo = LedgerRepositoryImpl(db: db, changeLogWriter: changeLog, clock: clock);
    accountRepo = AccountRepositoryImpl(db: db, changeLogWriter: changeLog, clock: clock);
    goalRepo = SavingsGoalRepositoryImpl(
      db: db, changeLogWriter: changeLog, now: clock.now);
    deposit = DepositToGoalUseCase(
      goalRepository: goalRepo,
      ledgerRepository: ledgerRepo,
      accountRepository: accountRepo,
      clock: clock,
      idGen: UuidV7(),
    );

    await accountRepo.create(Account(
      id: 'acc-cash', name: '现金', type: AccountType.cash,
      currency: 'CNY', openingBalance: 1000000, sortOrder: 0,
      createdAt: clock.now(), updatedAt: clock.now(), deviceId: deviceId,
    ));
  });

  tearDown(() => db.close());

  Future<SavingsGoal> makeGoal({String? accountId = 'acc-cash'}) async {
    final goal = SavingsGoal(
      id: 'g1', bookId: bookId, name: '车险',
      // 12 个月后到期，目标 3000 元
      targetCents: 300000, savedCents: 0,
      dueAt: DateTime.utc(2026, 12, 31),
      accountId: accountId,
      createdAt: clock.now(), updatedAt: clock.now(), deviceId: deviceId,
    );
    final r = await goalRepo.create(goal);
    expect(r.isSuccess, true, reason: r.failureOrNull?.toString() ?? '');
    return goal;
  }

  int statsExpenseCents() {
    final rows = db.raw.select(
        "SELECT COALESCE(SUM(expense_cents),0) AS s FROM daily_stats WHERE book_id = '$bookId'");
    return (rows.first['s'] as int?) ?? 0;
  }

  int statsIncomeCents() {
    final rows = db.raw.select(
        "SELECT COALESCE(SUM(income_cents),0) AS s FROM daily_stats WHERE book_id = '$bookId'");
    return (rows.first['s'] as int?) ?? 0;
  }

  test('AC1: monthly required is derived from target and due date', () async {
    final goal = await makeGoal();
    // 1 月存到 12 月 = 12 个月；3000 / 12 = 250
    expect(goal.monthlyRequiredCentsAt(clock.now()), 25000);
  });

  test('AC2/AC3: deposit credits the goal and leaves 收支 untouched', () async {
    await makeGoal();
    final r = await deposit(goalId: 'g1', amountCents: 25000, deviceId: deviceId);
    expect(r.isSuccess, true, reason: r.failureOrNull?.toString() ?? '');

    final after = (await goalRepo.getById('g1')).successOrNull!;
    expect(after.savedCents, 25000);
    expect(after.progress, closeTo(0.083, 0.001)); // 250 / 3000

    // AC3：内部转账不计入收支
    expect(statsExpenseCents(), 0);
    expect(statsIncomeCents(), 0);
    expect((await ledgerRepo.verifyDailyStats()).successOrNull, true);
  });

  test('the deposit is a real transfer: both account balances move', () async {
    await makeGoal();
    await deposit(goalId: 'g1', amountCents: 25000, deviceId: deviceId);

    final goalAccountId = (await goalRepo.getById('g1')).successOrNull!.goalAccountId!;
    expect(goalAccountId, isNotEmpty);

    // 转出端减少
    final cash = await accountRepo.balanceOf('acc-cash');
    expect(cash.successOrNull!.balanceCents, 1000000 - 25000);
    // 转入端（目标虚拟账户）持有这笔预留
    final bucket = await accountRepo.balanceOf(goalAccountId);
    expect(bucket.successOrNull!.balanceCents, 25000);

    // 转账类型 → 出现在流水里，但不算收支
    final tx = db.raw.select(
        "SELECT type, to_account_id FROM transactions WHERE book_id = '$bookId'");
    expect(tx, hasLength(1));
    expect(tx.first['type'], 'transfer');
    expect(tx.first['to_account_id'], goalAccountId);
  });

  test('subsequent deposits reuse the same virtual account', () async {
    await makeGoal();
    await deposit(goalId: 'g1', amountCents: 25000, deviceId: deviceId);
    final first = (await goalRepo.getById('g1')).successOrNull!.goalAccountId;

    await deposit(goalId: 'g1', amountCents: 10000, deviceId: deviceId);
    final second = (await goalRepo.getById('g1')).successOrNull!.goalAccountId;

    expect(second, first);
    // 只应有一个虚拟账户
    final virtuals = db.raw.select(
        "SELECT COUNT(*) AS c FROM accounts WHERE type = 'goal'");
    expect(virtuals.first['c'], 1);
    expect((await goalRepo.getById('g1')).successOrNull!.savedCents, 35000);
  });

  test('deposit without a linked account is rejected', () async {
    await makeGoal(accountId: null);
    final r = await deposit(goalId: 'g1', amountCents: 25000, deviceId: deviceId);
    expect(r.isFailure, true);
    expect(r.failureOrNull!.code, 'goal.account_required');
  });

  test('the virtual account is not a user-selectable account type', () {
    expect(AccountType.goal.isVirtual, true);
    expect(AccountType.goal.enabledInV1, false);
    expect(AccountType.cash.isVirtual, false);
  });

  test('AC4: overdue goal keeps its data and reports overdue', () async {
    await makeGoal();
    final goal = (await goalRepo.getById('g1')).successOrNull!;
    // 截止日之后仍未达成
    expect(goal.isOverdueAt(DateTime.utc(2027, 6, 1)), true);
    expect(goal.isAchieved, false);
    // 数据保留、可改期
    final extended = await goalRepo.update(goal.copyWith(
      dueAt: DateTime.utc(2028, 1, 1),
      updatedAt: clock.now(),
      revision: goal.revision + 1,
    ));
    expect(extended.isSuccess, true);
    expect(
      (await goalRepo.getById('g1')).successOrNull!.isOverdueAt(DateTime.utc(2027, 6, 1)),
      false,
    );
  });
}
