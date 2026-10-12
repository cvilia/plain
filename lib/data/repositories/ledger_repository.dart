/// Ledger repository implementation. See 04-6.1, 8.1, 08-8.
library;

import 'package:plain/data/db/row_x.dart';
import 'package:plain/core/logging/app_log.dart';
import 'package:plain/core/money/money.dart';
import 'package:plain/core/result/result.dart';
import 'package:plain/core/time/clock.dart';
import 'package:plain/data/db/database.dart';
import 'package:plain/data/sync/change_log_writer.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/entities/ledger_entry.dart';
import 'package:plain/domain/repositories/repositories.dart';

class LedgerRepositoryImpl implements LedgerRepository {
  LedgerRepositoryImpl({
    required AppDatabase db, required ChangeLogWriter changeLogWriter,
    required Clock clock, AppLog? log,
  })  : _db = db, _changeLog = changeLogWriter, _clock = clock, _log = log;

  final AppDatabase _db;
  final ChangeLogWriter _changeLog;
  final Clock _clock;
  final AppLog? _log;

  @override
  Future<Result<LedgerEntry>> create(LedgerEntry entry) async {
    try {
      _db.transaction(() {
        _insertEntry(entry);
        _upsertDailyStats(entry, isIncrement: true);
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
        _changeLog.write(
          entityType: EntityType.transaction, entityId: id, op: ChangeOp.delete,
          deviceId: old.deviceId, baseRevision: old.revision,
          before: _payload(old), after: const {},
        );
      });
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
        _changeLog.write(
          entityType: EntityType.transaction, entityId: id, op: ChangeOp.update,
          deviceId: old.deviceId, baseRevision: old.revision,
          before: _payload(old), after: _payload(restored),
        );
      });
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
          before: entryPayload(
            id: old.id, bookId: old.bookId, type: old.type.wire,
            amountCents: old.amount.cents, currency: old.currency,
            categoryId: old.categoryId, accountId: old.accountId,
            toAccountId: old.toAccountId,
            occurredAtMs: old.occurredAt.millisecondsSinceEpoch,
            note: old.note, source: old.source.wire, batchId: old.batchId,
            createdAtMs: old.createdAt.millisecondsSinceEpoch,
            updatedAtMs: old.updatedAt.millisecondsSinceEpoch,
            deletedAtMs: old.deletedAt?.millisecondsSinceEpoch,
            revision: old.revision, deviceId: old.deviceId,
            baseRevision: old.baseRevision,
          ),
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
            before: entryPayload(
              id: old.id, bookId: old.bookId, type: old.type.wire,
              amountCents: old.amount.cents, currency: old.currency,
              categoryId: old.categoryId, accountId: old.accountId,
              toAccountId: old.toAccountId,
              occurredAtMs: old.occurredAt.millisecondsSinceEpoch,
              note: old.note, source: old.source.wire, batchId: old.batchId,
              createdAtMs: old.createdAt.millisecondsSinceEpoch,
              updatedAtMs: old.updatedAt.millisecondsSinceEpoch,
              deletedAtMs: old.deletedAt?.millisecondsSinceEpoch,
              revision: old.revision, deviceId: old.deviceId,
              baseRevision: old.baseRevision,
            ),
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
        'SELECT COUNT(*) AS c FROM transactions '
        "WHERE deleted_at IS NULL AND type IN ('expense','income') AND source <> 'reconcile'",
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
          'SELECT id, book_id, type, amount_cents, category_id, account_id, occurred_at, source '
          "FROM transactions WHERE deleted_at IS NULL AND type IN ('expense','income') "
          "AND source <> 'reconcile'",
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
      'INSERT INTO transactions (id,book_id,type,amount_cents,currency,category_id,account_id,to_account_id,occurred_at,note,source,batch_id,split_role,parent_id,reimburse_status,reconciled_at,created_at,updated_at,deleted_at,revision,device_id,base_revision) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
      [e.id, e.bookId, e.type.wire, e.amount.cents, e.currency, e.categoryId, e.accountId, e.toAccountId, e.occurredAt.millisecondsSinceEpoch, e.note, e.source.wire, e.batchId, e.splitRole.wire, e.parentId, e.reimburseStatus.wire, e.reconciledAt?.millisecondsSinceEpoch, e.createdAt.millisecondsSinceEpoch, e.updatedAt.millisecondsSinceEpoch, e.deletedAt?.millisecondsSinceEpoch, e.revision, e.deviceId, e.baseRevision]);
  }

  void _updateEntry(LedgerEntry e) {
    _db.raw.execute(
      'UPDATE transactions SET type=?,amount_cents=?,category_id=?,account_id=?,to_account_id=?,occurred_at=?,note=?,split_role=?,parent_id=?,reimburse_status=?,reconciled_at=?,updated_at=?,deleted_at=?,revision=?,base_revision=? WHERE id=?',
      [e.type.wire, e.amount.cents, e.categoryId, e.accountId, e.toAccountId, e.occurredAt.millisecondsSinceEpoch, e.note, e.splitRole.wire, e.parentId, e.reimburseStatus.wire, e.reconciledAt?.millisecondsSinceEpoch, e.updatedAt.millisecondsSinceEpoch, e.deletedAt?.millisecondsSinceEpoch, e.revision, e.baseRevision, e.id]);
  }

  LedgerEntry? _findById(String id) {
    final rows = _db.raw.select('SELECT * FROM transactions WHERE id = ?', [id]);
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  void _upsertDailyStats(LedgerEntry entry, {required bool isIncrement}) {
    // STORY-6.2：分类/预算统计只记「子笔 + 普通」；父笔不进 daily_stats（避免双算）。
    // 收支合计由 Σ 子笔 = 父笔金额，与 PRD AC4 一致。
    if (!entry.countsInCategoryStats) return;
    final dayKey = _clock.localDayKey(entry.occurredAt);
    final sign = isIncrement ? 1 : -1;
    final exp = entry.type == EntryType.expense ? entry.amount.cents * sign : 0;
    final inc = entry.type == EntryType.income ? entry.amount.cents * sign : 0;
    final nowMs = _clock.now().millisecondsSinceEpoch;
    _db.raw.execute(
      'INSERT INTO daily_stats (book_id,day_key,category_id,account_id,expense_cents,income_cents,tx_count,updated_at) VALUES (?,?,?,?,?,?,?,?) '
      'ON CONFLICT(book_id,day_key,category_id,account_id) DO UPDATE SET expense_cents=expense_cents+?,income_cents=income_cents+?,tx_count=tx_count+?,updated_at=?',
      [entry.bookId, dayKey, entry.categoryId ?? '', entry.accountId ?? '', exp, inc, sign, nowMs, exp, inc, sign, nowMs]);
  }

  Map<String, Object?> _payload(LedgerEntry e) => entryPayload(
    id: e.id, bookId: e.bookId, type: e.type.wire, amountCents: e.amount.cents,
    currency: e.currency, categoryId: e.categoryId, accountId: e.accountId,
    toAccountId: e.toAccountId, occurredAtMs: e.occurredAt.millisecondsSinceEpoch,
    note: e.note, source: e.source.wire, batchId: e.batchId,
    createdAtMs: e.createdAt.millisecondsSinceEpoch,
    updatedAtMs: e.updatedAt.millisecondsSinceEpoch, deletedAtMs: e.deletedAt?.millisecondsSinceEpoch,
    revision: e.revision, deviceId: e.deviceId, baseRevision: e.baseRevision);

  LedgerEntry _fromRow(Map<String, Object?> row) => LedgerEntry(
    id: row['id']! as String, bookId: row['book_id']! as String,
    type: EntryType.fromWire(row['type'] as String?),
    amount: Money(row['amount_cents']! as int), currency: (row['currency'] as String?) ?? 'CNY',
    categoryId: row['category_id'] as String?, accountId: row['account_id'] as String?,
    toAccountId: row['to_account_id'] as String?,
    occurredAt: row.dateTime('occurred_at'),
    note: row['note'] as String?, source: EntrySource.fromWire(row['source'] as String?),
    batchId: row['batch_id'] as String?,
    splitRole: SplitRole.fromWire(row['split_role'] as String?),
    parentId: row['parent_id'] as String?,
    reimburseStatus: ReimburseStatus.fromWire(row['reimburse_status'] as String?),
    reconciledAt: row.nullableDateTime('reconciled_at'),
    createdAt: row.dateTime('created_at'),
    updatedAt: row.dateTime('updated_at'),
    deletedAt: row.nullableDateTime('deleted_at'),
    revision: row.intOr('revision', 1), deviceId: row['device_id']! as String,
    baseRevision: row.intOr('base_revision', 0));
}
