/// Bootstrap and dependency wiring. See 04-8.2, 06-B1.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plain/core/id/uuid_v7.dart';
import 'package:plain/core/logging/app_log.dart';
import 'package:plain/core/time/clock.dart';
import 'package:plain/data/db/database.dart';
import 'package:plain/data/repositories/account_repository.dart';
import 'package:plain/data/repositories/app_meta_repository.dart';
import 'package:plain/data/repositories/automation_rule_repository.dart';
import 'package:plain/data/repositories/budget_repository.dart';
import 'package:plain/data/repositories/change_log_repository.dart';
import 'package:plain/data/repositories/category_repository.dart';
import 'package:plain/data/repositories/ledger_repository.dart';
import 'package:plain/data/repositories/recurring_repository.dart';
import 'package:plain/data/repositories/reminder_repository.dart';
import 'package:plain/data/repositories/currency_rate_repository.dart';
import 'package:plain/data/repositories/holding_repository.dart';
import 'package:plain/data/repositories/merchant_rule_repository.dart';
import 'package:plain/data/repositories/member_repository.dart';
import 'package:plain/data/repositories/saved_report_repository.dart';
import 'package:plain/data/repositories/sync_conflict_repository.dart';
import 'package:plain/data/sync/sync_applier.dart';
import 'package:plain/data/sync/webdav_client.dart';
import 'package:plain/data/sync/incremental_sync_service.dart';
import 'package:plain/data/repositories/savings_goal_repository.dart';
import 'package:plain/data/repositories/tax_filing_repository.dart';
import 'package:plain/data/sync/change_log_writer.dart';
import 'package:plain/domain/repositories/repositories.dart';
import 'package:plain/domain/services/accounting_calendar.dart';
import 'package:plain/domain/services/member_service.dart';
import 'package:plain/domain/services/reminder_prefs_store.dart';
import 'package:plain/domain/services/reminder_service.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/usecases/budget_usecases.dart';
import 'package:plain/domain/usecases/entry_usecases.dart';
import 'package:plain/domain/usecases/goal_usecases.dart';
import 'package:plain/domain/usecases/import_usecase.dart';
import 'package:plain/domain/usecases/loan_usecases.dart';
import 'package:plain/domain/usecases/recurring_usecases.dart';
import 'package:plain/domain/services/weekly_report_service.dart';
import 'package:plain/app/settings/ledger_settings.dart';
import 'package:plain/app/l10n/strings_core.dart';
import 'package:plain/app/l10n/app_strings.dart';

class AppDependencies {
  const AppDependencies({
    required this.db, required this.clock, required this.log, required this.idGen,
    required this.ledgerRepository, required this.categoryRepository,
    required this.accountRepository, required this.budgetRepository, required this.recurringRepository,
    required this.automationRuleRepository,
    required this.savingsGoalRepository,
    required this.holdingRepository,
    required this.savedReportRepository,
    required this.taxFilingRepository,
    required this.currencyRateRepository,
    required this.merchantRuleRepository,
    required this.appMetaRepository,
    required this.reminderRepository,
    required this.reminderService,
    required this.memberRepository,
    required this.memberService,
    required this.syncConflictRepository,
    required this.syncApplier,
    required this.changeLogWriter, required this.changeLogRepository,
    required this.calendar,
    required this.createEntry, required this.updateEntry, required this.deleteEntry,
    required this.restoreEntry, required this.purgeTrash, required this.listDeletedEntries,
    required this.importCsv,
    required this.resolveBudgetStatus, required this.createRecurringRule,
    required this.generateDueRecurring, required this.confirmRecurringRule, required this.undoRecurringBatch,
    required this.depositToGoal, required this.setGoalAutoTransfer,
    required this.setLoanRepaymentSchedule,
    required this.deviceId, required this.bookId,
    this.strings = kDefaultAppStrings,
  });

  final AppDatabase db;

  /// 后台任务（通知 / 周报推送）用的文案包，无 context 时的来源。
  final AppStrings strings;
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
  final HoldingRepository holdingRepository;
  final SavedReportRepository savedReportRepository;
  final TaxFilingRepository taxFilingRepository;
  final CurrencyRateRepository currencyRateRepository;
  final MerchantRuleRepository merchantRuleRepository;

  /// STORY-6.3：提醒历史（去重 + 近 90 天可查）与「上次备份时间」。
  final AppMetaRepository appMetaRepository;
  final ReminderRepository reminderRepository;
  final ReminderService reminderService;
  final MemberRepository memberRepository;
  final MemberService memberService;
  final SyncConflictRepositoryImpl syncConflictRepository;
  final SyncApplier syncApplier;
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
  final DepositToGoalUseCase depositToGoal;
  final SetGoalAutoTransferUseCase setGoalAutoTransfer;
  final SetLoanRepaymentScheduleUseCase setLoanRepaymentSchedule;
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

/// STORY-9.5：周日 20:00 之后首次启动/回前台，补推「本周消费画像」。
/// 内部已吞掉所有异常（推送是尽力而为，绝不能拖累启动）。
Future<void> runWeeklyReportPush(AppDependencies deps) async {
  await WeeklyReportService.pushIfDue(
    s: deps.strings,
    ledger: deps.ledgerRepository,
    categories: deps.categoryRepository,
    clock: deps.clock,
    bookId: deps.bookId,
  );
}

/// STORY-7.1：储蓄目标存储的「已存」计数按账本重算（自愈）。
///
/// 计数是缓存、账本才是事实来源：生成划拨与撤销批次如果在中途失败，
/// 计数就会偏（撤销与删账目前不是同一事务）。与 `daily_stats` 巡检同理——
/// 能重算就不怕偏，因此启动时空闲时对齐一次，而不是靠「记得做减法」。
Future<void> runGoalCounterReconcile(AppDependencies deps) async {
  try {
    final goals =
        (await deps.savingsGoalRepository.listByBook(deps.bookId)).successOrNull ??
            const [];
    for (final g in goals) {
      final recomputed =
          await reconcileStoredSavedCents(goal: g, ledger: deps.ledgerRepository);
      if (recomputed == null || recomputed == g.savedCents) continue;
      await deps.savingsGoalRepository.update(g.copyWith(
        savedCents: recomputed,
        updatedAt: deps.clock.now(),
        revision: g.revision + 1,
        baseRevision: g.revision,
      ));
    }
  } catch (_) {
    // 自愈失败不影响业务，下次启动再试
  }
}

/// STORY-6.3：启动 / 回前台扫一次九类提醒，推系统通知，再做夜间汇总。
///
/// 与 [runWeeklyReportPush] 同款：离线 App 没有后台唤醒，靠**启动与回前台补发**
/// ——宁可晚到，也不能因为那一刻没开 App 就没有提醒。**不新增常驻轮询**。
/// 异常全部吞掉（通知是尽力而为，绝不能拖累启动）。
Future<void> runReminderScan(AppDependencies deps) async {
  try {
    final prefs = await ReminderPrefsStore.load();
    final items = await deps.reminderService.collect(
      s: deps.strings,
      bookId: deps.bookId,
      prefs: prefs,
    );
    await deps.reminderService.pushToSystem(items);
    await deps.reminderService.pushDigestIfDue(
      s: deps.strings,
      bookId: deps.bookId,
      prefs: prefs,
    );
  } catch (_) {
    // 扫描失败不影响业务，下次启动/回前台再试。
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
  // G-1 月起始日 + STORY-11.1 预算方法论（可同步设置，落 app_meta）
  registerMetaWriter(setKey);
  final msd = int.tryParse(getKey(kMetaMonthStartDay)) ?? 1;
  preloadLedgerSettings(
    msd,
    methodology: BudgetMethodology.fromWire(getKey(kMetaBudgetMethodology)),
  );
  return (deviceId: deviceId, bookId: bookId);
}

/// STORY-8.1：可同步设置写入 `app_meta` 的同时记一条 `setting` 变更。
/// 在 [buildDependencies] 里覆盖早先注册的裸写入器（那时还没有 change_log 写入器）。
void _registerSyncedMetaWriter(
  AppDatabase db,
  ChangeLogWriter changeLog,
  String deviceId,
) {
  void writeMeta(String key, String value) {
    // ⚠️ 必须先写 change_log（writeSyncedSetting 要读**旧值**判有没有变化），
    // 再落 app_meta。反过来写的话它读到的就是刚写进去的新值 → 判定「没变化」
    // → 日志永远不写 → 设置（含提醒开关）永远同步不出去。
    writeSyncedSetting(
      db: db, changeLog: changeLog, deviceId: deviceId, key: key, value: value);
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    db.raw.execute(
      'INSERT INTO app_meta (key,value,updated_at) VALUES (?,?,?) '
      'ON CONFLICT(key) DO UPDATE SET value=?,updated_at=?',
      [key, value, now, value, now],
    );
  }

  registerMetaWriter(writeMeta);
  // STORY-8.1 AC5：提醒开关（`pref.reminder`）也走这条**可同步**路径
  // （写 `app_meta` + 记 `setting` 变更），读回以 `app_meta` 为准——
  // 对端 pull 下来的开关只落在 `app_meta`，读 SharedPreferences 永远读不到。
  ReminderPrefsStore.registerMetaBridge(
    write: writeMeta,
    read: (key) => readMetaValue(db, key),
  );
}

/// `app_meta` 单键读取（缺失返回空串）。
String readMetaValue(AppDatabase db, String key) {
  final rows = db.raw.select('SELECT value FROM app_meta WHERE key = ?', [key]);
  return rows.isEmpty ? '' : (rows.first['value'] as String? ?? '');
}

/// 当前 WebDAV 配置（未配置时返回 null）。凭据只存本机 `app_meta`，不参与同步。
WebDavConfig? webDavConfigOf(AppDatabase db) {
  String getK(String k) {
    final rows = db.raw.select('SELECT value FROM app_meta WHERE key = ?', [k]);
    return rows.isEmpty ? '' : rows.first['value']! as String;
  }

  final url = getK('webdav.url');
  if (url.isEmpty) return null;
  final path = getK('webdav.path');
  return WebDavConfig(
    baseUrl: url,
    username: getK('webdav.user'),
    password: getK('webdav.pass'),
    remotePath: path.isEmpty ? '/plain/sync' : path,
  );
}

/// 开关打开且已配置时才返回配置。
///
/// 开关本身是**本机偏好**（`sync.enabled` 不进 change_log）：一台设备要不要
/// 后台同步，属于「这台设备怎么看数据」。
WebDavConfig? syncConfigIfEnabled(AppDatabase db) {
  final rows = db.raw.select('SELECT value FROM app_meta WHERE key = ?', ['sync.enabled']);
  if (rows.isNotEmpty && (rows.first['value'] as String?) == '0') return null;
  return webDavConfigOf(db);
}

/// 开关状态（默认开；配置了 WebDAV 就应该同步）。
bool syncEnabledOf(AppDatabase db) {
  final rows = db.raw.select('SELECT value FROM app_meta WHERE key = ?', ['sync.enabled']);
  return rows.isEmpty || (rows.first['value'] as String?) != '0';
}

void setSyncEnabled(AppDatabase db, bool enabled) {
  final now = DateTime.now().toUtc().millisecondsSinceEpoch;
  db.raw.execute(
    'INSERT INTO app_meta (key,value,updated_at) VALUES (?,?,?) '
    'ON CONFLICT(key) DO UPDATE SET value=?,updated_at=?',
    ['sync.enabled', enabled ? '1' : '0', now, enabled ? '1' : '0', now],
  );
}

/// 构造一次增量同步（用完即弃的 client，避免长连接泄漏）。
IncrementalSyncService buildIncrementalSync(AppDependencies deps, WebDavConfig config) {
  return IncrementalSyncService(
    db: deps.db,
    client: WebDavClient(),
    applier: deps.syncApplier,
    clock: deps.clock,
    deviceId: deps.deviceId,
    log: deps.log,
  );
}

AppDependencies buildDependencies({
  required AppDatabase db, required String deviceId, required String bookId, Clock? clock,
}) {
  final effectiveClock = clock ?? SystemClock();
  final log = AppLog(sink: RingBufferSink());
  final idGen = UuidV7();
  final changeLogWriter = ChangeLogWriter(db, clock: effectiveClock);
  final changeLogRepo = ChangeLogRepository(db);
  // STORY-8.2：家庭成员
  final memberRepo = MemberRepositoryImpl(
    db: db,
    changeLogWriter: changeLogWriter,
    idGen: idGen,
    clock: effectiveClock,
  );
  final memberSvc = MemberService(
    repository: memberRepo,
    idGen: idGen,
    clock: effectiveClock,
  );
  final ledgerRepo = LedgerRepositoryImpl(
    db: db,
    changeLogWriter: changeLogWriter,
    clock: effectiveClock,    log: log,
  );
  // STORY-8.1：增量同步（applier 要拿到账单仓储，才能同口径维护统计）
  final syncConflicts = SyncConflictRepositoryImpl(db: db);
  final syncApplier = SyncApplier(
    db: db,
    ledger: ledgerRepo,
    conflicts: syncConflicts,
    idGen: idGen,
    clock: effectiveClock,
    localDeviceId: deviceId,
    changeLog: changeLogWriter,
  );
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
  final holdingRepo = HoldingRepositoryImpl(
    db: db,
    changeLogWriter: changeLogWriter,
  );
  final savedReportRepo = SavedReportRepositoryImpl(
    db: db,
    changeLogWriter: changeLogWriter,
    clock: effectiveClock,
  );
  final taxFilingRepo = TaxFilingRepositoryImpl(
    db: db,
    changeLogWriter: changeLogWriter,
    clock: effectiveClock,
  );
  final currencyRateRepo = CurrencyRateRepositoryImpl(
    db: db,
    idGen: idGen,
    clock: effectiveClock,
    // STORY-9.3 × 8.1：锁定汇率是账本数据，要写 change_log 才能跨端
    changeLogWriter: changeLogWriter,
    deviceId: deviceId,
  );
  final merchantRuleRepo = MerchantRuleRepositoryImpl(
    db: db,
    changeLogWriter: changeLogWriter,
    idGen: idGen,
    clock: effectiveClock,
  );
  final calendar = AccountingCalendar(clock: effectiveClock);
  // STORY-6.3：提醒历史表 + 「上次备份时间」+ 九类提醒扫描服务
  final appMetaRepo = AppMetaRepository(db: db);
  final reminderRepo = ReminderRepositoryImpl(db: db);
  final reminderSvc = ReminderService(
    ledgerRepository: ledgerRepo,
    accountRepository: accountRepo,
    budgetRepository: budgetRepo,
    recurringRepository: recurringRepo,
    savingsGoalRepository: savingsRepo,
    categoryRepository: categoryRepo,
    reminderRepository: reminderRepo,
    appMetaRepository: appMetaRepo,
    calendar: calendar,
    clock: effectiveClock,
    idGen: idGen,
  );
  _registerSyncedMetaWriter(db, changeLogWriter, deviceId);
  return AppDependencies(
    db: db, clock: effectiveClock, log: log, idGen: idGen,
    ledgerRepository: ledgerRepo, categoryRepository: categoryRepo, accountRepository: accountRepo,
    budgetRepository: budgetRepo, recurringRepository: recurringRepo,
    automationRuleRepository: ruleRepo,
    savingsGoalRepository: savingsRepo,
    holdingRepository: holdingRepo,
    savedReportRepository: savedReportRepo,
    taxFilingRepository: taxFilingRepo,
    currencyRateRepository: currencyRateRepo,
    merchantRuleRepository: merchantRuleRepo,
    appMetaRepository: appMetaRepo,
    reminderRepository: reminderRepo,
    reminderService: reminderSvc,
    memberRepository: memberRepo,
    memberService: memberSvc,
    syncConflictRepository: syncConflicts,
    syncApplier: syncApplier,
    changeLogWriter: changeLogWriter, changeLogRepository: changeLogRepo,
    calendar: calendar,
    createEntry: CreateEntryUseCase(
      repository: ledgerRepo, clock: effectiveClock, idGen: idGen,
      ruleRepository: ruleRepo, memberRepository: memberRepo,
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
      clock: effectiveClock, idGen: idGen, ruleRepository: ruleRepo,
      savingsGoalRepository: savingsRepo, accountRepository: accountRepo),
    confirmRecurringRule: ConfirmRecurringRuleUseCase(
      repository: recurringRepo, ledgerRepository: ledgerRepo,
      clock: effectiveClock, idGen: idGen,
      accountRepository: accountRepo, savingsGoalRepository: savingsRepo,
      ruleRepository: ruleRepo,
    ),
    undoRecurringBatch: UndoRecurringBatchUseCase(
      repository: ledgerRepo,
      clock: effectiveClock,
      // STORY-7.3：储蓄划拨批次撤销要一起回滚目标进度
      recurringRepository: recurringRepo,
      savingsGoalRepository: savingsRepo,
    ),
    depositToGoal: DepositToGoalUseCase(
      goalRepository: savingsRepo,
      ledgerRepository: ledgerRepo,
      accountRepository: accountRepo,
      clock: effectiveClock,
      idGen: idGen,
    ),
    setGoalAutoTransfer: SetGoalAutoTransferUseCase(
      goalRepository: savingsRepo,
      accountRepository: accountRepo,
      recurringRepository: recurringRepo,
      clock: effectiveClock,
      idGen: idGen,
    ),
    setLoanRepaymentSchedule: SetLoanRepaymentScheduleUseCase(
      recurringRepository: recurringRepo,
      clock: effectiveClock,
      idGen: idGen,
    ),
    deviceId: deviceId, bookId: bookId,
  );
}
