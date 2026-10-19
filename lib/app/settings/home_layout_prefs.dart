/// STORY-5.3 首页卡片布局偏好（本地偏好，不同步）。
library;

import 'package:plain/app/l10n/app_strings.dart';
import 'package:plain/app/l10n/strings_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 可选卡片 ID。
enum HomeCardId {
  safeToSpend('safe_to_spend'),
  monthlyBalance('monthly_balance'),
  budgetProgress('budget_progress'),
  netAssets('net_assets'),
  pendingReimburse('pending_reimburse'),
  savingsGoals('savings_goals'),
  recentEntries('recent_entries');

  const HomeCardId(this.id);
  final String id;

  /// 卡片显示名（i18n 收口，调用点：`x.label(s)`）。
  String label(AppStrings s) => switch (this) {
        HomeCardId.safeToSpend => s.homeCardSafeToSpend,
        HomeCardId.monthlyBalance => s.homeCardMonthlyBalance,
        HomeCardId.budgetProgress => s.homeCardBudgetProgress,
        HomeCardId.netAssets => s.homeCardNetAssets,
        HomeCardId.pendingReimburse => s.homeCardPendingReimburse,
        HomeCardId.savingsGoals => s.homeCardSavingsGoals,
        HomeCardId.recentEntries => s.homeCardRecentEntries,
      };
}

/// 3 套预设布局。
abstract class HomeLayoutPresets {
  static const minimal = [HomeCardId.monthlyBalance, HomeCardId.recentEntries];
  static const standard = [
    HomeCardId.safeToSpend,
    HomeCardId.monthlyBalance,
    HomeCardId.budgetProgress,
    HomeCardId.recentEntries,
  ];
  static const panoramic = HomeCardId.values;
}

const String _kPrefHomeCards = 'pref.home.cards';
const String _kPrefHomeHidden = 'pref.home.hidden';

/// 读取卡片顺序（id 列表），默认 standard。
Future<List<String>> loadHomeCardOrder() async {
  try {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getStringList(_kPrefHomeCards);
    if (raw != null && raw.isNotEmpty) return raw;
  } catch (_) {}
  return HomeLayoutPresets.standard.map((c) => c.id).toList();
}

/// 读取隐藏卡片 id 集合。
Future<Set<String>> loadHomeCardHidden() async {
  try {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getStringList(_kPrefHomeHidden);
    if (raw != null) return raw.toSet();
  } catch (_) {}
  return {};
}

/// 保存布局。
Future<void> saveHomeLayout({
  required List<String> order,
  required Set<String> hidden,
}) async {
  try {
    final sp = await SharedPreferences.getInstance();
    await sp.setStringList(_kPrefHomeCards, order);
    await sp.setStringList(_kPrefHomeHidden, hidden.toList());
  } catch (_) {}
}

/// 应用预设布局。
Future<void> applyHomePreset(List<HomeCardId> preset) async {
  await saveHomeLayout(
    order: preset.map((c) => c.id).toList(),
    hidden: {},
  );
}

/// 根据顺序 + 隐藏集，返回可见卡片。
List<HomeCardId> visibleCards(List<String> order, Set<String> hidden) {
  return [
    for (final id in order)
      if (!hidden.contains(id))
        HomeCardId.values.firstWhere((c) => c.id == id, orElse: () => HomeCardId.recentEntries),
  ];
}
