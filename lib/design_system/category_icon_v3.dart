/// Quiet Ledger category icons: map iconRef → PlainIconData (new SVG set)
/// with category ink colors. Falls back to null for unknown/legacy refs.
library;

import 'package:flutter/material.dart';
import 'package:plain/app/theme/theme_registry.dart';
import 'package:plain/design_system/plain_icons_v3.dart';

/// iconRef → v3 SVG 图标。
///
/// ⚠️ **这里的键是语义 ref（近 300 个），值只有 100 枚图标 —— 映射是多对一。**
///
/// 2026-10-19 扩建：此前只有 12 枚 `cat*` 一级图标，于是「咖啡」和「火锅」
/// 长得一模一样（都落到 `catFood`）。自定义图标上传下线后，可选图标必须
/// 自己够用，故图标库扩到 100 枚（`ic_cat_*`），这里同步把每个 ref 重新
/// 指到最贴近的那一枚。
///
/// **新增 ref 的规矩**：先确认 `ic_cat_*` 里有没有语义合适的图标；
/// 没有才复用最接近的（比如下面 `pizza` → `catFastfood`），
/// 并在 `category_icons.dart` 的清单里补上这个 ref。
const Map<String, PlainIconData> kCategoryPlainIcons = {
  // ── 餐饮 ────────────────────────────────────────────────────────────
  'food': PlainIconData.catFood,
  'dining': PlainIconData.catFood,
  'meal': PlainIconData.catFood,
  'breakfast': PlainIconData.catFood,
  'lunch': PlainIconData.catFood,
  'dinner': PlainIconData.catFood,
  'takeout': PlainIconData.catTakeout,
  'fastfood': PlainIconData.catFastfood,
  'pizza': PlainIconData.catFastfood,
  'bbq': PlainIconData.catFastfood,
  'noodle': PlainIconData.catNoodle,
  'sushi': PlainIconData.catSushi,
  'hotpot': PlainIconData.catHotpot,
  'coffee': PlainIconData.catCoffee,
  'coffee_shop': PlainIconData.catCoffee,
  'milk': PlainIconData.catCoffee,
  'tea': PlainIconData.catTea,
  'bar': PlainIconData.catBeer,
  'beer': PlainIconData.catBeer,
  'wine': PlainIconData.catWine,
  'cocktail': PlainIconData.catWine,
  'dessert': PlainIconData.catCake,
  'cake': PlainIconData.catCake,
  'bread': PlainIconData.catBread,
  'snack': PlainIconData.catBread,
  'candy': PlainIconData.catBread,
  // ── 食材 ────────────────────────────────────────────────────────────
  'grocery': PlainIconData.catGrocery,
  'market': PlainIconData.catGrocery,
  'recipe': PlainIconData.catGrocery,
  'cookbook': PlainIconData.catGrocery,
  'kitchen': PlainIconData.catGrocery,
  'egg': PlainIconData.catGrocery,
  'fruit': PlainIconData.catFruit,
  'vegetable': PlainIconData.catVegetable,
  'seafood': PlainIconData.catSeafood,
  'meat': PlainIconData.catMeat,
  // ── 购物 ────────────────────────────────────────────────────────────
  'shopping': PlainIconData.catShopping,
  'toy': PlainIconData.catShopping,
  'toy_blocks': PlainIconData.catShopping,
  'bag': PlainIconData.catBag,
  'souvenir': PlainIconData.catBag,
  'mall': PlainIconData.catMall,
  'clothes': PlainIconData.catClothes,
  'shoes': PlainIconData.catShoes,
  'shoe_repair': PlainIconData.catShoes,
  'cosmetics': PlainIconData.catCosmetics,
  'makeup': PlainIconData.catCosmetics,
  'skincare': PlainIconData.catCosmetics,
  'perfume': PlainIconData.catPerfume,
  'watch': PlainIconData.catWatch,
  'luxury': PlainIconData.catJewelry,
  'jewelry': PlainIconData.catJewelry,
  'ring': PlainIconData.catJewelry,
  'umbrella': PlainIconData.catUmbrella,
  'gift': PlainIconData.gift,
  // ── 日用 ────────────────────────────────────────────────────────────
  'daily': PlainIconData.catDaily,
  'household': PlainIconData.catDaily,
  'home_goods': PlainIconData.catDaily,
  'bottle': PlainIconData.catDaily,
  'cleaning': PlainIconData.catCleaning,
  'clean_house': PlainIconData.catCleaning,
  'deep_clean': PlainIconData.catCleaning,
  'pest_control': PlainIconData.catCleaning,
  'laundry': PlainIconData.catLaundry,
  'laundromat': PlainIconData.catLaundry,
  'dry_clean': PlainIconData.catLaundry,
  'beauty': PlainIconData.catBeauty,
  'spa': PlainIconData.catBeauty,
  'haircut': PlainIconData.catHaircut,
  'barber': PlainIconData.catHaircut,
  'nail': PlainIconData.catHaircut,
  'pet': PlainIconData.catPet,
  'pet_food': PlainIconData.catPet,
  'pet_toys': PlainIconData.catPet,
  'vet': PlainIconData.catPet,
  'baby': PlainIconData.catBaby,
  'baby_care': PlainIconData.catBaby,
  'baby_food': PlainIconData.catBaby,
  'diaper': PlainIconData.catBaby,
  'stroller': PlainIconData.catBaby,
  'nursery': PlainIconData.catBaby,
  'tools': PlainIconData.catTools,
  'repair': PlainIconData.catTools,
  'garden': PlainIconData.catTools,
  'sewing': PlainIconData.catTools,
  'knitting': PlainIconData.catTools,
  'craft': PlainIconData.catTools,
  'electrician': PlainIconData.catTools,
  'plumber': PlainIconData.catTools,
  'locksmith': PlainIconData.catTools,
  'mover': PlainIconData.catBox,
  'furniture': PlainIconData.catFurniture,
  'stationery': PlainIconData.catExam,
  'notebook': PlainIconData.catExam,
  'pen': PlainIconData.catExam,
  // ── 交通 ────────────────────────────────────────────────────────────
  'transport': PlainIconData.catTransport,
  'bus': PlainIconData.catTransport,
  'bus_card': PlainIconData.catTransport,
  'bus_stop': PlainIconData.catTransport,
  'bus_ticket': PlainIconData.catTransport,
  'metro': PlainIconData.catTransport,
  'subway_card': PlainIconData.catTransport,
  'car': PlainIconData.catCar,
  'electric_car': PlainIconData.catCar,
  'car_wash': PlainIconData.catCar,
  'car_repair': PlainIconData.catCar,
  'tire': PlainIconData.catCar,
  'insurance_car': PlainIconData.catCar,
  'taxi': PlainIconData.catTaxi,
  'taxi_fee': PlainIconData.catTaxi,
  'taxi_tip': PlainIconData.catTaxi,
  'train': PlainIconData.catTrain,
  'train_ticket': PlainIconData.catTrain,
  'highway': PlainIconData.catTrain,
  'plane': PlainIconData.catPlane,
  'flight_ticket': PlainIconData.catPlane,
  'bike': PlainIconData.catBike,
  'bike_share': PlainIconData.catBike,
  'motorcycle': PlainIconData.catBike,
  'gas': PlainIconData.catGas,
  'oil': PlainIconData.catGas,
  'charging': PlainIconData.catCharging,
  'parking': PlainIconData.catParking,
  'toll_road': PlainIconData.catParking,
  'ferry': PlainIconData.catShip,
  'ship_ticket': PlainIconData.catShip,
  'passport': PlainIconData.catTravel,
  'visa': PlainIconData.catTravel,
  'luggage_tag': PlainIconData.catTravel,
  // ── 居住 ────────────────────────────────────────────────────────────
  'housing': PlainIconData.catHousing,
  'home': PlainIconData.catHousing,
  'rent': PlainIconData.catRent,
  'rental_income': PlainIconData.catRent,
  'utilities': PlainIconData.catElectricity,
  'electricity': PlainIconData.catElectricity,
  'property_fee': PlainIconData.catElectricity,
  'water': PlainIconData.catWater,
  'gas_bill': PlainIconData.catWater,
  'internet': PlainIconData.catWifi,
  'broadband': PlainIconData.catWifi,
  'bed': PlainIconData.catBed,
  'hotel': PlainIconData.catHotel,
  'night_hotel': PlainIconData.catHotel,
  'airbnb': PlainIconData.catHotel,
  'hostel': PlainIconData.catHotel,
  // ── 通讯 ────────────────────────────────────────────────────────────
  'telecom': PlainIconData.catTelecom,
  'phone': PlainIconData.catTelecom,
  'phone_case': PlainIconData.catTelecom,
  'mobile_bill': PlainIconData.catTelecom,
  'app': PlainIconData.catTelecom,
  'cloud': PlainIconData.catTelecom,
  'sim': PlainIconData.catSim,
  'email': PlainIconData.catEmail,
  'router': PlainIconData.catRouter,
  'domain': PlainIconData.catRouter,
  'hosting': PlainIconData.catRouter,
  // ── 娱乐 ────────────────────────────────────────────────────────────
  'entertainment': PlainIconData.catEntertainment,
  'fun': PlainIconData.catEntertainment,
  'movie': PlainIconData.catMovie,
  'movie_ticket': PlainIconData.catMovie,
  'ticket': PlainIconData.catTicket,
  'movie_club': PlainIconData.catMovie,
  'streaming': PlainIconData.catMovie,
  'streaming_alt': PlainIconData.catMovie,
  'video': PlainIconData.catTv,
  'tv': PlainIconData.catTv,
  'music': PlainIconData.catMusic,
  'music_note': PlainIconData.catMusic,
  'headphone': PlainIconData.catHeadphone,
  'concert': PlainIconData.catMic,
  'podcast': PlainIconData.catMic,
  'game': PlainIconData.catGame,
  'game_pad': PlainIconData.catGame,
  'game_sub': PlainIconData.catGame,
  'arcade': PlainIconData.catGame,
  'board_game': PlainIconData.catGame,
  'puzzle': PlainIconData.catGame,
  'sports': PlainIconData.catSports,
  'running': PlainIconData.catSports,
  'swimming': PlainIconData.catSwim,
  'gym': PlainIconData.catGym,
  'fitness': PlainIconData.catGym,
  'yoga': PlainIconData.catGym,
  'travel': PlainIconData.catTravel,
  'camping': PlainIconData.catCamping,
  'theme_park': PlainIconData.catCamping,
  'zoo': PlainIconData.catCamping,
  'museum': PlainIconData.catMuseum,
  'camera': PlainIconData.catMuseum,
  'photo': PlainIconData.catMuseum,
  'photo_print': PlainIconData.catMuseum,
  'frame': PlainIconData.catMuseum,
  'newspaper': PlainIconData.catMuseum,
  // ── 医疗 ────────────────────────────────────────────────────────────
  'medical': PlainIconData.catMedical,
  'health': PlainIconData.catHealth,
  'insurance': PlainIconData.catHealth,
  'insurance_health': PlainIconData.catHealth,
  'pension': PlainIconData.catHealth,
  'pharmacy': PlainIconData.catPharmacy,
  'doctor': PlainIconData.catDoctor,
  'bandage': PlainIconData.catBandage,
  'heart': PlainIconData.catHeart,
  'love': PlainIconData.catHeart,
  'kiss': PlainIconData.catHeart,
  'date': PlainIconData.catHeart,
  // ── 学习 ────────────────────────────────────────────────────────────
  'study': PlainIconData.catStudy,
  'book': PlainIconData.catStudy,
  'learn': PlainIconData.catStudy,
  'textbook': PlainIconData.catStudy,
  'school': PlainIconData.catSchool,
  'school_bus': PlainIconData.catSchool,
  'course': PlainIconData.catCourse,
  'tuition': PlainIconData.catCourse,
  'education_fund': PlainIconData.catCourse,
  'exam': PlainIconData.catExam,
  'stationery_set': PlainIconData.catExam,
  'library': PlainIconData.catLibrary,
  'tech': PlainIconData.catLaptop,
  'laptop': PlainIconData.catLaptop,
  'laptop_stand': PlainIconData.catLaptop,
  'monitor': PlainIconData.catLaptop,
  'office': PlainIconData.catLaptop,
  'conference': PlainIconData.catLaptop,
  'coworking': PlainIconData.catLaptop,
  'mouse': PlainIconData.catKeyboard,
  'keyboard': PlainIconData.catKeyboard,
  'printer': PlainIconData.catPrinter,
  'scanner': PlainIconData.catPrinter,
  // ── 人情 / 社交 ─────────────────────────────────────────────────────
  'social': PlainIconData.catSocial,
  'community': PlainIconData.catSocial,
  'party': PlainIconData.catParty,
  'birthday': PlainIconData.catParty,
  'wedding': PlainIconData.catCouple,
  'couple': PlainIconData.catCouple,
  'elder': PlainIconData.catCouple,
  'flowers': PlainIconData.catFlowers,
  'funeral': PlainIconData.catFlowers,
  'donation': PlainIconData.catDonation,
  'charity': PlainIconData.catDonation,
  'donate_blood': PlainIconData.catDonation,
  'volunteer': PlainIconData.catDonation,
  // 红包：礼物盒。这个 ref 同时被「收入 · 红包」用（收入侧没有第二个 ref，
  // 别再往下面叠一行同名的）。
  'redpacket': PlainIconData.catRedpacket,
  // ── 其他 / 财务 ─────────────────────────────────────────────────────
  'other': PlainIconData.catOther,
  'misc': PlainIconData.catOther,
  'work': PlainIconData.catOther,
  'budget': PlainIconData.catOther,
  'chart': PlainIconData.catOther,
  'subscription': PlainIconData.catOther,
  'barcode': PlainIconData.catOther,
  'safe': PlainIconData.catSafe,
  'retirement': PlainIconData.catSafe,
  'emergency_fund': PlainIconData.catSafe,
  'piggy': PlainIconData.catPiggy,
  'saving': PlainIconData.catPiggy,
  'coins': PlainIconData.catCoins,
  'gold': PlainIconData.catCoins,
  'cryptocurrency': PlainIconData.catCoins,
  'dividend': PlainIconData.catCoins,
  'bill': PlainIconData.catBill,
  'invoice': PlainIconData.catInvoice,
  'receipt_scan': PlainIconData.catInvoice,
  'auto_debit': PlainIconData.catInvoice,
  'bill_split': PlainIconData.catInvoice,
  'shared_expense': PlainIconData.catInvoice,
  'card': PlainIconData.catCard,
  'credit_card_bill': PlainIconData.catCard,
  'installment': PlainIconData.catCard,
  'loan': PlainIconData.catCard,
  'debt': PlainIconData.catCard,
  'tax': PlainIconData.catPercent,
  'fee': PlainIconData.catPercent,
  'interest': PlainIconData.catPercent,
  'fund': PlainIconData.catPercent,
  'bond': PlainIconData.catPercent,
  'wallet': PlainIconData.wallet,
  'trophy': PlainIconData.trophy,
  'medal': PlainIconData.trophy,
  'cup': PlainIconData.trophy,
  // ── 收入（v1.x 补）──────────────────────────────────────────────────
  //
  // 上面那批 `cat*` 主要覆盖**支出**场景；收入这些 ref 给各自一个专属图标，
  // 免得 6 个收入分类长得一模一样。
  //
  // 配色不用管：`_canonRef` 只认 12 个色板键（INV-1 要求 `categoryColorMap`
  // 恰好 12 色，不能加第 13 个），非 `cat*` 图标一律归到 `other` 色板。
  'salary': PlainIconData.wallet,
  'bonus': PlainIconData.trophy,
  'invest': PlainIconData.trendUp,
  'parttime': PlainIconData.arrowDownLeft,
  'freelance': PlainIconData.arrowDownLeft,
  'business': PlainIconData.chartBars,
  'reimburse': PlainIconData.receipt,
  'subsidy': PlainIconData.shield,
  'refund': PlainIconData.undo,
  'resale': PlainIconData.tag,
  'prize': PlainIconData.celebration,
  'family': PlainIconData.account,
};

/// 图标 → 12 色板键（INV-1：`categoryColorMap` 恰好 12 色）。
///
/// 100 枚 `ic_cat_*` 分成 12 组，每组共用一个一级分类色。非 `cat*` 图标
/// （红包/收入那几个通用图标）不在此表 → 回落 `other` 色板。
const Map<String, String> kIconPaletteKey = {
  // 餐饮
  'ic_cat_food': 'food',
  'ic_cat_takeout': 'food',
  'ic_cat_fastfood': 'food',
  'ic_cat_noodle': 'food',
  'ic_cat_sushi': 'food',
  'ic_cat_hotpot': 'food',
  'ic_cat_coffee': 'food',
  'ic_cat_tea': 'food',
  'ic_cat_beer': 'food',
  'ic_cat_wine': 'food',
  'ic_cat_cake': 'food',
  'ic_cat_bread': 'food',
  // 食材
  'ic_cat_grocery': 'fruit',
  'ic_cat_fruit': 'fruit',
  'ic_cat_vegetable': 'fruit',
  'ic_cat_seafood': 'fruit',
  'ic_cat_meat': 'fruit',
  // 购物
  'ic_cat_shopping': 'shopping',
  'ic_cat_bag': 'shopping',
  'ic_cat_mall': 'shopping',
  'ic_cat_clothes': 'shopping',
  'ic_cat_shoes': 'shopping',
  'ic_cat_cosmetics': 'shopping',
  'ic_cat_perfume': 'shopping',
  'ic_cat_watch': 'shopping',
  'ic_cat_jewelry': 'shopping',
  'ic_cat_umbrella': 'shopping',
  // 日用
  'ic_cat_daily': 'daily',
  'ic_cat_cleaning': 'daily',
  'ic_cat_laundry': 'daily',
  'ic_cat_beauty': 'daily',
  'ic_cat_haircut': 'daily',
  'ic_cat_pet': 'daily',
  'ic_cat_baby': 'daily',
  'ic_cat_tools': 'daily',
  'ic_cat_furniture': 'daily',
  // 交通
  'ic_cat_transport': 'transport',
  'ic_cat_car': 'transport',
  'ic_cat_taxi': 'transport',
  'ic_cat_train': 'transport',
  'ic_cat_plane': 'transport',
  'ic_cat_bike': 'transport',
  'ic_cat_gas': 'transport',
  'ic_cat_charging': 'transport',
  'ic_cat_parking': 'transport',
  'ic_cat_ship': 'transport',
  // 居住
  'ic_cat_housing': 'housing',
  'ic_cat_rent': 'housing',
  'ic_cat_electricity': 'housing',
  'ic_cat_water': 'housing',
  'ic_cat_wifi': 'housing',
  'ic_cat_bed': 'housing',
  'ic_cat_hotel': 'housing',
  // 通讯
  'ic_cat_telecom': 'telecom',
  'ic_cat_sim': 'telecom',
  'ic_cat_email': 'telecom',
  'ic_cat_router': 'telecom',
  // 娱乐
  'ic_cat_entertainment': 'entertainment',
  'ic_cat_movie': 'entertainment',
  'ic_cat_music': 'entertainment',
  'ic_cat_game': 'entertainment',
  'ic_cat_sports': 'entertainment',
  'ic_cat_gym': 'entertainment',
  'ic_cat_swim': 'entertainment',
  'ic_cat_travel': 'entertainment',
  'ic_cat_camping': 'entertainment',
  'ic_cat_mic': 'entertainment',
  'ic_cat_museum': 'entertainment',
  'ic_cat_tv': 'entertainment',
  // 医疗
  'ic_cat_medical': 'medical',
  'ic_cat_pharmacy': 'medical',
  'ic_cat_doctor': 'medical',
  'ic_cat_bandage': 'medical',
  'ic_cat_health': 'medical',
  // 学习
  'ic_cat_study': 'study',
  'ic_cat_school': 'study',
  'ic_cat_course': 'study',
  'ic_cat_laptop': 'study',
  'ic_cat_keyboard': 'study',
  'ic_cat_printer': 'study',
  'ic_cat_library': 'study',
  'ic_cat_exam': 'study',
  // 人情
  'ic_cat_social': 'social',
  'ic_cat_party': 'social',
  'ic_cat_couple': 'social',
  'ic_cat_flowers': 'social',
  'ic_cat_donation': 'social',
  // 其他 / 财务
  'ic_cat_other': 'other',
  'ic_cat_safe': 'other',
  'ic_cat_piggy': 'other',
  'ic_cat_coins': 'other',
  'ic_cat_bill': 'other',
  'ic_cat_invoice': 'other',
  'ic_cat_card': 'other',
  'ic_cat_percent': 'other',
  // 心：医疗语义（体检/健康）更近，归医疗色板
  'ic_cat_heart': 'medical',
};

/// Resolve v3 icon for a category ref; null when not in the new set.
PlainIconData? plainIconForRef(String ref) => kCategoryPlainIcons[ref];

/// Category ink color for icons/small text on light or dark hosts.
Color categoryIconColor(String ref, {required bool isDark}) {
  final map = isDark ? categoryInkDark : categoryInkLight;
  final argb = map[_canonRef(ref)] ?? categoryInkLight['other']!;
  return Color(argb);
}

/// Base (slice/dot) color for charts and dots.
Color categoryDotColor(String ref) {
  final argb = categoryColorMap[_canonRef(ref)] ?? categoryColorMap['other']!;
  return Color(argb);
}

/// ref → 12 色板键：先取它对应的图标，再由图标查色板分组。
///
/// ⚠️ 键是 `icon.name`（如 `ic_cat_coffee`）而不是 ref —— 因为近 300 个 ref
/// 是多对一映射到 100 枚图标的，按图标查才能一次覆盖全部。
String _canonRef(String ref) {
  final icon = kCategoryPlainIcons[ref];
  if (icon == null) return ref;
  return kIconPaletteKey[icon.name] ?? 'other';
}

/// Category icon widget: colored stroke SVG, no backing plate.
///
/// 2026-10-19：移除了「本地上传自定义图优先」的分支（原 F1.2）。
/// 内置图标库已扩到 100 枚，不再有自定义图可显示，这里只走描边图标一条路。
class CategoryIcon extends StatelessWidget {
  const CategoryIcon({
    super.key,
    required this.iconRef,
    this.size = 24,
    this.color,
  });

  final String iconRef;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = color ?? categoryIconColor(iconRef, isDark: isDark);
    // 未知 ref 落到「其他」分类图标 —— 不再回退 Material。
    final icon = plainIconForRef(iconRef) ?? PlainIconData.catOther;
    return PlainIcon(icon, size: size, color: c);
  }
}
