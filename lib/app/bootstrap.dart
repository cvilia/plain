/// Bootstrap and dependency wiring. See 04-8.2, 06-B1.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plain/core/id/uuid_v7.dart';
import 'package:plain/core/logging/app_log.dart';
import 'package:plain/core/time/clock.dart';
import 'package:plain/data/db/database.dart';
import 'package:plain/data/repositories/account_repository.dart';
import 'package:plain/data/repositories/automation_rule_repository.dart';
import 'package:plain/data/repositories/budget_repository.dart';
import 'package:plain/data/repositories/change_log_repository.dart';
import 'package:plain/data/repositories/category_repository.dart';
import 'package:plain/data/repositories/ledger_repository.dart';
import 'package:plain/data/repositories/recurring_repository.dart';
import 'package:plain/data/repositories/savings_goal_repository.dart';
import 'package:plain/data/sync/change_log_writer.dart';
import 'package:plain/domain/repositories/repositories.dart';
import 'package:plain/domain/services/accounting_calendar.dart';
import 'package:plain/domain/usecases/budget_usecases.dart';
import 'package:plain/domain/usecases/entry_usecases.dart';
import 'package:plain/domain/usecases/import_usecase.dart';
import 'package:plain/domain/usecases/recurring_usecases.dart';
import 'package:plain/app/settings/ledger_settings.dart';

class AppDependencies {
  const AppDependencies({
    required this.db, required this.clock, required this.log, required this.idGen,
    required this.ledgerRepository, required this.categoryRepository,
    required this.accountRepository, required this.budgetRepository, required this.recurringRepository,
    required this.automationRuleRepository,
    required this.savingsGoalRepository,
    required this.changeLogWriter, required this.changeLogRepository,
    required this.calendar,
    required this.createEntry, required this.updateEntry, required this.deleteEntry,
    required this.restoreEntry, required this.purgeTrash, required this.listDeletedEntries,
    required this.importCsv,
    required this.resolveBudgetStatus, required this.createRecurringRule,
    required this.generateDueRecurring, required this.confirmRecurringRule, required this.undoRecurringBatch,
    required this.deviceId, required this.bookId,
  });

  final AppDatabase db;
  final Clock clock;
  final AppLog log;
  final UuidV7 idGen;
  final LedgerRepository ledgerRepository;
  final CategoryRepository categoryRepository;
  final AccountRepository accountRepository;
  final BudgetRepository budgetRepository;
  final RecurringRepository recurringRepository;
  final AutomationRuleRepository automationRuleRepository;
  final SavingsGoalRepository savingsGoalRepository;
  final ChangeLogWriter changeLogWriter;
  final ChangeLogRepository changeLogRepository;
  final AccountingCalendar calendar;
  final CreateEntryUseCase createEntry;
  final UpdateEntryUseCase updateEntry;
  final DeleteEntryUseCase deleteEntry;
  final RestoreEntryUseCase restoreEntry;
  final PurgeTrashUseCase purgeTrash;
  final ListDeletedEntriesUseCase listDeletedEntries;
  final ImportCsvUseCase importCsv;
  final ResolveBudgetStatusUseCase resolveBudgetStatus;
  final CreateRecurringRuleUseCase createRecurringRule;
  final GenerateDueRecurringUseCase generateDueRecurring;
  final ConfirmRecurringRuleUseCase confirmRecurringRule;
  final UndoRecurringBatchUseCase undoRecurringBatch;
  final String deviceId;
  final String bookId;
}

final appDependenciesProvider = Provider<AppDependencies>((ref) {
  throw UnimplementedError('Override in bootstrap');
});

final clockProvider = Provider<Clock>((ref) => ref.watch(appDependenciesProvider).clock);
final logProvider = Provider<AppLog>((ref) => ref.watch(appDependenciesProvider).log);
final ledgerRepositoryProvider = Provider<LedgerRepository>((ref) => ref.watch(appDependenciesProvider).ledgerRepository);
final categoryRepositoryProvider = Provider<CategoryRepository>((ref) => ref.watch(appDependenciesProvider).categoryRepository);
final budgetRepositoryProvider = Provider<BudgetRepository>((ref) => ref.watch(appDependenciesProvider).budgetRepository);
final recurringRepositoryProvider = Provider<RecurringRepository>((ref) => ref.watch(appDependenciesProvider).recurringRepository);
final calendarProvider = Provider<AccountingCalendar>((ref) {
  final deps = ref.watch(appDependenciesProvider);
  final monthStartDay = ref.watch(monthStartDayProvider);
  return AccountingCalendar(clock: deps.clock, monthStartDay: monthStartDay);
});

/// 08-§8 巡检：冷启动比对 tx 条数 vs daily_stats 合计，不一致即重建。
/// 失败不阻塞启动——统计可重建，绝不能拖垮首帧。
Future<void> runDailyStatsIntegrityCheck(AppDependencies deps) async {
  try {
    final v = await deps.ledgerRepository.verifyDailyStats();
    if (v.successOrNull == false) {
      await deps.ledgerRepository.rebuildDailyStats();
    }
  } catch (_) {
    // 巡检/重建是自愈手段，异常仅吞掉；下次启动再试。
  }
}

/// 06-C3：change_log GC（30 天 / 5 万行）。空闲时跑，不阻塞首帧。
Future<void> runChangeLogGc(AppDependencies deps) async {
  try {
    await deps.changeLogRepository.gc(now: deps.clock.now());
  } catch (_) {
    // GC 失败不影响业务，下次启动再试。
  }
}
final createEntryProvider = Provider<CreateEntryUseCase>((ref) => ref.watch(appDependenciesProvider).createEntry);
final restoreEntryProvider = Provider<RestoreEntryUseCase>((ref) => ref.watch(appDependenciesProvider).restoreEntry);
final purgeTrashProvider = Provider<PurgeTrashUseCase>((ref) => ref.watch(appDependenciesProvider).purgeTrash);
final listDeletedEntriesProvider = Provider<ListDeletedEntriesUseCase>((ref) => ref.watch(appDependenciesProvider).listDeletedEntries);
final resolveBudgetStatusProvider = Provider<ResolveBudgetStatusUseCase>((ref) => ref.watch(appDependenciesProvider).resolveBudgetStatus);
final createRecurringRuleProvider = Provider<CreateRecurringRuleUseCase>((ref) => ref.watch(appDependenciesProvider).createRecurringRule);
final generateDueRecurringProvider = Provider<GenerateDueRecurringUseCase>((ref) => ref.watch(appDependenciesProvider).generateDueRecurring);
final undoRecurringBatchProvider = Provider<UndoRecurringBatchUseCase>((ref) => ref.watch(appDependenciesProvider).undoRecurringBatch);

Future<({String deviceId, String bookId})> ensureDeviceMeta(AppDatabase db, UuidV7 idGen) async {
  final now = DateTime.now().toUtc().millisecondsSinceEpoch;
  String getKey(String key) {
    final rows = db.raw.select('SELECT value FROM app_meta WHERE key = ?', [key]);
    return rows.isEmpty ? '' : rows.first['value']! as String;
  }
  void setKey(String key, String value) {
    db.raw.execute('INSERT INTO app_meta (key,value,updated_at) VALUES (?,?,?) ON CONFLICT(key) DO UPDATE SET value=?,updated_at=?',
      [key, value, now, value, now]);
  }
  var deviceId = getKey('device.id');
  if (deviceId.isEmpty) {
    deviceId = idGen.generate();
    setKey('device.id', deviceId);
    setKey('book.default_id', idGen.generate());
  }
  var bookId = getKey('book.default_id');
  if (bookId.isEmpty) {
    bookId = idGen.generate();
    setKey('book.default_id', bookId);
  }
  // G-1 月起始日（可同步设置，落 app_meta）
  registerMetaWriter(setKey);
  final msd = int.tryParse(getKey(kMetaMonthStartDay)) ?? 1;
  preloadLedgerSettings(msd);
  return (deviceId: deviceId, bookId: bookId);
}

AppDependencies buildDependencies({
  required AppDatabase db, required String deviceId, required String bookId, Clock? clock,
}) {
  final effectiveClock = clock ?? SystemClock();
  final log = AppLog(sink: RingBufferSink());
  final idGen = UuidV7();
  final changeLogWriter = ChangeLogWriter(db, clock: effectiveClock);
  final changeLogRepo = ChangeLogRepository(db);
  final ledgerRepo = LedgerRepositoryImpl(db: db, changeLogWriter: changeLogWriter, clock: effectiveClock, log: log);
  final categoryRepo = CategoryRepositoryImpl(db: db, changeLogWriter: changeLogWriter, clock: effectiveClock);
  final accountRepo = AccountRepositoryImpl(db: db, changeLogWriter: changeLogWriter, clock: effectiveClock);
  final budgetRepo = BudgetRepositoryImpl(db: db, changeLogWriter: changeLogWriter, clock: effectiveClock);
  final recurringRepo = RecurringRepositoryImpl(db: db, changeLogWriter: changeLogWriter, clock: effectiveClock);
  final ruleRepo = AutomationRuleRepositoryImpl(db: db, changeLogWriter: changeLogWriter);
  final savingsRepo = SavingsGoalRepositoryImpl(
    db: db,
    changeLogWriter: changeLogWriter,
    now: () => effectiveClock.now(),
  );
  final calendar = AccountingCalendar(clock: effectiveClock);
  return AppDependencies(
    db: db, clock: effectiveClock, log: log, idGen: idGen,
    ledgerRepository: ledgerRepo, categoryRepository: categoryRepo, accountRepository: accountRepo,
    budgetRepository: budgetRepo, recurringRepository: recurringRepo,
    automationRuleRepository: ruleRepo,
    savingsGoalRepository: savingsRepo,
    changeLogWriter: changeLogWriter, changeLogRepository: changeLogRepo,
    calendar: calendar,
    createEntry: CreateEntryUseCase(
      repository: ledgerRepo, clock: effectiveClock, idGen: idGen,
      ruleRepository: ruleRepo,
    ),
    updateEntry: UpdateEntryUseCase(repository: ledgerRepo, clock: effectiveClock),
    deleteEntry: DeleteEntryUseCase(repository: ledgerRepo),
    restoreEntry: RestoreEntryUseCase(repository: ledgerRepo),
    purgeTrash: PurgeTrashUseCase(repository: ledgerRepo, clock: effectiveClock),
    listDeletedEntries: ListDeletedEntriesUseCase(repository: ledgerRepo),
    importCsv: ImportCsvUseCase(repository: ledgerRepo, clock: effectiveClock, idGen: idGen, ruleRepository: ruleRepo),
    resolveBudgetStatus: ResolveBudgetStatusUseCase(repository: budgetRepo, clock: effectiveClock),
    createRecurringRule: CreateRecurringRuleUseCase(repository: recurringRepo, clock: effectiveClock, idGen: idGen),
    generateDueRecurring: GenerateDueRecurringUseCase(
      recurringRepository: recurringRepo, ledgerRepository: ledgerRepo,
      clock: effectiveClock, idGen: idGen, ruleRepository: ruleRepo),
    confirmRecurringRule: ConfirmRecurringRuleUseCase(
      repository: recurringRepo, ledgerRepository: ledgerRepo,
      clock: effectiveClock, idGen: idGen,
    ),
    undoRecurringBatch: UndoRecurringBatchUseCase(repository: recurringRepo, clock: effectiveClock),
    deviceId: deviceId, bookId: bookId,
  );
}
