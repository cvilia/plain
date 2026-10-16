/// STORY-11.1 预算方法论。
///
/// 四套方法论共享**同一份分类预算数据**（也就是 STORY-7.2 的限额目标）：
/// 切换只改变呈现与校验规则，不产生第二套数据、不改历史账单（AC5/AC6）。
///
/// 50/30/20 的「需要 / 想要」判据用分类的**刚性支出标记**
/// （`categories.is_rigid`，v10 已落列并在分类管理页可编辑）；
/// 「储蓄」= 收入 − 总支出，是派生量而不是第三类支出。
library;

import 'package:plain/core/result/result.dart';
import 'package:plain/domain/entities/enums.dart';

/// 参与测算的一条分类预算（含其实花金额与刚性标记）。
class CategorySpendInput {
  const CategorySpendInput({
    required this.categoryId,
    required this.name,
    required this.limitCents,
    required this.spentCents,
    required this.isRigid,
  });

  final String categoryId;
  final String name;

  /// 该分类的预算额度（限额目标）。
  final int limitCents;
  final int spentCents;

  /// 刚性支出 = 50/30/20 里的「需要」。
  final bool isRigid;
}

/// 信封法下的一个信封（AC1）。
class BudgetEnvelope {
  const BudgetEnvelope({
    required this.categoryId,
    required this.name,
    required this.limitCents,
    required this.spentCents,
  });

  final String categoryId;
  final String name;
  final int limitCents;
  final int spentCents;

  /// 信封余额（超支为负）。
  int get remainingCents => limitCents - spentCents;
  bool get isOver => spentCents > limitCents;

  /// 超支的差额（未超支为 0）。
  int get overdraftCents => isOver ? spentCents - limitCents : 0;
}

/// 零基预算视图（AC3）。
class ZeroBasedView {
  const ZeroBasedView({
    required this.incomeCents,
    required this.allocatedCents,
  });

  final int incomeCents;

  /// Σ各分类预算额度。
  final int allocatedCents;

  /// 待分配 = 收入 − 已分配（可为负，表示分配超过收入）。
  int get unallocatedCents => incomeCents - allocatedCents;

  /// AC3：未分配为 0 才算「归零」。
  bool get isBalanced => unallocatedCents == 0;
}

/// 50/30/20 的一档（AC4）。
class RatioBucket {
  const RatioBucket({
    required this.kind,
    required this.actualCents,
    required this.targetCents,
  });

  final RatioBucketKind kind;
  final int actualCents;

  /// 目标金额 = 收入 × 目标比例。
  final int targetCents;

  /// 实际占比（收入为 0 时为 0）。
  double actualRatio(int incomeCents) =>
      incomeCents <= 0 ? 0 : actualCents / incomeCents;

  /// 目标占比。
  double targetRatio(int incomeCents) =>
      incomeCents <= 0 ? 0 : targetCents / incomeCents;

  /// 偏差（实际占比 − 目标占比，正=超）。
  double deviation(int incomeCents) =>
      actualRatio(incomeCents) - targetRatio(incomeCents);

  /// 金额差（实际 − 目标，正=超出）。
  int get deltaCents => actualCents - targetCents;
}

class BudgetMethodologyService {
  const BudgetMethodologyService();

  /// 信封视图（AC1）：每类一个信封，独立滚存。
  List<BudgetEnvelope> envelopes(List<CategorySpendInput> items) => [
        for (final i in items)
          BudgetEnvelope(
            categoryId: i.categoryId,
            name: i.name,
            limitCents: i.limitCents,
            spentCents: i.spentCents,
          ),
      ];

  /// 零基视图（AC3）。
  ZeroBasedView zeroBased({
    required int incomeCents,
    required List<CategorySpendInput> items,
  }) =>
      ZeroBasedView(
        incomeCents: incomeCents,
        allocatedCents: items.fold(0, (s, i) => s + i.limitCents),
      );

  /// 50/30/20 三档（AC4）。
  ///
  /// [needsBp] / [wantsBp] 是目标比例（基点，5000 = 50%）；储蓄 = 余下部分。
  /// 「需要」= 刚性支出分类，「想要」= 其余支出分类，「储蓄」= 收入 − 总支出。
  List<RatioBucket> ratioBuckets({
    required int incomeCents,
    required List<CategorySpendInput> items,
    int needsBp = 5000,
    int wantsBp = 3000,
    int savingsBp = 2000,
  }) {
    var needs = 0;
    var wants = 0;
    for (final i in items) {
      if (i.isRigid) {
        needs += i.spentCents;
      } else {
        wants += i.spentCents;
      }
    }
    final savings = incomeCents - needs - wants;
    int target(int bp) => incomeCents <= 0 ? 0 : (incomeCents * bp / 10000).round();
    return [
      RatioBucket(
          kind: RatioBucketKind.needs, actualCents: needs, targetCents: target(needsBp)),
      RatioBucket(
          kind: RatioBucketKind.wants, actualCents: wants, targetCents: target(wantsBp)),
      RatioBucket(
          kind: RatioBucketKind.savings,
          // 储蓄可以是负数（超支月），如实呈现
          actualCents: savings,
          targetCents: target(savingsBp)),
    ];
  }

  /// AC2：信封法下不许跨类挪用。
  ///
  /// 具体判定（对「从别的信封挪钱来补」的可执行翻译）：**不能把某个信封的额度
  /// 调到低于它已经花掉的金额**——那必然意味着动用了别处的钱。其它方法论不限制。
  Result<void> validateEnvelopeLimitChange({
    required BudgetMethodology methodology,
    required String categoryName,
    required int newLimitCents,
    required int spentCents,
  }) {
    if (methodology != BudgetMethodology.envelope) return ok(null);
    if (newLimitCents < spentCents) {
      return err(ValidationFailure(
        'budget.envelope_no_borrow',
        '信封法下不可跨类挪用：「$categoryName」已花 '
            '${(spentCents / 100).toStringAsFixed(2)} 元，额度不能低于该值',
      ));
    }
    return ok(null);
  }

  /// 切换方法论时的对照预览（AC1：给出切换前后的对照）。
  ///
  /// 返回「呈现方式」的变化描述，用于在切换确认里说明**数据不变、只是看法变了**。
  String switchPreview({
    required BudgetMethodology from,
    required BudgetMethodology to,
    required int categoryBudgetCount,
  }) {
    String shape(BudgetMethodology m) => switch (m) {
          BudgetMethodology.custom => '总预算 + $categoryBudgetCount 条分类限额',
          BudgetMethodology.envelope => '$categoryBudgetCount 个信封（各自滚存）',
          BudgetMethodology.zeroBased => '$categoryBudgetCount 项已分配 + 待分配余额',
          BudgetMethodology.fiftyThirtyTwenty =>
            '需要 / 想要 / 储蓄三档（$categoryBudgetCount 条限额按刚性标记归入前两档）',
        };
    return '从「${from.label}」切到「${to.label}」：'
        '同样的数据由「${shape(from)}」呈现为「${shape(to)}」。'
        '账单与报表不受影响。';
  }

  /// 分类在 50/30/20 里落在哪一档（用于呈现分组）。
  static RatioBucketKind bucketOf(CategorySpendInput item) =>
      item.isRigid ? RatioBucketKind.needs : RatioBucketKind.wants;
}
