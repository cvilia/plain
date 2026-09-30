/// Home flow list page. Date-grouped, keyset paginated, swipe-to-delete.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:plain/app/breakpoints.dart';
import 'package:plain/app/theme/design_tokens.dart';
import 'package:plain/core/constants/app_constants.dart';
import 'package:plain/design_system/category_icons.dart';
import 'package:plain/domain/entities/category.dart' as domain;
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/entities/ledger_entry.dart';
import 'package:plain/features/ledger/controllers/flow_list_controller.dart';
import 'package:plain/features/ledger/presentation/budget_progress_strip.dart';

class FlowListPage extends ConsumerWidget {
  const FlowListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(flowListControllerProvider);
    final controller = ref.read(flowListControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('流水'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => controller.refresh()),
        ],
      ),
      body: state.groups.isEmpty && !state.isLoading
          ? ContentWidthConstraint(child: _EmptyState(onEntryTap: () => _openEntry(context, ref)))
          : ContentWidthConstraint(
              child: Column(children: [
                const BudgetProgressStrip(),
                Expanded(child: _FlowList(state: state, controller: controller)),
              ]),
            ),
    );
  }

  Future<void> _openEntry(BuildContext context, WidgetRef ref) async {
    await context.push('/entry');
    ref.read(flowListControllerProvider.notifier).refresh();
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onEntryTap});
  final VoidCallback onEntryTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 80, color: BrandColors.inkTertiary),
          const SizedBox(height: Spacing.lg),
          Text('还没有记录', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: BrandColors.inkSecondary)),
          const SizedBox(height: Spacing.sm),
          Text('点击下方按钮记一笔', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: BrandColors.inkTertiary)),
          const SizedBox(height: Spacing.xl),
          FilledButton.icon(onPressed: onEntryTap, icon: const Icon(Icons.add), label: const Text('记一笔')),
        ],
      ),
    );
  }
}

class _FlowList extends StatelessWidget {
  const _FlowList({required this.state, required this.controller});
  final FlowListState state;
  final FlowListController controller;

  @override
  Widget build(BuildContext context) {
    final groups = state.groups;
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: groups.length + (state.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == groups.length) {
          WidgetsBinding.instance.addPostFrameCallback((_) => controller.loadMore());
          return const Center(child: Padding(padding: EdgeInsets.all(Spacing.lg), child: CircularProgressIndicator()));
        }
        return _DayGroupWidget(group: groups[index], controller: controller, categoryMap: state.categoryMap);
      },
    );
  }
}

class _DayGroupWidget extends StatelessWidget {
  const _DayGroupWidget({required this.group, required this.controller, required this.categoryMap});
  final DayGroup group;
  final FlowListController controller;
  final Map<String, domain.Category> categoryMap;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.lg, Spacing.lg, Spacing.sm),
        child: Row(children: [
          Text(_dayLabel(group.dayKey), style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: BrandColors.ink)),
          const Spacer(),
          if (group.dayExpense > 0)
            Text('-${(group.dayExpense / 100).toStringAsFixed(2)}', style: TextStyle(fontSize: 12, color: BrandColors.expense)),
          if (group.dayIncome > 0) ...[
            const SizedBox(width: Spacing.sm),
            Text('+${(group.dayIncome / 100).toStringAsFixed(2)}', style: TextStyle(fontSize: 12, color: BrandColors.income)),
          ],
        ]),
      ),
      ...group.entries.map((e) => _EntryTile(entry: e, category: categoryMap[e.categoryId], controller: controller)),
    ]);
  }

  String _dayLabel(String dayKey) {
    final now = DateTime.now();
    final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final y = now.subtract(const Duration(days: 1));
    final yest = '${y.year}-${y.month.toString().padLeft(2, '0')}-${y.day.toString().padLeft(2, '0')}';
    if (dayKey == today) return '今天';
    if (dayKey == yest) return '昨天';
    final parts = dayKey.split('-');
    return parts.length == 3 ? '${parts[1]}-${parts[2]}' : dayKey;
  }
}

class _EntryTile extends StatefulWidget {
  const _EntryTile({required this.entry, required this.category, required this.controller});
  final LedgerEntry entry;
  final domain.Category? category;
  final FlowListController controller;

  @override
  State<_EntryTile> createState() => _EntryTileState();
}

class _EntryTileState extends State<_EntryTile> {
  bool _dismissing = false;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final category = widget.category;
    final controller = widget.controller;
    final isExpense = entry.type == EntryType.expense;
    final isIncome = entry.type == EntryType.income;
    final amountColor = isExpense ? BrandColors.expense : isIncome ? BrandColors.income : BrandColors.transfer;
    final prefix = isExpense ? '-' : isIncome ? '+' : '';
    final amountText = '$prefix${(entry.amount.cents / 100).toStringAsFixed(2)}';

    return Dismissible(
      key: Key(entry.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: Spacing.lg),
        color: BrandColors.expense.withValues(alpha: 0.15),
        child: Icon(Icons.delete_outline, color: BrandColors.expense),
      ),
      confirmDismiss: (direction) async {
        // Prevent multiple calls during dismiss animation
        if (_dismissing) return false;
        _dismissing = true;

        final ok = await controller.deleteEntry(entry.id);
        if (ok && mounted) {
          // Clear old snackbars first, then show new one
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..clearSnackBars()
            ..showSnackBar(SnackBar(
              content: const Text('已删除'),
              duration: UiDurations.undoWindow,
              action: SnackBarAction(
                label: '撤销',
                onPressed: () async {
                  await controller.undoDelete();
                },
              ),
            ));
        }
        return ok;
      },
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.xs),
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: amountColor.withValues(alpha: 0.1),
          child: Icon(iconForCategory(category?.iconRef ?? 'other'), size: 20, color: amountColor),
        ),
        title: Text(category?.name ?? '未分类', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
        subtitle: entry.note != null && entry.note!.isNotEmpty
            ? Text(entry.note!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: BrandColors.inkTertiary))
            : null,
        trailing: Text(amountText, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: amountColor)),
        onTap: () => context.push('/entry/${entry.id}'),
      ),
    );
  }
}
