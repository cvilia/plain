/// V2.0 数据地基回归：G-2「不计入收支」、G-2.1 信用卡欠款存储值、
/// daily_stats 分割交易双算、G-2.0 分类计数口径、旧版备份恢复。
library;
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:plain/core/id/uuid_v7.dart';
import 'package:plain/core/money/money.dart';
import 'package:plain/core/time/clock.dart';
import 'package:plain/data/db/database.dart';
import 'package:plain/data/repositories/account_repository.dart';
import 'package:plain/data/repositories/category_repository.dart';
import 'package:plain/data/repositories/ledger_repository.dart';
import 'package:plain/data/sync/change_log_writer.dart';
import 'package:plain/domain/entities/category.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/entities/ledger_entry.dart';
import 'package:plain/domain/services/credit_card_service.dart';
import 'package:plain/domain/usecases/split_usecases.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late AppDatabase db;
  late FixedClock clock;
  late LedgerRepositoryImpl ledgerRepo;
  late AccountRepositoryImpl accountRepo;
  late CategoryRepositoryImpl categoryRepo;

  setUp(() async {
    db = AppDatabase.inMemory();
    clock = FixedClock(DateTime.utc(2026, 9, 29, 12));
    final changeLog = ChangeLogWriter(db, clock: clock);
    ledgerRepo = LedgerRepositoryImpl(db: db, changeLogWriter: changeLog, clock: clock);
    accountRepo = AccountRepositoryImpl(db: db, changeLogWriter: changeLog, clock: clock);
    categoryRepo = CategoryRepositoryImpl(db: db, changeLogWriter: changeLog, clock: clock);

    await accountRepo.create(Account(
      id: 'acc-cash', name: '现金', type: AccountType.cash,
      currency: 'CNY', openingBalance: 0, sortOrder: 0,
      createdAt: clock.now(), updatedAt: clock.now(), deviceId: 'dev-1',
    ));
    await accountRepo.create(Account(
      id: 'acc-credit', name: '招行信用卡', type: AccountType.credit,
      currency: 'CNY', openingBalance: 0, sortOrder: 1,
      creditLimitCents: 2000000, creditDebtCents: 0,
      billDay: 5, dueDay: 25,
      createdAt: clock.now(), updatedAt: clock.now(), deviceId: 'dev-1',
    ));
    db.raw.execute(
      "INSERT INTO categories (id,name,kind,icon_ref,sort_order,is_hidden,is_preset,created_at,updated_at,device_id) "
      "VALUES ('c-food','食材','expense','other',0,0,0,0,0,'d'),"
      "('c-daily','日用','expense','other',1,0,0,0,0,'d'),"
      "('c-other','其他','expense','other',2,0,1,0,0,'d')",
    );
  });

  tearDown(() => db.close());

  LedgerEntry entry({
    String id = 'e1',
    int cents = 2500,
    String? accountId = 'acc-cash',
    String? toAccountId,
    EntryType type = EntryType.expense,
    String? categoryId = 'c-food',
    String? note,
    EntrySource source = EntrySource.manual,
    bool excludeFromStats = false,
    SplitRole splitRole = SplitRole.normal,
    String? parentId,
  }) =>
      LedgerEntry(
        id: id, bookId: 'book-1', type: type,
        amount: Money(cents), currency: 'CNY',
        categoryId: categoryId, accountId: accountId, toAccountId: toAccountId,
        occurredAt: clock.now(), note: note, source: source,
        excludeFromStats: excludeFromStats,
        splitRole: splitRole, parentId: parentId,
        createdAt: clock.now(), updatedAt: clock.now(), deviceId: 'dev-1',
      );

  int statsExpenseCents() {
    final rows = db.raw.select(
        "SELECT COALESCE(SUM(expense_cents),0) AS s FROM daily_stats WHERE book_id = 'book-1'");
    return (rows.first['s'] as int?) ?? 0;
  }

  int statsTxCount() {
    final rows = db.raw.select(
        "SELECT COALESCE(SUM(tx_count),0) AS c FROM daily_stats WHERE book_id = 'book-1'");
    return (rows.first['c'] as int?) ?? 0;
  }

  int creditDebtCents() {
    final rows = db.raw.select(
        "SELECT credit_debt_cents AS d FROM accounts WHERE id = 'acc-credit'");
    return (rows.first['d'] as int?) ?? 0;
  }

  // ───────────────────────── G-2「不计入收支」─────────────────────────

  group('G-2 手动标记不计入收支', () {
    test('excluded entry skips stats but still moves the account balance', () async {
      await ledgerRepo.create(entry(cents: 2500, excludeFromStats: true));

      // 不进收支合计 / 分类统计 / 预算
      expect(statsExpenseCents(), 0);
      expect(statsTxCount(), 0);

      // 但仍是一笔真实账单：钱从账户里划走了
      final bal = await accountRepo.balanceOf('acc-cash');
      expect(bal.successOrNull!.balanceCents, -2500);

      // 且与巡检口径一致
      expect((await ledgerRepo.verifyDailyStats()).successOrNull, true);
    });

    test('flag round-trips and toggling it off restores stats', () async {
      await ledgerRepo.create(entry(cents: 2500, excludeFromStats: true));
      final created = (await ledgerRepo.getById('e1')).successOrNull!;
      expect(created.excludeFromStats, true);
      expect(statsExpenseCents(), 0);

      final off = await ledgerRepo.update(created.copyWith(
        excludeFromStats: false,
        updatedAt: clock.now(),
        revision: created.revision + 1,
      ));
      expect(off.isSuccess, true);
      expect(statsExpenseCents(), 2500);
      expect((await ledgerRepo.verifyDailyStats()).successOrNull, true);
    });

    test('toggling the flag on removes it from stats', () async {
      await ledgerRepo.create(entry(cents: 2500));
      expect(statsExpenseCents(), 2500);

      final live = (await ledgerRepo.getById('e1')).successOrNull!;
      await ledgerRepo.update(live.copyWith(
        excludeFromStats: true,
        updatedAt: clock.now(),
        revision: live.revision + 1,
      ));
      expect(statsExpenseCents(), 0);
      expect((await ledgerRepo.verifyDailyStats()).successOrNull, true);
    });

    test('soft-deleting an excluded entry leaves stats untouched', () async {
      await ledgerRepo.create(entry(cents: 2500, excludeFromStats: true));
      await ledgerRepo.softDelete('e1');
      expect(statsExpenseCents(), 0);
      expect((await ledgerRepo.verifyDailyStats()).successOrNull, true);
    });

    test('only manual ordinary expense/income may be marked', () {
      expect(entry().canMarkExcluded, true);
      expect(entry(type: EntryType.income).canMarkExcluded, true);
      // 转账 / 对账 / 拆分子笔的计入口径由 G-2 定死
      expect(entry(type: EntryType.transfer).canMarkExcluded, false);
      expect(entry(source: EntrySource.reconcile).canMarkExcluded, false);
      expect(entry(splitRole: SplitRole.child).canMarkExcluded, false);
      expect(entry(accountId: null, type: EntryType.borrowOut).canMarkExcluded, false);
    });
  });

  // ─────────────── daily_stats 分割交易双算（C15 巡检口径）───────────────

  group('daily_stats 与分割交易口径一致', () {
    Future<void> splitInto() async {
      await ledgerRepo.create(entry(id: 'p1', cents: 30000));
      final parent = (await ledgerRepo.getById('p1')).successOrNull!;
      final r = await SplitEntryUseCase(
        repository: ledgerRepo, clock: clock, idGen: UuidV7(),
      ).call(
        parent: parent,
        items: const [
          SplitItem(amountCents: 20000, categoryId: 'c-food'),
          SplitItem(amountCents: 10000, categoryId: 'c-daily'),
        ],
      );
      expect(r.isSuccess, true);
    }

    test('verifyDailyStats stays consistent after a split', () async {
      await splitInto();
      // 父笔不进 daily_stats（金额由子笔承担），巡检必须用同一口径。
      // 这里曾因巡检漏过滤 split_role 而误判不一致。
      expect((await ledgerRepo.verifyDailyStats()).successOrNull, true);
    });

    test('rebuild does not double count the split parent', () async {
      await splitInto();
      expect(statsExpenseCents(), 30000);

      final rebuilt = await ledgerRepo.rebuildDailyStats();
      expect(rebuilt.isSuccess, true);

      // 双算会得到 60000（父 300 + 子 300）
      expect(statsExpenseCents(), 30000);
      expect((await ledgerRepo.verifyDailyStats()).successOrNull, true);
    });

    test('rebuild skips excluded entries too', () async {
      await ledgerRepo.create(entry(id: 'x1', cents: 2500, excludeFromStats: true));
      await ledgerRepo.create(entry(id: 'x2', cents: 1000));

      await ledgerRepo.rebuildDailyStats();
      expect(statsExpenseCents(), 1000);
      expect((await ledgerRepo.verifyDailyStats()).successOrNull, true);
    });
  });

  // ─────────────────── G-2.1 信用卡欠款余额（存储值）───────────────────

  group('G-2.1 信用卡欠款存储值', () {
    test('a purchase raises the debt and balance is its negative', () async {
      await ledgerRepo.create(entry(cents: 50000, accountId: 'acc-credit'));
      expect(creditDebtCents(), 50000);

      final bal = await accountRepo.balanceOf('acc-credit');
      expect(bal.successOrNull!.balanceCents, -50000);

      // 可用额度是派生量（AC1）
      final acc = (await accountRepo.getById('acc-credit')).successOrNull!;
      expect(acc.creditAvailableCents, 2000000 - 50000);
    });

    test('paying the card back via a transfer lowers the debt', () async {
      await ledgerRepo.create(entry(cents: 50000, accountId: 'acc-credit'));
      expect(creditDebtCents(), 50000);

      await ledgerRepo.create(entry(
        id: 't1', cents: 20000, type: EntryType.transfer,
        accountId: 'acc-cash', toAccountId: 'acc-credit', categoryId: null,
      ));
      expect(creditDebtCents(), 30000);
      // 非信用卡一侧仍走派生，不受影响
      final cash = await accountRepo.balanceOf('acc-cash');
      expect(cash.successOrNull!.balanceCents, -20000);
    });

    test('deleting and restoring a credit entry reverses and reapplies', () async {
      await ledgerRepo.create(entry(cents: 50000, accountId: 'acc-credit'));
      await ledgerRepo.softDelete('e1');
      expect(creditDebtCents(), 0);

      await ledgerRepo.restore('e1');
      expect(creditDebtCents(), 50000);
    });

    test('editing an amount adjusts the debt by the delta', () async {
      await ledgerRepo.create(entry(cents: 50000, accountId: 'acc-credit'));
      final live = (await ledgerRepo.getById('e1')).successOrNull!;
      await ledgerRepo.update(live.copyWith(
        amount: Money(30000), updatedAt: clock.now(), revision: live.revision + 1,
      ));
      expect(creditDebtCents(), 30000);
    });

    test('the reconcile voucher does not move the debt a second time (AC7)', () async {
      await ledgerRepo.create(entry(cents: 50000, accountId: 'acc-credit'));
      final acc = (await accountRepo.getById('acc-credit')).successOrNull!;
      // 刷卡本身是正常支出，计入收支
      expect(statsExpenseCents(), 50000);

      final r = await CreditReconcileService(
        accountRepository: accountRepo,
        ledgerRepository: ledgerRepo,
        clock: clock,
        idGen: UuidV7(),
      ).reconcile(
        account: acc,
        actualDebtCents: 48000,
        bookId: 'book-1',
        deviceId: 'dev-1',
      );
      expect(r.isSuccess, true, reason: r.failureOrNull?.toString() ?? '');

      // 直接写定的存储值必须保持 48000——凭证账单若再累加一次会变成 50000
      expect(creditDebtCents(), 48000);
      // 调整单本身仍要入账留痕，但不计入收支（G-2）
      final vouchers = db.raw.select(
          "SELECT COUNT(*) AS c FROM transactions WHERE source = 'reconcile'");
      expect(vouchers.first['c'], 1);
      expect(statsExpenseCents(), 50000);
    });

    test('derivedBalanceOf still aggregates bills for the AC8 check', () async {
      await ledgerRepo.create(entry(cents: 50000, accountId: 'acc-credit'));
      final acc = (await accountRepo.getById('acc-credit')).successOrNull!;
      await CreditReconcileService(
        accountRepository: accountRepo,
        ledgerRepository: ledgerRepo,
        clock: clock,
        idGen: UuidV7(),
      ).reconcile(
        account: acc, actualDebtCents: 48000, bookId: 'book-1', deviceId: 'dev-1',
      );

      // 存储值 48000；按账单聚合 = -(派生余额) = 48000 → 差额 0（AC8 无差异态）
      final derived = await accountRepo.derivedBalanceOf('acc-credit');
      expect(derived.successOrNull!.balanceCents, -48000);
      expect(
        CreditCardService.aggregateDiff(
          storedDebtCents: creditDebtCents(),
          balanceCents: derived.successOrNull!.balanceCents,
        ),
        0,
      );
    });

    test('an opening debt set at account creation is authoritative', () async {
      await accountRepo.create(Account(
        id: 'acc-new', name: '新卡', type: AccountType.credit,
        currency: 'CNY', openingBalance: 0, sortOrder: 2,
        creditLimitCents: 1000000, creditDebtCents: 300000,
        createdAt: clock.now(), updatedAt: clock.now(), deviceId: 'dev-1',
      ));
      final bal = await accountRepo.balanceOf('acc-new');
      expect(bal.successOrNull!.balanceCents, -300000);
    });
  });

  // ─────────────────────────── schema v12 ────────────────────────────

  group('schema v12', () {
    test('exclude_from_stats lands with a safe default', () {
      final tx = db.raw.select('PRAGMA table_info(transactions)');
      final col = tx.where((r) => r['name'] == 'exclude_from_stats');
      expect(col, hasLength(1));
      // NOT NULL DEFAULT 0 —— 历史行保持「计入收支」的原语义
      expect(col.first['notnull'], 1);
      expect(col.first['dflt_value'], '0');

      final ver = db.raw.select('PRAGMA user_version').first.values.first;
      expect(ver, kSchemaVersion);
    });

    test('rows written without the flag read back as not-excluded', () async {
      // 模拟 v11 老库升级后写入的行（默认值路径）
      db.raw.execute(
        'INSERT INTO transactions (id,book_id,type,amount_cents,currency,'
        'category_id,account_id,occurred_at,source,created_at,updated_at,'
        'revision,device_id,base_revision) '
        "VALUES ('old-1','book-1','expense',1200,'CNY','c-food','acc-cash',"
        "0,'manual',0,0,1,'dev-1',0)",
      );
      final e = (await ledgerRepo.getById('old-1')).successOrNull!;
      expect(e.excludeFromStats, false);
      expect(e.countsInCategoryStats, true);
    });

    test('a flagged row reads back as excluded', () async {
      db.raw.execute(
        'INSERT INTO transactions (id,book_id,type,amount_cents,currency,'
        'category_id,account_id,occurred_at,source,exclude_from_stats,'
        'created_at,updated_at,revision,device_id,base_revision) '
        "VALUES ('flag-1','book-1','expense',1200,'CNY','c-food','acc-cash',"
        "0,'manual',1,0,0,1,'dev-1',0)",
      );
      final e = (await ledgerRepo.getById('flag-1')).successOrNull!;
      expect(e.excludeFromStats, true);
      expect(e.countsInCategoryStats, false);
      expect(e.countsInOutflow, false);
      expect(e.affectsBalance, true);
    });
  });

  // ──────────────────── G-2.0 分类「N 笔」计数口径 ─────────────────────

  group('分类笔数计数', () {
    test('counts excluded entries but not reconcile adjustments', () async {
      await ledgerRepo.create(entry(cents: 2500, excludeFromStats: true));
      final kept = await categoryRepo.countLiveEntries(categoryId: 'c-food');
      // 标记「不计入收支」仍是一笔真实账单，照常计入 N 笔
      expect(kept.successOrNull, 1);

      await accountRepo.reconcile(
        accountId: 'acc-cash',
        actualBalanceCents: -1000,
        deviceId: 'dev-1',
        bookId: 'book-1',
        otherCategoryId: 'c-other',
      );
      final other = await categoryRepo.countLiveEntries(categoryId: 'c-other');
      // 对账调整的分类恒为「其他」，但不得出现在计数里
      expect(other.successOrNull, 0);
    });
  });

  // ────────────────────── 旧 schema 备份仍然可恢复 ──────────────────────

  group('旧版备份恢复', () {
    test('a v11-era transactions table restores into v12', () {
      final dir = Directory.systemTemp.createTempSync('plain_restore_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final backupPath = p.join(dir.path, 'old.sqlite');

      // 造一个 v11 形态的库：transactions 缺 exclude_from_stats
      final old = sqlite3.open(backupPath);
      old.execute('CREATE TABLE transactions ('
          'id TEXT NOT NULL PRIMARY KEY, book_id TEXT NOT NULL, type TEXT NOT NULL,'
          "amount_cents INTEGER NOT NULL, currency TEXT NOT NULL DEFAULT 'CNY',"
          'category_id TEXT NULL, account_id TEXT NULL, to_account_id TEXT NULL,'
          'occurred_at INTEGER NOT NULL, note TEXT NULL, source TEXT NOT NULL,'
          'batch_id TEXT NULL, split_role TEXT NOT NULL DEFAULT \'normal\','
          'parent_id TEXT NULL,'
          "reimburse_status TEXT NOT NULL DEFAULT 'none',"
          'reconciled_at INTEGER NULL, created_at INTEGER NOT NULL,'
          'updated_at INTEGER NOT NULL, deleted_at INTEGER NULL,'
          'revision INTEGER NOT NULL DEFAULT 1, device_id TEXT NOT NULL,'
          'base_revision INTEGER NOT NULL DEFAULT 0)');
      old.execute(
        'INSERT INTO transactions (id,book_id,type,amount_cents,category_id,'
        "account_id,occurred_at,source,created_at,updated_at,revision,device_id) "
        "VALUES ('old-a','book-1','expense',1500,'c-food','acc-cash',0,"
        "'manual',0,0,1,'dev-1')",
      );
      old.close();

      // 列数不匹配曾会让整表恢复抛错；现在按列交集迁移，新列取默认值
      db.restoreFrom(backupPath);

      final rows = db.raw.select('SELECT * FROM transactions');
      expect(rows, hasLength(1));
      expect(rows.first['id'], 'old-a');
      expect(rows.first['amount_cents'], 1500);
      expect(rows.first['exclude_from_stats'], 0);
      expect(rows.first['split_role'], 'normal');
    });

    test('savings_goals / rules / merchant_rules are carried over (08 C21)', () {
      final dir = Directory.systemTemp.createTempSync('plain_restore2_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final backupPath = p.join(dir.path, 'full.sqlite');

      // 备份侧只放这三张表，验证还原清单不再漏搬
      final old = sqlite3.open(backupPath);
      old.execute('CREATE TABLE savings_goals ('
          'id TEXT NOT NULL PRIMARY KEY, book_id TEXT NOT NULL, name TEXT NOT NULL,'
          "goal_type TEXT NOT NULL DEFAULT 'savings', target_cents INTEGER NOT NULL,"
          'saved_cents INTEGER NOT NULL DEFAULT 0, remaining_terms INTEGER NULL,'
          'due_at INTEGER NULL, account_id TEXT NULL,'
          'auto_transfer INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL,'
          'updated_at INTEGER NOT NULL, deleted_at INTEGER NULL,'
          'revision INTEGER NOT NULL DEFAULT 1, device_id TEXT NOT NULL,'
          'base_revision INTEGER NOT NULL DEFAULT 0)');
      old.execute(
        "INSERT INTO savings_goals (id,book_id,name,target_cents,created_at,"
        "updated_at,revision,device_id) VALUES "
        "('g1','book-1','车险',300000,0,0,1,'dev-1')",
      );
      old.close();

      db.restoreFrom(backupPath);

      final goals = db.raw.select('SELECT id, name, target_cents FROM savings_goals');
      expect(goals, hasLength(1));
      expect(goals.first['name'], '车险');
      expect(goals.first['target_cents'], 300000);
    });
  });
}
