/// Reports page (SP-3-01). See PRD STORY-3.1.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plain/app/bootstrap.dart';
import 'package:plain/app/breakpoints.dart';
import 'package:plain/app/theme/design_tokens.dart';
import 'package:plain/data/data_freshness.dart';
import 'package:plain/design_system/donut_chart.dart';

class MonthlyReport {
  const MonthlyReport({
    required this.year,
    required this.month,
    required this.expenseCents,
    required this.incomeCents,
    required this.txCount,
    required this.categoryBreakdown,
  });

  final int year;
  final int month;
  final int expenseCents;
  final int incomeCents;
  final int txCount;
  final List<CategorySlice> categoryBreakdown;

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
  ref.watch(dataFreshnessProvider);
  final month = ref.watch(_selectedMonthProvider);
  final deps = ref.watch(appDependenciesProvider);
  final db = deps.db;

  final dayFrom = '${month.year}-${month.month.toString().padLeft(2, '0')}-01';
  final nextMonth = month.month == 12 ? DateTime(month.year + 1, 1) : DateTime(month.year, month.month + 1);
  final dayTo = '${nextMonth.year}-${nextMonth.month.toString().padLeft(2, '0')}-01';

  final rows = db.raw.select(
    'SELECT category_id, SUM(expense_cents) AS exp, SUM(income_cents) AS inc, SUM(tx_count) AS cnt '
    'FROM daily_stats WHERE book_id = ? AND day_key >= ? AND day_key < ? '
    'GROUP BY category_id ORDER BY exp DESC',
    [deps.bookId, dayFrom, dayTo],
  );

  var totalExpense = 0;
  var totalIncome = 0;
  var totalCount = 0;
  final breakdown = <CategorySlice>[];

  final catRows = db.raw.select('SELECT id, name FROM categories WHERE deleted_at IS NULL');
  final catMap = {for (final r in catRows) r['id']! as String: r['name']! as String};

  final colors = [
    BrandColors.expense, BrandColors.primary, BrandColors.accent,
    BrandColors.transfer, BrandColors.income,
    const Color(0xFF9B7BB8), const Color(0xFFD4A76A), const Color(0xFF6B9BD2),
  ];

  var colorIdx = 0;
  for (final row in rows) {
    final exp = (row['exp'] as int?) ?? 0;
    final inc = (row['inc'] as int?) ?? 0;
    final cnt = (row['cnt'] as int?) ?? 0;
    totalExpense += exp;
    totalIncome += inc;
    totalCount += cnt;

    if (exp > 0) {
      final catId = row['category_id']! as String;
      breakdown.add(CategorySlice(
        name: catMap[catId] ?? '其他',
        expenseCents: exp,
        color: colors[colorIdx % colors.length],
      ));
      colorIdx++;
    }
  }

  return MonthlyReport(
    year: month.year,
    month: month.month,
    expenseCents: totalExpense,
    incomeCents: totalIncome,
    txCount: totalCount,
    categoryBreakdown: breakdown,
  );
});

final _prevReportProvider = FutureProvider<MonthlyReport>((ref) async {
  ref.watch(dataFreshnessProvider);
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
            return ContentWidthConstraint(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.pie_chart_outline, size: 80, color: BrandColors.inkTertiary),
                    const SizedBox(height: Spacing.lg),
                    Text('本月还没有记录', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: BrandColors.inkSecondary)),
                  ],
                ),
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

    return ListView(
      padding: const EdgeInsets.all(Spacing.lg),
      children: [
        _SummaryCard(report: report),
        const SizedBox(height: Spacing.lg),
        widget.prevAsync.when(
          data: (prev) => _ComparisonCard(current: report, previous: prev),
          loading: () => const SizedBox.shrink(),
          error: (e, _) => const SizedBox.shrink(),
        ),
        const SizedBox(height: Spacing.lg),
        if (segments.isNotEmpty) ...[
          Text('分类支出占比', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: Spacing.md),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Spacing.lg),
              child: DonutChart(
                segments: segments,
                drillSegment: _drillSegment,
                onSegmentTap: (seg) => setState(() => _drillSegment = seg),
                onDrillBack: () => setState(() => _drillSegment = null),
                onSubcategoryTap: (sub) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('查看 ${sub.name} 的账单')),
                  );
                },
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.report});
  final MonthlyReport report;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.xl),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: _SummaryItem(label: '支出', value: (report.expenseCents / 100).toStringAsFixed(2), color: BrandColors.expense)),
                Expanded(child: _SummaryItem(label: '收入', value: (report.incomeCents / 100).toStringAsFixed(2), color: BrandColors.income)),
                Expanded(child: _SummaryItem(label: '结余', value: (report.balanceCents / 100).toStringAsFixed(2), color: report.balanceCents >= 0 ? BrandColors.income : BrandColors.expense)),
              ],
            ),
            const SizedBox(height: Spacing.lg),
            Text('${report.txCount} 笔交易', style: TextStyle(fontSize: 12, color: BrandColors.inkTertiary)),
          ],
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: BrandColors.inkSecondary)),
        const SizedBox(height: Spacing.xs),
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: color)),
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

class _ChangeItem extends StatelessWidget {
  const _ChangeItem({required this.label, required this.current, required this.previous, required this.change, required this.isExpense});
  final String label;
  final int current;
  final int previous;
  final double? change;
  final bool isExpense;

  @override
  Widget build(BuildContext context) {
    final changeColor = change == null
        ? BrandColors.inkTertiary
        : (isExpense ? (change! > 0 ? BrandColors.expense : BrandColors.income) : (change! > 0 ? BrandColors.income : BrandColors.expense));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: BrandColors.inkSecondary)),
        const SizedBox(height: Spacing.xs),
        Text((current / 100).toStringAsFixed(2), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        if (change != null)
          Text('${change! > 0 ? '+' : ''}${change!.toStringAsFixed(1)}%', style: TextStyle(fontSize: 12, color: changeColor)),
      ],
    );
  }
}
