/// STORY-3.3 安全可花卡片：首页核心数字 + 日均 + 三行拆解。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plain/app/bootstrap.dart';
import 'package:plain/app/theme/app_colors.dart';
import 'package:plain/app/theme/design_tokens.dart';
import 'package:plain/core/format/amount_formatter.dart';
import 'package:plain/core/refresh/data_invalidation.dart';
import 'package:plain/domain/services/safe_to_spend_service.dart';

final _safeToSpendProvider = FutureProvider<SafeToSpendResult?>((ref) async {
  ref.watch(ledgerVersionProvider);
  ref.watch(accountsVersionProvider);
  ref.watch(budgetVersionProvider);
  ref.watch(recurringVersionProvider);
  ref.watch(categoriesVersionProvider);
  final deps = ref.watch(appDependenciesProvider);
  final calendar = ref.watch(calendarProvider);
  final calc = SafeToSpendCalculator(
    accountRepository: deps.accountRepository,
    budgetRepository: deps.budgetRepository,
    recurringRepository: deps.recurringRepository,
    savingsGoalRepository: deps.savingsGoalRepository,
    categoryRepository: deps.categoryRepository,
    calendar: calendar,
    bookId: deps.bookId,
  );
  return calc.calculate();
});

class SafeToSpendCard extends ConsumerWidget {
  const SafeToSpendCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_safeToSpendProvider);
    return async.when(
      loading: () => const SizedBox(height: 8),
      error: (_, _) => const SizedBox.shrink(),
      data: (r) {
        if (r == null || !r.hasAnyBudget) return const SizedBox.shrink();
        return _Card(result: r);
      },
    );
  }
}

class _Card extends StatefulWidget {
  const _Card({required this.result});
  final SafeToSpendResult result;

  @override
  State<_Card> createState() => _CardState();
}

class _CardState extends State<_Card> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    final colors = context.colors;
    final hideAmounts = false; // AmountText handles hide mode via provider
    final safe = r.safeToSpendCents;
    final daily = r.dailyAverageCents;

    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.md),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.all(Spacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('今日可花', style: TextStyle(fontSize: 12, color: colors.inkTertiary, letterSpacing: 2)),
                          const SizedBox(height: 4),
                          Text(
                            formatAmount(safe, hide: hideAmounts),
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w600,
                              color: r.isNegative ? colors.expense : colors.ink,
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('日均', style: TextStyle(fontSize: 11, color: colors.inkTertiary)),
                        const SizedBox(height: 2),
                        Text(
                          formatAmount(daily, hide: hideAmounts),
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: colors.inkSecondary),
                        ),
                        Text('剩 ${r.remainingDays} 天', style: TextStyle(fontSize: 10, color: colors.inkTertiary)),
                      ],
                    ),
                  ],
                ),
                if (r.isNegative) ...[
                  const SizedBox(height: Spacing.sm),
                  Text('本月已超支，建议暂停非必要支出', style: TextStyle(fontSize: 12, color: colors.expense)),
                ],
                if (_expanded) ...[
                  const SizedBox(height: Spacing.md),
                  const Divider(height: 1),
                  const SizedBox(height: Spacing.sm),
                  _BreakRow(label: '可用资金', value: r.availableCents, color: colors.income),
                  _BreakRow(label: '未来账单预留', value: -r.futureBillsCents, color: colors.expense),
                  _BreakRow(label: '目标待拨付', value: -r.goalAllocationCents, color: colors.expense),
                  _BreakRow(label: '刚性支出预留', value: -r.rigidReserveCents, color: colors.expense),
                ],
                const SizedBox(height: Spacing.sm),
                Row(
                  children: [
                    Icon(_expanded ? Icons.expand_less : Icons.expand_more, size: 18, color: colors.inkTertiary),
                    const SizedBox(width: 4),
                    Text(_expanded ? '收起明细' : '展开明细', style: TextStyle(fontSize: 11, color: colors.inkTertiary)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BreakRow extends StatelessWidget {
  const _BreakRow({required this.label, required this.value, required this.color});
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 12, color: context.colors.inkSecondary))),
          Text(
            '${value >= 0 ? '+' : ''}${formatAmount(value.abs())}',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: color),
          ),
        ],
      ),
    );
  }
}
