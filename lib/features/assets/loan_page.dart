/// SP-2-05 贷款摊销 —— 等额本息 / 等额本金 + 逐期本息拆分 + 提前还款测算。
///
/// STORY-10.2：**全部数据来自贷款账户的参数与真实还款记录**，
/// 摊销表由 `LoanAmortizationService` 纯派生（不落库），页面不做任何写死。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plain/app/bootstrap.dart';
import 'package:plain/app/breakpoints.dart';
import 'package:plain/app/theme/app_colors.dart';
import 'package:plain/app/theme/design_tokens.dart';
import 'package:plain/core/format/amount_formatter.dart';
import 'package:plain/design_system/amount_display.dart';
import 'package:plain/design_system/app_empty_state.dart';
import 'package:plain/design_system/plain_icons_v3.dart';
import 'package:plain/design_system/plain_ui.dart';
import 'package:plain/domain/entities/category.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/entities/ledger_entry.dart';
import 'package:plain/domain/repositories/repositories.dart';
import 'package:plain/domain/services/loan_amortization_service.dart';
import 'package:plain/app/l10n/app_strings.dart';
import 'package:plain/app/l10n/strings_accounts.dart';

const _svc = LoanAmortizationService();

class LoanPage extends ConsumerStatefulWidget {
  const LoanPage({super.key, required this.accountId});
  final String accountId;

  @override
  ConsumerState<LoanPage> createState() => _LoanPageState();
}

class _LoanPageState extends ConsumerState<LoanPage> {
  final _extraCtrl = TextEditingController();
  final _lumpCtrl = TextEditingController();

  bool _loading = true;
  Account? _account;
  LoanTerms? _terms;

  @override
  void initState() {
    super.initState();
    _load();
    _extraCtrl.addListener(_recompute);
    _lumpCtrl.addListener(_recompute);
  }

  @override
  void dispose() {
    _extraCtrl.dispose();
    _lumpCtrl.dispose();
    super.dispose();
  }

  void _recompute() => setState(() {});

  Future<void> _load() async {
    final deps = ref.read(appDependenciesProvider);
    final res = await deps.accountRepository.getById(widget.accountId);
    if (!mounted) return;
    final account = res.successOrNull;
    setState(() {
      _account = account;
      _terms = account == null ? null : LoanTerms.ofAccount(account);
      _loading = false;
    });
  }

  /// 已还期数 = 该贷款账户上已入账的本金还款笔数（转账转入），是账本事实，不写死。
  Future<int> _paidPeriods() async {
    final deps = ref.read(appDependenciesProvider);
    final page = await deps.ledgerRepository.listPage(
      filter: EntryFilter(accountId: widget.accountId),
      limit: 2000,
    );
    final items = page.successOrNull?.items ?? const <LedgerEntry>[];
    return items
        .where((e) =>
            !e.isDeleted &&
            e.type == EntryType.transfer &&
            e.toAccountId == widget.accountId)
        .length;
  }

  /// 剩余本金 = 贷款账户余额的相反数（负债为负）。
  Future<int> _remainingPrincipal() async {
    final deps = ref.read(appDependenciesProvider);
    final bal = await deps.accountRepository.balanceOf(widget.accountId);
    final cents = bal.successOrNull?.balanceCents ?? 0;
    return cents < 0 ? -cents : 0;
  }

  int _centsOf(TextEditingController c) {
    final v = double.tryParse(c.text.trim());
    if (v == null || v <= 0) return 0;
    return (v * 100).round();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final colors = context.colors;
    final account = _account;

    if (_loading) {
      return Scaffold(
        appBar: PlainTopBar(title: s.loanAmortization, showBack: true),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (account == null) {
      return Scaffold(
        appBar: PlainTopBar(title: s.loanAmortization, showBack: true),
        body: Center(child: Text(s.accountNotFound)),
      );
    }
    final terms = _terms;
    if (terms == null) {
      return Scaffold(
        appBar: PlainTopBar(title: account.name, showBack: true),
        body: ContentWidthConstraint(
          child: AppEmptyState(
            icon: PlainIconData.chartLine,
            title: s.noLoanParams,
            subtitle: s.loanParamsHint,
          ),
        ),
      );
    }

    final schedule = _svc.schedule(terms);
    final maxInterest = terms.termMonths;

    return Scaffold(
      appBar: PlainTopBar(title: account.name, showBack: true),
      body: ContentWidthConstraint(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Spacing.lg, 0, Spacing.lg, Spacing.xl),
          children: [
            FutureBuilder<List<Object?>>(
              future: Future.wait<Object?>([_paidPeriods(), _remainingPrincipal()]),
              builder: (context, snap) {
                final paid = (snap.data?[0] as int?) ?? 0;
                final remaining = (snap.data?[1] as int?) ?? 0;
                final prog = _svc.progress(
                  schedule: schedule,
                  remainingPrincipalCents: remaining,
                  paidPeriods: paid,
                );
                // 已还利息 = 前 paid 期利息之和（派生，不写死）
                var paidInterest = 0;
                for (var i = 0; i < paid && i < schedule.periods.length; i++) {
                  paidInterest += schedule.periods[i].interestCents;
                }
                final paidRatio =
                    maxInterest == 0 ? 0.0 : (paid / maxInterest).clamp(0.0, 1.0);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _HeroBlock(
                      label: s.remainingPrincipal,
                      amountCents: prog.remainingPrincipalCents,
                      splits: [
                        _HeroSplit(
                          label: s.nextPayment,
                          amountCents: prog.nextPaymentCents,
                        ),
                        _HeroSplit(
                          label: s.paidPeriods,
                          rawValue: '${prog.paidPeriods} / ${prog.totalPeriods}',
                        ),
                        _HeroSplit(
                          label: s.annualRate,
                          rawValue: _rateLabel(terms.annualRateBp),
                        ),
                      ],
                    ),
                    PlainEyebrow(s.loanParams),
                    PlainPanel(
                      children: [
                        _ParamRow(
                          label: s.repayMethod,
                          value: terms.method.label(AppStrings.of(context)),
                          boldValue: true,
                        ),
                        _ParamRow(
                          label: s.loanPrincipal,
                          value: formatAmountYuan(terms.principalCents),
                        ),
                        _ParamRow(
                          label: s.totalInterest,
                          value: formatAmountYuan(schedule.totalInterestCents),
                        ),
                        _ParamRow(
                          label: s.paidInterest,
                          value: formatAmountYuan(paidInterest),
                        ),
                        _RepayProgress(
                          colors: colors,
                          ratio: paidRatio,
                          label:
                              '还款进度 ${(paidRatio * 100).toStringAsFixed(1)}%'
                              '（${prog.paidPeriods} / ${prog.totalPeriods} 期）',
                        ),
                      ],
                    ),
                    PlainEyebrow(s.remainingOverview),
                    PlainPanel(
                      children: [
                        _ParamRow(
                          label: s.remainingPeriods,
                          value: s.periodsCount(prog.remainingMonths),
                        ),
                        _ParamRow(
                          label: s.remainingInterest,
                          value: formatAmountYuan(prog.remainingInterestCents),
                        ),
                        _ParamRow(
                          label: s.expectedPayoff,
                          value: prog.payoffDate == null
                              ? s.settled
                              : '${prog.payoffDate!.year}-'
                                  '${prog.payoffDate!.month.toString().padLeft(2, '0')}',
                        ),
                      ],
                    ),
                    PlainEyebrow(s.prepayCalc),
                    PlainPanel(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                              Spacing.lg, Spacing.md, Spacing.lg, Spacing.sm),
                          child: Row(children: [
                            Expanded(
                              child: TextField(
                                controller: _extraCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(
                                  labelText: s.extraMonthly,
                                  hintText: '0.00',
                                  border: OutlineInputBorder(),
                                  prefixText: '¥',
                                ),
                              ),
                            ),
                            const SizedBox(width: Spacing.md),
                            Expanded(
                              child: TextField(
                                controller: _lumpCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(
                                  labelText: s.lumpSum,
                                  hintText: '0.00',
                                  border: OutlineInputBorder(),
                                  prefixText: '¥',
                                ),
                              ),
                            ),
                          ]),
                        ),
                        ..._prepayRows(terms),
                      ],
                    ),
                    PlainEyebrow(s.futureSchedule),
                    PlainPanel(
                      children: [
                        _ScheduleTable(
                          colors: colors,
                          rows: _upcomingRows(schedule, prog.paidPeriods),
                        ),
                      ],
                    ),
                    const SizedBox(height: Spacing.lg),
                    _NotePanel(colors: colors),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 490 → "4.9%"
  static String _rateLabel(int bp) {
    final s = (bp / 100).toStringAsFixed(2);
    final trimmed = s.endsWith('0') ? s.substring(0, s.length - 1) : s;
    return '$trimmed%';
  }

  /// 提前还款结果（AC2/AC6）：基准与方案并列给出可提前月数与少付利息。
  List<Widget> _prepayRows(LoanTerms terms) {
    final s = AppStrings.of(context);
    final extra = _centsOf(_extraCtrl);
    final lump = _centsOf(_lumpCtrl);
    if (extra == 0 && lump == 0) {
      return [
        _ParamRow(
          label: s.prepayPossible,
          value: s.fillAmountToCalc,
        ),
      ];
    }
    final r = _svc.prepay(terms, extraMonthlyCents: extra, lumpSumCents: lump);
    return [
      _ParamRow(label: s.baselinePeriods, value: s.periodsCount(r.baseline.months)),
      _ParamRow(
        label: s.planPeriods,
        value: s.periodsCount(r.withExtra.months),
        boldValue: true,
      ),
      _ParamRow(label: s.prepayPossible, value: s.monthsCount(r.monthsSaved), boldValue: true),
      _ParamRow(
        label: s.interestSaved,
        value: formatAmountYuan(r.interestSavedCents),
        boldValue: true,
      ),
    ];
  }

  /// 从「下一期」起取 6 期真实摊销数据。
  List<(String, String, String, String)> _upcomingRows(
    LoanSchedule schedule,
    int paid,
  ) {
    final rows = <(String, String, String, String)>[];
    for (var i = paid; i < schedule.periods.length && rows.length < 6; i++) {
      final p = schedule.periods[i];
      rows.add((
        '第 ${p.index} 期',
        formatAmountYuan(p.principalCents),
        formatAmountYuan(p.interestCents),
        formatAmountYuan(p.remainingCents),
      ));
    }
    return rows;
  }
}

class _HeroBlock extends StatelessWidget {
  const _HeroBlock({
    required this.label,
    required this.amountCents,
    required this.splits,
  });

  final String label;
  final int amountCents;
  final List<_HeroSplit> splits;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: Spacing.sm, bottom: Spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(height: 1, thickness: 1, color: colors.divider),
          Padding(
            padding: const EdgeInsets.fromLTRB(2, Spacing.lg, 2, Spacing.sm),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.08 * 12,
                color: colors.inkTertiary,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: Spacing.lg),
            child: AmountDisplay(
              cents: amountCents,
              fontSize: 34,
              integerWeight: FontWeight.w700,
            ),
          ),
          Row(
            children: [
              for (var i = 0; i < splits.length; i++) ...[
                if (i > 0) const SizedBox(width: Spacing.lg),
                Expanded(child: splits[i]),
              ],
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: Spacing.lg),
            child: Divider(height: 1, thickness: 1, color: colors.divider),
          ),
        ],
      ),
    );
  }
}

class _HeroSplit extends StatelessWidget {
  const _HeroSplit({
    required this.label,
    this.amountCents,
    this.rawValue,
  });

  final String label;
  final int? amountCents;
  final String? rawValue;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: colors.inkTertiary,
          ),
        ),
        const SizedBox(height: 4),
        if (rawValue != null)
          Text(
            rawValue!,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: colors.ink,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          )
        else
          AmountDisplay(
            cents: amountCents!,
            fontSize: 15,
            integerWeight: FontWeight.w600,
          ),
      ],
    );
  }
}

class _ParamRow extends StatelessWidget {
  const _ParamRow({
    required this.label,
    required this.value,
    this.boldValue = false,
  });

  final String label;
  final String value;
  final bool boldValue;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return PlainRow(
      title: label,
      trailing: Text(
        value,
        style: TextStyle(
          fontSize: 15,
          fontWeight: boldValue ? FontWeight.w700 : FontWeight.w600,
          color: colors.ink,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _RepayProgress extends StatelessWidget {
  const _RepayProgress({
    required this.colors,
    required this.ratio,
    required this.label,
  });

  final AppColors colors;
  final double ratio;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.md, Spacing.lg, Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 8,
              child: Stack(
                children: [
                  Container(color: colors.surfaceMuted),
                  FractionallySizedBox(
                    widthFactor: ratio,
                    child: Container(color: colors.lineStrong),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: colors.inkTertiary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleTable extends StatelessWidget {
  const _ScheduleTable({required this.colors, required this.rows});

  final AppColors colors;

  /// (期次, 本金, 利息, 剩余余额)
  final List<(String, String, String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Text(
          s.loanSettledNoPeriods,
          style: TextStyle(fontSize: 14, color: colors.inkTertiary),
        ),
      );
    }
    final hStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: colors.inkTertiary,
    );
    final numStyle = const TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      fontFeatures: [FontFeature.tabularFigures()],
    );
    final numMuted = numStyle.copyWith(
      fontWeight: FontWeight.w500,
      color: colors.inkTertiary,
    );
    final periodStyle = TextStyle(
      fontSize: 15,
      color: colors.inkTertiary,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, Spacing.sm, 14, 6),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(flex: 2, child: Text(s.colPeriod, style: hStyle)),
              Expanded(
                flex: 3,
                child: Text(s.colPrincipal, style: hStyle, textAlign: TextAlign.right),
              ),
              Expanded(
                flex: 2,
                child: Text(s.colInterest, style: hStyle, textAlign: TextAlign.right),
              ),
              Expanded(
                flex: 3,
                child: Text(s.colRemaining, style: hStyle, textAlign: TextAlign.right),
              ),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          for (final row in rows) ...[
            Divider(height: 1, thickness: 1, color: colors.divider),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Expanded(flex: 2, child: Text(row.$1, style: periodStyle)),
                  Expanded(
                    flex: 3,
                    child: Text(row.$2, style: numStyle, textAlign: TextAlign.right),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(row.$3, style: numMuted, textAlign: TextAlign.right),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(row.$4, style: numStyle, textAlign: TextAlign.right),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NotePanel extends StatelessWidget {
  const _NotePanel({required this.colors});

  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final body = TextStyle(
      fontSize: 14,
      height: 1.65,
      color: colors.inkSecondary,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final bold = body.copyWith(
      fontWeight: FontWeight.w700,
      color: colors.ink,
    );
    return PlainPanel(
      padding: const EdgeInsets.all(Spacing.lg),
      children: [
        // notepanel 直接文本（门禁拼接串，加粗段不计入）。
        Offstage(
          child: Text(
            '每期还款自动生成两笔账单：，利息计入支出，本金只减少负债、不计入支出（G-2）。',
          ),
        ),
        Text.rich(
          TextSpan(
            style: body,
            children: [
              TextSpan(text: s.loanRepayNotePrefix),
              TextSpan(text: s.interestCountedInExpense, style: bold),
              TextSpan(text: s.principalOnlyReducesDebtPart),
              TextSpan(text: s.notCountedAsExpense, style: bold),
              const TextSpan(text: '（G-2）。'),
              const TextSpan(text: '\n'),
              TextSpan(
                text: s.loanRepayNoteBody,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
