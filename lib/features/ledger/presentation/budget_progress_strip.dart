/// Compact total-budget progress strip for the home flow list. See PRD F5.1.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plain/app/bootstrap.dart';
import 'package:plain/app/breakpoints.dart';
import 'package:plain/app/theme/design_tokens.dart';
import 'package:plain/core/format/amount_formatter.dart';
import 'package:plain/core/refresh/data_invalidation.dart';
import 'package:plain/domain/entities/budget.dart';
import 'package:plain/domain/entities/enums.dart';

final budgetStatusProvider = FutureProvider.autoDispose<BudgetStatus?>((ref) async {
  // Refetch when entries or budget rules change.
  ref.watch(ledgerVersionProvider);
  ref.watch(budgetVersionProvider);
  final deps = ref.watch(appDependenciesProvider);
  final res = await deps.resolveBudgetStatus.totalStatus(deps.bookId);
  return res.successOrNull;
});

class BudgetProgressStrip extends ConsumerWidget {
  const BudgetProgressStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(budgetStatusProvider);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (status) {
        if (status == null) return const SizedBox.shrink();
        final hide = ref.watch(hideAmountsProvider);
        final ratio = status.ratio.clamp(0.0, 1.0);
        final color = switch (status.level) {
          BudgetLevel.over => BrandColors.expense,
          BudgetLevel.warn => BrandColors.accent,
          BudgetLevel.ok => BrandColors.primary,
        };
        return Padding(
          padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.sm, Spacing.lg, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(
                    '本月预算 ${formatAmountYuan(status.spentCents, hide: hide)} / ${formatAmountYuan(status.limitCents, hide: hide)}',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: AdaptiveFontSizes.caption,
                      color: BrandColors.inkSecondary,
                    ),
                  ),
                ),
                Text(
                  status.isOver ? '已超支' : '日均可用 ${formatAmountYuan(status.dailyAvailableCents, hide: hide)}',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: AdaptiveFontSizes.caption,
                    color: color, fontWeight: FontWeight.w600,
                  ),
                ),
              ]),
              const SizedBox(height: Spacing.xs),
              ClipRRect(
                borderRadius: BorderRadius.circular(Radii.pill),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 6,
                  backgroundColor: BrandColors.surfaceMuted,
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
