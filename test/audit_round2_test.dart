/// 深度互联审计收口（第二轮，2026-10-15）：五件事的回归测试。
///
/// ① 提醒开关真的落 `app_meta`（可同步，PRD 8.1）
/// ② `currency_rates`（锁定汇率）补 change_log
/// ③ 附件孤儿标记 / 恢复 / 清理补 change_log
/// ④ 撤销周期批次回滚储蓄目标进度
/// ⑤ 外币账户单币种口径 + 目标进度读虚拟账户派生余额
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:plain/app/bootstrap.dart';
import 'package:plain/core/id/uuid_v7.dart';
import 'package:plain/core/money/money.dart';
import 'package:plain/core/constants/app_constants.dart';
import 'package:plain/core/time/clock.dart';
import 'package:plain/data/db/column_writer.dart';
import 'package:plain/data/db/database.dart';
import 'package:plain/data/repositories/account_repository.dart';
import 'package:plain/data/repositories/attachment_repository.dart';
import 'package:plain/data/repositories/currency_rate_repository.dart';
import 'package:plain/data/repositories/ledger_repository.dart';
import 'package:plain/data/repositories/recurring_repository.dart';
import 'package:plain/data/repositories/savings_goal_repository.dart';
import 'package:plain/data/repositories/sync_conflict_repository.dart';
import 'package:plain/data/sync/change_log_writer.dart';
import 'package:plain/data/sync/sync_applier.dart';
import 'package:plain/data/sync/sync_wire.dart';
import 'package:plain/domain/entities/attachment.dart';
import 'package:plain/domain/entities/category.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/entities/ledger_entry.dart';
import 'package:plain/domain/entities/recurring_rule.dart';
import 'package:plain/domain/entities/reminder.dart';
import 'package:plain/domain/entities/savings_goal.dart';
import 'package:plain/domain/services/goal_progress_service.dart';
import 'package:plain/domain/services/net_worth_service.dart';
import 'package:plain/domain/services/reminder_prefs_store.dart';
import 'package:plain/domain/services/sync_scope.dart';
import 'package:plain/domain/usecases/goal_usecases.dart';
import 'package:plain/domain/usecases/recurring_usecases.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kBook = 'book-1';
const String kDevice = 'dev-1';

/// change_log 当前全部行 → 同步记录（与 `IncrementalSyncService._readLocalRecords`
/// 同口径，够用来跑「一台设备改、另一台应用」的收敛断言）。
List<SyncRecord> recordsOf(AppDatabase db) {
  final rows = db.raw.select(
    'SELECT local_revision, entity_type, entity_id, op, device_id, base_revision, '
    'payload, changed_at FROM change_log ORDER BY local_revision',
  );
  final out = <SyncRecord>[];
  for (final row in rows) {
    final decoded = jsonDecode(row['payload']! as String);
    if (decoded is! Map<String, Object?>) continue;
    final before = decoded['before'];
    final after = decoded['after'];
    out.add(SyncRecord(
      localRevision: row['local_revision']! as int,
      entityType: row['entity_type']! as String,
      entityId: row['entity_id']! as String,
      op: ChangeOp.fromWire(row['op'] as String?),
      deviceId: (row['device_id'] as String?) ?? '',
      baseRevision: (row['base_revision'] as num?)?.toInt() ?? 0,
      changedAt: DateTime.fromMillisecondsSinceEpoch(
          (row['changed_at']! as num).toInt(), isUtc: true),
      before: before is Map<String, Object?> ? before : const {},
      after: after is Map<String, Object?> ? after : const {},
    ));
  }
  return out;
}

/// 只要锁定汇率的同步记录（测试只跑这条链路，别把账户等其它变更一起带过去）。
List<SyncRecord> rateRecordsOf(AppDatabase db) =>
    [for (final r in recordsOf(db)) if (r.entityType == 'currency_rate') r];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late FixedClock clock;
  late ChangeLogWriter changeLog;
  late LedgerRepositoryImpl ledgerRepo;
  late AccountRepositoryImpl accountRepo;
  late SavingsGoalRepositoryImpl goalRepo;
  late RecurringRepositoryImpl recurringRepo;
  late CurrencyRateRepositoryImpl rateRepo;

  setUp(() async {
    db = AppDatabase.inMemory();
    clock = FixedClock(DateTime.utc(2026, 1, 15, 12));
    final idGen = UuidV7();
    changeLog = ChangeLogWriter(db, clock: clock);
    ledgerRepo = LedgerRepositoryImpl(db: db, changeLogWriter: changeLog, clock: clock);
    accountRepo = AccountRepositoryImpl(db: db, changeLogWriter: changeLog, clock: clock);
    goalRepo = SavingsGoalRepositoryImpl(db: db, changeLogWriter: changeLog, now: clock.now);
    recurringRepo = RecurringRepositoryImpl(db: db, changeLogWriter: changeLog, clock: clock);
    rateRepo = CurrencyRateRepositoryImpl(
      db: db, idGen: idGen, clock: clock, changeLogWriter: changeLog, deviceId: kDevice);

    await accountRepo.create(Account(
      id: 'acc-cash', name: '现金', type: AccountType.cash,
      currency: MoneyRules.defaultCurrency, openingBalance: 1000000, sortOrder: 0,
      createdAt: clock.now(), updatedAt: clock.now(), deviceId: kDevice,
    ));
  });

  tearDown(() => db.close());

  // ① ── 提醒开关落 app_meta（可同步） ──
  group('① 提醒开关写进 app_meta', () {
    test('保存开关 → app_meta + 一条 setting 变更；读回以 app_meta 为准', () async {
      SharedPreferences.setMockInitialValues({});
      // 生产接线：bootstrap 在这里注册「可同步设置」写入器（app_meta + change_log）
      buildDependencies(db: db, deviceId: kDevice, bookId: kBook);

      const key = ReminderRules.kPrefReminder;
      expect(isSyncedSetting(key), isTrue, reason: 'PRD 8.1 的可同步设置白名单');

      final prefs = const ReminderPrefs().toggle(ReminderKind.anomalySpend);
      final withMute = prefs.copyWith(allMuted: true);
      await ReminderPrefsStore.save(withMute);

      final meta = db.raw.select('SELECT value FROM app_meta WHERE key = ?', [key]);
      expect(meta, hasLength(1), reason: '开关必须落能同步的 app_meta');
      expect(meta.first['value'], withMute.encode());

      final logs = db.raw.select(
          "SELECT entity_id, op FROM change_log WHERE entity_type = 'setting'");
      expect(logs, hasLength(1), reason: '要跨端就得记一条 setting 变更');
      expect(logs.first['entity_id'], key);
      expect(logs.first['op'], 'update');

      // 对端 pull 下来的开关只写 app_meta → 读回必须认它
      final loaded = await ReminderPrefsStore.load();
      expect(loaded.allMuted, isTrue);
      expect(loaded.isEnabled(ReminderKind.anomalySpend), isFalse);
      expect(loaded.isEnabled(ReminderKind.budgetWarn), isFalse);
    });
  });

  // ② ── 锁定汇率补 change_log ──
  group('② 锁定汇率写 change_log', () {
    test('setRate 记 insert/update，removeRate 记 delete（整行列形态 payload）', () async {
      expect(isSyncedEntityType('currency_rate'), isTrue);
      expect(kEntityTables['currency_rate'], 'currency_rates');

      final first = await rateRepo.setRate(
        bookId: kBook, fromCurrency: 'USD', toCurrency: MoneyRules.defaultCurrency,
        rate: 7.2, deviceId: kDevice);
      expect(first.isSuccess, isTrue, reason: first.failureOrNull?.toString() ?? '');

      var logs = db.raw.select(
          "SELECT entity_type, op, entity_id, payload FROM change_log "
          "WHERE entity_type = 'currency_rate' ORDER BY local_revision");
      expect(logs, hasLength(1));
      expect(logs.first['entity_type'], 'currency_rate');
      expect(logs.first['op'], 'insert');
      expect(logs.first['entity_id'], first.requireValue.id);

      var payload = jsonDecode(logs.first['payload']! as String) as Map<String, Object?>;
      var after = payload['after']! as Map<String, Object?>;
      // 线形态 = 整行，缺列会让该列在跨端合并时静默丢失
      expect(after['id'], first.requireValue.id);
      expect(after['book_id'], kBook);
      expect(after['from_currency'], 'USD');
      expect(after['to_currency'], MoneyRules.defaultCurrency);
      expect(after['rate_micro'], CurrencyRules.rateToMicro(7.2));
      expect(after['device_id'], kDevice);
      expect(after['updated_at'], isA<int>());
      expect(after['revision'], isA<int>());
      expect(after['base_revision'], isA<int>());

      // 改汇率 → update，且 before 是改动前的旧值
      final changed = await rateRepo.setRate(
        bookId: kBook, fromCurrency: 'USD', toCurrency: MoneyRules.defaultCurrency,
        rate: 7.5, deviceId: kDevice);
      expect(changed.isSuccess, isTrue, reason: changed.failureOrNull?.toString() ?? '');
      logs = db.raw.select(
          "SELECT op, payload FROM change_log WHERE entity_type = 'currency_rate' "
          'ORDER BY local_revision');
      expect(logs, hasLength(2));
      expect(logs.last['op'], 'update');
      payload = jsonDecode(logs.last['payload']! as String) as Map<String, Object?>;
      final before = payload['before']! as Map<String, Object?>;
      after = payload['after']! as Map<String, Object?>;
      expect(before['rate_micro'], CurrencyRules.rateToMicro(7.2));
      expect(after['rate_micro'], CurrencyRules.rateToMicro(7.5));

      // 解除锁定 → delete（否则对端还在按幽灵汇率折算）
      final removed = await rateRepo.removeRate(
        bookId: kBook, fromCurrency: 'USD', toCurrency: MoneyRules.defaultCurrency);
      expect(removed.isSuccess, isTrue, reason: removed.failureOrNull?.toString() ?? '');
      logs = db.raw.select(
          "SELECT op, payload FROM change_log WHERE entity_type = 'currency_rate' "
          'ORDER BY local_revision');
      expect(logs.last['op'], 'delete');
      payload = jsonDecode(logs.last['payload']! as String) as Map<String, Object?>;
      expect((payload['before']! as Map<String, Object?>)['rate_micro'],
          CurrencyRules.rateToMicro(7.5));
      expect(payload['after'], isEmpty);
    });

    test('解除锁定的删除能传到对端（表没有 deleted_at → 物理删）', () async {
      // A 设备：设一条汇率并同步到 B
      await rateRepo.setRate(
        bookId: kBook, fromCurrency: 'USD', toCurrency: MoneyRules.defaultCurrency,
        rate: 7.2, deviceId: kDevice);
      final rateId = (await rateRepo.listByBook(kBook)).requireValue.first.id;

      final dbB = AppDatabase.inMemory();
      addTearDown(dbB.close);
      final applierB = SyncApplier(
        db: dbB,
        ledger: LedgerRepositoryImpl(
            db: dbB, changeLogWriter: ChangeLogWriter(dbB, clock: clock), clock: clock),
        conflicts: SyncConflictRepositoryImpl(db: dbB),
        idGen: UuidV7(),
        clock: clock,
        localDeviceId: 'dev-2',
      );
      final appliedB = await applierB.applyAll(rateRecordsOf(db), writerDeviceId: kDevice);
      expect(appliedB.isSuccess, isTrue, reason: appliedB.failureOrNull?.toString() ?? '');
      expect(
        dbB.raw.select('SELECT COUNT(*) AS c FROM currency_rates WHERE id = ?', [rateId])
            .first['c'],
        1,
        reason: '对端要能拿到这条锁定汇率',
      );

      // A 解除锁定 → B 必须真的删掉（currency_rates 没有 deleted_at 列）
      await rateRepo.removeRate(
        bookId: kBook, fromCurrency: 'USD', toCurrency: MoneyRules.defaultCurrency);
      final appliedB2 = await applierB.applyAll(rateRecordsOf(db), writerDeviceId: kDevice);
      expect(appliedB2.isSuccess, isTrue, reason: appliedB2.failureOrNull?.toString() ?? '');
      expect(
        dbB.raw.select('SELECT COUNT(*) AS c FROM currency_rates').first['c'],
        0,
        reason: '解除锁定要跨端，否则对端留着幽灵汇率',
      );
    });

    test('没有 deleted_at 列的表，同步删除按物理删处理', () {
      db.raw.execute(
        "INSERT INTO currency_rates (id,book_id,from_currency,to_currency,rate_micro,"
        "updated_at,revision,device_id,base_revision) "
        "VALUES ('fx-1','$kBook','USD','CNY',7000000,0,1,'$kDevice',0)");
      ColumnWriter.deleteRow(db, 'currency_rates', 'fx-1', clock.now());
      expect(db.raw.select('SELECT COUNT(*) AS c FROM currency_rates').first['c'], 0);
    });
  });

  // ③ ── 附件孤儿生命周期补 change_log ──
  group('③ 附件清理写 change_log', () {
    Future<AttachmentRepositoryImpl> setUpAttachment({String id = 'att-1'}) async {
      final repo = AttachmentRepositoryImpl(
          db: db, clock: clock, changeLogWriter: changeLog, deviceId: kDevice);
      await repo.create(Attachment(
        id: id, entryId: 'entry-1', bookId: kBook,
        storedName: '$id.jpg', mime: 'image/jpeg', sizeBytes: 1024,
        createdAt: clock.now(), updatedAt: clock.now(), deviceId: kDevice,
      ));
      return repo;
    }

    test('账单删除 → 标孤儿；恢复 → 清标记；清理 → delete（三条都写日志）', () async {
      final repo = await setUpAttachment();
      // create 自己也记一条 insert
      var logs = db.raw.select(
          "SELECT op FROM change_log WHERE entity_type = 'attachment' ORDER BY local_revision");
      expect(logs, hasLength(1));
      expect(logs.first['op'], 'insert');

      final marked = await repo.markOrphanedByEntry('entry-1', clock.now());
      expect(marked.requireValue, 1);
      logs = db.raw.select(
          "SELECT op, payload FROM change_log WHERE entity_type = 'attachment' "
          'ORDER BY local_revision');
      expect(logs, hasLength(2), reason: '孤儿标记要跨端');
      expect(logs.last['op'], 'update');
      var payload = jsonDecode(logs.last['payload']! as String) as Map<String, Object?>;
      expect((payload['after']! as Map<String, Object?>)['is_orphan'], 1);
      expect((payload['before']! as Map<String, Object?>)['is_orphan'], 0);

      final restored = await repo.restoreByEntry('entry-1');
      expect(restored.requireValue, 1);
      logs = db.raw.select(
          "SELECT op, payload FROM change_log WHERE entity_type = 'attachment' "
          'ORDER BY local_revision');
      expect(logs, hasLength(3));
      payload = jsonDecode(logs.last['payload']! as String) as Map<String, Object?>;
      expect((payload['before']! as Map<String, Object?>)['is_orphan'], 1);
      expect((payload['after']! as Map<String, Object?>)['is_orphan'], 0);

      // 巡检超期清理 → 物理删本地 + delete 变更（对端不能留幽灵附件）
      await repo.hardDelete('att-1');
      logs = db.raw.select(
          "SELECT op, payload FROM change_log WHERE entity_type = 'attachment' "
          'ORDER BY local_revision');
      expect(logs, hasLength(4));
      expect(logs.last['op'], 'delete');
      payload = jsonDecode(logs.last['payload']! as String) as Map<String, Object?>;
      expect((payload['before']! as Map<String, Object?>)['id'], 'att-1');
      expect(db.raw.select('SELECT COUNT(*) AS c FROM attachments').first['c'], 0);
    });

    test('没有变化时不写空变更（已孤儿的行再标一次不产生日志）', () async {
      final repo = await setUpAttachment();
      await repo.markOrphanedByEntry('entry-1', clock.now());
      await repo.markOrphanedByEntry('entry-1', clock.now());
      final logs = db.raw.select(
          "SELECT COUNT(*) AS c FROM change_log WHERE entity_type = 'attachment'");
      expect(logs.first['c'], 2, reason: 'insert + 一次真正生效的 update');
    });
  });

  // ④ ── 撤销周期批次回滚目标进度 ──
  group('④ 撤销储蓄划拨批次', () {
    const monthStartDay = 5;

    Future<({String batchId, RecurringRule rule})> runMonthlyTransfer() async {
      await goalRepo.create(SavingsGoal(
        id: 'g1', bookId: kBook, name: '车险', targetCents: 300000, savedCents: 0,
        dueAt: DateTime.utc(2026, 12, 31), accountId: 'acc-cash',
        createdAt: clock.now(), updatedAt: clock.now(), deviceId: kDevice,
      ));
      final setAuto = SetGoalAutoTransferUseCase(
        goalRepository: goalRepo, accountRepository: accountRepo,
        recurringRepository: recurringRepo, clock: clock, idGen: UuidV7());
      final on = await setAuto(goalId: 'g1', enabled: true, monthStartDay: monthStartDay);
      expect(on.isSuccess, isTrue, reason: on.failureOrNull?.toString() ?? '');

      final rule = (await recurringRepo.listByBook(kBook)).requireValue.first;
      // 走到下一个记账月首日（2 月 5 日）
      clock.set(DateTime.utc(2026, 2, 5, 9));
      final generate = GenerateDueRecurringUseCase(
        recurringRepository: recurringRepo, ledgerRepository: ledgerRepo,
        clock: clock, idGen: UuidV7(), savingsGoalRepository: goalRepo);
      final gen = await generate();
      expect(gen.isSuccess, isTrue, reason: gen.failureOrNull?.toString() ?? '');
      final updated = (await recurringRepo.getById(rule.id)).requireValue;
      return (batchId: updated.lastBatchId!, rule: updated);
    }

    test('撤销后目标进度扣回，虚拟账户余额同步回落', () async {
      final run = await runMonthlyTransfer();
      final goal = (await goalRepo.getById('g1')).requireValue;
      final goalAccountId = goal.goalAccountId!;
      expect(goal.savedCents, 25000);
      expect((await accountRepo.balanceOf(goalAccountId)).requireValue.balanceCents, 25000);

      final undo = UndoRecurringBatchUseCase(
        repository: ledgerRepo, clock: clock,
        recurringRepository: recurringRepo, savingsGoalRepository: goalRepo);
      final res = await undo(run.batchId);
      expect(res.isSuccess, isTrue, reason: res.failureOrNull?.toString() ?? '');
      expect(res.requireValue, 1, reason: '这批只有一笔划拨转账');

      // 存储计数扣回
      expect((await goalRepo.getById('g1')).requireValue.savedCents, 0);
      // 虚拟账户余额也回落（转账已软删）
      final balances = GoalProgressService.balanceIndex(
          (await accountRepo.listWithBalances()).requireValue);
      expect(balances[goalAccountId] ?? 0, 0);
      // 页面口径（派生）一起回落
      final view = const GoalProgressService().of(
        goal: (await goalRepo.getById('g1')).requireValue,
        balanceByAccount: balances,
      );
      expect(view.savedCents, 0);
      expect(view.progress, 0);
      // 统计不受影响（划拨从来不计收支）
      final stats = db.raw.select(
          "SELECT COALESCE(SUM(expense_cents),0) AS e, COALESCE(SUM(income_cents),0) AS i "
          "FROM daily_stats WHERE book_id = '$kBook'");
      expect(stats.first['e'], 0);
      expect(stats.first['i'], 0);
    });

    test('普通周期批次的撤销不动目标进度', () async {
      await goalRepo.create(SavingsGoal(
        id: 'g1', bookId: kBook, name: '车险', targetCents: 300000, savedCents: 0,
        accountId: 'acc-cash',
        createdAt: clock.now(), updatedAt: clock.now(), deviceId: kDevice,
      ));
      // 手工建一条普通周期规则并生成一笔
      final rule = await recurringRepo.create(RecurringRule(
        id: 'rr-1', bookId: kBook, name: '房租', frequency: RecurringFrequency.monthly,
        anchorDay: 1, entryType: EntryType.expense, amount: const Money(150000),
        accountId: 'acc-cash', nextRunAt: DateTime.utc(2026, 1, 1),
        createdAt: clock.now(), updatedAt: clock.now(), deviceId: kDevice,
      ));
      expect(rule.isSuccess, isTrue, reason: rule.failureOrNull?.toString() ?? '');
      final generate = GenerateDueRecurringUseCase(
        recurringRepository: recurringRepo, ledgerRepository: ledgerRepo,
        clock: clock, idGen: UuidV7(), savingsGoalRepository: goalRepo);
      final gen = await generate();
      expect(gen.successOrNull!.created, hasLength(1));
      final batchId = (await recurringRepo.getById('rr-1')).requireValue.lastBatchId!;

      final undo = UndoRecurringBatchUseCase(
        repository: ledgerRepo, clock: clock,
        recurringRepository: recurringRepo, savingsGoalRepository: goalRepo);
      final res = await undo(batchId);
      expect(res.requireValue, 1);
      expect((await goalRepo.getById('g1')).requireValue.savedCents, 0,
          reason: '普通批次从来没记过目标进度，不该被扣');
    });
  });

  // ⑤ ── 两条已定口径 ──
  group('⑤ 外币账户单币种 + 目标进度派生', () {
    test('外币账户余额不含原币期初（期初只按汇率折算进净值）', () async {
      await accountRepo.create(Account(
        id: 'acc-usd', name: '美元卡', type: AccountType.debit,
        currency: 'USD', openingBalance: 100000, sortOrder: 1,
        createdAt: clock.now(), updatedAt: clock.now(), deviceId: kDevice,
      ));
      // 一笔本位币流水（原币 100 × 7.2 = 72000 分）
      final created = await ledgerRepo.create(LedgerEntry(
        id: 'e1', bookId: kBook, type: EntryType.expense,
        amount: const Money(72000), currency: MoneyRules.defaultCurrency,
        originalAmountCents: 10000, exchangeRate: 7.2,
        accountId: 'acc-usd', occurredAt: clock.now(), source: EntrySource.manual,
        createdAt: clock.now(), updatedAt: clock.now(), deviceId: kDevice,
      ));
      expect(created.isSuccess, isTrue, reason: created.failureOrNull?.toString() ?? '');

      final bal = (await accountRepo.balanceOf('acc-usd')).requireValue;
      expect(bal.balanceCents, -72000,
          reason: '期初 100000 是原币（1000 美元），不能当 100000 分混加');
      final row = (await accountRepo.listWithBalances())
          .requireValue
          .firstWhere((r) => r.account.id == 'acc-usd');
      expect(row.balanceCents, -72000);
      // 本位币账户不受影响
      expect((await accountRepo.balanceOf('acc-cash')).requireValue.balanceCents, 1000000);
    });

    test('净值折算：有锁定汇率才参与，拿不到则整个账户不参与', () async {
      final usd = Account(
        id: 'acc-usd', name: '美元卡', type: AccountType.debit,
        currency: 'USD', openingBalance: 100000, sortOrder: 1,
        createdAt: clock.now(), updatedAt: clock.now(), deviceId: kDevice,
      );
      // 本位币账户永远无需汇率
      final cny = Account(
        id: 'acc-cash', name: '现金', type: AccountType.cash,
        currency: MoneyRules.defaultCurrency, openingBalance: 1000000, sortOrder: 0,
        createdAt: clock.now(), updatedAt: clock.now(), deviceId: kDevice,
      );
      expect(NetWorthService.convertedOpeningCents(account: cny, rateToBase: const <String, double>{}),
          1000000);
      expect(NetWorthService.convertedOpeningCents(account: usd, rateToBase: const <String, double>{}),
          isNull, reason: '拿不到汇率 → 返回 null（页面据此把该账户排除并注明）');
      expect(
        NetWorthService.convertedOpeningCents(account: usd, rateToBase: const {'USD': 7.2}),
        720000,
        reason: '1000 美元 × 7.2 = 7200 元',
      );
    });

    test('目标进度随虚拟账户派生余额变化（删掉存入转账后回落）', () async {
      await goalRepo.create(SavingsGoal(
        id: 'g1', bookId: kBook, name: '车险', targetCents: 100000, savedCents: 0,
        accountId: 'acc-cash',
        createdAt: clock.now(), updatedAt: clock.now(), deviceId: kDevice,
      ));
      final deposit = DepositToGoalUseCase(
        goalRepository: goalRepo, ledgerRepository: ledgerRepo,
        accountRepository: accountRepo, clock: clock, idGen: UuidV7());
      final ok = await deposit(goalId: 'g1', amountCents: 40000, deviceId: kDevice);
      expect(ok.isSuccess, isTrue, reason: ok.failureOrNull?.toString() ?? '');

      final goal = (await goalRepo.getById('g1')).requireValue;
      var balances = GoalProgressService.balanceIndex(
          (await accountRepo.listWithBalances()).requireValue);
      var view = const GoalProgressService()
          .of(goal: goal, balanceByAccount: balances);
      expect(view.savedCents, 40000);
      expect(view.progress, closeTo(0.4, 0.0001));

      // 用户在流水里删掉那笔「存入」内部转账（= 钱转回去了）
      final page = (await ledgerRepo.listPage(limit: 10)).requireValue;
      final depositEntry = page.items.first;
      expect(depositEntry.type, EntryType.transfer);
      expect((await ledgerRepo.softDelete(depositEntry.id)).isSuccess, isTrue);

      balances = GoalProgressService.balanceIndex(
          (await accountRepo.listWithBalances()).requireValue);
      final after = (await goalRepo.getById('g1')).requireValue;
      view = const GoalProgressService().of(goal: after, balanceByAccount: balances);
      expect(view.savedCents, 0, reason: '进度读派生余额，必须能回落');
      expect(view.progress, 0);
      expect(view.isAchieved, isFalse);
      expect(view.monthlyRequiredCentsAt(clock.now()), greaterThan(0),
          reason: '回落之后月需存要重新生效');
    });
  });
}
