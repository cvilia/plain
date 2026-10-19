/// Preset category seed data —— **本文件就是分类预设的唯一真值**
///（原注释指向的 `12-分类体系设计.md` 已不存在，别再照它找）。
///
/// 2026-10-19 重构（爸爸口径）：
/// · **支出一级 30 个**，每个一级都有独立图标（`assets/icons/ic_cat_*`，图标库
///   同步精简到 30+1 枚）；**每个一级下面都必须有二级**，记账时只选二级；
/// · **收入 13 个一级**，同样每级都有二级（原先 7 个光杆一级已补齐）；
/// · 二级不写 `iconRef`，**继承父级图标** —— 30 枚图标对应 30 个一级分类，
///   子级再各配图标就会让「30 个支出图标」的口径失效，也没必要。
///
/// · `seedPresetCategories` **只在空库跑** —— 用户改名/挪组后不会被重新写回；
/// · 后加的预设由 `backfillPresetCategories` 每次启动补插（幂等、只新增不覆盖）；
/// · 老库里被「提升为一级」的预置二级（服饰/数码/家居/美妆/游戏/旅行/运动健身/
///   书籍/水电气）由 `AppDatabase._migrate()` 里的一次性 `promoteLegacyPresets`
///   摘掉 parent_id —— 账单引用的仍是同一个分类 id，不会丢数据。
library;

import 'package:plain/core/time/clock.dart';
import 'package:plain/data/db/database.dart';
import 'package:plain/domain/entities/enums.dart';

class PresetCategory {
  const PresetCategory({
    required this.key,
    required this.name,
    required this.kind,
    this.iconRef = '',
    this.note,
    this.children = const [],
  });

  final String key;
  final String name;
  final CategoryKind kind;

  /// 空 = 继承父级图标（所有二级都走这条）。
  final String iconRef;
  final String? note;
  final List<PresetCategory> children;
}

/// 支出一级 30 个（顺序即记账宫格/分类管理页的默认顺序）。
const List<PresetCategory> presetExpenseCategories = [
  // 1
  PresetCategory(key: 'food', name: '餐饮', kind: CategoryKind.expense, iconRef: 'food',
      note: '在外吃、点外卖；买回家做的记「食材」', children: [
    PresetCategory(key: 'food_breakfast', name: '早餐', kind: CategoryKind.expense, note: '上午 10 点前吃的'),
    PresetCategory(key: 'food_lunch', name: '午餐', kind: CategoryKind.expense, note: '工作日的中饭、堂食'),
    PresetCategory(key: 'food_dinner', name: '晚餐', kind: CategoryKind.expense, note: '晚饭；朋友下馆子也记这里'),
    PresetCategory(key: 'food_night', name: '夜宵', kind: CategoryKind.expense, note: '晚饭之后的加餐'),
    PresetCategory(key: 'food_snack', name: '零食', kind: CategoryKind.expense, note: '包装食品、坚果这类嘴馋开销'),
    PresetCategory(key: 'food_takeout', name: '外卖', kind: CategoryKind.expense, note: '配送费、打包费算在餐费里'),
    PresetCategory(key: 'food_drink', name: '饮料', kind: CategoryKind.expense, note: '佐餐饮料；现制咖啡奶茶记「咖啡茶饮」'),
    PresetCategory(key: 'food_banquet', name: '宴席聚餐', kind: CategoryKind.expense, note: '多人聚餐、请客吃饭（自己付钱）'),
  ]),
  // 2
  PresetCategory(key: 'fruit', name: '食材', kind: CategoryKind.expense, iconRef: 'grocery',
      note: '买菜买肉买米，回家做；在外吃记「餐饮」', children: [
    PresetCategory(key: 'fruit_veg', name: '蔬菜', kind: CategoryKind.expense, note: '蔬菜、菌菇、豆制品'),
    PresetCategory(key: 'fruit_fruit', name: '水果', kind: CategoryKind.expense, note: '水果、干果'),
    PresetCategory(key: 'fruit_meat', name: '肉蛋', kind: CategoryKind.expense, note: '肉禽蛋'),
    PresetCategory(key: 'fruit_seafood', name: '水产', kind: CategoryKind.expense, note: '鱼虾蟹贝'),
    PresetCategory(key: 'fruit_grain', name: '粮油调味', kind: CategoryKind.expense, note: '米面粮油、盐糖酱醋'),
    PresetCategory(key: 'fruit_frozen', name: '速冻食品', kind: CategoryKind.expense, note: '速冻水饺、半成品'),
  ]),
  // 3
  PresetCategory(key: 'coffee', name: '咖啡茶饮', kind: CategoryKind.expense, iconRef: 'coffee',
      note: '现制饮品店：咖啡、奶茶、茶饮', children: [
    PresetCategory(key: 'coffee_shop', name: '咖啡', kind: CategoryKind.expense, note: '现磨咖啡、连锁咖啡'),
    PresetCategory(key: 'coffee_milk_tea', name: '奶茶', kind: CategoryKind.expense, note: '奶茶、果茶'),
    PresetCategory(key: 'coffee_tea', name: '茶饮', kind: CategoryKind.expense, note: '纯茶、柠檬茶'),
    PresetCategory(key: 'coffee_bottle', name: '瓶装饮料', kind: CategoryKind.expense, note: '便利店整瓶、整箱采购'),
  ]),
  // 4
  PresetCategory(key: 'shopping', name: '购物', kind: CategoryKind.expense, iconRef: 'shopping',
      note: '大件与穿戴以外的买买买；消耗品记「日用」', children: [
    PresetCategory(key: 'shopping_bag', name: '箱包', kind: CategoryKind.expense, note: '背包、行李箱、钱包'),
    PresetCategory(key: 'shopping_jewelry', name: '首饰', kind: CategoryKind.expense, note: '项链、戒指、耳饰'),
    PresetCategory(key: 'shopping_watch', name: '手表', kind: CategoryKind.expense, note: '腕表、智能手表'),
    PresetCategory(key: 'shopping_gift', name: '礼品采购', kind: CategoryKind.expense, note: '买来送人的东西（送出后记「人情」）'),
    PresetCategory(key: 'shopping_misc', name: '其他购物', kind: CategoryKind.expense, note: '一次性的杂项采购'),
  ]),
  // 5（老库：由「购物 · 服饰」提升为一级）
  PresetCategory(key: 'shopping_clothes', name: '服饰', kind: CategoryKind.expense, iconRef: 'clothes',
      note: '衣裤鞋帽、配饰、箱包', children: [
    PresetCategory(key: 'clothes_tops', name: '上衣裤装', kind: CategoryKind.expense, note: 'T 恤、衬衫、裤子、外套'),
    PresetCategory(key: 'clothes_shoes', name: '鞋靴', kind: CategoryKind.expense, note: '运动鞋、皮鞋、靴子'),
    PresetCategory(key: 'clothes_accessory', name: '帽子配饰', kind: CategoryKind.expense, note: '帽子、围巾、腰带'),
    PresetCategory(key: 'clothes_underwear', name: '内衣袜品', kind: CategoryKind.expense, note: '内衣、袜子、家居服'),
    PresetCategory(key: 'clothes_tailor', name: '改衣定制', kind: CategoryKind.expense, note: '裁缝、改裤脚、干洗熨烫'),
  ]),
  // 6（老库：由「购物 · 美妆」提升为一级）
  PresetCategory(key: 'shopping_beauty', name: '美妆个护', kind: CategoryKind.expense, iconRef: 'cosmetics',
      note: '护肤彩妆与个人护理', children: [
    PresetCategory(key: 'beauty_skincare', name: '护肤', kind: CategoryKind.expense, note: '水乳面霜、面膜'),
    PresetCategory(key: 'beauty_makeup', name: '彩妆', kind: CategoryKind.expense, note: '底妆、口红、眼妆'),
    PresetCategory(key: 'beauty_perfume', name: '香水', kind: CategoryKind.expense, note: '香水、香氛'),
    PresetCategory(key: 'beauty_hair', name: '洗护美发', kind: CategoryKind.expense, note: '洗发护发、烫染剪发'),
    PresetCategory(key: 'beauty_nail', name: '美甲美容', kind: CategoryKind.expense, note: '美甲、美容院'),
  ]),
  // 7（老库：由「购物 · 数码」提升为一级）
  PresetCategory(key: 'shopping_digital', name: '数码', kind: CategoryKind.expense, iconRef: 'laptop',
      note: '手机电脑、配件、数码周边', children: [
    PresetCategory(key: 'digital_phone', name: '手机', kind: CategoryKind.expense, note: '手机整机、平板'),
    PresetCategory(key: 'digital_computer', name: '电脑', kind: CategoryKind.expense, note: '笔记本、台式机、显示器'),
    PresetCategory(key: 'digital_accessory', name: '配件耗材', kind: CategoryKind.expense, note: '数据线、充电头、键鼠、耳机'),
    PresetCategory(key: 'digital_smart', name: '智能设备', kind: CategoryKind.expense, note: '手环、音箱、智能家居'),
    PresetCategory(key: 'digital_repair', name: '数码维修', kind: CategoryKind.expense, note: '换屏、换电池、维修费'),
  ]),
  // 8（老库：由「购物 · 家居」提升为一级）
  PresetCategory(key: 'shopping_home', name: '家居', kind: CategoryKind.expense, iconRef: 'furniture',
      note: '耐用品：家具、家纺、家电', children: [
    PresetCategory(key: 'home_furniture', name: '家具', kind: CategoryKind.expense, note: '桌椅、床柜、沙发'),
    PresetCategory(key: 'home_textile', name: '家纺', kind: CategoryKind.expense, note: '床品、窗帘、地毯'),
    PresetCategory(key: 'home_kitchenware', name: '厨具', kind: CategoryKind.expense, note: '锅具、餐具、小厨电'),
    PresetCategory(key: 'home_decor', name: '家饰', kind: CategoryKind.expense, note: '摆件、绿植、挂画'),
    PresetCategory(key: 'home_appliance', name: '家电', kind: CategoryKind.expense, note: '冰箱、洗衣机、空调'),
  ]),
  // 9
  PresetCategory(key: 'daily', name: '日用', kind: CategoryKind.expense, iconRef: 'daily',
      note: '消耗品（纸品、清洁、洗护）；耐用品记「家居」', children: [
    PresetCategory(key: 'daily_household', name: '日用品', kind: CategoryKind.expense, note: '牙膏、洗发水、沐浴露等洗护消耗品'),
    PresetCategory(key: 'daily_clean', name: '清洁纸品', kind: CategoryKind.expense, note: '纸巾、洗衣液、清洁剂、垃圾袋'),
    PresetCategory(key: 'daily_kitchen', name: '厨房耗材', kind: CategoryKind.expense, note: '保鲜膜、洗碗布、一次性用品'),
    PresetCategory(key: 'daily_storage', name: '收纳整理', kind: CategoryKind.expense, note: '收纳盒、衣架、挂钩'),
    PresetCategory(key: 'daily_battery', name: '电池五金', kind: CategoryKind.expense, note: '电池、灯泡、螺丝五金'),
  ]),
  // 10
  PresetCategory(key: 'transport', name: '交通', kind: CategoryKind.expense, iconRef: 'transport',
      note: '通勤与出行工具；养车开销记「汽车养护」', children: [
    PresetCategory(key: 'transport_bus', name: '公交地铁', kind: CategoryKind.expense, note: '公交、地铁'),
    PresetCategory(key: 'transport_taxi', name: '打车', kind: CategoryKind.expense, note: '网约车、出租车'),
    PresetCategory(key: 'transport_fuel', name: '加油', kind: CategoryKind.expense, note: '汽车加油'),
    PresetCategory(key: 'transport_park', name: '停车', kind: CategoryKind.expense, note: '停车费、过路费、违章罚款'),
    PresetCategory(key: 'transport_long', name: '火车机票', kind: CategoryKind.expense, note: '火车、高铁、机票、长途客运'),
    PresetCategory(key: 'transport_bike', name: '共享单车', kind: CategoryKind.expense, note: '共享单车、共享电单车'),
  ]),
  // 11
  PresetCategory(key: 'auto', name: '汽车养护', kind: CategoryKind.expense, iconRef: 'car',
      note: '养车的固定开销；加油停车记「交通」', children: [
    PresetCategory(key: 'auto_maintenance', name: '保养', kind: CategoryKind.expense, note: '小保养、大保养'),
    PresetCategory(key: 'auto_repair', name: '维修', kind: CategoryKind.expense, note: '事故维修、换件'),
    PresetCategory(key: 'auto_wash', name: '洗车', kind: CategoryKind.expense, note: '洗车、打蜡、内饰清洁'),
    PresetCategory(key: 'auto_charge', name: '充电', kind: CategoryKind.expense, note: '新能源充电桩'),
    PresetCategory(key: 'auto_inspection', name: '年检', kind: CategoryKind.expense, note: '年检、上牌、车船税'),
  ]),
  // 12
  PresetCategory(key: 'housing', name: '居住', kind: CategoryKind.expense, iconRef: 'housing',
      note: '住处的固定支出；水电燃气单列', children: [
    PresetCategory(key: 'housing_rent', name: '房租', kind: CategoryKind.expense, note: '租房租金、押金'),
    PresetCategory(key: 'housing_mortgage', name: '房贷', kind: CategoryKind.expense, note: '按揭月供'),
    PresetCategory(key: 'housing_property', name: '物业', kind: CategoryKind.expense, note: '物业费、取暖费'),
    PresetCategory(key: 'housing_repair', name: '家修', kind: CategoryKind.expense, note: '维修、装修、家电修理'),
    PresetCategory(key: 'housing_agent', name: '中介费', kind: CategoryKind.expense, note: '租房买房中介费'),
    PresetCategory(key: 'housing_moving', name: '搬家', kind: CategoryKind.expense, note: '搬家、仓储'),
  ]),
  // 13（老库：由「居住 · 水电气」提升为一级）
  PresetCategory(key: 'housing_water', name: '水电燃气', kind: CategoryKind.expense, iconRef: 'electricity',
      note: '住处的公用事业费', children: [
    PresetCategory(key: 'utilities_electric', name: '电费', kind: CategoryKind.expense, note: '家庭用电'),
    PresetCategory(key: 'utilities_water', name: '水费', kind: CategoryKind.expense, note: '自来水、污水处理'),
    PresetCategory(key: 'utilities_gas', name: '燃气费', kind: CategoryKind.expense, note: '天然气、煤气'),
    PresetCategory(key: 'utilities_heating', name: '取暖费', kind: CategoryKind.expense, note: '集中供暖'),
    PresetCategory(key: 'utilities_waste', name: '垃圾处理', kind: CategoryKind.expense, note: '垃圾清运费'),
  ]),
  // 14
  PresetCategory(key: 'telecom', name: '通讯', kind: CategoryKind.expense, iconRef: 'telecom',
      note: '手机与网络的固定支出', children: [
    PresetCategory(key: 'telecom_phone', name: '话费', kind: CategoryKind.expense, note: '手机套餐'),
    PresetCategory(key: 'telecom_net', name: '网费', kind: CategoryKind.expense, note: '宽带、有线电视'),
    PresetCategory(key: 'telecom_data', name: '流量', kind: CategoryKind.expense, note: '流量包、日租卡'),
    PresetCategory(key: 'telecom_tv', name: '有线电视', kind: CategoryKind.expense, note: '广电收视费'),
  ]),
  // 15
  PresetCategory(key: 'entertainment', name: '娱乐', kind: CategoryKind.expense, iconRef: 'entertainment',
      note: '玩乐与兴趣；游戏 / 旅行 / 运动健身已单列', children: [
    PresetCategory(key: 'ent_movie', name: '电影', kind: CategoryKind.expense, note: '电影票、影院消费'),
    PresetCategory(key: 'ent_show', name: '演出展览', kind: CategoryKind.expense, note: '演唱会、话剧、展览'),
    PresetCategory(key: 'ent_ktv', name: 'KTV', kind: CategoryKind.expense, note: 'KTV、Livehouse'),
    PresetCategory(key: 'ent_bar', name: '酒吧', kind: CategoryKind.expense, note: '酒吧、清吧'),
    PresetCategory(key: 'ent_boardgame', name: '桌游密室', kind: CategoryKind.expense, note: '桌游、剧本杀、密室'),
  ]),
  // 16（老库：由「娱乐 · 游戏」提升为一级）
  PresetCategory(key: 'ent_game', name: '游戏', kind: CategoryKind.expense, iconRef: 'game',
      note: '游戏充值、皮肤、道具', children: [
    PresetCategory(key: 'game_recharge', name: '游戏充值', kind: CategoryKind.expense, note: '点券、钻石、金币'),
    PresetCategory(key: 'game_sub', name: '游戏订阅', kind: CategoryKind.expense, note: '月卡、会员、通行证'),
    PresetCategory(key: 'game_item', name: '道具皮肤', kind: CategoryKind.expense, note: '皮肤、道具、抽卡'),
    PresetCategory(key: 'game_console', name: '主机游戏', kind: CategoryKind.expense, note: '主机、卡带、手柄'),
  ]),
  // 17（老库：由「娱乐 · 旅行」提升为一级）
  PresetCategory(key: 'ent_travel', name: '旅行', kind: CategoryKind.expense, iconRef: 'travel',
      note: '住宿、门票；交通记「交通」', children: [
    PresetCategory(key: 'travel_hotel', name: '住宿', kind: CategoryKind.expense, note: '酒店、民宿'),
    PresetCategory(key: 'travel_ticket', name: '门票', kind: CategoryKind.expense, note: '景区、乐园门票'),
    PresetCategory(key: 'travel_package', name: '跟团游', kind: CategoryKind.expense, note: '旅行团、机酒套餐'),
    PresetCategory(key: 'travel_visa', name: '签证', kind: CategoryKind.expense, note: '签证、通行证'),
    PresetCategory(key: 'travel_camping', name: '露营', kind: CategoryKind.expense, note: '营地、露营装备租赁'),
  ]),
  // 18（老库：由「娱乐 · 运动健身」提升为一级）
  PresetCategory(key: 'ent_sport', name: '运动健身', kind: CategoryKind.expense, iconRef: 'sports',
      note: '健身房、场地费、运动装备', children: [
    PresetCategory(key: 'sport_gym', name: '健身卡', kind: CategoryKind.expense, note: '年卡、私教课'),
    PresetCategory(key: 'sport_field', name: '场地费', kind: CategoryKind.expense, note: '球场、泳池、攀岩'),
    PresetCategory(key: 'sport_gear', name: '运动装备', kind: CategoryKind.expense, note: '跑鞋、球拍、护具'),
    PresetCategory(key: 'sport_swim', name: '游泳', kind: CategoryKind.expense, note: '泳池、游泳课'),
    PresetCategory(key: 'sport_yoga', name: '瑜伽', kind: CategoryKind.expense, note: '瑜伽馆、普拉提'),
  ]),
  // 19
  PresetCategory(key: 'medical', name: '医疗健康', kind: CategoryKind.expense, iconRef: 'medical',
      note: '看病买药与健康支出', children: [
    PresetCategory(key: 'medical_drug', name: '药品', kind: CategoryKind.expense, note: '药店购药'),
    PresetCategory(key: 'medical_hospital', name: '就医', kind: CategoryKind.expense, note: '挂号、门诊、住院'),
    PresetCategory(key: 'medical_care', name: '保健', kind: CategoryKind.expense, note: '保健品、理疗'),
    PresetCategory(key: 'medical_checkup', name: '体检', kind: CategoryKind.expense, note: '年度体检、专项检查'),
    PresetCategory(key: 'medical_dental', name: '牙科', kind: CategoryKind.expense, note: '洗牙、补牙、正畸'),
    PresetCategory(key: 'medical_glasses', name: '配镜', kind: CategoryKind.expense, note: '近视镜、隐形眼镜'),
  ]),
  // 20
  PresetCategory(key: 'study', name: '学习', kind: CategoryKind.expense, iconRef: 'study',
      note: '提升自己的支出；买书记「书籍阅读」', children: [
    PresetCategory(key: 'study_course', name: '课程', kind: CategoryKind.expense, note: '培训、网课、学费'),
    PresetCategory(key: 'study_exam', name: '考试报名', kind: CategoryKind.expense, note: '考证、报名费、考试差旅'),
    PresetCategory(key: 'study_training', name: '技能培训', kind: CategoryKind.expense, note: '线下班、工作坊'),
    PresetCategory(key: 'study_online', name: '线上会员', kind: CategoryKind.expense, note: '学习平台会员、题库'),
  ]),
  // 21（老库：由「学习 · 书籍」提升为一级）
  PresetCategory(key: 'study_book', name: '书籍阅读', kind: CategoryKind.expense, iconRef: 'library',
      note: '纸质书、电子书、报刊', children: [
    PresetCategory(key: 'book_paper', name: '纸质书', kind: CategoryKind.expense, note: '新书、二手书'),
    PresetCategory(key: 'book_ebook', name: '电子书', kind: CategoryKind.expense, note: 'Kindle、阅读 App'),
    PresetCategory(key: 'book_magazine', name: '杂志报纸', kind: CategoryKind.expense, note: '期刊、报纸'),
    PresetCategory(key: 'book_borrow', name: '借阅会员', kind: CategoryKind.expense, note: '图书馆、借书卡'),
  ]),
  // 22
  PresetCategory(key: 'office', name: '办公文印', kind: CategoryKind.expense, iconRef: 'printer',
      note: '办公用品、打印与寄件', children: [
    PresetCategory(key: 'office_supplies', name: '办公用品', kind: CategoryKind.expense, note: '文具、纸张、耗材'),
    PresetCategory(key: 'office_print', name: '打印复印', kind: CategoryKind.expense, note: '打印、复印、装订'),
    PresetCategory(key: 'office_shipping', name: '快递邮寄', kind: CategoryKind.expense, note: '快递、物流、同城配送'),
    PresetCategory(key: 'office_software', name: '办公软件', kind: CategoryKind.expense, note: '办公套件、协作工具'),
  ]),
  // 23
  PresetCategory(key: 'pet', name: '宠物', kind: CategoryKind.expense, iconRef: 'pet',
      note: '养宠开销', children: [
    PresetCategory(key: 'pet_food', name: '宠物食品', kind: CategoryKind.expense, note: '主粮、罐头、零食'),
    PresetCategory(key: 'pet_vet', name: '医疗疫苗', kind: CategoryKind.expense, note: '看病、疫苗、驱虫'),
    PresetCategory(key: 'pet_grooming', name: '洗护美容', kind: CategoryKind.expense, note: '洗澡、剪毛、寄养'),
    PresetCategory(key: 'pet_supplies', name: '用品玩具', kind: CategoryKind.expense, note: '猫砂、牵引绳、玩具'),
  ]),
  // 24
  PresetCategory(key: 'baby', name: '育儿', kind: CategoryKind.expense, iconRef: 'baby',
      note: '孩子的日常开销', children: [
    PresetCategory(key: 'baby_food', name: '奶粉辅食', kind: CategoryKind.expense, note: '奶粉、米粉、辅食'),
    PresetCategory(key: 'baby_diaper', name: '纸尿裤', kind: CategoryKind.expense, note: '纸尿裤、湿巾'),
    PresetCategory(key: 'baby_clothes', name: '婴儿衣物', kind: CategoryKind.expense, note: '童装、鞋袜'),
    PresetCategory(key: 'baby_toy', name: '玩具早教', kind: CategoryKind.expense, note: '玩具、绘本、早教课'),
    PresetCategory(key: 'baby_care', name: '托育保姆', kind: CategoryKind.expense, note: '托班、保姆、月嫂'),
  ]),
  // 25
  PresetCategory(key: 'social', name: '人情往来', kind: CategoryKind.expense, iconRef: 'social',
      note: '送礼、红包、替他人付账', children: [
    PresetCategory(key: 'social_gift', name: '礼物', kind: CategoryKind.expense, note: '送出去的礼物'),
    PresetCategory(key: 'social_red', name: '红包', kind: CategoryKind.expense, note: '份子钱、压岁钱、微信红包'),
    PresetCategory(key: 'social_party', name: '请客', kind: CategoryKind.expense, note: '替他人付的餐费'),
    PresetCategory(key: 'social_elder', name: '孝敬长辈', kind: CategoryKind.expense, note: '给父母的生活费、礼品'),
    PresetCategory(key: 'social_donate', name: '捐赠', kind: CategoryKind.expense, note: '公益捐款、义卖'),
  ]),
  // 26
  PresetCategory(key: 'insurance', name: '保险', kind: CategoryKind.expense, iconRef: 'umbrella',
      note: '各类保险保费', children: [
    PresetCategory(key: 'insurance_medical', name: '医疗险', kind: CategoryKind.expense, note: '百万医疗、门诊险'),
    PresetCategory(key: 'insurance_accident', name: '意外险', kind: CategoryKind.expense, note: '综合意外、旅行意外'),
    PresetCategory(key: 'insurance_life', name: '寿险重疾', kind: CategoryKind.expense, note: '定期寿险、重疾险'),
    PresetCategory(key: 'insurance_property', name: '财产险', kind: CategoryKind.expense, note: '家财险、宠物险'),
  ]),
  // 27
  PresetCategory(key: 'tax', name: '税费', kind: CategoryKind.expense, iconRef: 'bill',
      note: '与收入/资产相关的税费', children: [
    PresetCategory(key: 'tax_income', name: '个人所得税', kind: CategoryKind.expense, note: '年度汇算补税'),
    PresetCategory(key: 'tax_vehicle', name: '车辆税费', kind: CategoryKind.expense, note: '车船税、购置税'),
    PresetCategory(key: 'tax_property', name: '房产税费', kind: CategoryKind.expense, note: '契税、房产税'),
    PresetCategory(key: 'tax_fine', name: '罚没款', kind: CategoryKind.expense, note: '违章罚款、滞纳金'),
  ]),
  // 28
  PresetCategory(key: 'fee', name: '手续费', kind: CategoryKind.expense, iconRef: 'percent',
      note: '银行与平台收的服务费', children: [
    PresetCategory(key: 'fee_withdraw', name: '提现手续费', kind: CategoryKind.expense, note: '提现、跨行转账'),
    PresetCategory(key: 'fee_service', name: '平台服务费', kind: CategoryKind.expense, note: '电商、外卖平台佣金'),
    PresetCategory(key: 'fee_interest', name: '利息支出', kind: CategoryKind.expense, note: '信用卡分期、消费贷利息'),
    PresetCategory(key: 'fee_annual', name: '年费', kind: CategoryKind.expense, note: '银行卡年费、账户管理费'),
  ]),
  // 29
  PresetCategory(key: 'subscription', name: '订阅会员', kind: CategoryKind.expense, iconRef: 'tv',
      note: '按月/按年自动续费的会员', children: [
    PresetCategory(key: 'sub_video', name: '视频会员', kind: CategoryKind.expense, note: '长视频、影视平台'),
    PresetCategory(key: 'sub_music', name: '音乐会员', kind: CategoryKind.expense, note: '音乐、有声书'),
    PresetCategory(key: 'sub_cloud', name: '云存储', kind: CategoryKind.expense, note: '网盘、相册扩容'),
    PresetCategory(key: 'sub_software', name: '软件订阅', kind: CategoryKind.expense, note: '工具类 App、设计软件'),
  ]),
  // 30（必须垫底，且 id 不能改：用户删分类时的兜底目标之一）
  PresetCategory(key: 'other', name: '其他', kind: CategoryKind.expense, iconRef: 'other',
      note: '仅在无更贴切分类时使用', children: [
    PresetCategory(key: 'other_misc', name: '杂项支出', kind: CategoryKind.expense, note: '说不清归哪类的小额支出'),
    PresetCategory(key: 'other_pending', name: '待归类', kind: CategoryKind.expense, note: '先记下，回头再整理'),
  ]),
];

/// 收入预设（13 个一级，**每个一级都有二级**）。
///
/// 口径：**每条收入都要能被归类**，所以除了「工资 / 奖金 / 理财 / 兼职」这条
/// 主线，把常见的「报销（回款）、红包（礼金）、补贴（公积金/社保返还）、退款、
/// 经营、变卖、中奖、家用」都单列出来 —— 它们混在「其他」里会让收入报表失去
/// 解释力。每条 note 都写「什么算、什么不算」，避免又落回「凭感觉选」。
///
/// 结构上**与支出侧同一套**：一级当"文件夹"（记账时选不到），二级才是可选项
/// （`CategoryListX.leaves`）。二级不写 iconRef，继承一级图标。
///
/// ⚠️ `其他`（`income_other`）必须**留在最后**，且 id 不能改：`preset_income_other`
/// 是收入侧的兜底分类（删分类时的改挂目标）。
const List<PresetCategory> presetIncomeCategories = [
  PresetCategory(key: 'income_salary', name: '工资', kind: CategoryKind.income, iconRef: 'salary',
      note: '每月固定薪酬；一次性的激励记「奖金」', children: [
    PresetCategory(key: 'income_base', name: '基本工资', kind: CategoryKind.income, note: '税后到手的基本薪酬'),
    PresetCategory(key: 'income_overtime', name: '加班', kind: CategoryKind.income, note: '加班费、值班补贴'),
    PresetCategory(key: 'income_attendance', name: '全勤奖', kind: CategoryKind.income, note: '月度全勤、考勤奖励'),
    PresetCategory(key: 'income_performance', name: '绩效工资', kind: CategoryKind.income, note: '月度/季度绩效'),
  ]),
  PresetCategory(key: 'income_bonus', name: '奖金', kind: CategoryKind.income, iconRef: 'bonus',
      note: '基本工资之外的激励性收入', children: [
    PresetCategory(key: 'income_year_end', name: '年终奖', kind: CategoryKind.income, note: '年度奖金'),
    PresetCategory(key: 'income_project', name: '项目奖', kind: CategoryKind.income, note: '项目完结发的一次性奖'),
    PresetCategory(key: 'income_commission', name: '提成', kind: CategoryKind.income, note: '销售提成、业务提成'),
    PresetCategory(key: 'income_contest', name: '竞赛奖金', kind: CategoryKind.income, note: '公司内外比赛奖金'),
  ]),
  PresetCategory(key: 'income_invest', name: '理财', kind: CategoryKind.income, iconRef: 'invest',
      note: '钱生钱的部分；本金进出不算收入', children: [
    PresetCategory(key: 'income_interest', name: '利息', kind: CategoryKind.income, note: '存款、货币基金利息'),
    PresetCategory(key: 'income_invest_return', name: '投资收益', kind: CategoryKind.income, note: '基金、股票、理财赎回的收益'),
    PresetCategory(key: 'income_dividend', name: '分红', kind: CategoryKind.income, note: '股息、股东分红'),
    PresetCategory(key: 'income_fund_gain', name: '基金收益', kind: CategoryKind.income, note: '场外基金已实现收益'),
  ]),
  PresetCategory(key: 'income_parttime', name: '兼职', kind: CategoryKind.income, iconRef: 'parttime',
      note: '本职工作之外的零散进账；成规模的生意记「经营」', children: [
    PresetCategory(key: 'income_royalty', name: '稿费', kind: CategoryKind.income, note: '稿酬、版权、课程分成'),
    PresetCategory(key: 'income_freelance', name: '外包接单', kind: CategoryKind.income, note: '设计、开发、咨询等私活'),
    PresetCategory(key: 'income_tutoring', name: '家教', kind: CategoryKind.income, note: '家教、代课、辅导'),
    PresetCategory(key: 'income_streaming', name: '直播打赏', kind: CategoryKind.income, note: '直播、自媒体打赏分成'),
  ]),
  PresetCategory(key: 'income_business', name: '经营', kind: CategoryKind.income, iconRef: 'business',
      note: '以经营主体的名义入账；个人打零工记「兼职」', children: [
    PresetCategory(key: 'income_revenue', name: '营业收入', kind: CategoryKind.income, note: '店铺、项目结算的净收入'),
    PresetCategory(key: 'income_affiliate', name: '带货佣金', kind: CategoryKind.income, note: '直播、分销、联盟返佣'),
    PresetCategory(key: 'income_service_fee', name: '服务费收入', kind: CategoryKind.income, note: '咨询、代运营等服务收入'),
  ]),
  PresetCategory(key: 'income_reimburse', name: '报销', kind: CategoryKind.income, iconRef: 'reimburse',
      note: '仅用于无对应账单的补贴类回款', children: [
    PresetCategory(key: 'income_reimburse_travel', name: '差旅报销', kind: CategoryKind.income, note: '出差交通住宿回款'),
    PresetCategory(key: 'income_reimburse_meal', name: '餐费报销', kind: CategoryKind.income, note: '业务招待、加班餐'),
    PresetCategory(key: 'income_reimburse_purchase', name: '采购报销', kind: CategoryKind.income, note: '垫付办公采购'),
    PresetCategory(key: 'income_reimburse_other', name: '其他报销', kind: CategoryKind.income, note: '说不清类别的回款'),
  ]),
  PresetCategory(key: 'income_redpacket', name: '红包', kind: CategoryKind.income, iconRef: 'redpacket',
      note: '亲友给的红包、压岁钱、礼金', children: [
    PresetCategory(key: 'income_rp_friend', name: '亲友红包', kind: CategoryKind.income, note: '微信/支付宝收到的红包'),
    PresetCategory(key: 'income_rp_newyear', name: '压岁钱', kind: CategoryKind.income, note: '春节压岁钱'),
    PresetCategory(key: 'income_rp_gift', name: '礼金', kind: CategoryKind.income, note: '婚丧嫁娶收到的礼金'),
  ]),
  PresetCategory(key: 'income_subsidy', name: '补贴', kind: CategoryKind.income, iconRef: 'subsidy',
      note: '单位/政策给的补助；报销回款记「报销」', children: [
    PresetCategory(key: 'income_housing_fund', name: '公积金', kind: CategoryKind.income, note: '单位缴存 + 提取到账'),
    PresetCategory(key: 'income_social_insurance', name: '社保返还', kind: CategoryKind.income, note: '医保报销、失业金'),
    PresetCategory(key: 'income_meal_allowance', name: '交通餐补', kind: CategoryKind.income, note: '车补、餐补、话费补贴'),
    PresetCategory(key: 'income_housing_allowance', name: '住房补贴', kind: CategoryKind.income, note: '租房补贴、安家费'),
    PresetCategory(key: 'income_maternity', name: '生育津贴', kind: CategoryKind.income, note: '生育医疗费、产假津贴'),
  ]),
  PresetCategory(key: 'income_refund', name: '退款', kind: CategoryKind.income, iconRef: 'refund',
      note: '购物退款、返现、平台赔付', children: [
    PresetCategory(key: 'income_refund_shopping', name: '购物退款', kind: CategoryKind.income, note: '退货、取消订单'),
    PresetCategory(key: 'income_refund_platform', name: '平台赔付', kind: CategoryKind.income, note: '超时赔付、破损赔付'),
    PresetCategory(key: 'income_refund_service', name: '服务退款', kind: CategoryKind.income, note: '会员、课程、票务退款'),
  ]),
  PresetCategory(key: 'income_resale', name: '变卖', kind: CategoryKind.income, iconRef: 'resale',
      note: '二手转卖、闲置出手', children: [
    PresetCategory(key: 'income_resale_secondhand', name: '二手转让', kind: CategoryKind.income, note: '闲鱼、转转成交'),
    PresetCategory(key: 'income_resale_idle', name: '闲置出售', kind: CategoryKind.income, note: '家具家电等闲置'),
    PresetCategory(key: 'income_resale_scrap', name: '废品回收', kind: CategoryKind.income, note: '旧书旧纸、废金属'),
  ]),
  PresetCategory(key: 'income_prize', name: '中奖', kind: CategoryKind.income, iconRef: 'prize',
      note: '抽奖、彩票、比赛奖金', children: [
    PresetCategory(key: 'income_prize_lottery', name: '抽奖', kind: CategoryKind.income, note: '平台抽奖、锦鲤'),
    PresetCategory(key: 'income_prize_ticket', name: '彩票', kind: CategoryKind.income, note: '福彩、体彩'),
    PresetCategory(key: 'income_prize_contest', name: '比赛奖金', kind: CategoryKind.income, note: '马拉松、比赛获奖'),
  ]),
  PresetCategory(key: 'income_family', name: '家用', kind: CategoryKind.income, iconRef: 'family',
      note: '家人给的生活费、赡养费', children: [
    PresetCategory(key: 'income_family_living', name: '生活费', kind: CategoryKind.income, note: '父母给的生活费'),
    PresetCategory(key: 'income_family_support', name: '赡养费', kind: CategoryKind.income, note: '子女给父母的赡养费'),
    PresetCategory(key: 'income_family_education', name: '子女教育金', kind: CategoryKind.income, note: '给孩子的教育经费'),
  ]),
  PresetCategory(key: 'income_other', name: '其他', kind: CategoryKind.income, iconRef: 'other',
      note: '仅在无更贴切分类时使用', children: [
    PresetCategory(key: 'income_other_misc', name: '杂项收入', kind: CategoryKind.income, note: '说不清归哪类的小额进账'),
    PresetCategory(key: 'income_other_pending', name: '待归类', kind: CategoryKind.income, note: '先记下，回头再整理'),
  ]),
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
    void insertOne(PresetCategory cat, String? parentId, String? parentIconRef) {
      final id = 'preset_${cat.key}';
      // 二级继承父级图标（30 个一级 ↔ 30 枚图标）
      final iconRef = cat.iconRef.isNotEmpty ? cat.iconRef : (parentIconRef ?? 'other');
      db.raw.execute(
        'INSERT OR IGNORE INTO categories (id,parent_id,name,kind,icon_ref,note,sort_order,is_hidden,is_preset,created_at,updated_at,revision,device_id,base_revision) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
        [id, parentId, cat.name, cat.kind.wire, iconRef, cat.note, sortOrder, 0, 1, now.millisecondsSinceEpoch, now.millisecondsSinceEpoch, 1, deviceId, 0]);
      sortOrder += 10;
      for (final child in cat.children) {
        insertOne(child, id, iconRef);
      }
    }

    for (final cat in presetExpenseCategories) {
      insertOne(cat, null, null);
    }
    for (final cat in presetIncomeCategories) {
      insertOne(cat, null, null);
    }
  });
}

/// 老库补插**后加的**预设分类（种子只在空库跑，见文件头）。
///
/// 每次启动跑一遍，幂等：
/// · 按主键 `preset_<key>` **只插缺失的** —— 用户改过名 / 挪过分组 / 软删过的行
///   主键还在，直接跳过，绝不会"恢复出厂设置"；
/// · 新增项 `sort_order` 取「现有最大值 +10」递增追加，并把两侧的「其他」顶到最末，
///   保证它始终垫底；
/// · 顺带把几个预置的**兜底图标**升级成专属图标 —— 仅当用户没动过
///   （`icon_ref` 仍是 `other`）才改。
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

    void insertMissing(PresetCategory cat, String? parentId, String? parentIconRef) {
      final id = 'preset_${cat.key}';
      final iconRef = cat.iconRef.isNotEmpty ? cat.iconRef : (parentIconRef ?? 'other');
      final exists =
          db.raw.select('SELECT 1 FROM categories WHERE id = ?', [id]).isNotEmpty;
      if (!exists) {
        order += 10;
        // `OR IGNORE`：用户可能已经自建了同名分类（主键不同、名字相同）——
        // 撞 `uq_category_name` 时跳过就行，绝不能让一条约束把整个事务掀翻。
        db.raw.execute(
          'INSERT OR IGNORE INTO categories (id,parent_id,name,kind,icon_ref,note,sort_order,is_hidden,is_preset,created_at,updated_at,revision,device_id,base_revision) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
          [id, parentId, cat.name, cat.kind.wire, iconRef, cat.note, order, 0, 1, now, now, 1, deviceId, 0],
        );
      }
      for (final child in cat.children) {
        insertMissing(child, id, iconRef);
      }
    }

    // 2026-10-19：支出侧也加入补插（30 个一级是分批到的，老库只补缺的）
    for (final cat in presetExpenseCategories) {
      insertMissing(cat, null, null);
    }
    for (final cat in presetIncomeCategories) {
      insertMissing(cat, null, null);
    }
    // 「其他」永远垫底（新增项都是追加在它后面的）
    db.raw.execute(
      "UPDATE categories SET sort_order = ? WHERE id IN ('preset_income_other', 'preset_other')",
      [order + 10],
    );

    // 预置分类按**本文件的顺序**重新编号（2026-10-19 树重构）。
    // 老库里被提升的一级还带着当年做「二级」时的 sort_order、新增的 18 个一级
    // 又是追加在末尾 —— 不重排就是「错乱」的观感。只动 is_preset=1 的行，
    // 用户自建分类一律不动；用户行原本排在预置中间时，一次性整体后移（幂等）。
    var seq = 0;
    void place(PresetCategory cat) {
      seq += 10;
      db.raw.execute(
        'UPDATE categories SET sort_order = ? WHERE id = ? AND is_preset = 1',
        [seq, 'preset_${cat.key}'],
      );
      for (final child in cat.children) {
        place(child);
      }
    }

    for (final cat in presetExpenseCategories) {
      place(cat);
    }
    for (final cat in presetIncomeCategories) {
      place(cat);
    }
    final minUser = db.raw.select(
        'SELECT MIN(sort_order) AS m FROM categories WHERE is_preset = 0 AND deleted_at IS NULL');
    final minUserOrder = minUser.isEmpty ? null : minUser.first['m'] as int?;
    if (minUserOrder != null && minUserOrder < seq) {
      db.raw.execute(
          'UPDATE categories SET sort_order = sort_order + 100000 WHERE is_preset = 0');
    }
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
    // 2026-10-19：被提升为一级的那几个，图标 ref 还是当年的旧值，会与其它一级
    // 撞同一枚图标（如「书籍」的 `book` 与「学习」同图标）。只在用户没改过时换。
    const promotedIconUpgrades = <String, (String, String)>{
      'preset_study_book': ('book', 'library'),
      'preset_housing_water': ('utilities', 'electricity'),
    };
    promotedIconUpgrades.forEach((id, refs) {
      db.raw.execute(
        'UPDATE categories SET icon_ref = ? WHERE id = ? AND icon_ref = ?',
        [refs.$2, id, refs.$1],
      );
    });
  });
}
