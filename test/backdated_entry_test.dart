/// 回归：今天之前的账单写入后，列表与月报必须能读到（刷新问题）。
library;
import 'package:flutter_test/flutter_test.dart';
import 'package:plain/core/id/uuid_v7.dart';
import 'package:plain/core/time/clock.dart';
import 'package:plain/data/db/database.dart';
import 'package:plain/data/repositories/ledger_repository.dart';
import 'package:plain/data/sync/change_log_writer.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/repositories/repositories.dart';
import 'package:plain/domain/usecases/entry_usecases.dart';

void main() {
  late AppDatabase db;
  late FixedClock clock;
  late LedgerRepositoryImpl ledgerRepo;
  late CreateEntryUseCase createEntry;

  setUp(() async {
    db = AppDatabase.inMemory();
    // 「今天」= 2026-09-29
    clock = FixedClock(DateTime.utc(2026, 9, 29, 12));
    final changeLog = ChangeLogWriter(db, clock: clock);
    ledgerRepo = LedgerRepositoryImpl(db: db, changeLogWriter: changeLog, clock: clock);
    createEntry = CreateEntryUseCase(repository: ledgerRepo, clock: clock, idGen: UuidV7());
  });

  tearDown(() => db.close());

  test('backdated expense appears in listPage and monthSummary', () async {
    // 记一笔「今天之前」的账：2026-09-20
    final past = DateTime.utc(2026, 9, 20, 3);
    final r = await createEntry(CreateEntryInput(
      amountExpression: '25',
      type: EntryType.expense,
      categoryId: 'cat-food',
      accountId: 'acc-a',
      bookId: 'book-1',
      deviceId: 'dev-1',
      occurredAt: past,
    ));
    expect(r.isSuccess, true);

    // 1) listPage 必须能查到（不管排序位置）
    final page = await ledgerRepo.listPage(
      filter: EntryFilter(bookId: 'book-1'),
      limit: 50,
    );
    final items = page.successOrNull!.items;
    expect(items.length, 1);
    expect(items.first.amount.cents, 2500);
    expect(items.first.occurredAt.toUtc(), past);

    // 2) 当月报表必须计入
    final summary = await ledgerRepo.monthSummary(
      bookId: 'book-1',
      dayFrom: '2026-09-01',
      dayTo: '2026-09-30',
    );
    expect(summary.successOrNull!.expenseCents, 2500);
    expect(summary.successOrNull!.txCount, 1);
  });

  test('dayKey of backdated entry falls in its own day', () async {
    final past = DateTime.utc(2026, 9, 20, 3);
    await createEntry(CreateEntryInput(
      amountExpression: '25',
      type: EntryType.expense,
      categoryId: 'cat-food',
      accountId: 'acc-a',
      bookId: 'book-1',
      deviceId: 'dev-1',
      occurredAt: past,
    ));
    // 9 月 20 日分区
    final summary = await ledgerRepo.monthSummary(
      bookId: 'book-1',
      dayFrom: '2026-09-20',
      dayTo: '2026-09-20',
    );
    expect(summary.successOrNull!.expenseCents, 2500);
  });
}
