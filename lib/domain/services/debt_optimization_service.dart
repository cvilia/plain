/// STORY-10.5 债务优化（雪球 / 雪崩）。
///
/// 两种还款策略的**逐月模拟**，纯派生、不落库：
/// - **雪球法**：每月优先砸向余额最小的债务（心理激励强）；
/// - **雪崩法**：每月优先砸向利率最高的债务（总利息最省）。
///
/// 每月固定预算 = Σ各债最低还款 + 额外还款。某笔结清后它的最低还款额
/// 自动变成「剩余预算」流向下一个目标——这是两种策略真正拉开差距的地方。
library;

/// 还款策略。
enum DebtStrategy {
  snowball('snowball', '雪球法'),
  avalanche('avalanche', '雪崩法');

  const DebtStrategy(this.wire, this.label);
  final String wire;
  final String label;
}

/// 一笔债务的输入。
class DebtItem {
  const DebtItem({
    required this.id,
    required this.name,
    required this.balanceCents,
    required this.annualRateBp,
    required this.minPaymentCents,
  });

  final String id;
  final String name;
  final int balanceCents;

  /// 年利率，基点（1800 = 18%）。
  final int annualRateBp;

  /// 每月最低还款。
  final int minPaymentCents;
}

/// 一笔债务的结清记录。
class PayoffStep {
  const PayoffStep({
    required this.id,
    required this.name,
    required this.month,
  });

  final String id;
  final String name;

  /// 第几个月结清（1-based）。
  final int month;
}

/// 一种策略的模拟结果。
class DebtPlan {
  const DebtPlan({
    required this.strategy,
    required this.months,
    required this.totalInterestCents,
    required this.totalPaidCents,
    required this.order,
    required this.settled,
  });

  final DebtStrategy strategy;

  /// 还清全部债务所需月数（未结清时为模拟上限）。
  final int months;
  final int totalInterestCents;
  final int totalPaidCents;

  /// 结清顺序。
  final List<PayoffStep> order;

  /// 是否在模拟上限内结清（月供不足以覆盖利息时为 false）。
  final bool settled;
}

/// 两种策略的对比（AC1/AC3）。
class DebtComparison {
  const DebtComparison({
    required this.snowball,
    required this.avalanche,
    required this.recommended,
  });

  final DebtPlan snowball;
  final DebtPlan avalanche;
  final DebtStrategy recommended;

  DebtPlan get recommendedPlan =>
      recommended == DebtStrategy.avalanche ? avalanche : snowball;

  DebtPlan get otherPlan =>
      recommended == DebtStrategy.avalanche ? snowball : avalanche;

  /// 推荐策略相对另一种省下的利息（分）。
  int get savingCents {
    final d = otherPlan.totalInterestCents - recommendedPlan.totalInterestCents;
    return d > 0 ? d : 0;
  }

  /// AC3 的推荐理由文案。
  String get reason => savingCents > 0
      ? '推荐${recommended.label}：总利息比另一种少 '
          '${(savingCents / 100).toStringAsFixed(2)} 元'
      : '两种策略总利息相同，任选其一即可';
}

class DebtOptimizationService {
  const DebtOptimizationService({this.maxMonths = 1200});

  /// 模拟上限（100 年），防止「月供不足以覆盖利息」时死循环。
  final int maxMonths;

  /// 模拟一种策略（AC1/AC2）。
  DebtPlan simulate(
    List<DebtItem> debts,
    DebtStrategy strategy, {
    int extraMonthlyCents = 0,
  }) {
    final live = [
      for (final d in debts)
        if (d.balanceCents > 0 && d.minPaymentCents > 0) d,
    ];
    if (live.isEmpty) {
      return DebtPlan(
        strategy: strategy,
        months: 0,
        totalInterestCents: 0,
        totalPaidCents: 0,
        order: const [],
        settled: true,
      );
    }

    final balances = <String, int>{
      for (final d in live) d.id: d.balanceCents,
    };
    final extra = extraMonthlyCents > 0 ? extraMonthlyCents : 0;
    final budget = live.fold<int>(0, (s, d) => s + d.minPaymentCents) + extra;

    var totalInterest = 0;
    var totalPaid = 0;
    var months = 0;
    final order = <PayoffStep>[];

    while (balances.values.any((b) => b > 0) && months < maxMonths) {
      months++;

      // 1) 计息
      for (final d in live) {
        final balance = balances[d.id]!;
        if (balance <= 0) continue;
        final interest = _monthlyInterest(balance, d.annualRateBp);
        totalInterest += interest;
        balances[d.id] = balance + interest;
      }

      // 2) 各债付最低还款
      var used = 0;
      for (final d in live) {
        final balance = balances[d.id]!;
        if (balance <= 0) continue;
        final pay = d.minPaymentCents > balance ? balance : d.minPaymentCents;
        balances[d.id] = balance - pay;
        totalPaid += pay;
        used += pay;
      }

      // 3) 剩余预算砸向优先目标，可连续击穿多笔
      var free = budget - used;
      for (final d in _prioritized(live, balances, strategy)) {
        if (free <= 0) break;
        final balance = balances[d.id]!;
        if (balance <= 0) continue;
        final pay = free > balance ? balance : free;
        balances[d.id] = balance - pay;
        totalPaid += pay;
        free -= pay;
      }

      // 4) 记录本月结清的债务
      for (final d in live) {
        if (balances[d.id] == 0 && !order.any((s) => s.id == d.id)) {
          order.add(PayoffStep(id: d.id, name: d.name, month: months));
        }
      }
    }

    final settled = balances.values.every((b) => b <= 0);
    return DebtPlan(
      strategy: strategy,
      months: months,
      totalInterestCents: totalInterest,
      totalPaidCents: totalPaid,
      order: order,
      settled: settled,
    );
  }

  /// 两种策略并列对比（AC1/AC3）。
  DebtComparison compare(
    List<DebtItem> debts, {
    int extraMonthlyCents = 0,
  }) {
    final snowball = simulate(debts, DebtStrategy.snowball,
        extraMonthlyCents: extraMonthlyCents);
    final avalanche = simulate(debts, DebtStrategy.avalanche,
        extraMonthlyCents: extraMonthlyCents);
    // 利息更省者胜；相等时按雪球（更早看到成果）
    final recommended =
        avalanche.totalInterestCents < snowball.totalInterestCents
            ? DebtStrategy.avalanche
            : DebtStrategy.snowball;
    return DebtComparison(
      snowball: snowball,
      avalanche: avalanche,
      recommended: recommended,
    );
  }

  /// 月利息 = 余额 × 年利率 ÷ 12（整数分，四舍五入）。
  int _monthlyInterest(int balanceCents, int annualRateBp) {
    if (balanceCents <= 0 || annualRateBp <= 0) return 0;
    return (balanceCents * annualRateBp / 120000).round();
  }

  /// 优先顺序：雪球按余额升序，雪崩按利率降序（同率时余额小的先还）。
  List<DebtItem> _prioritized(
    List<DebtItem> live,
    Map<String, int> balances,
    DebtStrategy strategy,
  ) {
    final pending = [
      for (final d in live)
        if ((balances[d.id] ?? 0) > 0) d,
    ];
    pending.sort((a, b) {
      if (strategy == DebtStrategy.avalanche) {
        final byRate = b.annualRateBp.compareTo(a.annualRateBp);
        if (byRate != 0) return byRate;
      }
      return balances[a.id]!.compareTo(balances[b.id]!);
    });
    return pending;
  }
}
