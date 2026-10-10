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
