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
  ///
  /// ⚠️ **开了 WebDAV 同步就不再按时间删**（2026-10-20 修）：
  /// 按 `changed_at` 删行只看「本机这条日志多久了」，完全不看对端位点。
  /// 一台设备离线超过 30 天，它要的那段变更已经被删掉，而同步位点照常推进 ——
  /// 结果是**永久缺一段账、无报错**。删除是不可逆的，所以宁可多占几 MB。
  /// 行数上限保留（5 万行 ≈ 个人记账好几年的变更量），只作为增长兜底。
  ///
  /// 未配置同步（单机使用）时没有消费方，按时间裁剪仍然安全。
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

        if (!_syncConfigured()) {
          _db.raw.execute('DELETE FROM change_log WHERE changed_at < ?', [cutoff]);
        }

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

  /// 这台设备是否配置过 WebDAV 同步（= 有别的设备在消费本机的 change_log）。
  bool _syncConfigured() {
    final rows = _db.raw.select(
      "SELECT value FROM app_meta WHERE key = 'webdav.url'",
    );
    if (rows.isEmpty) return false;
    return ((rows.first['value'] as String?) ?? '').trim().isNotEmpty;
  }
}
