/// 代码审查第三轮（2026-10-20）收口：五件事的回归测试。
///
/// ① 同步 payload 必须带**必填审计列**（created_at / updated_at / device_id…）：
///    DDL 里它们是 `NOT NULL` 且无默认值，漏了会让对端「插入新行」直接抛
///    NOT NULL，`applyAll` 整批失败、位点不推进 —— 该设备永久卡在同一行。
/// ② `ColumnWriter.upsert` 对「部分列 payload」的兜底：即便将来又有旁路写出
///    少列的 payload，也只能是「这列取默认值」，不能是「整条同步卡死」。
/// ③ 储蓄目标删除要进 change_log（原先只改本机，对端永远删不掉）。
/// ④ 目标/持仓/报表的 `before` 必须是改动前的整行（空 map = 无共同祖先 →
///    每次线性修改都产生一批假冲突）。
/// ⑤ 分类换父级必须真的落库（`_update` 的 SET 原先漏了 `parent_id`，
///    于是「对端生效、本机没动」，两端分类树分叉）。
/// ⑥ 流水页翻页失败不能自动重试（否则每帧一次 SQL 的死循环）。
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plain/app/bootstrap.dart';
import 'package:plain/app/l10n/strings_core.dart';
import 'package:plain/core/id/uuid_v7.dart';
import 'package:plain/core/time/clock.dart';
import 'package:plain/data/db/column_writer.dart';
import 'package:plain/data/db/database.dart';
import 'package:plain/data/repositories/account_repository.dart';
import 'package:plain/data/repositories/category_repository.dart';
import 'package:plain/data/repositories/change_log_repository.dart';
import 'package:plain/data/repositories/ledger_repository.dart';
import 'package:plain/data/repositories/savings_goal_repository.dart';
import 'package:plain/data/repositories/sync_conflict_repository.dart';
import 'package:plain/data/sync/change_log_writer.dart';
import 'package:plain/data/sync/sync_applier.dart';
import 'package:plain/data/sync/sync_wire.dart';
import 'package:plain/domain/entities/category.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/entities/savings_goal.dart';
import 'package:plain/domain/usecases/entry_usecases.dart';
import 'package:plain/features/ledger/controllers/entry_input_controller.dart';
import 'package:plain/features/ledger/controllers/flow_list_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kBook = 'book-1';
const String kDeviceA = 'dev-a';
const String kDeviceB = 'dev-b';

/// change_log 当前全部行 → 同步记录（与 `IncrementalSyncService` 同口径）。
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
          (row['changed_at']! as num).toInt(),
          isUtc: true),
      before: before is Map<String, Object?> ? before : const {},
      after: after is Map<String, Object?> ? after : const {},
    ));
  }
  return out;
}

List<SyncRecord> recordsOfType(AppDatabase db, String entityType) =>
    [for (final r in recordsOf(db)) if (r.entityType == entityType) r];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase dbA;
  late AppDatabase dbB;
  late FixedClock clock;
  late ChangeLogWriter changeLog;
  late AccountRepositoryImpl accountRepo;
  late SavingsGoalRepositoryImpl goalRepo;
  late CategoryRepositoryImpl catRepo;
  late SyncApplier applierB;

  SyncApplier applierFor(AppDatabase db, String deviceId) => SyncApplier(
        db: db,
        ledger: LedgerRepositoryImpl(
            db: db, changeLogWriter: ChangeLogWriter(db, clock: clock), clock: clock),
        conflicts: SyncConflictRepositoryImpl(db: db),
        idGen: UuidV7(),
        clock: clock,
        localDeviceId: deviceId,
      );

  setUp(() {
    dbA = AppDatabase.inMemory();
    dbB = AppDatabase.inMemory();
    clock = FixedClock(DateTime.utc(2026, 10, 20, 10));
    changeLog = ChangeLogWriter(dbA, clock: clock);
    accountRepo = AccountRepositoryImpl(db: dbA, changeLogWriter: changeLog, clock: clock);
    goalRepo = SavingsGoalRepositoryImpl(
        db: dbA, changeLogWriter: changeLog, now: clock.now);
    catRepo = CategoryRepositoryImpl(db: dbA, changeLogWriter: changeLog, clock: clock);
    applierB = applierFor(dbB, kDeviceB);
  });

  tearDown(() {
    dbA.close();
    dbB.close();
  });

  // ① ── 必填审计列 ──
  group('① 同步 payload 带齐必填审计列', () {
    test('账户：对端「本地没有 → 直接插入」不再失败', () async {
      final created = await accountRepo.create(Account(
        id: 'acc-1', name: '现金', type: AccountType.cash,
        currency: 'CNY', openingBalance: 100000, sortOrder: 1,
        createdAt: clock.now(), updatedAt: clock.now(), deviceId: kDeviceA,
      ));
      expect(created.isSuccess, isTrue, reason: created.failureOrNull?.toString() ?? '');

      final payload = (jsonDecode(dbA.raw
              .select("SELECT payload FROM change_log WHERE entity_type = 'account'")
              .first['payload']! as String) as Map<String, Object?>)['after']!
          as Map<String, Object?>;
      for (final col in [
        'created_at', 'updated_at', 'revision', 'device_id', 'base_revision',
      ]) {
        expect(payload.containsKey(col), isTrue,
            reason: 'account payload 缺 $col → 对端 INSERT 必抛 NOT NULL');
      }

      final applied = await applierB.applyAll(
          recordsOfType(dbA, 'account'), writerDeviceId: kDeviceA);
      expect(applied.isSuccess, isTrue,
          reason: applied.failureOrNull?.toString() ?? '');
      final onB = dbB.raw.select('SELECT * FROM accounts WHERE id = ?', ['acc-1']);
      expect(onB, hasLength(1));
      expect(onB.first['device_id'], kDeviceA);
      expect(onB.first['created_at'], clock.now().millisecondsSinceEpoch);
    });

    test('目标 / 分类同理，且 category 换父级本机真的落库', () async {
      await goalRepo.create(SavingsGoal(
        id: 'goal-1', bookId: kBook, name: '换车', targetCents: 500000,
        savedCents: 0, createdAt: clock.now(), updatedAt: clock.now(),
        deviceId: kDeviceA,
      ));
      final goalSync = await applierB.applyAll(
          recordsOfType(dbA, 'savings_goal'), writerDeviceId: kDeviceA);
      expect(goalSync.isSuccess, isTrue, reason: goalSync.failureOrNull?.toString() ?? '');
      expect(dbB.raw.select('SELECT * FROM savings_goals WHERE id = ?', ['goal-1']),
          hasLength(1));

      Category mk(String id, String name, {String? parentId}) => Category(
            id: id, parentId: parentId, name: name, kind: CategoryKind.expense,
            iconRef: 'other', sortOrder: 0, isPreset: false,
            createdAt: clock.now(), updatedAt: clock.now(), deviceId: kDeviceA,
          );
      await catRepo.create(mk('g-food', '餐饮'));
      await catRepo.create(mk('g-shop', '购物'));
      await catRepo.create(mk('c-breakfast', '早餐', parentId: 'g-food'));

      final moved = await catRepo.moveToParent(
          categoryId: 'c-breakfast', newParentId: 'g-shop');
      expect(moved.isSuccess, isTrue, reason: moved.failureOrNull?.toString() ?? '');
      final localRow = dbA.raw
          .select('SELECT parent_id, revision FROM categories WHERE id = ?', ['c-breakfast'])
          .first;
      expect(localRow['parent_id'], 'g-shop',
          reason: 'SET 漏 parent_id 会「对端生效、本机没动」');
      expect(localRow['revision'], 2);

      final catSync = await applierB.applyAll(
          recordsOfType(dbA, 'category'), writerDeviceId: kDeviceA);
      expect(catSync.isSuccess, isTrue, reason: catSync.failureOrNull?.toString() ?? '');
      expect(
        dbB.raw.select('SELECT parent_id FROM categories WHERE id = ?', ['c-breakfast'])
            .first['parent_id'],
        'g-shop',
        reason: '两端分类树必须一致',
      );
    });

    test('兜底：部分列 payload 也只取默认值，不会让同步整批卡死', () {
      // 模拟一条「只有 id + name」的旁路 payload（历史版本 / 未来新加的表）
      ColumnWriter.upsert(dbB, 'accounts', {'id': 'acc-partial', 'name': '旧客户端'});
      final row =
          dbB.raw.select('SELECT * FROM accounts WHERE id = ?', ['acc-partial']).first;
      expect(row['created_at'], isA<int>());
      expect((row['created_at']! as int) > 0, isTrue);
      expect(row['revision'], 1);
      expect(row['base_revision'], 0);
    });
  });

  // ② ── 目标删除进 change_log ──
  test('② 删除储蓄目标会写 delete 变更，并能传到对端', () async {
    await goalRepo.create(SavingsGoal(
      id: 'goal-1', bookId: kBook, name: '换车', targetCents: 500000,
      savedCents: 0, createdAt: clock.now(), updatedAt: clock.now(),
      deviceId: kDeviceA,
    ));
    final created = await applierB.applyAll(
        recordsOfType(dbA, 'savings_goal'), writerDeviceId: kDeviceA);
    expect(created.isSuccess, isTrue, reason: created.failureOrNull?.toString() ?? '');

    final del = await goalRepo.softDelete('goal-1');
    expect(del.isSuccess, isTrue, reason: del.failureOrNull?.toString() ?? '');

    final logs = dbA.raw.select(
        "SELECT op FROM change_log WHERE entity_type = 'savings_goal' "
        'ORDER BY local_revision');
    expect(logs.last['op'], 'delete', reason: '不记 delete 就等于「只在本机删了」');

    final applied = await applierB.applyAll(
        recordsOfType(dbA, 'savings_goal'), writerDeviceId: kDeviceA);
    expect(applied.isSuccess, isTrue, reason: applied.failureOrNull?.toString() ?? '');
    expect(
      dbB.raw.select('SELECT deleted_at FROM savings_goals WHERE id = ?', ['goal-1'])
          .first['deleted_at'],
      isNotNull,
      reason: '对端要跟着软删',
    );
  });

  // ③ ── before 必须是改动前的整行 ──
  test('③ 目标 update 的 before 非空 → 对端应用零冲突', () async {
    await goalRepo.create(SavingsGoal(
      id: 'goal-1', bookId: kBook, name: '换车', targetCents: 500000,
      savedCents: 0, createdAt: clock.now(), updatedAt: clock.now(),
      deviceId: kDeviceA,
    ));
    final first = await applierB.applyAll(
        recordsOfType(dbA, 'savings_goal'), writerDeviceId: kDeviceA);
    expect(first.isSuccess, isTrue, reason: first.failureOrNull?.toString() ?? '');

    final old = (await goalRepo.getById('goal-1')).requireValue;
    final payloadBeforeUpdate = (jsonDecode(dbA.raw
            .select("SELECT payload FROM change_log WHERE entity_type = 'savings_goal'")
            .first['payload']! as String) as Map<String, Object?>)['before'];
    expect(payloadBeforeUpdate, isNotNull);

    clock.set(clock.now().add(const Duration(minutes: 5)));
    final upd = await goalRepo.update(old.copyWith(
      name: '换车(改)',
      updatedAt: clock.now(),
      revision: old.revision + 1,
      baseRevision: old.revision,
    ));
    expect(upd.isSuccess, isTrue, reason: upd.failureOrNull?.toString() ?? '');

    final updatePayload = (jsonDecode(dbA.raw.select(
              "SELECT payload FROM change_log WHERE entity_type = 'savings_goal' "
              'ORDER BY local_revision DESC LIMIT 1',
            ).first['payload']! as String)
        as Map<String, Object?>);
    final before = updatePayload['before']! as Map<String, Object?>;
    expect(before['name'], '换车', reason: '空 before = 无共同祖先 → 每次修改都出假冲突');

    final applied = await applierB.applyAll(
        recordsOfType(dbA, 'savings_goal'), writerDeviceId: kDeviceA);
    expect(applied.isSuccess, isTrue, reason: applied.failureOrNull?.toString() ?? '');
    expect(applied.requireValue.conflicts, 0);
    expect(
      dbB.raw.select('SELECT name FROM savings_goals WHERE id = ?', ['goal-1'])
          .first['name'],
      '换车(改)',
    );
    expect(dbB.raw.select('SELECT COUNT(*) AS c FROM sync_conflicts').first['c'], 0);
  });

  // ⑤ ── change_log GC ──
  test('⑤ 配置了 WebDAV 同步后不再按 30 天删日志', () async {
    final repo = ChangeLogRepository(dbA);
    changeLog.write(
      entityType: EntityType.account,
      entityId: 'acc-1',
      op: ChangeOp.insert,
      deviceId: kDeviceA,
      baseRevision: 0,
      before: const {},
      after: const {'id': 'acc-1'},
    );
    // 单机使用：没有消费方，按时间裁剪安全
    final pruned = await repo.gc(now: clock.now().add(const Duration(days: 60)));
    expect(pruned.isSuccess, isTrue);
    expect(dbA.raw.select('SELECT COUNT(*) AS c FROM change_log').first['c'], 0);

    // 开了同步：离线超过 30 天的设备还要靠这些行补齐，绝不能按时间删
    dbA.raw.execute(
        "INSERT INTO app_meta (key,value,updated_at) VALUES ('webdav.url','https://dav.example/x',0)");
    changeLog.write(
      entityType: EntityType.account,
      entityId: 'acc-2',
      op: ChangeOp.insert,
      deviceId: kDeviceA,
      baseRevision: 0,
      before: const {},
      after: const {'id': 'acc-2'},
    );
    await repo.gc(now: clock.now().add(const Duration(days: 60)));
    expect(dbA.raw.select('SELECT COUNT(*) AS c FROM change_log').first['c'], 1,
        reason: '删掉这段 = 对端永久缺一段账，且没有任何报错');
  });

  // ⑥ ── 编辑态残留 ──
  test('⑥ 编辑过一笔后「记一笔」不再改写旧账', () async {
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase.inMemory();
    addTearDown(db.close);
    final clock = FixedClock(DateTime(2026, 10, 20, 9).toUtc());
    final deps =
        buildDependencies(db: db, deviceId: kDeviceA, bookId: kBook, clock: clock);
    final container = ProviderContainer(
      overrides: [appDependenciesProvider.overrideWithValue(deps)],
    );
    addTearDown(container.dispose);

    final create = CreateEntryUseCase(
        repository: deps.ledgerRepository, clock: clock, idGen: deps.idGen);
    final first = await create(
      CreateEntryInput(
        amountExpression: '10', type: EntryType.expense,
        categoryId: 'cat-food', accountId: 'acc-cash',
        bookId: kBook, deviceId: kDeviceA,
      ),
      s: kDefaultAppStrings,
    );
    expect(first.isSuccess, isTrue, reason: first.failureOrNull?.toString() ?? '');
    final old = first.requireValue;

    final ctl = container.read(entryInputControllerProvider.notifier);
    ctl.loadForEdit(entry: old);
    expect(container.read(entryInputControllerProvider).isEditing, isTrue);

    // 用户没保存就退出编辑，再点「记一笔」
    ctl.startNewEntry();
    final fresh = container.read(entryInputControllerProvider);
    expect(fresh.isEditing, isFalse, reason: '编辑残留没清 → 按 OK 会走 update 分支');
    expect(fresh.editingId, isNull);

    // 输入 20 并保存 → 必须是**新增**一笔，而不是把 10 改成 20
    ctl.onDigit('2');
    ctl.onDigit('0');
    ctl.selectCategory('cat-food');
    final saved = await ctl.saveExplicit();
    expect(saved, isTrue, reason: '${container.read(entryInputControllerProvider).errorMessage}');

    final page = (await deps.ledgerRepository.listPage(limit: 10)).requireValue;
    expect(page.items.length, 2, reason: '旧账被覆盖 = 新账悄没声地丢了');
    expect((await deps.ledgerRepository.getById(old.id)).requireValue.amount.cents, 1000);
  });

  // ④ ── 翻页失败不再自动重试 ──
  group('④ 流水页翻页失败', () {
    late AppDatabase db;
    late AppDependencies deps;
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase.inMemory();
      clock = FixedClock(DateTime(2026, 10, 20, 9).toUtc());
      deps = buildDependencies(
        db: db, deviceId: kDeviceA, bookId: kBook, clock: clock);
      container = ProviderContainer(
        overrides: [appDependenciesProvider.overrideWithValue(deps)],
      );
      final create = CreateEntryUseCase(
        repository: deps.ledgerRepository, clock: clock, idGen: deps.idGen);
      // 51 笔 → 第一页 50 条后 hasMore = true，尾部的「更多」行会出现
      for (var i = 0; i < 51; i++) {
        final r = await create(
          CreateEntryInput(
            amountExpression: '1',
            type: EntryType.expense,
            categoryId: 'cat-food',
            accountId: 'acc-cash',
            occurredAt: clock.now().add(Duration(minutes: i)),
            bookId: kBook,
            deviceId: kDeviceA,
          ),
          s: kDefaultAppStrings,
        );
        expect(r.isSuccess, isTrue);
      }
    });

    tearDown(() {
      container.dispose();
      db.close();
    });

    test('失败后置 loadMoreFailed，再次调用不会重新进入加载', () async {
      final ctl = container.read(flowListControllerProvider.notifier);
      await ctl.loadInitial();
      var state = container.read(flowListControllerProvider);
      expect(state.hasMore, isTrue);

      // 让下一次查询必然失败（表没了 → DatabaseException → StorageFailure）
      db.raw.execute('DROP TABLE transactions');

      await ctl.loadMore();
      state = container.read(flowListControllerProvider);
      expect(state.loadMoreFailed, isTrue);
      expect(state.isLoading, isFalse);

      final snapshot = container.read(flowListControllerProvider);
      await ctl.loadMore();
      expect(identical(container.read(flowListControllerProvider), snapshot), isTrue,
          reason: '失败后仍自动重试 = 每帧一次 SQL 的死循环');

      // 用户可以手动重试（这里表仍然不存在，所以还是失败，但状态可重入）
      await ctl.retryLoadMore();
      expect(container.read(flowListControllerProvider).loadMoreFailed, isTrue);
    });
  });
}
