/// 提醒历史（`reminders` 表，schema v24）的读写。
///
/// 两件事共用这张表（STORY-6.3 边界）：
///   ① **同类去重**——同一去重键在窗口内只产生一次（如「同一预算周期的同一分类
///      80%/100% 各一次」）；
///   ② **历史可查**——近 90 天全部提醒（含已读/未读）与触发时间。
///
/// 表示**这台设备产生过什么提醒**（通知日志），不是账本数据，因此不写
/// change_log、不进云同步；但随备份/恢复走（`restoreFrom` 清单里有它）。
library;

import 'package:plain/core/result/result.dart';
import 'package:plain/data/db/database.dart';
import 'package:plain/data/db/row_x.dart';
import 'package:plain/domain/entities/reminder.dart';
import 'package:plain/domain/repositories/repositories.dart';

class ReminderRepositoryImpl implements ReminderRepository {
  ReminderRepositoryImpl({required AppDatabase db}) : _db = db;

  final AppDatabase _db;

  @override
  Future<Result<void>> append({
    required String bookId,
    required AppReminder reminder,
  }) async {
    try {
      _db.raw.execute(
        'INSERT INTO reminders (id,book_id,kind,title,body,requested_level,level,dedup_key,triggered_at,is_read,digested,created_at) '
        'VALUES (?,?,?,?,?,?,?,?,?,?,?,?)',
        [
          reminder.id,
          bookId,
          reminder.kind.wire,
          reminder.title,
          reminder.body,
          reminder.effectiveRequestedLevel.wire,
          reminder.level.wire,
          reminder.dedupKey,
          reminder.triggeredAt.millisecondsSinceEpoch,
          reminder.read ? 1 : 0,
          0,
          reminder.triggeredAt.millisecondsSinceEpoch,
        ],
      );
      return ok(null);
    } on Object catch (e) {
      return err(StorageFailure('db.insert_failed', e.toString(), isRetryable: true));
    }
  }

  @override
  Future<Result<bool>> hasSince({
    required String bookId,
    required String dedupKey,
    required int sinceMs,
  }) async {
    try {
      final rows = _db.raw.select(
        'SELECT COUNT(*) AS c FROM reminders '
        'WHERE book_id = ? AND dedup_key = ? AND triggered_at >= ?',
        [bookId, dedupKey, sinceMs],
      );
      return ok(((rows.first['c'] as int?) ?? 0) > 0);
    } on Object catch (e) {
      return err(StorageFailure('db.query_failed', e.toString(), isRetryable: true));
    }
  }

  @override
  Future<Result<List<AppReminder>>> listRecent({
    required String bookId,
    required int sinceMs,
    int limit = 200,
    bool undigestedOnly = false,
  }) async {
    try {
      final rows = _db.raw.select(
        'SELECT * FROM reminders WHERE book_id = ? AND triggered_at >= ?'
        '${undigestedOnly ? ' AND digested = 0' : ''} '
        'ORDER BY triggered_at DESC, id DESC LIMIT ?',
        [bookId, sinceMs, limit],
      );
      return ok(rows.map(_fromRow).toList());
    } on Object catch (e) {
      return err(StorageFailure('db.query_failed', e.toString(), isRetryable: true));
    }
  }

  @override
  Future<Result<void>> markRead({required String id, required bool read}) async {
    try {
      _db.raw.execute(
        'UPDATE reminders SET is_read = ? WHERE id = ?',
        [read ? 1 : 0, id],
      );
      return ok(null);
    } on Object catch (e) {
      return err(StorageFailure('db.update_failed', e.toString(), isRetryable: true));
    }
  }

  @override
  Future<Result<void>> markDigested({required List<String> ids}) async {
    if (ids.isEmpty) return ok(null);
    try {
      final placeholders = List.filled(ids.length, '?').join(',');
      _db.raw.execute(
        'UPDATE reminders SET digested = 1 WHERE id IN ($placeholders)',
        ids,
      );
      return ok(null);
    } on Object catch (e) {
      return err(StorageFailure('db.update_failed', e.toString(), isRetryable: true));
    }
  }

  @override
  Future<Result<int>> gc({required DateTime before}) async {
    try {
      final rows = _db.raw.select(
        'SELECT COUNT(*) AS c FROM reminders WHERE triggered_at < ?',
        [before.millisecondsSinceEpoch],
      );
      final n = (rows.first['c'] as int?) ?? 0;
      if (n > 0) {
        _db.raw.execute(
          'DELETE FROM reminders WHERE triggered_at < ?',
          [before.millisecondsSinceEpoch],
        );
      }
      return ok(n);
    } on Object catch (e) {
      return err(StorageFailure('db.delete_failed', e.toString(), isRetryable: true));
    }
  }

  AppReminder _fromRow(Map<String, Object?> row) => AppReminder(
        id: row['id']! as String,
        kind: ReminderKind.fromWire(row['kind'] as String?),
        title: (row['title'] as String?) ?? '',
        body: (row['body'] as String?) ?? '',
        requestedLevel:
            ReminderLevel.values.firstWhere(
          (l) => l.wire == row['requested_level'],
          orElse: () => ReminderLevel.ring,
        ),
        level: ReminderLevel.values.firstWhere(
          (l) => l.wire == row['level'],
          orElse: () => ReminderLevel.silent,
        ),
        dedupKey: (row['dedup_key'] as String?) ?? '',
        triggeredAt: row.dateTime('triggered_at'),
        read: row.boolOr('is_read'),
      );
}
