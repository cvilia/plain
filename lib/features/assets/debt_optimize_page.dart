/// SP-2-07 债务优化 —— 雪球法 vs 雪崩法。
///
/// STORY-10.5：输入来自**真实的债务账户**——
/// - 信用卡：欠款取 `creditDebtCents`（存储值），年利率与最低还款取账户上录入的事实；
/// - 贷款：剩余本金取账户余额的相反数，年利率取贷款参数，最低还款取**摊销表首期月供**。
///
/// 缺年利率或最低还款的债务无法参与测算，页面会点名提示补录，不替用户假设。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plain/app/bootstrap.dart';
import 'package:plain/app/breakpoints.dart';
import 'package:plain/app/theme/app_colors.dart';
import 'package:plain/app/theme/design_tokens.dart';
import 'package:plain/core/format/amount_formatter.dart';
import 'package:plain/design_system/app_empty_state.dart';
import 'package:plain/design_system/plain_icons_v3.dart';
import 'package:plain/design_system/plain_ui.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/repositories/repositories.dart';
import 'package:plain/domain/services/debt_optimization_service.dart';
import 'package:plain/domain/services/loan_amortization_service.dart';
import 'package:plain/app/l10n/app_strings.dart';
import 'package:plain/app/l10n/strings_accounts.dart';

const _svc = DebtOptimizationService();
const _loanSvc = LoanAmortizationService();

class DebtOptimizePage extends ConsumerStatefulWidget {
  const DebtOptimizePage({super.key});

  @override
  ConsumerState<DebtOptimizePage> createState() => _DebtOptimizePageState();
}

class _DebtOptimizePageState extends ConsumerState<DebtOptimizePage> {
  final _extraCtrl = TextEditingController();

  bool _loading = true;
  List<DebtItem> _debts = const [];

  /// 因缺少年利率/最低还款而无法参与的债务账户名。
  List<String> _incomplete = const [];

  /// 外币负债账户名（口径：不参与债务测算，需手动维护）。
  List<String> _foreignDebts = const [];

  @override
  void initState() {
    super.initState();
    _extraCtrl.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _extraCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final deps = ref.read(appDependenciesProvider);
    final accountsRes = await deps.accountRepository.listWithBalances();
    final accounts = accountsRes.successOrNull ?? const <AccountWithBalance>[];
    if (!mounted) return;

    final debts = <DebtItem>[];
    final incomplete = <String>[];
    // 外币负债不参与测算（口径 2026-10-15）：本金原币、流水本位币，算不出可信的剩余本金
    final foreignDebts = <String>[];

    for (final ab in accounts) {
      final a = ab.account;

      if (a.needsManualDebtNote) {
        foreignDebts.add(a.name);
        continue;
      }

      // 信用卡：欠款 = 存储值
      if (a.isCredit) {
        final debt = a.creditDebtCents;
        if (debt <= 0) continue;
        if (a.creditAnnualRateBp <= 0 || a.minPaymentCents <= 0) {
          incomplete.add(a.name);
          continue;
        }
        debts.add(DebtItem(
          id: a.id,
          name: a.name,
          balanceCents: debt,
          annualRateBp: a.creditAnnualRateBp,
          minPaymentCents: a.minPaymentCents,
        ));
        continue;
      }

      // 贷款：剩余本金 = 余额的相反数；最低还款 = 摊销表首期月供
      if (a.type == AccountType.loanIn) {
        final remaining = ab.balanceCents < 0 ? -ab.balanceCents : 0;
        if (remaining <= 0) continue;
        final terms = LoanTerms.ofAccount(a);
        if (terms == null) {
          incomplete.add(a.name);
          continue;
        }
        final schedule = _loanSvc.schedule(terms);
        if (schedule.isEmpty) {
          incomplete.add(a.name);
          continue;
        }
        debts.add(DebtItem(
          id: a.id,
          name: a.name,
          balanceCents: remaining,
          annualRateBp: terms.annualRateBp,
          minPaymentCents: schedule.periods.first.paymentCents,
        ));
      }
    }

    setState(() {
      _debts = debts;
      _incomplete = incomplete;
      _foreignDebts = foreignDebts;
      _loading = false;
    });
  }

  int get _extraCents {
    final v = double.tryParse(_extraCtrl.text.trim());
    if (v == null || v <= 0) return 0;
    return (v * 100).round();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final colors = context.colors;
    return Scaffold(
      appBar: PlainTopBar(title: s.debtOptimize, showBack: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ContentWidthConstraint(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    Spacing.lg, 0, Spacing.lg, Spacing.xl),
                children: [
                  if (_debts.isEmpty)
                    AppEmptyState(
                      icon: PlainIconData.chartLine,
                      title: s.noDebtsToCalc,
                      subtitle: _incomplete.isEmpty
                          ? s.noDebtsHint
                          : '以下账户缺少年利率/最低还款：${_incomplete.join('、')}',
                    )
                  else ...[
                    PlainEyebrow(s.extraMonthlyRepay),
                    PlainPanel(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                              Spacing.lg, Spacing.md, Spacing.lg, Spacing.md),
                          child: TextField(
                            controller: _extraCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: InputDecoration(
                              labelText: s.extraBeyondMinLabel,
                              hintText: '0.00',
                              border: OutlineInputBorder(),
                              prefixText: '¥',
                            ),
                          ),
                        ),
                      ],
                    ),
                    ..._result(colors),
                    PlainEyebrow(s.debtsCount(_debts.length)),
                    PlainPanel(
                      children: [
                        for (var i = 0; i < _debts.length; i++) ...[
                          if (i > 0)
                            Divider(
                                height: 1,
                                thickness: 1,
                                indent: 16,
                                color: colors.divider),
                          _DebtRow(debt: _debts[i], colors: colors),
                        ],
                      ],
                    ),
                  ],
                  if (_incomplete.isNotEmpty && _debts.isNotEmpty) ...[
                    const SizedBox(height: Spacing.md),
                    _NotePanel(
                      lines: [
                        '以下账户缺少年利率或最低还款，未参与测算：${_incomplete.join('、')}。'
                            '在账户里补全后即可加入对比。',
                      ],
                    ),
                  ],
                  if (_foreignDebts.isNotEmpty) ...[
                    const SizedBox(height: Spacing.md),
                    _NotePanel(
                      // 结合实际场景：外币贷款常见于海外房贷/留学贷款，
                      // 这类债务的剩余本金要用户自己盯，不能让测算给个假数字
                      lines: [
                        '以下外币负债未参与测算：${_foreignDebts.join('、')}。'
                            '它们的本金是外币、流水记的是本位币，折算不出可信的剩余本金，'
                            '请手动维护余额与还款计划。',
                      ],
                    ),
                  ],
                  const SizedBox(height: Spacing.md),
                  _NotePanel(
                    lines: [
                      '两种方法都是「每月预算固定 = Σ最低还款 + 额外还款」，'
                          '某笔结清后它让出的最低还款自动滚向下一个目标。',
                      s.debtMethodNoteB,
                      if (_extraCents == 0)
                        '当前未填额外还款：此时没有余钱可调度，两种方法的推进方式相同，'
                            '要看出差异请填入额外还款。',
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  /// AC1/AC2/AC3：两种策略并列 + 推荐理由。
  List<Widget> _result(AppColors colors) {
    final s = AppStrings.of(context);
    final cmp = _svc.compare(_debts, extraMonthlyCents: _extraCents);
    return [
      PlainEyebrow(s.strategyCompare),
      PlainPanel(
        children: [
          for (final plan in [cmp.avalanche, cmp.snowball]) ...[
            _PlanBlock(
              plan: plan,
              isRecommended: plan.strategy == cmp.recommended,
              extraCents: _extraCents,
              colors: colors,
            ),
          ],
        ],
      ),
      if (cmp.savingCents > 0)
        Padding(
          padding: const EdgeInsets.only(top: Spacing.sm),
          child: Text(
            cmp.reason(AppStrings.of(context)),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colors.income,
            ),
          ),
        ),
    ];
  }
}

class _PlanBlock extends StatelessWidget {
  const _PlanBlock({
    required this.plan,
    required this.isRecommended,
    required this.extraCents,
    required this.colors,
  });

  final DebtPlan plan;
  final bool isRecommended;
  final int extraCents;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final orderText = plan.order.isEmpty
        ? '—'
        : plan.order.map((s) => '${s.name}(${s.month}月)').join(' → ');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(
              plan.strategy.label(AppStrings.of(context)),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: colors.ink,
              ),
            ),
            if (isRecommended) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.income.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(s.cheaper,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colors.income)),
              ),
            ],
          ]),
          const SizedBox(height: 6),
          Text(
            plan.settled
                ? s.settledSummary(plan.months, formatAmountYuan(plan.totalInterestCents))
                : s.notSettledSummary(plan.months),
            style: TextStyle(fontSize: 14, color: colors.inkSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            s.orderLabel(orderText),
            style: TextStyle(fontSize: 12, color: colors.inkTertiary),
          ),
        ],
      ),
    );
  }
}

class _DebtRow extends StatelessWidget {
  const _DebtRow({required this.debt, required this.colors});
  final DebtItem debt;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final rate = (debt.annualRateBp / 100).toStringAsFixed(2);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(debt.name,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w500)),
            ),
            Text(formatAmountYuan(debt.balanceCents),
                style: TextStyle(fontSize: 15, color: colors.ink)),
          ]),
          const SizedBox(height: 2),
          Text(
            s.debtRateLine(rate, formatAmountYuan(debt.minPaymentCents)),
            style: TextStyle(fontSize: 12, color: colors.inkTertiary),
          ),
        ],
      ),
    );
  }
}

class _NotePanel extends StatelessWidget {
  const _NotePanel({required this.lines});
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return PlainPanel(
      padding: const EdgeInsets.all(Spacing.lg),
      children: [
        for (final l in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(l,
                style: TextStyle(
                    fontSize: 14, height: 1.65, color: colors.inkSecondary)),
          ),
      ],
    );
  }
}
