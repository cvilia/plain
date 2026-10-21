/// Shared date formatting. Single source for day labels and timestamps.
library;

import 'package:plain/app/l10n/app_strings.dart';
import 'package:plain/app/l10n/strings_core.dart';
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

/// 把「只选了哪一天」的日期补上一个时刻：**那一天 + [now] 的时分秒**（返回 UTC）。
///
/// 为什么必须补：`showAppDatePicker` 返回的是 `DateTime(y,m,d).toUtc()`，时分秒
/// 恒为 00:00:00。直接落库会让补记的账落在**当天最早的一刻**，流水页按
/// `occurred_at DESC` 排序时它永远沉在当天分组最下面（用户 2026-10-20 报的
/// 「新建昨天的食材消费排到昨天的交通下面」就是这个原因）。
///
/// 补「此刻的时分秒」而不是 23:59 —— 列表副标题在无分类/无备注时会**显示时分**，
/// 编一个 23:59 会被看见；而「此刻」对用户也是可解释的：这条账是你现在补的。
/// 选「今天」时等价于「就是现在」。
DateTime mergeDayWithNowTime(DateTime pickedDay, DateTime now) {
  final d = pickedDay.toLocal();
  final n = now.toLocal();
  return DateTime(d.year, d.month, d.day, n.hour, n.minute, n.second,
          n.millisecond)
      .toUtc();
}

/// Group-header label for a `yyyy-MM-dd` day key: 今天 / 昨天 / `M月D日 周X`.
///
/// 日期形态照设计稿屏 2 的 `.eyebrow`：`9月28日 周日`（不补零、不带年）。
/// 今天/昨天仍是特例 —— 设计稿的样例数据里没有「今天」那一行，而这两个词
/// 在扫读时的价值远高于日期本身。
String dayLabel(AppStrings s, String dayKey, {DateTime? now}) {
  final ref = now ?? DateTime.now();
  final today = Clock.dayKeyOf(ref);
  final yest = Clock.dayKeyOf(ref.subtract(const Duration(days: 1)));
  if (dayKey == today) return s.today;
  if (dayKey == yest) return s.yesterday;
  final dt = DateTime.tryParse(dayKey);
  if (dt == null) return dayKey;
  final wd = s.weekdayLabels[(dt.weekday - 1) % 7];
  return s.shortMonthDayWeekday(dt, wd);
}
