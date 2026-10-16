/// 目标进度的**唯一口径**（V3.0 拍板 2026-10-15）。
///
/// 已存额 = **目标虚拟账户的派生余额**，不再是存储的 `savings_goals.saved_cents`。
///
/// 为什么：存入与自动划拨都是一笔「可用账户 → 目标虚拟账户」的内部转账，
/// 钱真的被预留出去了，所以虚拟账户余额才是权威值。存储的 `saved_cents` 只是
/// 一个累加计数——用户在流水里删掉那笔「存入」转账后，账户余额会回落，而计数
/// 不会，于是出现「钱转回去了进度还在」的分叉。
///
/// 账户余额由 `AccountRepository` 派生（G-2 五段式），本服务只做映射，无 IO。
library;

import 'package:plain/domain/entities/savings_goal.dart';
import 'package:plain/domain/repositories/repositories.dart';

/// 目标 + 它的**派生已存额**。
///
/// 进度数学只有一份实现（[SavingsGoal] 上那套），这里把已存额换成派生值再算，
/// 避免「页面一套算法、实体一套算法」漂移。
class GoalProgress {
  GoalProgress({required this.goal, required int savedCents})
      : savedCents = savedCents < 0 ? 0 : savedCents;

  final SavingsGoal goal;

  /// 已存金额（分）= 目标虚拟账户的派生余额。
  final int savedCents;

  int get targetCents => goal.targetCents;

  SavingsGoal get _withSaved => goal.copyWith(savedCents: savedCents);

  bool get isAchieved => _withSaved.isAchieved;

  double get progress => _withSaved.progress;

  int get remainingCents => _withSaved.remainingCents;

  int monthlyRequiredCentsAt(DateTime now) => _withSaved.monthlyRequiredCentsAt(now);

  bool isOverdueAt(DateTime now) => _withSaved.isOverdueAt(now);
}

class GoalProgressService {
  const GoalProgressService();

  /// [balanceByAccount] = `AccountRepository.listWithBalances` 的 accountId → 派生余额。
  ///
  /// 还没有虚拟账户（= 从没存过，存入/划拨都会惰性建账户）时已存为 0。
  GoalProgress of({
    required SavingsGoal goal,
    required Map<String, int> balanceByAccount,
  }) {
    final accountId = goal.goalAccountId;
    return GoalProgress(
      goal: goal,
      savedCents: accountId == null ? 0 : (balanceByAccount[accountId] ?? 0),
    );
  }

  List<GoalProgress> ofAll({
    required List<SavingsGoal> goals,
    required Map<String, int> balanceByAccount,
  }) =>
      [for (final g in goals) of(goal: g, balanceByAccount: balanceByAccount)];

  /// `listWithBalances` 的结果 → accountId → 余额（一次查询喂给所有目标）。
  static Map<String, int> balanceIndex(List<AccountWithBalance> accounts) => {
        for (final a in accounts) a.account.id: a.balanceCents,
      };
}
