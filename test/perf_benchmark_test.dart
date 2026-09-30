/// Performance benchmark tests. See 04-8.1, 04-11.
/// Measures expression eval, DB insert, query pagination.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:plain/core/id/uuid_v7.dart';
import 'package:plain/core/money/expression_evaluator.dart';
import 'package:plain/core/time/clock.dart';
import 'package:plain/data/db/database.dart';
import 'package:plain/data/repositories/ledger_repository.dart';
import 'package:plain/data/sync/change_log_writer.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/usecases/entry_usecases.dart';

void main() {
  group('Expression evaluator benchmarks', () {
    const eval = ExpressionEvaluator();

    test('simple expression 1000 iterations', () {
      final sw = Stopwatch()..start();
      for (var i = 0; i < 1000; i++) {
        eval.eval('12.5+7.5');
      }
      sw.stop();
      // Should complete in <100ms
      expect(sw.elapsedMilliseconds, lessThan(100));
    });

    test('complex expression 1000 iterations', () {
      final sw = Stopwatch()..start();
      for (var i = 0; i < 1000; i++) {
        eval.eval('(100-30)*2.5/5+12.5');
      }
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(100));
    });
  });

  group('Database benchmarks', () {
    late AppDatabase db;
    late LedgerRepositoryImpl repo;
    late CreateEntryUseCase createEntry;

    setUp(() {
      db = AppDatabase.inMemory();
      final clock = FixedClock(DateTime.utc(2026, 9, 29, 12));
      final changeLog = ChangeLogWriter(db);
      repo = LedgerRepositoryImpl(db: db, changeLogWriter: changeLog, clock: clock);
      createEntry = CreateEntryUseCase(repository: repo, clock: clock, idGen: UuidV7());
    });

    tearDown(() => db.close());

    test('insert 100 entries performance', () async {
      final sw = Stopwatch()..start();
      for (var i = 0; i < 100; i++) {
        await createEntry(CreateEntryInput(
          amountExpression: '${(i % 90) + 1}',
          type: i % 3 == 0 ? EntryType.income : EntryType.expense,
          categoryId: 'cat-${i % 12}',
          accountId: 'acc-${i % 3}',
          bookId: 'book-1',
          deviceId: 'dev-1',
        ));
      }
      sw.stop();
      // 100 inserts should complete in <2s
      expect(sw.elapsedMilliseconds, lessThan(2000));
    });

    test('query 100 entries page performance', () async {
      // Insert test data
      for (var i = 0; i < 100; i++) {
        await createEntry(CreateEntryInput(
          amountExpression: '${(i % 90) + 1}',
          type: EntryType.expense,
          categoryId: 'cat-${i % 12}',
          bookId: 'book-1',
          deviceId: 'dev-1',
        ));
      }

      final sw = Stopwatch()..start();
      final page = await repo.listPage(limit: 50);
      sw.stop();

      expect(page.successOrNull!.items.length, 50);
      // Query should complete in <100ms
      expect(sw.elapsedMilliseconds, lessThan(100));
    });

    test('month summary performance', () async {
      for (var i = 0; i < 50; i++) {
        await createEntry(CreateEntryInput(
          amountExpression: '${(i % 90) + 1}',
          type: EntryType.expense,
          categoryId: 'cat-${i % 12}',
          bookId: 'book-1',
          deviceId: 'dev-1',
        ));
      }

      final sw = Stopwatch()..start();
      final summary = await repo.monthSummary(
        bookId: 'book-1',
        dayFrom: '2026-09-01',
        dayTo: '2026-09-30',
      );
      sw.stop();

      expect(summary.isSuccess, true);
      // Summary should complete in <50ms
      expect(sw.elapsedMilliseconds, lessThan(50));
    });

    test('UUID generation 1000 iterations', () {
      final gen = UuidV7();
      final sw = Stopwatch()..start();
      for (var i = 0; i < 1000; i++) {
        gen.generate();
      }
      sw.stop();
      // 1000 UUIDs in <100ms
      expect(sw.elapsedMilliseconds, lessThan(100));
    });
  });
}
