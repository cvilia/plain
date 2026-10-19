/// STORY-9.5 AI 消费周报：周日推送、消费画像、可关闭。
/// 文案基调：只陈述 + 只夸不贬。
///
/// **周窗口口径（全产品唯一）**：本周 = 本周一 00:00 起，到今天（周日 20:00 推送
/// 时即周一~周日）。上周对比一律走**同期**（上周一 ~ 上周同一天），
/// 否则「本周还没过完」会天然显示成支出下降，那是假结论。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:plain/app/l10n/app_strings.dart';
import 'package:plain/core/constants/app_constants.dart';
import 'package:plain/core/time/clock.dart';
import 'package:plain/data/platform/notification_bridge.dart';
import 'package:plain/domain/entities/category.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/entities/reminder.dart';
import 'package:plain/domain/repositories/repositories.dart';
import 'package:plain/app/l10n/strings_domain.dart';

/// 消费周报开关（Riverpod，UI 绑定用）。
class _WeeklyReportEnabledNotifier extends Notifier<bool> {
  @override
  bool build() {
    WeeklyReportService.isEnabled().then((v) {
      if (v != state) state = v;
    });
    return true;
  }

  void toggle(bool v) {
    state = v;
    WeeklyReportService.setEnabled(v);
  }
}

final weeklyReportEnabledProvider =
    NotifierProvider<_WeeklyReportEnabledNotifier, bool>(_WeeklyReportEnabledNotifier.new);

/// 周报数据。
class WeeklyReport {
  const WeeklyReport({
    required this.weekStart,
    required this.weekEnd,
    required this.totalExpenseCents,
    required this.totalIncomeCents,
    required this.entryCount,
    required this.topCategories,
    required this.highlights,
    required this.isComparedToLastWeek,
    required this.expenseChangePercent,
    this.largestExpenseCents = 0,
  });

  final String weekStart;
  final String weekEnd;
  final int totalExpenseCents;
  final int totalIncomeCents;
  final int entryCount;

  /// 分类占比（name → cents）。
  final Map<String, int> topCategories;

  /// 高亮文案（只陈述、只夸不贬）。
  final List<String> highlights;

  /// 是否与上周对比。
  final bool isComparedToLastWeek;

  /// 支出环比变化（%）。正 = 增加。对比口径为上周**同期**。
  final double expenseChangePercent;

  /// 本周单笔最大支出（分）；0 = 本周无支出。
  final int largestExpenseCents;

  bool get isEmpty => entryCount == 0 && totalExpenseCents == 0 && totalIncomeCents == 0;

  /// 占比最高的分类名（无支出时为 null）。
  String? get topCategory {
    if (topCategories.isEmpty) return null;
    final sorted = topCategories.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first.key;
  }

  /// 生成周报正文（免费简版，1 屏）。
  String summary(AppStrings s) {
    final buf = StringBuffer('${s.wrSummaryTitle}\n');
    buf.writeln(
        s.wrExpenseLine((totalExpenseCents / 100).toStringAsFixed(2), entryCount));
    if (isComparedToLastWeek) {
      final dir = expenseChangePercent >= 0 ? s.wrUp : s.wrDown;
      buf.writeln(
          s.wrMonthOverMonth(dir, expenseChangePercent.abs().toStringAsFixed(0)));
    }
    for (final h in highlights) {
      buf.writeln(h);
    }
    return buf.toString();
  }

  /// 系统通知正文（一行，中性陈述）。
  String notificationBody(AppStrings s) {
    if (totalExpenseCents == 0 && totalIncomeCents == 0) {
      return s.wrNoRecords;
    }
    final parts = <String>[
      s.wrExpenseOnly((totalExpenseCents / 100).toStringAsFixed(2)),
    ];
    if (totalExpenseCents > 0) parts.add(s.wrMainCategory(topCategory ?? s.other));
    parts.add(s.wrCountLine(entryCount));
    return parts.join(' · ');
  }
}

/// 周报服务：生成 + 推送偏好管理。
class WeeklyReportService {
  /// 「本周」的起点：本周一 00:00（本地时区）。
  static DateTime weekStartOf(DateTime local) {
    final d = local.toLocal();
    final monday = DateTime(d.year, d.month, d.day)
        .subtract(Duration(days: d.weekday - WeeklyReportRules.weekStartWeekday));
    return monday;
  }

  /// 本周的推送时刻：周日 20:00（本地时区）。
  static DateTime weekDueAt(DateTime local) {
    final d = local.toLocal();
    return weekStartOf(d).add(Duration(
      days: WeeklyReportRules.pushWeekday - WeeklyReportRules.weekStartWeekday,
      hours: WeeklyReportRules.pushHour,
    ));
  }

  /// 周标识（本周一的日期）。同一周内重复判定与去重都用它。
  static String weekKeyOf(DateTime local) => Clock.dayKeyOf(weekStartOf(local));

  /// 检查是否应推送。
  ///
  /// 口径：开关开着、且**本周的周日 20:00 已过**、且本周尚未推过。
  /// 素记没有后台唤醒（离线、不常驻），因此到点后首次启动补发——宁可晚到，
  /// 不能因为那一刻没开 App 就整周没有周报。
  static Future<bool> shouldPush(DateTime now) async {
    try {
      final sp = await SharedPreferences.getInstance();
      final enabled = sp.getBool(WeeklyReportRules.kPrefEnabled) ?? true;
      if (!enabled) return false;

      final local = now.toLocal();
      if (local.isBefore(weekDueAt(local))) return false;

      final lastPush = sp.getString(WeeklyReportRules.kPrefLastPush) ?? '';
      return lastPush != weekKeyOf(local);
    } catch (_) {
      return false;
    }
  }

  /// 标记已推送。
  static Future<void> markPushed(DateTime now) async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(WeeklyReportRules.kPrefLastPush, weekKeyOf(now.toLocal()));
    } catch (_) {}
  }

  /// 读取/保存推送开关。
  static Future<bool> isEnabled() async {
    try {
      final sp = await SharedPreferences.getInstance();
      return sp.getBool(WeeklyReportRules.kPrefEnabled) ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> setEnabled(bool v) async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setBool(WeeklyReportRules.kPrefEnabled, v);
    } catch (_) {}
  }

  /// 提醒方式（AC1「静默或响铃按用户设置」）。
  static Future<ReminderLevel> level() async {
    try {
      final sp = await SharedPreferences.getInstance();
      return sp.getString(WeeklyReportRules.kPrefLevel) == ReminderLevel.silent.wire
          ? ReminderLevel.silent
          : ReminderLevel.ring;
    } catch (_) {
      return ReminderLevel.ring;
    }
  }

  static Future<void> setLevel(ReminderLevel v) async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(WeeklyReportRules.kPrefLevel, v.wire);
    } catch (_) {}
  }

  /// 从本周和上周的分类支出生成周报。
  ///
  /// [lastWeekExpenseCents] 必须是**上周同期**合计；
  /// [lastWeekCategories] 同为上周同期的分类支出（缺省则不写占比变化）。
  static WeeklyReport generate({
    required AppStrings s,
    required String weekStart,
    required String weekEnd,
    required int totalExpenseCents,
    required int totalIncomeCents,
    required int entryCount,
    required Map<String, int> topCategories,
    required int lastWeekExpenseCents,
    Map<String, int> lastWeekCategories = const {},
    int largestExpenseCents = 0,
  }) {
    final highlights = <String>[];
    double changePercent = 0;
    final hasComparison = lastWeekExpenseCents > 0;

    if (hasComparison) {
      changePercent = ((totalExpenseCents - lastWeekExpenseCents) / lastWeekExpenseCents * 100);
      // 只陈述、只夸不贬
      if (changePercent < -10) {
        highlights.add(s.wrHighlightLess);
      } else if (changePercent > 10) {
        highlights.add(s.wrHighlightMore);
      }
    }

    // 最大分类（占比一并陈述，不含评价）
    if (topCategories.isNotEmpty && totalExpenseCents > 0) {
      final sorted = topCategories.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final top = sorted.first;
      final share = (top.value * 100 / totalExpenseCents).round();
      highlights.add(s.wrTopCategory(top.key, share));
    }

    // 占比变化：只取变化最大的一条，纯陈述（百分点阈值见规则常量）。
    // ⚠️ 上周分类缺失（`lastWeekCategories` 为空）时**不写**这条：
    // 「没有数据」不等于上周占比 0%，否则每一条都会变成「0% → N%」的假结论。
    if (topCategories.isNotEmpty &&
        lastWeekCategories.isNotEmpty &&
        totalExpenseCents > 0 &&
        lastWeekExpenseCents > 0) {
      final cur = topCategories.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      for (final e in cur) {
        final curPct = e.value * 100 / totalExpenseCents;
        final prevCents = lastWeekCategories[e.key];
        final prevPct = prevCents == null ? 0.0 : prevCents * 100 / lastWeekExpenseCents;
        if (curPct - prevPct >= WeeklyReportRules.shareShiftPoints) {
          highlights.add(s.wrShareShift(e.key, prevPct.round(), curPct.round()));
          break;
        }
      }
    }

    // 单笔最大（PRD「异常大额」，用中性措辞，不作评判）
    if (largestExpenseCents > 0) {
      highlights.add(s.wrLargest((largestExpenseCents / 100).toStringAsFixed(2)));
    }

    return WeeklyReport(
      weekStart: weekStart,
      weekEnd: weekEnd,
      totalExpenseCents: totalExpenseCents,
      totalIncomeCents: totalIncomeCents,
      entryCount: entryCount,
      topCategories: topCategories,
      highlights: highlights,
      isComparedToLastWeek: hasComparison,
      expenseChangePercent: changePercent,
      largestExpenseCents: largestExpenseCents,
    );
  }

  /// 从库里取数生成周报。所有金额来自 daily_stats / transactions，无写死数据。
  static Future<WeeklyReport> build({
    required AppStrings s,
    required LedgerRepository ledger,
    required CategoryRepository categories,
    required Clock clock,
    required String bookId,
    DateTime? now,
  }) async {
    final at = (now ?? clock.now()).toLocal();
    final start = weekStartOf(at);
    final today = DateTime(at.year, at.month, at.day);
    // 已过天数（含今天）：上周取同样天数，保证同期对比
    final elapsedDays = today.difference(start).inDays + 1;
    final lastStart = start.subtract(const Duration(days: 7));
    final todayEnd = DateTime(at.year, at.month, at.day).add(const Duration(days: 1));
    final lastEnd = lastStart.add(Duration(days: elapsedDays));

    final curRes = await ledger.monthSummary(
      bookId: bookId,
      dayFrom: Clock.dayKeyOf(start),
      dayTo: Clock.dayKeyOf(today),
    );
    final prevRes = await ledger.monthSummary(
      bookId: bookId,
      dayFrom: Clock.dayKeyOf(lastStart),
      dayTo: Clock.dayKeyOf(lastEnd.subtract(const Duration(days: 1))),
    );
    final cur = curRes.successOrNull;
    final prev = prevRes.successOrNull;

    // 单笔最大走 transactions；day_key 是本地日、occurred_at 是 UTC 毫秒，
    // 因此本地日边界要先 toUtc 再取毫秒，两端口径才对齐。
    final maxRes = await ledger.maxExpenseCents(
      bookId: bookId,
      fromMs: start.toUtc().millisecondsSinceEpoch,
      toMs: todayEnd.toUtc().millisecondsSinceEpoch,
    );

    final catRes = await categories.listAll(kind: CategoryKind.expense);
    final nameOf = {
      for (final Category c in catRes.successOrNull ?? const <Category>[]) c.id: c.name,
    };

    Map<String, int> byName(MonthSummary? m) {
      final out = <String, int>{};
      if (m == null) return out;
      for (final e in m.byCategory.entries) {
        if (e.value.expenseCents <= 0) continue;
        final name = nameOf[e.key] ?? s.other;
        out[name] = (out[name] ?? 0) + e.value.expenseCents;
      }
      return out;
    }

    final curCats = byName(cur);
    final prevCats = byName(prev);

    return generate(
      s: s,
      weekStart: Clock.dayKeyOf(start),
      weekEnd: Clock.dayKeyOf(today),
      totalExpenseCents: cur?.expenseCents ?? 0,
      totalIncomeCents: cur?.incomeCents ?? 0,
      entryCount: cur?.txCount ?? 0,
      topCategories: curCats,
      lastWeekExpenseCents: prev?.expenseCents ?? 0,
      lastWeekCategories: prevCats,
      largestExpenseCents: maxRes.successOrNull ?? 0,
    );
  }

  /// 到点则生成并推系统通知。返回是否真的推送了。
  static Future<bool> pushIfDue({
    required AppStrings s,
    required LedgerRepository ledger,
    required CategoryRepository categories,
    required Clock clock,
    required String bookId,
  }) async {
    try {
      final now = clock.now();
      if (!await shouldPush(now)) return false;

      final report = await build(
        s: s,
        ledger: ledger,
        categories: categories,
        clock: clock,
        bookId: bookId,
        now: now,
      );
      // 本周没有任何记录就没有可陈述的内容；同样标记已推，避免反复尝试。
      if (report.isEmpty) {
        await markPushed(now);
        return false;
      }

      final reminderLevel = applyQuietHours(await level(), now);
      await NotificationBridge.show(
        id: WeeklyReportRules.notificationId,
        title: s.wrSummaryTitle,
        body: report.notificationBody(s),
        payload: 'weekly_report',
        silent: reminderLevel == ReminderLevel.silent,
      );
      await markPushed(now);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 夜间免打扰（G-3）：与提醒中心同一组阈值，响铃降为静默。
  static ReminderLevel applyQuietHours(ReminderLevel level, DateTime at) {
    final h = at.toLocal().hour;
    final quiet = h >= ReminderRules.quietStartHour || h < ReminderRules.quietEndHour;
    return quiet ? ReminderLevel.silent : level;
  }
}
