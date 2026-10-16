/// 提醒开关的本地持久化（STORY-6.3 边界 + STORY-8.1 AC5）。
///
/// 键名与 `sync_scope.dart` 的 `kSyncedSettingKeys` 中 `pref.reminder` 一致：
/// PRD 8.1 把「提醒开关」列为**可同步设置**，因此这里不允许换键名。
///
/// **双写**（audit 2026-10-15 收口）：
/// - `app_meta`（可同步的那一份）：由 [registerMetaBridge] 注入的写入器落库，
///   它与月起始日走**同一条** `setting` change_log 路径，因此开关会跨端；
/// - `SharedPreferences`（本机兜底）：`app_meta` 的写入器还没注册时（极早期启动）
///   或注入失败时，开关至少不丢。
///
/// **读回**以 `app_meta` 为准：对端 pull 下来的开关写的就是 `app_meta`
/// （`SyncApplier._applySetting` 只认这一处），若读 SharedPreferences 就永远读不到
/// 同步过来的值。两者都没有时回落默认（逐项全开、总开关关）。
library;

import 'package:plain/core/constants/app_constants.dart';
import 'package:plain/domain/entities/reminder.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// `app_meta` 写入器（bootstrap 注入；已带 `setting` change_log）。
typedef ReminderMetaWriter = void Function(String key, String value);

/// `app_meta` 读取器（bootstrap 注入）。
typedef ReminderMetaReader = String? Function(String key);

class ReminderPrefsStore {
  ReminderPrefsStore._();

  static ReminderMetaWriter? _metaWriter;
  static ReminderMetaReader? _metaReader;

  /// bootstrap 在 change_log 写入器就绪后注入（见 `_registerSyncedMetaWriter`）。
  static void registerMetaBridge({
    required ReminderMetaWriter write,
    required ReminderMetaReader read,
  }) {
    _metaWriter = write;
    _metaReader = read;
  }

  /// 读取偏好；`app_meta` 优先，其次 SharedPreferences，最后默认值。
  static Future<ReminderPrefs> load() async {
    final synced = _metaReader?.call(ReminderRules.kPrefReminder);
    if (synced != null && synced.isNotEmpty) {
      return ReminderPrefs.decode(synced);
    }
    try {
      final sp = await SharedPreferences.getInstance();
      return ReminderPrefs.decode(sp.getString(ReminderRules.kPrefReminder));
    } catch (_) {
      return const ReminderPrefs();
    }
  }

  /// 保存：先写可同步的 `app_meta`，再写本机 SharedPreferences。
  static Future<void> save(ReminderPrefs prefs) async {
    final encoded = prefs.encode();
    try {
      _metaWriter?.call(ReminderRules.kPrefReminder, encoded);
    } catch (_) {
      // app_meta 写失败不能连累本机持久化，下面的 SharedPreferences 仍会写入。
    }
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(ReminderRules.kPrefReminder, encoded);
    } catch (_) {
      // 写偏好失败不影响本次会话的开关状态，下次再写。
    }
  }
}
