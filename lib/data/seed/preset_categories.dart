/// Preset category seed data. Source of truth: 12-分类体系设计.md §3–§5.
/// Note: seed only runs when categories table is empty — renames apply to new installs only.
library;

import 'package:plain/core/time/clock.dart';
import 'package:plain/data/db/database.dart';
import 'package:plain/domain/entities/enums.dart';

class PresetCategory {
  const PresetCategory({
    required this.key,
    required this.name,
    required this.kind,
    required this.iconRef,
    this.note,
    this.children = const [],
  });

  final String key;
  final String name;
  final CategoryKind kind;
  final String iconRef;
  final String? note;
  final List<PresetCategory> children;
}

const List<PresetCategory> presetExpenseCategories = [
  PresetCategory(key: 'food', name: '餐饮', kind: CategoryKind.expense, iconRef: 'food',
      note: '在外吃、点外卖、现制饮品；买回家做的记「食材」', children: [
    PresetCategory(key: 'food_breakfast', name: '早餐', kind: CategoryKind.expense, iconRef: 'food', note: '上午 10 点前吃的'),
    PresetCategory(key: 'food_lunch', name: '午餐', kind: CategoryKind.expense, iconRef: 'food', note: '工作日的中饭、外卖、堂食'),
    PresetCategory(key: 'food_dinner', name: '晚餐', kind: CategoryKind.expense, iconRef: 'food', note: '晚饭；朋友下馆子也记这里'),
    PresetCategory(key: 'food_night', name: '夜宵', kind: CategoryKind.expense, iconRef: 'food', note: '晚饭之后的加餐'),
    PresetCategory(key: 'food_snack', name: '零食', kind: CategoryKind.expense, iconRef: 'food', note: '包装食品、坚果这类嘴馋开销'),
    PresetCategory(key: 'food_drink', name: '饮料', kind: CategoryKind.expense, iconRef: 'food', note: '现制咖啡奶茶、瓶装即饮；整箱采购记「日用」'),
  ]),
  PresetCategory(key: 'shopping', name: '购物', kind: CategoryKind.expense, iconRef: 'shopping',
      note: '耐用品与穿戴；消耗品记「日用」', children: [
    PresetCategory(key: 'shopping_clothes', name: '服饰', kind: CategoryKind.expense, iconRef: 'shopping', note: '衣裤鞋帽、配饰、箱包'),
    PresetCategory(key: 'shopping_digital', name: '数码', kind: CategoryKind.expense, iconRef: 'shopping', note: '手机电脑、配件、数码周边'),
    PresetCategory(key: 'shopping_home', name: '家居', kind: CategoryKind.expense, iconRef: 'shopping', note: '耐用品：锅具、家具、家纺'),
    PresetCategory(key: 'shopping_beauty', name: '美妆', kind: CategoryKind.expense, iconRef: 'shopping', note: '彩妆、香水、护肤'),
  ]),
  PresetCategory(key: 'daily', name: '日用', kind: CategoryKind.expense, iconRef: 'daily',
      note: '消耗品（纸品、清洁、洗护）；耐用品记「购物」', children: [
    PresetCategory(key: 'daily_household', name: '日用品', kind: CategoryKind.expense, iconRef: 'daily', note: '牙膏、洗发水、沐浴露等洗护消耗品'),
    PresetCategory(key: 'daily_clean', name: '清洁纸品', kind: CategoryKind.expense, iconRef: 'daily', note: '纸巾、洗衣液、清洁剂、垃圾袋'),
  ]),
  PresetCategory(key: 'transport', name: '交通', kind: CategoryKind.expense, iconRef: 'transport',
      note: '通勤与出行工具；旅行中的交通也记这里', children: [
    PresetCategory(key: 'transport_bus', name: '公交地铁', kind: CategoryKind.expense, iconRef: 'transport', note: '公交、地铁、共享单车'),
    PresetCategory(key: 'transport_taxi', name: '打车', kind: CategoryKind.expense, iconRef: 'transport', note: '网约车、出租车'),
    PresetCategory(key: 'transport_fuel', name: '加油', kind: CategoryKind.expense, iconRef: 'transport', note: '汽车加油、充电'),
    PresetCategory(key: 'transport_park', name: '停车', kind: CategoryKind.expense, iconRef: 'transport', note: '停车费、过路费、违章罚款'),
    PresetCategory(key: 'transport_long', name: '火车机票', kind: CategoryKind.expense, iconRef: 'transport', note: '火车、高铁、机票、长途客运'),
  ]),
  PresetCategory(key: 'fruit', name: '食材', kind: CategoryKind.expense, iconRef: 'fruit',
      note: '买菜买肉买米，回家做；在外吃记「餐饮」', children: [
    PresetCategory(key: 'fruit_veg', name: '蔬菜', kind: CategoryKind.expense, iconRef: 'fruit', note: '蔬菜、菌菇、豆制品'),
    PresetCategory(key: 'fruit_fruit', name: '水果', kind: CategoryKind.expense, iconRef: 'fruit', note: '水果、干果'),
    PresetCategory(key: 'fruit_meat', name: '肉蛋', kind: CategoryKind.expense, iconRef: 'fruit', note: '肉禽蛋、水产'),
    PresetCategory(key: 'fruit_grain', name: '粮油调味', kind: CategoryKind.expense, iconRef: 'fruit', note: '米面粮油、盐糖酱醋'),
  ]),
  PresetCategory(key: 'entertainment', name: '娱乐', kind: CategoryKind.expense, iconRef: 'entertainment',
      note: '玩乐与兴趣；旅行中的交通记「交通」', children: [
    PresetCategory(key: 'ent_movie', name: '电影', kind: CategoryKind.expense, iconRef: 'entertainment', note: '电影票、演出、展览'),
    PresetCategory(key: 'ent_game', name: '游戏', kind: CategoryKind.expense, iconRef: 'entertainment', note: '游戏充值、皮肤、道具'),
    PresetCategory(key: 'ent_travel', name: '旅行', kind: CategoryKind.expense, iconRef: 'entertainment', note: '住宿、门票；交通记「交通」'),
    PresetCategory(key: 'ent_sport', name: '运动健身', kind: CategoryKind.expense, iconRef: 'entertainment', note: '健身房、场地费、运动装备'),
  ]),
  PresetCategory(key: 'telecom', name: '通讯', kind: CategoryKind.expense, iconRef: 'telecom',
      note: '手机与网络的固定支出', children: [
    PresetCategory(key: 'telecom_phone', name: '话费', kind: CategoryKind.expense, iconRef: 'telecom', note: '手机套餐、流量充值'),
    PresetCategory(key: 'telecom_net', name: '网费', kind: CategoryKind.expense, iconRef: 'telecom', note: '宽带、有线电视'),
  ]),
  PresetCategory(key: 'housing', name: '居住', kind: CategoryKind.expense, iconRef: 'housing',
      note: '住处的固定支出', children: [
    PresetCategory(key: 'housing_rent', name: '房租', kind: CategoryKind.expense, iconRef: 'housing', note: '租房租金、押金'),
    PresetCategory(key: 'housing_mortgage', name: '房贷', kind: CategoryKind.expense, iconRef: 'housing', note: '按揭月供'),
    PresetCategory(key: 'housing_property', name: '物业', kind: CategoryKind.expense, iconRef: 'housing', note: '物业费、取暖费'),
    PresetCategory(key: 'housing_water', name: '水电气', kind: CategoryKind.expense, iconRef: 'housing', note: '水费、电费、燃气费'),
    PresetCategory(key: 'housing_repair', name: '家修', kind: CategoryKind.expense, iconRef: 'housing', note: '维修、装修、家电修理'),
  ]),
  PresetCategory(key: 'medical', name: '医疗', kind: CategoryKind.expense, iconRef: 'medical',
      note: '看病买药与健康支出', children: [
    PresetCategory(key: 'medical_drug', name: '药品', kind: CategoryKind.expense, iconRef: 'medical', note: '药店购药'),
    PresetCategory(key: 'medical_hospital', name: '就医', kind: CategoryKind.expense, iconRef: 'medical', note: '挂号、门诊、住院'),
    PresetCategory(key: 'medical_care', name: '保健', kind: CategoryKind.expense, iconRef: 'medical', note: '体检、保健品、理疗'),
  ]),
  PresetCategory(key: 'study', name: '学习', kind: CategoryKind.expense, iconRef: 'study',
      note: '提升自己的支出', children: [
    PresetCategory(key: 'study_book', name: '书籍', kind: CategoryKind.expense, iconRef: 'study', note: '纸质书、电子书'),
    PresetCategory(key: 'study_course', name: '课程', kind: CategoryKind.expense, iconRef: 'study', note: '培训、网课、学费'),
    PresetCategory(key: 'study_exam', name: '考试报名', kind: CategoryKind.expense, iconRef: 'study', note: '考证、报名费、考试差旅'),
  ]),
  PresetCategory(key: 'social', name: '人情', kind: CategoryKind.expense, iconRef: 'social',
      note: '送礼、红包、替他人付账', children: [
    PresetCategory(key: 'social_gift', name: '礼物', kind: CategoryKind.expense, iconRef: 'social', note: '送出去的礼物'),
    PresetCategory(key: 'social_red', name: '红包', kind: CategoryKind.expense, iconRef: 'social', note: '份子钱、压岁钱、微信红包'),
    PresetCategory(key: 'social_party', name: '请客', kind: CategoryKind.expense, iconRef: 'social', note: '替他人付的餐费'),
  ]),
  PresetCategory(key: 'other', name: '其他', kind: CategoryKind.expense, iconRef: 'other',
      note: '仅在无更贴切分类时使用'),
];

const List<PresetCategory> presetIncomeCategories = [
  PresetCategory(key: 'income_salary', name: '工资', kind: CategoryKind.income, iconRef: 'salary',
      note: '每月固定薪酬', children: [
    PresetCategory(key: 'income_base', name: '基本工资', kind: CategoryKind.income, iconRef: 'salary', note: '税后到手的基本薪酬'),
    PresetCategory(key: 'income_overtime', name: '加班', kind: CategoryKind.income, iconRef: 'salary', note: '加班费、值班补贴'),
  ]),
  PresetCategory(key: 'income_bonus', name: '奖金', kind: CategoryKind.income, iconRef: 'bonus',
      note: '基本工资之外的激励性收入', children: [
    PresetCategory(key: 'income_year_end', name: '年终奖', kind: CategoryKind.income, iconRef: 'bonus', note: '年度奖金'),
    PresetCategory(key: 'income_project', name: '项目奖', kind: CategoryKind.income, iconRef: 'bonus', note: '项目提成、绩效奖'),
  ]),
  PresetCategory(key: 'income_invest', name: '理财', kind: CategoryKind.income, iconRef: 'other',
      note: '利息、分红、理财赎回收益'),
  PresetCategory(key: 'income_parttime', name: '兼职', kind: CategoryKind.income, iconRef: 'other',
      note: '副业、外快、稿费'),
  PresetCategory(key: 'income_reimburse', name: '报销', kind: CategoryKind.income, iconRef: 'other',
      note: '仅用于无对应账单的补贴类回款'),
  PresetCategory(key: 'income_other', name: '其他', kind: CategoryKind.income, iconRef: 'other',
      note: '仅在无更贴切分类时使用'),
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
        'INSERT OR IGNORE INTO categories (id,parent_id,name,kind,icon_ref,note,sort_order,is_hidden,is_preset,created_at,updated_at,revision,device_id,base_revision) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
        [id, parentId, cat.name, cat.kind.wire, cat.iconRef, cat.note, sortOrder, 0, 1, now.millisecondsSinceEpoch, now.millisecondsSinceEpoch, 1, deviceId, 0]);
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
