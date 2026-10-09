/// Budget settings page. See PRD F5.1/F5.2.
library;

import 'package:plain/app/theme/app_colors.dart';
import 'package:plain/design_system/confirm_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plain/app/bootstrap.dart';
import 'package:plain/app/breakpoints.dart';
import 'package:plain/app/theme/design_tokens.dart';
import 'package:plain/core/format/amount_formatter.dart';
import 'package:plain/core/refresh/data_invalidation.dart';
import 'package:plain/core/money/money.dart';
import 'package:plain/design_system/category_icons.dart';
import 'package:plain/domain/entities/budget.dart';
import 'package:plain/domain/entities/category.dart';
import 'package:plain/domain/entities/enums.dart';


class _BudgetData {
  const _BudgetData({
    required this.totalStatus,
    required this.categoryStatuses,
    required this.expenseCategories,
  });
  final BudgetStatus? totalStatus;
  final List<BudgetStatus> categoryStatuses;
  final List<Category> expenseCategories;
}

/// Read model for the budget page. Watches budget + categories + ledger
/// versions so local writes refetch automatically (AGENTS.md 写→bump / 读→watch).
final _budgetDataProvider = FutureProvider<_BudgetData>((ref) async {
  ref.watch(budgetVersionProvider);
  ref.watch(categoriesVersionProvider);
  ref.watch(ledgerVersionProvider);
  final deps = ref.watch(appDependenciesProvider);
  final total = await deps.resolveBudgetStatus.totalStatus(deps.bookId);
  final all = await deps.resolveBudgetStatus.allStatuses(deps.bookId);
  final cats = await deps.categoryRepository.listVisible(kind: CategoryKind.expense);
  final list = all.successOrNull ?? const <BudgetStatus>[];
  return _BudgetData(
    totalStatus: total.successOrNull,
    categoryStatuses: list.where((s) => !s.budget.isTotal).toList(),
    expenseCategories: cats.successOrNull ?? const [],
  );
});

class BudgetPage extends ConsumerStatefulWidget {
  const BudgetPage({super.key});

  @override
  ConsumerState<BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends ConsumerState<BudgetPage> {
  @override
  Widget build(BuildContext context) {
    final hide = ref.watch(hideAmountsProvider);
    final async = ref.watch(_budgetDataProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('预算')),
      body: ContentWidthConstraint(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('加载失败: $e')),
          data: (data) {
            final totalStatus = data.totalStatus;
            final categoryStatuses = data.categoryStatuses;
            final expenseCategories = data.expenseCategories;
            return ListView(
                padding: const EdgeInsets.only(bottom: 100),
                children: [
                  const SizedBox(height: Spacing.md),
                  _TotalBudgetCard(status: totalStatus, hide: hide, onEdit: _editTotal),
                  const SizedBox(height: Spacing.lg),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
                    child: Row(
                      children: [
                        Text('分类预算', style: TextStyle(
                          fontSize: AdaptiveFontSizes.title,
                          fontWeight: FontWeight.w600,
                          color: context.colors.ink,
                        )),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: _addCategoryBudget,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('添加'),
                        ),
                      ],
                    ),
                  ),
                  if (categoryStatuses.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(Spacing.xl),
                      child: Text(
                        '还没有分类预算。给常超支的分类设个上限吧。',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: context.colors.inkTertiary, fontSize: AdaptiveFontSizes.body),
                      ),
                    )
                  else
                    ...categoryStatuses.map((s) => _CategoryBudgetTile(
                      status: s, hide: hide, categories: expenseCategories,
                      onEdit: () => _editCategory(s),
                      onDelete: () => _deleteBudget(s.budget),
                    )),
                ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _editTotal() async {
    final deps = ref.read(appDependenciesProvider);
    final current = ref.read(_budgetDataProvider).value?.totalStatus?.budget;
    final picked = await _askAmount(
      context,
      initial: current?.amount,
      initialRollover: current?.rollover ?? false,
    );
    if (picked == null || !mounted) return;
    final amount = picked.amount;
    final rollover = picked.rollover;
    final now = deps.clock.now();
    if (current == null) {
      await deps.budgetRepository.create(Budget(
        id: deps.idGen.generate(), bookId: deps.bookId, scope: BudgetScope.total,
        amount: amount, rollover: rollover,
        createdAt: now, updatedAt: now, deviceId: deps.deviceId,
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
    final amount = picked.amount;
    final rollover = picked.rollover;
    final deps = ref.read(appDependenciesProvider);
    final now = deps.clock.now();
    await deps.budgetRepository.create(Budget(
      id: deps.idGen.generate(), bookId: deps.bookId, scope: BudgetScope.category,
      categoryId: cat.id, amount: amount, rollover: rollover,
      createdAt: now, updatedAt: now, deviceId: deps.deviceId,
    ));
    ref.invalidateData.bumpBudgetMutated();
  }

  Future<void> _editCategory(BudgetStatus status) async {
    final picked = await _askAmount(
      context,
      initial: status.budget.amount,
      initialRollover: status.budget.rollover,
    );
    if (picked == null || !mounted) return;
    final amount = picked.amount;
    final rollover = picked.rollover;
    final deps = ref.read(appDependenciesProvider);
    final now = deps.clock.now();
    final b = status.budget;
    await deps.budgetRepository.update(b.copyWith(
      amount: amount, rollover: rollover, updatedAt: now,
      revision: b.revision + 1, baseRevision: b.revision,
    ));
    ref.invalidateData.bumpBudgetMutated();
  }

  Future<void> _deleteBudget(Budget budget) async {
    final okDel = await showConfirmDialog(
      context,
      title: '删除预算',
      message: '删除后不可恢复，确定删除这笔预算？',
      confirmLabel: '删除',
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
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CategoryPickerSheet(
        categories: (ref.read(_budgetDataProvider).value?.expenseCategories ?? const []).leaves,
      ),
    );
  }

  /// Returns amount + rollover flag, or null when cancelled / invalid.
  Future<({Money amount, bool rollover})?> _askAmount(
    BuildContext context, {
    Money? initial,
    bool initialRollover = false,
  }) async {
    final controller = TextEditingController(
      text: initial == null ? '' : initial.toYuanString());
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
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(
                ctx,
                (text: controller.text, rollover: rollover),
              ),
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

class _TotalBudgetCard extends StatelessWidget {
  const _TotalBudgetCard({required this.status, required this.hide, required this.onEdit});
  final BudgetStatus? status;
  final bool hide;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: Spacing.lg),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text('总预算', style: TextStyle(
                fontSize: AdaptiveFontSizes.title, fontWeight: FontWeight.w600)),
              const Spacer(),
              TextButton(onPressed: onEdit, child: Text(status == null ? '设置' : '修改')),
            ]),
            if (status == null)
              Text('未设置月度总预算', style: TextStyle(color: context.colors.inkTertiary))
            else
              _BudgetBody(status: status!, hide: hide),
          ],
        ),
      ),
    );
  }
}

class _CategoryBudgetTile extends StatelessWidget {
  const _CategoryBudgetTile({
    required this.status, required this.hide,
    required this.categories,
    required this.onEdit, required this.onDelete,
  });
  final BudgetStatus status;
  final bool hide;
  final List<Category> categories;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  /// Display name only — never raw categoryId (e.g. preset_food).
  String get _title {
    final id = status.budget.categoryId;
    if (id == null) return '分类';
    for (final c in categories) {
      if (c.id == id) return c.name;
    }
    // Never surface internal ids like preset_food.
    return '分类';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.xs),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text(
                _title,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              )),
              TextButton(onPressed: onEdit, child: const Text('修改')),
              TextButton(onPressed: onDelete, child: const Text('删除')),
            ]),
            _BudgetBody(status: status, hide: hide),
          ],
        ),
      ),
    );
  }
}

class _BudgetBody extends StatelessWidget {
  const _BudgetBody({required this.status, required this.hide});
  final BudgetStatus status;
  final bool hide;

  @override
  Widget build(BuildContext context) {
    final s = status;
    final ratio = s.ratio.clamp(0.0, 1.0);
    final color = switch (s.level) {
      BudgetLevel.over => context.colors.expense,
      BudgetLevel.warn => context.colors.accent,
      BudgetLevel.ok => context.colors.primary,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: Spacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(Radii.pill),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 8,
            backgroundColor: context.colors.surfaceMuted,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
        const SizedBox(height: Spacing.sm),
        Row(children: [
          Expanded(child: Text(
            '已用 ${formatAmountYuan(s.spentCents, hide: hide)} / ${formatAmountYuan(s.limitCents, hide: hide)}',
            style: TextStyle(fontSize: AdaptiveFontSizes.caption, color: context.colors.inkSecondary),
            maxLines: 1, overflow: TextOverflow.ellipsis,
          )),
          Text(
            s.isOver ? '已超支' : '剩余 ${formatAmountYuan(s.remainingCents, hide: hide)}',
            style: TextStyle(fontSize: AdaptiveFontSizes.caption, color: color, fontWeight: FontWeight.w600),
          ),
        ]),
        const SizedBox(height: Spacing.xs),
        Text(
          '剩 ${s.daysLeft} 天 · 日均可用 ${formatAmountYuan(s.dailyAvailableCents, hide: hide)}',
          style: TextStyle(fontSize: AdaptiveFontSizes.caption, color: context.colors.inkTertiary),
          maxLines: 1, overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}


/// Bottom-sheet category picker (budget page).
class _CategoryPickerSheet extends StatelessWidget {
  const _CategoryPickerSheet({required this.categories});
  final List<Category> categories;

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.sizeOf(context).height * 0.55;
    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(maxHeight: maxH),
        decoration: BoxDecoration(
          color: context.colors.surfaceCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 24, offset: const Offset(0, -4)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: context.colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text('选择分类', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.colors.ink)),
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
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: context.colors.primaryLight.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(iconForCategory(c.iconRef), size: 18, color: context.colors.primary),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(c.name, style: TextStyle(fontSize: 15, color: context.colors.ink)),
                          ),
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
