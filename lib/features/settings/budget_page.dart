/// 预算（STORY-5.x / SP-5-09）：四种方法论 + 分类限额进度行。
library;

import 'package:plain/app/theme/app_colors.dart';
import 'package:plain/app/theme/typography.dart';
import 'package:plain/design_system/confirm_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plain/app/bootstrap.dart';
import 'package:plain/app/breakpoints.dart';
import 'package:plain/app/settings/ledger_settings.dart';
import 'package:plain/app/theme/design_tokens.dart';
import 'package:plain/core/constants/app_constants.dart';
import 'package:plain/core/format/amount_formatter.dart';
import 'package:plain/core/refresh/data_invalidation.dart';
import 'package:plain/core/money/money.dart';
import 'package:plain/design_system/app_error_state.dart';
import 'package:plain/design_system/app_toast.dart';
import 'package:plain/design_system/category_icon_v3.dart';
import 'package:plain/design_system/app_empty_state.dart';
import 'package:plain/design_system/plain_icons_v3.dart';
import 'package:plain/design_system/plain_ui.dart';
import 'package:plain/domain/entities/budget.dart';
import 'package:plain/domain/entities/category.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/services/budget_methodology_service.dart';
import 'package:plain/domain/services/gamification_service.dart';
import 'package:plain/app/l10n/app_strings.dart';
import 'package:plain/app/l10n/strings_domain.dart';
import 'package:plain/app/l10n/strings_settings_a.dart';
import 'package:plain/app/l10n/strings_settings_b.dart';

class _BudgetData {
  const _BudgetData({
    required this.totalStatus,
    required this.categoryStatuses,
    required this.expenseCategories,
    required this.incomeCents,
  });
  final BudgetStatus? totalStatus;
  final List<BudgetStatus> categoryStatuses;
  final List<Category> expenseCategories;

  /// STORY-11.1：当前记账月的收入（零基预算与 50/30/20 的分配基数）。
  final int incomeCents;
}

final _budgetDataProvider = FutureProvider<_BudgetData>((ref) async {
  ref.watch(budgetVersionProvider);
  ref.watch(categoriesVersionProvider);
  ref.watch(ledgerVersionProvider);
  final deps = ref.watch(appDependenciesProvider);
  final total = await deps.resolveBudgetStatus.totalStatus(deps.bookId);
  final all = await deps.resolveBudgetStatus.allStatuses(deps.bookId);
  final cats = await deps.categoryRepository.listVisible(kind: CategoryKind.expense);
  // 当期收入：走 G-1 记账月边界，不自行按自然月算
  final period = deps.calendar.currentPeriod();
  final summary = await deps.ledgerRepository.monthSummary(
    bookId: deps.bookId, dayFrom: period.dayFrom, dayTo: period.dayTo);
  final list = all.successOrNull ?? const <BudgetStatus>[];
  return _BudgetData(
    totalStatus: total.successOrNull,
    categoryStatuses: list.where((s) => !s.budget.isTotal).toList(),
    expenseCategories: cats.successOrNull ?? const [],
    incomeCents: summary.successOrNull?.incomeCents ?? 0,
  );
});

class BudgetPage extends ConsumerStatefulWidget {
  const BudgetPage({super.key});

  @override
  ConsumerState<BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends ConsumerState<BudgetPage> {
  static const _methodologies = [
    BudgetMethodology.custom,
    BudgetMethodology.envelope,
    BudgetMethodology.zeroBased,
    BudgetMethodology.fiftyThirtyTwenty,
  ];

  Future<void> _switchMethodology(BudgetMethodology to) async {
    final s = AppStrings.of(context);
    final settings = ref.read(ledgerSettingsProvider);
    final from = settings.budgetMethodology;
    if (from == to) return;
    final count = ref.read(_budgetDataProvider).value?.categoryStatuses.length ?? 0;
    // AC1：切换前给出「同一份数据，看法不同」的对照预览
    final ok = await showConfirmDialog(
      context,
      title: s.switchTo(to.label(s)),
      message: const BudgetMethodologyService()
          .switchPreview(
              s: AppStrings.of(context),
              from: from,
              to: to,
              categoryBudgetCount: count),
      confirmLabel: s.switchAction,
    );
    if (ok != true) return;
    // AC5：只改呈现与校验，不触碰任何账单/报表数据
    ref.read(ledgerSettingsProvider.notifier).setBudgetMethodology(to);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final hide = ref.watch(hideAmountsProvider);
    final async = ref.watch(_budgetDataProvider);
    final methodology = ref.watch(ledgerSettingsProvider).budgetMethodology;
    return Scaffold(
      appBar: PlainTopBar(
        title: s.entityBudget,
        showBack: true,
        actions: [
          Material(
            color: const Color(0x00000000),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: _addCategoryBudget,
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 52,
                height: 44,
                child: Center(
                  child: Text(s.newAction, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: context.colors.primary)),
                ),
              ),
            ),
          ),
        ],
      ),
      body: ContentWidthConstraint(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => AppErrorState.of(context, e, onRetry: () => ref.invalidateData.bumpEverything()),
          data: (data) {
            final totalStatus = data.totalStatus;
            final categoryStatuses = data.categoryStatuses;
            final expenseCategories = data.expenseCategories;
            return ListView(
              padding: const EdgeInsets.only(bottom: 100),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.sm),
                  child: PlainSeg(
                    items: [for (final m in _methodologies) m.label(AppStrings.of(context))],
                    selectedIndex: _methodologies.indexOf(methodology),
                    onChanged: (i) => _switchMethodology(_methodologies[i]),
                  ),
                ),
                _Hero(status: totalStatus, hide: hide, onEditTotal: _editTotal),
                if (categoryStatuses.isEmpty && methodology == BudgetMethodology.custom)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
                    child: AppEmptyState(
                      icon: PlainIconData.chartLine,
                      title: s.noCategoryLimits,
                      subtitle: s.noCategoryLimitsHint,
                      action: FilledButton.icon(
                        onPressed: _addCategoryBudget,
                        icon: const PlainIcon(PlainIconData.plus),
                        label: Text(s.addLimit),
                      ),
                    ),
                  )
                else ...[
                  // 四套方法论共享同一份分类预算数据，只是呈现方式不同（AC6）
                  switch (methodology) {
                    BudgetMethodology.custom => _categoryList(
                        context, categoryStatuses, expenseCategories, hide),
                    BudgetMethodology.envelope =>
                      _envelopeList(context, categoryStatuses, hide),
                    BudgetMethodology.zeroBased => _zeroBasedView(
                        context, data.incomeCents, categoryStatuses),
                    BudgetMethodology.fiftyThirtyTwenty => _ratioView(
                        context,
                        data.incomeCents,
                        categoryStatuses,
                        expenseCategories,
                      ),
                  },
                  const SizedBox(height: Spacing.md),
                ],
                _NotePanel(),
              ],
            );
          },
        ),
      ),
    );
  }

  /// 方法论①：分类限额（默认）——总预算 + 分类预算行。
  Widget _categoryList(
    BuildContext context,
    List<BudgetStatus> statuses,
    List<Category> categories,
    bool hide,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PlainEyebrow('分类限额 · ${statuses.length} 类'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.colors.border),
            ),
            child: Column(
              children: [
                for (var i = 0; i < statuses.length; i++) ...[
                  if (i > 0)
                    Divider(
                        height: 1,
                        thickness: 1,
                        indent: 16,
                        color: context.colors.divider),
                  _CategoryProgressRow(
                    status: statuses[i],
                    hide: hide,
                    categories: categories,
                    onEdit: () => _editCategory(statuses[i]),
                    onDelete: () => _deleteBudget(statuses[i].budget),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 方法论②：信封法——每类一个信封，独立滚存，超支不许跨类挪用（AC1/AC2）。
  Widget _envelopeList(
    BuildContext context,
    List<BudgetStatus> statuses,
    bool hide,
  ) {
    final envelopes = const BudgetMethodologyService().envelopes([
      for (final s in statuses)
        CategorySpendInput(
          categoryId: s.budget.categoryId ?? s.budget.id,
          name: _categoryNameOf(s),
          limitCents: s.limitCents,
          spentCents: s.spentCents,
          isRigid: false,
        ),
    ]);
    final overs = envelopes.where((e) => e.isOver).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PlainEyebrow('信封 · ${envelopes.length} 个${overs > 0 ? ' · $overs 个超支' : ''}'),
        PlainPanel(
          children: [
            for (var i = 0; i < envelopes.length; i++) ...[
              if (i > 0)
                Divider(
                    height: 1,
                    thickness: 1,
                    indent: 16,
                    color: context.colors.divider),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(envelopes[i].name,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w500)),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          hide
                              ? '✱✱✱✱'
                              : '余 ${formatAmountYuan(envelopes[i].remainingCents)}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: envelopes[i].isOver
                                ? context.colors.expense
                                : context.colors.ink,
                          ),
                        ),
                        Text(
                          envelopes[i].isOver
                              ? '已超支 ${formatAmountYuan(envelopes[i].overdraftCents)}，不可跨类挪用'
                              : '已花 ${formatAmountYuan(envelopes[i].spentCents)}',
                          style: TextStyle(
                              fontSize: 12, color: context.colors.inkTertiary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.sm, Spacing.lg, 0),
          child: Text(
            '信封法下每个信封独立滚存；某个信封超支时，不能把别类的额度挪过来。',
            style: TextStyle(fontSize: 12, color: context.colors.inkTertiary),
          ),
        ),
      ],
    );
  }

  /// 方法论③：零基预算——收入逐项分配，未分配必须为 0（AC3）。
  Widget _zeroBasedView(
    BuildContext context,
    int incomeCents,
    List<BudgetStatus> statuses,
  ) {
    final view = const BudgetMethodologyService().zeroBased(
      incomeCents: incomeCents,
      items: [
        for (final s in statuses)
          CategorySpendInput(
            categoryId: s.budget.categoryId ?? s.budget.id,
            name: _categoryNameOf(s),
            limitCents: s.limitCents,
            spentCents: s.spentCents,
            isRigid: false,
          ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!view.isBalanced)
          Padding(
            padding: const EdgeInsets.fromLTRB(Spacing.lg, 0, Spacing.lg, Spacing.sm),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: context.colors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  // AC3：待分配金额常驻页顶，直到归零
                  view.unallocatedCents > 0
                      ? '待分配 ${formatAmountYuan(view.unallocatedCents)}'
                      : '已超分配 ${formatAmountYuan(-view.unallocatedCents)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.colors.accent,
                  ),
                ),
              ),
            ),
          ),
        PlainEyebrow('分配明细'),
        PlainPanel(
          children: [
            _PlainKV(label: '当期收入', value: formatAmountYuan(view.incomeCents)),
            _PlainKV(label: '已分配到分类', value: formatAmountYuan(view.allocatedCents)),
            _PlainKV(
              label: '待分配',
              value: formatAmountYuan(view.unallocatedCents),
              bold: true,
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.sm, Spacing.lg, 0),
          child: Text(
            '零基预算要求把收入分配干净（待分配为 0）。分配用的是同一批分类预算，不影响账单。',
            style: TextStyle(fontSize: 12, color: context.colors.inkTertiary),
          ),
        ),
      ],
    );
  }

  /// 方法论④：50/30/20——需要 / 想要 / 储蓄三档（AC4）。
  ///
  /// 「需要」= 分类的刚性支出标记，其余支出算「想要」，储蓄 = 收入 − 总支出。
  Widget _ratioView(
    BuildContext context,
    int incomeCents,
    List<BudgetStatus> statuses,
    List<Category> categories,
  ) {
    final rigid = {for (final c in categories) c.id: c.isRigid};
    final buckets = const BudgetMethodologyService().ratioBuckets(
      incomeCents: incomeCents,
      // 50/30/20 是固定预设，比例集中在核心常量里，不在页面写死数字
      needsBp: BudgetRatioRules.needsBp,
      wantsBp: BudgetRatioRules.wantsBp,
      items: [
        for (final s in statuses)
          CategorySpendInput(
            categoryId: s.budget.categoryId ?? s.budget.id,
            name: _categoryNameOf(s),
            limitCents: s.limitCents,
            spentCents: s.spentCents,
            isRigid: rigid[s.budget.categoryId] ?? false,
          ),
      ],
    );
    final rigidCount = statuses
        .where((s) => rigid[s.budget.categoryId] ?? false)
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PlainEyebrow('三档占比'),
        PlainPanel(
          children: [
            for (final b in buckets)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(b.kind.label(AppStrings.of(context)),
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w500)),
                      ),
                      Text(
                        '${(b.actualRatio(incomeCents) * 100).toStringAsFixed(1)}%'
                        ' / 目标 ${(b.targetRatio(incomeCents) * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: context.colors.ink,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 2),
                    Text(
                      '${formatAmountYuan(b.actualCents)} · 目标 '
                      '${formatAmountYuan(b.targetCents)}'
                      '${b.deltaCents == 0 ? '' : b.deltaCents > 0 ? ' · 超出 ${formatAmountYuan(b.deltaCents)}' : ' · 低于 ${formatAmountYuan(-b.deltaCents)}'}',
                      style: TextStyle(
                          fontSize: 12, color: context.colors.inkTertiary),
                    ),
                  ],
                ),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.sm, Spacing.lg, 0),
          child: Text(
            '「需要」取分类的刚性支出标记（$rigidCount 条已标记），其余算「想要」，'
            '「储蓄」= 收入 − 总支出。可在分类管理里调整刚性标记。',
            style: TextStyle(fontSize: 12, color: context.colors.inkTertiary),
          ),
        ),
      ],
    );
  }

  String _categoryNameOf(BudgetStatus st) {
    final s = AppStrings.of(context);
    final id = st.budget.categoryId;
    if (id == null) return s.remTotalBudget;
    final cats = ref.read(_budgetDataProvider).value?.expenseCategories ??
        const <Category>[];
    for (final c in cats) {
      if (c.id == id) return c.name;
    }
    return s.unnamedCategory;
  }

  Future<void> _editTotal() async {
    final deps = ref.read(appDependenciesProvider);
    final current = ref.read(_budgetDataProvider).value?.totalStatus?.budget;
    final picked = await _askAmount(context, initial: current?.amount, initialRollover: current?.rollover ?? false);
    if (picked == null || !mounted) return;
    final amount = picked.amount;
    final rollover = picked.rollover;
    final now = deps.clock.now();
    if (current == null) {
      await deps.budgetRepository.create(Budget(
        id: deps.idGen.generate(), bookId: deps.bookId, scope: BudgetScope.total,
        amount: amount, rollover: rollover, createdAt: now, updatedAt: now, deviceId: deps.deviceId,
      ));
    } else {
      await deps.budgetRepository.update(current.copyWith(
        amount: amount, rollover: rollover, updatedAt: now,
        revision: current.revision + 1, baseRevision: current.revision,
      ));
    }
    ref.invalidateData.bumpBudgetMutated();
  }

  Future<void> _addCategoryBudget() async {
    final cat = await _pickCategory();
    if (cat == null || !mounted) return;
    final picked = await _askAmount(context);
    if (picked == null || !mounted) return;
    final deps = ref.read(appDependenciesProvider);
    final now = deps.clock.now();
    await deps.budgetRepository.create(Budget(
      id: deps.idGen.generate(), bookId: deps.bookId, scope: BudgetScope.category,
      categoryId: cat.id, amount: picked.amount, rollover: picked.rollover,
      createdAt: now, updatedAt: now, deviceId: deps.deviceId,
    ));
    ref.invalidateData.bumpBudgetMutated();
    // STORY-5.5 探索类徽章：首次设预算
    await GamificationService.unlockExplorationBadge('budget');
  }

  Future<void> _editCategory(BudgetStatus status) async {
    final picked = await _askAmount(context, initial: status.budget.amount, initialRollover: status.budget.rollover);
    if (picked == null || !mounted) return;
    // STORY-11.1 AC2：信封法下不许跨类挪用——额度不能调到低于已花金额
    final methodology =
        ref.read(ledgerSettingsProvider).budgetMethodology;
    final guard = const BudgetMethodologyService().validateEnvelopeLimitChange(
      s: AppStrings.of(context),
      methodology: methodology,
      categoryName: _categoryNameOf(status),
      newLimitCents: picked.amount.cents,
      spentCents: status.spentCents,
    );
    final failure = guard.failureOrNull;
    if (failure != null) {
      showAppToast(context, failure.message);
      return;
    }
    final deps = ref.read(appDependenciesProvider);
    final now = deps.clock.now();
    final b = status.budget;
    await deps.budgetRepository.update(b.copyWith(
      amount: picked.amount, rollover: picked.rollover, updatedAt: now,
      revision: b.revision + 1, baseRevision: b.revision,
    ));
    ref.invalidateData.bumpBudgetMutated();
  }

  Future<void> _deleteBudget(Budget budget) async {
    final s = AppStrings.of(context);
    final okDel = await showConfirmDialog(
      context,
      title: '删除预算',
      message: '删除后不可恢复，确定删除这笔预算？',
      confirmLabel: s.delete,
      destructive: true,
    );
    if (okDel != true || !mounted) return;
    final deps = ref.read(appDependenciesProvider);
    await deps.budgetRepository.softDelete(budget.id);
    ref.invalidateData.bumpBudgetMutated();
  }

  Future<Category?> _pickCategory() async {
    return showModalBottomSheet<Category>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0x00000000),
      builder: (ctx) => _CategoryPickerSheet(
        categories: (ref.read(_budgetDataProvider).value?.expenseCategories ?? const []).leaves,
      ),
    );
  }

  Future<({Money amount, bool rollover})?> _askAmount(
    BuildContext context, {
    Money? initial,
    bool initialRollover = false,
  }) async {
    final controller = TextEditingController(text: initial == null ? '' : initial.toYuanString());
    var rollover = initialRollover;
    final result = await showDialog<({String text, bool rollover})>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('预算金额'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(prefixText: '¥ ', hintText: '0.00'),
              ),
              const SizedBox(height: Spacing.sm),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('结余滚存'),
                subtitle: const Text('上期未用完的额度计入本期'),
                value: rollover,
                onChanged: (v) => setDialogState(() => rollover = v),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, (text: controller.text, rollover: rollover)),
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
    if (result == null || result.text.trim().isEmpty) return null;
    try {
      final m = Money.parseYuan(result.text.trim());
      if (m.isZero || !m.withinProductLimit) return null;
      return (amount: m, rollover: result.rollover);
    } on FormatException {
      return null;
    }
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.status, required this.hide, required this.onEditTotal});
  final BudgetStatus? status;
  final bool hide;
  final VoidCallback onEditTotal;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final colors = context.colors;
    final spent = status?.spentCents ?? 0;
    final limit = status?.limitCents ?? 0;
    final remaining = status?.remainingCents ?? 0;
    final pct = limit > 0 ? (spent / limit * 100).toStringAsFixed(1) : '0.0';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(height: 1, thickness: 1, color: colors.border),
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8, left: 2),
            child: Text(
              s.budgetUsedThisMonth,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.08 * 12, color: colors.inkTertiary),
            ),
          ),
          GestureDetector(
            onTap: onEditTotal,
            child: Text.rich(
              TextSpan(
                children: [
                  // 设计稿屏 26 `.hero-amt` 实测：数字 = 34 / **w400** / 行盒 **45** /
                  // ls **normal**；百分号 = **21.08（= 34 × 0.62）** / w600 / 行盒 **28**。
                  // 原代码三处都与设计稿不符：`w700`、`34 * 0.52`、`letterSpacing: -0.5`。
                  //
                  // ⚠️ 这里是 `line-height: normal`，**不是** `.amt` 的 1.16/1.12。
                  // `normal` 是关键字，**按各元素自身的 font-size 重算**：
                  // 34 → 45，派生段 21.08 → 27.95 → **28**。
                  // 所以派生段要用 `designLineHeight(21.08)` **重新查表**，
                  // 而不是沿用 34 的比值（沿用会得到 27.9，虽只差 0.1 但机制是错的）。
                  TextSpan(
                    text: pct,
                    style: TextStyle(
                      fontSize: 34,
                      height: designLineHeight(34),
                      fontWeight: FontWeight.w400,
                      color: colors.ink,
                    ),
                  ),
                  TextSpan(
                    text: '%',
                    style: TextStyle(
                      fontSize: 34 * 0.62,
                      height: designLineHeight(34 * 0.62),
                      fontWeight: FontWeight.w600,
                      color: colors.ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _Split(label: s.spentLabel, text: formatAmountYuan(spent, hide: hide)),
              const SizedBox(width: 20),
              _Split(label: s.entityBudget, text: formatAmountYuan(limit, hide: hide)),
              const SizedBox(width: 20),
              _Split(label: s.remainingLabel, text: formatAmountYuan(remaining, hide: hide)),
            ],
          ),
          const SizedBox(height: 16),
          Divider(height: 1, thickness: 1, color: colors.border),
        ],
      ),
    );
  }
}

class _Split extends StatelessWidget {
  const _Split({required this.label, required this.text});
  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: colors.inkTertiary)),
        const SizedBox(height: 4),
        Text(text, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.ink)),
      ],
    );
  }
}

enum _FootnoteTone { normal, warn, over }

class _CategoryProgressRow extends StatelessWidget {
  const _CategoryProgressRow({
    required this.status,
    required this.hide,
    required this.categories,
    required this.onEdit,
    required this.onDelete,
  });
  final BudgetStatus status;
  final bool hide;
  final List<Category> categories;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  String _title(AppStrings s) {
    final id = status.budget.categoryId;
    if (id == null) return s.category;
    for (final c in categories) {
      if (c.id == id) return c.name;
    }
    return s.category;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final appS = AppStrings.of(context);
    final s = status;
    final ratio = s.ratio.clamp(0.0, 1.0).toDouble();
    final tone = switch (s.level) {
      BudgetLevel.over => _FootnoteTone.over,
      BudgetLevel.warn => _FootnoteTone.warn,
      BudgetLevel.ok => _FootnoteTone.normal,
    };
    final barColor = switch (s.level) {
      BudgetLevel.over => colors.expense,
      BudgetLevel.warn => colors.accent,
      BudgetLevel.ok => colors.primary,
    };
    final footnote = s.isOver
        ? appS.overSpent(formatAmountYuan(s.spentCents - s.limitCents, hide: hide))
        : appS.remainingAmount(formatAmountYuan(s.remainingCents, hide: hide));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(color: barColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(_title(AppStrings.of(context)), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500))),
              Text(
                '${formatAmountYuan(s.spentCents, hide: hide)} / ${formatAmountYuan(s.limitCents, hide: hide)}',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.ink),
              ),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          _ProgressBar(progress: ratio, color: barColor),
          const SizedBox(height: Spacing.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  footnote,
                  style: TextStyle(
                    fontSize: 12,
                    color: switch (tone) {
                      _FootnoteTone.over => colors.expense,
                      _FootnoteTone.warn => colors.accent,
                      _FootnoteTone.normal => colors.inkTertiary,
                    },
                  ),
                ),
              ),
              TextButton(onPressed: onEdit, child: Text(appS.actionLogOpUpdate)),
              TextButton(onPressed: onDelete, child: Text(appS.delete)),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlainKV extends StatelessWidget {
  const _PlainKV({required this.label, required this.value, this.bold = false});
  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Expanded(
          child: Text(label,
              style: TextStyle(fontSize: 14, color: colors.inkSecondary)),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
            color: colors.ink,
          ),
        ),
      ]),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.progress, required this.color});
  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      height: 6,
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: progress.clamp(0.0, 1.0).toDouble(),
          child: Container(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      ),
    );
  }
}

class _NotePanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(Spacing.lg),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _RichPara(
              plain: s.budgetNote1Body,
              parts: [
                (true, s.budgetNote1Title),
                (false, s.budgetNote1Body),
              ],
            ),
            const SizedBox(height: Spacing.sm),
            _RichPara(
              plain: s.budgetNote2Plain,
              parts: [
                (false, s.budgetNote2A),
                (true, s.budgetNote2B),
                (false, s.budgetNote2C),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RichPara extends StatelessWidget {
  const _RichPara({required this.plain, required this.parts});
  final String plain;
  final List<(bool, String)> parts;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      label: plain,
      child: Text.rich(
        TextSpan(
          children: [
            for (final (isBold, text) in parts)
              TextSpan(
                text: text,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
                  color: isBold ? colors.ink : colors.inkSecondary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CategoryPickerSheet extends StatelessWidget {
  const _CategoryPickerSheet({required this.categories});
  final List<Category> categories;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final maxH = MediaQuery.sizeOf(context).height * 0.55;
    return Material(
      color: const Color(0x00000000),
      child: Container(
        constraints: BoxConstraints(maxHeight: maxH),
        decoration: BoxDecoration(
          color: context.colors.surfaceCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(color: const Color(0x00000000).withValues(alpha: 0.12), blurRadius: 24, offset: const Offset(0, -4)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 32, height: 4,
              decoration: BoxDecoration(color: context.colors.border, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            Text(s.pickCategory, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.colors.ink)),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(Spacing.xl, 4, Spacing.xl, Spacing.xl),
                itemCount: categories.length,
                separatorBuilder: (_, _) => Divider(height: 1, indent: 52, color: context.colors.divider),
                itemBuilder: (ctx, i) {
                  final c = categories[i];
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Navigator.pop(ctx, c),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: context.colors.primaryLight.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: CategoryIcon(
                              iconRef: c.iconRef,
                              size: 18,
                              color: context.colors.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Text(c.name, style: TextStyle(fontSize: 15, color: context.colors.ink))),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
