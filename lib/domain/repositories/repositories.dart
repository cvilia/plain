/// Repository interfaces. See 04-6.1, 05-A4.
library;

import 'package:plain/core/result/result.dart';
import 'package:plain/domain/entities/automation_rule.dart';
import 'package:plain/domain/entities/budget.dart';
import 'package:plain/domain/entities/category.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/entities/ledger_entry.dart';
import 'package:plain/domain/entities/recurring_rule.dart';
import 'package:plain/domain/entities/savings_goal.dart';

class EntryCursor {
  const EntryCursor({required this.occurredAtMs, required this.id});
  final int occurredAtMs;
  final String id;
}

class EntryPage {
  const EntryPage({required this.items, this.nextCursor, this.hasMore = false});
  final List<LedgerEntry> items;
  final EntryCursor? nextCursor;
  final bool hasMore;
}

class EntryFilter {
  const EntryFilter({this.categoryId, this.accountId, this.type, this.fromMs, this.toMs, this.keyword, this.bookId});
  final String? categoryId;
  final String? accountId;
  final String? type;
  final int? fromMs;
  final int? toMs;
  final String? keyword;
  final String? bookId;
}

abstract interface class LedgerRepository {
  Future<Result<LedgerEntry>> create(LedgerEntry entry);
  Future<Result<LedgerEntry>> update(LedgerEntry entry);
  Future<Result<void>> softDelete(String id);
  Future<Result<LedgerEntry>> getById(String id);
  Future<Result<EntryPage>> listPage({EntryFilter? filter, EntryCursor? cursor, int limit = 50});
  Future<Result<MonthSummary>> monthSummary({required String bookId, required String dayFrom, required String dayTo});
  /// List soft-deleted entries, newest deletion first.
  Future<Result<List<LedgerEntry>>> listDeleted({String? bookId, int limit = 100});
  /// Restore a soft-deleted entry (clears deleted_at, restores daily_stats).
  Future<Result<LedgerEntry>> restore(String id);
  /// Physically delete a single soft-deleted entry by id.
  Future<Result<void>> hardDelete(String id);
  /// Physically delete soft-deleted rows older than [before]. Returns count purged.
  Future<Result<int>> purgeExpired({required DateTime before});
  /// Return fingerprints of live entries in [fromMs, toMs] for import dedup.
  Future<Result<Set<String>>> fingerprintsInRange({required int fromMs, required int toMs});
  /// 08-§8 巡检：比对 transactions 行数与 daily_stats.tx_count 合计。
  /// 返回 true 表示一致；false 表示需要重建。
  Future<Result<bool>> verifyDailyStats();
  /// 08-§8 重建：单事务清空 daily_stats 后由 transactions 全量重算。
  Future<Result<void>> rebuildDailyStats();
}

class MonthSummary {
  const MonthSummary({required this.expenseCents, required this.incomeCents, required this.txCount, required this.byCategory});
  final int expenseCents;
  final int incomeCents;
  final int txCount;
  final Map<String, CategoryAgg> byCategory;
  int get balanceCents => incomeCents - expenseCents;
}

class CategoryAgg {
  const CategoryAgg({required this.expenseCents, required this.incomeCents, required this.txCount});
  final int expenseCents;
  final int incomeCents;
  final int txCount;
}

abstract interface class CategoryRepository {
  Future<Result<List<Category>>> listVisible({CategoryKind? kind});
  Future<Result<List<Category>>> listAll({CategoryKind? kind});
  Future<Result<Category>> getById(String id);
  Future<Result<Category>> create(Category category);
  Future<Result<Category>> update(Category category);
  Future<Result<void>> softDelete(String id);
  /// Move a second-level category under a different first-level parent.
  ///
  /// Transactions stay on the category — only [Category.parentId] changes.
  /// First-level groups cannot be moved.
  Future<Result<Category>> moveToParent({
    required String categoryId,
    required String newParentId,
  });

  /// Count live transactions on [categoryId] (and optionally its descendants).
  Future<Result<int>> countLiveEntries({
    required String categoryId,
    bool includeDescendants = false,
  });

  /// Soft-delete [categoryId] (and descendants when requested), moving every
  /// live transaction to [fallbackCategoryId] (typically the default 其他).
  Future<Result<int>> deleteAndReassign({
    required String categoryId,
    required String fallbackCategoryId,
    bool includeDescendants = false,
  });

  /// STORY-1.3 AC11–13：同层级合并。
  /// 一级合并时，其下二级整体迁到目标一级；同名二级并入目标同名项。
  Future<Result<CategoryMergeResult>> mergeCategories({
    required String sourceId,
    required String targetId,
  });
}

class CategoryMergeResult {
  const CategoryMergeResult({
    required this.movedEntries,
    required this.movedChildren,
    required this.mergedSameNameChildren,
  });
  final int movedEntries;
  final int movedChildren;
  final int mergedSameNameChildren;
  int get totalAffected => movedEntries + movedChildren + mergedSameNameChildren;
}

class AccountWithBalance {
  const AccountWithBalance({
    required this.account,
    required this.balanceCents,
  });
  final Account account;
  final int balanceCents;
}

abstract interface class AccountRepository {
  Future<Result<List<Account>>> listAll();
  /// Accounts plus derived balance in one query (replaces UI-side N+1).
  Future<Result<List<AccountWithBalance>>> listWithBalances();
  Future<Result<Account>> getById(String id);
  Future<Result<Account>> create(Account account);
  Future<Result<Account>> update(Account account);
  Future<Result<void>> softDelete(String id);
  Future<Result<AccountBalance>> balanceOf(String accountId);
  Future<Result<void>> reconcile({required String accountId, required int actualBalanceCents, required String deviceId, required String bookId, required String otherCategoryId});
  /// STORY-2.1 AC6：删除前的引用统计（账单/转入/周期/预算）。
  Future<Result<AccountRefCounts>> countReferences(String accountId);
  /// 把 [fromId] 上的账单引用迁到 [toId]（含转出/转入两侧）。
  Future<Result<int>> migrateTransactions({required String fromId, required String toId});
}

/// 账户被引用的四类来源（STORY-2.1 AC6）。
class AccountRefCounts {
  const AccountRefCounts({
    required this.transactions,
    required this.transferIn,
    required this.recurringRules,
    required this.budgets,
  });
  final int transactions;
  final int transferIn;
  final int recurringRules;
  final int budgets;
  int get total => transactions + transferIn + recurringRules + budgets;
  bool get isEmpty => total == 0;
}

/// STORY-6.1 自动化规则。
abstract interface class AutomationRuleRepository {
  Future<Result<List<AutomationRule>>> listEnabled({String? bookId, RuleStage? stage});
  Future<Result<List<AutomationRule>>> listAll({String? bookId});
  Future<Result<AutomationRule>> getById(String id);
  Future<Result<AutomationRule>> create(AutomationRule rule);
  Future<Result<AutomationRule>> update(AutomationRule rule);
  Future<Result<void>> softDelete(String id);
  /// 命中条数（变更预览用）。
  Future<Result<int>> countMatches({required String bookId, required List<RuleCondition> conditions});
}

/// STORY-7.1 储蓄目标。
abstract interface class SavingsGoalRepository {
  Future<Result<List<SavingsGoal>>> listByBook(String bookId);
  Future<Result<SavingsGoal>> getById(String id);
  Future<Result<SavingsGoal>> create(SavingsGoal goal);
  Future<Result<SavingsGoal>> update(SavingsGoal goal);
  Future<Result<void>> softDelete(String id);
  /// 存入金额（累加 saved_cents）。
  Future<Result<SavingsGoal>> deposit({required String goalId, required int amountCents});
}

abstract interface class BudgetRepository {
  Future<Result<Budget>> getTotal(String bookId);
  Future<Result<List<Budget>>> listByBook(String bookId);
  Future<Result<Budget>> create(Budget budget);
  Future<Result<Budget>> update(Budget budget);
  Future<Result<void>> softDelete(String id);
  /// Expense cents in [fromMs, toMs) for the whole book (scope=total)
  /// or a single category and its children (scope=category).
  Future<Result<int>> spentCents({
    required String bookId, String? categoryId,
    required int fromMs, required int toMs,
  });
}

abstract interface class RecurringRepository {
  Future<Result<List<RecurringRule>>> listByBook(String bookId);
  Future<Result<List<RecurringRule>>> listDue({required DateTime now});
  Future<Result<RecurringRule>> getById(String id);
  Future<Result<RecurringRule>> create(RecurringRule rule);
  Future<Result<RecurringRule>> update(RecurringRule rule);
  Future<Result<void>> softDelete(String id);
  /// Soft-delete every transaction generated by [batchId]. Returns count.
  Future<Result<int>> undoBatch({required String batchId, required DateTime deletedAt});
}
