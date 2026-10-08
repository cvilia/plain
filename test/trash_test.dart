/// Trash (recycle bin) tests: list deleted, restore, hard delete, purge expired.
library;
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

  Future<String> makeEntry({String amount = '25'}) async {
    final r = await createEntry(CreateEntryInput(
      amountExpression: amount, type: EntryType.expense,
      categoryId: 'cat-food', accountId: 'acc-cash',
      bookId: 'book-1', deviceId: 'dev-1',
    ));
    return r.successOrNull!.id;
  }

  test('listDeleted returns soft-deleted entries', () async {
    final id = await makeEntry();
    await repo.softDelete(id);
    final res = await repo.listDeleted(bookId: 'book-1');
    expect(res.successOrNull!.length, 1);
    expect(res.successOrNull!.first.id, id);
  });

  test('listDeleted excludes live entries', () async {
    await makeEntry();
    final res = await repo.listDeleted(bookId: 'book-1');
    expect(res.successOrNull, isEmpty);
  });

  test('restore clears deletedAt and returns entry to page', () async {
    final id = await makeEntry();
    await repo.softDelete(id);

    final restored = await repo.restore(id);
    expect(restored.isSuccess, true);
    expect(restored.successOrNull!.deletedAt, isNull);

    final page = await repo.listPage(limit: 10);
    expect(page.successOrNull!.items.length, 1);
  });

  test('restore re-adds daily_stats', () async {
    final id = await makeEntry(amount: '25');
    await repo.softDelete(id);

    // Stats should be zero after delete
    var rows = db.raw.select(
        "SELECT SUM(expense_cents) AS s FROM daily_stats WHERE book_id = 'book-1'");
    expect((rows.first['s'] as int?) ?? 0, 0);

    await repo.restore(id);
    rows = db.raw.select(
        "SELECT SUM(expense_cents) AS s FROM daily_stats WHERE book_id = 'book-1'");
    expect(rows.first['s'], 2500);
  });

  test('restore on live entry fails', () async {
    final id = await makeEntry();
    final res = await repo.restore(id);
    expect(res.isFailure, true);
  });

  test('hardDelete removes row permanently', () async {
    final id = await makeEntry();
    await repo.softDelete(id);
    final res = await repo.hardDelete(id);
    expect(res.isSuccess, true);

    final rows = db.raw.select('SELECT COUNT(*) AS c FROM transactions');
    expect(rows.first['c'], 0);
  });

  test('hardDelete on live entry fails', () async {
    final id = await makeEntry();
    final res = await repo.hardDelete(id);
    expect(res.isFailure, true);
  });

  test('purgeExpired removes only rows older than cutoff', () async {
    final id1 = await makeEntry(amount: '10');
    await repo.softDelete(id1); // deleted_at = T0

    clock.advance(const Duration(days: 31));
    final id2 = await makeEntry(amount: '20');
    await repo.softDelete(id2); // deleted_at = T0+31d

    // cutoff = now-30d = T0+1d → id1 (T0) purged, id2 (T0+31d) stays
    final cutoff = clock.now().subtract(const Duration(days: 30));
    final purged = await repo.purgeExpired(before: cutoff);
    expect(purged.successOrNull, 1);

    final remaining = await repo.listDeleted(bookId: 'book-1');
    expect(remaining.successOrNull!.length, 1);
    expect(remaining.successOrNull!.first.id, id2);
  });

  test('purgeTrash use case uses 30-day TTL', () async {
    final purge = PurgeTrashUseCase(repository: repo, clock: clock);
    final id = await makeEntry();
    await repo.softDelete(id);

    // Not yet expired
    var res = await purge();
    expect(res.successOrNull, 0);

    clock.advance(const Duration(days: 31));
    res = await purge();
    expect(res.successOrNull, 1);

    final rows = db.raw.select('SELECT COUNT(*) AS c FROM transactions');
    expect(rows.first['c'], 0);
  });

  test('restore bumps revision and writes change_log', () async {
    final id = await makeEntry();
    await repo.softDelete(id);
    final before = db.raw.select('SELECT COUNT(*) AS c FROM change_log').first['c'] as int;

    await repo.restore(id);
    final after = db.raw.select('SELECT COUNT(*) AS c FROM change_log').first['c'] as int;
    expect(after, before + 1);

    final entry = await repo.getById(id);
    expect(entry.successOrNull!.revision, 3); // create=1, delete=2, restore=3
    expect(entry.successOrNull!.deletedAt, isNull);
  });
}
