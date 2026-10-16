/// SP-3-03 资金年龄（Age of Money）。
///
/// STORY-11.4：数字 + 近 6 个月趋势 + 一句话解读。
/// 全部由真实账单按 FIFO 算出（`MoneyAgeService`），页面无写死值。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plain/app/bootstrap.dart';
import 'package:plain/app/breakpoints.dart';
import 'package:plain/app/settings/ledger_settings.dart';
import 'package:plain/app/theme/app_colors.dart';
import 'package:plain/app/theme/design_tokens.dart';
import 'package:plain/app/theme/typography.dart';
import 'package:plain/design_system/app_empty_state.dart';
import 'package:plain/design_system/plain_icons_v3.dart';
import 'package:plain/design_system/plain_ui.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/services/money_age_service.dart';

const _svc = MoneyAgeService();

class MoneyAgePage extends ConsumerStatefulWidget {
  const MoneyAgePage({super.key});

  @override
  ConsumerState<MoneyAgePage> createState() => _MoneyAgePageState();
}

class _MoneyAgePageState extends ConsumerState<MoneyAgePage> {
  bool _loading = true;
  MoneyAgeResult? _result;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final deps = ref.read(appDependenciesProvider);
    // 取全量账单：FIFO 需要从最早的收入开始排队，不能只取当月
    final page = await deps.ledgerRepository.listPage(limit: 5000);
    if (!mounted) return;
    final entries = page.successOrNull?.items ?? const [];

    // G-2：只有真正计入收支的账单参与（排除对账调整、拆分子笔、转账等）
    final incomes = <MoneyLot>[];
    final expenses = <MoneyLot>[];
    for (final e in entries) {
      if (e.isDeleted) continue;
      if (!e.countsInOutflow) continue;
      final lot = MoneyLot(at: e.occurredAt, cents: e.amount.cents);
      if (e.type == EntryType.income) {
        incomes.add(lot);
      } else if (e.type == EntryType.expense) {
        expenses.add(lot);
      }
    }

    final now = deps.clock.now();
    final result = _svc.evaluate(
      incomes: incomes,
      expenses: expenses,
      months: MoneyAgeService.recentMonths(
        now: now.toLocal(),
        monthStartDay: ref.read(monthStartDayProvider),
        count: 6,
      ),
    );
    setState(() {
      _result = result;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    return Scaffold(
      appBar: const PlainTopBar(title: '资金年龄', showBack: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ContentWidthConstraint(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    Spacing.lg, 0, Spacing.lg, Spacing.xl),
                children: [
                  if (r == null || !r.hasEnoughData)
                    AppEmptyState(
                      icon: PlainIconData.chartLine,
                      title: '数据积累中',
                      subtitle:
                          '资金年龄需要至少 5 笔收入、跨度约两个月的数据。'
                          '当前收入 ${r?.incomeCount ?? 0} 笔、支出 ${r?.expenseCount ?? 0} 笔。',
                    )
                  else ...[
                    _Hero(result: r),
                    PlainEyebrow('近 6 个月趋势'),
                    PlainPanel(children: [_Trend(result: r)]),
                  ],
                  const SizedBox(height: Spacing.md),
                  _NotePanel(result: r),
                ],
              ),
            ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.result});
  final MoneyAgeResult result;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final age = result.currentAgeDays;
    return Padding(
      padding: const EdgeInsets.only(top: Spacing.sm, bottom: Spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(height: 1, thickness: 1, color: colors.divider),
          Padding(
            padding: const EdgeInsets.fromLTRB(2, Spacing.lg, 2, Spacing.sm),
            child: Text(
              '当前资金年龄',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.08 * 12,
                color: colors.inkTertiary,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: Spacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  age == null ? '—' : '${age.round()}',
                  style: TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.w700,
                    color: colors.ink,
                    height: designLineHeight(44),
                  ),
                ),
                const SizedBox(width: 6),
                Text('天',
                    style: TextStyle(fontSize: 15, color: colors.inkSecondary)),
              ],
            ),
          ),
          Text(
            result.interpretation,
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              fontWeight: FontWeight.w600,
              color: colors.inkSecondary,
            ),
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

class _Trend extends StatelessWidget {
  const _Trend({required this.result});
  final MoneyAgeResult result;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final maxAge = result.trend
        .map((p) => p.ageDays ?? 0)
        .fold<double>(1, (a, b) => a > b ? a : b);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, Spacing.md, 16, Spacing.md),
      child: Column(
        children: [
          for (final p in result.trend)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                SizedBox(
                  width: 58,
                  child: Text(p.label,
                      style:
                          TextStyle(fontSize: 12, color: colors.inkTertiary)),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: Stack(children: [
                      Container(height: 8, color: colors.surfaceMuted),
                      FractionallySizedBox(
                        widthFactor:
                            (((p.ageDays ?? 0) / maxAge).clamp(0.0, 1.0)),
                        child: Container(
                          height: 8,
                          color: p.ageDays == null
                              ? colors.surfaceMuted
                              : colors.primary,
                        ),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 64,
                  child: Text(
                    p.ageDays == null ? '无支出' : '${p.ageDays!.round()} 天',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colors.ink),
                  ),
                ),
              ]),
            ),
        ],
      ),
    );
  }
}

class _NotePanel extends StatelessWidget {
  const _NotePanel({required this.result});
  final MoneyAgeResult? result;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final r = result;
    final lines = <String>[
      '资金年龄 = 花掉的每一块钱，其来源收入距花掉那天有多久，按金额加权平均。',
      '算法是 FIFO：每笔支出消耗最早尚未用完的那笔收入。',
      '年龄越大越从容——说明钱在手里待得久，不靠当月工资过日子。',
      if (r != null)
        '当前参与计算：收入 ${r.incomeCount} 笔、支出 ${r.expenseCount} 笔。',
      if (r != null && r.trend.any((p) => p.expenseCents > 0))
        '趋势里每月是当月支出的加权平均；当月没花钱显示「无支出」。',
    ];
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
