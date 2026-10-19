/// STORY-7.2 目标体系：三类目标里的**限额目标**。
///
/// ⚠️ 限额目标的底层就是「分类预算」（PRD 明写「复用分类预算，不重复建设」）：
/// 因此这里**没有新表、没有第二种数据**——读的是 `budgets`（`scope = category`），
/// 写也是写同一行（同分类已存在就改额度，不新增）。
///
/// 与 STORY-11.1 的关系：四套预算方法论下限额目标全部继续生效
/// （自定义法=分类预算行、信封法=信封、零基法=已分配项、50/30/20=落入档位的分类），
/// 因为呈现方式切换不影响这份数据本身。
library;

import 'package:plain/app/l10n/app_strings.dart';
import 'package:plain/core/money/money.dart';
import 'package:plain/core/result/result.dart';
import 'package:plain/core/id/uuid_v7.dart';
import 'package:plain/core/time/clock.dart';
import 'package:plain/domain/entities/budget.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/repositories/repositories.dart';
import 'package:plain/app/l10n/strings_domain.dart';

/// 一个限额目标的展示视图（全部派生，不落库）。
class LimitGoalView {
  const LimitGoalView({
    required this.budget,
    required this.categoryName,
    required this.spentCents,
  });

  final Budget budget;
  final String categoryName;
  final int spentCents;

  int get limitCents => budget.amount.cents;

  /// 剩余可花；负数表示已超支。
  int get remainingCents => limitCents - spentCents;

  bool get isOver => limitCents > 0 && spentCents > limitCents;

  /// 进度（0–1，超支时截到 1 供进度条使用）。
  double get progress {
    if (limitCents <= 0) return 0;
    final p = spentCents / limitCents;
    return p < 0 ? 0 : (p > 1 ? 1 : p);
  }

  /// 超支比例（用于文案，0 = 未超支）。
  double get overRatio {
    if (!isOver || limitCents <= 0) return 0;
    return (spentCents - limitCents) / limitCents;
  }
}

class GoalSystemService {
  GoalSystemService({
    required BudgetRepository budgets,
    required UuidV7 idGen,
    required Clock clock,
  })  : _budgets = budgets,
        _idGen = idGen,
        _clock = clock;

  final BudgetRepository _budgets;
  final UuidV7 _idGen;
  final Clock _clock;

  /// AC4：设定（或修改）一个限额目标。
  ///
  /// 同一分类**只保留一条**预算行：已有就改额度，没有才新建。
  /// 「本月餐饮 ≤ 2000」因此就是 `budgets(category_id=餐饮, amount=2000)`，
  /// 预算页看到的、这里看到的、报表口径用的都是同一行。
  Future<Result<Budget>> setCategoryLimit({
    required String bookId,
    required String categoryId,
    required int amountCents,
    required String deviceId,
  }) async {
    if (amountCents <= 0) {
      return err(const ValidationFailure('goal.limit_positive', 'amount'));
    }
    final existingRes = await _budgets.listByBook(bookId);
    if (existingRes.isFailure) return err(existingRes.failureOrNull!);
    final existing = existingRes.requireValue
        .where((b) =>
            b.scope == BudgetScope.category && b.categoryId == categoryId)
        .firstOrNull;

    final now = _clock.now();
    if (existing != null) {
      // 复用同一行：不新增、不搬家、revision 照常推进
      return _budgets.update(existing.copyWith(
        amount: Money(amountCents),
        isEnabled: true,
        updatedAt: now,
        revision: existing.revision + 1,
        baseRevision: existing.revision,
      ));
    }
    return _budgets.create(Budget(
      id: _idGen.generate(at: now),
      bookId: bookId,
      scope: BudgetScope.category,
      categoryId: categoryId,
      amount: Money(amountCents),
      createdAt: now,
      updatedAt: now,
      deviceId: deviceId,
    ));
  }

  /// 纯派生：把分类预算 + 当期已花金额拼成限额目标视图。
  ///
  /// [spentByCategory] 由调用方按记账月取（走 `BudgetRepository.spentCents`，
  /// 含子分类），这里不重新发明口径。
  static List<LimitGoalView> buildViews({
    required AppStrings s,
    required List<Budget> budgets,
    required Map<String, int> spentByCategory,
    required Map<String, String> categoryNames,
  }) {
    final views = <LimitGoalView>[];
    for (final b in budgets) {
      if (b.scope != BudgetScope.category || !b.isEnabled || b.isDeleted) continue;
      final catId = b.categoryId;
      if (catId == null) continue;
      views.add(LimitGoalView(
        budget: b,
        categoryName: categoryNames[catId] ?? s.unnamedCategory,
        spentCents: spentByCategory[catId] ?? 0,
      ));
    }
    views.sort((a, b) => b.progress.compareTo(a.progress));
    return views;
  }

  /// 读取限额目标（AC4 的展示侧）：分类预算 + 当期实际支出。
  Future<Result<List<LimitGoalView>>> limitGoals({
    required AppStrings s,
    required String bookId,
    required DateTime from,
    required DateTime to,
    required Map<String, String> categoryNames,
  }) async {
    final budgetsRes = await _budgets.listByBook(bookId);
    if (budgetsRes.isFailure) return err(budgetsRes.failureOrNull!);
    final budgets = budgetsRes.requireValue
        .where((b) =>
            b.scope == BudgetScope.category && b.isEnabled && !b.isDeleted)
        .toList();

    final spent = <String, int>{};
    for (final b in budgets) {
      final catId = b.categoryId;
      if (catId == null) continue;
      final res = await _budgets.spentCents(
        bookId: bookId,
        categoryId: catId,
        fromMs: from.toUtc().millisecondsSinceEpoch,
        toMs: to.toUtc().millisecondsSinceEpoch,
      );
      if (res.isFailure) return err(res.failureOrNull!);
      spent[catId] = res.requireValue;
    }

    return ok(buildViews(
      s: s,
      budgets: budgets,
      spentByCategory: spent,
      categoryNames: categoryNames,
    ));
  }

  /// 删除限额目标（= 删掉那条分类预算，同一份数据）。
  Future<Result<void>> removeLimit(String budgetId) => _budgets.softDelete(budgetId);
}
