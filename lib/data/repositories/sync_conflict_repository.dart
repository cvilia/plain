/// STORY-8.1 冲突仓储（冲突中心的数据源）。
library;

import 'package:plain/core/result/result.dart';
import 'package:plain/data/db/database.dart';
import 'package:plain/data/db/row_x.dart';
import 'package:plain/domain/entities/sync_conflict.dart';

class SyncConflictRepositoryImpl {
  SyncConflictRepositoryImpl({required AppDatabase db}) : _db = db;

  final AppDatabase _db;

  Future<Result<List<SyncConflict>>> listOpen({String? bookId}) async {
    try {
      final rows = _db.raw.select(
        "SELECT * FROM sync_conflicts WHERE resolution = 'unresolved' "
        '${bookId == null ? '' : 'AND book_id = ? '}'
        'ORDER BY created_at DESC',
        [?bookId],
      );
      return ok([for (final r in rows) _fromRow(r)]);
    } on Exception catch (e) {
      return err(StorageFailure('db.query_failed', e.toString(), isRetryable: true));
    }
  }

  Future<Result<int>> countOpen({String? bookId}) async {
    try {
      final rows = _db.raw.select(
        "SELECT COUNT(*) AS c FROM sync_conflicts WHERE resolution = 'unresolved' "
        '${bookId == null ? '' : 'AND book_id = ? '}',
        [?bookId],
      );
      return ok((rows.first['c'] as int?) ?? 0);
    } on Exception catch (e) {
      return err(StorageFailure('db.query_failed', e.toString(), isRetryable: true));
    }
  }

  /// 同实体同字段同值对只留一条（重复拉取不应堆出重复冲突）。
  Future<Result<bool>> exists({
    required String entityType,
    required String entityId,
    required String field,
    required String? localValue,
    required String? remoteValue,
  }) async {
    try {
      final rows = _db.raw.select(
        "SELECT 1 AS x FROM sync_conflicts WHERE entity_type = ? AND entity_id = ? "
        "AND field = ? AND IFNULL(local_value,'') = IFNULL(?,'') "
        "AND IFNULL(remote_value,'') = IFNULL(?,'') AND resolution = 'unresolved'",
        [entityType, entityId, field, localValue, remoteValue],
      );
      return ok(rows.isNotEmpty);
    } on Exception catch (e) {
      return err(StorageFailure('db.query_failed', e.toString(), isRetryable: true));
    }
  }

  Future<Result<void>> insert(SyncConflict c) async {
    try {
      _db.raw.execute(
        'INSERT OR REPLACE INTO sync_conflicts (id,book_id,entity_type,entity_id,field,'
        'ancestor_value,local_value,remote_value,local_payload,remote_payload,'
        'local_changed_at,remote_changed_at,winner,resolution,resolved_at,created_at) '
        'VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
        [
          c.id, c.bookId, c.entityType, c.entityId, c.field,
          c.ancestorValue, c.localValue, c.remoteValue,
          c.localPayload, c.remotePayload,
          c.localChangedAt?.millisecondsSinceEpoch,
          c.remoteChangedAt?.millisecondsSinceEpoch,
          c.winner, c.resolution.wire, c.resolvedAt?.millisecondsSinceEpoch,
          c.createdAt.millisecondsSinceEpoch,
        ],
      );
      return ok(null);
    } on Exception catch (e) {
      return err(StorageFailure('db.insert_failed', e.toString(), isRetryable: true));
    }
  }

  Future<Result<void>> resolve(String id, ConflictResolution resolution, DateTime at) async {
    try {
      _db.raw.execute(
        'UPDATE sync_conflicts SET resolution = ?, resolved_at = ? WHERE id = ?',
        [resolution.wire, at.millisecondsSinceEpoch, id],
      );
      return ok(null);
    } on Exception catch (e) {
      return err(StorageFailure('db.update_failed', e.toString(), isRetryable: true));
    }
  }

  /// 该实体是否还有别的未裁决冲突（裁决一个字段后判断整体是否结清）。
  Future<Result<int>> countOpenForEntity(String entityType, String entityId) async {
    try {
      final rows = _db.raw.select(
        "SELECT COUNT(*) AS c FROM sync_conflicts WHERE entity_type = ? AND entity_id = ? "
        "AND resolution = 'unresolved'",
        [entityType, entityId],
      );
      return ok((rows.first['c'] as int?) ?? 0);
    } on Exception catch (e) {
      return err(StorageFailure('db.query_failed', e.toString(), isRetryable: true));
    }
  }

  SyncConflict _fromRow(Map<String, Object?> row) => SyncConflict(
        id: row['id']! as String,
        bookId: row['book_id']! as String,
        entityType: row['entity_type']! as String,
        entityId: row['entity_id']! as String,
        field: row['field']! as String,
        ancestorValue: row['ancestor_value'] as String?,
        localValue: row['local_value'] as String?,
        remoteValue: row['remote_value'] as String?,
        localPayload: (row['local_payload'] as String?) ?? '{}',
        remotePayload: (row['remote_payload'] as String?) ?? '{}',
        localChangedAt: row.nullableDateTime('local_changed_at'),
        remoteChangedAt: row.nullableDateTime('remote_changed_at'),
        winner: (row['winner'] as String?) ?? 'local',
        resolution: ConflictResolution.fromWire(row['resolution'] as String?),
        resolvedAt: row.nullableDateTime('resolved_at'),
        createdAt: row.dateTime('created_at'),
      );
}
