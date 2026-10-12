/// STORY-5.4 情绪反馈：阈值触发、只夸不贬、可关闭、每周限量。
/// 统计口径与 STORY-6.3 共用（StatsWindowRules）。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:plain/core/constants/app_constants.dart';

/// 情绪反馈开关（Riverpod，UI 绑定用）。
class _EmotionEnabledNotifier extends Notifier<bool> {
  @override
  bool build() {
    EmotionFeedbackPrefs.isEnabled().then((v) {
      if (v != state) state = v;
    });
    return true;
  }

  void toggle(bool v) {
    state = v;
    EmotionFeedbackPrefs.setEnabled(v);
  }
}

final emotionEnabledProvider = NotifierProvider<_EmotionEnabledNotifier, bool>(_EmotionEnabledNotifier.new);

/// 反馈类型。
enum EmotionKind {
  /// 单笔 ≤ 分类中位数：正面肯定。
  positive,
  /// 单笔 > P90 × 2：中性陈述。
  large,
  /// 本月首次记账。
  monthFirst,
  /// 达成储蓄目标。
  goalAchieved,
}

class EmotionFeedback {
  const EmotionFeedback(this.kind, this.message);
  final EmotionKind kind;
  final String message;
}

/// 读取/保存情绪反馈偏好。
class EmotionFeedbackPrefs {
  static Future<bool> isEnabled() async {
    try {
      final sp = await SharedPreferences.getInstance();
      return sp.getBool(EmotionFeedbackRules.kPrefEnabled) ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> setEnabled(bool v) async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setBool(EmotionFeedbackRules.kPrefEnabled, v);
    } catch (_) {}
  }

  /// 当前周 key（ISO 周）。
  static String _weekKey(DateTime now) {
    final jan1 = DateTime(now.year, 1, 1);
    final week = ((now.difference(jan1).inDays + jan1.weekday - 1) / 7).ceil();
    return '${now.year}-W$week';
  }

  /// 是否还能触发（每周 ≤ weeklyMaxCount）。
  static Future<bool> canTrigger(DateTime now) async {
    try {
      final sp = await SharedPreferences.getInstance();
      final key = _weekKey(now);
      if (sp.getString(EmotionFeedbackRules.kPrefWeekKey) != key) {
        // 新周，重置计数
        await sp.setString(EmotionFeedbackRules.kPrefWeekKey, key);
        await sp.setInt(EmotionFeedbackRules.kPrefWeekCount, 0);
      }
      final count = sp.getInt(EmotionFeedbackRules.kPrefWeekCount) ?? 0;
      return count < EmotionFeedbackRules.weeklyMaxCount;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _incrementCount(DateTime now) async {
    try {
      final sp = await SharedPreferences.getInstance();
      final key = _weekKey(now);
      if (sp.getString(EmotionFeedbackRules.kPrefWeekKey) == key) {
        final count = sp.getInt(EmotionFeedbackRules.kPrefWeekCount) ?? 0;
        await sp.setInt(EmotionFeedbackRules.kPrefWeekCount, count + 1);
      }
    } catch (_) {}
  }

  /// 判断某笔支出应给什么反馈。返回 null = 不给反馈。
  ///
  /// [amountCents] 该笔金额；[categoryAmountsCents] 同分类近 90 天已入账支出金额列表；
  /// [isMonthFirstEntry] 是否本月首笔；[isOverBudget] 本月是否已超预算。
  static Future<EmotionFeedback?> evaluate({
    required int amountCents,
    required List<int> categoryAmountsCents,
    required bool isMonthFirstEntry,
    required bool isOverBudget,
    required DateTime now,
    bool isGoalAchieved = false,
  }) async {
    // AC5：超预算不给情绪反馈
    if (isOverBudget) return null;

    // 目标达成优先（不受样本量限制）
    if (isGoalAchieved) {
      final ok = await _checkAndCount(now);
      return ok ? const EmotionFeedback(EmotionKind.goalAchieved, '目标达成！') : null;
    }

    // 本月首次记账
    if (isMonthFirstEntry) {
      final ok = await _checkAndCount(now);
      return ok ? const EmotionFeedback(EmotionKind.monthFirst, '新的一月，从这一笔开始') : null;
    }

    // 样本不足不触发阈值反馈
    if (categoryAmountsCents.length < StatsWindowRules.minSamples) return null;

    final sorted = List<int>.from(categoryAmountsCents)..sort();
    final median = sorted[sorted.length ~/ 2];
    final p90 = sorted[(sorted.length * 0.9).floor().clamp(0, sorted.length - 1)];

    // 正面肯定：≤ 中位数
    if (amountCents <= median) {
      final ok = await _checkAndCount(now);
      return ok ? const EmotionFeedback(EmotionKind.positive, '这笔记得很稳') : null;
    }

    // 中性陈述：> P90 × 2
    if (amountCents > (p90 * StatsWindowRules.highAmountMultiplier)) {
      final ok = await _checkAndCount(now);
      return ok ? const EmotionFeedback(EmotionKind.large, '这笔比平时大一些') : null;
    }

    return null;
  }

  static Future<bool> _checkAndCount(DateTime now) async {
    if (!await isEnabled()) return false;
    if (!await canTrigger(now)) return false;
    await _incrementCount(now);
    return true;
  }
}
