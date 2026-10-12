/// Home flow list page. Date-grouped, keyset paginated, swipe-to-delete.
/// Visual source of truth: 09-高保真UI.html SP-0-02.
library;

import 'package:plain/app/theme/app_colors.dart';
import 'package:plain/features/ledger/presentation/home_shell.dart';
import 'package:plain/core/time/date_format.dart';
import 'package:plain/design_system/category_avatar.dart';
import 'package:plain/design_system/app_empty_state.dart';
import 'package:flutter/material.dart';
import 'package:plain/design_system/app_toast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:plain/app/breakpoints.dart';
import 'package:plain/app/bootstrap.dart';
import 'package:plain/app/theme/design_tokens.dart';
import 'package:plain/app/theme/tokens.dart';
import 'package:plain/core/format/amount_formatter.dart';
import 'package:plain/core/refresh/data_invalidation.dart';
import 'package:plain/domain/entities/category.dart' as domain;
import 'package:plain/features/ledger/presentation/safe_to_spend_card.dart';
import 'package:plain/features/ledger/presentation/advanced_filter_page.dart';
import 'package:plain/app/settings/home_layout_prefs.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/entities/ledger_entry.dart';
import 'package:plain/features/ledger/controllers/flow_list_controller.dart';

/// 首页卡片布局（order + hidden）（STORY-5.3）。
final _homeLayoutProvider = FutureProvider<(List<String>, Set<String>)>((ref) async {
  ref.watch(homeLayoutVersionProvider);
  final order = await loadHomeCardOrder();
  final hidden = await loadHomeCardHidden();
  return (order, hidden);
});

class FlowListPage extends ConsumerWidget {
  const FlowListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(flowListControllerProvider);
    final controller = ref.read(flowListControllerProvider.notifier);
    final filterCatId = ref.watch(flowCategoryFilterProvider);

    // 写→bump→读：页面级 listen 确保返回本页时列表已重载
    // （Notifier 内 listen 依赖 notifier 存活，页面监听更稳）。
    ref.listen(ledgerVersionProvider, (prev, next) {
      if (prev == next) return;
      controller.refresh();
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('流水'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune, size: 22),
            tooltip: '高级筛选',
            onPressed: () => Navigator.push<void>(
              context,
              MaterialPageRoute(builder: (_) => const AdvancedFilterPage()),
            ),
          ),
          const EntryAppBarAction(),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (filterCatId != null)
              Material(
                color: context.colors.surfaceMuted,
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.filter_alt_outlined, size: 18),
                  title: Text(
                    '已筛选：${state.categoryMap[filterCatId]?.name ?? '该分类'}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  trailing: TextButton(
                    onPressed: () {
                      ref.read(flowCategoryFilterProvider.notifier).clear();
                      controller.refresh();
                    },
                    child: const Text('显示全部'),
                  ),
                ),
              ),
            Expanded(
              child: state.groups.isEmpty && !state.isLoading
                  ? ContentWidthConstraint(
                      child: _EmptyState(onEntryTap: () => _openEntry(context)),
                    )
                  : ContentWidthConstraint(
                      child: _FlowList(state: state, controller: controller),
                    ),
            ),
          ],
        ),
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
    return AppEmptyState(
      icon: Icons.receipt_long_outlined,
      title: '还没有记录',
      subtitle: '点击下方按钮记一笔',
      action: FilledButton.icon(onPressed: onEntryTap, icon: const Icon(Icons.add), label: const Text('记一笔')),
    );
  }
}

class _FlowList extends ConsumerWidget {
  const _FlowList({required this.state, required this.controller});
  final FlowListState state;
  final FlowListController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = state.groups;
    // Keep the balance card clear of the status bar / notch.
    // 顶部安全区由外层 SafeArea 统一处理，这里只留间距
    const topPad = Spacing.sm;

    // 拍平成单一列表：日标题 + 账单各自为 ListView 顶层子项。
    // 嵌套 Column 里的 Dismissible 在删一条后会失效（手势丢失）。
    // 首页卡片按布局偏好排序 + 显示/隐藏（STORY-5.3）。
    final layout = ref.watch(_homeLayoutProvider).maybeWhen(
      data: (v) => v,
      orElse: () => (const <String>[], const <String>{}),
    );
    final (cardOrder, hiddenCards) = layout;
    // 按用户排序决定 balance/safeToSpend 的顺序
    final showBalance = !hiddenCards.contains('monthly_balance');
    final showSafe = !hiddenCards.contains('safe_to_spend');
    final balanceIdx = cardOrder.indexOf('monthly_balance');
    final safeIdx = cardOrder.indexOf('safe_to_spend');
    final headerRows = <_FlowRow>[
      if (showBalance) const _FlowRow.balance(),
      if (showSafe) const _FlowRow.safeToSpend(),
    ];
    // 按 order 中的相对位置排序
    headerRows.sort((a, b) {
      final ia = a.kind == _FlowRowKind.balance ? (balanceIdx < 0 ? 0 : balanceIdx) : (safeIdx < 0 ? 1 : safeIdx);
      final ib = b.kind == _FlowRowKind.balance ? (balanceIdx < 0 ? 0 : balanceIdx) : (safeIdx < 0 ? 1 : safeIdx);
      return ia.compareTo(ib);
    });
    final rows = <_FlowRow>[
      ...headerRows,
      for (final g in groups) ...[
        _FlowRow.dayHeader(g),
        for (final e in g.entries) _FlowRow.entry(e),
      ],
      if (state.hasMore) const _FlowRow.more(),
    ];

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(Spacing.lg, topPad, Spacing.lg, 96),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        switch (row.kind) {
          case _FlowRowKind.balance:
            return _BalanceCard(state: state);
          case _FlowRowKind.safeToSpend:
            return const SafeToSpendCard();
          case _FlowRowKind.dayHeader:
            return _DayHeader(group: row.group!, key: ValueKey('day-${row.group!.dayKey}'));
          case _FlowRowKind.entry:
            final e = row.entry!;
            return _EntryTile(
              key: ValueKey('e-${e.id}'),
              entry: e,
              category: state.categoryMap[e.categoryId],
              controller: controller,
            );
          case _FlowRowKind.more:
            WidgetsBinding.instance.addPostFrameCallback((_) => controller.loadMore());
            return const Center(child: Padding(padding: EdgeInsets.all(Spacing.lg), child: CircularProgressIndicator()));
        }
      },
    );
  }
}

enum _FlowRowKind { balance, safeToSpend, dayHeader, entry, more }

class _FlowRow {
  const _FlowRow.balance() : kind = _FlowRowKind.balance, group = null, entry = null;
  const _FlowRow.safeToSpend() : kind = _FlowRowKind.safeToSpend, group = null, entry = null;
  const _FlowRow.dayHeader(DayGroup this.group) : kind = _FlowRowKind.dayHeader, entry = null;
  const _FlowRow.entry(LedgerEntry this.entry) : kind = _FlowRowKind.entry, group = null;
  const _FlowRow.more() : kind = _FlowRowKind.more, group = null, entry = null;

  final _FlowRowKind kind;
  final DayGroup? group;
  final LedgerEntry? entry;
}

/// 结余卡：hero 渐变 + 漂浮光斑（高保真记忆点）。
class _BalanceCard extends ConsumerWidget {
  const _BalanceCard({required this.state});
  final FlowListState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hideAmounts = ref.watch(hideAmountsProvider);
    var income = 0;
    var expense = 0;
    for (final g in state.groups) {
      income += g.dayIncome;
      expense += g.dayExpense;
    }
    final balance = income - expense;
    final now = ref.read(appDependenciesProvider).clock.now().toLocal();
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
                  gradient: heroGradient(context.colors.heroStart, context.colors.heroEnd),
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
                    '${balance >= 0 ? '+' : ''}${formatAmount(balance, hide: hideAmounts)}',
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
                      _BalanceStat(label: '收入', value: '+${formatAmount(income, hide: hideAmounts)}', color: const Color(0xFFFFDCC6)),
                      const SizedBox(width: Spacing.xl),
                      _BalanceStat(label: '支出', value: '-${formatAmount(expense, hide: hideAmounts)}', color: const Color(0xFFDFF2EC)),
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

class _DayHeader extends ConsumerWidget {
  const _DayHeader({super.key, required this.group});
  final DayGroup group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hideAmounts = ref.watch(hideAmountsProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.lg, Spacing.lg, Spacing.sm),
      child: Row(children: [
        Text(dayLabel(group.dayKey), style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: context.colors.ink)),
        const Spacer(),
        if (group.dayExpense > 0)
          Text('-${formatAmount(group.dayExpense, hide: hideAmounts)}', style: TextStyle(fontSize: 12, color: context.colors.expense)),
        if (group.dayIncome > 0) ...[
          const SizedBox(width: Spacing.sm),
          Text('+${formatAmount(group.dayIncome, hide: hideAmounts)}', style: TextStyle(fontSize: 12, color: context.colors.income)),
        ],
      ]),
    );
  }
}

class _EntryTile extends ConsumerStatefulWidget {
  const _EntryTile({super.key, required this.entry, required this.category, required this.controller});
  final LedgerEntry entry;
  final domain.Category? category;
  final FlowListController controller;

  @override
  ConsumerState<_EntryTile> createState() => _EntryTileState();
}

class _EntryTileState extends ConsumerState<_EntryTile> {
  bool _dismissing = false;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final category = widget.category;
    final controller = widget.controller;
    final isExpense = entry.type == EntryType.expense;
    final isIncome = entry.type == EntryType.income;
    final isTransfer = entry.type == EntryType.transfer;
    final amountColor = isExpense ? context.colors.expense : isIncome ? context.colors.income : context.colors.transfer;
    final prefix = isExpense ? '-' : isIncome ? '+' : '';
    final amountText = isTransfer
        ? formatAmount(entry.amount.cents, hide: ref.watch(hideAmountsProvider))
        : '$prefix${formatAmount(entry.amount.cents, hide: ref.watch(hideAmountsProvider))}';
    // STORY-1.7 AC4：转账双行（去向 / 来源）
    final subtitle = isTransfer
        ? '转账 · ${entry.accountId ?? ''} → ${entry.toAccountId ?? ''}'
        : _subtitleOf(entry);

    return Dismissible(
      key: Key(entry.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: Spacing.lg),
        color: context.colors.expense.withValues(alpha: 0.15),
        child: Icon(Icons.delete_outline, color: context.colors.expense),
      ),
      // confirmDismiss 只做防重入；真正移除必须在 onDismissed 同步完成
      // （Flutter 要求 dismissed 后控件立刻离开树，否则触发断言）。
      confirmDismiss: (_) async {
        if (_dismissing) return false;
        _dismissing = true;
        return true;
      },
      onDismissed: (_) {
        // ① 同步移除本地条目（不可 await）
        controller.removeLocal(entry.id);
        // ② 异步删库 + toast
        controller.deleteEntry(entry.id).then((ok) {
          if (!context.mounted) return;
          if (ok) {
            showAppToastWithAction(
              context,
              '已删除',
              actionLabel: '撤销',
              onAction: () => controller.undoDelete(),
            );
          } else {
            showAppToast(context, '删除失败');
          }
        });
      },
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.xs),
        leading: CategoryAvatar(iconRef: category?.iconRef ?? 'other', iconAsset: category?.iconAsset, color: amountColor),
        title: Text(
          '${category?.name ?? '未分类'}${entry.isSplitParent ? ' · 拆分' : entry.isSplitChild ? ' · 子笔' : ''}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, color: context.colors.inkTertiary),
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

