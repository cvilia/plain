/// Read-only view of the change log (操作日志).
library;

import 'package:plain/core/result/result.dart';
import 'package:plain/data/db/database.dart';
import 'package:plain/data/db/row_x.dart';

class ChangeLogItem {
  const ChangeLogItem({
    required this.localRevision,
    required this.entityType,
    required this.entityId,
    required this.op,
    required this.deviceId,
    required this.changedAt,
    required this.payload,
  });

  final int localRevision;
  final String entityType;
  final String entityId;
  final String op;
  final String deviceId;
  final DateTime changedAt;
  final String payload;
}

class ChangeLogRepository {
  ChangeLogRepository(this._db);
  final AppDatabase _db;

  /// Newest-first page of local mutations (for the 操作日志 screen).
  Future<Result<List<ChangeLogItem>>> listRecent({int limit = 200}) async {
    try {
      final rows = _db.raw.select(
        'SELECT local_revision, entity_type, entity_id, op, device_id, changed_at, payload '
        'FROM change_log ORDER BY local_revision DESC LIMIT ?',
        [limit],
      );
      return ok([
        for (final row in rows)
          ChangeLogItem(
            localRevision: row['local_revision']! as int,
            entityType: row['entity_type']! as String,
            entityId: row['entity_id']! as String,
            op: row['op']! as String,
            deviceId: row['device_id']! as String,
            changedAt: row.dateTime('changed_at'),
            payload: (row['payload'] as String?) ?? '',
          ),
      ]);
    } on Exception catch (e) {
      return err(StorageFailure('db.query_failed', e.toString(), isRetryable: true));
    }
  }
}
