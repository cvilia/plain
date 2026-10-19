/// STORY-11.1 预算方法论四套。
library;
import 'package:flutter_test/flutter_test.dart';
import 'package:plain/app/l10n/strings_core.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/services/budget_methodology_service.dart';

void main() {
  const svc = BudgetMethodologyService();

  // 同一份分类预算数据（= 限额目标），四套方法论都从它派生
  const items = [
    CategorySpendInput(
        categoryId: 'food', name: '餐饮', limitCents: 300000,
        spentCents: 200000, isRigid: true),
    CategorySpendInput(
        categoryId: 'fun', name: '娱乐', limitCents: 100000,
        spentCents: 150000, isRigid: false),
  ];

  group('AC1 切换只改呈现，并给出对照预览', () {
    test('预览说明同一份数据的两种呈现，且声明账单不受影响', () {
      final text = svc.switchPreview(
        from: BudgetMethodology.custom,
        to: BudgetMethodology.envelope,
        categoryBudgetCount: 2,
        s: kDefaultAppStrings,
      );
      expect(text, contains('分类限额'));
      expect(text, contains('信封'));
      expect(text, contains('2'));
      expect(text, contains('账单与报表不受影响'));
    });

    test('切到零基与 50/30/20 也各有对应说明', () {
      expect(
        svc.switchPreview(
            from: BudgetMethodology.custom,
            to: BudgetMethodology.zeroBased,
            categoryBudgetCount: 3,
            s: kDefaultAppStrings,),
        contains('待分配'),
      );
      expect(
        svc.switchPreview(
            from: BudgetMethodology.custom,
            to: BudgetMethodology.fiftyThirtyTwenty,
            categoryBudgetCount: 3,
            s: kDefaultAppStrings,),
        contains('需要'),
      );
    });
  });

  group('AC2 信封法不许跨类挪用', () {
    test('把额度调到低于已花金额会被拦截，并给出中文提示', () {
      final r = svc.validateEnvelopeLimitChange(
        methodology: BudgetMethodology.envelope,
        categoryName: '娱乐',
        newLimitCents: 100000,
        spentCents: 150000,
        s: kDefaultAppStrings,
      );
      expect(r.isFailure, true);
      expect(r.failureOrNull!.code, 'budget.envelope_no_borrow');
      expect(r.failureOrNull!.message, contains('不可跨类挪用'));
      expect(r.failureOrNull!.message, contains('娱乐'));
    });

    test('额度不低于已花金额时放行', () {
      expect(
        svc
            .validateEnvelopeLimitChange(
              methodology: BudgetMethodology.envelope,
              categoryName: '娱乐',
              newLimitCents: 150000,
              spentCents: 150000,
              s: kDefaultAppStrings,
            )
            .isSuccess,
        true,
      );
    });

    test('其它方法论不做此限制', () {
      for (final m in [
        BudgetMethodology.custom,
        BudgetMethodology.zeroBased,
        BudgetMethodology.fiftyThirtyTwenty,
      ]) {
        expect(
          svc
              .validateEnvelopeLimitChange(
                methodology: m,
                categoryName: '娱乐',
                newLimitCents: 1000,
                spentCents: 150000,
                s: kDefaultAppStrings,
              )
              .isSuccess,
          true,
          reason: '${m.label} 不应限制',
        );
      }
    });
  });

  group('AC1 信封视图', () {
    test('每个分类一个信封，余额与超支差额正确', () {
      final envelopes = svc.envelopes(items);
      expect(envelopes, hasLength(2));
      expect(envelopes[0].remainingCents, 100000);
      expect(envelopes[0].isOver, false);
      // 娱乐：额度 1000 元、花了 1500 元 → 超支 500 元
      expect(envelopes[1].isOver, true);
      expect(envelopes[1].overdraftCents, 50000);
    });
  });

  group('AC3 零基预算', () {
    test('待分配 = 收入 − 已分配', () {
      final v = svc.zeroBased(incomeCents: 600000, items: items);
      expect(v.allocatedCents, 400000);
      expect(v.unallocatedCents, 200000);
      expect(v.isBalanced, false);
    });

    test('分配干净即归零', () {
      final v = svc.zeroBased(incomeCents: 400000, items: items);
      expect(v.unallocatedCents, 0);
      expect(v.isBalanced, true);
    });

    test('超分配时待分配为负（不隐藏）', () {
      final v = svc.zeroBased(incomeCents: 300000, items: items);
      expect(v.unallocatedCents, -100000);
    });
  });

  group('AC4 50/30/20', () {
    test('刚性支出进「需要」，其余进「想要」，储蓄是余下部分', () {
      final buckets = svc.ratioBuckets(
        incomeCents: 1000000, items: items, needsBp: 5000, wantsBp: 3000);
      expect(buckets, hasLength(3));
      expect(buckets[0].kind, RatioBucketKind.needs);
      expect(buckets[0].actualCents, 200000); // 餐饮（刚性）
      expect(buckets[1].kind, RatioBucketKind.wants);
      expect(buckets[1].actualCents, 150000); // 娱乐（非刚性）
      // 储蓄 = 收入 − 总支出 = 10000 − 3500 = 6500 元
      expect(buckets[2].kind, RatioBucketKind.savings);
      expect(buckets[2].actualCents, 650000);
    });

    test('给出实际占比与目标占比的偏差', () {
      final buckets = svc.ratioBuckets(
        incomeCents: 1000000, items: items, needsBp: 5000, wantsBp: 3000);
      final needs = buckets[0];
      expect(needs.targetCents, 500000); // 50%
      expect(needs.actualRatio(1000000), closeTo(0.20, 1e-9));
      expect(needs.targetRatio(1000000), closeTo(0.50, 1e-9));
      // 实际比目标低 30 个百分点
      expect(needs.deviation(1000000), closeTo(-0.30, 1e-9));
      expect(needs.deltaCents, -300000);
    });

    test('默认比例即 50/30/20，储蓄取余下 20%', () {
      final buckets = svc.ratioBuckets(incomeCents: 1000000, items: const []);
      expect(buckets[0].targetCents, 500000);
      expect(buckets[1].targetCents, 300000);
      expect(buckets[2].targetCents, 200000);
    });

    test('超支月储蓄为负，如实呈现', () {
      final buckets = svc.ratioBuckets(
        incomeCents: 100000,
        items: const [
          CategorySpendInput(
              categoryId: 'x', name: 'X', limitCents: 0,
              spentCents: 300000, isRigid: true),
        ],
      );
      expect(buckets[2].actualCents, -200000);
    });

    test('收入为 0 时占比不出现除零', () {
      final buckets = svc.ratioBuckets(incomeCents: 0, items: items);
      expect(buckets[0].actualRatio(0), 0);
      expect(buckets[0].targetRatio(0), 0);
    });
  });

  group('AC6 四套方法论共享同一份数据', () {
    test('同一批分类预算在四套下条目数一致（不产生第二套数据）', () {
      expect(svc.envelopes(items), hasLength(items.length));
      expect(svc.zeroBased(incomeCents: 500000, items: items).allocatedCents,
          items.fold(0, (s, i) => s + i.limitCents));
      final buckets = svc.ratioBuckets(incomeCents: 500000, items: items);
      // 需要 + 想要 的支出合计 = 全部分类支出合计
      expect(buckets[0].actualCents + buckets[1].actualCents,
          items.fold(0, (s, i) => s + i.spentCents));
    });

    test('分类归入哪一档由刚性标记决定', () {
      expect(BudgetMethodologyService.bucketOf(items[0]), RatioBucketKind.needs);
      expect(BudgetMethodologyService.bucketOf(items[1]), RatioBucketKind.wants);
    });
  });
}
