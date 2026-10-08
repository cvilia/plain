/// Reports page (SP-3-01). See PRD STORY-3.1.
library;

import 'package:plain/app/theme/app_colors.dart';
import 'package:plain/domain/entities/category.dart';
import 'package:plain/design_system/app_empty_state.dart';
import 'package:flutter/material.dart';
import 'package:plain/design_system/app_toast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plain/app/bootstrap.dart';
import 'package:plain/app/breakpoints.dart';
import 'package:plain/app/theme/design_tokens.dart';
import 'package:plain/app/theme/theme_registry.dart';
import 'package:plain/core/format/amount_formatter.dart';
import 'package:plain/core/refresh/data_invalidation.dart';
import 'package:plain/design_system/donut_chart.dart';

class MonthlyReport {
  const MonthlyReport({
    required this.year,
    required this.month,
    required this.expenseCents,
    required this.incomeCents,
    required this.txCount,
    required this.categoryBreakdown,
    this.dailyExpense = const {},
  });

  final int year;
  final int month;
  final int expenseCents;
  final int incomeCents;
  final int txCount;
  final List<CategorySlice> categoryBreakdown;

  /// day-of-month (1–31) → expense cents. Used by 日支出走势.
  final Map<int, int> dailyExpense;

  int get balanceCents => incomeCents - expenseCents;
}

class CategorySlice {
  const CategorySlice({required this.name, required this.expenseCents, required this.color});
  final String name;
  final int expenseCents;
  final Color color;
}

class SelectedMonthNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month);
  }

  void set(DateTime month) => state = month;

  void changeMonth(int delta) {
    final next = state.month + delta;
    if (next > 12) {
      state = DateTime(state.year + 1, 1);
    } else if (next < 1) {
      state = DateTime(state.year - 1, 12);
    } else {
      state = DateTime(state.year, next);
    }
  }
}

final _selectedMonthProvider = NotifierProvider<SelectedMonthNotifier, DateTime>(SelectedMonthNotifier.new);

final _reportProvider = FutureProvider<MonthlyReport>((ref) async {
  ref.watch(ledgerVersionProvider);
  ref.watch(categoriesVersionProvider);
  final month = ref.watch(_selectedMonthProvider);
  final deps = ref.watch(appDependenciesProvider);

  final dayFrom = '${month.year}-${month.month.toString().padLeft(2, '0')}-01';
  final lastDay = DateTime(month.year, month.month + 1, 0).day;
  final dayTo = '${month.year}-${month.month.toString().padLeft(2, '0')}-${lastDay.toString().padLeft(2, '0')}';

  final summaryRes = await deps.ledgerRepository.monthSummary(
    bookId: deps.bookId, dayFrom: dayFrom, dayTo: dayTo,
  );
  final summary = summaryRes.successOrNull;
  if (summary == null) {
    return MonthlyReport(
      year: month.year, month: month.month,
      expenseCents: 0, incomeCents: 0, txCount: 0,
      categoryBreakdown: const [],
    );
  }

  final catRes = await deps.categoryRepository.listAll();
  final cats = catRes.successOrNull ?? const <Category>[];
  final catNameMap = {for (final c in cats) c.id: c.name};
  final catIconMap = {for (final c in cats) c.id: c.iconRef};

  // Category slices prefer the fixed categoryColorMap palette (INV-1).
  // Fallbacks for uncategorized slices — fixed palette, no BuildContext here.
  const fallbackColors = [
    Color(0xFFD97C7C), Color(0xFF7FA8DC), Color(0xFFE69A6D),
    Color(0xFF97BC81), Color(0xFFBFA8E9),
  ];

  final breakdown = <CategorySlice>[];
  var colorIdx = 0;
  final sorted = summary.byCategory.entries.toList()
    ..sort((a, b) => b.value.expenseCents.compareTo(a.value.expenseCents));
  for (final e in sorted) {
    final exp = e.value.expenseCents;
    if (exp <= 0) continue;
    final catId = e.key;
    final catName = catNameMap[catId] ?? '其他';
    final iconRef = catIconMap[catId] ?? 'other';
    final palette = categoryColorMap[iconRef];
    breakdown.add(CategorySlice(
      name: catName,
      expenseCents: exp,
      color: palette != null
          ? Color(palette)
          : fallbackColors[colorIdx % fallbackColors.length],
    ));
    colorIdx++;
  }

  // Daily expense for 日支出走势
  final db = deps.db;
  final dayRows = db.raw.select(
    'SELECT day_key, SUM(expense_cents) AS exp FROM daily_stats '
    'WHERE book_id = ? AND day_key >= ? AND day_key <= ? GROUP BY day_key',
    [deps.bookId, dayFrom, dayTo],
  );
  final dailyExpense = <int, int>{};
  for (final r in dayRows) {
    final key = r['day_key']! as String;
    final d = int.tryParse(key.substring(8, 10)) ?? 0;
    if (d > 0) dailyExpense[d] = ((r['exp'] as int?) ?? 0);
  }

  return MonthlyReport(
    year: month.year,
    month: month.month,
    expenseCents: summary.expenseCents,
    incomeCents: summary.incomeCents,
    txCount: summary.txCount,
    categoryBreakdown: breakdown,
    dailyExpense: dailyExpense,
  );
});
final _prevReportProvider = FutureProvider<MonthlyReport>((ref) async {
  ref.watch(ledgerVersionProvider);
  final month = ref.watch(_selectedMonthProvider);
  final prevMonth = month.month == 1 ? DateTime(month.year - 1, 12) : DateTime(month.year, month.month - 1);
  final deps = ref.watch(appDependenciesProvider);
  final db = deps.db;

  final dayFrom = '${prevMonth.year}-${prevMonth.month.toString().padLeft(2, '0')}-01';
  final nextMonth = prevMonth.month == 12 ? DateTime(prevMonth.year + 1, 1) : DateTime(prevMonth.year, prevMonth.month + 1);
  final dayTo = '${nextMonth.year}-${nextMonth.month.toString().padLeft(2, '0')}-01';

  final rows = db.raw.select(
    'SELECT COALESCE(SUM(expense_cents), 0) AS exp, COALESCE(SUM(income_cents), 0) AS inc '
    'FROM daily_stats WHERE book_id = ? AND day_key >= ? AND day_key < ?',
    [deps.bookId, dayFrom, dayTo],
  );

  return MonthlyReport(
    year: prevMonth.year,
    month: prevMonth.month,
    expenseCents: (rows.first['exp'] as int?) ?? 0,
    incomeCents: (rows.first['inc'] as int?) ?? 0,
    txCount: 0,
    categoryBreakdown: const [],
  );
});

class ReportsPage extends ConsumerWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedMonth = ref.watch(_selectedMonthProvider);
    final reportAsync = ref.watch(_reportProvider);
    final prevAsync = ref.watch(_prevReportProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('报表'),
        actions: [
          IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => ref.read(_selectedMonthProvider.notifier).changeMonth(-1)),
          Center(
            child: Text(
              '${selectedMonth.year}-${selectedMonth.month.toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => ref.read(_selectedMonthProvider.notifier).changeMonth(1)),
        ],
      ),
      body: reportAsync.when(
        data: (report) {
          if (report.txCount == 0) {
            return const ContentWidthConstraint(
              child: AppEmptyState(
                icon: Icons.pie_chart_outline,
                title: '本月还没有记录',
              ),
            );
          }
          return ContentWidthConstraint(child: _ReportContent(report: report, prevAsync: prevAsync));
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
      ),
    );
  }
}

class _ReportContent extends StatefulWidget {
  const _ReportContent({required this.report, required this.prevAsync});
  final MonthlyReport report;
  final AsyncValue<MonthlyReport> prevAsync;

  @override
  State<_ReportContent> createState() => _ReportContentState();
}

class _ReportContentState extends State<_ReportContent> {
  DonutSegment? _drillSegment;

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final segments = report.categoryBreakdown
        .map((s) => DonutSegment(name: s.name, value: s.expenseCents, color: s.color))
        .toList();

    // 高保真 SP-3-01：支出分类 → 日支出走势 → 月对比
    return ListView(
      padding: const EdgeInsets.all(Spacing.lg),
      children: [
        if (segments.isNotEmpty) ...[
          _sectionTitle(context, '支出分类'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Spacing.lg),
              child: DonutChart(
                segments: segments,
                drillSegment: _drillSegment,
                onSegmentTap: (seg) => setState(() => _drillSegment = seg),
                onDrillBack: () => setState(() => _drillSegment = null),
                onSubcategoryTap: (sub) {
                  showAppToast(context, '查看 ${sub.name} 的账单');
                },
              ),
            ),
          ),
          const SizedBox(height: Spacing.lg),
        ],
        _sectionTitle(context, '日支出走势'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(Spacing.lg),
            child: _DailyBars(dailyExpense: report.dailyExpense, month: report.month, year: report.year),
          ),
        ),
        const SizedBox(height: Spacing.lg),
        _sectionTitle(context, '月对比'),
        widget.prevAsync.when(
          data: (prev) => _ComparisonCard(current: report, previous: prev),
          loading: () => const SizedBox.shrink(),
          error: (e, _) => const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _sectionTitle(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(left: 2, bottom: Spacing.sm),
        child: Text(text, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
      );
}

/// 日支出柱状图（高保真 .bars）
class _DailyBars extends ConsumerWidget {
  const _DailyBars({required this.dailyExpense, required this.month, required this.year});
  final Map<int, int> dailyExpense;
  final int month;
  final int year;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hideAmounts = ref.watch(hideAmountsProvider);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final maxExp = dailyExpense.values.fold<int>(0, (m, v) => v > m ? v : m);
    final now = DateTime.now();
    final isCurrentMonth = now.year == year && now.month == month;
    final today = now.day;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('$month/1', style: TextStyle(fontSize: 10, color: context.colors.inkTertiary)),
            Text('$month/${daysInMonth ~/ 2}', style: TextStyle(fontSize: 10, color: context.colors.inkTertiary)),
            Text('$month/$daysInMonth', style: TextStyle(fontSize: 10, color: context.colors.inkTertiary)),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 92,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var d = 1; d <= daysInMonth; d++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1.5),
                    child: Tooltip(
                      message: '$month月$d日 ¥${formatAmount(dailyExpense[d] ?? 0, hide: hideAmounts)}',
                      child: Container(
                        height: ((dailyExpense[d] ?? 0) / (maxExp == 0 ? 1 : maxExp) * 92).clamp(3.0, 92.0),
                        decoration: BoxDecoration(
                          color: (isCurrentMonth && d == today)
                              ? context.colors.primary
                              : context.colors.barFill,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ComparisonCard extends StatelessWidget {
  const _ComparisonCard({required this.current, required this.previous});
  final MonthlyReport current;
  final MonthlyReport previous;

  @override
  Widget build(BuildContext context) {
    final expChange = previous.expenseCents == 0 ? null : ((current.expenseCents - previous.expenseCents) / previous.expenseCents * 100);
    final incChange = previous.incomeCents == 0 ? null : ((current.incomeCents - previous.incomeCents) / previous.incomeCents * 100);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('与上月对比', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: Spacing.md),
            Row(
              children: [
                Expanded(child: _ChangeItem(label: '支出', current: current.expenseCents, previous: previous.expenseCents, change: expChange, isExpense: true)),
                Expanded(child: _ChangeItem(label: '收入', current: current.incomeCents, previous: previous.incomeCents, change: incChange, isExpense: false)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChangeItem extends ConsumerWidget {
  const _ChangeItem({required this.label, required this.current, required this.previous, required this.change, required this.isExpense});
  final String label;
  final int current;
  final int previous;
  final double? change;
  final bool isExpense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hideAmounts = ref.watch(hideAmountsProvider);
    final changeColor = change == null
        ? context.colors.inkTertiary
        : (isExpense ? (change! > 0 ? context.colors.expense : context.colors.income) : (change! > 0 ? context.colors.income : context.colors.expense));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: context.colors.inkSecondary)),
        const SizedBox(height: Spacing.xs),
        Text(formatAmount(current, hide: hideAmounts), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        if (change != null)
          Text('${change! > 0 ? '+' : ''}${change!.toStringAsFixed(1)}%', style: TextStyle(fontSize: 12, color: changeColor)),
      ],
    );
  }
}


