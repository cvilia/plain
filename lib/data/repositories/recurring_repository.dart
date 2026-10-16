/// Recurring rule repository + batch undo. See PRD F6.1.
library;

import 'package:plain/core/money/money.dart';
import 'package:plain/core/result/result.dart';
import 'package:plain/core/time/clock.dart';
import 'package:plain/data/db/database.dart';
import 'package:plain/data/db/row_x.dart';
import 'package:plain/data/db/run_write.dart';
import 'package:plain/data/sync/change_log_writer.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/entities/recurring_rule.dart';
import 'package:plain/domain/repositories/repositories.dart';

class RecurringRepositoryImpl implements RecurringRepository {
  RecurringRepositoryImpl({
    required AppDatabase db, required ChangeLogWriter changeLogWriter,
    required Clock clock,
  })  : _db = db, _changeLog = changeLogWriter, _clock = clock;

  final AppDatabase _db;
  final ChangeLogWriter _changeLog;
  final Clock _clock;

  @override
  Future<Result<List<RecurringRule>>> listByBook(String bookId) async {
    final rows = _db.raw.select(
      'SELECT * FROM recurring_rules WHERE book_id = ? AND deleted_at IS NULL ORDER BY next_run_at',
      [bookId]);
    return ok(rows.map(_fromRow).toList());
  }

  @override
  Future<Result<List<RecurringRule>>> listDue({required DateTime now}) async {
    final rows = _db.raw.select(
      'SELECT * FROM recurring_rules WHERE is_enabled = 1 AND deleted_at IS NULL AND next_run_at <= ? ORDER BY next_run_at',
      [now.millisecondsSinceEpoch]);
    return ok(rows.map(_fromRow).toList());
  }

  @override
  Future<Result<RecurringRule>> getById(String id) async {
    final rows = _db.raw.select('SELECT * FROM recurring_rules WHERE id = ?', [id]);
    if (rows.isEmpty) return err<RecurringRule>(const NotFoundFailure('recurring.not_found', 'nf'));
    return ok(_fromRow(rows.first));
  }

  /// 产出某批次账单的那条规则（撤销批次时要据此回滚目标进度）。
  ///
  /// 未删除的优先；同批次只可能由一条规则产出（`lastBatchId` 在生成/确认时写定），
  /// 因此取最近更新的一条即可。
  @override
  Future<Result<RecurringRule?>> findByLastBatchId(String batchId) async {
    final rows = _db.raw.select(
      'SELECT * FROM recurring_rules WHERE last_batch_id = ? '
      'ORDER BY deleted_at IS NULL DESC, updated_at DESC LIMIT 1',
      [batchId],
    );
    return ok(rows.isEmpty ? null : _fromRow(rows.first));
  }

  @override
  Future<Result<RecurringRule>> create(RecurringRule rule) async {
    if (rule.frequency == RecurringFrequency.unknown) {
      return err<RecurringRule>(const ValidationFailure('recurring.frequency_invalid', 'invalid'));
    }
    if (!rule.amount.withinProductLimit || rule.amount.isZero) {
      return err<RecurringRule>(const ValidationFailure('recurring.amount_invalid', 'invalid'));
    }
    return runWrite(
      _db,
      failCode: 'db.insert_failed',
      result: rule,
      body: () {
        _insert(rule);
        _changeLog.write(
          entityType: EntityType.recurringRule, entityId: rule.id, op: ChangeOp.insert,
          deviceId: rule.deviceId, baseRevision: 0,
          before: const {}, after: _payload(rule),
        );
      },
    );
  }

  @override
  Future<Result<RecurringRule>> update(RecurringRule rule) async {
    final old = _findById(rule.id);
    if (old == null) return err<RecurringRule>(const NotFoundFailure('recurring.not_found', 'nf'));
    return runWrite(
      _db,
      failCode: 'db.update_failed',
      result: rule,
      body: () {
        _update(rule);
        _changeLog.write(
          entityType: EntityType.recurringRule, entityId: rule.id, op: ChangeOp.update,
          deviceId: rule.deviceId, baseRevision: rule.baseRevision,
          before: _payload(old), after: _payload(rule),
        );
      },
    );
  }

  @override
  Future<Result<void>> softDelete(String id) async {
    final old = _findById(id);
    if (old == null) return err<void>(const NotFoundFailure('recurring.not_found', 'nf'));
    final now = _clock.now();
    final deleted = old.copyWith(
      deletedAt: now, updatedAt: now,
      isEnabled: false, revision: old.revision + 1, baseRevision: old.revision);
    return runWrite<void>(
      _db,
      failCode: 'db.delete_failed',
      result: null,
      body: () {
        _update(deleted);
        _changeLog.write(
          entityType: EntityType.recurringRule, entityId: id, op: ChangeOp.delete,
          deviceId: old.deviceId, baseRevision: old.revision,
          before: _payload(old), after: const {},
        );
      },
    );
  }

  RecurringRule? _findById(String id) {
    final rows = _db.raw.select('SELECT * FROM recurring_rules WHERE id = ?', [id]);
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  void _insert(RecurringRule r) {
    _db.raw.execute(
      'INSERT INTO recurring_rules (id,book_id,name,frequency,interval_n,anchor_day,weekday,skip_strategy,auto_confirm,'
      'end_type,end_at,end_count,generated_count,next_run_at,entry_type,amount_cents,category_id,account_id,to_account_id,'
      'note,last_batch_id,kind,goal_id,is_enabled,created_at,updated_at,deleted_at,revision,device_id,base_revision) '
      'VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
      _rowArgs(r));
  }

  void _update(RecurringRule r) {
    _db.raw.execute(
      'UPDATE recurring_rules SET name=?,frequency=?,interval_n=?,anchor_day=?,weekday=?,skip_strategy=?,auto_confirm=?,'
      'end_type=?,end_at=?,end_count=?,generated_count=?,next_run_at=?,entry_type=?,amount_cents=?,category_id=?,account_id=?,'
      'to_account_id=?,note=?,last_batch_id=?,kind=?,goal_id=?,is_enabled=?,updated_at=?,deleted_at=?,revision=?,base_revision=? WHERE id=?',
      [r.name, r.frequency.wire, r.intervalN, r.anchorDay, r.weekday, r.skipStrategy.wire,
        r.autoConfirm ? 1 : 0, r.endType.wire, r.endAt?.millisecondsSinceEpoch, r.endCount,
        r.generatedCount, r.nextRunAt.millisecondsSinceEpoch, r.entryType.wire, r.amount.cents,
        r.categoryId, r.accountId, r.toAccountId, r.note, r.lastBatchId, r.kind.wire, r.goalId,
        r.isEnabled ? 1 : 0,
        r.updatedAt.millisecondsSinceEpoch, r.deletedAt?.millisecondsSinceEpoch,
        r.revision, r.baseRevision, r.id]);
  }

  List<Object?> _rowArgs(RecurringRule r) => [
    r.id, r.bookId, r.name, r.frequency.wire, r.intervalN, r.anchorDay, r.weekday,
    r.skipStrategy.wire, r.autoConfirm ? 1 : 0, r.endType.wire,
    r.endAt?.millisecondsSinceEpoch, r.endCount, r.generatedCount,
    r.nextRunAt.millisecondsSinceEpoch, r.entryType.wire, r.amount.cents,
    r.categoryId, r.accountId, r.toAccountId, r.note, r.lastBatchId,
    r.kind.wire, r.goalId,
    r.isEnabled ? 1 : 0, r.createdAt.millisecondsSinceEpoch,
    r.updatedAt.millisecondsSinceEpoch, r.deletedAt?.millisecondsSinceEpoch,
    r.revision, r.deviceId, r.baseRevision,
  ];

  Map<String, Object?> _payload(RecurringRule r) => {
    'id': r.id, 'book_id': r.bookId, 'name': r.name, 'frequency': r.frequency.wire,
    'interval_n': r.intervalN, 'anchor_day': r.anchorDay, 'weekday': r.weekday,
    'skip_strategy': r.skipStrategy.wire, 'auto_confirm': r.autoConfirm,
    'end_type': r.endType.wire, 'end_at': r.endAt?.millisecondsSinceEpoch,
    'end_count': r.endCount, 'generated_count': r.generatedCount,
    'next_run_at': r.nextRunAt.millisecondsSinceEpoch, 'entry_type': r.entryType.wire,
    'amount_cents': r.amount.cents, 'category_id': r.categoryId,
    'account_id': r.accountId, 'to_account_id': r.toAccountId, 'note': r.note,
    'last_batch_id': r.lastBatchId, 'kind': r.kind.wire, 'goal_id': r.goalId,
    'is_enabled': r.isEnabled,
    'created_at': r.createdAt.millisecondsSinceEpoch,
    'updated_at': r.updatedAt.millisecondsSinceEpoch,
    'deleted_at': r.deletedAt?.millisecondsSinceEpoch,
    'revision': r.revision, 'device_id': r.deviceId, 'base_revision': r.baseRevision,
  };

  RecurringRule _fromRow(Map<String, Object?> row) => RecurringRule(
    id: row['id']! as String, bookId: row['book_id']! as String,
    name: row['name'] as String?,
    frequency: RecurringFrequency.fromWire(row['frequency'] as String?),
    intervalN: (row['interval_n'] as int?) ?? 1,
    anchorDay: row['anchor_day'] as int?, weekday: row['weekday'] as int?,
    skipStrategy: RecurringSkipStrategy.fromWire(row['skip_strategy'] as String?),
    autoConfirm: ((row['auto_confirm'] as int?) ?? 1) == 1,
    endType: RecurringEndType.fromWire(row['end_type'] as String?),
    endAt: row.nullableDateTime('end_at'),
    endCount: row['end_count'] as int?,
    generatedCount: (row['generated_count'] as int?) ?? 0,
    nextRunAt: row.dateTime('next_run_at'),
    entryType: EntryType.fromWire(row['entry_type'] as String?),
    amount: Money(row['amount_cents']! as int),
    categoryId: row['category_id'] as String?,
    accountId: row['account_id'] as String?,
    toAccountId: row['to_account_id'] as String?,
    note: row['note'] as String?,
    kind: RecurringKind.fromWire(row['kind'] as String?),
    goalId: row['goal_id'] as String?,
    lastBatchId: row['last_batch_id'] as String?,
    isEnabled: ((row['is_enabled'] as int?) ?? 1) == 1,
    createdAt: row.dateTime('created_at'),
    updatedAt: row.dateTime('updated_at'),
    deletedAt: row.nullableDateTime('deleted_at'),
    revision: row.intOr('revision', 1),
    deviceId: row['device_id']! as String,
    baseRevision: row.intOr('base_revision', 0));
}
