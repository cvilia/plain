/// Repository interfaces. See 04-6.1, 05-A4.
library;

import 'package:plain/core/result/result.dart';
import 'package:plain/domain/entities/attachment.dart';
import 'package:plain/domain/entities/automation_rule.dart';
import 'package:plain/domain/entities/budget.dart';
import 'package:plain/domain/entities/category.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/entities/currency_rate.dart';
import 'package:plain/domain/entities/holding.dart';
import 'package:plain/domain/entities/ledger_entry.dart';
import 'package:plain/domain/entities/member.dart';
import 'package:plain/domain/entities/merchant_rule.dart';
import 'package:plain/domain/entities/recurring_rule.dart';
import 'package:plain/domain/entities/reminder.dart';
import 'package:plain/domain/entities/saved_report.dart';
import 'package:plain/domain/entities/savings_goal.dart';
import 'package:plain/domain/entities/tax_filing.dart';

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
  const EntryFilter({this.categoryId, this.accountId, this.type, this.fromMs, this.toMs, this.keyword, this.bookId, this.minAmountCents, this.maxAmountCents, this.memberId});
  final String? categoryId;
  final String? accountId;
  final String? type;
  final int? fromMs;
  final int? toMs;
  final String? keyword;
  final String? bookId;
  final int? minAmountCents;
  final int? maxAmountCents;

  /// STORY-8.2：归属成员。
  final String? memberId;
}

abstract interface class LedgerRepository {
  Future<Result<LedgerEntry>> create(LedgerEntry entry);
  Future<Result<LedgerEntry>> update(LedgerEntry entry);
  Future<Result<void>> softDelete(String id);
  Future<Result<LedgerEntry>> getById(String id);
  Future<Result<EntryPage>> listPage({EntryFilter? filter, EntryCursor? cursor, int limit = 50});
  Future<Result<MonthSummary>> monthSummary({required String bookId, required String dayFrom, required String dayTo});
  /// [fromMs, toMs) 内单笔最大支出（分）；无支出返回 0。
  /// 供 STORY-9.5 周报的「本周单笔最大」陈述使用，与
  /// [monthSummary] 共用同一套统计口径。
  Future<Result<int>> maxExpenseCents({required String bookId, required int fromMs, required int toMs});

  /// STORY-8.2 AC3：按**归属成员**汇总（笔数与收支）。
  /// 未指定归属的老账单一并归到空 memberId 组里，不丢数据。
  Future<Result<List<MemberAgg>>> memberSummary({
    required String bookId,
    required int fromMs,
    required int toMs,
  });

  /// STORY-8.1：把同步合并后的账单写回。
  ///
  /// 与普通写入**同口径**地维护 `daily_stats` 与信用卡欠款（跨端合并不能
  /// 绕过统计单点），但**不写 change_log**——这条变更来自远端，再记一次会两头乒乓。
  /// [softDelete] 为 true 时按远端删除处理（`columns` 忽略）。
  Future<Result<void>> applySyncedEntry({
    required String id,
    required bool softDelete,
    required DateTime changedAt,
    Map<String, Object?> columns,
  });
  /// List soft-deleted entries, newest deletion first.
  Future<Result<List<LedgerEntry>>> listDeleted({String? bookId, int limit = 100});
  /// Restore a soft-deleted entry (clears deleted_at, restores daily_stats).
  Future<Result<LedgerEntry>> restore(String id);
  /// 按批次软删除一组账单（周期生成的批次撤销）。
  ///
  /// **必须走这里，而不是直接改 `transactions`**：撤销要同步回滚 `daily_stats`
  /// 与信用卡欠款余额，否则当月合计会一直偏大——只有冷启动巡检才发现。
  Future<Result<int>> softDeleteBatch({
    required String batchId,
    required DateTime at,
  });
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
  ///
  /// 按 G-2 的分类计数口径：排除对账调整——它的分类恒为「其他」，但不该出现在
  /// 任何分类的「N 笔」里。手动标记「不计入收支」的账单**仍计入**（它是一笔真实
  /// 账单）。
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

/// STORY-1.6 商户学习。
abstract interface class MerchantRuleRepository {
  Future<Result<List<MerchantRule>>> listByBook(String bookId);

  /// 学习一条「备注 → 分类」：同商户已存在则命中 +1 并更新分类。
  Future<Result<MerchantRule>> learn({
    required String bookId,
    required String merchant,
    required String categoryId,
    required String deviceId,
  });

  /// 忘掉某条学习（软删）。
  Future<Result<void>> forget(String id);
}

/// STORY-1.5 账单附件（元数据；文件本体在附件目录）。
///
/// **不写 change_log**：PRD 明确附件不进云同步（体量），
/// 因此附件元数据只随备份包走，不参与增量同步。
abstract interface class AttachmentRepository {
  /// 某笔账单的附件（按 sort_order）。
  Future<Result<List<Attachment>>> listByEntry(String entryId, {bool includeDeleted = false});

  /// 某笔账单的**有效**附件数（上限判定用）。
  Future<Result<int>> countByEntry(String entryId);

  Future<Result<Attachment>> getById(String id);

  Future<Result<Attachment>> create(Attachment attachment);

  /// 单张软删（用户在详情页移除）。
  Future<Result<void>> softDelete(String id);

  /// 账单被删 → 该笔附件全部标记孤儿（30 天内随回收站恢复）。
  Future<Result<int>> markOrphanedByEntry(String entryId, DateTime at);

  /// 账单被恢复 → 该笔孤儿标记清除。
  Future<Result<int>> restoreByEntry(String entryId);

  /// 超过保留期的孤儿附件（供巡检物理清理）。
  Future<Result<List<Attachment>>> listExpiredOrphans(DateTime cutoff);

  /// 物理删除（清理孤儿后调用）。
  Future<Result<void>> hardDelete(String id);
}

/// STORY-8.2 家庭共享：成员与 AA 参与人。
///
/// 成员**软删除**：退出（`status = left`）后记录保留，历史账单的 member_id
/// 仍指向它，只是不再占名额、不再出现在选择器里（AC4）。
abstract interface class MemberRepository {
  Future<Result<List<Member>>> listByBook(String bookId, {bool includeLeft = true});

  /// 活跃成员数（6 人名额只看这个数）。
  Future<Result<int>> countActive(String bookId);

  Future<Result<Member>> getById(String id);

  /// 本机用户（「我」）；未初始化时为 null。
  Future<Result<Member?>> getMe(String bookId);

  Future<Result<Member>> create(Member member);
  Future<Result<Member>> update(Member member);

  /// 物理登记意义上的删除（仍为软删，保留历史归属）。
  Future<Result<void>> softDelete(String id);

  /// 退出家庭账本：状态置 left，不占名额（AC4）。
  Future<Result<void>> leave(String id, DateTime at);

  /// 某笔账单的 AA 参与人。
  Future<Result<List<EntryParticipant>>> participantsOf(String entryId);

  /// 覆盖式设置参与人（整组替换，保持 sort_order = 传入顺序）。
  Future<Result<void>> setParticipants({
    required String entryId,
    required String bookId,
    required List<String> memberIds,
    required String deviceId,
  });
}

/// STORY-9.3 锁定汇率（用户手填，跨重启保留）。
abstract interface class CurrencyRateRepository {
  Future<Result<List<CurrencyRate>>> listByBook(String bookId);

  /// 设定或覆盖某个币种对的锁定汇率（按 currency_rates 的唯一索引 upsert）。
  Future<Result<CurrencyRate>> setRate({
    required String bookId,
    required String fromCurrency,
    required String toCurrency,
    required double rate,
    required String deviceId,
  });

  /// 解除某币种对的锁定。
  Future<Result<void>> removeRate({
    required String bookId,
    required String fromCurrency,
    required String toCurrency,
  });
}

/// STORY-11.5 税务申报状态。
abstract interface class TaxFilingRepository {
  Future<Result<List<TaxFiling>>> listByBook(String bookId);

  /// 标记某个周期「已申报」。
  Future<Result<TaxFiling>> markFiled({
    required String id,
    required String bookId,
    required String periodKey,
    required TaxPeriodKind periodKind,
    required String deviceId,
    String? note,
  });

  /// 取消申报（软删）。
  Future<Result<void>> unmarkFiled(String id);
}

/// STORY-11.3「我的报表」。
abstract interface class SavedReportRepository {
  Future<Result<List<SavedReport>>> listByBook(String bookId);
  Future<Result<SavedReport>> create(SavedReport report);
  Future<Result<SavedReport>> update(SavedReport report);
  Future<Result<void>> softDelete(String id);
}

/// STORY-10.1 投资持仓。
abstract interface class HoldingRepository {
  Future<Result<List<Holding>>> listByAccount(String accountId);
  Future<Result<List<Holding>>> listByBook(String bookId);
  Future<Result<Holding>> getById(String id);
  Future<Result<Holding>> create(Holding holding);
  Future<Result<Holding>> update(Holding holding);
  Future<Result<void>> softDelete(String id);
}

abstract interface class AccountRepository {
  Future<Result<List<Account>>> listAll();
  /// Accounts plus derived balance in one query (replaces UI-side N+1).
  ///
  /// G-2.1：信用卡取存储的欠款余额的负值，其余类型走五段式派生。
  Future<Result<List<AccountWithBalance>>> listWithBalances();
  Future<Result<Account>> getById(String id);
  Future<Result<Account>> create(Account account);
  Future<Result<Account>> update(Account account);
  Future<Result<void>> softDelete(String id);
  Future<Result<AccountBalance>> balanceOf(String accountId);
  /// 恒走五段式派生，不适用 G-2.1 的信用卡例外。
  ///
  /// 信用卡对账页的「按账单聚合」校验用它（STORY-2.2 AC8）。
  Future<Result<AccountBalance>> derivedBalanceOf(String accountId);
  Future<Result<void>> reconcile({required String accountId, required int actualBalanceCents, required String deviceId, required String bookId, required String otherCategoryId});
  /// STORY-2.1 AC6：删除前的引用统计（账单/转入/周期/预算）。
  Future<Result<AccountRefCounts>> countReferences(String accountId);
  /// 把 [fromId] 上的账单引用迁到 [toId]（含转出/转入两侧）。
  Future<Result<int>> migrateTransactions({required String fromId, required String toId});
  /// 把该账户的账单/周期规则改为「不指定账户」（account_id = null），返回影响行数。
  Future<Result<int>> detachFromAccount(String accountId);
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

  /// 产出 [batchId] 那批账单的规则；查不到返回 null。
  ///
  /// 撤销周期批次（`UndoRecurringBatchUseCase`）用它判断这批是否来自
  /// `kind = savingsTransfer` 的规则，从而把目标进度一起扣回。
  Future<Result<RecurringRule?>> findByLastBatchId(String batchId);

  Future<Result<RecurringRule>> create(RecurringRule rule);
  Future<Result<RecurringRule>> update(RecurringRule rule);
  Future<Result<void>> softDelete(String id);
}

/// STORY-6.3 提醒历史（`reminders` 表）。
///
/// 「同类去重」与「历史近 90 天可查」两件事共用它；表示设备产生过什么提醒，
/// 不写 change_log、不进云同步。
abstract interface class ReminderRepository {
  Future<Result<void>> append({
    required String bookId,
    required AppReminder reminder,
  });

  /// 去重窗口内是否已产生过同一 [dedupKey]。
  Future<Result<bool>> hasSince({
    required String bookId,
    required String dedupKey,
    required int sinceMs,
  });

  /// 近 [sinceMs] 之后的提醒，最新在前。
  Future<Result<List<AppReminder>>> listRecent({
    required String bookId,
    required int sinceMs,
    int limit = 200,
    bool undigestedOnly = false,
  });

  Future<Result<void>> markRead({required String id, required bool read});

  /// 夜间汇总摘要已发出（同一批不再重复汇总）。
  Future<Result<void>> markDigested({required List<String> ids});

  /// 清理超期历史，返回删除条数。
  Future<Result<int>> gc({required DateTime before});
}
