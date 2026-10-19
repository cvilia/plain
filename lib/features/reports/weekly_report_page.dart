/// 本周消费画像（STORY-9.5）。
///
/// 内容与推送同一份数据：`WeeklyReportService.build` 从 daily_stats /
/// transactions 取数，页面无写死金额；文案只陈述、只夸不贬。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plain/app/bootstrap.dart';
import 'package:plain/app/breakpoints.dart';
import 'package:plain/app/theme/app_colors.dart';
import 'package:plain/app/theme/design_tokens.dart';
import 'package:plain/app/theme/typography.dart';
import 'package:plain/core/format/amount_formatter.dart';
import 'package:plain/core/refresh/data_invalidation.dart';
import 'package:plain/design_system/app_empty_state.dart';
import 'package:plain/design_system/plain_icons_v3.dart';
import 'package:plain/design_system/plain_ui.dart';
import 'package:plain/domain/entities/reminder.dart';
import 'package:plain/domain/services/weekly_report_service.dart';
import 'package:plain/app/l10n/app_strings.dart';
import 'package:plain/app/l10n/strings_reports.dart';
import 'package:plain/app/l10n/strings_domain.dart';

class WeeklyReportPage extends ConsumerStatefulWidget {
  const WeeklyReportPage({super.key});

  @override
  ConsumerState<WeeklyReportPage> createState() => _WeeklyReportPageState();
}

class _WeeklyReportPageState extends ConsumerState<WeeklyReportPage> {
  bool _loading = true;
  WeeklyReport? _report;
  ReminderLevel _level = ReminderLevel.ring;

  @override
  void initState() {
    super.initState();
    _load();
    WeeklyReportService.level().then((v) {
      if (mounted) setState(() => _level = v);
    });
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final deps = ref.read(appDependenciesProvider);
    final report = await WeeklyReportService.build(
      s: AppStrings.of(context),
      ledger: deps.ledgerRepository,
      categories: deps.categoryRepository,
      clock: deps.clock,
      bookId: deps.bookId,
    );
    if (!mounted) return;
    setState(() {
      _report = report;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final colors = context.colors;
    final report = _report;
    final enabled = ref.watch(weeklyReportEnabledProvider);
    // 记账增删改后重取（AGENTS.md：读侧 watch 版本，不靠手动 refresh）
    ref.listen(ledgerVersionProvider, (_, _) => _load());

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: PlainTopBar(title: s.wrSummaryTitle, showBack: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ContentWidthConstraint(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    Spacing.lg, 0, Spacing.lg, Spacing.xl),
                children: [
                  if (report == null || report.isEmpty)
                    AppEmptyState(
                      icon: PlainIconData.chartLine,
                      title: s.weeklyNoRecordsTitle,
                      subtitle: s.weeklyNoRecordsSubtitle,
                    )
                  else ...[
                    _Hero(report: report),
                    PlainEyebrow(s.reportCategoryShare),
                    PlainPanel(children: [_CategoryShares(report: report)]),
                    const SizedBox(height: Spacing.md),
                    if (report.highlights.isNotEmpty) ...[
                      PlainEyebrow(s.weeklySummaryEyebrow),
                      PlainPanel(children: [_Highlights(report: report)]),
                      const SizedBox(height: Spacing.md),
                    ],
                  ],
                  PlainEyebrow(s.weeklyPushSection),
                  PlainPanel(children: [
                    PlainRow(
                      title: s.weeklyPushTitle,
                      value: enabled ? s.weeklyEnabledOn : s.weeklyEnabledOff,
                      trailing: PlainSwitch(
                        value: enabled,
                        onChanged: (v) {
                          ref
                              .read(weeklyReportEnabledProvider.notifier)
                              .toggle(v);
                          setState(() {});
                        },
                      ),
                    ),
                    const Divider(height: 1, thickness: 1, indent: 16),
                    PlainRow(
                      title: s.weeklyLevelTitle,
                      trailing: PlainSeg(
                        items: [s.weeklyLevelRing, s.weeklyLevelSilent],
                        selectedIndex: _level == ReminderLevel.ring ? 0 : 1,
                        onChanged: (i) {
                          final next =
                              i == 0 ? ReminderLevel.ring : ReminderLevel.silent;
                          WeeklyReportService.setLevel(next);
                          setState(() => _level = next);
                        },
                      ),
                    ),
                  ]),
                  if (report != null && !report.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: Spacing.md),
                      child: Text(
                        s.weeklyPushNote(report.weekEnd),
                        style: TextStyle(
                          fontSize: 12,
                          height: designLineHeight(12),
                          color: colors.inkTertiary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _Hero extends ConsumerWidget {
  const _Hero({required this.report});
  final WeeklyReport report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final colors = context.colors;
    final hide = ref.watch(hideAmountsProvider);
    return Padding(
      padding: const EdgeInsets.only(top: Spacing.sm, bottom: Spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(height: 1, thickness: 1, color: colors.divider),
          Padding(
            padding: const EdgeInsets.fromLTRB(2, Spacing.lg, 2, Spacing.xs),
            child: Text(
              s.weeklyExpenseLabel,
              style: TextStyle(
                fontSize: 12,
                height: designLineHeight(12),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.08 * 12,
                color: colors.inkTertiary,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: Spacing.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '¥${formatAmount(report.totalExpenseCents, hide: hide)}',
                  style: TextStyle(
                    fontSize: 44,
                    height: designLineHeight(44),
                    fontWeight: FontWeight.w700,
                    color: colors.ink,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Text(
              s.weeklyRangeLine(
                report.weekStart,
                report.weekEnd,
                report.entryCount,
                formatAmount(report.totalIncomeCents, hide: hide),
              ),
              style: TextStyle(
                fontSize: 12,
                height: designLineHeight(12),
                color: colors.inkTertiary,
              ),
            ),
          ),
          if (report.isComparedToLastWeek)
            Padding(
              padding: const EdgeInsets.only(left: 2, top: Spacing.xs),
              child: Text(
                s.weeklyCompareLine(
                  report.expenseChangePercent >= 0 ? s.wrUp : s.wrDown,
                  report.expenseChangePercent.abs().toStringAsFixed(0),
                ),
                style: TextStyle(
                  fontSize: 14,
                  height: designLineHeight(14),
                  fontWeight: FontWeight.w500,
                  color: colors.inkSecondary,
                ),
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

class _CategoryShares extends ConsumerWidget {
  const _CategoryShares({required this.report});
  final WeeklyReport report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final hide = ref.watch(hideAmountsProvider);
    final total = report.totalExpenseCents;
    final rows = report.topCategories.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, Spacing.md, 16, Spacing.md),
      child: Column(
        children: [
          for (final e in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(children: [
                Expanded(
                  child: Text(
                    e.key,
                    style: TextStyle(
                      fontSize: 15,
                      height: designLineHeight(15),
                      color: colors.ink,
                    ),
                  ),
                ),
                Text(
                  total <= 0
                      ? '—'
                      : '${(e.value * 100 / total).round()}%',
                  style: TextStyle(
                    fontSize: 14,
                    height: designLineHeight(14),
                    color: colors.inkTertiary,
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 92,
                  child: Text(
                    '¥${formatAmount(e.value, hide: hide)}',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 15,
                      height: designLineHeight(15),
                      fontWeight: FontWeight.w600,
                      color: colors.ink,
                    ),
                  ),
                ),
              ]),
            ),
        ],
      ),
    );
  }
}

class _Highlights extends StatelessWidget {
  const _Highlights({required this.report});
  final WeeklyReport report;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, Spacing.md, 16, Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final h in report.highlights)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 7),
                    child: CategoryDot(color: colors.primaryInk, size: 6),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      h,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.6,
                        color: colors.inkSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
