/// 预置分类树的结构性升级（2026-10-19：30 个支出一级 + 全员二级）。
///
/// 老库里的这些预置二级，本次被**提升为一级**；另有几个一级改了名。
/// 只在 `AppDatabase._migrate()` 里跑（每次打开都跑，判据是「现状是否还是旧样子」，
/// 幂等）。账单引用的是分类 id，提升父级不改 id，**不丢任何账**。
library;

/// 老库「二级 → 一级」：分类 id → 变更前必须匹配的父 id。
///
/// 若用户已经手动挪过（parent_id 不是这个值），一律不动。
const Map<String, String> kPromotedPresetIds = {
  'preset_shopping_clothes': 'preset_shopping',
  'preset_shopping_beauty': 'preset_shopping',
  'preset_shopping_digital': 'preset_shopping',
  'preset_shopping_home': 'preset_shopping',
  'preset_ent_game': 'preset_entertainment',
  'preset_ent_travel': 'preset_entertainment',
  'preset_ent_sport': 'preset_entertainment',
  'preset_study_book': 'preset_study',
  'preset_housing_water': 'preset_housing',
};

/// 一级改名：分类 id → (旧名, 新名)。只在「现在还是旧名」时改。
const Map<String, (String, String)> kRenamedPresetIds = {
  'preset_shopping_beauty': ('美妆', '美妆个护'),
  'preset_study_book': ('书籍', '书籍阅读'),
  'preset_housing_water': ('水电气', '水电燃气'),
  'preset_medical': ('医疗', '医疗健康'),
  'preset_social': ('人情', '人情往来'),
};
