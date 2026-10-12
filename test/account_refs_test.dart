/// STORY-2.1 AC6：账户引用检查与迁移。
library;
import 'package:flutter_test/flutter_test.dart';
import 'package:plain/core/id/uuid_v7.dart';
import 'package:plain/core/time/clock.dart';
import 'package:plain/data/db/database.dart';
import 'package:plain/data/repositories/account_repository.dart';
import 'package:plain/data/repositories/ledger_repository.dart';
import 'package:plain/data/sync/change_log_writer.dart';
import 'package:plain/domain/entities/category.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/usecases/entry_usecases.dart';

void main() {
  late AppDatabase db;
  late FixedClock clock;
  late AccountRepositoryImpl accountRepo;
  late CreateEntryUseCase createEntry;

  setUp(() async {
    db = AppDatabase.inMemory();
    clock = FixedClock(DateTime.utc(2026, 9, 29, 12));
    final changeLog = ChangeLogWriter(db);
    accountRepo = AccountRepositoryImpl(db: db, changeLogWriter: changeLog, clock: clock);
    final ledgerRepo = LedgerRepositoryImpl(db: db, changeLogWriter: changeLog, clock: clock);
    createEntry = CreateEntryUseCase(repository: ledgerRepo, clock: clock, idGen: UuidV7());
    for (final id in ['acc-a', 'acc-b']) {
      await accountRepo.create(Account(
        id: id, name: id, type: AccountType.cash,
        currency: 'CNY', openingBalance: 0, sortOrder: 0,
        createdAt: clock.now(), updatedAt: clock.now(), deviceId: 'dev-1',
      ));
    }
  });

  tearDown(() => db.close());

  test('countReferences reports transactions and transfers', () async {
    await createEntry(CreateEntryInput(
      amountExpression: '10', type: EntryType.expense,
      categoryId: 'cat-food', accountId: 'acc-a',
      bookId: 'book-1', deviceId: 'dev-1',
    ));
    await createEntry(CreateEntryInput(
      amountExpression: '5', type: EntryType.transfer,
      categoryId: '', accountId: 'acc-a', toAccountId: 'acc-b',
      bookId: 'book-1', deviceId: 'dev-1',
    ));

    final a = await accountRepo.countReferences('acc-a');
    expect(a.successOrNull!.transactions, 2); // expense + transfer out
    final b = await accountRepo.countReferences('acc-b');
    expect(b.successOrNull!.transferIn, 1);
  });

  test('migrateTransactions moves both sides', () async {
    await createEntry(CreateEntryInput(
      amountExpression: '10', type: EntryType.expense,
      categoryId: 'cat-food', accountId: 'acc-a',
      bookId: 'book-1', deviceId: 'dev-1',
    ));
    final moved = await accountRepo.migrateTransactions(fromId: 'acc-a', toId: 'acc-b');
    expect(moved.isSuccess, true);
    expect(moved.successOrNull, 1);
    final a = await accountRepo.countReferences('acc-a');
    expect(a.successOrNull!.isEmpty, true);
  });

  test('softDelete blocked when references exist', () async {
    await createEntry(CreateEntryInput(
      amountExpression: '10', type: EntryType.expense,
      categoryId: 'cat-food', accountId: 'acc-a',
      bookId: 'book-1', deviceId: 'dev-1',
    ));
    final del = await accountRepo.softDelete('acc-a');
    expect(del.isFailure, true);
  });

  test('softDelete ok when no references', () async {
    final del = await accountRepo.softDelete('acc-b');
    expect(del.isSuccess, true);
  });

  test('detachFromAccount clears account_id then softDelete succeeds', () async {
    await createEntry(CreateEntryInput(
      amountExpression: '10', type: EntryType.expense,
      categoryId: 'cat-food', accountId: 'acc-a',
      bookId: 'book-1', deviceId: 'dev-1',
    ));
    await createEntry(CreateEntryInput(
      amountExpression: '5', type: EntryType.transfer,
      categoryId: '', accountId: 'acc-a', toAccountId: 'acc-b',
      bookId: 'book-1', deviceId: 'dev-1',
    ));

    // 有引用时不能直接删
    final del1 = await accountRepo.softDelete('acc-a');
    expect(del1.isFailure, isTrue);

    // 改为不指定账户后可以删
    final detached = await accountRepo.detachFromAccount('acc-a');
    expect(detached.isSuccess, isTrue);
    expect(detached.successOrNull, 2); // expense + transfer

    final refs = await accountRepo.countReferences('acc-a');
    expect(refs.successOrNull!.isEmpty, isTrue);

    final del2 = await accountRepo.softDelete('acc-a');
    expect(del2.isSuccess, isTrue);
  });

  test('detachFromAccount returns 0 when no references', () async {
    final detached = await accountRepo.detachFromAccount('acc-b');
    expect(detached.isSuccess, isTrue);
    expect(detached.successOrNull, 0);
  });
}
