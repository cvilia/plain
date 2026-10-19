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
  // STORY-8.1 同步范围表：成员是数据资产，要同步
  'member',
  'holding',
  'saved_report',
  'tax_filing',
  'merchant_rule',
  // STORY-9.3 锁定汇率：用户手填的「原币 → 本位币」汇率是**账本数据**
  // （换了设备照样要按同一汇率折算），因此必须跨端。
  'currency_rate',
  // 原 `attachment`（STORY-1.5）已随附件功能移除，不再同步。
  // 可同步设置（月起始日 / 隐藏余额 / 字体大小 / 音效 / 保存后停留 / 提醒开关）。
  // 具体键还要过 kSyncedSettingKeys 白名单——凭据、主题、布局都不在其中。
  'setting',
  // STORY-8.2 的 AA 参与人（audit 2026-10-15 前完全没进同步）
  'entry_participant',
};

/// entity_type → 表名（同步落库用）。
const Map<String, String> kEntityTables = {
  'transaction': 'transactions',
  'category': 'categories',
  'account': 'accounts',
  'budget': 'budgets',
  'recurring_rule': 'recurring_rules',
  'rule': 'rules',
  'savings_goal': 'savings_goals',
  'merchant_rule': 'merchant_rules',
  'member': 'members',
  'holding': 'holdings',
  'saved_report': 'saved_reports',
  'tax_filing': 'tax_filings',
  'currency_rate': 'currency_rates',
  // 可同步设置落 app_meta（主键是 key，落库走专门分支）
  'setting': 'app_meta',
  'entry_participant': 'entry_participants',
};

/// 这张表要不要参与增量同步（附件只同步元数据，见上）。
bool isSyncableTable(String entityType) =>
    kEntityTables.containsKey(entityType) && isSyncedEntityType(entityType);

/// 可同步设置 key（app_meta / prefs）。
const Set<String> kSyncedSettingKeys = {
  'pref.month_start_day',
  'pref.hide_amounts',
  'pref.font_scale',
  'pref.sound_enabled',
  'pref.stay_after_save',
  // 提醒开关（STORY-6.3 的逐项开关 + 「全部静音」总开关）。
  // PRD 8.1 把「提醒开关」列为**可同步设置**：`ReminderPrefsStore` 保存时
  // 同时写 `app_meta`（走 `registerMetaWriter` → 记一条 `setting` 变更），
  // 启动/开局也从 `app_meta` 读回，因此这里登记后开关真的会跨端。
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
