/// Ledger repository implementation. See 04-6.1, 8.1, 08-8.
library;

import 'package:plain/data/db/row_x.dart';
import 'package:plain/core/constants/app_constants.dart';
import 'package:plain/core/logging/app_log.dart';
import 'package:plain/core/money/money.dart';
import 'package:plain/core/result/result.dart';
import 'package:plain/core/time/clock.dart';
import 'package:plain/data/db/column_writer.dart';
import 'package:plain/data/db/stats_maintenance.dart';
import 'package:plain/data/db/database.dart';
import 'package:plain/data/sync/change_log_writer.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/entities/ledger_entry.dart';
import 'package:plain/domain/entities/member.dart';
import 'package:plain/domain/repositories/repositories.dart';

class LedgerRepositoryImpl implements LedgerRepository {
  LedgerRepositoryImpl({
    required AppDatabase db, required ChangeLogWriter changeLogWriter,
    required Clock clock, AppLog? log, AttachmentRepository? attachments,
  })  : _db = db, _changeLog = changeLogWriter, _clock = clock, _log = log,
        _attachments = attachments;

  final AppDatabase _db;
  final ChangeLogWriter _changeLog;
  final Clock _clock;
  final AppLog? _log;

  /// STORY-1.5：账单进/出回收站时同步附件孤儿标记。
  /// 跨仓储写在事务之后（两者都在同一连接上，失败窗口只有一次函数调用，
  /// 而孤儿附件有 30 天保留期 + 启动巡检兜底）。
  final AttachmentRepository? _attachments;

  @override
  Future<Result<LedgerEntry>> create(LedgerEntry entry) async {
    try {
      _db.transaction(() {
        _insertEntry(entry);
        _upsertDailyStats(entry, isIncrement: true);
        _maintainCreditDebt(entry, isIncrement: true);
        _changeLog.write(
          entityType: EntityType.transaction, entityId: entry.id, op: ChangeOp.insert,
          deviceId: entry.deviceId, baseRevision: 0,
          before: const {}, after: _payload(entry),
        );
      });
      _log?.entrySaved(entryType: entry.type.wire, source: entry.source.wire);
      return ok(entry);
    } on Object catch (e) {
      return err(StorageFailure('db.insert_failed', e.toString(), isRetryable: true));
    }
  }

  @override
  Future<Result<LedgerEntry>> update(LedgerEntry entry) async {
    try {
      final old = _findById(entry.id);
      if (old == null) return err<LedgerEntry>(const NotFoundFailure('entry.not_found', 'nf'));
      _db.transaction(() {
        _updateEntry(entry);
        _upsertDailyStats(old, isIncrement: false);
        _upsertDailyStats(entry, isIncrement: true);
        _maintainCreditDebt(old, isIncrement: false);
        _maintainCreditDebt(entry, isIncrement: true);
        _changeLog.write(
          entityType: EntityType.transaction, entityId: entry.id, op: ChangeOp.update,
          deviceId: entry.deviceId, baseRevision: entry.baseRevision,
          before: _payload(old), after: _payload(entry),
        );
      });
      return ok(entry);
    } on Object catch (e) {
      return err(StorageFailure('db.update_failed', e.toString(), isRetryable: true));
    }
  }

  @override
  Future<Result<void>> softDelete(String id) async {
    try {
      final old = _findById(id);
      if (old == null) return err<void>(const NotFoundFailure('entry.not_found', 'nf'));
      final now = _clock.now();
      final deleted = old.copyWith(deletedAt: now, updatedAt: now, revision: old.revision + 1, baseRevision: old.revision);
      _db.transaction(() {
        _updateEntry(deleted);
        _upsertDailyStats(old, isIncrement: false);
        _maintainCreditDebt(old, isIncrement: false);
        _changeLog.write(
          entityType: EntityType.transaction, entityId: id, op: ChangeOp.delete,
          deviceId: old.deviceId, baseRevision: old.revision,
          before: _payload(old), after: const {},
        );
      });
      // STORY-1.5：账单进回收站 → 附件标记孤儿（30 天内随恢复复原）
      await _attachments?.markOrphanedByEntry(id, now);
      return ok(null);
    } on Object catch (e) {
      return err(StorageFailure('db.delete_failed', e.toString(), isRetryable: true));
    }
  }

  @override
  Future<Result<LedgerEntry>> getById(String id) async {
    final row = _findById(id);
    if (row == null) return err<LedgerEntry>(const NotFoundFailure('entry.not_found', 'nf'));
    return ok(row);
  }

  @override
  Future<Result<EntryPage>> listPage({EntryFilter? filter, EntryCursor? cursor, int limit = 50}) async {
    try {
      final where = StringBuffer('deleted_at IS NULL');
      final args = <Object?>[];
      if (filter?.bookId != null) { where.write(' AND book_id = ?'); args.add(filter!.bookId); }
      if (filter?.categoryId != null) {
        // 含子分类：自身 OR parent_id = 该分类
        where.write(' AND (category_id = ? OR category_id IN (SELECT id FROM categories WHERE parent_id = ?))');
        args..add(filter!.categoryId)..add(filter.categoryId);
      }
      if (filter?.accountId != null) {
        where.write(' AND (account_id = ? OR to_account_id = ?)');
        args..add(filter!.accountId)..add(filter.accountId);
      }
      if (filter?.type != null) { where.write(' AND type = ?'); args.add(filter!.type); }
      // STORY-8.2：按归属成员筛选
      if (filter?.memberId != null) { where.write(' AND member_id = ?'); args.add(filter!.memberId); }
      if (filter?.fromMs != null) { where.write(' AND occurred_at >= ?'); args.add(filter!.fromMs); }
      if (filter?.toMs != null) { where.write(' AND occurred_at <= ?'); args.add(filter!.toMs); }
      if (filter?.minAmountCents != null) { where.write(' AND amount_cents >= ?'); args.add(filter!.minAmountCents); }
      if (filter?.maxAmountCents != null) { where.write(' AND amount_cents <= ?'); args.add(filter!.maxAmountCents); }
      if (filter?.keyword != null && filter!.keyword!.isNotEmpty) {
        // 匹配备注 / 账单 id / 分类名
        where.write(' AND (note LIKE ? OR id = ? OR category_id IN (SELECT id FROM categories WHERE name LIKE ?))');
        args..add('%${filter.keyword}%')..add(filter.keyword)..add('%${filter.keyword}%');
      }
      if (cursor != null) {
        where.write(' AND (occurred_at < ? OR (occurred_at = ? AND id < ?))');
        args..add(cursor.occurredAtMs)..add(cursor.occurredAtMs)..add(cursor.id);
      }
      args.add(limit);
      final rows = _db.raw.select(
        'SELECT * FROM transactions WHERE $where ORDER BY occurred_at DESC, id DESC LIMIT ?', args);
      final items = rows.map(_fromRow).toList();
      final hasMore = items.length == limit;
      final nextCursor = hasMore
          ? EntryCursor(occurredAtMs: items.last.occurredAt.millisecondsSinceEpoch, id: items.last.id)
          : null;
      return ok(EntryPage(items: items, nextCursor: nextCursor, hasMore: hasMore));
    } on Object catch (e) {
      return err(StorageFailure('db.query_failed', e.toString(), isRetryable: true));
    }
  }

  @override
  Future<Result<MonthSummary>> monthSummary({required String bookId, required String dayFrom, required String dayTo}) async {
    try {
      final rows = _db.raw.select(
        'SELECT category_id, SUM(expense_cents) AS exp, SUM(income_cents) AS inc, SUM(tx_count) AS cnt '
        'FROM daily_stats WHERE book_id = ? AND day_key >= ? AND day_key <= ? GROUP BY category_id',
        [bookId, dayFrom, dayTo]);
      var expense = 0; var income = 0; var count = 0;
      final byCat = <String, CategoryAgg>{};
      for (final r in rows) {
        final exp = (r['exp'] as int?) ?? 0;
        final inc = (r['inc'] as int?) ?? 0;
        final cnt = (r['cnt'] as int?) ?? 0;
        expense += exp; income += inc; count += cnt;
        byCat[r['category_id']! as String] = CategoryAgg(expenseCents: exp, incomeCents: inc, txCount: cnt);
      }
      return ok(MonthSummary(expenseCents: expense, incomeCents: income, txCount: count, byCategory: byCat));
    } on Object catch (e) {
      return err(StorageFailure('db.query_failed', e.toString(), isRetryable: true));
    }
  }

  @override
  Future<Result<List<MemberAgg>>> memberSummary({
    required String bookId,
    required int fromMs,
    required int toMs,
  }) async {
    try {
      // 与 daily_stats 同一套口径（_statsRowPredicate），
      // 时间边界用本地日 → UTC 毫秒，与 monthSummary 的本地 day_key 对齐。
      final rows = _db.raw.select(
        "SELECT IFNULL(member_id,'') AS mid, COUNT(*) AS cnt, "
        "COALESCE(SUM(CASE WHEN type='expense' THEN amount_cents ELSE 0 END),0) AS exp, "
        "COALESCE(SUM(CASE WHEN type='income' THEN amount_cents ELSE 0 END),0) AS inc "
        'FROM transactions '
        'WHERE book_id = ? AND occurred_at >= ? AND occurred_at < ? AND $_statsRowPredicate '
        'GROUP BY mid',
        [bookId, fromMs, toMs],
      );
      return ok([
        for (final r in rows)
          MemberAgg(
            memberId: (r['mid'] as String?) ?? '',
            txCount: (r['cnt'] as int?) ?? 0,
            expenseCents: (r['exp'] as int?) ?? 0,
            incomeCents: (r['inc'] as int?) ?? 0,
          ),
      ]);
    } on Object catch (e) {
      return err(StorageFailure('db.query_failed', e.toString(), isRetryable: true));
    }
  }

  @override
  Future<Result<void>> applySyncedEntry({
    required String id,
    required bool softDelete,
    required DateTime changedAt,
    Map<String, Object?> columns = const {},
  }) async {
    try {
      final previous = _findById(id);
      _db.transaction(() {
        if (softDelete) {
          ColumnWriter.softDeleteRow(_db, 'transactions', id, changedAt);
        } else {
          ColumnWriter.upsert(_db, 'transactions', columns);
        }
        final merged = _findById(id);
        // 统计与信用卡欠款都要跟着走：先撤旧的，再加新的
        if (previous != null) {
          _upsertDailyStats(previous, isIncrement: false);
          _maintainCreditDebt(previous, isIncrement: false);
        }
        if (!softDelete && merged != null) {
          _upsertDailyStats(merged, isIncrement: true);
          _maintainCreditDebt(merged, isIncrement: true);
        }
      });
      return ok(null);
    } on Object catch (e) {
      return err(StorageFailure('db.sync_apply_failed', e.toString(), isRetryable: true));
    }
  }

  @override
  Future<Result<int>> maxExpenseCents({required String bookId, required int fromMs, required int toMs}) async {
    try {
      final rows = _db.raw.select(
        'SELECT COALESCE(MAX(amount_cents), 0) AS m FROM transactions '
        "WHERE book_id = ? AND occurred_at >= ? AND occurred_at < ? AND type = 'expense' "
        'AND $_statsRowPredicate',
        [bookId, fromMs, toMs]);
      return ok((rows.first['m'] as int?) ?? 0);
    } on Object catch (e) {
      return err(StorageFailure('db.query_failed', e.toString(), isRetryable: true));
    }
  }

  @override
  Future<Result<List<LedgerEntry>>> listDeleted({String? bookId, int limit = 100}) async {
    try {
      final where = StringBuffer('deleted_at IS NOT NULL');
      final args = <Object?>[];
      if (bookId != null) { where.write(' AND book_id = ?'); args.add(bookId); }
      args.add(limit);
      final rows = _db.raw.select(
        'SELECT * FROM transactions WHERE $where ORDER BY deleted_at DESC, id DESC LIMIT ?', args);
      return ok(rows.map(_fromRow).toList());
    } on Object catch (e) {
      return err(StorageFailure('db.query_failed', e.toString(), isRetryable: true));
    }
  }

  @override
  Future<Result<LedgerEntry>> restore(String id) async {
    try {
      final old = _findById(id);
      if (old == null) return err<LedgerEntry>(const NotFoundFailure('entry.not_found', 'nf'));
      if (old.deletedAt == null) return err<LedgerEntry>(const ConflictFailure('entry.not_deleted', 'alive'));
      final now = _clock.now();
      final restored = old.copyWith(
        clearDeletedAt: true, updatedAt: now,
        revision: old.revision + 1, baseRevision: old.revision,
      );
      _db.transaction(() {
        _updateEntry(restored);
        _upsertDailyStats(restored, isIncrement: true);
        _maintainCreditDebt(restored, isIncrement: true);
        _changeLog.write(
          entityType: EntityType.transaction, entityId: id, op: ChangeOp.update,
          deviceId: old.deviceId, baseRevision: old.revision,
          before: _payload(old), after: _payload(restored),
        );
      });
      // STORY-1.5 AC2：账单恢复 → 附件孤儿标记复原
      await _attachments?.restoreByEntry(id);
      return ok(restored);
    } on Object catch (e) {
      return err(StorageFailure('db.restore_failed', e.toString(), isRetryable: true));
    }
  }

  @override
  Future<Result<void>> hardDelete(String id) async {
    try {
      final old = _findById(id);
      if (old == null) return err<void>(const NotFoundFailure('entry.not_found', 'nf'));
      if (old.deletedAt == null) return err<void>(const ConflictFailure('entry.not_deleted', 'alive'));
      _db.transaction(() {
        _db.raw.execute('DELETE FROM transactions WHERE id = ?', [id]);
        // Physical delete must still be visible to sync peers.
        _changeLog.write(
          entityType: EntityType.transaction,
          entityId: id,
          op: ChangeOp.delete,
          deviceId: old.deviceId,
          baseRevision: old.revision,
          before: _payload(old),
          after: const {},
        );
      });
      return ok(null);
    } on Object catch (e) {
      return err(StorageFailure('db.hard_delete_failed', e.toString(), isRetryable: true));
    }
  }

  @override
  Future<Result<int>> purgeExpired({required DateTime before}) async {
    try {
      final beforeMs = before.millisecondsSinceEpoch;
      final rows = _db.raw.select(
        'SELECT COUNT(*) AS c FROM transactions WHERE deleted_at IS NOT NULL AND deleted_at < ?', [beforeMs]);
      final count = (rows.first['c'] as int?) ?? 0;
      if (count == 0) return ok(0);
      _db.transaction(() {
        // Capture rows before delete so each gets a change_log entry.
        final doomed = _db.raw.select(
          'SELECT * FROM transactions WHERE deleted_at IS NOT NULL AND deleted_at < ?',
          [beforeMs],
        );
        _db.raw.execute(
          'DELETE FROM transactions WHERE deleted_at IS NOT NULL AND deleted_at < ?', [beforeMs]);
        for (final row in doomed) {
          final old = _fromRow(row);
          _changeLog.write(
            entityType: EntityType.transaction,
            entityId: old.id,
            op: ChangeOp.delete,
            deviceId: old.deviceId,
            baseRevision: old.revision,
            before: _payload(old),
            after: const {},
          );
        }
      });
      return ok(count);
    } on Object catch (e) {
      return err(StorageFailure('db.purge_failed', e.toString(), isRetryable: true));
    }
  }

  @override
  Future<Result<Set<String>>> fingerprintsInRange({required int fromMs, required int toMs}) async {
    try {
      final rows = _db.raw.select(
        'SELECT occurred_at, amount_cents, note FROM transactions '
        'WHERE deleted_at IS NULL AND occurred_at >= ? AND occurred_at <= ?',
        [fromMs, toMs]);
      final result = <String>{};
      for (final r in rows) {
        final at = r.dateTime('occurred_at');
        final cents = (r['amount_cents']! as int).abs();
        final note = r['note'] as String?;
        final dayKey = Clock.dayKeyOf(at);
        result.add('$dayKey|$cents|${note ?? ''}');
      }
      return ok(result);
    } on Object catch (e) {
      return err(StorageFailure('db.query_failed', e.toString(), isRetryable: true));
    }
  }

  @override
  Future<Result<bool>> verifyDailyStats() async {
    try {
      final tx = _db.raw.select(
        'SELECT COUNT(*) AS c FROM transactions WHERE $_statsRowPredicate',
      );
      final stats = _db.raw.select(
        'SELECT COALESCE(SUM(tx_count),0) AS c FROM daily_stats',
      );
      final a = (tx.first['c'] as int?) ?? 0;
      final b = (stats.first['c'] as int?) ?? 0;
      return ok(a == b);
    } on Object catch (e) {
      return err(StorageFailure('db.query_failed', e.toString(), isRetryable: true));
    }
  }

  @override
  Future<Result<void>> rebuildDailyStats() async {
    try {
      _db.transaction(() {
        _db.raw.execute('DELETE FROM daily_stats');
        final rows = _db.raw.select(
          'SELECT id, book_id, type, amount_cents, category_id, account_id, occurred_at, source, split_role '
          'FROM transactions WHERE $_statsRowPredicate',
        );
        for (final r in rows) {
          final entry = LedgerEntry(
            id: r['id']! as String,
            bookId: r['book_id']! as String,
            type: EntryType.fromWire(r['type'] as String?),
            amount: Money(r['amount_cents']! as int),
            currency: 'CNY',
            categoryId: r['category_id'] as String?,
            accountId: r['account_id'] as String?,
            toAccountId: null,
            occurredAt: r.dateTime('occurred_at'),
            note: null,
            source: EntrySource.fromWire(r['source'] as String?),
            batchId: null,
            splitRole: SplitRole.fromWire(r['split_role'] as String?),
            createdAt: r.dateTime('occurred_at'),
            updatedAt: r.dateTime('occurred_at'),
            deletedAt: null,
            revision: 1,
            deviceId: 'rebuild',
            baseRevision: 0,
          );
          _upsertDailyStats(entry, isIncrement: true);
        }
        // 08-§8：重建完成后写入校验位，供下次冷启动巡检
        final nowMs = _clock.now().millisecondsSinceEpoch;
        final countRow = _db.raw.select(
            'SELECT COALESCE(SUM(tx_count),0) AS c FROM daily_stats');
        final checksum = (countRow.first['c'] as int?) ?? 0;
        _db.raw.execute(
          'INSERT INTO app_meta (key,value,updated_at) VALUES (?,?,?) '
          'ON CONFLICT(key) DO UPDATE SET value=?,updated_at=?',
          ['stats.built_at', '$nowMs', nowMs, '$nowMs', nowMs],
        );
        _db.raw.execute(
          'INSERT INTO app_meta (key,value,updated_at) VALUES (?,?,?) '
          'ON CONFLICT(key) DO UPDATE SET value=?,updated_at=?',
          ['stats.checksum', '$checksum', nowMs, '$checksum', nowMs],
        );
      });
      return ok(null);
    } on Object catch (e) {
      return err(StorageFailure('db.rebuild_failed', e.toString(), isRetryable: true));
    }
  }

  void _insertEntry(LedgerEntry e) {
    _db.raw.execute(
      'INSERT INTO transactions (id,book_id,type,amount_cents,currency,category_id,account_id,to_account_id,occurred_at,note,source,batch_id,split_role,parent_id,reimburse_status,exclude_from_stats,original_amount_cents,exchange_rate_micro,reconciled_at,member_id,created_at,updated_at,deleted_at,revision,device_id,base_revision) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
      [e.id, e.bookId, e.type.wire, e.amount.cents, e.currency, e.categoryId, e.accountId, e.toAccountId, e.occurredAt.millisecondsSinceEpoch, e.note, e.source.wire, e.batchId, e.splitRole.wire, e.parentId, e.reimburseStatus.wire, e.excludeFromStats ? 1 : 0, e.originalAmountCents, e.exchangeRate == null ? null : CurrencyRules.rateToMicro(e.exchangeRate!), e.reconciledAt?.millisecondsSinceEpoch, e.memberId, e.createdAt.millisecondsSinceEpoch, e.updatedAt.millisecondsSinceEpoch, e.deletedAt?.millisecondsSinceEpoch, e.revision, e.deviceId, e.baseRevision]);
  }

  void _updateEntry(LedgerEntry e) {
    _db.raw.execute(
      'UPDATE transactions SET type=?,amount_cents=?,category_id=?,account_id=?,to_account_id=?,occurred_at=?,note=?,split_role=?,parent_id=?,reimburse_status=?,exclude_from_stats=?,original_amount_cents=?,exchange_rate_micro=?,reconciled_at=?,member_id=?,updated_at=?,deleted_at=?,revision=?,base_revision=? WHERE id=?',
      [e.type.wire, e.amount.cents, e.categoryId, e.accountId, e.toAccountId, e.occurredAt.millisecondsSinceEpoch, e.note, e.splitRole.wire, e.parentId, e.reimburseStatus.wire, e.excludeFromStats ? 1 : 0, e.originalAmountCents, e.exchangeRate == null ? null : CurrencyRules.rateToMicro(e.exchangeRate!), e.reconciledAt?.millisecondsSinceEpoch, e.memberId, e.updatedAt.millisecondsSinceEpoch, e.deletedAt?.millisecondsSinceEpoch, e.revision, e.baseRevision, e.id]);
  }

  LedgerEntry? _findById(String id) {
    final rows = _db.raw.select('SELECT * FROM transactions WHERE id = ?', [id]);
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  /// G-2.1 / STORY-2.2：信用卡欠款余额是**存储值**，由账单入账累加维护。
  ///
  /// 欠款与账户余额互为负值，所以一笔账单对某信用卡账户的欠款影响 =
  /// −(该笔对该账户的余额贡献)。只对 `type = 'credit'` 的账户生效；其余账户的
  /// 余额仍是派生量，不落列（G-2.1 适用边界）。
  ///
  /// 两种情况必须跳过：
  /// - **拆分子笔**：金额已在父笔计入一次（与 `affectsBalance` 同源）。
  /// - **`source = 'reconcile'`**：对账调整凭证只是可追溯凭证，欠款余额已由
  ///   `CreditReconcileService` 直接写定；这里再累加一次会双算（STORY-2.2 AC7）。
  void _maintainCreditDebt(LedgerEntry entry, {required bool isIncrement}) {
    if (entry.source == EntrySource.reconcile || !entry.affectsBalance) return;

    final deltas = <String, int>{};
    void add(String? accountId, int balanceDeltaCents) {
      if (accountId == null) return;
      deltas[accountId] = (deltas[accountId] ?? 0) + balanceDeltaCents;
    }

    switch (entry.type) {
      case EntryType.expense:
        add(entry.accountId, -entry.amount.cents);
      case EntryType.income:
        add(entry.accountId, entry.amount.cents);
      case EntryType.transfer:
        add(entry.accountId, -entry.amount.cents);
        add(entry.toAccountId, entry.amount.cents);
      // STORY-1.7：借出/借入与转出/转入同向，信用卡账户同样按余额贡献取反
      case EntryType.borrowOut:
        add(entry.accountId, -entry.amount.cents);
      case EntryType.borrowIn:
        add(entry.accountId, entry.amount.cents);
      case EntryType.repayCredit:
      case EntryType.unknown:
        return;
    }

    // 增量时欠款 += −余额贡献；回滚时反向累加。
    final sign = isIncrement ? 1 : -1;
    for (final d in deltas.entries) {
      _db.raw.execute(
        'UPDATE accounts SET credit_debt_cents = credit_debt_cents + ? '
        "WHERE id = ? AND type = 'credit'",
        [-sign * d.value, d.key],
      );
    }
  }

  @override
  Future<Result<int>> softDeleteBatch({required String batchId, required DateTime at}) async {
    try {
      final rows = _db.raw.select(
        'SELECT * FROM transactions WHERE batch_id = ? AND deleted_at IS NULL',
        [batchId],
      );
      if (rows.isEmpty) return ok(0);
      final old = rows.map(_fromRow).toList();
      _db.transaction(() {
        for (final e in old) {
          final deleted = e.copyWith(
            deletedAt: at,
            updatedAt: at,
            revision: e.revision + 1,
            baseRevision: e.revision,
          );
          _updateEntry(deleted);
          // 与单笔删除同口径：统计与信用卡欠款都要回滚
          _upsertDailyStats(e, isIncrement: false);
          _maintainCreditDebt(e, isIncrement: false);
          _changeLog.write(
            entityType: EntityType.transaction,
            entityId: e.id,
            op: ChangeOp.delete,
            deviceId: e.deviceId,
            baseRevision: e.revision,
            before: _payload(e),
            after: const {},
            changedAt: at,
          );
        }
      });
      // STORY-1.5：批次删除（周期撤销）同样要把附件标记为孤儿
      for (final e in old) {
        await _attachments?.markOrphanedByEntry(e.id, at);
      }
      return ok(old.length);
    } on Object catch (e) {
      return err(StorageFailure('db.undo_failed', e.toString(), isRetryable: true));
    }
  }

  /// `daily_stats` 行的唯一口径（与 [LedgerEntry.countsInCategoryStats] 一一对应），
  /// 实现已抽到 [kStatsRowPredicate] 供分类仓储共用。
  static const String _statsRowPredicate = kStatsRowPredicate;

  void _upsertDailyStats(LedgerEntry entry, {required bool isIncrement}) {
    upsertDailyStatsRow(
      _db,
      entry: entry,
      isIncrement: isIncrement,
      dayKey: statsDayKeyOf(_clock, entry.occurredAt),
      nowMs: _clock.now().millisecondsSinceEpoch,
    );
  }

  /// 实体 → 同步 payload。与分类仓储共用同一份实现（避免旁路写出部分列 payload）。
  Map<String, Object?> _payload(LedgerEntry e) => ledgerEntryPayloadOf(e);

  /// 行 → 实体。实现已抽到 [ledgerEntryFromRow]（分类仓储改派账单时也要读同一行，
  /// 两处各写一份转换迟早会漂）。
  LedgerEntry _fromRow(Map<String, Object?> row) => ledgerEntryFromRow(row);
}
