/// STORY-1.6 商户学习仓储。
library;

import 'package:plain/core/id/uuid_v7.dart';
import 'package:plain/core/result/result.dart';
import 'package:plain/core/time/clock.dart';
import 'package:plain/data/db/database.dart';
import 'package:plain/data/db/row_x.dart';
import 'package:plain/data/sync/change_log_writer.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/repositories/repositories.dart';
import 'package:plain/domain/services/merchant_learner.dart';

class MerchantRuleRepositoryImpl implements MerchantRuleRepository {
  MerchantRuleRepositoryImpl({
    required AppDatabase db,
    required ChangeLogWriter changeLogWriter,
    required UuidV7 idGen,
    Clock? clock,
  })  : _db = db,
        _changeLog = changeLogWriter,
        _idGen = idGen,
        _clock = clock ?? SystemClock();

  final AppDatabase _db;
  final ChangeLogWriter _changeLog;
  final UuidV7 _idGen;
  final Clock _clock;

  @override
  Future<Result<List<MerchantRule>>> listByBook(String bookId) async {
    try {
      final rows = _db.raw.select(
        'SELECT * FROM merchant_rules WHERE book_id = ? AND deleted_at IS NULL '
        'ORDER BY hit_count DESC, updated_at DESC',
        [bookId],
      );
      return ok([for (final r in rows) _fromRow(r)]);
    } on Exception catch (e) {
      return err(StorageFailure('db.query_failed', e.toString(), isRetryable: true));
    }
  }

  @override
  Future<Result<MerchantRule>> learn({
    required String bookId,
    required String merchant,
    required String categoryId,
    required String deviceId,
  }) async {
    final key = merchant.trim();
    if (key.isEmpty) {
      return err<MerchantRule>(
          const ValidationFailure('merchant.empty', 'merchant required'));
    }
    if (categoryId.isEmpty) {
      return err<MerchantRule>(
          const ValidationFailure('merchant.category_required', 'category required'));
    }
    try {
      final now = _clock.now();
      final existing = _findByMerchant(bookId, key);
      final next = MerchantLearner.learn(
        id: existing?.id ?? _idGen.generate(at: now),
        bookId: bookId,
        merchant: existing?.merchant ?? key,
        categoryId: categoryId,
        now: now,
        deviceId: deviceId,
        existing: existing,
      );
      _db.transaction(() {
        if (existing == null) {
          _insert(next);
        } else {
          _updateRow(next);
        }
        _changeLog.write(
          entityType: EntityType.merchantRule,
          entityId: next.id,
          op: existing == null ? ChangeOp.insert : ChangeOp.update,
          deviceId: deviceId,
          baseRevision: existing?.revision ?? 0,
          before: existing == null ? const {} : _payload(existing),
          after: _payload(next),
        );
      });
      return ok(next);
    } on Exception catch (e) {
      return err(StorageFailure('db.insert_failed', e.toString(), isRetryable: true));
    }
  }

  @override
  Future<Result<void>> forget(String id) async {
    try {
      final rows = _db.raw.select('SELECT * FROM merchant_rules WHERE id = ?', [id]);
      if (rows.isEmpty) {
        return err<void>(const NotFoundFailure('merchant.not_found', 'nf'));
      }
      final old = _fromRow(rows.first);
      final now = _clock.now();
      final deleted = old.copyWith(
        deletedAt: now,
        updatedAt: now,
        revision: old.revision + 1,
        baseRevision: old.revision,
      );
      _db.transaction(() {
        _updateRow(deleted);
        _changeLog.write(
          entityType: EntityType.merchantRule,
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

  MerchantRule? _findByMerchant(String bookId, String merchant) {
    final rows = _db.raw.select(
      'SELECT * FROM merchant_rules WHERE book_id = ? AND merchant = ? AND deleted_at IS NULL',
      [bookId, merchant],
    );
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  void _insert(MerchantRule r) {
    _db.raw.execute(
      'INSERT INTO merchant_rules (id,book_id,merchant,category_id,hit_count,'
      'last_corrected_at,created_at,updated_at,deleted_at,revision,device_id,base_revision) '
      'VALUES (?,?,?,?,?,?,?,?,?,?,?,?)',
      [
        r.id, r.bookId, r.merchant, r.categoryId, r.hitCount,
        r.lastCorrectedAt?.millisecondsSinceEpoch,
        r.createdAt.millisecondsSinceEpoch, r.updatedAt.millisecondsSinceEpoch,
        r.deletedAt?.millisecondsSinceEpoch, r.revision, r.deviceId, r.baseRevision,
      ],
    );
  }

  void _updateRow(MerchantRule r) {
    _db.raw.execute(
      'UPDATE merchant_rules SET category_id=?,hit_count=?,last_corrected_at=?,'
      'updated_at=?,deleted_at=?,revision=?,base_revision=? WHERE id=?',
      [
        r.categoryId, r.hitCount, r.lastCorrectedAt?.millisecondsSinceEpoch,
        r.updatedAt.millisecondsSinceEpoch, r.deletedAt?.millisecondsSinceEpoch,
        r.revision, r.baseRevision, r.id,
      ],
    );
  }

  MerchantRule _fromRow(Map<String, Object?> row) => MerchantRule(
        id: row['id']! as String,
        bookId: row['book_id']! as String,
        merchant: row['merchant']! as String,
        categoryId: row['category_id'] as String?,
        hitCount: row.intOr('hit_count', 1),
        lastCorrectedAt: row.nullableDateTime('last_corrected_at'),
        createdAt: row.dateTime('created_at'),
        updatedAt: row.dateTime('updated_at'),
        deletedAt: row.nullableDateTime('deleted_at'),
        revision: row.intOr('revision', 1),
        deviceId: row['device_id']! as String,
        baseRevision: row.intOr('base_revision', 0),
      );

  Map<String, Object?> _payload(MerchantRule r) => {
        'id': r.id,
        'book_id': r.bookId,
        'merchant': r.merchant,
        'category_id': r.categoryId,
        'hit_count': r.hitCount,
        // 修正时间也要同步：漏列会让对端「最近修正」永远为空（audit 2026-10-15）
        'last_corrected_at': r.lastCorrectedAt?.millisecondsSinceEpoch,
      };
}
