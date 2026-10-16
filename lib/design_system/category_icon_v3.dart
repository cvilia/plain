/// Quiet Ledger category icons: map iconRef → PlainIconData (new SVG set)
/// with category ink colors. Falls back to null for unknown/legacy refs.
library;

import 'package:flutter/material.dart';
import 'package:plain/app/theme/theme_registry.dart';
import 'package:plain/design_system/plain_icons_v3.dart';

/// iconRef → v3 SVG icon. 12 一级 + 二级/常见 ref 归并到最近一级。
const Map<String, PlainIconData> kCategoryPlainIcons = {
  // 餐饮
  'food': PlainIconData.catFood,
  'dining': PlainIconData.catFood,
  'meal': PlainIconData.catFood,
  'breakfast': PlainIconData.catFood,
  'lunch': PlainIconData.catFood,
  'dinner': PlainIconData.catFood,
  'takeout': PlainIconData.catFood,
  'fastfood': PlainIconData.catFood,
  'pizza': PlainIconData.catFood,
  'noodle': PlainIconData.catFood,
  'sushi': PlainIconData.catFood,
  'bbq': PlainIconData.catFood,
  'hotpot': PlainIconData.catFood,
  'coffee': PlainIconData.catFood,
  'coffee_shop': PlainIconData.catFood,
  'tea': PlainIconData.catFood,
  'bar': PlainIconData.catFood,
  'beer': PlainIconData.catFood,
  'wine': PlainIconData.catFood,
  'cocktail': PlainIconData.catFood,
  'dessert': PlainIconData.catFood,
  'cake': PlainIconData.catFood,
  'bread': PlainIconData.catFood,
  'milk': PlainIconData.catFood,
  'seafood': PlainIconData.catFood,
  'meat': PlainIconData.catFood,
  'egg': PlainIconData.catFood,
  'snack': PlainIconData.catFood,
  'candy': PlainIconData.catFood,
  // 食材
  'grocery': PlainIconData.catGrocery,
  'fruit': PlainIconData.catGrocery,
  'vegetable': PlainIconData.catGrocery,
  'market': PlainIconData.catGrocery,
  'recipe': PlainIconData.catGrocery,
  'cookbook': PlainIconData.catGrocery,
  'kitchen': PlainIconData.catGrocery,
  // 购物
  'shopping': PlainIconData.catShopping,
  'bag': PlainIconData.catShopping,
  'mall': PlainIconData.catShopping,
  'clothes': PlainIconData.catShopping,
  'shoes': PlainIconData.catShopping,
  'luxury': PlainIconData.catShopping,
  'gift': PlainIconData.catShopping,
  'cosmetics': PlainIconData.catShopping,
  'perfume': PlainIconData.catShopping,
  'skincare': PlainIconData.catShopping,
  'makeup': PlainIconData.catShopping,
  'jewelry': PlainIconData.catShopping,
  'watch': PlainIconData.catShopping,
  'umbrella': PlainIconData.catShopping,
  'toy': PlainIconData.catShopping,
  'souvenir': PlainIconData.catShopping,
  'frame': PlainIconData.catShopping,
  'photo_print': PlainIconData.catShopping,
  // 日用
  'daily': PlainIconData.catDaily,
  'household': PlainIconData.catDaily,
  'home_goods': PlainIconData.catDaily,
  'cleaning': PlainIconData.catDaily,
  'clean_house': PlainIconData.catDaily,
  'deep_clean': PlainIconData.catDaily,
  'laundry': PlainIconData.catDaily,
  'laundromat': PlainIconData.catDaily,
  'dry_clean': PlainIconData.catDaily,
  'bottle': PlainIconData.catDaily,
  'beauty': PlainIconData.catDaily,
  'haircut': PlainIconData.catDaily,
  'barber': PlainIconData.catDaily,
  'spa': PlainIconData.catDaily,
  'pet': PlainIconData.catDaily,
  'pet_food': PlainIconData.catDaily,
  'pet_toys': PlainIconData.catDaily,
  'baby': PlainIconData.catDaily,
  'baby_care': PlainIconData.catDaily,
  'baby_food': PlainIconData.catDaily,
  'diaper': PlainIconData.catDaily,
  'stroller': PlainIconData.catDaily,
  'tools': PlainIconData.catDaily,
  'repair': PlainIconData.catDaily,
  'garden': PlainIconData.catDaily,
  'stationery': PlainIconData.catDaily,
  'notebook': PlainIconData.catDaily,
  'pen': PlainIconData.catDaily,
  // 交通
  'transport': PlainIconData.catTransport,
  'bus': PlainIconData.catTransport,
  'car': PlainIconData.catTransport,
  'taxi': PlainIconData.catTransport,
  'train': PlainIconData.catTransport,
  'plane': PlainIconData.catTransport,
  'flight_ticket': PlainIconData.catTransport,
  'bike': PlainIconData.catTransport,
  'bike_share': PlainIconData.catTransport,
  'motorcycle': PlainIconData.catTransport,
  'gas': PlainIconData.catTransport,
  'oil': PlainIconData.catTransport,
  'parking': PlainIconData.catTransport,
  'toll_road': PlainIconData.catTransport,
  'highway': PlainIconData.catTransport,
  'bus_card': PlainIconData.catTransport,
  'bus_stop': PlainIconData.catTransport,
  'bus_ticket': PlainIconData.catTransport,
  'subway_card': PlainIconData.catTransport,
  'metro': PlainIconData.catTransport,
  'ferry': PlainIconData.catTransport,
  'train_ticket': PlainIconData.catTransport,
  'ship_ticket': PlainIconData.catTransport,
  'car_wash': PlainIconData.catTransport,
  'car_repair': PlainIconData.catTransport,
  'tire': PlainIconData.catTransport,
  'electric_car': PlainIconData.catTransport,
  'charging': PlainIconData.catTransport,
  'luggage_tag': PlainIconData.catTransport,
  'passport': PlainIconData.catTransport,
  'visa': PlainIconData.catTransport,
  // 居住
  'housing': PlainIconData.catHousing,
  'rent': PlainIconData.catHousing,
  'home': PlainIconData.catHousing,
  'rental_income': PlainIconData.catHousing,
  'utilities': PlainIconData.catHousing,
  'electricity': PlainIconData.catHousing,
  'water': PlainIconData.catHousing,
  'gas_bill': PlainIconData.catHousing,
  'property_fee': PlainIconData.catHousing,
  'furniture': PlainIconData.catHousing,
  'internet': PlainIconData.catHousing,
  'broadband': PlainIconData.catHousing,
  'night_hotel': PlainIconData.catHousing,
  'airbnb': PlainIconData.catHousing,
  'hostel': PlainIconData.catHousing,
  'hotel': PlainIconData.catHousing,
  'mover': PlainIconData.catHousing,
  'electrician': PlainIconData.catHousing,
  'plumber': PlainIconData.catHousing,
  'locksmith': PlainIconData.catHousing,
  'pest_control': PlainIconData.catHousing,
  // 通讯
  'telecom': PlainIconData.catTelecom,
  'phone': PlainIconData.catTelecom,
  'phone_case': PlainIconData.catTelecom,
  'mobile_bill': PlainIconData.catTelecom,
  'sim': PlainIconData.catTelecom,
  'email': PlainIconData.catTelecom,
  'app': PlainIconData.catTelecom,
  'cloud': PlainIconData.catTelecom,
  'domain': PlainIconData.catTelecom,
  'hosting': PlainIconData.catTelecom,
  'router': PlainIconData.catTelecom,
  // 娱乐
  'entertainment': PlainIconData.catEntertainment,
  'fun': PlainIconData.catEntertainment,
  'music': PlainIconData.catEntertainment,
  'music_note': PlainIconData.catEntertainment,
  'movie': PlainIconData.catEntertainment,
  'movie_ticket': PlainIconData.catEntertainment,
  'movie_club': PlainIconData.catEntertainment,
  'streaming': PlainIconData.catEntertainment,
  'game': PlainIconData.catEntertainment,
  'game_pad': PlainIconData.catEntertainment,
  'game_sub': PlainIconData.catEntertainment,
  'arcade': PlainIconData.catEntertainment,
  'board_game': PlainIconData.catEntertainment,
  'puzzle': PlainIconData.catEntertainment,
  'sports': PlainIconData.catEntertainment,
  'gym': PlainIconData.catEntertainment,
  'yoga': PlainIconData.catEntertainment,
  'running': PlainIconData.catEntertainment,
  'swimming': PlainIconData.catEntertainment,
  'travel': PlainIconData.catEntertainment,
  'camping': PlainIconData.catEntertainment,
  'theme_park': PlainIconData.catEntertainment,
  'concert': PlainIconData.catEntertainment,
  'museum': PlainIconData.catEntertainment,
  'zoo': PlainIconData.catEntertainment,
  'camera': PlainIconData.catEntertainment,
  'photo': PlainIconData.catEntertainment,
  'video': PlainIconData.catEntertainment,
  'podcast': PlainIconData.catEntertainment,
  'newspaper': PlainIconData.catEntertainment,
  // 医疗
  'medical': PlainIconData.catMedical,
  'health': PlainIconData.catMedical,
  'pharmacy': PlainIconData.catMedical,
  'doctor': PlainIconData.catMedical,
  'fitness': PlainIconData.catMedical,
  'vet': PlainIconData.catMedical,
  'insurance': PlainIconData.catMedical,
  'insurance_health': PlainIconData.catMedical,
  'insurance_car': PlainIconData.catMedical,
  'pension': PlainIconData.catMedical,
  // 学习
  'study': PlainIconData.catStudy,
  'book': PlainIconData.catStudy,
  'learn': PlainIconData.catStudy,
  'course': PlainIconData.catStudy,
  'school': PlainIconData.catStudy,
  'school_bus': PlainIconData.catStudy,
  'tuition': PlainIconData.catStudy,
  'exam': PlainIconData.catStudy,
  'library': PlainIconData.catStudy,
  'textbook': PlainIconData.catStudy,
  'stationery_set': PlainIconData.catStudy,
  'education_fund': PlainIconData.catStudy,
  'tech': PlainIconData.catStudy,
  'laptop': PlainIconData.catStudy,
  'laptop_stand': PlainIconData.catStudy,
  'mouse': PlainIconData.catStudy,
  'keyboard': PlainIconData.catStudy,
  'monitor': PlainIconData.catStudy,
  'office': PlainIconData.catStudy,
  'conference': PlainIconData.catStudy,
  'coworking': PlainIconData.catStudy,
  // 人情 / 社交
  'social': PlainIconData.catSocial,
  'party': PlainIconData.catSocial,
  'wedding': PlainIconData.catSocial,
  'birthday': PlainIconData.catSocial,
  'funeral': PlainIconData.catSocial,
  'flowers': PlainIconData.catSocial,
  'love': PlainIconData.catSocial,
  'kiss': PlainIconData.catSocial,
  'date': PlainIconData.catSocial,
  'redpacket': PlainIconData.catSocial,
  'donation': PlainIconData.catSocial,
  'charity': PlainIconData.catSocial,
  'donate_blood': PlainIconData.catSocial,
  'volunteer': PlainIconData.catSocial,
  'community': PlainIconData.catSocial,
  // 其他 / 财务
  'other': PlainIconData.catOther,
  'misc': PlainIconData.catOther,
  'work': PlainIconData.catOther,
  'freelance': PlainIconData.catOther,
  'salary': PlainIconData.catOther,
  'bonus': PlainIconData.catOther,
  'invest': PlainIconData.catOther,
  'loan': PlainIconData.catOther,
  'debt': PlainIconData.catOther,
  'credit_card_bill': PlainIconData.catOther,
  'installment': PlainIconData.catOther,
  'tax': PlainIconData.catOther,
  'fee': PlainIconData.catOther,
  'interest': PlainIconData.catOther,
  'saving': PlainIconData.catOther,
  'dividend': PlainIconData.catOther,
  'refund': PlainIconData.catOther,
  'budget': PlainIconData.catOther,
  'invoice': PlainIconData.catOther,
  'receipt_scan': PlainIconData.catOther,
  'barcode': PlainIconData.catOther,
  'cryptocurrency': PlainIconData.catOther,
  'gold': PlainIconData.catOther,
  'bond': PlainIconData.catOther,
  'fund': PlainIconData.catOther,
  'retirement': PlainIconData.catOther,
  'emergency_fund': PlainIconData.catOther,
  'subscription': PlainIconData.catOther,
  'auto_debit': PlainIconData.catOther,
  'bill_split': PlainIconData.catOther,
  'shared_expense': PlainIconData.catOther,
  'elder': PlainIconData.catOther,
  'wallet': PlainIconData.catOther,
  'safe': PlainIconData.catOther,
  'chart': PlainIconData.catOther,
  'piggy': PlainIconData.catOther,
  'medal': PlainIconData.catOther,
  'trophy': PlainIconData.catOther,
  'cup': PlainIconData.catOther,
  'shoe_repair': PlainIconData.catOther,
  'sewing': PlainIconData.catOther,
  'knitting': PlainIconData.catOther,
  'craft': PlainIconData.catOther,
  'nail': PlainIconData.catOther,
  'toy_blocks': PlainIconData.catOther,
  'streaming_alt': PlainIconData.catOther,
};

/// Resolve v3 icon for a category ref; null when not in the new set.
PlainIconData? plainIconForRef(String ref) => kCategoryPlainIcons[ref];

/// Category ink color for icons/small text on light or dark hosts.
Color categoryIconColor(String ref, {required bool isDark}) {
  final map = isDark ? categoryInkDark : categoryInkLight;
  final key = _canonRef(ref);
  final argb = map[key] ?? categoryInkLight['other']!;
  return Color(argb);
}

/// Base (slice/dot) color for charts and dots.
Color categoryDotColor(String ref) {
  final argb = categoryColorMap[_canonRef(ref)] ?? categoryColorMap['other']!;
  return Color(argb);
}

String _canonRef(String ref) {
  final icon = kCategoryPlainIcons[ref];
  if (icon == null) return ref;
  // Map by which v3 icon is used → 12 palette keys (INV-1).
  if (icon == PlainIconData.catFood) return 'food';
  if (icon == PlainIconData.catGrocery) return 'fruit';
  if (icon == PlainIconData.catShopping) return 'shopping';
  if (icon == PlainIconData.catDaily) return 'daily';
  if (icon == PlainIconData.catTransport) return 'transport';
  if (icon == PlainIconData.catHousing) return 'housing';
  if (icon == PlainIconData.catTelecom) return 'telecom';
  if (icon == PlainIconData.catEntertainment) return 'entertainment';
  if (icon == PlainIconData.catMedical) return 'medical';
  if (icon == PlainIconData.catStudy) return 'study';
  if (icon == PlainIconData.catSocial) return 'social';
  return 'other';
}

/// Category icon widget: colored stroke SVG, no backing plate.
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
    final icon = plainIconForRef(iconRef);
    if (icon != null) {
      return PlainIcon(icon, size: size, color: c);
    }
    // 未知 ref 落到「其他」分类图标 —— 不再回退 Material。
    return PlainIcon(PlainIconData.catOther, size: size, color: c);
  }
}
