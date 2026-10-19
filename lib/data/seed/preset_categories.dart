/// Preset category seed data —— **本文件就是分类预设的唯一真值**。
///
/// ## 设计口径（2026-10-19 第二版：边界优先）
///
/// 上一版为了「凑够 30 个」把同一件事拆成了两个一级（学习 / 书籍阅读、
/// 餐饮 / 咖啡茶饮），并把「购物」当成了筐 —— 结果是一笔支出能放进三四个地方。
/// 本版按**互斥**重排，规则只有三条：
///
/// 1. **一个一级 = 一个生活场景**，不按「商品 / 服务」拆同一个场景；
/// 2. **二级名在整棵树里唯一**，跨一级也不许重名（测试会守）；
/// 3. **每条 note 都写「什么算、什么不算」**，边界写在数据里，不靠记。
///
/// 支出一级 30 个，每个都有专属图标、都有二级；收入一级 13 个，同样全员有二级。
/// 二级不写 `iconRef`，**继承父级图标** —— 30 枚图标对应 30 个一级。
///
/// · `seedPresetCategories` 只在空库跑；后加的预设由 `backfillPresetCategories` 补插。
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
///
/// 路径：吃 → 住 → 行 → 穿用 → 健康 → 成长 → 玩乐 → 通讯办公 → 家庭 → 财务 → 其他。
const List<PresetCategory> presetExpenseCategories = [
  // ───────────────────────── 吃 ─────────────────────────
  // 1
  PresetCategory(
      key: 'food',
      name: '餐饮',
      kind: CategoryKind.expense,
      iconRef: 'food',
      note: '在外吃、点外卖、现制饮品；买菜回家做记「食材」',
      children: [
        PresetCategory(
            key: 'food_breakfast',
            name: '早餐',
            kind: CategoryKind.expense,
            note: '上午 10 点前吃的一顿'),
        PresetCategory(
            key: 'food_lunch',
            name: '午餐',
            kind: CategoryKind.expense,
            note: '工作日的中饭、堂食'),
        PresetCategory(
            key: 'food_dinner',
            name: '晚餐',
            kind: CategoryKind.expense,
            note: '晚饭'),
        PresetCategory(
            key: 'food_night',
            name: '夜宵',
            kind: CategoryKind.expense,
            note: '晚饭之后的加餐'),
        PresetCategory(
            key: 'food_takeout',
            name: '外卖',
            kind: CategoryKind.expense,
            note: '配送费、打包费一并算餐费'),
        PresetCategory(
            key: 'food_cafe',
            name: '咖啡奶茶',
            kind: CategoryKind.expense,
            note: '现制饮品店：咖啡、奶茶、果茶、纯茶'),
        PresetCategory(
            key: 'food_snack',
            name: '零食',
            kind: CategoryKind.expense,
            note: '包装食品、坚果这类嘴馋开销'),
        PresetCategory(
            key: 'food_gathering',
            name: '聚餐',
            kind: CategoryKind.expense,
            note: '和朋友吃饭 AA 或自己买单；送礼性质的请客记「人情往来」'),
      ]),
  // 2
  PresetCategory(
      key: 'fruit',
      name: '食材',
      kind: CategoryKind.expense,
      iconRef: 'grocery',
      note: '买菜买肉买米，回家做；做好的饭记「餐饮」',
      children: [
        PresetCategory(
            key: 'fruit_veg',
            name: '蔬菜菌菇',
            kind: CategoryKind.expense,
            note: '蔬菜、菌菇、豆制品'),
        PresetCategory(
            key: 'fruit_fruit',
            name: '水果',
            kind: CategoryKind.expense,
            note: '水果、干果'),
        PresetCategory(
            key: 'fruit_meat',
            name: '肉禽蛋',
            kind: CategoryKind.expense,
            note: '猪牛羊肉、鸡鸭、蛋'),
        PresetCategory(
            key: 'fruit_seafood',
            name: '水产海鲜',
            kind: CategoryKind.expense,
            note: '鱼虾蟹贝'),
        PresetCategory(
            key: 'fruit_grain',
            name: '米面粮油',
            kind: CategoryKind.expense,
            note: '大米、面粉、食用油、杂粮'),
        PresetCategory(
            key: 'fruit_sauce',
            name: '调味品',
            kind: CategoryKind.expense,
            note: '盐糖酱醋、香料；保鲜膜等耗材记「日用」'),
        PresetCategory(
            key: 'fruit_frozen',
            name: '速冻半成品',
            kind: CategoryKind.expense,
            note: '速冻水饺、半成品菜'),
      ]),

  // ───────────────────────── 住 ─────────────────────────
  // 3
  PresetCategory(
      key: 'housing',
      name: '居住',
      kind: CategoryKind.expense,
      iconRef: 'housing',
      note: '住处的固定支出；水电燃气单列，保洁维修记「家政服务」',
      children: [
        PresetCategory(
            key: 'housing_rent',
            name: '房租',
            kind: CategoryKind.expense,
            note: '租房租金、押金'),
        PresetCategory(
            key: 'housing_mortgage',
            name: '房贷',
            kind: CategoryKind.expense,
            note: '按揭月供'),
        PresetCategory(
            key: 'housing_property',
            name: '物业费',
            kind: CategoryKind.expense,
            note: '物业费、公摊水电'),
        PresetCategory(
            key: 'housing_agent',
            name: '中介费',
            kind: CategoryKind.expense,
            note: '租房、买房的中介服务费'),
        PresetCategory(
            key: 'housing_moving',
            name: '搬家',
            kind: CategoryKind.expense,
            note: '搬家、仓储、临时寄存'),
      ]),
  // 4
  PresetCategory(
      key: 'housing_water',
      name: '水电燃气',
      kind: CategoryKind.expense,
      iconRef: 'electricity',
      note: '住处的公用事业费（按月账单）',
      children: [
        PresetCategory(
            key: 'utilities_electric',
            name: '电费',
            kind: CategoryKind.expense,
            note: '家庭用电'),
        PresetCategory(
            key: 'utilities_water',
            name: '水费',
            kind: CategoryKind.expense,
            note: '自来水、污水处理'),
        PresetCategory(
            key: 'utilities_gas',
            name: '燃气费',
            kind: CategoryKind.expense,
            note: '天然气、煤气'),
        PresetCategory(
            key: 'utilities_heating',
            name: '取暖费',
            kind: CategoryKind.expense,
            note: '集中供暖'),
        PresetCategory(
            key: 'utilities_waste',
            name: '垃圾处理费',
            kind: CategoryKind.expense,
            note: '垃圾清运、卫生费'),
      ]),
  // 5
  PresetCategory(
      key: 'shopping_home',
      name: '家居',
      kind: CategoryKind.expense,
      iconRef: 'furniture',
      note: '能用很久的耐用品；纸巾洗衣液等消耗品记「日用」',
      children: [
        PresetCategory(
            key: 'home_furniture',
            name: '家具',
            kind: CategoryKind.expense,
            note: '桌椅、床柜、沙发'),
        PresetCategory(
            key: 'home_textile',
            name: '家纺',
            kind: CategoryKind.expense,
            note: '床品、窗帘、地毯'),
        PresetCategory(
            key: 'home_kitchenware',
            name: '厨具',
            kind: CategoryKind.expense,
            note: '锅具、餐具、小厨电'),
        PresetCategory(
            key: 'home_appliance',
            name: '家电',
            kind: CategoryKind.expense,
            note: '冰箱、洗衣机、空调、电视'),
        PresetCategory(
            key: 'home_decor',
            name: '家饰绿植',
            kind: CategoryKind.expense,
            note: '摆件、挂画、绿植花盆'),
      ]),
  // 6
  PresetCategory(
      key: 'daily',
      name: '日用',
      kind: CategoryKind.expense,
      iconRef: 'daily',
      note: '用完就没了的东西；护肤彩妆记「美妆护肤」',
      children: [
        PresetCategory(
            key: 'daily_clean',
            name: '清洁纸品',
            kind: CategoryKind.expense,
            note: '纸巾、洗衣液、清洁剂、垃圾袋'),
        PresetCategory(
            key: 'daily_bath',
            name: '沐浴洗护',
            kind: CategoryKind.expense,
            note: '洗发水、沐浴露、牙膏牙刷；脸上的护肤记「美妆护肤」'),
        PresetCategory(
            key: 'daily_kitchen',
            name: '厨房耗材',
            kind: CategoryKind.expense,
            note: '保鲜膜、洗碗布、一次性餐具'),
        PresetCategory(
            key: 'daily_storage',
            name: '收纳用品',
            kind: CategoryKind.expense,
            note: '收纳盒、衣架、挂钩'),
        PresetCategory(
            key: 'daily_battery',
            name: '五金电池',
            kind: CategoryKind.expense,
            note: '电池、灯泡、螺丝、胶带'),
      ]),

  // ───────────────────────── 行 ─────────────────────────
  // 7
  PresetCategory(
      key: 'transport',
      name: '交通',
      kind: CategoryKind.expense,
      iconRef: 'transport',
      note: '出门坐车买票；自家的车加油保养记「汽车养护」',
      children: [
        PresetCategory(
            key: 'transport_bus',
            name: '公交地铁',
            kind: CategoryKind.expense,
            note: '公交、地铁、轮渡'),
        PresetCategory(
            key: 'transport_taxi',
            name: '打车',
            kind: CategoryKind.expense,
            note: '网约车、出租车、顺风车'),
        PresetCategory(
            key: 'transport_train',
            name: '火车高铁',
            kind: CategoryKind.expense,
            note: '火车、高铁、长途客运'),
        PresetCategory(
            key: 'transport_flight',
            name: '机票',
            kind: CategoryKind.expense,
            note: '国内国际航班、机建燃油'),
        PresetCategory(
            key: 'transport_park',
            name: '停车过路',
            kind: CategoryKind.expense,
            note: '停车费、高速过路费；违章罚款记「税费」'),
        PresetCategory(
            key: 'transport_bike',
            name: '共享单车',
            kind: CategoryKind.expense,
            note: '共享单车、共享电单车'),
        PresetCategory(
            key: 'transport_rent',
            name: '租车',
            kind: CategoryKind.expense,
            note: '租车、包车、代驾'),
      ]),
  // 8
  PresetCategory(
      key: 'auto',
      name: '汽车养护',
      kind: CategoryKind.expense,
      iconRef: 'car',
      note: '自己车的能源与养护；坐车买票记「交通」',
      children: [
        PresetCategory(
            key: 'auto_fuel',
            name: '加油',
            kind: CategoryKind.expense,
            note: '汽油、柴油'),
        PresetCategory(
            key: 'auto_charge',
            name: '充电',
            kind: CategoryKind.expense,
            note: '新能源充电桩、换电'),
        PresetCategory(
            key: 'auto_maintenance',
            name: '保养',
            kind: CategoryKind.expense,
            note: '小保养、大保养、轮胎'),
        PresetCategory(
            key: 'auto_repair',
            name: '维修',
            kind: CategoryKind.expense,
            note: '事故维修、换件、钣喷'),
        PresetCategory(
            key: 'auto_wash',
            name: '洗车美容',
            kind: CategoryKind.expense,
            note: '洗车、打蜡、内饰清洁'),
        PresetCategory(
            key: 'auto_inspection',
            name: '年检上牌',
            kind: CategoryKind.expense,
            note: '年检、上牌、车船税'),
      ]),

  // ───────────────────────── 穿与用 ─────────────────────────
  // 9
  PresetCategory(
      key: 'shopping_clothes',
      name: '服饰',
      kind: CategoryKind.expense,
      iconRef: 'clothes',
      note: '穿在身上、戴在身上的；孩子的童装记「育儿」',
      children: [
        PresetCategory(
            key: 'clothes_tops',
            name: '上衣裤装',
            kind: CategoryKind.expense,
            note: 'T 恤、衬衫、裤子、外套'),
        PresetCategory(
            key: 'clothes_shoes',
            name: '鞋靴',
            kind: CategoryKind.expense,
            note: '运动鞋、皮鞋、靴子'),
        PresetCategory(
            key: 'clothes_underwear',
            name: '内衣袜品',
            kind: CategoryKind.expense,
            note: '内衣、袜子、家居服'),
        PresetCategory(
            key: 'clothes_bag',
            name: '箱包',
            kind: CategoryKind.expense,
            note: '背包、行李箱、钱包'),
        PresetCategory(
            key: 'clothes_jewelry',
            name: '首饰手表',
            kind: CategoryKind.expense,
            note: '项链、戒指、耳饰、腕表'),
        PresetCategory(
            key: 'clothes_tailor',
            name: '改衣干洗',
            kind: CategoryKind.expense,
            note: '裁缝、改裤脚、干洗熨烫'),
      ]),
  // 10
  PresetCategory(
      key: 'shopping_beauty',
      name: '美妆护肤',
      kind: CategoryKind.expense,
      iconRef: 'cosmetics',
      note: '买回家的瓶瓶罐罐；剪发美甲记「美容美发」',
      children: [
        PresetCategory(
            key: 'beauty_skincare',
            name: '护肤',
            kind: CategoryKind.expense,
            note: '水乳面霜、精华、面膜'),
        PresetCategory(
            key: 'beauty_makeup',
            name: '彩妆',
            kind: CategoryKind.expense,
            note: '底妆、口红、眼妆'),
        PresetCategory(
            key: 'beauty_perfume',
            name: '香水香氛',
            kind: CategoryKind.expense,
            note: '香水、香薰、身体香氛'),
        PresetCategory(
            key: 'beauty_tools',
            name: '美妆工具',
            kind: CategoryKind.expense,
            note: '化妆刷、美妆蛋、修眉刀'),
      ]),
  // 11
  PresetCategory(
      key: 'beauty_service',
      name: '美容美发',
      kind: CategoryKind.expense,
      iconRef: 'haircut',
      note: '为形象花的服务费；买回家用的产品记「美妆护肤」',
      children: [
        PresetCategory(
            key: 'service_hair',
            name: '剪发烫染',
            kind: CategoryKind.expense,
            note: '理发、烫发、染发、接发'),
        PresetCategory(
            key: 'service_nail',
            name: '美甲',
            kind: CategoryKind.expense,
            note: '美甲、美睫、手足护理'),
        PresetCategory(
            key: 'service_spa',
            name: '美容 SPA',
            kind: CategoryKind.expense,
            note: '面部护理、身体 SPA、按摩'),
        PresetCategory(
            key: 'service_medical_beauty',
            name: '医美',
            kind: CategoryKind.expense,
            note: '注射、激光、整形；看病记「医疗健康」'),
      ]),
  // 12
  PresetCategory(
      key: 'shopping_digital',
      name: '数码',
      kind: CategoryKind.expense,
      iconRef: 'laptop',
      note: '电子产品与配件；软件订阅记「订阅会员」',
      children: [
        PresetCategory(
            key: 'digital_phone',
            name: '手机平板',
            kind: CategoryKind.expense,
            note: '手机整机、平板、手表'),
        PresetCategory(
            key: 'digital_computer',
            name: '电脑',
            kind: CategoryKind.expense,
            note: '笔记本、台式机、显示器'),
        PresetCategory(
            key: 'digital_accessory',
            name: '数码配件',
            kind: CategoryKind.expense,
            note: '数据线、充电头、键鼠、耳机、音箱'),
        PresetCategory(
            key: 'digital_smart',
            name: '智能设备',
            kind: CategoryKind.expense,
            note: '手环、智能家居、无人机'),
        PresetCategory(
            key: 'digital_repair',
            name: '数码维修',
            kind: CategoryKind.expense,
            note: '换屏、换电池、数据恢复'),
      ]),

  // ───────────────────────── 健康 ─────────────────────────
  // 13
  PresetCategory(
      key: 'medical',
      name: '医疗健康',
      kind: CategoryKind.expense,
      iconRef: 'medical',
      note: '看病、买药、保养身体；医美记「美容美发」',
      children: [
        PresetCategory(
            key: 'medical_drug',
            name: '药品',
            kind: CategoryKind.expense,
            note: '药店购药、常备药'),
        PresetCategory(
            key: 'medical_hospital',
            name: '门诊住院',
            kind: CategoryKind.expense,
            note: '挂号、门诊、住院、手术'),
        PresetCategory(
            key: 'medical_checkup',
            name: '体检',
            kind: CategoryKind.expense,
            note: '年度体检、专项检查'),
        PresetCategory(
            key: 'medical_dental',
            name: '牙科',
            kind: CategoryKind.expense,
            note: '洗牙、补牙、正畸'),
        PresetCategory(
            key: 'medical_glasses',
            name: '配镜',
            kind: CategoryKind.expense,
            note: '近视镜、隐形眼镜、护理液'),
        PresetCategory(
            key: 'medical_care',
            name: '康复理疗',
            kind: CategoryKind.expense,
            note: '推拿、针灸、康复训练；保健品记「药品」'),
      ]),
  // 14
  PresetCategory(
      key: 'insurance',
      name: '保险',
      kind: CategoryKind.expense,
      iconRef: 'umbrella',
      note: '交出去的保费；报销回来的钱记收入「补贴」',
      children: [
        PresetCategory(
            key: 'insurance_medical',
            name: '医疗险',
            kind: CategoryKind.expense,
            note: '百万医疗、门诊险'),
        PresetCategory(
            key: 'insurance_accident',
            name: '意外险',
            kind: CategoryKind.expense,
            note: '综合意外、旅行意外'),
        PresetCategory(
            key: 'insurance_life',
            name: '寿险重疾',
            kind: CategoryKind.expense,
            note: '定期寿险、重疾险'),
        PresetCategory(
            key: 'insurance_property',
            name: '财产险',
            kind: CategoryKind.expense,
            note: '家财险、车险、宠物险'),
      ]),
  // 15
  PresetCategory(
      key: 'ent_sport',
      name: '运动健身',
      kind: CategoryKind.expense,
      iconRef: 'sports',
      note: '为运动花的钱；日常穿的鞋记「服饰」',
      children: [
        PresetCategory(
            key: 'sport_gym',
            name: '健身卡私教',
            kind: CategoryKind.expense,
            note: '年卡、月卡、私教课'),
        PresetCategory(
            key: 'sport_field',
            name: '场馆费',
            kind: CategoryKind.expense,
            note: '球场、泳池、攀岩馆门票'),
        PresetCategory(
            key: 'sport_gear',
            name: '运动装备',
            kind: CategoryKind.expense,
            note: '球拍、护具、泳镜、骑行装备'),
        PresetCategory(
            key: 'sport_course',
            name: '运动课程',
            kind: CategoryKind.expense,
            note: '游泳课、瑜伽课、滑雪课'),
        PresetCategory(
            key: 'sport_outdoor',
            name: '户外运动',
            kind: CategoryKind.expense,
            note: '徒步、露营活动费；装备记「运动装备」'),
      ]),

  // ───────────────────────── 成长 ─────────────────────────
  // 16
  PresetCategory(
      key: 'study',
      name: '教育培训',
      kind: CategoryKind.expense,
      iconRef: 'study',
      note: '为上课、考证花的钱；买书报记「图书报刊」',
      children: [
        PresetCategory(
            key: 'study_course',
            name: '课程学费',
            kind: CategoryKind.expense,
            note: '培训班、网课、学历教育'),
        PresetCategory(
            key: 'study_exam',
            name: '考证报名',
            kind: CategoryKind.expense,
            note: '资格证、语言考试、报名费'),
        PresetCategory(
            key: 'study_training',
            name: '技能培训',
            kind: CategoryKind.expense,
            note: '线下工作坊、企业内训'),
        PresetCategory(
            key: 'study_online',
            name: '线上学习',
            kind: CategoryKind.expense,
            note: '题库、学习平台会员；影视音乐会员记「订阅会员」'),
      ]),
  // 17
  PresetCategory(
      key: 'study_book',
      name: '图书报刊',
      kind: CategoryKind.expense,
      iconRef: 'library',
      note: '买到手的出版物；课程培训记「教育培训」',
      children: [
        PresetCategory(
            key: 'book_paper',
            name: '纸质书',
            kind: CategoryKind.expense,
            note: '新书、二手书、教材'),
        PresetCategory(
            key: 'book_ebook',
            name: '电子书',
            kind: CategoryKind.expense,
            note: 'Kindle、阅读 App 购书'),
        PresetCategory(
            key: 'book_audio',
            name: '有声书',
            kind: CategoryKind.expense,
            note: '有声书、播客付费节目'),
        PresetCategory(
            key: 'book_magazine',
            name: '报刊杂志',
            kind: CategoryKind.expense,
            note: '期刊、报纸、年鉴'),
      ]),

  // ───────────────────────── 玩乐 ─────────────────────────
  // 18
  PresetCategory(
      key: 'entertainment',
      name: '娱乐',
      kind: CategoryKind.expense,
      iconRef: 'entertainment',
      note: '出门玩乐；游戏、旅行、运动已单列',
      children: [
        PresetCategory(
            key: 'ent_movie',
            name: '电影',
            kind: CategoryKind.expense,
            note: '电影票、影院卖品'),
        PresetCategory(
            key: 'ent_show',
            name: '演出展览',
            kind: CategoryKind.expense,
            note: '演唱会、话剧、音乐节、展览'),
        PresetCategory(
            key: 'ent_ktv',
            name: 'KTV',
            kind: CategoryKind.expense,
            note: 'KTV、Livehouse'),
        PresetCategory(
            key: 'ent_bar',
            name: '酒吧夜店',
            kind: CategoryKind.expense,
            note: '酒吧、清吧、夜店；买酒回家记「其他 · 杂项支出」'),
        PresetCategory(
            key: 'ent_boardgame',
            name: '桌游密室',
            kind: CategoryKind.expense,
            note: '桌游、剧本杀、密室逃脱'),
        PresetCategory(
            key: 'ent_internet',
            name: '网吧电竞',
            kind: CategoryKind.expense,
            note: '网吧、电竞馆、台球厅'),
      ]),
  // 19
  PresetCategory(
      key: 'ent_game',
      name: '游戏',
      kind: CategoryKind.expense,
      iconRef: 'game',
      note: '游戏内购与主机；影视会员记「订阅会员」',
      children: [
        PresetCategory(
            key: 'game_recharge',
            name: '游戏充值',
            kind: CategoryKind.expense,
            note: '点券、钻石、金币'),
        PresetCategory(
            key: 'game_sub',
            name: '月卡通行证',
            kind: CategoryKind.expense,
            note: '游戏内月卡、战令、通行证'),
        PresetCategory(
            key: 'game_item',
            name: '道具皮肤',
            kind: CategoryKind.expense,
            note: '皮肤、道具、抽卡'),
        PresetCategory(
            key: 'game_console',
            name: '主机卡带',
            kind: CategoryKind.expense,
            note: '游戏主机、卡带、手柄'),
      ]),
  // 20
  PresetCategory(
      key: 'ent_travel',
      name: '旅行',
      kind: CategoryKind.expense,
      iconRef: 'travel',
      note: '出门在外的住宿门票；车票机票记「交通」',
      children: [
        PresetCategory(
            key: 'travel_hotel',
            name: '住宿',
            kind: CategoryKind.expense,
            note: '酒店、民宿、青旅'),
        PresetCategory(
            key: 'travel_ticket',
            name: '景点门票',
            kind: CategoryKind.expense,
            note: '景区、乐园、博物馆门票'),
        PresetCategory(
            key: 'travel_package',
            name: '跟团游',
            kind: CategoryKind.expense,
            note: '旅行团、机酒套餐'),
        PresetCategory(
            key: 'travel_visa',
            name: '签证证件',
            kind: CategoryKind.expense,
            note: '签证、通行证、护照'),
        PresetCategory(
            key: 'travel_camping',
            name: '露营营地',
            kind: CategoryKind.expense,
            note: '营地费、营位预订；装备记「运动装备」'),
      ]),
  // 21
  PresetCategory(
      key: 'subscription',
      name: '订阅会员',
      kind: CategoryKind.expense,
      iconRef: 'tv',
      note: '按月/按年自动续费的会员；游戏内购记「游戏」',
      children: [
        PresetCategory(
            key: 'sub_video',
            name: '视频会员',
            kind: CategoryKind.expense,
            note: '长视频、影视平台、电视端会员'),
        PresetCategory(
            key: 'sub_music',
            name: '音乐会员',
            kind: CategoryKind.expense,
            note: '音乐、播客、有声书平台'),
        PresetCategory(
            key: 'sub_cloud',
            name: '云存储',
            kind: CategoryKind.expense,
            note: '网盘、相册扩容、备份服务'),
        PresetCategory(
            key: 'sub_software',
            name: '软件订阅',
            kind: CategoryKind.expense,
            note: '工具类 App、设计软件、办公套件'),
      ]),

  // ───────────────────────── 通讯办公 ─────────────────────────
  // 22
  PresetCategory(
      key: 'telecom',
      name: '通讯',
      kind: CategoryKind.expense,
      iconRef: 'telecom',
      note: '手机与网络的固定支出',
      children: [
        PresetCategory(
            key: 'telecom_phone',
            name: '话费套餐',
            kind: CategoryKind.expense,
            note: '手机月租、套餐费'),
        PresetCategory(
            key: 'telecom_net',
            name: '宽带网费',
            kind: CategoryKind.expense,
            note: '家庭宽带、随身 WiFi'),
        PresetCategory(
            key: 'telecom_data',
            name: '流量包',
            kind: CategoryKind.expense,
            note: '流量加油包、日租卡'),
        PresetCategory(
            key: 'telecom_tv',
            name: '有线电视',
            kind: CategoryKind.expense,
            note: '广电基本收视费；点播会员记「订阅会员」'),
      ]),
  // 23
  PresetCategory(
      key: 'office',
      name: '办公文印',
      kind: CategoryKind.expense,
      iconRef: 'printer',
      note: '办公消耗与寄递；软件订阅记「订阅会员」',
      children: [
        PresetCategory(
            key: 'office_supplies',
            name: '办公用品',
            kind: CategoryKind.expense,
            note: '文具、纸张、打印耗材'),
        PresetCategory(
            key: 'office_print',
            name: '打印复印',
            kind: CategoryKind.expense,
            note: '打印、复印、装订'),
        PresetCategory(
            key: 'office_shipping',
            name: '快递物流',
            kind: CategoryKind.expense,
            note: '寄件、退货运费、同城配送'),
        PresetCategory(
            key: 'office_card',
            name: '名片工牌',
            kind: CategoryKind.expense,
            note: '名片、工牌、宣传物料'),
      ]),

  // ───────────────────────── 家庭 ─────────────────────────
  // 24
  PresetCategory(
      key: 'housekeeping',
      name: '家政服务',
      kind: CategoryKind.expense,
      iconRef: 'cleaning',
      note: '花钱请人上门干活；房租物业记「居住」',
      children: [
        PresetCategory(
            key: 'house_clean',
            name: '日常保洁',
            kind: CategoryKind.expense,
            note: '钟点工、定期保洁'),
        PresetCategory(
            key: 'house_deepclean',
            name: '深度保洁',
            kind: CategoryKind.expense,
            note: '开荒保洁、除螨、消毒'),
        PresetCategory(
            key: 'house_appliance_clean',
            name: '家电清洗',
            kind: CategoryKind.expense,
            note: '油烟机、空调、洗衣机清洗'),
        PresetCategory(
            key: 'house_repair',
            name: '上门维修',
            kind: CategoryKind.expense,
            note: '水电、门窗、管道维修；数码产品记「数码」'),
        PresetCategory(
            key: 'house_hourly',
            name: '钟点工',
            kind: CategoryKind.expense,
            note: '临时帮工、搬运、代跑腿'),
      ]),
  // 25
  PresetCategory(
      key: 'baby',
      name: '育儿',
      kind: CategoryKind.expense,
      iconRef: 'baby',
      note: '孩子的开销；大人的东西按品类记',
      children: [
        PresetCategory(
            key: 'baby_food',
            name: '奶粉辅食',
            kind: CategoryKind.expense,
            note: '奶粉、米粉、辅食'),
        PresetCategory(
            key: 'baby_diaper',
            name: '纸尿裤湿巾',
            kind: CategoryKind.expense,
            note: '纸尿裤、拉拉裤、湿巾'),
        PresetCategory(
            key: 'baby_clothes',
            name: '童装童鞋',
            kind: CategoryKind.expense,
            note: '孩子的衣服、鞋袜'),
        PresetCategory(
            key: 'baby_toy',
            name: '玩具绘本',
            kind: CategoryKind.expense,
            note: '玩具、绘本、早教玩具；课程记「教育培训」'),
        PresetCategory(
            key: 'baby_care',
            name: '托育保姆',
            kind: CategoryKind.expense,
            note: '托班、月嫂、育儿嫂'),
      ]),
  // 26
  PresetCategory(
      key: 'pet',
      name: '宠物',
      kind: CategoryKind.expense,
      iconRef: 'pet',
      note: '养宠开销；给自己买的东西记各自品类',
      children: [
        PresetCategory(
            key: 'pet_food',
            name: '主粮零食',
            kind: CategoryKind.expense,
            note: '主粮、罐头、冻干'),
        PresetCategory(
            key: 'pet_vet',
            name: '医疗疫苗',
            kind: CategoryKind.expense,
            note: '看病、疫苗、驱虫、绝育'),
        PresetCategory(
            key: 'pet_grooming',
            name: '洗护寄养',
            kind: CategoryKind.expense,
            note: '洗澡、剪毛、寄养、遛狗'),
        PresetCategory(
            key: 'pet_supplies',
            name: '用品玩具',
            kind: CategoryKind.expense,
            note: '猫砂、牵引绳、窝、玩具'),
      ]),
  // 27
  PresetCategory(
      key: 'social',
      name: '人情往来',
      kind: CategoryKind.expense,
      iconRef: 'social',
      note: '花在别人身上的钱；自己吃饭记「餐饮」',
      children: [
        PresetCategory(
            key: 'social_gift',
            name: '礼物',
            kind: CategoryKind.expense,
            note: '送出去的礼物、伴手礼'),
        PresetCategory(
            key: 'social_red',
            name: '红包份子',
            kind: CategoryKind.expense,
            note: '份子钱、压岁钱、微信红包'),
        PresetCategory(
            key: 'social_party',
            name: '代付请客',
            kind: CategoryKind.expense,
            note: '替别人付的账、请客送礼'),
        PresetCategory(
            key: 'social_elder',
            name: '孝敬长辈',
            kind: CategoryKind.expense,
            note: '给父母的生活费、礼品'),
        PresetCategory(
            key: 'social_donate',
            name: '公益捐赠',
            kind: CategoryKind.expense,
            note: '捐款、义卖、众筹'),
      ]),

  // ───────────────────────── 财务 ─────────────────────────
  // 28
  PresetCategory(
      key: 'tax',
      name: '税费',
      kind: CategoryKind.expense,
      iconRef: 'bill',
      note: '交给政府/平台的强制性支出',
      children: [
        PresetCategory(
            key: 'tax_income',
            name: '个人所得税',
            kind: CategoryKind.expense,
            note: '年度汇算补税'),
        PresetCategory(
            key: 'tax_vehicle',
            name: '车船购置税',
            kind: CategoryKind.expense,
            note: '车船税、车辆购置税'),
        PresetCategory(
            key: 'tax_property',
            name: '房产税费',
            kind: CategoryKind.expense,
            note: '契税、房产税'),
        PresetCategory(
            key: 'tax_fine',
            name: '罚没滞纳金',
            kind: CategoryKind.expense,
            note: '交通违章罚款、滞纳金'),
      ]),
  // 29
  PresetCategory(
      key: 'fee',
      name: '手续费',
      kind: CategoryKind.expense,
      iconRef: 'percent',
      note: '金融机构与平台收的服务费',
      children: [
        PresetCategory(
            key: 'fee_withdraw',
            name: '提现转账费',
            kind: CategoryKind.expense,
            note: '提现、跨行转账、外汇兑换'),
        PresetCategory(
            key: 'fee_service',
            name: '平台服务费',
            kind: CategoryKind.expense,
            note: '电商、外卖、票务平台佣金'),
        PresetCategory(
            key: 'fee_interest',
            name: '利息支出',
            kind: CategoryKind.expense,
            note: '信用卡分期、消费贷利息'),
        PresetCategory(
            key: 'fee_annual',
            name: '账户年费',
            kind: CategoryKind.expense,
            note: '银行卡年费、账户管理费'),
      ]),
  // 30（必须垫底：删分类时的兜底目标）
  PresetCategory(
      key: 'other',
      name: '其他',
      kind: CategoryKind.expense,
      iconRef: 'other',
      note: '确实找不到归属时才用',
      children: [
        PresetCategory(
            key: 'other_misc',
            name: '杂项支出',
            kind: CategoryKind.expense,
            note: '说不清归哪类的小额支出'),
        PresetCategory(
            key: 'other_pending',
            name: '待归类',
            kind: CategoryKind.expense,
            note: '先记下，回头再整理'),
      ]),
];

/// 收入预设（13 个一级，**每个一级都有二级**）。
///
/// 口径：每条收入都要能被归类。二级之间同样互斥：
/// 「奖金」只装**公司内部**的激励，「中奖」只装**外部**的抽奖/比赛，
/// 「理财」只装**钱生钱**的收益（本金进出不算收入）。
///
/// ⚠️ `其他`（`income_other`）必须**留在最后**，且 id 不能改。
const List<PresetCategory> presetIncomeCategories = [
  PresetCategory(
      key: 'income_salary',
      name: '工资',
      kind: CategoryKind.income,
      iconRef: 'salary',
      note: '每月固定薪酬；一次性激励记「奖金」',
      children: [
        PresetCategory(
            key: 'income_base',
            name: '基本工资',
            kind: CategoryKind.income,
            note: '税后到手的基本薪酬'),
        PresetCategory(
            key: 'income_overtime',
            name: '加班费',
            kind: CategoryKind.income,
            note: '加班费、值班补贴'),
        PresetCategory(
            key: 'income_attendance',
            name: '全勤奖',
            kind: CategoryKind.income,
            note: '月度全勤、考勤奖励'),
        PresetCategory(
            key: 'income_performance',
            name: '绩效工资',
            kind: CategoryKind.income,
            note: '月度/季度绩效'),
      ]),
  PresetCategory(
      key: 'income_bonus',
      name: '奖金',
      kind: CategoryKind.income,
      iconRef: 'bonus',
      note: '公司发的激励；外部比赛获奖记「中奖」',
      children: [
        PresetCategory(
            key: 'income_year_end',
            name: '年终奖',
            kind: CategoryKind.income,
            note: '年度奖金、十三薪'),
        PresetCategory(
            key: 'income_project',
            name: '项目奖',
            kind: CategoryKind.income,
            note: '项目完结发的一次性奖'),
        PresetCategory(
            key: 'income_commission',
            name: '提成',
            kind: CategoryKind.income,
            note: '销售提成、业务提成'),
        PresetCategory(
            key: 'income_contest',
            name: '评优奖励',
            kind: CategoryKind.income,
            note: '公司内部评优、优秀员工'),
      ]),
  PresetCategory(
      key: 'income_invest',
      name: '理财',
      kind: CategoryKind.income,
      iconRef: 'invest',
      note: '钱生钱的部分；本金进出不算收入',
      children: [
        PresetCategory(
            key: 'income_interest',
            name: '利息',
            kind: CategoryKind.income,
            note: '存款、货币基金利息'),
        PresetCategory(
            key: 'income_invest_return',
            name: '投资理财收益',
            kind: CategoryKind.income,
            note: '基金、股票、理财赎回的已实现收益'),
        PresetCategory(
            key: 'income_dividend',
            name: '分红',
            kind: CategoryKind.income,
            note: '股息、股东分红'),
      ]),
  PresetCategory(
      key: 'income_parttime',
      name: '兼职',
      kind: CategoryKind.income,
      iconRef: 'parttime',
      note: '本职之外的零散进账；成规模的生意记「经营」',
      children: [
        PresetCategory(
            key: 'income_royalty',
            name: '稿费版权',
            kind: CategoryKind.income,
            note: '稿酬、版权、课程分成'),
        PresetCategory(
            key: 'income_freelance',
            name: '外包接单',
            kind: CategoryKind.income,
            note: '设计、开发、咨询等私活'),
        PresetCategory(
            key: 'income_tutoring',
            name: '家教辅导',
            kind: CategoryKind.income,
            note: '家教、代课、课后辅导'),
        PresetCategory(
            key: 'income_streaming',
            name: '直播打赏',
            kind: CategoryKind.income,
            note: '直播、自媒体打赏分成'),
      ]),
  PresetCategory(
      key: 'income_business',
      name: '经营',
      kind: CategoryKind.income,
      iconRef: 'business',
      note: '以经营主体的名义入账；个人打零工记「兼职」',
      children: [
        PresetCategory(
            key: 'income_revenue',
            name: '营业收入',
            kind: CategoryKind.income,
            note: '店铺、项目结算的净收入'),
        PresetCategory(
            key: 'income_affiliate',
            name: '带货佣金',
            kind: CategoryKind.income,
            note: '直播、分销、联盟返佣'),
        PresetCategory(
            key: 'income_service_fee',
            name: '服务收入',
            kind: CategoryKind.income,
            note: '咨询、代运营等对公服务费'),
      ]),
  PresetCategory(
      key: 'income_reimburse',
      name: '报销',
      kind: CategoryKind.income,
      iconRef: 'reimburse',
      note: '仅用于没有对应账单的补贴类回款',
      children: [
        PresetCategory(
            key: 'income_reimburse_travel',
            name: '差旅报销',
            kind: CategoryKind.income,
            note: '出差交通住宿回款'),
        PresetCategory(
            key: 'income_reimburse_meal',
            name: '餐费报销',
            kind: CategoryKind.income,
            note: '业务招待、加班餐'),
        PresetCategory(
            key: 'income_reimburse_purchase',
            name: '采购报销',
            kind: CategoryKind.income,
            note: '垫付办公采购'),
        PresetCategory(
            key: 'income_reimburse_other',
            name: '其他报销',
            kind: CategoryKind.income,
            note: '说不清类别的回款'),
      ]),
  PresetCategory(
      key: 'income_redpacket',
      name: '红包',
      kind: CategoryKind.income,
      iconRef: 'redpacket',
      note: '亲友给的红包、压岁钱、礼金',
      children: [
        PresetCategory(
            key: 'income_rp_friend',
            name: '亲友红包',
            kind: CategoryKind.income,
            note: '微信/支付宝收到的红包'),
        PresetCategory(
            key: 'income_rp_newyear',
            name: '压岁钱',
            kind: CategoryKind.income,
            note: '春节压岁钱'),
        PresetCategory(
            key: 'income_rp_gift',
            name: '礼金',
            kind: CategoryKind.income,
            note: '婚丧嫁娶收到的礼金'),
      ]),
  PresetCategory(
      key: 'income_subsidy',
      name: '补贴',
      kind: CategoryKind.income,
      iconRef: 'subsidy',
      note: '单位/政策给的补助；报销回款记「报销」',
      children: [
        PresetCategory(
            key: 'income_housing_fund',
            name: '公积金',
            kind: CategoryKind.income,
            note: '单位缴存 + 提取到账'),
        PresetCategory(
            key: 'income_social_insurance',
            name: '社保返还',
            kind: CategoryKind.income,
            note: '医保报销、失业金'),
        PresetCategory(
            key: 'income_meal_allowance',
            name: '交通餐补',
            kind: CategoryKind.income,
            note: '车补、餐补、话费补贴'),
        PresetCategory(
            key: 'income_housing_allowance',
            name: '住房补贴',
            kind: CategoryKind.income,
            note: '租房补贴、安家费'),
        PresetCategory(
            key: 'income_maternity',
            name: '生育津贴',
            kind: CategoryKind.income,
            note: '生育医疗费、产假津贴'),
      ]),
  PresetCategory(
      key: 'income_refund',
      name: '退款',
      kind: CategoryKind.income,
      iconRef: 'refund',
      note: '把花出去的钱要回来',
      children: [
        PresetCategory(
            key: 'income_refund_shopping',
            name: '购物退款',
            kind: CategoryKind.income,
            note: '退货、取消订单'),
        PresetCategory(
            key: 'income_refund_platform',
            name: '平台赔付',
            kind: CategoryKind.income,
            note: '超时赔付、破损赔付'),
        PresetCategory(
            key: 'income_refund_service',
            name: '服务退款',
            kind: CategoryKind.income,
            note: '会员、课程、票务退款'),
      ]),
  PresetCategory(
      key: 'income_resale',
      name: '变卖',
      kind: CategoryKind.income,
      iconRef: 'resale',
      note: '卖闲置换钱',
      children: [
        PresetCategory(
            key: 'income_resale_secondhand',
            name: '二手转让',
            kind: CategoryKind.income,
            note: '闲鱼、转转成交'),
        PresetCategory(
            key: 'income_resale_idle',
            name: '闲置出售',
            kind: CategoryKind.income,
            note: '家具家电等闲置'),
        PresetCategory(
            key: 'income_resale_scrap',
            name: '废品回收',
            kind: CategoryKind.income,
            note: '旧书旧纸、废金属'),
      ]),
  PresetCategory(
      key: 'income_prize',
      name: '中奖',
      kind: CategoryKind.income,
      iconRef: 'prize',
      note: '外部抽奖与比赛；公司发的记「奖金」',
      children: [
        PresetCategory(
            key: 'income_prize_lottery',
            name: '抽奖',
            kind: CategoryKind.income,
            note: '平台抽奖、锦鲤'),
        PresetCategory(
            key: 'income_prize_ticket',
            name: '彩票',
            kind: CategoryKind.income,
            note: '福彩、体彩'),
        PresetCategory(
            key: 'income_prize_contest',
            name: '竞赛获奖',
            kind: CategoryKind.income,
            note: '马拉松、公开赛、征文比赛'),
      ]),
  PresetCategory(
      key: 'income_family',
      name: '家用',
      kind: CategoryKind.income,
      iconRef: 'family',
      note: '家人给的生活费、赡养费',
      children: [
        PresetCategory(
            key: 'income_family_living',
            name: '生活费',
            kind: CategoryKind.income,
            note: '父母给的生活费'),
        PresetCategory(
            key: 'income_family_support',
            name: '赡养费',
            kind: CategoryKind.income,
            note: '子女给父母的赡养费'),
        PresetCategory(
            key: 'income_family_education',
            name: '子女教育金',
            kind: CategoryKind.income,
            note: '给孩子的教育经费'),
      ]),
  PresetCategory(
      key: 'income_other',
      name: '其他',
      kind: CategoryKind.income,
      iconRef: 'other',
      note: '确实找不到归属时才用',
      children: [
        PresetCategory(
            key: 'income_other_misc',
            name: '杂项收入',
            kind: CategoryKind.income,
            note: '说不清归哪类的小额进账'),
        PresetCategory(
            key: 'income_other_pending',
            name: '待归类',
            kind: CategoryKind.income,
            note: '先记下，回头再整理'),
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

/// 补插**后加的**预设分类（种子只在空库跑，见文件头）。
///
/// 每次启动跑一遍，幂等：按主键 `preset_<key>` 只插缺失的 —— 用户改过名 /
/// 挪过分组 / 软删过的行主键还在，直接跳过，绝不会「恢复出厂设置」。
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

    for (final cat in presetExpenseCategories) {
      insertMissing(cat, null, null);
    }
    for (final cat in presetIncomeCategories) {
      insertMissing(cat, null, null);
    }

    // 预置分类按**本文件的顺序**编号（分类目录即唯一的排序真值）。
    // 只动 is_preset=1 的行；用户自建分类一律不挪，若原本混在预置中间，
    // 一次性整体后移（幂等）。
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
  });
}
