/// Home flow list page. Date-grouped, keyset paginated, swipe-to-delete.
/// Visual source of truth: 09-高保真UI.html SP-0-02.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:plain/app/breakpoints.dart';
import 'package:plain/app/theme/design_tokens.dart';
import 'package:plain/app/theme/tokens.dart';
import 'package:plain/core/constants/app_constants.dart';
import 'package:plain/design_system/category_icons.dart';
import 'package:plain/domain/entities/category.dart' as domain;
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/entities/ledger_entry.dart';
import 'package:plain/features/ledger/controllers/flow_list_controller.dart';

class FlowListPage extends ConsumerWidget {
  const FlowListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    watchBrandTheme(ref);
    final state = ref.watch(flowListControllerProvider);
    final controller = ref.read(flowListControllerProvider.notifier);

    return Scaffold(
      body: state.groups.isEmpty && !state.isLoading
          ? ContentWidthConstraint(child: _EmptyState(onEntryTap: () => _openEntry(context)))
          : ContentWidthConstraint(
              child: _FlowList(state: state, controller: controller),
            ),
    );
  }

  Future<void> _openEntry(BuildContext context) async {
    await context.push('/entry');
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
    // Keep the balance card clear of the status bar / notch.
    final topPad = MediaQuery.paddingOf(context).top + Spacing.sm;
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(Spacing.lg, topPad, Spacing.lg, 96),
      itemCount: 1 + groups.length + (state.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == 0) return _BalanceCard(state: state);
        final gi = index - 1;
        if (gi == groups.length) {
          WidgetsBinding.instance.addPostFrameCallback((_) => controller.loadMore());
          return const Center(child: Padding(padding: EdgeInsets.all(Spacing.lg), child: CircularProgressIndicator()));
        }
        return _DayGroupWidget(group: groups[gi], controller: controller, categoryMap: state.categoryMap);
      },
    );
  }
}

/// 结余卡：hero 渐变 + 漂浮光斑（高保真记忆点）。
class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.state});
  final FlowListState state;

  @override
  Widget build(BuildContext context) {
    var income = 0;
    var expense = 0;
    for (final g in state.groups) {
      income += g.dayIncome;
      expense += g.dayExpense;
    }
    final balance = income - expense;
    final now = DateTime.now();
    final monthLabel = '${now.year}年${now.month}月';

    return Padding(
      padding: const EdgeInsets.only(top: Spacing.md, bottom: Spacing.lg),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: heroGradient(BrandColors.heroStart, BrandColors.heroEnd),
                ),
              ),
            ),
            // 漂浮光斑
            Positioned(top: -34, right: -20, child: _GlowOrb(size: 120, opacity: 0.13)),
            Positioned(bottom: -26, right: 44, child: _GlowOrb(size: 84, opacity: 0.10)),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '本月结余',
                    style: TextStyle(
                      fontSize: 12,
                      letterSpacing: 4,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${balance >= 0 ? '+' : ''}${(balance / 100).toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: Colors.white,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _BalanceStat(label: '收入', value: '+${(income / 100).toStringAsFixed(2)}', color: const Color(0xFFFFDCC6)),
                      const SizedBox(width: Spacing.xl),
                      _BalanceStat(label: '支出', value: '-${(expense / 100).toStringAsFixed(2)}', color: const Color(0xFFDFF2EC)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    monthLabel,
                    style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.7)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.opacity});
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacity),
      ),
    );
  }
}

class _BalanceStat extends StatelessWidget {
  const _BalanceStat({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.75))),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: color)),
      ],
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
    if (parts.length != 3) return dayKey;
    final wd = const ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
    final dt = DateTime.tryParse(dayKey);
    final weekday = dt == null ? '' : ' ${wd[dt.weekday % 7]}';
    return '${int.parse(parts[1])}月${int.parse(parts[2])}日$weekday';
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
        subtitle: Text(
          _subtitleOf(entry),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, color: BrandColors.inkTertiary),
        ),
        trailing: Text(amountText, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: amountColor)),
        onTap: () => context.push('/entry/${entry.id}'),
      ),
    );
  }

  String _subtitleOf(LedgerEntry entry) {
    final t = entry.occurredAt.toLocal();
    final hm = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    final note = entry.note;
    if (note != null && note.isNotEmpty) return '$hm  $note';
    return hm;
  }
}
