/// 储蓄目标仓储（STORY-7.1）。
library;

import 'package:plain/core/result/result.dart';
import 'package:plain/data/db/database.dart';
import 'package:plain/data/db/row_x.dart';
import 'package:plain/data/sync/change_log_writer.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/entities/savings_goal.dart';
import 'package:plain/domain/repositories/repositories.dart';

class SavingsGoalRepositoryImpl implements SavingsGoalRepository {
  SavingsGoalRepositoryImpl({
    required AppDatabase db,
    required ChangeLogWriter changeLogWriter,
    required DateTime Function() now,
  })  : _db = db,
        _changeLog = changeLogWriter,
        _now = now;

  final AppDatabase _db;
  final ChangeLogWriter _changeLog;
  final DateTime Function() _now;

  @override
  Future<Result<List<SavingsGoal>>> listByBook(String bookId) async {
    try {
      final rows = _db.raw.select(
        'SELECT * FROM savings_goals WHERE book_id = ? AND deleted_at IS NULL '
        'ORDER BY created_at ASC',
        [bookId],
      );
      return ok([for (final r in rows) _fromRow(r)]);
    } on Exception catch (e) {
      return err(StorageFailure('db.query_failed', e.toString(), isRetryable: true));
    }
  }

  @override
  Future<Result<SavingsGoal>> getById(String id) async {
    try {
      final rows = _db.raw.select('SELECT * FROM savings_goals WHERE id = ?', [id]);
      if (rows.isEmpty) {
        return err<SavingsGoal>(const NotFoundFailure('goal.not_found', 'nf'));
      }
      return ok(_fromRow(rows.first));
    } on Exception catch (e) {
      return err(StorageFailure('db.query_failed', e.toString(), isRetryable: true));
    }
  }

  @override
  Future<Result<SavingsGoal>> create(SavingsGoal goal) async {
    try {
      _db.transaction(() {
        _insert(goal);
        _changeLog.write(
          entityType: EntityType.savingsGoal,
          entityId: goal.id,
          op: ChangeOp.insert,
          deviceId: goal.deviceId,
          baseRevision: 0,
          before: const {},
          after: _payload(goal),
        );
      });
      return ok(goal);
    } on Exception catch (e) {
      return err(StorageFailure('db.insert_failed', e.toString(), isRetryable: true));
    }
  }

  @override
  Future<Result<SavingsGoal>> update(SavingsGoal goal) async {
    try {
      _db.transaction(() {
        _updateRow(goal);
        _changeLog.write(
          entityType: EntityType.savingsGoal,
          entityId: goal.id,
          op: ChangeOp.update,
          deviceId: goal.deviceId,
          baseRevision: goal.baseRevision,
          before: const {},
          after: _payload(goal),
        );
      });
      return ok(goal);
    } on Exception catch (e) {
      return err(StorageFailure('db.update_failed', e.toString(), isRetryable: true));
    }
  }

  @override
  Future<Result<void>> softDelete(String id) async {
    try {
      final g = await getById(id);
      final f = g.failureOrNull;
      if (f != null) return err<void>(f);
      final old = g.successOrNull!;
      final now = _now();
      final deleted = old.copyWith(
        deletedAt: now,
        updatedAt: now,
        revision: old.revision + 1,
        baseRevision: old.revision,
      );
      _db.transaction(() => _updateRow(deleted));
      return ok(null);
    } on Exception catch (e) {
      return err(StorageFailure('db.delete_failed', e.toString(), isRetryable: true));
    }
  }

  @override
  Future<Result<SavingsGoal>> deposit({
    required String goalId,
    required int amountCents,
  }) async {
    if (amountCents <= 0) {
      return err<SavingsGoal>(const ValidationFailure('goal.amount_invalid', 'zero'));
    }
    final g = await getById(goalId);
    final f = g.failureOrNull;
    if (f != null) return err(f);
    final old = g.successOrNull!;
    final now = _now();
    final updated = old.copyWith(
      savedCents: old.savedCents + amountCents,
      updatedAt: now,
      revision: old.revision + 1,
      baseRevision: old.revision,
    );
    return update(updated);
  }

  void _insert(SavingsGoal g) {
    _db.raw.execute(
      'INSERT INTO savings_goals (id,book_id,name,goal_type,target_cents,saved_cents,remaining_terms,goal_account_id,due_at,account_id,auto_transfer,'
      'created_at,updated_at,deleted_at,revision,device_id,base_revision) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
      [
        g.id, g.bookId, g.name, g.goalType.wire, g.targetCents, g.savedCents,
        g.remainingTerms, g.goalAccountId, g.dueAt?.millisecondsSinceEpoch,
        g.accountId, g.autoTransfer ? 1 : 0,
        g.createdAt.millisecondsSinceEpoch, g.updatedAt.millisecondsSinceEpoch,
        g.deletedAt?.millisecondsSinceEpoch, g.revision, g.deviceId, g.baseRevision,
      ],
    );
  }

  void _updateRow(SavingsGoal g) {
    _db.raw.execute(
      'UPDATE savings_goals SET name=?,goal_type=?,target_cents=?,saved_cents=?,remaining_terms=?,goal_account_id=?,due_at=?,account_id=?,auto_transfer=?,'
      'updated_at=?,deleted_at=?,revision=?,base_revision=? WHERE id=?',
      [
        g.name, g.goalType.wire, g.targetCents, g.savedCents, g.remainingTerms,
        g.goalAccountId, g.dueAt?.millisecondsSinceEpoch, g.accountId,
        g.autoTransfer ? 1 : 0,
        g.updatedAt.millisecondsSinceEpoch, g.deletedAt?.millisecondsSinceEpoch,
        g.revision, g.baseRevision, g.id,
      ],
    );
  }

  SavingsGoal _fromRow(Map<String, Object?> row) => SavingsGoal(
        id: row['id']! as String,
        bookId: row['book_id']! as String,
        name: row['name']! as String,
        goalType: GoalType.fromWire(row['goal_type'] as String?),
        targetCents: row.intOr('target_cents', 0),
        savedCents: row.intOr('saved_cents', 0),
        remainingTerms: row['remaining_terms'] as int?,
        goalAccountId: row['goal_account_id'] as String?,
        dueAt: row.nullableDateTime('due_at'),
        accountId: row['account_id'] as String?,
        autoTransfer: ((row['auto_transfer'] as int?) ?? 0) == 1,
        createdAt: row.dateTime('created_at'),
        updatedAt: row.dateTime('updated_at'),
        deletedAt: row.nullableDateTime('deleted_at'),
        revision: row.intOr('revision', 1),
        deviceId: row['device_id']! as String,
        baseRevision: row.intOr('base_revision', 0),
      );

  Map<String, Object?> _payload(SavingsGoal g) => {
        'id': g.id,
        'book_id': g.bookId,
        'name': g.name,
        'goal_type': g.goalType.wire,
        'target_cents': g.targetCents,
        'saved_cents': g.savedCents,
        'remaining_terms': g.remainingTerms,
        'goal_account_id': g.goalAccountId,
        'due_at': g.dueAt?.millisecondsSinceEpoch,
        'account_id': g.accountId,
        'auto_transfer': g.autoTransfer,
      };
}
