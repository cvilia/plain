/// 2026-10-15 深度互联业务逻辑审计的回归测试。
///
/// 每条对应审计发现的一个真实缺陷，防止再次退化。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:plain/app/l10n/strings_core.dart';
import 'package:plain/core/id/uuid_v7.dart';
import 'package:plain/core/money/money.dart';
import 'package:plain/core/time/clock.dart';
import 'package:plain/data/db/database.dart';
import 'package:plain/data/repositories/account_repository.dart';
import 'package:plain/data/repositories/budget_repository.dart';
import 'package:plain/data/repositories/category_repository.dart';
import 'package:plain/data/repositories/ledger_repository.dart';
import 'package:plain/data/sync/change_log_writer.dart';
import 'package:plain/domain/entities/category.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/services/reconcile_mode_service.dart';
import 'package:plain/domain/usecases/entry_usecases.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  const bookId = 'book-1';
  const deviceId = 'dev-1';

  late AppDatabase db;
  late FixedClock clock;
  late LedgerRepositoryImpl ledgerRepo;
  late CategoryRepositoryImpl catRepo;
  late BudgetRepositoryImpl budgetRepo;
  late CreateEntryUseCase createEntry;

  setUp(() async {
    db = AppDatabase.inMemory();
    clock = FixedClock(DateTime.utc(2026, 10, 15, 12));
    final changeLog = ChangeLogWriter(db, clock: clock);
    ledgerRepo = LedgerRepositoryImpl(db: db, changeLogWriter: changeLog, clock: clock);
    catRepo = CategoryRepositoryImpl(db: db, changeLogWriter: changeLog, clock: clock);
    budgetRepo = BudgetRepositoryImpl(db: db, changeLogWriter: changeLog, clock: clock);
    createEntry = CreateEntryUseCase(repository: ledgerRepo, clock: clock, idGen: UuidV7());

    final accountRepo = AccountRepositoryImpl(db: db, changeLogWriter: changeLog, clock: clock);
    await accountRepo.create(Account(
      id: 'acc-cash', name: '现金', type: AccountType.cash,
      currency: 'CNY', openingBalance: 0, sortOrder: 0,
      createdAt: clock.now(), updatedAt: clock.now(), deviceId: deviceId,
    ));
    for (final (id, name) in [('c-a', '餐饮'), ('c-b', '外卖')]) {
      await catRepo.create(Category(
        id: id, name: name, kind: CategoryKind.expense, iconRef: 'other',
        sortOrder: 0, createdAt: clock.now(), updatedAt: clock.now(),
        deviceId: deviceId,
      ));
    }
  });

  tearDown(() => db.close());

  Future<String> addExpense(int cents, {String categoryId = 'c-a'}) async {
    final res = await createEntry(CreateEntryInput(
      amountExpression: '${cents / 100}', type: EntryType.expense,
      categoryId: categoryId, accountId: 'acc-cash',
      bookId: bookId, deviceId: deviceId,
    ), s: kDefaultAppStrings);
    expect(res.isSuccess, isTrue, reason: '${res.failureOrNull}');
    return res.requireValue.id;
  }

  /// daily_stats 里某分类的支出合计。
  int statsOf(String categoryId) {
    final rows = db.raw.select(
      'SELECT COALESCE(SUM(expense_cents),0) AS s FROM daily_stats '
      'WHERE book_id = ? AND category_id = ?',
      [bookId, categoryId],
    );
    return (rows.first['s'] as int?) ?? 0;
  }

  int statsTotal() {
    final rows = db.raw.select(
      'SELECT COALESCE(SUM(expense_cents),0) AS s FROM daily_stats WHERE book_id = ?',
      [bookId],
    );
    return (rows.first['s'] as int?) ?? 0;
  }

  group('审计修复：预算口径', () {
    test('「不计入收支」的账单不算进预算（原先把超支算出来了）', () async {
      final id = await addExpense(30000);
      final entry = (await ledgerRepo.getById(id)).requireValue;
      // 手动标记「不计入收支」
      final marked = entry.copyWith(
        excludeFromStats: true, updatedAt: clock.now(),
        revision: entry.revision + 1, baseRevision: entry.revision,
      );
      expect((await ledgerRepo.update(marked)).isSuccess, isTrue);

      final spent = await budgetRepo.spentCents(
        bookId: bookId, categoryId: 'c-a',
        fromMs: clock.now().subtract(const Duration(days: 1)).millisecondsSinceEpoch,
        toMs: clock.now().add(const Duration(days: 1)).millisecondsSinceEpoch,
      );
      expect(spent.requireValue, 0, reason: '被排除的账单不该占额度');
    });

    test('未排除的账单照常计入预算', () async {
      await addExpense(30000);
      final spent = await budgetRepo.spentCents(
        bookId: bookId, categoryId: 'c-a',
        fromMs: clock.now().subtract(const Duration(days: 1)).millisecondsSinceEpoch,
        toMs: clock.now().add(const Duration(days: 1)).millisecondsSinceEpoch,
      );
      expect(spent.requireValue, 30000);
    });
  });

  group('审计修复：分类改派要搬统计', () {
    test('分类删除改派：金额跟着搬到兜底分类', () async {
      await addExpense(30000);
      expect(statsOf('c-a'), 30000);

      final res = await catRepo.deleteAndReassign(
        categoryId: 'c-a', fallbackCategoryId: 'c-b',
      );
      expect(res.isSuccess, isTrue, reason: '${res.failureOrNull}');

      expect(statsOf('c-a'), 0, reason: '旧分类不该再挂金额');
      expect(statsOf('c-b'), 30000, reason: '新分类应接手');
      expect(statsTotal(), 30000, reason: '总额不变');
    });

    test('分类合并：金额跟着搬到目标分类，且 payload 是整行', () async {
      final entryId = await addExpense(30000);
      final res = await catRepo.mergeCategories(sourceId: 'c-a', targetId: 'c-b');
      expect(res.isSuccess, isTrue, reason: '${res.failureOrNull}');
      expect(statsOf('c-a'), 0);
      expect(statsOf('c-b'), 30000);

      // 同步日志必须是整行 payload（只写 category_id 会让对端插入失败 → 同步卡死）
      final rows = db.raw.select(
        "SELECT payload FROM change_log WHERE entity_type='transaction' AND entity_id=? "
        'ORDER BY local_revision DESC LIMIT 1',
        [entryId],
      );
      final payload = rows.first['payload']! as String;
      for (final key in ['amount_cents', 'book_id', 'occurred_at', 'type', 'created_at', 'device_id']) {
        expect(payload.contains('"$key"'), isTrue, reason: 'payload 缺列 $key');
      }
    });
  });

  group('审计修复：对账取消勾选', () {
    test('uncheck 真的清掉对账标记（原先 copyWith 吃掉 null）', () async {
      final id = await addExpense(10000);
      final service = ReconcileModeService(repository: ledgerRepo, clock: clock);
      final entry = (await ledgerRepo.getById(id)).requireValue;

      final checked = await service.check(entry);
      expect(checked.requireValue.isReconciled, isTrue);

      final unchecked = await service.uncheck(checked.requireValue);
      expect(unchecked.requireValue.isReconciled, isFalse, reason: '取消勾选要生效');
      final reread = (await ledgerRepo.getById(id)).requireValue;
      expect(reread.isReconciled, isFalse);
      expect(reread.reconciledAt, isNull);
    });
  });

  group('审计修复：备份还原的设备身份', () {
    test('保留本机 device.id，但采用备份的账本 id', () async {
      void setMeta(AppDatabase d, String k, String v) {
        d.raw.execute(
          'INSERT INTO app_meta (key,value,updated_at) VALUES (?,?,?) '
          'ON CONFLICT(key) DO UPDATE SET value=?,updated_at=?',
          [k, v, 0, v, 0],
        );
      }

      setMeta(db, 'device.id', 'dev-local');
      setMeta(db, 'book.default_id', 'book-local');

      // 造一个「备份机」的库
      final dir = await Directory.systemTemp.createTemp('audit_restore');
      addTearDown(() => dir.delete(recursive: true));
      final backupPath = '${dir.path}/backup.db';
      final backup = sqlite3.open(backupPath);
      backup.execute('CREATE TABLE app_meta (key TEXT PRIMARY KEY, value TEXT, updated_at INTEGER)');
      backup.execute("INSERT INTO app_meta VALUES ('device.id','dev-backup',0)");
      backup.execute("INSERT INTO app_meta VALUES ('book.default_id','book-backup',0)");
      backup.close();

      db.restoreFrom(backupPath);

      String metaOf(String k) {
        final rows = db.raw.select('SELECT value FROM app_meta WHERE key = ?', [k]);
        return rows.isEmpty ? '' : rows.first['value']! as String;
      }

      expect(metaOf('device.id'), 'dev-local',
          reason: '设备身份不能被备份覆盖，否则两端 deviceId 相同 → 同步互相跳过');
      expect(metaOf('book.default_id'), 'book-backup',
          reason: '账本 id 必须跟备份走，否则恢复后按 bookId 查不到数据');
    });
  });
  group('口径：外币贷款不参与债务测算（2026-10-15 拍板）', () {
    Account loan(String id, String currency) => Account(
          id: id, name: '贷款$id', type: AccountType.loanIn, currency: currency,
          openingBalance: 0, sortOrder: 0,
          createdAt: clock.now(), updatedAt: clock.now(), deviceId: deviceId,
        );

    test('本位币贷款参与；外币贷款不参与且需手动维护', () {
      expect(loan('l-cny', 'CNY').supportsDebtTracking, isTrue);
      expect(loan('l-cny', 'CNY').needsManualDebtNote, isFalse);

      final usd = loan('l-usd', 'USD');
      expect(usd.isForeignCurrency, isTrue);
      expect(usd.supportsDebtTracking, isFalse, reason: '本金原币、流水本位币，算不出可信剩余本金');
      expect(usd.needsManualDebtNote, isTrue, reason: '界面要明确标注，不能静默少算');
    });

    test('外币标记只对贷款成立：外币储蓄账户不受影响', () {
      final deposit = Account(
        id: 'acc-usd', name: '美元储蓄', type: AccountType.cash, currency: 'USD',
        openingBalance: 0, sortOrder: 0,
        createdAt: clock.now(), updatedAt: clock.now(), deviceId: deviceId,
      );
      expect(deposit.isForeignCurrency, isTrue);
      expect(deposit.needsManualDebtNote, isFalse, reason: '它不是负债，走汇折算那条路径');
      expect(deposit.supportsDebtTracking, isFalse, reason: '本就不是债务账户');
    });
  });
}

/// Money 仅用于断言可读性（保持与生产代码一致的构造方式）。
// ignore: unused_element
Money _m(int cents) => Money(cents);
