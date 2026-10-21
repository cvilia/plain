/// STORY-8.1 增量同步：合并规则、落库、冲突、双端收敛。
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:plain/app/l10n/strings_core.dart';
import 'package:plain/core/id/uuid_v7.dart';
import 'package:plain/core/money/money.dart';
import 'package:plain/core/time/clock.dart';
import 'package:plain/data/db/database.dart';
import 'package:plain/data/repositories/account_repository.dart';
import 'package:plain/data/repositories/ledger_repository.dart';
import 'package:plain/data/repositories/sync_conflict_repository.dart';
import 'package:plain/data/sync/change_log_writer.dart';
import 'package:plain/data/sync/incremental_sync_service.dart';
import 'package:plain/data/sync/sync_applier.dart';
import 'package:plain/data/sync/sync_wire.dart';
import 'package:plain/data/sync/webdav_client.dart';
import 'package:plain/domain/entities/category.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/services/merge_engine.dart';
import 'package:plain/domain/services/sync_scope.dart';
import 'package:plain/domain/usecases/entry_usecases.dart';

/// 内存传输层：把「远端」实现成一个 Map，用来测双端收敛。
class _MemoryTransport implements SyncTransport {
  final Map<String, List<int>> files = {};

  @override
  Future<bool> ensureCollection(WebDavConfig config) async => true;

  @override
  Future<bool> put(WebDavConfig config, String fileName, List<int> bytes) async {
    files[fileName] = bytes;
    return true;
  }

  @override
  Future<List<int>?> get(WebDavConfig config, String fileName) async => files[fileName];

  @override
  Future<List<String>> list(WebDavConfig config) async => files.keys.toList();

  @override
  void dispose() {}
}

/// 一台「设备」的全套依赖。
class _Device {
  _Device(this.name, this.db, this.clock, this.transport) {
    final changeLog = ChangeLogWriter(db, clock: clock);
    idGen = UuidV7();
    ledger = LedgerRepositoryImpl(db: db, changeLogWriter: changeLog, clock: clock);
    accountRepo = AccountRepositoryImpl(db: db, changeLogWriter: changeLog, clock: clock);
    conflicts = SyncConflictRepositoryImpl(db: db);
    applier = SyncApplier(
      db: db,
      ledger: ledger,
      conflicts: conflicts,
      idGen: idGen,
      clock: clock,
      localDeviceId: name,
    );
    sync = IncrementalSyncService(
      db: db,
      client: transport,
      applier: applier,
      clock: clock,
      deviceId: name,
    );
    createEntry = CreateEntryUseCase(
      repository: ledger, clock: clock, idGen: idGen, memberRepository: null);
  }

  final String name;
  final AppDatabase db;
  final FixedClock clock;
  final SyncTransport transport;
  late final UuidV7 idGen;
  late final LedgerRepositoryImpl ledger;
  late final AccountRepositoryImpl accountRepo;
  late final SyncConflictRepositoryImpl conflicts;
  late final SyncApplier applier;
  late final IncrementalSyncService sync;
  late final CreateEntryUseCase createEntry;

  Future<void> seedAccount() async {
    await accountRepo.create(Account(
      id: 'acc-cash', name: '现金', type: AccountType.cash,
      currency: 'CNY', openingBalance: 0, sortOrder: 0,
      createdAt: clock.now(), updatedAt: clock.now(), deviceId: name,
    ));
  }

  Future<String> addExpense(int cents, {String? note}) async {
    final res = await createEntry(CreateEntryInput(
      amountExpression: '${cents / 100}',
      type: EntryType.expense,
      categoryId: '',
      accountId: 'acc-cash',
      note: note,
      bookId: 'book-1',
      deviceId: name,
    ), s: kDefaultAppStrings);
    expect(res.isSuccess, isTrue, reason: '${res.failureOrNull}');
    return res.requireValue.id;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('三方合并（纯函数）', () {
    test('AC2：两端改不同字段 → 自动合并，无冲突', () {
      final out = MergeEngine.merge(
        ancestor: {'amount_cents': 100, 'note': '原备注'},
        local: {'amount_cents': 200, 'note': '原备注'},
        remote: {'amount_cents': 100, 'note': '新备注'},
        localChangedAt: DateTime.utc(2026, 1, 2),
        remoteChangedAt: DateTime.utc(2026, 1, 1),
      );
      expect(out.merged['amount_cents'], 200);
      expect(out.merged['note'], '新备注');
      expect(out.hasConflicts, isFalse);
    });

    test('AC3：同一字段改成不同值 → 冲突，最后写入者胜', () {
      final out = MergeEngine.merge(
        ancestor: {'amount_cents': 100},
        local: {'amount_cents': 200},
        remote: {'amount_cents': 300},
        localChangedAt: DateTime.utc(2026, 1, 1),
        remoteChangedAt: DateTime.utc(2026, 1, 2),
      );
      expect(out.merged['amount_cents'], 300, reason: '远端更晚');
      expect(out.conflicts.length, 1);
      expect(out.conflicts.first.winner, ConflictWinner.remote);
      expect(out.conflicts.first.ancestorValue, 100);
    });

    test('两边改成同一个值 → 不算冲突', () {
      final out = MergeEngine.merge(
        ancestor: {'note': 'a'},
        local: {'note': 'b'},
        remote: {'note': 'b'},
        localChangedAt: DateTime.utc(2026, 1, 1),
        remoteChangedAt: DateTime.utc(2026, 1, 2),
      );
      expect(out.hasConflicts, isFalse);
      expect(out.merged['note'], 'b');
    });

    test('时间戳相同 → 按 deviceId 定胜负（两端算出同一赢家）', () {
      final at = DateTime.utc(2026, 1, 1);
      final a = MergeEngine.merge(
        local: {'note': 'local'},
        remote: {'note': 'remote'},
        localChangedAt: at,
        remoteChangedAt: at,
        localDeviceId: 'dev-a',
        remoteDeviceId: 'dev-b',
      );
      final b = MergeEngine.merge(
        local: {'note': 'remote'},
        remote: {'note': 'local'},
        localChangedAt: at,
        remoteChangedAt: at,
        localDeviceId: 'dev-b',
        remoteDeviceId: 'dev-a',
      );
      // 两端都得到「dev-b 的设备值胜出」
      expect(a.merged['note'], 'remote');
      expect(b.merged['note'], 'remote');
    });

    test('布尔与 0/1 视为同一个值（JSON 与库表示不同）', () {
      final out = MergeEngine.merge(
        ancestor: {'exclude_from_stats': 0},
        local: {'exclude_from_stats': 1},
        remote: {'exclude_from_stats': true},
        localChangedAt: DateTime.utc(2026, 1, 1),
        remoteChangedAt: DateTime.utc(2026, 1, 2),
      );
      expect(out.hasConflicts, isFalse);
    });
  });

  group('同步范围（AC5）', () {
    test('只留同步范围内的实体类型', () {
      SyncRecord rec(String type) => SyncRecord(
            localRevision: 1,
            entityType: type,
            entityId: 'x',
            op: ChangeOp.insert,
            deviceId: 'd',
            baseRevision: 0,
            changedAt: DateTime.utc(2026, 1, 1),
            before: const {},
            after: const {},
          );
      final filtered = SyncWire.filterSyncable([
        rec('transaction'),
        rec('member'),
        rec('theme'),
        rec('pref'),
        rec('homeCardLayout'),
      ]);
      expect(filtered.map((r) => r.entityType).toList(),
          ['transaction', 'member']);
    });

    test('AC5：上传内容里不出现本地偏好键', () {
      final records = [
        SyncRecord(
          localRevision: 1,
          entityType: 'transaction',
          entityId: 't1',
          op: ChangeOp.insert,
          deviceId: 'd',
          baseRevision: 0,
          changedAt: DateTime.utc(2026, 1, 1),
          before: const {},
          after: const {'note': '午饭', 'amount_cents': 2000},
        ),
        SyncRecord(
          localRevision: 2,
          entityType: 'setting',
          entityId: 'pref.month_start_day',
          op: ChangeOp.update,
          deviceId: 'd',
          baseRevision: 0,
          changedAt: DateTime.utc(2026, 1, 1),
          before: const {'key': 'pref.month_start_day', 'value': '1'},
          after: const {'key': 'pref.month_start_day', 'value': '10'},
        ),
      ];
      final bytes = SyncWire.encodeLines(SyncWire.filterSyncable(records));
      final text = utf8.decode(bytes);
      for (final key in SyncWire.forbiddenKeys) {
        expect(text.contains(key), isFalse, reason: '不该出现 $key');
      }
      // 往返一致
      final back = SyncWire.decodeLines(bytes);
      expect(back.length, 2);
      expect(back.last.after['value'], '10');
    });

    test('本地偏好键不属于可同步设置', () {
      expect(isSyncedSetting('pref.month_start_day'), isTrue);
      expect(isSyncedSetting('pref.theme.id'), isFalse);
      expect(isSyncedSetting('webdav.pass'), isFalse);
    });
  });

  group('双端收敛', () {
    late _MemoryTransport transport;
    late _Device a;
    late _Device b;

    setUp(() async {
      transport = _MemoryTransport();
      a = _Device('dev-a', AppDatabase.inMemory(), FixedClock(DateTime.utc(2026, 1, 1, 9)), transport);
      b = _Device('dev-b', AppDatabase.inMemory(), FixedClock(DateTime.utc(2026, 1, 1, 9)), transport);
      await a.seedAccount();
      await b.seedAccount();
    });

    tearDown(() {
      a.db.close();
      b.db.close();
    });

    Future<int> expenseOf(_Device d) async {
      final rows = d.db.raw.select(
          "SELECT COALESCE(SUM(expense_cents),0) AS s FROM daily_stats WHERE book_id = 'book-1'");
      return (rows.first['s'] as int?) ?? 0;
    }

    test('AC1：A 记账 → 推送 → B 拉取后可见，统计口径一致', () async {
      final id = await a.addExpense(3000, note: '午饭');
      expect(await expenseOf(a), 3000);

      final pushRes = await a.sync.push(WebDavConfig(baseUrl: 'x', username: '', password: ''));
      expect(pushRes.success, isTrue);

      final pullRes = await b.sync.pull(WebDavConfig(baseUrl: 'x', username: '', password: ''));
      expect(pullRes.success, isTrue);
      expect(pullRes.pulled, greaterThan(0));

      final entry = await b.ledger.getById(id);
      expect(entry.isSuccess, isTrue);
      expect(entry.requireValue.amount.cents, 3000);
      // 统计也跟着走了（不能只搬行不修统计）
      expect(await expenseOf(b), 3000);
    });

    test('重复拉取不重复应用（位点推进）', () async {
      await a.addExpense(3000);
      await a.sync.push(WebDavConfig(baseUrl: 'x', username: '', password: ''));
      await b.sync.pull(WebDavConfig(baseUrl: 'x', username: '', password: ''));
      final second = await b.sync.pull(WebDavConfig(baseUrl: 'x', username: '', password: ''));
      expect(second.pulled, 0);
      expect(await expenseOf(b), 3000);
    });

    test('AC2：两端改不同字段 → 合并成功且无冲突', () async {
      final id = await a.addExpense(3000, note: '午饭');
      await a.sync.push(WebDavConfig(baseUrl: 'x', username: '', password: ''));
      await b.sync.pull(WebDavConfig(baseUrl: 'x', username: '', password: ''));

      // A 改备注；B 改金额（不同字段）
      final onA = (await a.ledger.getById(id)).requireValue;
      final updA = await a.ledger.update(onA.copyWith(note: 'A 改的备注', updatedAt: a.clock.now()));
      expect(updA.isSuccess, isTrue, reason: '${updA.failureOrNull}');
      final onB = (await b.ledger.getById(id)).requireValue;
      final updB = await b.ledger.update(onB.copyWith(amount: Money(4500), updatedAt: b.clock.now()));
      expect(updB.isSuccess, isTrue, reason: '${updB.failureOrNull}');
      expect((await a.ledger.getById(id)).requireValue.note, 'A 改的备注');

      // B 先推，A 拉；然后 A 推，B 拉
      await b.sync.push(WebDavConfig(baseUrl: 'x', username: '', password: ''));
      await a.sync.pull(WebDavConfig(baseUrl: 'x', username: '', password: ''));
      await a.sync.push(WebDavConfig(baseUrl: 'x', username: '', password: ''));
      await b.sync.pull(WebDavConfig(baseUrl: 'x', username: '', password: ''));

      // 两端都拿到「金额 4500 + 备注 A 改的备注」，且没有任何冲突
      for (final d in [a, b]) {
        final e = (await d.ledger.getById(id)).requireValue;
        expect(e.amount.cents, 4500, reason: d.name);
        expect(e.note, 'A 改的备注', reason: d.name);
        expect((await d.conflicts.countOpen(bookId: 'book-1')).requireValue, 0,
            reason: d.name);
      }
    });

    test('AC3：两端改同一字段 → 生成冲突，两端结论一致', () async {
      final id = await a.addExpense(3000, note: '午饭');
      await a.sync.push(WebDavConfig(baseUrl: 'x', username: '', password: ''));
      await b.sync.pull(WebDavConfig(baseUrl: 'x', username: '', password: ''));

      // B 先改（时间早），A 后改（时间晚）→ A 应胜出
      final onB = (await b.ledger.getById(id)).requireValue;
      await b.ledger.update(onB.copyWith(amount: Money(1000), updatedAt: b.clock.now()));
      final onA = (await a.ledger.getById(id)).requireValue;
      a.clock.advance(const Duration(minutes: 5));
      await a.ledger.update(onA.copyWith(amount: Money(2000), updatedAt: a.clock.now()));

      await b.sync.push(WebDavConfig(baseUrl: 'x', username: '', password: ''));
      await a.sync.push(WebDavConfig(baseUrl: 'x', username: '', password: ''));
      await a.sync.pull(WebDavConfig(baseUrl: 'x', username: '', password: ''));
      await b.sync.pull(WebDavConfig(baseUrl: 'x', username: '', password: ''));

      // 两端都产生了一条待裁决冲突，且金额取「最后写入」的 A 版
      for (final d in [a, b]) {
        expect((await d.conflicts.countOpen(bookId: 'book-1')).requireValue, 1,
            reason: d.name);
        final e = (await d.ledger.getById(id)).requireValue;
        expect(e.amount.cents, 2000, reason: '${d.name} 应取更晚写入的 2000');
      }
      final conflict = (await a.conflicts.listOpen(bookId: 'book-1')).requireValue.first;
      expect(conflict.field, 'amount_cents');
      // A 本机这一版更晚 → 本机胜出，冲突留给用户裁决
      expect(conflict.winner, 'local');
      expect(conflict.localValue, '2000');
      expect(conflict.remoteValue, '1000');
    });

    test('删除也同步，且统计回滚', () async {
      final id = await a.addExpense(3000);
      await a.sync.push(WebDavConfig(baseUrl: 'x', username: '', password: ''));
      await b.sync.pull(WebDavConfig(baseUrl: 'x', username: '', password: ''));
      expect(await expenseOf(b), 3000);

      await a.ledger.softDelete(id);
      await a.sync.push(WebDavConfig(baseUrl: 'x', username: '', password: ''));
      await b.sync.pull(WebDavConfig(baseUrl: 'x', username: '', password: ''));

      final e = (await b.ledger.getById(id)).requireValue;
      expect(e.isDeleted, isTrue);
      expect(await expenseOf(b), 0);
    });


    test('清空类改动能同步过去（远端置 null 也是改动）', () async {
      final id = await a.addExpense(3000, note: '午饭');
      await a.sync.push(WebDavConfig(baseUrl: 'x', username: '', password: ''));
      await b.sync.pull(WebDavConfig(baseUrl: 'x', username: '', password: ''));
      expect((await b.ledger.getById(id)).requireValue.note, '午饭');

      // A 把备注清空 → 这是「把列置 null」，必须能传到 B
      final onA = (await a.ledger.getById(id)).requireValue;
      await a.ledger.update(onA.copyWith(clearNote: true, updatedAt: a.clock.now()));
      await a.sync.push(WebDavConfig(baseUrl: 'x', username: '', password: ''));
      await b.sync.pull(WebDavConfig(baseUrl: 'x', username: '', password: ''));

      expect((await b.ledger.getById(id)).requireValue.note, isNull,
          reason: '清空备注属于真实改动，不能被当成「没变化」跳过');
    });

    test('备份还原后抬日志世代，对端会全量重放（不会因位点卡住）', () async {
      final id = await a.addExpense(3000, note: '午饭');
      await a.sync.push(WebDavConfig(baseUrl: 'x', username: '', password: ''));
      await b.sync.pull(WebDavConfig(baseUrl: 'x', username: '', password: ''));
      expect((await b.ledger.getById(id)).requireValue.amount.cents, 3000);
      // 两边位点都推到高位了：再拉一次没有新内容
      expect((await b.sync.pull(WebDavConfig(baseUrl: 'x', username: '', password: ''))).pulled, 0);

      // 模拟 A 从备份还原：change_log 被换成旧行 + 抬世代
      invalidateSyncPeerView(db: a.db, clock: a.clock);
      await a.sync.push(WebDavConfig(baseUrl: 'x', username: '', password: ''));

      final replayed = await b.sync.pull(WebDavConfig(baseUrl: 'x', username: '', password: ''));
      expect(replayed.pulled, greaterThan(0),
          reason: '换世代 = 对端把 A 当新设备，位点从 0 重放（否则被还原掉的变更永远推不出去）');
    });

    test('可同步设置传播（月起始日），本地偏好不传', () async {
      // A 改月起始日 → 记一条 setting 变更并推送
      b.db.raw.execute(
        "INSERT INTO app_meta (key,value,updated_at) VALUES ('pref.month_start_day','1',0)");
      a.db.raw.execute(
        "INSERT INTO app_meta (key,value,updated_at) VALUES ('pref.month_start_day','1',0)");
      writeSyncedSetting(
        db: a.db,
        changeLog: ChangeLogWriter(a.db, clock: a.clock),
        deviceId: a.name,
        key: 'pref.month_start_day',
        value: '10',
      );
      a.db.raw.execute(
        "UPDATE app_meta SET value='10' WHERE key='pref.month_start_day'");

      await a.sync.push(WebDavConfig(baseUrl: 'x', username: '', password: ''));
      await b.sync.pull(WebDavConfig(baseUrl: 'x', username: '', password: ''));

      final rows = b.db.raw
          .select("SELECT value FROM app_meta WHERE key='pref.month_start_day'");
      expect(rows.first['value'], '10');
    });

    test('对端日志被裁掉一段 → 记缺口，不静默少账', () async {
      const cfg = WebDavConfig(baseUrl: 'x', username: '', password: '');
      await a.addExpense(1000, note: '第一次');
      await a.sync.push(cfg);
      await b.sync.pull(cfg);
      expect(
        b.db.raw.select("SELECT value FROM app_meta WHERE key = 'sync.gap.dev-a'"),
        isEmpty,
        reason: '正常增量不该报缺口',
      );

      // A 的旧日志被 GC 掉（或整库还原换了一套日志），后面的变更从 3 开始
      a.db.raw.execute('DELETE FROM change_log WHERE local_revision <= 2');
      await a.addExpense(2000, note: '第二次');
      await a.sync.push(cfg);

      // B 的位点回到 0（模拟「离线太久 / 位点被重置」）
      b.db.raw.execute("UPDATE sync_state SET value = '0' WHERE key = 'cursor.dev-a'");
      await b.sync.pull(cfg);

      final gap = b.db.raw
          .select("SELECT value FROM app_meta WHERE key = 'sync.gap.dev-a'");
      expect(gap, hasLength(1), reason: '缺口必须留痕，否则用户只看到「同步成功」');
      final decoded = jsonDecode(gap.first['value']! as String) as Map<String, Object?>;
      expect(decoded['expected'], 1);
      expect(decoded['received'], greaterThan(1));
    });
  });
}
