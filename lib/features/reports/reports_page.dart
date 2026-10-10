/// Reports page (SP-3-01). See PRD STORY-3.1.
library;

import 'package:plain/app/theme/app_colors.dart';
import 'package:plain/domain/entities/category.dart';
import 'package:plain/design_system/app_empty_state.dart';
import 'package:plain/design_system/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:plain/app/bootstrap.dart';
import 'package:plain/app/breakpoints.dart';
import 'package:plain/app/router/app_router.dart';
import 'package:plain/app/settings/ledger_settings.dart';
import 'package:plain/app/theme/design_tokens.dart';
import 'package:plain/app/theme/theme_registry.dart';
import 'package:plain/core/format/amount_formatter.dart';
import 'package:plain/core/refresh/data_invalidation.dart';
import 'package:plain/design_system/donut_chart.dart';
import 'package:plain/features/ledger/controllers/flow_list_controller.dart';

class MonthlyReport {
  const MonthlyReport({
    required this.year,
    required this.month,
    required this.expenseCents,
    required this.incomeCents,
    required this.txCount,
    required this.categoryBreakdown,
    this.dailyExpense = const {},
    this.dailyIncome = const {},
  });

  final int year;
  final int month;
  final int expenseCents;
  final int incomeCents;
  final int txCount;
  final List<CategorySlice> categoryBreakdown;

  /// day-of-month (1–31) → expense cents. Used by 日支出走势.
  final Map<int, int> dailyExpense;

  /// day-of-month (1–31) → income cents.
  final Map<int, int> dailyIncome;

  int get balanceCents => incomeCents - expenseCents;
}

class CategorySlice {
  const CategorySlice({
    required this.name,
    required this.expenseCents,
    required this.color,
    this.categoryId,
    this.children = const [],
  });
  final String name;
  final int expenseCents;
  final Color color;
  final String? categoryId;

  /// 二级分类（STORY-3.1 AC2 下钻）。
  final List<CategorySlice> children;
}

class SelectedMonthNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = ref.read(appDependenciesProvider).clock.now().toLocal();
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
  final calendar = ref.watch(calendarProvider);
  final monthStartDay = ref.watch(monthStartDayProvider);

  // G-1：按记账月边界取期，不按自然月硬切
  final period = calendar.periodFor(month.year, month.month, day: monthStartDay);
  final dayFrom = period.dayFrom;
  final dayTo = period.dayTo;

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
  final catById = {for (final c in cats) c.id: c};
  final catNameMap = {for (final c in cats) c.id: c.name};
  final catIconMap = {for (final c in cats) c.id: c.iconRef};

  // Category slices prefer the fixed categoryColorMap palette (INV-1).
  // Fallbacks for uncategorized slices — fixed palette, no BuildContext here.
  const fallbackColors = [
    Color(0xFFD97C7C), Color(0xFF7FA8DC), Color(0xFFE69A6D),
    Color(0xFF97BC81), Color(0xFFBFA8E9),
  ];

  Color colorOf(String catId, int idx) {
    final iconRef = catIconMap[catId] ?? 'other';
    final palette = categoryColorMap[iconRef];
    return palette != null ? Color(palette) : fallbackColors[idx % fallbackColors.length];
  }

  // 归并到一级分类，二级作为 children（STORY-3.1 AC2 下钻）
  final rootAgg = <String, int>{}; // rootId -> expense
  final childAgg = <String, Map<String, int>>{}; // rootId -> {childId: expense}
  for (final e in summary.byCategory.entries) {
    final exp = e.value.expenseCents;
    if (exp <= 0) continue;
    final catId = e.key;
    final cat = catById[catId];
    final rootId = (cat != null && cat.parentId != null) ? cat.parentId! : catId;
    rootAgg[rootId] = (rootAgg[rootId] ?? 0) + exp;
    if (cat != null && cat.parentId != null) {
      (childAgg[rootId] ??= {})[catId] = exp;
    }
  }

  final breakdown = <CategorySlice>[];
  var colorIdx = 0;
  final sortedRoots = rootAgg.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  for (final e in sortedRoots) {
    final rootId = e.key;
    final kids = childAgg[rootId];
    final children = <CategorySlice>[];
    if (kids != null) {
      final sortedKids = kids.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      for (final k in sortedKids) {
        children.add(CategorySlice(
          name: catNameMap[k.key] ?? '其他',
          expenseCents: k.value,
          color: colorOf(k.key, colorIdx),
          categoryId: k.key,
        ));
      }
    }
    breakdown.add(CategorySlice(
      name: catNameMap[rootId] ?? '其他',
      expenseCents: e.value,
      color: colorOf(rootId, colorIdx),
      categoryId: rootId,
      children: children,
    ));
    colorIdx++;
  }

  // Daily expense/income for 日趋势
  final db = deps.db;
  final dayRows = db.raw.select(
    'SELECT day_key, SUM(expense_cents) AS exp, SUM(income_cents) AS inc FROM daily_stats '
    'WHERE book_id = ? AND day_key >= ? AND day_key <= ? GROUP BY day_key',
    [deps.bookId, dayFrom, dayTo],
  );
  final dailyExpense = <int, int>{};
  final dailyIncome = <int, int>{};
  for (final r in dayRows) {
    final key = r['day_key']! as String;
    final d = int.tryParse(key.substring(8, 10)) ?? 0;
    if (d > 0) {
      dailyExpense[d] = ((r['exp'] as int?) ?? 0);
      dailyIncome[d] = ((r['inc'] as int?) ?? 0);
    }
  }

  return MonthlyReport(
    year: month.year,
    month: month.month,
    expenseCents: summary.expenseCents,
    incomeCents: summary.incomeCents,
    txCount: summary.txCount,
    categoryBreakdown: breakdown,
    dailyExpense: dailyExpense,
    dailyIncome: dailyIncome,
  );
});
final _prevReportProvider = FutureProvider<MonthlyReport>((ref) async {
  ref.watch(ledgerVersionProvider);
  final month = ref.watch(_selectedMonthProvider);
  final calendar = ref.watch(calendarProvider);
  final monthStartDay = ref.watch(monthStartDayProvider);
  final deps = ref.watch(appDependenciesProvider);
  final db = deps.db;

  final cur = calendar.periodFor(month.year, month.month, day: monthStartDay);
  final prev = calendar.previousPeriod(cur);

  final rows = db.raw.select(
    'SELECT COALESCE(SUM(expense_cents), 0) AS exp, COALESCE(SUM(income_cents), 0) AS inc '
    'FROM daily_stats WHERE book_id = ? AND day_key >= ? AND day_key <= ?',
    [deps.bookId, prev.dayFrom, prev.dayTo],
  );

  return MonthlyReport(
    year: prev.year,
    month: prev.month,
    expenseCents: (rows.first['exp'] as int?) ?? 0,
    incomeCents: (rows.first['inc'] as int?) ?? 0,
    txCount: 0,
    categoryBreakdown: const [],
  );
});

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  @override
  void initState() {
    super.initState();
    // 报表下钻会带上流水分类筛选；再次进入报表时清除，
    // 保证返回首页是完整流水。
    Future.microtask(() {
      ref.read(flowCategoryFilterProvider.notifier).clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedMonth = ref.watch(_selectedMonthProvider);
    final monthStartDay = ref.watch(monthStartDayProvider);
    final reportAsync = ref.watch(_reportProvider);
    final prevAsync = ref.watch(_prevReportProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('报表'),
        actions: [
          IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => ref.read(_selectedMonthProvider.notifier).changeMonth(-1)),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${selectedMonth.year}-${selectedMonth.month.toString().padLeft(2, '0')}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              if (monthStartDay != 1)
                Text(
                  '记账月起始：$monthStartDay 日',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w400),
                ),
            ],
          ),
          IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => ref.read(_selectedMonthProvider.notifier).changeMonth(1)),
        ],
      ),
      body: reportAsync.when(
        data: (report) {
          if (report.txCount == 0) {
            // AC3：空态给记账入口
            return ContentWidthConstraint(
              child: AppEmptyState(
                icon: Icons.pie_chart_outline,
                title: '本月还没有记录',
                action: FilledButton.icon(
                  onPressed: () => context.go(Routes.home),
                  icon: const Icon(Icons.add),
                  label: const Text('记一笔'),
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

class _ReportContent extends ConsumerStatefulWidget {
  const _ReportContent({required this.report, required this.prevAsync});
  final MonthlyReport report;
  final AsyncValue<MonthlyReport> prevAsync;

  @override
  ConsumerState<_ReportContent> createState() => _ReportContentState();
}

class _ReportContentState extends ConsumerState<_ReportContent> {
  DonutSegment? _drillSegment;

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final segments = report.categoryBreakdown
        .map((s) => DonutSegment(
              name: s.name,
              value: s.expenseCents,
              color: s.color,
              children: [
                for (final c in s.children)
                  DonutSegment(name: c.name, value: c.expenseCents, color: c.color),
              ],
            ))
        .toList();

    void openCategory(String? categoryId, String name) {
      // STORY-3.1 AC2：下钻到该分类的流水列表
      ref.read(flowCategoryFilterProvider.notifier).set(categoryId);
      ref.read(flowListControllerProvider.notifier).loadInitial();
      context.go(Routes.home);
      showAppToast(context, '已筛选「$name」');
    }

    // 高保真 SP-3-01：结余卡 → 支出分类 → 日趋势 → 月对比
    return ListView(
      padding: const EdgeInsets.all(Spacing.lg),
      children: [
        _BalanceCard(report: report),
        const SizedBox(height: Spacing.lg),
        if (segments.isNotEmpty) ...[
          _sectionTitle(context, '支出分类'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Spacing.lg),
              child: DonutChart(
                segments: segments,
                drillSegment: _drillSegment,
                onSegmentTap: (seg) {
                  if (seg.children.isEmpty) {
                    final slice = report.categoryBreakdown
                        .where((s) => s.name == seg.name)
                        .toList();
                    openCategory(slice.isEmpty ? null : slice.first.categoryId, seg.name);
                  } else {
                    setState(() => _drillSegment = seg);
                  }
                },
                onDrillBack: () => setState(() => _drillSegment = null),
                onSubcategoryTap: (sub) {
                  final parent = _drillSegment;
                  final rootSlice = report.categoryBreakdown
                      .where((s) => s.name == (parent?.name ?? ''))
                      .toList();
                  String? catId;
                  if (rootSlice.isNotEmpty) {
                    final hit = rootSlice.first.children.where((c) => c.name == sub.name);
                    if (hit.isNotEmpty) catId = hit.first.categoryId;
                  }
                  openCategory(catId, sub.name);
                },
              ),
            ),
          ),
          const SizedBox(height: Spacing.lg),
        ],
        _sectionTitle(context, '日收支走势'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(Spacing.lg),
            child: _DailyBars(
              dailyExpense: report.dailyExpense,
              dailyIncome: report.dailyIncome,
              month: report.month,
              year: report.year,
            ),
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

/// 结余数字卡（STORY-3.1 页面结构 ①）
class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.report});
  final MonthlyReport report;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Row(children: [
          Expanded(child: _stat(context, '收入', report.incomeCents, context.colors.income)),
          Expanded(child: _stat(context, '支出', report.expenseCents, context.colors.expense)),
          Expanded(child: _stat(context, '结余', report.balanceCents, context.colors.ink)),
        ]),
      ),
    );
  }

  Widget _stat(BuildContext context, String label, int cents, Color color) {
    return Column(children: [
      Text(label, style: TextStyle(fontSize: 12, color: context.colors.inkTertiary)),
      const SizedBox(height: 4),
      Text(
        formatAmountYuan(cents),
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: color),
      ),
    ]);
  }
}

/// 日收支柱状图（STORY-3.1：支出 + 收入双系列）
class _DailyBars extends ConsumerWidget {
  const _DailyBars({
    required this.dailyExpense,
    required this.dailyIncome,
    required this.month,
    required this.year,
  });
  final Map<int, int> dailyExpense;
  final Map<int, int> dailyIncome;
  final int month;
  final int year;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hideAmounts = ref.watch(hideAmountsProvider);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final maxExp = dailyExpense.values.fold<int>(0, (m, v) => v > m ? v : m);
    final maxInc = dailyIncome.values.fold<int>(0, (m, v) => v > m ? v : m);
    final maxV = maxExp > maxInc ? maxExp : maxInc;
    final now = ref.read(appDependenciesProvider).clock.now().toLocal();
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
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: Tooltip(
                      message: '$month月$d日 支出 ¥${formatAmount(dailyExpense[d] ?? 0, hide: hideAmounts)} · 收入 ¥${formatAmount(dailyIncome[d] ?? 0, hide: hideAmounts)}',
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Container(
                              height: ((dailyExpense[d] ?? 0) / (maxV == 0 ? 1 : maxV) * 92).clamp(2.0, 92.0),
                              decoration: BoxDecoration(
                                color: (isCurrentMonth && d == today)
                                    ? context.colors.primary
                                    : context.colors.barFill,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          if (dailyIncome[d] != null && dailyIncome[d]! > 0) ...[
                            const SizedBox(width: 1),
                            Expanded(
                              child: Container(
                                height: ((dailyIncome[d] ?? 0) / (maxV == 0 ? 1 : maxV) * 92).clamp(2.0, 92.0),
                                decoration: BoxDecoration(
                                  color: context.colors.income.withValues(alpha: 0.55),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          _legendDot(context, context.colors.barFill, '支出'),
          const SizedBox(width: Spacing.md),
          _legendDot(context, context.colors.income.withValues(alpha: 0.55), '收入'),
        ]),
      ],
    );
  }

  Widget _legendDot(BuildContext context, Color color, String label) {
    return Row(children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 11, color: context.colors.inkTertiary)),
    ]);
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
                Expanded(child: _ChangeItem(label: '结余', current: current.balanceCents, previous: previous.balanceCents, change: null, isExpense: false)),
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


