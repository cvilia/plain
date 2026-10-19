/// G-2 / C11：对账调整不得进入 daily_stats、分类统计与预算消耗。
library;
import 'package:flutter_test/flutter_test.dart';
import 'package:plain/app/l10n/strings_core.dart';
import 'package:plain/core/time/clock.dart';
import 'package:plain/data/db/database.dart';
import 'package:plain/data/repositories/account_repository.dart';
import 'package:plain/data/repositories/budget_repository.dart';
import 'package:plain/data/repositories/ledger_repository.dart';
import 'package:plain/data/sync/change_log_writer.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/entities/category.dart';
import 'package:plain/domain/usecases/entry_usecases.dart';
import 'package:plain/core/id/uuid_v7.dart';

void main() {
  late AppDatabase db;
  late FixedClock clock;
  late ChangeLogWriter changeLog;
  late LedgerRepositoryImpl ledgerRepo;
  late AccountRepositoryImpl accountRepo;
  late BudgetRepositoryImpl budgetRepo;
  late CreateEntryUseCase createEntry;

  setUp(() async {
    db = AppDatabase.inMemory();
    clock = FixedClock(DateTime.utc(2026, 9, 29, 12));
    changeLog = ChangeLogWriter(db);
    ledgerRepo = LedgerRepositoryImpl(db: db, changeLogWriter: changeLog, clock: clock);
    accountRepo = AccountRepositoryImpl(db: db, changeLogWriter: changeLog, clock: clock);
    budgetRepo = BudgetRepositoryImpl(db: db, changeLogWriter: changeLog, clock: clock);
    createEntry = CreateEntryUseCase(repository: ledgerRepo, clock: clock, idGen: UuidV7());
    // 对账依赖已存在的账户
    await accountRepo.create(Account(
      id: 'acc-cash', name: '现金', type: AccountType.cash,
      currency: 'CNY', openingBalance: 0, sortOrder: 0,
      createdAt: clock.now(), updatedAt: clock.now(), deviceId: 'dev-1',
    ));
  });

  tearDown(() => db.close());

  int statsExpenseCents() {
    final rows = db.raw.select(
        "SELECT COALESCE(SUM(expense_cents),0) AS s FROM daily_stats WHERE book_id = 'book-1'");
    return (rows.first['s'] as int?) ?? 0;
  }

  test('reconcile adjustment does not write daily_stats (C11)', () async {
    await createEntry(CreateEntryInput(
      amountExpression: '25', type: EntryType.expense,
      categoryId: 'cat-food', accountId: 'acc-cash',
      bookId: 'book-1', deviceId: 'dev-1',
    ), s: kDefaultAppStrings);
    expect(statsExpenseCents(), 2500);

    final r = await accountRepo.reconcile(
      accountId: 'acc-cash',
      actualBalanceCents: -1000, // 差额产生调整单
      deviceId: 'dev-1',
      bookId: 'book-1',
      otherCategoryId: 'cat-other',
    );
    expect(r.isSuccess, true, reason: r.failureOrNull?.toString() ?? '');

    // 对账后统计不变：调整单只修余额
    expect(statsExpenseCents(), 2500);

    // 但调整单本身已入账
    final tx = db.raw.select(
        "SELECT COUNT(*) AS c FROM transactions WHERE source = 'reconcile'");
    expect(tx.first['c'], 1);
  });

  test('budget spentCents excludes reconcile source (C11)', () async {
    await createEntry(CreateEntryInput(
      amountExpression: '25', type: EntryType.expense,
      categoryId: 'cat-food', accountId: 'acc-cash',
      bookId: 'book-1', deviceId: 'dev-1',
    ), s: kDefaultAppStrings);
    await accountRepo.reconcile(
      accountId: 'acc-cash',
      actualBalanceCents: -5000,
      deviceId: 'dev-1',
      bookId: 'book-1',
      otherCategoryId: 'cat-other',
    );

    final spent = await budgetRepo.spentCents(
      bookId: 'book-1',
      fromMs: DateTime.utc(2026, 9, 1).millisecondsSinceEpoch,
      toMs: DateTime.utc(2026, 10, 1).millisecondsSinceEpoch,
    );
    expect(spent.successOrNull, 2500); // 仅手动 25 元，不含对账调整
  });

  test('monthSummary unaffected by reconcile (C11)', () async {
    await createEntry(CreateEntryInput(
      amountExpression: '25', type: EntryType.expense,
      categoryId: 'cat-food', accountId: 'acc-cash',
      bookId: 'book-1', deviceId: 'dev-1',
    ), s: kDefaultAppStrings);
    await accountRepo.reconcile(
      accountId: 'acc-cash',
      actualBalanceCents: -999,
      deviceId: 'dev-1',
      bookId: 'book-1',
      otherCategoryId: 'cat-other',
    );
    final summary = await ledgerRepo.monthSummary(
        bookId: 'book-1', dayFrom: '2026-09-01', dayTo: '2026-09-30');
    expect(summary.successOrNull!.expenseCents, 2500);
    expect(summary.successOrNull!.txCount, 1);
  });

  test('verifyDailyStats detects drift and rebuild restores (C15)', () async {
    await createEntry(CreateEntryInput(
      amountExpression: '25', type: EntryType.expense,
      categoryId: 'cat-food', accountId: 'acc-cash',
      bookId: 'book-1', deviceId: 'dev-1',
    ), s: kDefaultAppStrings);
    expect((await ledgerRepo.verifyDailyStats()).successOrNull, true);

    // 人为污染：塞一行不该存在的统计
    db.raw.execute(
      'INSERT INTO daily_stats (book_id,day_key,category_id,account_id,expense_cents,income_cents,tx_count,updated_at) '
      "VALUES ('book-1','2026-09-29','cat-x','acc-x',100,0,1,0)",
    );
    expect((await ledgerRepo.verifyDailyStats()).successOrNull, false);

    final rebuilt = await ledgerRepo.rebuildDailyStats();
    expect(rebuilt.isSuccess, true);
    expect((await ledgerRepo.verifyDailyStats()).successOrNull, true);
    expect(statsExpenseCents(), 2500);

    final builtAt = db.raw.select(
        "SELECT value FROM app_meta WHERE key = 'stats.built_at'");
    expect(builtAt, isNotEmpty);
  });
}
