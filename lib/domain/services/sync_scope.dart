/// 同步范围判定（STORY-8.1 AC4/AC5）。
/// 原则：描述「数据是什么」的同步；描述「这台设备怎么看数据」的不同步。
library;

/// 可同步的数据资产类型（对应 change_log.entity_type / 表）。
const Set<String> kSyncedEntityTypes = {
  'transaction',
  'category',
  'account',
  'budget',
  'recurring_rule',
  'rule',
  'savings_goal',
};

/// 可同步设置 key（app_meta / prefs）。
const Set<String> kSyncedSettingKeys = {
  'pref.month_start_day',
  'pref.hide_amounts',
  'pref.font_scale',
  'pref.sound_enabled',
  'pref.stay_after_save',
  // 提醒开关
  'pref.reminder',
};

/// 本地偏好：永不同步（INV-3 / AC4）。
const Set<String> kLocalOnlySettingKeys = {
  'pref.theme.id',
  'pref.theme.mode',
  'pref.home_card_layout',
  'pref.entry_layout',
};

bool isSyncedEntityType(String type) => kSyncedEntityTypes.contains(type);

bool isSyncedSetting(String key) =>
    kSyncedSettingKeys.contains(key) && !kLocalOnlySettingKeys.contains(key);

bool isLocalOnlySetting(String key) => kLocalOnlySettingKeys.contains(key);

/// 导出 payload 过滤：去掉本地偏好（AC5）。
Map<String, Object?> filterSyncPayload(Map<String, Object?> payload) {
  final out = <String, Object?>{};
  for (final e in payload.entries) {
    if (isLocalOnlySetting(e.key)) continue;
    if (e.key.startsWith('pref.theme') ||
        e.key.contains('homeCard') ||
        e.key.contains('themeMode') ||
        e.key.contains('themeId')) {
      continue;
    }
    out[e.key] = e.value;
  }
  return out;
}
