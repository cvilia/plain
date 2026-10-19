/// 分类图标选择器的 **可选 ref 清单**（v3 图标集）。
///
/// ref → `PlainIconData` 的映射在 `category_icon_v3.dart`（`plainIconForRef`）：
/// v3 图标集共 100 枚（12 枚一级 + 88 枚 cat 细分，见 04-ICON-SYSTEM/svg）。
/// 近 300 个语义 ref 归并到最接近的一枚；同一枚图标可能对应多个 ref。
/// 本文件只回答「选择器里列出哪些 ref」，不持有任何图标几何，也不依赖字体。
library;

/// 全部可选分类图标 ref。
const List<String> kAllCategoryIconRefs = [
  // 餐饮
  'food', 'dining', 'coffee', 'tea', 'fastfood', 'cake', 'pizza', 'grocery',
  // 购物
  'shopping', 'mall', 'clothes', 'shoes', 'bag', 'gift', 'luxury',
  // 日用
  'daily', 'home_goods', 'cleaning', 'beauty', 'pet', 'baby', 'repair',
  // 交通
  'transport', 'bus', 'car', 'taxi', 'train', 'plane', 'bike', 'gas', 'parking',
  // 居住
  'housing', 'rent', 'utilities', 'furniture', 'internet',
  // 健康
  'medical', 'pharmacy', 'fitness', 'doctor', 'insurance',
  // 娱乐
  'entertainment', 'movie', 'music', 'game', 'sports', 'travel', 'hotel',
  // 学习
  'study', 'book', 'course', 'school', 'tech',
  // 通讯
  'telecom', 'phone', 'email', 'app',
  // 社交
  'social', 'party', 'wedding', 'donation', 'redpacket',
  // 财务
  'salary', 'bonus', 'invest', 'loan', 'tax', 'fee', 'interest', 'saving',
  // 其他
  'fruit', 'other', 'work', 'baby_care', 'elder', 'charity', 'subscription',
  // 扩展（更多生活/消费场景）
  'breakfast', 'lunch', 'dinner', 'takeout', 'bar', 'dessert', 'seafood',
  'makeup', 'haircut', 'laundry', 'tools', 'garden', 'stationery',
  'electricity', 'water', 'gas_bill', 'property_fee',
  'bus_card', 'highway', 'taxi_fee', 'flight_ticket',
  'movie_ticket', 'concert', 'museum', 'zoo', 'camping',
  'nursery', 'tuition', 'exam', 'library',
  'mobile_bill', 'broadband', 'cloud',
  'birthday', 'funeral', 'flowers',
  'freelance', 'dividend', 'rental_income', 'refund',
  'debt', 'credit_card_bill', 'installment',
  'gym', 'yoga', 'running', 'swimming',
  'coffee_shop', 'barber', 'spa',
  'toy', 'game_pad', 'music_note', 'headphone', 'camera', 'photo',
  'newspaper', 'podcast', 'video',
  'bus_stop', 'metro', 'ferry', 'motorcycle',
  'insurance_car', 'insurance_health', 'pension',
  'office', 'laptop', 'conference', 'coworking',
  'wallet', 'safe', 'chart', 'piggy',
  // 更多场景
  'beer', 'wine', 'cocktail', 'bottle', 'noodle', 'sushi', 'bbq', 'hotpot',
  'bread', 'milk', 'egg', 'meat', 'vegetable', 'snack', 'candy',
  'cosmetics', 'perfume', 'skincare', 'nail',
  'electrician', 'plumber', 'locksmith', 'mover',
  'sewing', 'knitting', 'craft',
  'umbrella', 'watch', 'jewelry', 'ring',
  'notebook', 'pen', 'printer', 'scanner',
  'router', 'sim', 'domain', 'hosting',
  'car_wash', 'car_repair', 'tire', 'oil',
  'subway_card', 'taxi_tip', 'toll_road',
  'night_hotel', 'airbnb', 'hostel',
  'theme_park', 'arcade', 'board_game', 'puzzle',
  'pet_food', 'vet', 'pet_toys',
  'baby_food', 'diaper', 'stroller', 'toy_blocks',
  'school_bus', 'textbook', 'stationery_set',
  'laptop_stand', 'mouse', 'keyboard', 'monitor', 'phone_case',
  'medal', 'trophy', 'cup',
  'love', 'kiss', 'date',
  'ticket', 'bus_ticket', 'train_ticket', 'ship_ticket',
  'passport', 'visa', 'luggage_tag',
  'electric_car', 'charging', 'bike_share',
  'movie_club', 'streaming', 'game_sub',
  'donate_blood', 'volunteer', 'community',
  'budget', 'invoice', 'receipt_scan', 'barcode',
  'cryptocurrency', 'gold', 'bond', 'fund',
  'retirement', 'education_fund', 'emergency_fund',
  'clean_house', 'deep_clean', 'pest_control',
  'photo_print', 'frame', 'souvenir',
  'recipe', 'cookbook', 'kitchen',
  'laundromat', 'dry_clean', 'shoe_repair',
  'auto_debit', 'bill_split', 'shared_expense',
  // 收入（v1.x 补）：收入分类的专属图标 —— 映射见 `category_icon_v3.dart`
  // 的「收入」段。`salary` / `bonus` / `invest` / `freelance` / `refund` /
  // `wallet` / `trophy` 本来就在上面的清单里，这里只补缺的。
  'parttime', 'business', 'reimburse', 'subsidy',
  'resale', 'prize', 'family',
  // 补：映射表里有、此前选择器里选不到的 ref
  'bandage',
  // 补：映射表里有、此前选择器里选不到的 ref
  'bed',
  // 补：映射表里有、此前选择器里选不到的 ref
  'bill',
  // 补：映射表里有、此前选择器里选不到的 ref
  'card',
  // 补：映射表里有、此前选择器里选不到的 ref
  'coins',
  // 补：映射表里有、此前选择器里选不到的 ref
  'couple',
  // 补：映射表里有、此前选择器里选不到的 ref
  'fun',
  // 补：映射表里有、此前选择器里选不到的 ref
  'health',
  // 补：映射表里有、此前选择器里选不到的 ref
  'heart',
  // 补：映射表里有、此前选择器里选不到的 ref
  'home',
  // 补：映射表里有、此前选择器里选不到的 ref
  'household',
  // 补：映射表里有、此前选择器里选不到的 ref
  'learn',
  // 补：映射表里有、此前选择器里选不到的 ref
  'market',
  // 补：映射表里有、此前选择器里选不到的 ref
  'meal',
  // 补：映射表里有、此前选择器里选不到的 ref
  'misc',
  // 补：映射表里有、此前选择器里选不到的 ref
  'streaming_alt',
  // 补：映射表里有、此前选择器里选不到的 ref
  'tv',
];

// 取图标请用 `category_icon_v3.dart` 的 `plainIconForRef(ref)`（或 `CategoryIcon`
// widget）—— 未收录的 ref 自动回落到「其他」。
