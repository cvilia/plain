/// Product constants. See 05-C3.
library;

class MoneyRules {
  MoneyRules._();
  static const int maxAmountCents = 9999999999;
  static const int decimalDigits = 2;
  static const String defaultCurrency = 'CNY';
}

/// STORY-9.3 多币种。
class CurrencyRules {
  CurrencyRules._();
  /// 常用币种符号；未知币种回退为代码本身。
  static const Map<String, String> symbols = {
    'CNY': '¥',
    'USD': r'$',
    'EUR': '€',
    'GBP': '£',
    'JPY': 'JP¥',
    'HKD': r'HK$',
    'TWD': r'NT$',
    'KRW': '₩',
    'SGD': r'S$',
    'AUD': r'A$',
    'CAD': r'C$',
  };

  static String symbolOf(String code) => symbols[code] ?? code;
}

class CategoryRules {
  CategoryRules._();
  static const int maxNameLength = 6;
  static const int maxHierarchyDepth = 2;
  static const int gridPageSize = 8;
  static const int sortOrderStep = 10;
}

class PagingRules {
  PagingRules._();
  static const int pageSize = 50;
  static const int prefetchThreshold = 10;
}

class DraftRules {
  DraftRules._();
  static const Duration draftTtl = Duration(hours: 24);
}

class UiDurations {
  UiDurations._();
  static const Duration saveToast = Duration(milliseconds: 1500);
  static const Duration undoWindow = Duration(seconds: 5);
  static const Duration revealBalance = Duration(seconds: 5);
  static const Duration shortAnim = Duration(milliseconds: 160);
}

class TrashRules {
  TrashRules._();
  /// Soft-deleted rows are physically purged after this window.
  /// Matches the recycle-bin retention period (PRD F7.7).
  static const Duration trashTtl = Duration(days: 30);
}

/// STORY-6.2 分割交易。
class SplitRules {
  SplitRules._();
  /// 一笔最多拆成多少子笔（PRD STORY-6.2）。
  static const int maxChildren = 10;
  static const int minChildren = 2;
  /// 未分类占位分类 id（合并回父笔时使用）。
  static const String uncategorizedId = 'other';
}

/// STORY-6.3 提醒中心。
class ReminderRules {
  ReminderRules._();
  /// 夜间免打扰（G-3）：响铃降级为静默。
  static const int quietStartHour = 23;
  static const int quietEndHour = 7;
  /// 汇总推送时刻（次日）。
  static const int summaryHour = 8;
  /// 提醒历史保留天数。
  static const Duration historyTtl = Duration(days: 90);
  /// 信用卡还款提醒提前天数。
  static const int creditDueAheadDays = 3;
  /// 异常支出：单笔 > 近 90 天 P90 的倍数。
  static const double anomalyP90Factor = 2.0;
  /// 备份提醒间隔。
  static const Duration backupRemindInterval = Duration(days: 30);
  /// 默认预算预警阈值。
  static const double budgetWarnRatio = 0.8;
  static const double budgetOverRatio = 1.0;
}

/// STORY-7.1 沉淀基金 / 储蓄目标。
class SavingsRules {
  SavingsRules._();
  /// 每月需存 =（目标 − 已存）÷ 剩余月数；剩余月数至少按 1 算，避免除零。
  static const int minRemainingMonths = 1;
}

/// STORY-2.2 信用卡。
class CreditCardRules {
  CreditCardRules._();
  /// 账单日 / 还款日取值范围（PRD：1–28）。
  static const int minDay = 1;
  static const int maxDay = 28;
  /// 未配置还款日时的默认免息宽限天数。
  static const int defaultGraceDays = 20;
}

/// STORY-5.4 情绪反馈 + STORY-6.3 异常提醒共同统计口径。
class StatsWindowRules {
  StatsWindowRules._();
  /// 统计窗口：该分类近 N 天已入账支出账单。
  static const int windowDays = 90;
  /// 最小样本量：不足此数不触发任何阈值反馈。
  static const int minSamples = 5;
  /// 高额阈值：单笔金额 > 该分类 P90 的 N 倍。
  static const double highAmountMultiplier = 2.0;
}

/// STORY-5.4 情绪反馈。
class EmotionFeedbackRules {
  EmotionFeedbackRules._();
  /// 每周最多触发次数（防轰炸）。
  static const int weeklyMaxCount = 3;
  /// 每周计数的本地键。
  static const String kPrefEnabled = 'pref.emotion.enabled';
  static const String kPrefWeekCount = 'pref.emotion.week_count';
  static const String kPrefWeekKey = 'pref.emotion.week_key';
  /// 反馈卡片自动消失时长。
  static const Duration cardDuration = Duration(seconds: 4);
}

/// STORY-5.5 游戏化留存：连续记账 + 成就徽章 + 权益券。
class GamificationRules {
  GamificationRules._();
  /// 连续记账里程碑：达到该天数发放权益券。
  static const Map<int, int> streakVoucherMilestones = {
    7: 1,   // 连续 7 天 → 权益券 ×1
    30: 3,  // 连续 30 天 → 权益券 ×3
    100: 0, // 连续 100 天 → 终身卡抽奖资格（券数 0 表示特殊奖励）
  };
  /// 累计记账笔数徽章阈值。
  static const List<int> entryCountMilestones = [100, 500, 1000, 5000, 10000];
  /// 权益券生效版本标注。
  static const String voucherActivateLabel = 'V4.0 起生效';
  /// 本地存储键。
  static const String kPrefStreakDays = 'pref.game.streak_days';
  static const String kPrefStreakBest = 'pref.game.streak_best';
  static const String kPrefLastEntryDay = 'pref.game.last_entry_day';
  static const String kPrefVouchers = 'pref.game.vouchers';
  static const String kPrefBadges = 'pref.game.badges';
  static const String kPrefTotalEntries = 'pref.game.total_entries';
}

/// 成就徽章类别。
enum BadgeCategory {
  persistence('persistence', '坚持'),
  exploration('exploration', '探索'),
  discipline('discipline', '节制'),
  accumulation('accumulation', '积累'),
  goal('goal', '目标');

  const BadgeCategory(this.id, this.label);
  final String id;
  final String label;
}

/// STORY-9.4 AI 识别记账：额度制。
class AiRecognitionRules {
  AiRecognitionRules._();
  /// 每记账月免费额度（次）。
  static const int monthlyQuota = 10;
  /// 额度计数的本地键。
  static const String kPrefMonthKey = 'pref.ai.month_key';
  static const String kPrefMonthCount = 'pref.ai.month_count';
  /// 识别结果预填超时。
  static const Duration parseTimeout = Duration(seconds: 5);
}

/// STORY-9.5 AI 消费周报。
class WeeklyReportRules {
  WeeklyReportRules._();
  /// 推送时间：周日 20:00。
  static const int pushWeekday = DateTime.sunday;
  static const int pushHour = 20;
  /// 本地键。
  static const String kPrefEnabled = 'pref.weekly_report.enabled';
  static const String kPrefLastPush = 'pref.weekly_report.last_push';
}
