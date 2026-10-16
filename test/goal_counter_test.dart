/// 储蓄目标「已存」计数：按账本重算（幂等），而非按规则金额做减法。
///
/// 背景（audit 2026-10-15）：撤销批次与删账不是同一事务，减法在规则金额被改过、
/// 一期生成多笔、或撤销被重试时都会算错。计数是缓存，账本才是事实来源 ——
/// 能重算就不怕偏。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:plain/core/constants/app_constants.dart';
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
  const bookId = 'book-1';
  const deviceId = 'dev-1';

  late AppDatabase db;
  late FixedClock clock;
  late LedgerRepositoryImpl ledgerRepo;
  late SavingsGoalRepositoryImpl goalRepo;
  late AccountRepositoryImpl accountRepo;
  late DepositToGoalUseCase deposit;

  setUp(() async {
    db = AppDatabase.inMemory();
    clock = FixedClock(DateTime.utc(2026, 10, 15, 12));
    final changeLog = ChangeLogWriter(db, clock: clock);
    ledgerRepo = LedgerRepositoryImpl(db: db, changeLogWriter: changeLog, clock: clock);
    goalRepo = SavingsGoalRepositoryImpl(
        db: db, changeLogWriter: changeLog, now: clock.now);
    accountRepo = AccountRepositoryImpl(
        db: db, changeLogWriter: changeLog, clock: clock);
    deposit = DepositToGoalUseCase(
      goalRepository: goalRepo,
      ledgerRepository: ledgerRepo,
      accountRepository: accountRepo,
      clock: clock,
      idGen: UuidV7(),
    );

    await accountRepo.create(Account(
      id: 'acc-cash', name: '现金', type: AccountType.cash,
      currency: MoneyRules.defaultCurrency, openingBalance: 1000000, sortOrder: 0,
      createdAt: clock.now(), updatedAt: clock.now(), deviceId: deviceId,
    ));
    await goalRepo.create(SavingsGoal(
      id: 'g1', bookId: bookId, name: '车险', targetCents: 100000, savedCents: 0,
      accountId: 'acc-cash',
      createdAt: clock.now(), updatedAt: clock.now(), deviceId: deviceId,
    ));
  });

  tearDown(() => db.close());

  Future<int?> storedRecompute() async {
    final g = (await goalRepo.getById('g1')).requireValue;
    return reconcileStoredSavedCents(goal: g, ledger: ledgerRepo);
  }

  test('存入后：重算值 = 虚拟账户净流入 = 存储值', () async {
    final res = await deposit(goalId: 'g1', amountCents: 40000, deviceId: deviceId);
    expect(res.isSuccess, isTrue, reason: '${res.failureOrNull}');

    final stored = (await goalRepo.getById('g1')).requireValue.savedCents;
    expect(stored, 40000);
    expect(await storedRecompute(), 40000, reason: '账本与存储值一致');
  });

  test('删掉那笔「存入」转账后：重算回落到 0，且反复重算结果稳定（幂等）', () async {
    await deposit(goalId: 'g1', amountCents: 40000, deviceId: deviceId);

    final page = (await ledgerRepo.listPage(limit: 10)).requireValue;
    final entry = page.items.first;
    expect(entry.type, EntryType.transfer, reason: '存入是内部转账，不计入收支');
    expect((await ledgerRepo.softDelete(entry.id)).isSuccess, isTrue);

    expect(await storedRecompute(), 0, reason: '钱转回去了，计数必须能回落');
    // 幂等：这是「重算」相对「做减法」的关键差别 —— 重试不会算成负数
    expect(await storedRecompute(), 0);
    expect(await storedRecompute(), 0);
  });

  test('没有虚拟账户的老目标不做猜测（返回 null）', () async {
    final legacy = SavingsGoal(
      id: 'g-legacy', bookId: bookId, name: '老目标', targetCents: 50000,
      savedCents: 12345, accountId: 'acc-cash',
      createdAt: clock.now(), updatedAt: clock.now(), deviceId: deviceId,
    );
    expect(await reconcileStoredSavedCents(goal: legacy, ledger: ledgerRepo), isNull,
        reason: '没有目标账户就没有可追溯的转账，不猜、也不清零');
  });
}
