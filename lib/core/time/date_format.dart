/// Shared date formatting. Single source for day labels and timestamps.
library;

import 'package:plain/core/time/clock.dart';

/// `2026-01-15 14:30` in local time.
String formatDateTime(DateTime at) {
  final local = at.toLocal();
  final mm = local.month.toString().padLeft(2, '0');
  final dd = local.day.toString().padLeft(2, '0');
  final hh = local.hour.toString().padLeft(2, '0');
  final mi = local.minute.toString().padLeft(2, '0');
  return '${local.year}-$mm-$dd $hh:$mi';
}

/// `2026-01-15` in local time (date only, no time).
String formatDate(DateTime at) {
  final local = at.toLocal();
  final mm = local.month.toString().padLeft(2, '0');
  final dd = local.day.toString().padLeft(2, '0');
  return '${local.year}-$mm-$dd';
}

/// `1/15` short label for the entry-input date chip.
String shortDateLabel(DateTime at) {
  final local = at.toLocal();
  return '${local.month}/${local.day}';
}

/// Whether [at] falls on the device's current local calendar day.
bool isSameLocalDay(DateTime at, DateTime now) {
  final a = at.toLocal();
  return a.year == now.year && a.month == now.month && a.day == now.day;
}

/// Group-header label for a `yyyy-MM-dd` day key: 今天 / 昨天 / `M月D日 周X`.
///
/// 日期形态照设计稿屏 2 的 `.eyebrow`：`9月28日 周日`（不补零、不带年）。
/// 今天/昨天仍是特例 —— 设计稿的样例数据里没有「今天」那一行，而这两个词
/// 在扫读时的价值远高于日期本身。
String dayLabel(String dayKey, {DateTime? now}) {
  final ref = now ?? DateTime.now();
  final today = Clock.dayKeyOf(ref);
  final yest = Clock.dayKeyOf(ref.subtract(const Duration(days: 1)));
  if (dayKey == today) return '今天';
  if (dayKey == yest) return '昨天';
  final dt = DateTime.tryParse(dayKey);
  if (dt == null) return dayKey;
  const wd = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
  return '${dt.month}月${dt.day}日 ${wd[dt.weekday % 7]}';
}
