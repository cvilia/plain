/// Product constants. See 05-C3.
library;

class MoneyRules {
  MoneyRules._();
  static const int maxAmountCents = 9999999999;
  static const int decimalDigits = 2;
  static const String defaultCurrency = 'CNY';
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
