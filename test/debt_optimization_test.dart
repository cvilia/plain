/// STORY-10.5 债务优化（雪球 / 雪崩）逐月模拟。
library;
import 'package:flutter_test/flutter_test.dart';
import 'package:plain/domain/services/debt_optimization_service.dart';

void main() {
  const svc = DebtOptimizationService();

  // AC1 的三笔债务：金额与利率各不相同
  const debts = [
    // 最小但利率最低
    DebtItem(
        id: 'A', name: '花呗', balanceCents: 100000,
        annualRateBp: 600, minPaymentCents: 5000),
    // 中等但利率最高
    DebtItem(
        id: 'B', name: '信用卡', balanceCents: 300000,
        annualRateBp: 3600, minPaymentCents: 10000),
    // 最大、利率中等
    DebtItem(
        id: 'C', name: '车贷', balanceCents: 500000,
        annualRateBp: 1200, minPaymentCents: 15000),
  ];

  group('AC1 两种策略并列', () {
    test('都给出月数与总利息，且都能还清', () {
      final cmp = svc.compare(debts);
      expect(cmp.snowball.settled, true);
      expect(cmp.avalanche.settled, true);
      expect(cmp.snowball.months, greaterThan(0));
      expect(cmp.avalanche.months, greaterThan(0));
      expect(cmp.snowball.totalInterestCents, greaterThan(0));
      expect(cmp.avalanche.totalInterestCents, greaterThan(0));
    });

    test('雪崩法总利息更少，因此被推荐（AC3）', () {
      final cmp = svc.compare(debts);
      expect(cmp.avalanche.totalInterestCents,
          lessThan(cmp.snowball.totalInterestCents));
      expect(cmp.recommended, DebtStrategy.avalanche);
      expect(cmp.savingCents, greaterThan(0));
      expect(cmp.reason, contains('雪崩法'));
      expect(cmp.reason, contains('少'));
    });

    test('雪球法先清最小的，雪崩法先清利率最高的（需有余钱可变现）', () {
      // 预算恰好等于各债最低还款时没有余钱，两种策略无从施展；
      // 加 500 元/月额外还款后，优先级才真正起作用。
      final cmp = svc.compare(debts, extraMonthlyCents: 50000);
      expect(cmp.snowball.order.first.id, 'A'); // 余额最小
      expect(cmp.avalanche.order.first.id, 'B'); // 利率 36% 最高
      // 两种策略的结清顺序不同
      expect(cmp.snowball.order.map((s) => s.id).toList(),
          isNot(cmp.avalanche.order.map((s) => s.id).toList()));
      // 雪崩法依然更省
      expect(cmp.avalanche.totalInterestCents,
          lessThan(cmp.snowball.totalInterestCents));
    });

    test('没有余钱时两种策略推进方式相同（这是真实性质，不是缺陷）', () {
      final cmp = svc.compare(debts); // 无额外还款
      final snowballIds = cmp.snowball.order.map((s) => s.id).toList();
      final avalancheIds = cmp.avalanche.order.map((s) => s.id).toList();
      // 首笔结清由「最低还款覆盖速度」决定，与优先级无关
      expect(snowballIds.first, avalancheIds.first);
    });
  });

  group('AC2 额外还款', () {
    test('每月多还 1000 元，两种策略都更快还清且少付利息', () {
      const extra = 100000; // 1000 元
      final base = svc.compare(debts);
      final boosted = svc.compare(debts, extraMonthlyCents: extra);

      expect(boosted.snowball.months,
          lessThan(base.snowball.months));
      expect(boosted.snowball.totalInterestCents,
          lessThan(base.snowball.totalInterestCents));
      expect(boosted.avalanche.months,
          lessThan(base.avalanche.months));
      expect(boosted.avalanche.totalInterestCents,
          lessThan(base.avalanche.totalInterestCents));
      // 雪崩法在两种情形下都更省
      expect(boosted.avalanche.totalInterestCents,
          lessThan(boosted.snowball.totalInterestCents));
    });
  });

  group('模拟口径', () {
    test('总还款 = 本金合计 + 利息合计', () {
      final plan = svc.simulate(debts, DebtStrategy.avalanche);
      const principal = 100000 + 300000 + 500000;
      expect(plan.totalPaidCents - plan.totalInterestCents, principal);
    });

    test('每月固定预算：债务结清后其最低还款滚入下一目标', () {
      // 单笔债务：预算就是它的最低还款
      const single = [
        DebtItem(id: 'X', name: 'X', balanceCents: 100000,
            annualRateBp: 0, minPaymentCents: 10000),
      ];
      final plan = svc.simulate(single, DebtStrategy.snowball);
      expect(plan.settled, true);
      expect(plan.totalInterestCents, 0);
      expect(plan.months, 10); // 1000 元 / 每月 100 元
      expect(plan.totalPaidCents, 100000);
    });

    test('零利率下多笔债务按优先级依次清空', () {
      const zero = [
        DebtItem(id: 'A', name: 'A', balanceCents: 20000,
            annualRateBp: 0, minPaymentCents: 10000),
        DebtItem(id: 'B', name: 'B', balanceCents: 60000,
            annualRateBp: 0, minPaymentCents: 10000),
      ];
      // 预算 200 元/月，合计欠 800 元 → 4 个月
      final plan = svc.simulate(zero, DebtStrategy.snowball);
      expect(plan.months, 4);
      expect(plan.order.first.id, 'A');
      expect(plan.order.last.id, 'B');
    });

    test('月供不足以覆盖利息时报「未结清」而不是死循环', () {
      const svcSmall = DebtOptimizationService(maxMonths: 12);
      const bad = [
        DebtItem(id: 'X', name: '高利贷', balanceCents: 1000000,
            annualRateBp: 24000, minPaymentCents: 10000),
      ];
      final plan = svcSmall.simulate(bad, DebtStrategy.avalanche);
      expect(plan.settled, false);
      expect(plan.months, 12);
    });

    test('没有债务时给出空计划', () {
      final plan = svc.simulate(const [], DebtStrategy.snowball);
      expect(plan.months, 0);
      expect(plan.totalInterestCents, 0);
      expect(plan.settled, true);
      expect(plan.order, isEmpty);
    });
  });
}
