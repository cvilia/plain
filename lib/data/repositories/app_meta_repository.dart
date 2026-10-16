/// `app_meta` 键值设置的最小读写门面。
///
/// STORY-6.3 的「备份提醒」需要一条**跨重启的持久化事实**——上次备份完成的
/// 时刻。它既不是账本数据也不是偏好，落 `app_meta`；写点（备份页）与读点
/// （提醒服务）都走这里，不各自裸写 SQL。
library;

import 'package:plain/data/db/database.dart';

class AppMetaRepository {
  AppMetaRepository({required AppDatabase db}) : _db = db;

  final AppDatabase _db;

  /// 「上次备份完成时刻」（UTC 毫秒）。
  static const String kLastBackupAt = 'backup.last_at';

  String? read(String key) {
    final rows = _db.raw.select('SELECT value FROM app_meta WHERE key = ?', [key]);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  int? readInt(String key) => int.tryParse(read(key) ?? '');

  void write(String key, String value) {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    _db.raw.execute(
      'INSERT INTO app_meta (key,value,updated_at) VALUES (?,?,?) '
      'ON CONFLICT(key) DO UPDATE SET value=?,updated_at=?',
      [key, value, now, value, now],
    );
  }

  /// 上次备份时刻（ms）；从未备份过返回 null。
  int? lastBackupAtMs() => readInt(kLastBackupAt);

  /// 备份/恢复完成后打点。
  void markBackedUpAt(DateTime at) =>
      write(kLastBackupAt, '${at.millisecondsSinceEpoch}');
}
