/// Entry use case integration tests (in-memory DB).
import 'package:flutter_test/flutter_test.dart';
import 'package:plain/core/id/uuid_v7.dart';
import 'package:plain/core/time/clock.dart';
import 'package:plain/data/db/database.dart';
import 'package:plain/data/repositories/ledger_repository.dart';
import 'package:plain/data/sync/change_log_writer.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/usecases/entry_usecases.dart';

void main() {
  late AppDatabase db;
  late CreateEntryUseCase createEntry;
  late LedgerRepositoryImpl repo;
  late FixedClock clock;

  setUp(() {
    db = AppDatabase.inMemory();
    clock = FixedClock(DateTime.utc(2026, 9, 29, 12));
    final changeLog = ChangeLogWriter(db);
    repo = LedgerRepositoryImpl(db: db, changeLogWriter: changeLog, clock: clock);
    createEntry = CreateEntryUseCase(repository: repo, clock: clock, idGen: UuidV7());
  });

  tearDown(() => db.close());

  test('create entry and query page', () async {
    final result = await createEntry(CreateEntryInput(
      amountExpression: '25', type: EntryType.expense,
      categoryId: 'cat-food', accountId: 'acc-cash',
      bookId: 'book-1', deviceId: 'dev-1',
    ));
    expect(result.isSuccess, true);
    final entry = result.successOrNull!;
    expect(entry.amount.cents, 2500);

    final page = await repo.listPage(limit: 10);
    expect(page.successOrNull!.items.length, 1);
  });

  test('expression 12.5+7.5 saves as 20.00', () async {
    final result = await createEntry(CreateEntryInput(
      amountExpression: '12.5+7.5', type: EntryType.expense,
      categoryId: 'cat-food', bookId: 'book-1', deviceId: 'dev-1',
    ));
    expect(result.successOrNull!.amount.toYuanString(), '20.00');
  });

  test('zero amount rejected', () async {
    final result = await createEntry(CreateEntryInput(
      amountExpression: '0', type: EntryType.expense,
      categoryId: 'cat-food', bookId: 'book-1', deviceId: 'dev-1',
    ));
    expect(result.isFailure, true);
  });

  test('soft delete removes from page', () async {
    final created = await createEntry(CreateEntryInput(
      amountExpression: '25', type: EntryType.expense,
      categoryId: 'cat-food', bookId: 'book-1', deviceId: 'dev-1',
    ));
    final deleted = await repo.softDelete(created.successOrNull!.id);
    expect(deleted.isSuccess, true);
    final page = await repo.listPage(limit: 10);
    expect(page.successOrNull!.items, isEmpty);
  });

  test('change_log written on create', () async {
    await createEntry(CreateEntryInput(
      amountExpression: '25', type: EntryType.expense,
      categoryId: 'cat-food', bookId: 'book-1', deviceId: 'dev-1',
    ));
    final rows = db.raw.select('SELECT COUNT(*) AS c FROM change_log');
    expect(rows.first['c'], 1);
  });

  test('daily_stats maintained', () async {
    await createEntry(CreateEntryInput(
      amountExpression: '25', type: EntryType.expense,
      categoryId: 'cat-food', accountId: 'acc-cash',
      bookId: 'book-1', deviceId: 'dev-1',
    ));
    final summary = await repo.monthSummary(bookId: 'book-1', dayFrom: '2026-09-01', dayTo: '2026-09-30');
    expect(summary.successOrNull!.expenseCents, 2500);
    expect(summary.successOrNull!.txCount, 1);
  });
}
