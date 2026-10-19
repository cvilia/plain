/// STORY-1.7：借出 / 借入的余额口径与统计口径。
///
/// G-2 表规定：借出 / 借入**计入账户余额**，但**不计入收支、不进行业分类统计**。
/// 借出是钱离开所选账户、借入是钱进入所选账户（方向与转出/转入一致）。
library;
import 'package:flutter_test/flutter_test.dart';
import 'package:plain/app/l10n/strings_core.dart';
import 'package:plain/core/id/uuid_v7.dart';
import 'package:plain/core/money/money.dart';
import 'package:plain/core/time/clock.dart';
import 'package:plain/data/db/database.dart';
import 'package:plain/data/repositories/account_repository.dart';
import 'package:plain/data/repositories/ledger_repository.dart';
import 'package:plain/data/sync/change_log_writer.dart';
import 'package:plain/domain/entities/category.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/entities/ledger_entry.dart';
import 'package:plain/domain/services/net_worth_service.dart';
import 'package:plain/domain/usecases/entry_usecases.dart';

void main() {
  late AppDatabase db;
  late FixedClock clock;
  late LedgerRepositoryImpl ledgerRepo;
  late AccountRepositoryImpl accountRepo;
  late CreateEntryUseCase createEntry;

  setUp(() async {
    db = AppDatabase.inMemory();
    clock = FixedClock(DateTime.utc(2026, 10, 15, 12));
    final changeLog = ChangeLogWriter(db, clock: clock);
    ledgerRepo = LedgerRepositoryImpl(db: db, changeLogWriter: changeLog, clock: clock);
    accountRepo = AccountRepositoryImpl(db: db, changeLogWriter: changeLog, clock: clock);
    createEntry = CreateEntryUseCase(repository: ledgerRepo, clock: clock, idGen: UuidV7());

    // 现金账户 5000 元
    await accountRepo.create(Account(
      id: 'acc-cash', name: '现金', type: AccountType.cash,
      currency: 'CNY', openingBalance: 500000, sortOrder: 0,
      createdAt: clock.now(), updatedAt: clock.now(), deviceId: 'dev-1',
    ));
    // 信用卡（额度 2 万，初始无欠款）
    await accountRepo.create(Account(
      id: 'acc-credit', name: '信用卡', type: AccountType.credit,
      currency: 'CNY', openingBalance: 0, sortOrder: 1,
      creditLimitCents: 2000000, creditDebtCents: 0,
      createdAt: clock.now(), updatedAt: clock.now(), deviceId: 'dev-1',
    ));
  });

  tearDown(() => db.close());

  int statsExpenseCents() {
    final rows = db.raw.select(
        "SELECT COALESCE(SUM(expense_cents),0) AS s FROM daily_stats WHERE book_id = 'book-1'");
    return (rows.first['s'] as int?) ?? 0;
  }

  Future<int> statsTxCount() async {
    final rows = db.raw.select(
        "SELECT COALESCE(SUM(tx_count),0) AS c FROM daily_stats WHERE book_id = 'book-1'");
    return (rows.first['c'] as int?) ?? 0;
  }

  test('借出使所选账户余额减少，但不计入收支', () async {
    final r = await createEntry(CreateEntryInput(
      amountExpression: '1000',
      type: EntryType.borrowOut,
      categoryId: '',
      accountId: 'acc-cash',
      note: '借给张三',
      bookId: 'book-1',
      deviceId: 'dev-1',
    ), s: kDefaultAppStrings);
    expect(r.isSuccess, true, reason: r.failureOrNull?.toString() ?? '');

    final bal = await accountRepo.balanceOf('acc-cash');
    expect(bal.successOrNull!.balanceCents, 500000 - 100000);
    // G-2：不计入收支与分类统计
    expect(statsExpenseCents(), 0);
    expect(await statsTxCount(), 0);
    expect((await ledgerRepo.verifyDailyStats()).successOrNull, true);
  });

  test('借入使所选账户余额增加，但不计入收支', () async {
    await createEntry(CreateEntryInput(
      amountExpression: '1000',
      type: EntryType.borrowIn,
      categoryId: '',
      accountId: 'acc-cash',
      note: '向李四借',
      bookId: 'book-1',
      deviceId: 'dev-1',
    ), s: kDefaultAppStrings);
    final bal = await accountRepo.balanceOf('acc-cash');
    expect(bal.successOrNull!.balanceCents, 500000 + 100000);
    expect(statsExpenseCents(), 0);
    expect(await statsTxCount(), 0);
  });

  test('借出/借入都要有往来对象（备注）', () async {
    final r = await createEntry(CreateEntryInput(
      amountExpression: '1000',
      type: EntryType.borrowOut,
      categoryId: '',
      accountId: 'acc-cash',
      bookId: 'book-1',
      deviceId: 'dev-1',
    ), s: kDefaultAppStrings);
    expect(r.isFailure, true);
    expect(r.failureOrNull!.code, 'entry.borrow_counterparty_required');
  });

  test('删除借出记账后余额回滚', () async {
    final created = await createEntry(CreateEntryInput(
      amountExpression: '1000',
      type: EntryType.borrowOut,
      categoryId: '',
      accountId: 'acc-cash',
      note: '借给张三',
      bookId: 'book-1',
      deviceId: 'dev-1',
    ), s: kDefaultAppStrings);
    await ledgerRepo.softDelete(created.successOrNull!.id);
    final bal = await accountRepo.balanceOf('acc-cash');
    expect(bal.successOrNull!.balanceCents, 500000);
  });

  test('列表余额与单账户余额口径一致（借出计入）', () async {
    await createEntry(CreateEntryInput(
      amountExpression: '700',
      type: EntryType.borrowOut,
      categoryId: '',
      accountId: 'acc-cash',
      note: '借出',
      bookId: 'book-1',
      deviceId: 'dev-1',
    ), s: kDefaultAppStrings);
    final list = (await accountRepo.listWithBalances()).successOrNull!;
    final cash = list.firstWhere((a) => a.account.id == 'acc-cash');
    expect(cash.balanceCents, 500000 - 70000);
    final single = await accountRepo.balanceOf('acc-cash');
    expect(single.successOrNull!.balanceCents, cash.balanceCents);
  });

  test('信用卡上记借出会推高欠款（与余额贡献取反一致）', () async {
    await createEntry(CreateEntryInput(
      amountExpression: '300',
      type: EntryType.borrowOut,
      categoryId: '',
      accountId: 'acc-credit',
      note: '刷卡借出',
      bookId: 'book-1',
      deviceId: 'dev-1',
    ), s: kDefaultAppStrings);
    final rows = db.raw.select(
        "SELECT credit_debt_cents AS d FROM accounts WHERE id = 'acc-credit'");
    expect(rows.first['d'], 30000);
    // 余额 = −欠款
    final bal = await accountRepo.balanceOf('acc-credit');
    expect(bal.successOrNull!.balanceCents, -30000);
  });

  test('净值历史点也认借出（balanceAt 与实时口径一致）', () async {
    await createEntry(CreateEntryInput(
      amountExpression: '250',
      type: EntryType.borrowOut,
      categoryId: '',
      accountId: 'acc-cash',
      note: '借出',
      bookId: 'book-1',
      deviceId: 'dev-1',
    ), s: kDefaultAppStrings);
    final page = await ledgerRepo.listPage(limit: 100);
    final entries = page.successOrNull!.items;
    final account = (await accountRepo.getById('acc-cash')).successOrNull!;

    final atNow = NetWorthService.balanceAt(
      account: account,
      entries: entries,
      asOf: clock.now().add(const Duration(days: 1)),
    );
    // 历史点用的口径必须与实时余额一致，否则净值曲线与资产页对不上
    expect(atNow, 500000 - 25000);

    // 借出之前的历史点不受影响
    final before = NetWorthService.balanceAt(
      account: account,
      entries: [
        LedgerEntry(
          id: 'x', bookId: 'book-1', type: EntryType.borrowOut,
          amount: Money(25000), currency: 'CNY', accountId: 'acc-cash',
          occurredAt: DateTime.utc(2026, 12, 1), source: EntrySource.manual,
          createdAt: clock.now(), updatedAt: clock.now(), deviceId: 'dev-1',
        ),
      ],
      asOf: clock.now(),
    );
    expect(before, 500000);
  });
}
