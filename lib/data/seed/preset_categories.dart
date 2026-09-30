/// Preset category seed data. See PRD STORY-1.3.
library;

import 'package:plain/core/time/clock.dart';
import 'package:plain/data/db/database.dart';
import 'package:plain/domain/entities/enums.dart';

class PresetCategory {
  const PresetCategory({required this.key, required this.name, required this.kind, required this.iconRef, this.children = const []});
  final String key;
  final String name;
  final CategoryKind kind;
  final String iconRef;
  final List<PresetCategory> children;
}

const List<PresetCategory> presetExpenseCategories = [
  PresetCategory(key: 'food', name: '餐饮', kind: CategoryKind.expense, iconRef: 'food', children: [
    PresetCategory(key: 'food_breakfast', name: '早餐', kind: CategoryKind.expense, iconRef: 'food'),
    PresetCategory(key: 'food_lunch', name: '正餐', kind: CategoryKind.expense, iconRef: 'food'),
    PresetCategory(key: 'food_snack', name: '零食', kind: CategoryKind.expense, iconRef: 'food'),
    PresetCategory(key: 'food_drink', name: '饮料', kind: CategoryKind.expense, iconRef: 'food'),
  ]),
  PresetCategory(key: 'shopping', name: '购物', kind: CategoryKind.expense, iconRef: 'shopping', children: [
    PresetCategory(key: 'shopping_clothes', name: '服饰', kind: CategoryKind.expense, iconRef: 'shopping'),
    PresetCategory(key: 'shopping_digital', name: '数码', kind: CategoryKind.expense, iconRef: 'shopping'),
    PresetCategory(key: 'shopping_home', name: '家居', kind: CategoryKind.expense, iconRef: 'shopping'),
    PresetCategory(key: 'shopping_beauty', name: '美妆', kind: CategoryKind.expense, iconRef: 'shopping'),
  ]),
  PresetCategory(key: 'daily', name: '日用', kind: CategoryKind.expense, iconRef: 'daily', children: [
    PresetCategory(key: 'daily_supermarket', name: '超市', kind: CategoryKind.expense, iconRef: 'daily'),
    PresetCategory(key: 'daily_household', name: '日用品', kind: CategoryKind.expense, iconRef: 'daily'),
  ]),
  PresetCategory(key: 'transport', name: '交通', kind: CategoryKind.expense, iconRef: 'transport', children: [
    PresetCategory(key: 'transport_bus', name: '公交地铁', kind: CategoryKind.expense, iconRef: 'transport'),
    PresetCategory(key: 'transport_taxi', name: '打车', kind: CategoryKind.expense, iconRef: 'transport'),
    PresetCategory(key: 'transport_fuel', name: '加油', kind: CategoryKind.expense, iconRef: 'transport'),
  ]),
  PresetCategory(key: 'fruit', name: '蔬果', kind: CategoryKind.expense, iconRef: 'fruit', children: [
    PresetCategory(key: 'fruit_veg', name: '蔬菜', kind: CategoryKind.expense, iconRef: 'fruit'),
    PresetCategory(key: 'fruit_fruit', name: '水果', kind: CategoryKind.expense, iconRef: 'fruit'),
    PresetCategory(key: 'fruit_meat', name: '肉蛋', kind: CategoryKind.expense, iconRef: 'fruit'),
  ]),
  PresetCategory(key: 'entertainment', name: '娱乐', kind: CategoryKind.expense, iconRef: 'entertainment', children: [
    PresetCategory(key: 'ent_movie', name: '电影', kind: CategoryKind.expense, iconRef: 'entertainment'),
    PresetCategory(key: 'ent_game', name: '游戏', kind: CategoryKind.expense, iconRef: 'entertainment'),
    PresetCategory(key: 'ent_travel', name: '旅行', kind: CategoryKind.expense, iconRef: 'entertainment'),
  ]),
  PresetCategory(key: 'telecom', name: '通讯', kind: CategoryKind.expense, iconRef: 'telecom', children: [
    PresetCategory(key: 'telecom_phone', name: '话费', kind: CategoryKind.expense, iconRef: 'telecom'),
    PresetCategory(key: 'telecom_net', name: '网费', kind: CategoryKind.expense, iconRef: 'telecom'),
  ]),
  PresetCategory(key: 'housing', name: '居住', kind: CategoryKind.expense, iconRef: 'housing', children: [
    PresetCategory(key: 'housing_rent', name: '房租', kind: CategoryKind.expense, iconRef: 'housing'),
    PresetCategory(key: 'housing_water', name: '水电气', kind: CategoryKind.expense, iconRef: 'housing'),
    PresetCategory(key: 'housing_property', name: '物业', kind: CategoryKind.expense, iconRef: 'housing'),
  ]),
  PresetCategory(key: 'medical', name: '医疗', kind: CategoryKind.expense, iconRef: 'medical', children: [
    PresetCategory(key: 'medical_drug', name: '药品', kind: CategoryKind.expense, iconRef: 'medical'),
    PresetCategory(key: 'medical_hospital', name: '就医', kind: CategoryKind.expense, iconRef: 'medical'),
  ]),
  PresetCategory(key: 'study', name: '学习', kind: CategoryKind.expense, iconRef: 'study', children: [
    PresetCategory(key: 'study_book', name: '书籍', kind: CategoryKind.expense, iconRef: 'study'),
    PresetCategory(key: 'study_course', name: '课程', kind: CategoryKind.expense, iconRef: 'study'),
  ]),
  PresetCategory(key: 'social', name: '人情', kind: CategoryKind.expense, iconRef: 'social', children: [
    PresetCategory(key: 'social_gift', name: '礼物', kind: CategoryKind.expense, iconRef: 'social'),
    PresetCategory(key: 'social_red', name: '红包', kind: CategoryKind.expense, iconRef: 'social'),
    PresetCategory(key: 'social_party', name: '聚餐', kind: CategoryKind.expense, iconRef: 'social'),
  ]),
  PresetCategory(key: 'other', name: '其他', kind: CategoryKind.expense, iconRef: 'other'),
];

const List<PresetCategory> presetIncomeCategories = [
  PresetCategory(key: 'income_salary', name: '工资', kind: CategoryKind.income, iconRef: 'salary', children: [
    PresetCategory(key: 'income_base', name: '基本工资', kind: CategoryKind.income, iconRef: 'salary'),
    PresetCategory(key: 'income_overtime', name: '加班', kind: CategoryKind.income, iconRef: 'salary'),
  ]),
  PresetCategory(key: 'income_bonus', name: '奖金', kind: CategoryKind.income, iconRef: 'bonus', children: [
    PresetCategory(key: 'income_year_end', name: '年终奖', kind: CategoryKind.income, iconRef: 'bonus'),
    PresetCategory(key: 'income_project', name: '项目奖', kind: CategoryKind.income, iconRef: 'bonus'),
  ]),
  PresetCategory(key: 'income_invest', name: '理财', kind: CategoryKind.income, iconRef: 'other'),
  PresetCategory(key: 'income_parttime', name: '兼职', kind: CategoryKind.income, iconRef: 'other'),
  PresetCategory(key: 'income_reimburse', name: '报销', kind: CategoryKind.income, iconRef: 'other'),
  PresetCategory(key: 'income_other', name: '其他', kind: CategoryKind.income, iconRef: 'other'),
];

Future<void> seedPresetCategories(AppDatabase db, Clock clock) async {
  final now = clock.now();
  final deviceRows = db.raw.select('SELECT value FROM app_meta WHERE key = ?', ['device.id']);
  final deviceId = deviceRows.isEmpty ? '' : deviceRows.first['value']! as String;
  if (deviceId.isEmpty) return;

  final existing = db.raw.select('SELECT COUNT(*) AS c FROM categories');
  if ((existing.first['c'] as int) > 0) return;

  db.transaction(() {
    var sortOrder = 0;
    void insertOne(PresetCategory cat, String? parentId) {
      final id = 'preset_${cat.key}';
      db.raw.execute(
        'INSERT OR IGNORE INTO categories (id,parent_id,name,kind,icon_ref,sort_order,is_hidden,is_preset,created_at,updated_at,revision,device_id,base_revision) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)',
        [id, parentId, cat.name, cat.kind.wire, cat.iconRef, sortOrder, 0, 1, now.millisecondsSinceEpoch, now.millisecondsSinceEpoch, 1, deviceId, 0]);
      sortOrder += 10;
      for (final child in cat.children) {
        insertOne(child, id);
      }
    }

    for (final cat in presetExpenseCategories) {
      insertOne(cat, null);
    }
    for (final cat in presetIncomeCategories) {
      insertOne(cat, null);
    }
  });
}
