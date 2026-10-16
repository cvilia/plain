/// Budget status and recurring engine tests (in-memory DB).
library;
import 'package:flutter_test/flutter_test.dart';
import 'package:plain/core/id/uuid_v7.dart';
import 'package:plain/core/money/money.dart';
import 'package:plain/core/time/clock.dart';
import 'package:plain/data/db/database.dart';
import 'package:plain/data/repositories/budget_repository.dart';
import 'package:plain/data/repositories/ledger_repository.dart';
import 'package:plain/data/repositories/recurring_repository.dart';
import 'package:plain/data/sync/change_log_writer.dart';
import 'package:plain/domain/entities/budget.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/entities/recurring_rule.dart';
import 'package:plain/domain/services/recurring_scheduler.dart';
import 'package:plain/domain/usecases/budget_usecases.dart';
import 'package:plain/domain/usecases/entry_usecases.dart';
import 'package:plain/domain/usecases/recurring_usecases.dart';

void main() {
  late AppDatabase db;
  late FixedClock clock;
  late BudgetRepositoryImpl budgetRepo;
  late RecurringRepositoryImpl recurringRepo;
  late LedgerRepositoryImpl ledgerRepo;
  late ChangeLogWriter changeLog;
  late UuidV7 idGen;

  setUp(() {
    db = AppDatabase.inMemory();
    clock = FixedClock(DateTime.utc(2026, 9, 30, 12));
    changeLog = ChangeLogWriter(db);
    budgetRepo = BudgetRepositoryImpl(db: db, changeLogWriter: changeLog, clock: clock);
    recurringRepo = RecurringRepositoryImpl(db: db, changeLogWriter: changeLog, clock: clock);
    ledgerRepo = LedgerRepositoryImpl(db: db, changeLogWriter: changeLog, clock: clock);
    idGen = UuidV7();
  });

  tearDown(() => db.close());

  Budget makeTotal({int cents = 500000}) => Budget(
    id: idGen.generate(), bookId: 'book-1', scope: BudgetScope.total,
    amount: Money(cents), createdAt: clock.now(), updatedAt: clock.now(),
    deviceId: 'dev-1',
  );

  group('Budget period window', () {
    test('start day 1 covers calendar month', () {
      final w = budgetPeriodWindow(today: DateTime(2026, 9, 15), startDay: 1);
      expect(w.start, DateTime(2026, 9, 1));
      expect(w.end, DateTime(2026, 10, 1));
    });

    test('before start day rolls to previous month', () {
      final w = budgetPeriodWindow(today: DateTime(2026, 9, 10), startDay: 15);
      expect(w.start, DateTime(2026, 8, 15));
      expect(w.end, DateTime(2026, 9, 15));
    });

    test('on start day starts that month', () {
      final w = budgetPeriodWindow(today: DateTime(2026, 9, 15), startDay: 15);
      expect(w.start, DateTime(2026, 9, 15));
      expect(w.end, DateTime(2026, 10, 15));
    });
  });

  group('Budget repository + status', () {
    test('create total budget and resolve status', () async {
      final created = await budgetRepo.create(makeTotal(cents: 100000));
      expect(created.isSuccess, true);

      final createEntry = CreateEntryUseCase(repository: ledgerRepo, clock: clock, idGen: idGen);
      await createEntry(CreateEntryInput(
        amountExpression: '100', type: EntryType.expense,
        categoryId: 'cat-food', accountId: 'acc-1',
        bookId: 'book-1', deviceId: 'dev-1',
        occurredAt: DateTime.utc(2026, 9, 20),
      ));

      final useCase = ResolveBudgetStatusUseCase(repository: budgetRepo, clock: clock);
      final statusRes = await useCase.totalStatus('book-1');
      expect(statusRes.isSuccess, true);
      final status = statusRes.successOrNull;
      expect(status, isNotNull);
      expect(status!.spentCents, 10000);
      expect(status.limitCents, 100000);
      expect(status.remainingCents, 90000);
      expect(status.level, BudgetLevel.ok);
    });

    test('80% threshold is warn, 100% is over', () async {
      await budgetRepo.create(makeTotal(cents: 10000));
      final createEntry = CreateEntryUseCase(repository: ledgerRepo, clock: clock, idGen: idGen);
      await createEntry(CreateEntryInput(
        amountExpression: '80', type: EntryType.expense,
        categoryId: 'cat-food', bookId: 'book-1', deviceId: 'dev-1',
        occurredAt: DateTime.utc(2026, 9, 10),
      ));
      final useCase = ResolveBudgetStatusUseCase(repository: budgetRepo, clock: clock);
      var status = (await useCase.totalStatus('book-1')).successOrNull!;
      expect(status.level, BudgetLevel.warn);

      await createEntry(CreateEntryInput(
        amountExpression: '30', type: EntryType.expense,
        categoryId: 'cat-food', bookId: 'book-1', deviceId: 'dev-1',
        occurredAt: DateTime.utc(2026, 9, 11),
      ));
      status = (await useCase.totalStatus('book-1')).successOrNull!;
      expect(status.level, BudgetLevel.over);
      expect(status.isOver, true);
    });

    test('daily available uses remaining days', () async {
      // Fixed clock: 2026-09-30 → 2 days left in September (30, 31) with startDay=1.
      await budgetRepo.create(makeTotal(cents: 100000));
      final useCase = ResolveBudgetStatusUseCase(repository: budgetRepo, clock: clock);
      final status = (await useCase.totalStatus('book-1')).successOrNull!;
      expect(status.daysLeft, 2);
      expect(status.dailyAvailableCents, 50000);
    });

    test('duplicate total budget rejected', () async {
      await budgetRepo.create(makeTotal());
      final second = await budgetRepo.create(makeTotal());
      expect(second.isFailure, true);
    });

    test('category budget spent includes child categories', () async {
      final catBudget = Budget(
        id: idGen.generate(), bookId: 'book-1', scope: BudgetScope.category,
        categoryId: 'cat-parent', amount: Money(100000),
        createdAt: clock.now(), updatedAt: clock.now(), deviceId: 'dev-1',
      );
      await budgetRepo.create(catBudget);
      // Seed parent + child categories
      db.raw.execute(
        "INSERT INTO categories (id,parent_id,name,kind,icon_ref,sort_order,is_hidden,is_preset,created_at,updated_at,device_id) "
        "VALUES ('cat-parent',NULL,'Food','expense','food',0,0,1,0,0,'dev-1'),"
        "('cat-child','cat-parent','Lunch','expense','food',1,0,1,0,0,'dev-1')");
      final createEntry = CreateEntryUseCase(repository: ledgerRepo, clock: clock, idGen: idGen);
      await createEntry(CreateEntryInput(
        amountExpression: '50', type: EntryType.expense,
        categoryId: 'cat-child', bookId: 'book-1', deviceId: 'dev-1',
        occurredAt: DateTime.utc(2026, 9, 5),
      ));
      final spent = await budgetRepo.spentCents(
        bookId: 'book-1', categoryId: 'cat-parent',
        fromMs: DateTime.utc(2026, 9, 1).millisecondsSinceEpoch,
        toMs: DateTime.utc(2026, 10, 1).millisecondsSinceEpoch);
      expect(spent.successOrNull, 5000);
    });
  });

  group('RecurringScheduler', () {
    const scheduler = RecurringScheduler();

    test('short month clamps 31 to 28 in Feb', () {
      final d = scheduler.resolveAnchor(2026, 2, 31, RecurringSkipStrategy.clamp);
      expect(d, DateTime(2026, 2, 28));
    });

    test('short month skip returns null', () {
      final d = scheduler.resolveAnchor(2026, 2, 31, RecurringSkipStrategy.skip);
      expect(d, isNull);
    });

    test('monthly 31st after Jan 31 goes to Feb 28 then Mar 31', () {
      final rule = RecurringRule(
        id: 'r', bookId: 'b', frequency: RecurringFrequency.monthly,
        anchorDay: 31, nextRunAt: DateTime.utc(2026, 1, 31),
        entryType: EntryType.expense, amount: Money(100),
        createdAt: DateTime.utc(2026, 1, 1), updatedAt: DateTime.utc(2026, 1, 1),
        deviceId: 'd',
      );
      final feb = scheduler.nextAfter(rule, DateTime.utc(2026, 1, 31, 12));
      expect(feb!.toLocal(), DateTime(2026, 2, 28));
      final mar = scheduler.nextAfter(
        rule.copyWith(nextRunAt: feb), feb);
      expect(mar!.toLocal(), DateTime(2026, 3, 31));
    });

    test('count end type finishes after N generations', () {
      final rule = RecurringRule(
        id: 'r', bookId: 'b', frequency: RecurringFrequency.daily,
        nextRunAt: DateTime.utc(2026, 9, 30), entryType: EntryType.expense,
        amount: Money(100), endType: RecurringEndType.count, endCount: 2,
        generatedCount: 1,
        createdAt: DateTime.utc(2026, 9, 1), updatedAt: DateTime.utc(2026, 9, 1),
        deviceId: 'd',
      );
      expect(rule.isFinished, false);
      expect(rule.copyWith(generatedCount: 2).isFinished, true);
    });

    test('until end type blocks past end date', () {
      final rule = RecurringRule(
        id: 'r', bookId: 'b', frequency: RecurringFrequency.daily,
        nextRunAt: DateTime.utc(2026, 9, 30), entryType: EntryType.expense,
        amount: Money(100), endType: RecurringEndType.until,
        endAt: DateTime.utc(2026, 10, 1),
        createdAt: DateTime.utc(2026, 9, 1), updatedAt: DateTime.utc(2026, 9, 1),
        deviceId: 'd',
      );
      expect(scheduler.nextAfter(rule, DateTime.utc(2026, 9, 30)), isNotNull);
      expect(scheduler.nextAfter(rule, DateTime.utc(2026, 10, 5)), isNull);
    });
  });

  group('Recurring generation', () {
    test('due rule generates entry with source=recurring and batch id', () async {
      final createRule = CreateRecurringRuleUseCase(
        repository: recurringRepo, clock: clock, idGen: idGen);
      final ruleRes = await createRule(CreateRecurringRuleInput(
        bookId: 'book-1', deviceId: 'dev-1',
        frequency: RecurringFrequency.monthly, anchorDay: 30,
        entryType: EntryType.expense, amountCents: 20000,
        categoryId: 'cat-rent', accountId: 'acc-1',
        name: '房租', firstRunAt: DateTime.utc(2026, 9, 30),
      ));
      expect(ruleRes.isSuccess, true);

      final generate = GenerateDueRecurringUseCase(
        recurringRepository: recurringRepo, ledgerRepository: ledgerRepo,
        clock: clock, idGen: idGen);
      final result = await generate();
      expect(result.isSuccess, true);
      final gen = result.requireValue;
      expect(gen.created.length, 1);
      expect(gen.created.first.source, EntrySource.recurring);
      expect(gen.created.first.batchId, isNotNull);
      expect(gen.created.first.amount.cents, 20000);

      final ruleAfter = (await recurringRepo.getById(ruleRes.requireValue.id)).requireValue;
      expect(ruleAfter.generatedCount, 1);
      expect(ruleAfter.lastBatchId, gen.created.first.batchId);
    });

    test('batch undo soft-deletes generated entries', () async {
      final createRule = CreateRecurringRuleUseCase(
        repository: recurringRepo, clock: clock, idGen: idGen);
      await createRule(CreateRecurringRuleInput(
        bookId: 'book-1', deviceId: 'dev-1',
        frequency: RecurringFrequency.daily,
        entryType: EntryType.expense, amountCents: 100,
        categoryId: 'cat', firstRunAt: DateTime.utc(2026, 9, 30),
      ));
      final generate = GenerateDueRecurringUseCase(
        recurringRepository: recurringRepo, ledgerRepository: ledgerRepo,
        clock: clock, idGen: idGen);
      final gen = (await generate()).requireValue;
      final batchId = gen.created.first.batchId!;

      final undo = UndoRecurringBatchUseCase(repository: ledgerRepo, clock: clock);
      final undone = await undo(batchId);
      expect(undone.successOrNull, 1);

      final page = await ledgerRepo.listPage(limit: 10);
      expect(page.successOrNull!.items, isEmpty);
    });

    test('edit rule does not touch already generated entries', () async {
      final createRule = CreateRecurringRuleUseCase(
        repository: recurringRepo, clock: clock, idGen: idGen);
      final rule = (await createRule(CreateRecurringRuleInput(
        bookId: 'book-1', deviceId: 'dev-1',
        frequency: RecurringFrequency.daily,
        entryType: EntryType.expense, amountCents: 100,
        categoryId: 'cat', firstRunAt: DateTime.utc(2026, 9, 30),
      ))).requireValue;
      final generate = GenerateDueRecurringUseCase(
        recurringRepository: recurringRepo, ledgerRepository: ledgerRepo,
        clock: clock, idGen: idGen);
      await generate();

      final updated = rule.copyWith(amount: Money(99900));
      await recurringRepo.update(updated);
      final page = await ledgerRepo.listPage(limit: 10);
      expect(page.successOrNull!.items.single.amount.cents, 100);
    });
  });

  group('Schema migration', () {
    test('budgets and recurring_rules tables exist', () {
      final t = db.raw.select(
        "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('budgets','recurring_rules')");
      expect(t.length, 2);
    });

    test('transactions has batch_id column', () {
      final cols = db.raw.select('PRAGMA table_info(transactions)');
      expect(cols.any((r) => r['name'] == 'batch_id'), true);
    });

    test('v4 adds split_role / parent_id / is_rigid with safe defaults', () {
      final tx = db.raw.select('PRAGMA table_info(transactions)');
      expect(tx.any((r) => r['name'] == 'split_role'), true);
      expect(tx.any((r) => r['name'] == 'parent_id'), true);
      final cat = db.raw.select('PRAGMA table_info(categories)');
      expect(cat.any((r) => r['name'] == 'is_rigid'), true);
      final ver = db.raw.select('PRAGMA user_version').first.values.first;
      // 断言当前版本常量而非字面量，迁移加版本时不必改这里
      expect(ver, kSchemaVersion);
    });

    test('v4 index idx_entry_parent exists', () {
      final idx = db.raw.select(
        "SELECT name FROM sqlite_master WHERE type='index' AND name='idx_entry_parent'");
      expect(idx.length, 1);
    });
  });
}
