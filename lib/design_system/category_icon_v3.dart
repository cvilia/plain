/// Quiet Ledger category icons: map iconRef → PlainIconData (new SVG set)
/// with category ink colors. Falls back to null for unknown/legacy refs.
library;

import 'package:flutter/material.dart';
import 'package:plain/app/theme/theme_registry.dart';
import 'package:plain/design_system/plain_icons_v3.dart';

/// iconRef → v3 SVG 图标。
///
/// ⚠️ **这里的键是语义 ref（近 300 个），值只有 31 枚图标 —— 映射是多对一。**
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
  'takeout': PlainIconData.catFood,
  'fastfood': PlainIconData.catFood,
  'pizza': PlainIconData.catFood,
  'bbq': PlainIconData.catFood,
  'noodle': PlainIconData.catFood,
  'sushi': PlainIconData.catFood,
  'hotpot': PlainIconData.catFood,
  'coffee': PlainIconData.catFood,
  'coffee_shop': PlainIconData.catFood,
  'milk': PlainIconData.catFood,
  'tea': PlainIconData.catFood,
  'bar': PlainIconData.catFood,
  'beer': PlainIconData.catFood,
  'wine': PlainIconData.catFood,
  'cocktail': PlainIconData.catFood,
  'dessert': PlainIconData.catFood,
  'cake': PlainIconData.catFood,
  'bread': PlainIconData.catFood,
  'snack': PlainIconData.catFood,
  'candy': PlainIconData.catFood,
  // ── 食材 ────────────────────────────────────────────────────────────
  'grocery': PlainIconData.catGrocery,
  'market': PlainIconData.catGrocery,
  'recipe': PlainIconData.catGrocery,
  'cookbook': PlainIconData.catGrocery,
  'kitchen': PlainIconData.catGrocery,
  'egg': PlainIconData.catGrocery,
  'fruit': PlainIconData.catGrocery,
  'vegetable': PlainIconData.catGrocery,
  'seafood': PlainIconData.catGrocery,
  'meat': PlainIconData.catGrocery,
  // ── 购物 ────────────────────────────────────────────────────────────
  'shopping': PlainIconData.catDaily,
  'toy': PlainIconData.catBaby,
  'toy_blocks': PlainIconData.catBaby,
  'bag': PlainIconData.catClothes,
  'souvenir': PlainIconData.catClothes,
  'mall': PlainIconData.catDaily,
  'clothes': PlainIconData.catClothes,
  'shoes': PlainIconData.catClothes,
  'shoe_repair': PlainIconData.catClothes,
  'cosmetics': PlainIconData.catCosmetics,
  'makeup': PlainIconData.catCosmetics,
  'skincare': PlainIconData.catCosmetics,
  'perfume': PlainIconData.catCosmetics,
  'watch': PlainIconData.catClothes,
  'luxury': PlainIconData.catClothes,
  'jewelry': PlainIconData.catClothes,
  'ring': PlainIconData.catClothes,
  'umbrella': PlainIconData.catUmbrella,
  'gift': PlainIconData.gift,
  // ── 日用 ────────────────────────────────────────────────────────────
  'daily': PlainIconData.catDaily,
  'household': PlainIconData.catDaily,
  'home_goods': PlainIconData.catDaily,
  'bottle': PlainIconData.catDaily,
  'cleaning': PlainIconData.catCleaning,
  'clean_house': PlainIconData.catDaily,
  'deep_clean': PlainIconData.catDaily,
  'pest_control': PlainIconData.catDaily,
  'laundry': PlainIconData.catDaily,
  'laundromat': PlainIconData.catDaily,
  'dry_clean': PlainIconData.catDaily,
  'beauty': PlainIconData.catCosmetics,
  'spa': PlainIconData.catCosmetics,
  'haircut': PlainIconData.catHaircut,
  'barber': PlainIconData.catCosmetics,
  'nail': PlainIconData.catCosmetics,
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
  'tools': PlainIconData.catHousing,
  'repair': PlainIconData.catHousing,
  'garden': PlainIconData.catHousing,
  'sewing': PlainIconData.catHousing,
  'knitting': PlainIconData.catHousing,
  'craft': PlainIconData.catHousing,
  'electrician': PlainIconData.catHousing,
  'plumber': PlainIconData.catHousing,
  'locksmith': PlainIconData.catHousing,
  'mover': PlainIconData.catDaily,
  'furniture': PlainIconData.catFurniture,
  'stationery': PlainIconData.catStudy,
  'notebook': PlainIconData.catStudy,
  'pen': PlainIconData.catStudy,
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
  'taxi': PlainIconData.catTransport,
  'taxi_fee': PlainIconData.catTransport,
  'taxi_tip': PlainIconData.catTransport,
  'train': PlainIconData.catTransport,
  'train_ticket': PlainIconData.catTransport,
  'highway': PlainIconData.catTransport,
  'plane': PlainIconData.catTransport,
  'flight_ticket': PlainIconData.catTransport,
  'bike': PlainIconData.catTransport,
  'bike_share': PlainIconData.catTransport,
  'motorcycle': PlainIconData.catTransport,
  'gas': PlainIconData.catTransport,
  'oil': PlainIconData.catTransport,
  'charging': PlainIconData.catCar,
  'parking': PlainIconData.catTransport,
  'toll_road': PlainIconData.catTransport,
  'ferry': PlainIconData.catTransport,
  'ship_ticket': PlainIconData.catTransport,
  'passport': PlainIconData.catTravel,
  'visa': PlainIconData.catTravel,
  'luggage_tag': PlainIconData.catTravel,
  // ── 居住 ────────────────────────────────────────────────────────────
  'housing': PlainIconData.catHousing,
  'home': PlainIconData.catHousing,
  'rent': PlainIconData.catHousing,
  'rental_income': PlainIconData.catHousing,
  'utilities': PlainIconData.catElectricity,
  'electricity': PlainIconData.catElectricity,
  'property_fee': PlainIconData.catElectricity,
  'water': PlainIconData.catElectricity,
  'gas_bill': PlainIconData.catElectricity,
  'internet': PlainIconData.catTelecom,
  'broadband': PlainIconData.catTelecom,
  'bed': PlainIconData.catFurniture,
  'hotel': PlainIconData.catTravel,
  'night_hotel': PlainIconData.catTravel,
  'airbnb': PlainIconData.catTravel,
  'hostel': PlainIconData.catTravel,
  // ── 通讯 ────────────────────────────────────────────────────────────
  'telecom': PlainIconData.catTelecom,
  'phone': PlainIconData.catTelecom,
  'phone_case': PlainIconData.catTelecom,
  'mobile_bill': PlainIconData.catTelecom,
  'app': PlainIconData.catTelecom,
  'cloud': PlainIconData.catTelecom,
  'sim': PlainIconData.catTelecom,
  'email': PlainIconData.catTelecom,
  'router': PlainIconData.catTelecom,
  'domain': PlainIconData.catTelecom,
  'hosting': PlainIconData.catTelecom,
  // ── 娱乐 ────────────────────────────────────────────────────────────
  'entertainment': PlainIconData.catEntertainment,
  'fun': PlainIconData.catEntertainment,
  'movie': PlainIconData.catEntertainment,
  'movie_ticket': PlainIconData.catEntertainment,
  'ticket': PlainIconData.catEntertainment,
  'movie_club': PlainIconData.catEntertainment,
  'streaming': PlainIconData.catEntertainment,
  'streaming_alt': PlainIconData.catEntertainment,
  'video': PlainIconData.catTv,
  'tv': PlainIconData.catTv,
  'music': PlainIconData.catEntertainment,
  'music_note': PlainIconData.catEntertainment,
  'headphone': PlainIconData.catEntertainment,
  'concert': PlainIconData.catEntertainment,
  'podcast': PlainIconData.catEntertainment,
  'game': PlainIconData.catGame,
  'game_pad': PlainIconData.catGame,
  'game_sub': PlainIconData.catGame,
  'arcade': PlainIconData.catGame,
  'board_game': PlainIconData.catGame,
  'puzzle': PlainIconData.catGame,
  'sports': PlainIconData.catSports,
  'running': PlainIconData.catSports,
  'swimming': PlainIconData.catSports,
  'gym': PlainIconData.catSports,
  'fitness': PlainIconData.catSports,
  'yoga': PlainIconData.catSports,
  'travel': PlainIconData.catTravel,
  'camping': PlainIconData.catTravel,
  'theme_park': PlainIconData.catTravel,
  'zoo': PlainIconData.catTravel,
  'museum': PlainIconData.catEntertainment,
  'camera': PlainIconData.catEntertainment,
  'photo': PlainIconData.catEntertainment,
  'photo_print': PlainIconData.catEntertainment,
  'frame': PlainIconData.catEntertainment,
  'newspaper': PlainIconData.catEntertainment,
  // ── 医疗 ────────────────────────────────────────────────────────────
  'medical': PlainIconData.catMedical,
  'health': PlainIconData.catMedical,
  'insurance': PlainIconData.catMedical,
  'insurance_health': PlainIconData.catMedical,
  'pension': PlainIconData.catMedical,
  'pharmacy': PlainIconData.catMedical,
  'doctor': PlainIconData.catMedical,
  'bandage': PlainIconData.catMedical,
  'heart': PlainIconData.catMedical,
  'love': PlainIconData.catMedical,
  'kiss': PlainIconData.catMedical,
  'date': PlainIconData.catMedical,
  // ── 学习 ────────────────────────────────────────────────────────────
  'study': PlainIconData.catStudy,
  'book': PlainIconData.catLibrary,
  'learn': PlainIconData.catStudy,
  'textbook': PlainIconData.catStudy,
  'school': PlainIconData.catStudy,
  'school_bus': PlainIconData.catStudy,
  'course': PlainIconData.catStudy,
  'tuition': PlainIconData.catStudy,
  'education_fund': PlainIconData.catStudy,
  'exam': PlainIconData.catStudy,
  'stationery_set': PlainIconData.catStudy,
  'library': PlainIconData.catLibrary,
  'tech': PlainIconData.catLaptop,
  'laptop': PlainIconData.catLaptop,
  'laptop_stand': PlainIconData.catLaptop,
  'monitor': PlainIconData.catLaptop,
  'office': PlainIconData.catLaptop,
  'conference': PlainIconData.catLaptop,
  'coworking': PlainIconData.catLaptop,
  'mouse': PlainIconData.catLaptop,
  'keyboard': PlainIconData.catLaptop,
  'printer': PlainIconData.catPrinter,
  'scanner': PlainIconData.catPrinter,
  // ── 人情 / 社交 ─────────────────────────────────────────────────────
  'social': PlainIconData.catSocial,
  'community': PlainIconData.catSocial,
  'party': PlainIconData.catSocial,
  'birthday': PlainIconData.catSocial,
  'wedding': PlainIconData.catSocial,
  'couple': PlainIconData.catSocial,
  'elder': PlainIconData.catSocial,
  'flowers': PlainIconData.catSocial,
  'funeral': PlainIconData.catSocial,
  'donation': PlainIconData.catSocial,
  'charity': PlainIconData.catSocial,
  'donate_blood': PlainIconData.catSocial,
  'volunteer': PlainIconData.catSocial,
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
  'safe': PlainIconData.catOther,
  'retirement': PlainIconData.catOther,
  'emergency_fund': PlainIconData.catOther,
  'piggy': PlainIconData.catOther,
  'saving': PlainIconData.catOther,
  'coins': PlainIconData.catOther,
  'gold': PlainIconData.catOther,
  'cryptocurrency': PlainIconData.catOther,
  'dividend': PlainIconData.catOther,
  'bill': PlainIconData.catBill,
  'invoice': PlainIconData.catBill,
  'receipt_scan': PlainIconData.catBill,
  'auto_debit': PlainIconData.catBill,
  'bill_split': PlainIconData.catBill,
  'shared_expense': PlainIconData.catBill,
  'card': PlainIconData.catBill,
  'credit_card_bill': PlainIconData.catBill,
  'installment': PlainIconData.catBill,
  'loan': PlainIconData.catBill,
  'debt': PlainIconData.catBill,
  'tax': PlainIconData.catPercent,
  'percent': PlainIconData.catPercent,
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
/// 31 枚 `ic_cat_*` 分成 12 组，每组共用一个一级分类色。非 `cat*` 图标
/// （红包/收入那几个通用图标）不在此表 → 回落 `other` 色板。
const Map<String, String> kIconPaletteKey = {
  // 餐饮
  'ic_cat_food': 'food',
  // 食材
  'ic_cat_grocery': 'fruit',
  // 服饰 / 美妆 / 美容
  'ic_cat_clothes': 'shopping',
  'ic_cat_haircut': 'shopping',
  'ic_cat_cosmetics': 'shopping',
  'ic_cat_umbrella': 'shopping',
  // 日用
  'ic_cat_daily': 'daily',
  'ic_cat_cleaning': 'daily',
  'ic_cat_pet': 'daily',
  'ic_cat_baby': 'daily',
  'ic_cat_furniture': 'daily',
  // 交通
  'ic_cat_transport': 'transport',
  'ic_cat_car': 'transport',
  // 居住
  'ic_cat_housing': 'housing',
  'ic_cat_electricity': 'housing',
  // 通讯
  'ic_cat_telecom': 'telecom',
  // 娱乐
  'ic_cat_entertainment': 'entertainment',
  'ic_cat_game': 'entertainment',
  'ic_cat_sports': 'entertainment',
  'ic_cat_travel': 'entertainment',
  'ic_cat_tv': 'entertainment',
  // 医疗
  'ic_cat_medical': 'medical',
  // 学习
  'ic_cat_study': 'study',
  'ic_cat_laptop': 'study',
  'ic_cat_printer': 'study',
  'ic_cat_library': 'study',
  // 人情
  'ic_cat_social': 'social',
  // 其他 / 财务
  'ic_cat_other': 'other',
  'ic_cat_bill': 'other',
  'ic_cat_percent': 'other',
  // 心：医疗语义（体检/健康）更近，归医疗色板
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
/// ⚠️ 键是 `icon.name`（如 `ic_cat_food`）而不是 ref —— 因为近 300 个 ref
/// 是多对一映射到 100 枚图标的，按图标查才能一次覆盖全部。
String _canonRef(String ref) {
  final icon = kCategoryPlainIcons[ref];
  if (icon == null) return ref;
  return kIconPaletteKey[icon.name] ?? 'other';
}

/// Category icon widget: colored stroke SVG, no backing plate.
///
/// 2026-10-19：移除了「本地上传自定义图优先」的分支（原 F1.2）。
/// 内置分类图标共 31 枚，不再有自定义图可显示，这里只走描边图标一条路。
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
