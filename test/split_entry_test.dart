/// STORY-6.2 分割交易：对平与统计口径。
library;
import 'package:flutter_test/flutter_test.dart';
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
import 'package:plain/domain/usecases/split_usecases.dart';

void main() {
  late AppDatabase db;
  late FixedClock clock;
  late LedgerRepositoryImpl ledgerRepo;
  late AccountRepositoryImpl accountRepo;
  late SplitEntryUseCase splitUseCase;

  setUp(() async {
    db = AppDatabase.inMemory();
    clock = FixedClock(DateTime.utc(2026, 9, 29, 12));
    final changeLog = ChangeLogWriter(db, clock: clock);
    ledgerRepo = LedgerRepositoryImpl(db: db, changeLogWriter: changeLog, clock: clock);
    accountRepo = AccountRepositoryImpl(db: db, changeLogWriter: changeLog, clock: clock);
    splitUseCase = SplitEntryUseCase(repository: ledgerRepo, clock: clock, idGen: UuidV7());
    await accountRepo.create(Account(
      id: 'acc-a', name: '现金', type: AccountType.cash,
      currency: 'CNY', openingBalance: 0, sortOrder: 0,
      createdAt: clock.now(), updatedAt: clock.now(), deviceId: 'dev-1',
    ));
    db.raw.execute(
      "INSERT INTO categories (id,name,kind,icon_ref,sort_order,is_hidden,is_preset,created_at,updated_at,device_id) "
      "VALUES ('c-food','食材','expense','other',0,0,0,0,0,'d'),('c-daily','日用','expense','other',1,0,0,0,0,'d')",
    );
  });

  tearDown(() => db.close());

  LedgerEntry makeParent(int cents) {
    return LedgerEntry(
      id: 'p1', bookId: 'book-1', type: EntryType.expense,
      amount: Money(cents), currency: 'CNY',
      categoryId: 'c-food', accountId: 'acc-a',
      occurredAt: clock.now(), note: '超市', source: EntrySource.manual,
      createdAt: clock.now(), updatedAt: clock.now(), deviceId: 'dev-1',
    );
  }

  test('split rejects unbalanced children (AC2)', () async {
    await ledgerRepo.create(makeParent(30000));
    final parent = (await ledgerRepo.getById('p1')).successOrNull!;
    final r = await splitUseCase.call(
      parent: parent,
      items: const [
        SplitItem(amountCents: 20000, categoryId: 'c-food'),
        SplitItem(amountCents: 8000, categoryId: 'c-daily'),
      ],
    );
    expect(r.isFailure, true);
  });

  test('split keeps category stats = children only (AC1/AC5)', () async {
    await ledgerRepo.create(makeParent(30000));
    final parent = (await ledgerRepo.getById('p1')).successOrNull!;
    final r = await splitUseCase.call(
      parent: parent,
      items: const [
        SplitItem(amountCents: 20000, categoryId: 'c-food'),
        SplitItem(amountCents: 10000, categoryId: 'c-daily'),
      ],
    );
    expect(r.isSuccess, true);

    final summary = await ledgerRepo.monthSummary(
      bookId: 'book-1', dayFrom: '2026-09-01', dayTo: '2026-09-30');
    final s = summary.successOrNull!;
    // AC4：支出合计 300，不是 380
    expect(s.expenseCents, 30000);
    // AC5：分类 200 / 100，父笔 300 不进分类
    expect(s.byCategory['c-food']?.expenseCents, 20000);
    expect(s.byCategory['c-daily']?.expenseCents, 10000);
  });

  test('balance uses parent only (AC3)', () async {
    await ledgerRepo.create(makeParent(30000));
    final parent = (await ledgerRepo.getById('p1')).successOrNull!;
    await splitUseCase.call(
      parent: parent,
      items: const [
        SplitItem(amountCents: 20000, categoryId: 'c-food'),
        SplitItem(amountCents: 10000, categoryId: 'c-daily'),
      ],
    );
    final bal = await accountRepo.balanceOf('acc-a');
    // 期初 0 - 父笔 300 = -300；若子笔也计会变成 -600
    expect(bal.successOrNull!.balanceCents, -30000);
  });
}
