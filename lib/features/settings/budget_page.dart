/// Budget settings page. See PRD F5.1/F5.2.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plain/app/bootstrap.dart';
import 'package:plain/app/breakpoints.dart';
import 'package:plain/app/theme/design_tokens.dart';
import 'package:plain/core/format/amount_formatter.dart';
import 'package:plain/core/money/money.dart';
import 'package:plain/domain/entities/budget.dart';
import 'package:plain/domain/entities/category.dart';
import 'package:plain/domain/entities/enums.dart';

class BudgetPage extends ConsumerStatefulWidget {
  const BudgetPage({super.key});

  @override
  ConsumerState<BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends ConsumerState<BudgetPage> {
  BudgetStatus? _totalStatus;
  List<BudgetStatus> _categoryStatuses = const [];
  List<Category> _expenseCategories = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final deps = ref.read(appDependenciesProvider);
    final total = await deps.resolveBudgetStatus.totalStatus(deps.bookId);
    final all = await deps.resolveBudgetStatus.allStatuses(deps.bookId);
    final cats = await deps.categoryRepository.listVisible(kind: CategoryKind.expense);
    if (!mounted) return;
    setState(() {
      _totalStatus = total.successOrNull;
      final list = all.successOrNull ?? const <BudgetStatus>[];
      _categoryStatuses = list.where((s) => !s.budget.isTotal).toList();
      _expenseCategories = cats.successOrNull ?? const [];
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hide = ref.watch(hideAmountsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('预算')),
      body: ContentWidthConstraint(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.only(bottom: 100),
                children: [
                  const SizedBox(height: Spacing.md),
                  _TotalBudgetCard(status: _totalStatus, hide: hide, onEdit: _editTotal),
                  const SizedBox(height: Spacing.lg),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
                    child: Row(
                      children: [
                        Text('分类预算', style: TextStyle(
                          fontSize: AdaptiveFontSizes.title,
                          fontWeight: FontWeight.w600,
                          color: BrandColors.ink,
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
                  if (_categoryStatuses.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(Spacing.xl),
                      child: Text(
                        '还没有分类预算。给常超支的分类设个上限吧。',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: BrandColors.inkTertiary, fontSize: AdaptiveFontSizes.body),
                      ),
                    )
                  else
                    ..._categoryStatuses.map((s) => _CategoryBudgetTile(
                      status: s, hide: hide,
                      onEdit: () => _editCategory(s),
                      onDelete: () => _deleteBudget(s.budget),
                    )),
                ],
              ),
      ),
    );
  }

  Future<void> _editTotal() async {
    final deps = ref.read(appDependenciesProvider);
    final current = _totalStatus?.budget;
    final amount = await _askAmount(context, initial: current?.amount);
    if (amount == null || !mounted) return;
    final now = deps.clock.now();
    if (current == null) {
      await deps.budgetRepository.create(Budget(
        id: deps.idGen.generate(), bookId: deps.bookId, scope: BudgetScope.total,
        amount: amount, createdAt: now, updatedAt: now, deviceId: deps.deviceId,
      ));
    } else {
      await deps.budgetRepository.update(current.copyWith(
        amount: amount, updatedAt: now,
        revision: current.revision + 1, baseRevision: current.revision,
      ));
    }
    await _load();
  }

  Future<void> _addCategoryBudget() async {
    final cat = await _pickCategory();
    if (cat == null || !mounted) return;
    final amount = await _askAmount(context);
    if (amount == null || !mounted) return;
    final deps = ref.read(appDependenciesProvider);
    final now = deps.clock.now();
    await deps.budgetRepository.create(Budget(
      id: deps.idGen.generate(), bookId: deps.bookId, scope: BudgetScope.category,
      categoryId: cat.id, amount: amount, createdAt: now, updatedAt: now,
      deviceId: deps.deviceId,
    ));
    await _load();
  }

  Future<void> _editCategory(BudgetStatus status) async {
    final amount = await _askAmount(context, initial: status.budget.amount);
    if (amount == null || !mounted) return;
    final deps = ref.read(appDependenciesProvider);
    final now = deps.clock.now();
    final b = status.budget;
    await deps.budgetRepository.update(b.copyWith(
      amount: amount, updatedAt: now,
      revision: b.revision + 1, baseRevision: b.revision,
    ));
    await _load();
  }

  Future<void> _deleteBudget(Budget budget) async {
    final okDel = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除预算'),
        content: const Text('删除后不可恢复，确定删除这笔预算？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除')),
        ],
      ),
    );
    if (okDel != true || !mounted) return;
    final deps = ref.read(appDependenciesProvider);
    await deps.budgetRepository.softDelete(budget.id);
    await _load();
  }

  Future<Category?> _pickCategory() async {
    return showDialog<Category>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('选择分类'),
        children: _expenseCategories
            .map((c) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, c),
                  child: Text(c.name),
                ))
            .toList(),
      ),
    );
  }

  Future<Money?> _askAmount(BuildContext context, {Money? initial}) async {
    final controller = TextEditingController(
      text: initial == null ? '' : initial.toYuanString());
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('预算金额'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(prefixText: '¥ ', hintText: '0.00'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('确定')),
        ],
      ),
    );
    if (result == null || result.trim().isEmpty) return null;
    try {
      final m = Money.parseYuan(result.trim());
      if (m.isZero || !m.withinProductLimit) return null;
      return m;
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
    final theme = Theme.of(context);
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
              Text('未设置月度总预算', style: TextStyle(color: BrandColors.inkTertiary))
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
    required this.onEdit, required this.onDelete,
  });
  final BudgetStatus status;
  final bool hide;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

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
                status.budget.categoryId ?? '分类',
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
      BudgetLevel.over => BrandColors.expense,
      BudgetLevel.warn => BrandColors.accent,
      BudgetLevel.ok => BrandColors.primary,
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
            backgroundColor: BrandColors.surfaceMuted,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
        const SizedBox(height: Spacing.sm),
        Row(children: [
          Expanded(child: Text(
            '已用 ${formatAmountYuan(s.spentCents, hide: hide)} / ${formatAmountYuan(s.limitCents, hide: hide)}',
            style: TextStyle(fontSize: AdaptiveFontSizes.caption, color: BrandColors.inkSecondary),
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
          style: TextStyle(fontSize: AdaptiveFontSizes.caption, color: BrandColors.inkTertiary),
          maxLines: 1, overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
