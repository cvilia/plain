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

  /// 06-C3 / 08-§12：change_log GC（30 天 / 5 万行上限）。
  /// V1.0 无同步消费方，裁剪安全；V2.0 增量同步上线后须先确认
  /// 所有已知设备位点早于被删行（08-§7.4 S6 耦合）。
  Future<Result<int>> gc({
    required DateTime now,
    int maxRows = 50000,
    Duration maxAge = const Duration(days: 30),
  }) async {
    try {
      var deleted = 0;
      _db.transaction(() {
        final cutoff = now.toUtc().millisecondsSinceEpoch - maxAge.inMilliseconds;
        final before = _db.raw.select('SELECT COUNT(*) AS c FROM change_log');
        final countBefore = (before.first['c'] as int?) ?? 0;

        _db.raw.execute('DELETE FROM change_log WHERE changed_at < ?', [cutoff]);

        final mid = _db.raw.select('SELECT COUNT(*) AS c FROM change_log');
        final countMid = (mid.first['c'] as int?) ?? 0;
        if (countMid > maxRows) {
          _db.raw.execute(
            'DELETE FROM change_log WHERE local_revision NOT IN ('
            'SELECT local_revision FROM change_log ORDER BY local_revision DESC LIMIT ?)',
            [maxRows],
          );
        }
        final after = _db.raw.select('SELECT COUNT(*) AS c FROM change_log');
        final countAfter = (after.first['c'] as int?) ?? 0;
        deleted = countBefore - countAfter;
      });
      return ok(deleted);
    } on Object catch (e) {
      return err(StorageFailure('db.gc_failed', e.toString(), isRetryable: true));
    }
  }
}
