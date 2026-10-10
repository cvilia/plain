/// 自动化规则仓储（STORY-6.1）。
library;

import 'dart:convert';

import 'package:plain/core/money/money.dart';
import 'package:plain/core/result/result.dart';
import 'package:plain/data/db/database.dart';
import 'package:plain/data/db/row_x.dart';
import 'package:plain/data/sync/change_log_writer.dart';
import 'package:plain/domain/entities/automation_rule.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/entities/ledger_entry.dart';
import 'package:plain/domain/repositories/repositories.dart';
import 'package:plain/domain/services/rule_engine.dart';

LedgerEntry _entryFromRow(Map<String, Object?> row) => LedgerEntry(
      id: row['id']! as String,
      bookId: row['book_id']! as String,
      type: EntryType.fromWire(row['type'] as String?),
      amount: Money(row['amount_cents']! as int),
      currency: (row['currency'] as String?) ?? 'CNY',
      categoryId: row['category_id'] as String?,
      accountId: row['account_id'] as String?,
      toAccountId: row['to_account_id'] as String?,
      occurredAt: row.dateTime('occurred_at'),
      note: row['note'] as String?,
      source: EntrySource.fromWire(row['source'] as String?),
      batchId: row['batch_id'] as String?,
      createdAt: row.dateTime('created_at'),
      updatedAt: row.dateTime('updated_at'),
      deletedAt: row.nullableDateTime('deleted_at'),
      revision: row.intOr('revision', 1),
      deviceId: row['device_id']! as String,
      baseRevision: row.intOr('base_revision', 0),
    );

class AutomationRuleRepositoryImpl implements AutomationRuleRepository {
  AutomationRuleRepositoryImpl({
    required AppDatabase db,
    required ChangeLogWriter changeLogWriter,
  })  : _db = db,
        _changeLog = changeLogWriter;

  final AppDatabase _db;
  final ChangeLogWriter _changeLog;

  @override
  Future<Result<List<AutomationRule>>> listEnabled({String? bookId, RuleStage? stage}) async {
    try {
      final where = StringBuffer('deleted_at IS NULL AND is_enabled = 1');
      final args = <Object?>[];
      if (bookId != null) {
        where.write(' AND book_id = ?');
        args.add(bookId);
      }
      if (stage != null) {
        where.write(' AND stage = ?');
        args.add(stage.wire);
      }
      final rows = _db.raw.select(
        'SELECT * FROM rules WHERE $where ORDER BY priority ASC, created_at ASC',
        args,
      );
      return ok([for (final r in rows) _fromRow(r)]);
    } on Exception catch (e) {
      return err(StorageFailure('db.query_failed', e.toString(), isRetryable: true));
    }
  }

  @override
  Future<Result<List<AutomationRule>>> listAll({String? bookId}) async {
    try {
      final where = StringBuffer('deleted_at IS NULL');
      final args = <Object?>[];
      if (bookId != null) {
        where.write(' AND book_id = ?');
        args.add(bookId);
      }
      final rows = _db.raw.select(
        'SELECT * FROM rules WHERE $where ORDER BY priority ASC, created_at ASC',
        args,
      );
      return ok([for (final r in rows) _fromRow(r)]);
    } on Exception catch (e) {
      return err(StorageFailure('db.query_failed', e.toString(), isRetryable: true));
    }
  }

  @override
  Future<Result<AutomationRule>> getById(String id) async {
    try {
      final rows = _db.raw.select('SELECT * FROM rules WHERE id = ?', [id]);
      if (rows.isEmpty) {
        return err<AutomationRule>(const NotFoundFailure('rule.not_found', 'nf'));
      }
      return ok(_fromRow(rows.first));
    } on Exception catch (e) {
      return err(StorageFailure('db.query_failed', e.toString(), isRetryable: true));
    }
  }

  @override
  Future<Result<AutomationRule>> create(AutomationRule rule) async {
    try {
      _db.transaction(() {
        _insert(rule);
        _changeLog.write(
          entityType: EntityType.automationRule,
          entityId: rule.id,
          op: ChangeOp.insert,
          deviceId: rule.deviceId,
          baseRevision: 0,
          before: const {},
          after: _payload(rule),
        );
      });
      return ok(rule);
    } on Exception catch (e) {
      return err(StorageFailure('db.insert_failed', e.toString(), isRetryable: true));
    }
  }

  @override
  Future<Result<AutomationRule>> update(AutomationRule rule) async {
    try {
      final existing = await getById(rule.id);
      final old = existing.successOrNull;
      if (old == null) {
        return err<AutomationRule>(const NotFoundFailure('rule.not_found', 'nf'));
      }
      _db.transaction(() {
        _updateRow(rule);
        _changeLog.write(
          entityType: EntityType.automationRule,
          entityId: rule.id,
          op: ChangeOp.update,
          deviceId: rule.deviceId,
          baseRevision: rule.baseRevision,
          before: _payload(old),
          after: _payload(rule),
        );
      });
      return ok(rule);
    } on Exception catch (e) {
      return err(StorageFailure('db.update_failed', e.toString(), isRetryable: true));
    }
  }

  @override
  Future<Result<void>> softDelete(String id) async {
    try {
      final existing = await getById(id);
      final f = existing.failureOrNull;
      if (f != null) return err<void>(f);
      final old = existing.successOrNull!;
      final now = DateTime.now().toUtc();
      final deleted = old.copyWith(
        deletedAt: now,
        updatedAt: now,
        revision: old.revision + 1,
        baseRevision: old.revision,
      );
      _db.transaction(() {
        _updateRow(deleted);
        _changeLog.write(
          entityType: EntityType.automationRule,
          entityId: id,
          op: ChangeOp.delete,
          deviceId: old.deviceId,
          baseRevision: old.revision,
          before: _payload(old),
          after: const {},
        );
      });
      return ok(null);
    } on Exception catch (e) {
      return err(StorageFailure('db.delete_failed', e.toString(), isRetryable: true));
    }
  }

  @override
  Future<Result<int>> countMatches({
    required String bookId,
    required List<RuleCondition> conditions,
  }) async {
    try {
      // 用 RuleEngine 在内存中过滤最近账单（变更预览）
      final rows = _db.raw.select(
        'SELECT * FROM transactions WHERE book_id = ? AND deleted_at IS NULL '
        'ORDER BY occurred_at DESC LIMIT 500',
        [bookId],
      );
      const engine = RuleEngine();
      final probe = AutomationRule(
        id: 'preview',
        bookId: bookId,
        stage: RuleStage.post,
        priority: 0,
        scope: RuleScope.all,
        conditions: conditions,
        actions: const [],
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
        deviceId: 'preview',
      );
      var n = 0;
      for (final r in rows) {
        final e = _entryFromRow(r);
        if (engine.matches(e, probe)) n++;
      }
      return ok(n);
    } on Exception catch (e) {
      return err(StorageFailure('db.query_failed', e.toString(), isRetryable: true));
    }
  }

  void _insert(AutomationRule r) {
    _db.raw.execute(
      'INSERT INTO rules (id,book_id,name,stage,priority,scope,conditions,actions,is_enabled,'
      'created_at,updated_at,deleted_at,revision,device_id,base_revision) '
      'VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
      [
        r.id, r.bookId, r.name, r.stage.wire, r.priority, r.scope.wire,
        RuleEngine.encodeConditions(r.conditions),
        RuleEngine.encodeActions(r.actions),
        r.isEnabled ? 1 : 0,
        r.createdAt.millisecondsSinceEpoch,
        r.updatedAt.millisecondsSinceEpoch,
        r.deletedAt?.millisecondsSinceEpoch,
        r.revision, r.deviceId, r.baseRevision,
      ],
    );
  }

  void _updateRow(AutomationRule r) {
    _db.raw.execute(
      'UPDATE rules SET name=?,stage=?,priority=?,scope=?,conditions=?,actions=?,is_enabled=?,'
      'updated_at=?,deleted_at=?,revision=?,base_revision=? WHERE id=?',
      [
        r.name, r.stage.wire, r.priority, r.scope.wire,
        RuleEngine.encodeConditions(r.conditions),
        RuleEngine.encodeActions(r.actions),
        r.isEnabled ? 1 : 0,
        r.updatedAt.millisecondsSinceEpoch,
        r.deletedAt?.millisecondsSinceEpoch,
        r.revision, r.baseRevision, r.id,
      ],
    );
  }

  AutomationRule _fromRow(Map<String, Object?> row) {
    return AutomationRule(
      id: row['id']! as String,
      bookId: row['book_id']! as String,
      name: row['name'] as String?,
      stage: RuleStage.fromWire(row['stage'] as String?),
      priority: row.intOr('priority', 0),
      scope: RuleScope.fromWire(row['scope'] as String?),
      conditions: RuleEngine.parseConditions((row['conditions'] as String?) ?? '[]'),
      actions: RuleEngine.parseActions((row['actions'] as String?) ?? '[]'),
      isEnabled: ((row['is_enabled'] as int?) ?? 1) == 1,
      createdAt: row.dateTime('created_at'),
      updatedAt: row.dateTime('updated_at'),
      deletedAt: row.nullableDateTime('deleted_at'),
      revision: row.intOr('revision', 1),
      deviceId: row['device_id']! as String,
      baseRevision: row.intOr('base_revision', 0),
    );
  }

  Map<String, Object?> _payload(AutomationRule r) => {
        'id': r.id,
        'book_id': r.bookId,
        'name': r.name,
        'stage': r.stage.wire,
        'priority': r.priority,
        'scope': r.scope.wire,
        'conditions': jsonEncode([for (final c in r.conditions) c.toJson()]),
        'actions': jsonEncode([for (final a in r.actions) a.toJson()]),
        'is_enabled': r.isEnabled,
      };
}
