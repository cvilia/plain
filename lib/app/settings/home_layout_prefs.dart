/// STORY-5.3 首页卡片布局偏好（本地偏好，不同步）。
library;

import 'package:shared_preferences/shared_preferences.dart';

/// 可选卡片 ID。
enum HomeCardId {
  safeToSpend('safe_to_spend', '安全可花'),
  monthlyBalance('monthly_balance', '本月收支'),
  budgetProgress('budget_progress', '预算进度'),
  netAssets('net_assets', '资产净值'),
  pendingReimburse('pending_reimburse', '待报销'),
  savingsGoals('savings_goals', '储蓄目标'),
  recentEntries('recent_entries', '最近账单');

  const HomeCardId(this.id, this.label);
  final String id;
  final String label;
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
