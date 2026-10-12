/// STORY-9.5 AI 消费周报：周日推送、消费画像、可关闭。
/// 文案基调：只陈述 + 只夸不贬。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:plain/core/constants/app_constants.dart';

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

  /// 支出环比变化（%）。正 = 增加。
  final double expenseChangePercent;

  /// 生成周报文案。
  String get summary {
    final buf = StringBuffer('本周消费画像\n');
    buf.writeln('支出 ¥${(totalExpenseCents / 100).toStringAsFixed(2)} · $entryCount 笔');
    if (isComparedToLastWeek) {
      final dir = expenseChangePercent >= 0 ? '上升' : '下降';
      buf.writeln('环比$dir ${expenseChangePercent.abs().toStringAsFixed(0)}%');
    }
    for (final h in highlights) {
      buf.writeln(h);
    }
    return buf.toString();
  }
}

/// 周报服务：生成 + 推送偏好管理。
class WeeklyReportService {
  /// 检查是否应推送（周日 20:00 后、本周未推过）。
  static Future<bool> shouldPush(DateTime now) async {
    try {
      final sp = await SharedPreferences.getInstance();
      final enabled = sp.getBool(WeeklyReportRules.kPrefEnabled) ?? true;
      if (!enabled) return false;

      final lastPush = sp.getString(WeeklyReportRules.kPrefLastPush) ?? '';
      final nowLocal = now.toLocal();
      // 只在周日推送
      if (nowLocal.weekday != WeeklyReportRules.pushWeekday) return false;
      if (nowLocal.hour < WeeklyReportRules.pushHour) return false;

      // 本周是否已推
      final weekKey = _weekKey(nowLocal);
      return lastPush != weekKey;
    } catch (_) {
      return false;
    }
  }

  /// 标记已推送。
  static Future<void> markPushed(DateTime now) async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(WeeklyReportRules.kPrefLastPush, _weekKey(now.toLocal()));
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

  /// 从本周和上周的分类支出生成周报。
  static WeeklyReport generate({
    required String weekStart,
    required String weekEnd,
    required int totalExpenseCents,
    required int totalIncomeCents,
    required int entryCount,
    required Map<String, int> topCategories,
    required int lastWeekExpenseCents,
  }) {
    final highlights = <String>[];
    double changePercent = 0;
    final hasComparison = lastWeekExpenseCents > 0;

    if (hasComparison) {
      changePercent = ((totalExpenseCents - lastWeekExpenseCents) / lastWeekExpenseCents * 100);
      // 只陈述、只夸不贬
      if (changePercent < -10) {
        highlights.add('支出比上周有所减少，继续保持');
      } else if (changePercent > 10) {
        highlights.add('本周有一些特别的开销');
      }
    }

    // 最大分类
    if (topCategories.isNotEmpty) {
      final sorted = topCategories.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final top = sorted.first;
      highlights.add('「${top.key}」是本周主要支出');
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
    );
  }

  static String _weekKey(DateTime dt) {
    final jan1 = DateTime(dt.year, 1, 1);
    final week = ((dt.difference(jan1).inDays + dt.weekday - 1) / 7).ceil();
    return '${dt.year}-W$week';
  }
}
