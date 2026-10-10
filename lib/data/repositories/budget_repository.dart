/// Budget repository implementation. See PRD F5.1/F5.2.
library;

import 'package:plain/core/money/money.dart';
import 'package:plain/core/result/result.dart';
import 'package:plain/core/time/clock.dart';
import 'package:plain/data/db/database.dart';
import 'package:plain/data/db/row_x.dart';
import 'package:plain/data/db/run_write.dart';
import 'package:plain/data/sync/change_log_writer.dart';
import 'package:plain/domain/entities/budget.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/repositories/repositories.dart';

class BudgetRepositoryImpl implements BudgetRepository {
  BudgetRepositoryImpl({
    required AppDatabase db, required ChangeLogWriter changeLogWriter,
    required Clock clock,
  })  : _db = db, _changeLog = changeLogWriter, _clock = clock;

  final AppDatabase _db;
  final ChangeLogWriter _changeLog;
  final Clock _clock;

  @override
  Future<Result<Budget>> getTotal(String bookId) async {
    final rows = _db.raw.select(
      'SELECT * FROM budgets WHERE book_id = ? AND scope = ? AND deleted_at IS NULL LIMIT 1',
      [bookId, BudgetScope.total.wire]);
    if (rows.isEmpty) return err<Budget>(const NotFoundFailure('budget.not_found', 'nf'));
    return ok(_fromRow(rows.first));
  }

  @override
  Future<Result<List<Budget>>> listByBook(String bookId) async {
    final rows = _db.raw.select(
      'SELECT * FROM budgets WHERE book_id = ? AND deleted_at IS NULL '
      "ORDER BY CASE scope WHEN 'total' THEN 0 ELSE 1 END, category_id",
      [bookId]);
    return ok(rows.map(_fromRow).toList());
  }

  @override
  Future<Result<Budget>> create(Budget budget) async {
    if (budget.isTotal) {
      final existing = await getTotal(budget.bookId);
      if (existing.isSuccess) {
        return err<Budget>(const ConflictFailure('budget.total_exists', 'exists'));
      }
    } else if (budget.categoryId == null) {
      return err<Budget>(const ValidationFailure('budget.category_required', 'req'));
    }
    return runWrite(
      _db,
      failCode: 'db.insert_failed',
      result: budget,
      body: () {
        _insert(budget);
        _changeLog.write(
          entityType: EntityType.budget, entityId: budget.id, op: ChangeOp.insert,
          deviceId: budget.deviceId, baseRevision: 0,
          before: const {}, after: _payload(budget),
        );
      },
    );
  }

  @override
  Future<Result<Budget>> update(Budget budget) async {
    final old = _findById(budget.id);
    if (old == null) return err<Budget>(const NotFoundFailure('budget.not_found', 'nf'));
    return runWrite(
      _db,
      failCode: 'db.update_failed',
      result: budget,
      body: () {
        _update(budget);
        _changeLog.write(
          entityType: EntityType.budget, entityId: budget.id, op: ChangeOp.update,
          deviceId: budget.deviceId, baseRevision: budget.baseRevision,
          before: _payload(old), after: _payload(budget),
        );
      },
    );
  }

  @override
  Future<Result<void>> softDelete(String id) async {
    final old = _findById(id);
    if (old == null) return err<void>(const NotFoundFailure('budget.not_found', 'nf'));
    final now = _clock.now();
    final deleted = old.copyWith(
      deletedAt: now, updatedAt: now,
      revision: old.revision + 1, baseRevision: old.revision,
    );
    return runWrite<void>(
      _db,
      failCode: 'db.delete_failed',
      result: null,
      body: () {
        _update(deleted);
        _changeLog.write(
          entityType: EntityType.budget, entityId: id, op: ChangeOp.delete,
          deviceId: old.deviceId, baseRevision: old.revision,
          before: _payload(old), after: const {},
        );
      },
    );
  }

  @override
  Future<Result<int>> spentCents({
    required String bookId, String? categoryId,
    required int fromMs, required int toMs,
  }) async {
    try {
      // STORY-6.2：预算只计「子笔 + 普通」，父笔不计（避免双算）。
      const notParent = "AND split_role <> 'parent'";
      if (categoryId == null) {
        final rows = _db.raw.select(
          'SELECT COALESCE(SUM(amount_cents),0) AS s FROM transactions '
          "WHERE book_id = ? AND type = ? AND source <> 'reconcile' AND deleted_at IS NULL $notParent AND occurred_at >= ? AND occurred_at < ?",
          [bookId, EntryType.expense.wire, fromMs, toMs]);
        return ok((rows.first['s'] as int?) ?? 0);
      }
      // Include the category and its descendants (one level in V1).
      final children = _db.raw.select(
        'SELECT id FROM categories WHERE (id = ? OR parent_id = ?) AND deleted_at IS NULL',
        [categoryId, categoryId]);
      final ids = children.map((r) => r['id']! as String).toList();
      if (ids.isEmpty) return ok(0);
      final placeholders = List.filled(ids.length, '?').join(',');
      final rows = _db.raw.select(
        'SELECT COALESCE(SUM(amount_cents),0) AS s FROM transactions '
        "WHERE book_id = ? AND type = ? AND source <> 'reconcile' AND deleted_at IS NULL $notParent AND category_id IN ($placeholders) "
        'AND occurred_at >= ? AND occurred_at < ?',
        [bookId, EntryType.expense.wire, ...ids, fromMs, toMs]);
      return ok((rows.first['s'] as int?) ?? 0);
    } on Exception catch (e) {
      return err(StorageFailure('db.query_failed', e.toString(), isRetryable: true));
    }
  }

  Budget? _findById(String id) {
    final rows = _db.raw.select('SELECT * FROM budgets WHERE id = ?', [id]);
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  void _insert(Budget b) {
    _db.raw.execute(
      'INSERT INTO budgets (id,book_id,scope,category_id,period_type,start_day,amount_cents,rollover,is_enabled,created_at,updated_at,deleted_at,revision,device_id,base_revision) '
      'VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
      [b.id, b.bookId, b.scope.wire, b.categoryId, b.periodType.wire, b.startDay,
        b.amount.cents, b.rollover ? 1 : 0, b.isEnabled ? 1 : 0,
        b.createdAt.millisecondsSinceEpoch, b.updatedAt.millisecondsSinceEpoch,
        b.deletedAt?.millisecondsSinceEpoch, b.revision, b.deviceId, b.baseRevision]);
  }

  void _update(Budget b) {
    _db.raw.execute(
      'UPDATE budgets SET category_id=?,start_day=?,amount_cents=?,rollover=?,is_enabled=?,updated_at=?,deleted_at=?,revision=?,base_revision=? WHERE id=?',
      [b.categoryId, b.startDay, b.amount.cents, b.rollover ? 1 : 0, b.isEnabled ? 1 : 0,
        b.updatedAt.millisecondsSinceEpoch, b.deletedAt?.millisecondsSinceEpoch,
        b.revision, b.baseRevision, b.id]);
  }

  Map<String, Object?> _payload(Budget b) => {
    'id': b.id, 'book_id': b.bookId, 'scope': b.scope.wire,
    'category_id': b.categoryId, 'period_type': b.periodType.wire,
    'start_day': b.startDay, 'amount_cents': b.amount.cents,
    'rollover': b.rollover, 'is_enabled': b.isEnabled,
    'created_at': b.createdAt.millisecondsSinceEpoch,
    'updated_at': b.updatedAt.millisecondsSinceEpoch,
    'deleted_at': b.deletedAt?.millisecondsSinceEpoch,
    'revision': b.revision, 'device_id': b.deviceId, 'base_revision': b.baseRevision,
  };

  Budget _fromRow(Map<String, Object?> row) => Budget(
    id: row['id']! as String, bookId: row['book_id']! as String,
    scope: BudgetScope.fromWire(row['scope'] as String?),
    categoryId: row['category_id'] as String?,
    periodType: BudgetPeriod.fromWire(row['period_type'] as String?),
    startDay: (row['start_day'] as int?) ?? 1,
    amount: Money(row['amount_cents']! as int),
    rollover: ((row['rollover'] as int?) ?? 0) == 1,
    isEnabled: ((row['is_enabled'] as int?) ?? 1) == 1,
    createdAt: row.dateTime('created_at'),
    updatedAt: row.dateTime('updated_at'),
    deletedAt: row.nullableDateTime('deleted_at'),
    revision: row.intOr('revision', 1),
    deviceId: row['device_id']! as String,
    baseRevision: row.intOr('base_revision', 0));
}
