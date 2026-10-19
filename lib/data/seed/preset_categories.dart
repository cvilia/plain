/// Preset category seed data —— **本文件就是分类预设的唯一真值**
///（原注释指向的 `12-分类体系设计.md` 已不存在，别再照它找）。
///
/// · `seedPresetCategories` **只在空库跑** —— 用户改名/挪组后不会被重新写回，
///   但对**后加的**预设也就永远不生效；
/// · 后加的预设由 `backfillPresetCategories` 每次启动补插（幂等、只新增不覆盖）。
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
    PresetCategory(key: 'food_breakfast', name: '早餐', kind: CategoryKind.expense, iconRef: 'bread', note: '上午 10 点前吃的'),
    PresetCategory(key: 'food_lunch', name: '午餐', kind: CategoryKind.expense, iconRef: 'noodle', note: '工作日的中饭、外卖、堂食'),
    PresetCategory(key: 'food_dinner', name: '晚餐', kind: CategoryKind.expense, iconRef: 'hotpot', note: '晚饭；朋友下馆子也记这里'),
    PresetCategory(key: 'food_night', name: '夜宵', kind: CategoryKind.expense, iconRef: 'bbq', note: '晚饭之后的加餐'),
    PresetCategory(key: 'food_snack', name: '零食', kind: CategoryKind.expense, iconRef: 'dessert', note: '包装食品、坚果这类嘴馋开销'),
    PresetCategory(key: 'food_drink', name: '饮料', kind: CategoryKind.expense, iconRef: 'coffee', note: '现制咖啡奶茶、瓶装即饮；整箱采购记「日用」'),
  ]),
  PresetCategory(key: 'shopping', name: '购物', kind: CategoryKind.expense, iconRef: 'shopping',
      note: '耐用品与穿戴；消耗品记「日用」', children: [
    PresetCategory(key: 'shopping_clothes', name: '服饰', kind: CategoryKind.expense, iconRef: 'clothes', note: '衣裤鞋帽、配饰、箱包'),
    PresetCategory(key: 'shopping_digital', name: '数码', kind: CategoryKind.expense, iconRef: 'laptop', note: '手机电脑、配件、数码周边'),
    PresetCategory(key: 'shopping_home', name: '家居', kind: CategoryKind.expense, iconRef: 'furniture', note: '耐用品：锅具、家具、家纺'),
    PresetCategory(key: 'shopping_beauty', name: '美妆', kind: CategoryKind.expense, iconRef: 'cosmetics', note: '彩妆、香水、护肤'),
  ]),
  PresetCategory(key: 'daily', name: '日用', kind: CategoryKind.expense, iconRef: 'daily',
      note: '消耗品（纸品、清洁、洗护）；耐用品记「购物」', children: [
    PresetCategory(key: 'daily_household', name: '日用品', kind: CategoryKind.expense, iconRef: 'bottle', note: '牙膏、洗发水、沐浴露等洗护消耗品'),
    PresetCategory(key: 'daily_clean', name: '清洁纸品', kind: CategoryKind.expense, iconRef: 'cleaning', note: '纸巾、洗衣液、清洁剂、垃圾袋'),
  ]),
  PresetCategory(key: 'transport', name: '交通', kind: CategoryKind.expense, iconRef: 'transport',
      note: '通勤与出行工具；旅行中的交通也记这里', children: [
    PresetCategory(key: 'transport_bus', name: '公交地铁', kind: CategoryKind.expense, iconRef: 'metro', note: '公交、地铁、共享单车'),
    PresetCategory(key: 'transport_taxi', name: '打车', kind: CategoryKind.expense, iconRef: 'taxi', note: '网约车、出租车'),
    PresetCategory(key: 'transport_fuel', name: '加油', kind: CategoryKind.expense, iconRef: 'gas', note: '汽车加油、充电'),
    PresetCategory(key: 'transport_park', name: '停车', kind: CategoryKind.expense, iconRef: 'parking', note: '停车费、过路费、违章罚款'),
    PresetCategory(key: 'transport_long', name: '火车机票', kind: CategoryKind.expense, iconRef: 'train', note: '火车、高铁、机票、长途客运'),
  ]),
  PresetCategory(key: 'fruit', name: '食材', kind: CategoryKind.expense, iconRef: 'grocery',
      note: '买菜买肉买米，回家做；在外吃记「餐饮」', children: [
    PresetCategory(key: 'fruit_veg', name: '蔬菜', kind: CategoryKind.expense, iconRef: 'vegetable', note: '蔬菜、菌菇、豆制品'),
    PresetCategory(key: 'fruit_fruit', name: '水果', kind: CategoryKind.expense, iconRef: 'fruit', note: '水果、干果'),
    PresetCategory(key: 'fruit_meat', name: '肉蛋', kind: CategoryKind.expense, iconRef: 'meat', note: '肉禽蛋、水产'),
    PresetCategory(key: 'fruit_grain', name: '粮油调味', kind: CategoryKind.expense, iconRef: 'kitchen', note: '米面粮油、盐糖酱醋'),
  ]),
  PresetCategory(key: 'entertainment', name: '娱乐', kind: CategoryKind.expense, iconRef: 'entertainment',
      note: '玩乐与兴趣；旅行中的交通记「交通」', children: [
    PresetCategory(key: 'ent_movie', name: '电影', kind: CategoryKind.expense, iconRef: 'movie', note: '电影票、演出、展览'),
    PresetCategory(key: 'ent_game', name: '游戏', kind: CategoryKind.expense, iconRef: 'game', note: '游戏充值、皮肤、道具'),
    PresetCategory(key: 'ent_travel', name: '旅行', kind: CategoryKind.expense, iconRef: 'travel', note: '住宿、门票；交通记「交通」'),
    PresetCategory(key: 'ent_sport', name: '运动健身', kind: CategoryKind.expense, iconRef: 'gym', note: '健身房、场地费、运动装备'),
  ]),
  PresetCategory(key: 'telecom', name: '通讯', kind: CategoryKind.expense, iconRef: 'telecom',
      note: '手机与网络的固定支出', children: [
    PresetCategory(key: 'telecom_phone', name: '话费', kind: CategoryKind.expense, iconRef: 'phone', note: '手机套餐、流量充值'),
    PresetCategory(key: 'telecom_net', name: '网费', kind: CategoryKind.expense, iconRef: 'internet', note: '宽带、有线电视'),
  ]),
  PresetCategory(key: 'housing', name: '居住', kind: CategoryKind.expense, iconRef: 'housing',
      note: '住处的固定支出', children: [
    PresetCategory(key: 'housing_rent', name: '房租', kind: CategoryKind.expense, iconRef: 'rent', note: '租房租金、押金'),
    PresetCategory(key: 'housing_mortgage', name: '房贷', kind: CategoryKind.expense, iconRef: 'loan', note: '按揭月供'),
    PresetCategory(key: 'housing_property', name: '物业', kind: CategoryKind.expense, iconRef: 'bill', note: '物业费、取暖费'),
    PresetCategory(key: 'housing_water', name: '水电气', kind: CategoryKind.expense, iconRef: 'utilities', note: '水费、电费、燃气费'),
    PresetCategory(key: 'housing_repair', name: '家修', kind: CategoryKind.expense, iconRef: 'tools', note: '维修、装修、家电修理'),
  ]),
  PresetCategory(key: 'medical', name: '医疗', kind: CategoryKind.expense, iconRef: 'medical',
      note: '看病买药与健康支出', children: [
    PresetCategory(key: 'medical_drug', name: '药品', kind: CategoryKind.expense, iconRef: 'pharmacy', note: '药店购药'),
    PresetCategory(key: 'medical_hospital', name: '就医', kind: CategoryKind.expense, iconRef: 'doctor', note: '挂号、门诊、住院'),
    PresetCategory(key: 'medical_care', name: '保健', kind: CategoryKind.expense, iconRef: 'health', note: '体检、保健品、理疗'),
  ]),
  PresetCategory(key: 'study', name: '学习', kind: CategoryKind.expense, iconRef: 'study',
      note: '提升自己的支出', children: [
    PresetCategory(key: 'study_book', name: '书籍', kind: CategoryKind.expense, iconRef: 'book', note: '纸质书、电子书'),
    PresetCategory(key: 'study_course', name: '课程', kind: CategoryKind.expense, iconRef: 'course', note: '培训、网课、学费'),
    PresetCategory(key: 'study_exam', name: '考试报名', kind: CategoryKind.expense, iconRef: 'exam', note: '考证、报名费、考试差旅'),
  ]),
  PresetCategory(key: 'social', name: '人情', kind: CategoryKind.expense, iconRef: 'social',
      note: '送礼、红包、替他人付账', children: [
    PresetCategory(key: 'social_gift', name: '礼物', kind: CategoryKind.expense, iconRef: 'gift', note: '送出去的礼物'),
    PresetCategory(key: 'social_red', name: '红包', kind: CategoryKind.expense, iconRef: 'redpacket', note: '份子钱、压岁钱、微信红包'),
    PresetCategory(key: 'social_party', name: '请客', kind: CategoryKind.expense, iconRef: 'party', note: '替他人付的餐费'),
  ]),
  PresetCategory(key: 'other', name: '其他', kind: CategoryKind.expense, iconRef: 'other',
      note: '仅在无更贴切分类时使用'),
];

/// 收入预设。
///
/// 口径：**每条的收入都要能被归类**，所以除了「工资 / 奖金 / 理财 / 兼职」这条
/// 主线，把常见的「报销（回款）、红包（礼金）、补贴（公积金/社保返还）、退款、
/// 经营、变卖、中奖、家用」都单列出来 —— 它们混在「其他」里会让收入报表失去
/// 解释力。每条 note 都写「什么算、什么不算」，避免又落回「凭感觉选」。
///
/// 结构上**与支出侧同一套**：一级当"文件夹"（记账时选不到），二级才是可选项
/// （`CategoryListX.leaves`）。所以「理财 / 兼职 / 经营 / 补贴」这四类也各带二级，
/// 二级**沿用一级的 iconRef**（支出侧同样如此：所有「餐饮」二级都用 food 图标）。
///
/// ⚠️ `其他`（`income_other`）必须**留在最后**，且 id 不能改：`preset_income_other`
/// 是收入侧的兜底分类（删分类时的改挂目标）。
const List<PresetCategory> presetIncomeCategories = [
  PresetCategory(key: 'income_salary', name: '工资', kind: CategoryKind.income, iconRef: 'salary',
      note: '每月固定薪酬；一次性的激励记「奖金」', children: [
    PresetCategory(key: 'income_base', name: '基本工资', kind: CategoryKind.income, iconRef: 'wallet', note: '税后到手的基本薪酬'),
    PresetCategory(key: 'income_overtime', name: '加班', kind: CategoryKind.income, iconRef: 'office', note: '加班费、值班补贴'),
  ]),
  PresetCategory(key: 'income_bonus', name: '奖金', kind: CategoryKind.income, iconRef: 'bonus',
      note: '基本工资之外的激励性收入', children: [
    PresetCategory(key: 'income_year_end', name: '年终奖', kind: CategoryKind.income, iconRef: 'trophy', note: '年度奖金'),
    PresetCategory(key: 'income_project', name: '项目奖', kind: CategoryKind.income, iconRef: 'medal', note: '项目完结发的一次性奖'),
    PresetCategory(key: 'income_commission', name: '提成', kind: CategoryKind.income, iconRef: 'cup', note: '销售提成、绩效奖'),
  ]),
  PresetCategory(key: 'income_invest', name: '理财', kind: CategoryKind.income, iconRef: 'invest',
      note: '钱生钱的部分；本金进出不算收入', children: [
    PresetCategory(key: 'income_interest', name: '利息', kind: CategoryKind.income, iconRef: 'interest', note: '存款、货币基金利息'),
    PresetCategory(key: 'income_invest_return', name: '投资收益', kind: CategoryKind.income, iconRef: 'fund', note: '基金、股票、理财赎回的收益'),
    PresetCategory(key: 'income_dividend', name: '分红', kind: CategoryKind.income, iconRef: 'dividend', note: '股息、股东分红'),
  ]),
  PresetCategory(key: 'income_parttime', name: '兼职', kind: CategoryKind.income, iconRef: 'parttime',
      note: '本职工作之外的零散进账；成规模的生意记「经营」', children: [
    PresetCategory(key: 'income_royalty', name: '稿费', kind: CategoryKind.income, iconRef: 'pen', note: '稿酬、版权、课程分成'),
    PresetCategory(key: 'income_freelance', name: '外包接单', kind: CategoryKind.income, iconRef: 'freelance', note: '设计、开发、咨询等私活'),
  ]),
  PresetCategory(key: 'income_business', name: '经营', kind: CategoryKind.income, iconRef: 'business',
      note: '以经营主体的名义入账；个人打零工记「兼职」', children: [
    PresetCategory(key: 'income_revenue', name: '营业收入', kind: CategoryKind.income, iconRef: 'invoice', note: '店铺、项目结算的净收入'),
    PresetCategory(key: 'income_affiliate', name: '带货佣金', kind: CategoryKind.income, iconRef: 'barcode', note: '直播、分销、联盟返佣'),
  ]),
  PresetCategory(key: 'income_reimburse', name: '报销', kind: CategoryKind.income, iconRef: 'reimburse',
      note: '仅用于无对应账单的补贴类回款'),
  PresetCategory(key: 'income_redpacket', name: '红包', kind: CategoryKind.income, iconRef: 'redpacket',
      note: '亲友给的红包、压岁钱、礼金'),
  PresetCategory(key: 'income_subsidy', name: '补贴', kind: CategoryKind.income, iconRef: 'subsidy',
      note: '单位/政策给的补助；报销回款记「报销」', children: [
    PresetCategory(key: 'income_housing_fund', name: '公积金', kind: CategoryKind.income, iconRef: 'safe', note: '单位缴存 + 提取到账'),
    PresetCategory(key: 'income_social_insurance', name: '社保返还', kind: CategoryKind.income, iconRef: 'pension', note: '医保报销、失业金、生育津贴'),
    PresetCategory(key: 'income_meal_allowance', name: '交通餐补', kind: CategoryKind.income, iconRef: 'bus_card', note: '车补、餐补、话费补贴'),
  ]),
  PresetCategory(key: 'income_refund', name: '退款', kind: CategoryKind.income, iconRef: 'refund',
      note: '购物退款、返现、平台赔付'),
  PresetCategory(key: 'income_resale', name: '变卖', kind: CategoryKind.income, iconRef: 'resale',
      note: '二手转卖、闲置出手'),
  PresetCategory(key: 'income_prize', name: '中奖', kind: CategoryKind.income, iconRef: 'prize',
      note: '抽奖、彩票、比赛奖金'),
  PresetCategory(key: 'income_family', name: '家用', kind: CategoryKind.income, iconRef: 'family',
      note: '家人给的生活费、赡养费'),
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

/// 老库补插**后加的**预设分类（种子只在空库跑，见文件头）。
///
/// 每次启动跑一遍，幂等：
/// · 按主键 `preset_<key>` **只插缺失的** —— 用户改过名 / 挪过分组 / 软删过的行
///   主键还在，直接跳过，绝不会"恢复出厂设置"；
/// · 新增项 `sort_order` 取「现有最大值 +10」递增追加（目前新增都在收入侧），
///   并把收入侧的「其他」顶到最末，保证它始终垫底；
/// · 顺带把几个预置的**兜底图标**升级成专属图标 —— 仅当用户没动过
///   （`icon_ref` 仍是 `other`、且没上传自定义图）才改。
Future<void> backfillPresetCategories(AppDatabase db, Clock clock) async {
  final deviceRows =
      db.raw.select('SELECT value FROM app_meta WHERE key = ?', ['device.id']);
  final deviceId = deviceRows.isEmpty ? '' : deviceRows.first['value']! as String;
  if (deviceId.isEmpty) return;

  final now = clock.now().millisecondsSinceEpoch;
  db.transaction(() {
    var order = db.raw
        .select('SELECT IFNULL(MAX(sort_order), 0) AS m FROM categories')
        .first['m']! as int;

    void insertMissing(PresetCategory cat, String? parentId) {
      final id = 'preset_${cat.key}';
      final exists =
          db.raw.select('SELECT 1 FROM categories WHERE id = ?', [id]).isNotEmpty;
      if (!exists) {
        order += 10;
        // `OR IGNORE`：用户可能已经自建了同名分类（主键不同、名字相同）——
        // 撞 `uq_category_name` 时跳过就行，绝不能让一条约束把整个事务掀翻。
        db.raw.execute(
          'INSERT OR IGNORE INTO categories (id,parent_id,name,kind,icon_ref,note,sort_order,is_hidden,is_preset,created_at,updated_at,revision,device_id,base_revision) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
          [id, parentId, cat.name, cat.kind.wire, cat.iconRef, cat.note, order, 0, 1, now, now, 1, deviceId, 0],
        );
      }
      for (final child in cat.children) {
        insertMissing(child, id);
      }
    }

    for (final cat in presetIncomeCategories) {
      insertMissing(cat, null);
    }
    // 「其他」永远垫底（新增项都是追加在它后面的）
    db.raw.execute(
      "UPDATE categories SET sort_order = ? WHERE id = 'preset_income_other'",
      [order + 10],
    );
    // 预置图标升级：只碰用户没动过的那些（改过名/换过图的一律不动）
    const iconUpgrades = <String, String>{
      'preset_income_invest': 'invest',
      'preset_income_parttime': 'parttime',
      'preset_income_reimburse': 'reimburse',
    };
    iconUpgrades.forEach((id, ref) {
      db.raw.execute(
        "UPDATE categories SET icon_ref = ? WHERE id = ? AND icon_ref = 'other'",
        [ref, id],
      );
    });
  });
}
