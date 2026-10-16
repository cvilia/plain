/// STORY-3.3 安全可花：可用资金 − 未来账单预留 − 目标待拨付 − 刚性支出预留。
library;

import 'package:plain/domain/entities/category.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/entities/recurring_rule.dart';
import 'package:plain/domain/entities/savings_goal.dart';
import 'package:plain/domain/repositories/repositories.dart';
import 'package:plain/domain/services/accounting_calendar.dart';
import 'package:plain/domain/services/goal_progress_service.dart';

/// 安全可花计算结果与三行拆解。
class SafeToSpendResult {
  const SafeToSpendResult({
    required this.availableCents,
    required this.futureBillsCents,
    required this.goalAllocationCents,
    required this.rigidReserveCents,
    required this.remainingDays,
    required this.hasAnyBudget,
  });

  /// 可用资金 = 现金 + 储蓄卡余额（不含信用卡额度、不含投资）。
  final int availableCents;

  /// 未来账单预留 = 本记账月内周期规则待生成账单之和。
  final int futureBillsCents;

  /// 目标待拨付 = 各储蓄目标本记账月尚未划拨的金额。
  final int goalAllocationCents;

  /// 刚性支出预留 = isRigid 分类的剩余预算之和。
  final int rigidReserveCents;

  /// 本记账月剩余天数（至少 1）。
  final int remainingDays;

  /// 是否有任何预算（无预算时隐藏卡片）。
  final bool hasAnyBudget;

  /// 安全可花 = 可用 − 未来账单 − 目标拨付 − 刚性预留。
  int get safeToSpendCents =>
      availableCents - futureBillsCents - goalAllocationCents - rigidReserveCents;

  /// 日均安全可花 = 安全可花 ÷ 剩余天数。
  int get dailyAverageCents {
    if (remainingDays <= 0) return 0;
    return (safeToSpendCents / remainingDays).floor();
  }

  bool get isNegative => safeToSpendCents < 0;
}

/// 从各仓储聚合数据并计算安全可花。
class SafeToSpendCalculator {
  SafeToSpendCalculator({
    required this.accountRepository,
    required this.budgetRepository,
    required this.recurringRepository,
    required this.savingsGoalRepository,
    required this.categoryRepository,
    required this.calendar,
    required this.bookId,
  });

  final AccountRepository accountRepository;
  final BudgetRepository budgetRepository;
  final RecurringRepository recurringRepository;
  final SavingsGoalRepository savingsGoalRepository;
  final CategoryRepository categoryRepository;
  final AccountingCalendar calendar;
  final String bookId;

  Future<SafeToSpendResult> calculate() async {
    // 1) 可用资金 = 现金 + 储蓄卡
    final accountsRes = await accountRepository.listWithBalances();
    final accounts = accountsRes.successOrNull ?? const <AccountWithBalance>[];
    var available = 0;
    for (final aw in accounts) {
      final t = aw.account.type;
      if (t == AccountType.cash || t == AccountType.debit) {
        available += aw.balanceCents;
      }
    }

    // 2) 本记账月窗口
    final period = calendar.currentPeriod();
    final startMs = DateTime.parse(period.dayFrom).millisecondsSinceEpoch;
    final endMs = DateTime.parse(period.dayTo).millisecondsSinceEpoch + 86400000 - 1;
    final now = DateTime.now().toLocal();
    final monthEnd = DateTime.parse(period.dayTo);
    final remainingDays = monthEnd.difference(now).inDays + 1;

    // 3) 未来账单预留：本记账月内待生成的周期规则金额
    final rulesRes = await recurringRepository.listByBook(bookId);
    final rules = rulesRes.successOrNull ?? const <RecurringRule>[];
    var futureBills = 0;
    for (final r in rules) {
      // 简化：取每条规则的单次金额作为本记账月预留
      // （精确计算需要展开规则在本记账月内的每次生成时间点）
      futureBills += r.amount.cents;
    }

    // 4) 目标待拨付：各储蓄目标本月尚需存入
    //    进度按 V3.0 口径读虚拟账户派生余额（复用第 1 步已经取到的余额，不再查库）
    final goalsRes = await savingsGoalRepository.listByBook(bookId);
    final goals = goalsRes.successOrNull ?? const <SavingsGoal>[];
    final goalProgress = const GoalProgressService().ofAll(
      goals: goals,
      balanceByAccount: GoalProgressService.balanceIndex(accounts),
    );
    var goalAllocation = 0;
    for (final v in goalProgress) {
      if (v.isAchieved) continue;
      goalAllocation += v.monthlyRequiredCentsAt(now);
    }

    // 5) 刚性支出预留：isRigid 分类的剩余预算
    final catsRes = await categoryRepository.listAll(kind: CategoryKind.expense);
    final cats = catsRes.successOrNull ?? const <Category>[];
    final rigidRoots = cats.where((c) => c.isRigid && c.isRoot).toList();
    var rigidReserve = 0;
    var hasAnyBudget = false;

    final budgetsRes = await budgetRepository.listByBook(bookId);
    final budgets = budgetsRes.successOrNull ?? const [];
    if (budgets.isNotEmpty) hasAnyBudget = true;

    for (final root in rigidRoots) {
      // 找该分类的预算
      final budget = budgets.where((b) => b.categoryId == root.id).firstOrNull;
      if (budget == null) continue;
      final spentRes = await budgetRepository.spentCents(
        bookId: bookId,
        categoryId: root.id,
        fromMs: startMs,
        toMs: endMs,
      );
      final spent = spentRes.successOrNull ?? 0;
      final remaining = budget.amount.cents - spent;
      if (remaining > 0) rigidReserve += remaining;
    }

    return SafeToSpendResult(
      availableCents: available,
      futureBillsCents: futureBills,
      goalAllocationCents: goalAllocation,
      rigidReserveCents: rigidReserve,
      remainingDays: remainingDays < 1 ? 1 : remainingDays,
      hasAnyBudget: hasAnyBudget,
    );
  }
}
