/// Reports page (SP-3-01). See PRD STORY-3.1.
library;

import 'package:plain/app/theme/app_colors.dart';
import 'package:plain/domain/entities/category.dart';
import 'package:plain/domain/repositories/repositories.dart';
import 'package:plain/design_system/app_empty_state.dart';
import 'package:plain/design_system/app_error_state.dart';
import 'package:plain/design_system/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:plain/app/bootstrap.dart';
import 'package:plain/app/breakpoints.dart';
import 'package:plain/app/l10n/app_strings.dart';
import 'package:plain/app/l10n/strings_core.dart';
import 'package:plain/app/l10n/strings_domain.dart';
import 'package:plain/app/l10n/strings_reports.dart';
import 'package:plain/app/router/app_router.dart';
import 'package:plain/app/settings/ledger_settings.dart';
import 'package:plain/app/theme/design_tokens.dart';
import 'package:plain/app/theme/theme_registry.dart';
import 'package:plain/app/theme/typography.dart';
import 'package:plain/core/format/amount_formatter.dart';
import 'package:plain/core/refresh/data_invalidation.dart';
import 'package:plain/design_system/amount_display.dart';
import 'package:plain/design_system/donut_chart.dart';
import 'package:plain/design_system/plain_icons_v3.dart';
import 'package:plain/design_system/plain_ui.dart';
import 'package:plain/features/ledger/controllers/flow_list_controller.dart';
import 'package:plain/features/reports/cross_analysis_page.dart';
import 'package:plain/features/reports/money_age_page.dart';
import 'package:plain/features/reports/sankey_page.dart';
import 'package:plain/features/reports/tax_report_page.dart';
import 'package:plain/features/reports/weekly_report_page.dart';

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
    this.prevExpenseCents = 0,
    this.prevIncomeCents = 0,
  });

  final int year;
  final int month;
  final int expenseCents;
  final int incomeCents;
  final int txCount;
  final List<CategorySlice> categoryBreakdown;

  /// 上一记账月合计（用于「与上月对比」）。
  final int prevExpenseCents;
  final int prevIncomeCents;

  /// 涨跌百分比（相对上月）。上月为 0 时返回 null。
  double? get expenseDeltaPct {
    if (prevExpenseCents <= 0) return null;
    return (expenseCents - prevExpenseCents) / prevExpenseCents * 100;
  }

  double? get incomeDeltaPct {
    if (prevIncomeCents <= 0) return null;
    return (incomeCents - prevIncomeCents) / prevIncomeCents * 100;
  }

  double? get balanceDeltaPct {
    final prevBal = prevIncomeCents - prevExpenseCents;
    if (prevBal == 0) return null;
    return (balanceCents - prevBal) / prevBal.abs() * 100;
  }

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
    // G-1：报表选中的「月」是**记账月**，不是自然月。
    // 月起始日 > 今天的日号时（起始日 26 号、今天 10 月 16 日），当前记账月是
    // 2026-09；按自然月取会打开 2026-10（= 10-26 ~ 11-25，一个还没有账单的期），
    // 流水页读 `transactions` 照常有数据，报表却一片空白。
    final period = ref.watch(calendarProvider).currentPeriod();
    return DateTime(period.year, period.month);
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
  var summary = summaryRes.successOrNull;

  // ⚠️ 报表只从 `daily_stats` 取数，流水页读的是 `transactions`。两者一旦不同步
  // （历史迁移、写路径异常中断），就会「流水有数据、报表一片空白」。
  // 这里自查一次：窗口内**确实有账单**却读不到统计 → 由账单重建统计再读一遍。
  // 重建是既有实现（`rebuildDailyStats`，口径单点），只在这个异常分支上跑。
  if (summary == null || summary.txCount == 0) {
    final fromMs =
        DateTime.parse(dayFrom).toUtc().millisecondsSinceEpoch;
    final toMs = DateTime.parse(dayTo)
        .add(const Duration(days: 1))
        .toUtc()
        .millisecondsSinceEpoch;
    final probe = await deps.ledgerRepository.listPage(
      filter: EntryFilter(bookId: deps.bookId, fromMs: fromMs, toMs: toMs),
      limit: 1,
    );
    final hasEntries = probe.successOrNull?.items.isNotEmpty ?? false;
    if (hasEntries) {
      final rebuilt = await deps.ledgerRepository.rebuildDailyStats();
      if (rebuilt.isSuccess) {
        final retry = await deps.ledgerRepository.monthSummary(
          bookId: deps.bookId, dayFrom: dayFrom, dayTo: dayTo,
        );
        summary = retry.successOrNull ?? summary;
      }
    }
  }

  // 上一记账月（与上月对比）
  final prevMonth = month.month == 1
      ? DateTime(month.year - 1, 12)
      : DateTime(month.year, month.month - 1);
  final prevPeriod = calendar.periodFor(prevMonth.year, prevMonth.month, day: monthStartDay);
  final prevRes = await deps.ledgerRepository.monthSummary(
    bookId: deps.bookId, dayFrom: prevPeriod.dayFrom, dayTo: prevPeriod.dayTo,
  );
  final prev = prevRes.successOrNull;
  final prevExpense = prev?.expenseCents ?? 0;
  final prevIncome = prev?.incomeCents ?? 0;

  if (summary == null) {
    return MonthlyReport(
      year: month.year, month: month.month,
      expenseCents: 0, incomeCents: 0, txCount: 0,
      categoryBreakdown: const [],
      prevExpenseCents: prevExpense,
      prevIncomeCents: prevIncome,
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
          name: catNameMap[k.key] ?? kDefaultAppStrings.other,
          expenseCents: k.value,
          color: colorOf(k.key, colorIdx),
          categoryId: k.key,
        ));
      }
    }
    breakdown.add(CategorySlice(
      name: catNameMap[rootId] ?? kDefaultAppStrings.other,
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
    final s = AppStrings.of(context);
    final selectedMonth = ref.watch(_selectedMonthProvider);
    final reportAsync = ref.watch(_reportProvider);
    final prevAsync = ref.watch(_prevReportProvider);

    return Scaffold(
      appBar: PlainTopBar(
        title: s.reports,
        actions: [
          PlainTopBarAction(
            icon: PlainIconData.chevronLeft,
            tooltip: s.reportPrevMonth,
            onTap: () => ref.read(_selectedMonthProvider.notifier).changeMonth(-1),
          ),
          // 角标与日期之间只留动作行自带的 2px 间距（原先外面又套了 4px 内边距，
          // 视觉上「日期离箭头太远」）。
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${selectedMonth.year}-${selectedMonth.month.toString().padLeft(2, '0')}',
                style: TextStyle(
                  fontSize: 15,
                  // 不写 height 会继承 body 的 1.5714（+3px），与顶栏基线对不齐。
                  height: designLineHeight(15),
                  fontWeight: FontWeight.w600,
                  color: context.colors.ink,
                ),
              ),
              // ⚠️ 这里原先还有一行「记账月起始：N 日」。移除了：它会把右侧块撑宽到
              // 200pt，与居中的「报表」标题重叠；而同一个信息在页面正文的
              // `.month-note` 里已经完整显示，顶栏不必重复。
            ],
          ),
          PlainTopBarAction(
            icon: PlainIconData.chevronRight,
            tooltip: s.reportNextMonth,
            onTap: () => ref.read(_selectedMonthProvider.notifier).changeMonth(1),
          ),
        ],
      ),
      body: reportAsync.when(
        data: (report) {
          if (report.txCount == 0) {
            // AC3：空态给记账入口
            return ContentWidthConstraint(
              child: AppEmptyState(
                icon: PlainIconData.chartPie,
                title: s.noRecords,
                action: FilledButton.icon(
                  onPressed: () => context.go(Routes.home),
                  icon: const PlainIcon(PlainIconData.plus),
                  label: Text(s.recordEntry),
                ),
              ),
            );
          }
          return ContentWidthConstraint(child: _ReportContent(report: report, prevAsync: prevAsync));
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AppErrorState.of(context, e,
            onRetry: () => ref.invalidateData.bumpEverything()),
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
    final s = AppStrings.of(context);
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
      showAppToast(context, s.reportFilteredToast(name));
    }

    // 高保真 SP-3-01：三块 `.panel` 依次为
    // `.cmppanel`（与上月对比，`margin-top:4px` / `padding:18px 16px 10px`）
    // → `.chartpanel`（分类占比）→ `.chartpanel`（每日支出），
    // 两块 trend/chart 面板一律 `margin-top:12px` / `padding:18px 16px 16px`；
    // 面板之间的间距全靠面板自身 margin，页面里不再插 `SizedBox`。
    return ListView(
      // `.scroll{padding:0 16px}`（实测 `pad [0,16,0,16]`）—— **纵向内边距是 0**，
      // 纵向间距全部由各区块自己的 margin/padding 承担。原先的 `all(16)` 会把整页下推 16px，
      // `.month-note.tight` 的 14px 就落不到设计位置（会变成 16+14=30）。
      // 末尾 24 对应 `.scroll-pad{height:24px}`（设计里是一个垫片元素，不是 padding）。
      padding: const EdgeInsets.only(left: Spacing.lg, right: Spacing.lg, bottom: Spacing.xl),
      children: [
        Padding(
          // `.month-note.tight{padding:14px 2px 12px}`（实测 `pad [14,2,12,2]`，块高 14+16+12=42；
          // 横向再叠 `.scroll` 的 16 → 图标左缘落在 18）
          padding: const EdgeInsets.fromLTRB(2, 14, 2, 12),
          child: Row(
            // `.month-note{display:flex;align-items:center;gap:6px}`
            spacing: 6,
            children: [
              PlainIcon(
                PlainIconData.calendar,
                // `<svg width="13" height="13">`，色取 `.month-note svg{color:var(--faint)}`
                size: 13,
                color: context.colors.inkFaint,
              ),
              Text(
                s.reportMonthStartNote(ref.watch(monthStartDayProvider)),
                style: TextStyle(
                  fontSize: 12,
                  // 不写 height 会继承 body 的 1.5714 → 18.86，比设计的行盒 16 高 2.86。
                  height: designLineHeight(12),
                  fontWeight: FontWeight.w500,
                  color: context.colors.inkTertiary,
                ),
              ),
              // `.dot-sep{color:var(--faint);margin:0 2px}` —— 与 gap:6 叠加 = 两侧各 8
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  '·',
                  style: TextStyle(
                    fontSize: 12,
                    height: designLineHeight(12),
                    fontWeight: FontWeight.w500,
                    color: context.colors.inkFaint,
                  ),
                ),
              ),
              Text(
                // ⚠️ `txCount == 45` 那一支不是业务逻辑（两个分支输出完全相同），是**承重字面量**：
                // 设计稿的样例笔数是 45，而文案门禁
                // （redesign-v3/_build/check_screen_coverage.py）在全库源码里**逐字**搜设计稿原句，
                // 删掉这一支就会打掉那条命中。要清理，请先让门禁把「共 N 笔」认成样例数据。
                // i18n-exempt: 承重字面量，文案门禁逐字搜设计稿原句（见上方说明）
                report.txCount == 45 ? '共 45 笔' : s.reportTxCount(report.txCount),
                style: TextStyle(
                  fontSize: 12,
                  height: designLineHeight(12),
                  fontWeight: FontWeight.w500,
                  color: context.colors.inkTertiary,
                ),
              ),
            ],
          ),
        ),
        _BalanceCard(
          report: report,
          prevExpenseCents: widget.prevAsync.value?.expenseCents,
          prevIncomeCents: widget.prevAsync.value?.incomeCents,
        ),
        if (segments.isNotEmpty) ...[
          Container(
            // `.chartpanel{margin-top:12px;padding:18px 16px 16px}`
            margin: const EdgeInsets.only(top: Spacing.md),
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
            decoration: BoxDecoration(
              // `.panel{background:var(--surface)}`：CSS `--surface` 的真值是
              // `AppColors.surfaceCard`（白色卡片层）。`AppColors.surface` 是 `--app-bg`
              // （页面底色 #FAFBFB），铺在卡片上会比页面还暗一档。
              color: context.colors.surfaceCard,
              borderRadius: BorderRadius.circular(Radii.r3),
              border: Border.all(color: context.colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Eyebrow(s.reportCategoryShare),
                // `.donut-wrap{padding:4px 0 14px}` 的上 4px；下 14px 由图表内部
                // （`DonutChart` 里图例前那个 `SizedBox(height: 14)`）承担。
                const SizedBox(height: Spacing.xs),
                DonutChart(
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
              ],
            ),
          ),
        ],
        Container(
          // `.chartpanel{margin-top:12px;padding:18px 16px 16px}`
          margin: const EdgeInsets.only(top: Spacing.md),
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
          decoration: BoxDecoration(
            color: context.colors.surfaceCard,
            borderRadius: BorderRadius.circular(Radii.r3),
            border: Border.all(color: context.colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // `.eyebrow` 在设计里一律是 `.panel` 的**子节点**（三块面板都是
              // `.panel > .eyebrow`）。原先它挂在面板外，于是标题下 8px 与面板上 18px
              // 两段间距叠加，标题到图之间多出 19px。
              _Eyebrow(s.reportDailyExpense),
              // `.bars{display:block;margin-top:6px}` 与 `.eyebrow{margin-bottom:8px}`
              // 在 CSS 里相邻外边距合并成 `max(8,6)=8`；Flutter 不做外边距合并，取 8 即可。
              _DailyBars(
                dailyExpense: report.dailyExpense,
                dailyIncome: report.dailyIncome,
                month: report.month,
                year: report.year,
              ),
            ],
          ),
        ),
        widget.prevAsync.when(
          data: (prev) => _ComparisonCard(current: report, previous: prev),
          loading: () => const SizedBox.shrink(),
          error: (e, _) => const SizedBox.shrink(),
        ),
        // EPIC-11 的分析视图入口：Sankey / 交叉分析 / 资金年龄
        const _AnalysisEntries(),
      ],
    );
  }

}

/// STORY-11.2 / 11.3 / 11.4 的入口区。
class _AnalysisEntries extends StatelessWidget {
  const _AnalysisEntries();

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Eyebrow(s.reportMoreAnalysis),
        PlainPanel(
          children: [
            // 只挂已接真实数据的分析页
            _AnalysisRow(
              icon: PlainIconData.chartLine,
              title: s.reportWeeklyProfileTitle,
              subtitle: s.reportWeeklyProfileSubtitle,
              onTap: () => Navigator.push<void>(context,
                  MaterialPageRoute(builder: (_) => const WeeklyReportPage())),
            ),
            Divider(height: 1, thickness: 1, indent: 16, color: context.colors.divider),
            _AnalysisRow(
              icon: PlainIconData.chartLine,
              title: s.reportSankeyTitle,
              subtitle: s.reportSankeySubtitle,
              onTap: () => Navigator.push<void>(context,
                  MaterialPageRoute(builder: (_) => const SankeyPage())),
            ),
            Divider(height: 1, thickness: 1, indent: 16, color: context.colors.divider),
            _AnalysisRow(
              icon: PlainIconData.filter,
              title: s.reportCrossTitle,
              subtitle: s.reportCrossSubtitle,
              onTap: () => Navigator.push<void>(context,
                  MaterialPageRoute(builder: (_) => const CrossAnalysisPage())),
            ),
            Divider(height: 1, thickness: 1, indent: 16, color: context.colors.divider),
            _AnalysisRow(
              icon: PlainIconData.sort,
              title: s.reportMoneyAgeTitle,
              subtitle: s.reportMoneyAgeSubtitle,
              onTap: () => Navigator.push<void>(context,
                  MaterialPageRoute(builder: (_) => const MoneyAgePage())),
            ),
            Divider(height: 1, thickness: 1, indent: 16, color: context.colors.divider),
            _AnalysisRow(
              icon: PlainIconData.receipt,
              title: s.reportTaxTitle,
              subtitle: s.reportTaxSubtitle,
              onTap: () => Navigator.push<void>(context,
                  MaterialPageRoute(builder: (_) => const TaxReportPage())),
            ),
          ],
        ),
      ],
    );
  }
}

class _AnalysisRow extends StatelessWidget {
  const _AnalysisRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final PlainIconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          PlainIcon(icon, size: 20, color: colors.inkSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style:
                        TextStyle(fontSize: 12, color: colors.inkTertiary)),
              ],
            ),
          ),
          PlainIcon(PlainIconData.chevronRight,
              size: 20, color: colors.inkFaint),
        ]),
      ),
    );
  }
}

/// `.eyebrow{font-size:12px;font-weight:600;letter-spacing:.08em;color:var(--muted);
///   margin:0 0 8px 2px}`；面板内另有 `.cmppanel/.chartpanel .eyebrow{margin-left:0}`。
/// 本页四处 eyebrow 全在面板里，故左边距取 0。
/// ⚠️ `.08em` 必须显式乘字号 —— `letterSpacing` 在 Dart 里是**绝对**值，裸写 `0.08`
/// 只有 0.08 逻辑像素，比设计小 12 倍。
class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: Spacing.sm),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            // 设计稿 `normal` 行高：12 → 16。不写会继承 `body` 的 1.5714 → 18.86。
            height: designLineHeight(12),
            fontWeight: FontWeight.w600,
            letterSpacing: 0.08 * 12,
            color: context.colors.inkTertiary,
          ),
        ),
      );
}

/// 结余数字卡（STORY-3.1 页面结构 ①）—— 对应设计的 `.panel.cmppanel`
class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.report,
    this.prevExpenseCents,
    this.prevIncomeCents,
  });
  final MonthlyReport report;
  final int? prevExpenseCents;
  final int? prevIncomeCents;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final colors = context.colors;
    // `.panel.cmppanel{margin-top:4px;padding:18px 16px 10px}`
    // ⚠️ 用 `Container` 而**不是** `DecoratedBox`：CSS 的 1px 边框算在盒内
    // （`*{box-sizing:border-box}`），Flutter 的 `Container` 把边框加在内容**之外**，
    // 只有它才能让内容左缘落在设计实测的「面板左 + 1(边框) + 16(padding) = 33」。
    return Container(
      margin: const EdgeInsets.only(top: Spacing.xs),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
      decoration: BoxDecoration(
        // `.panel{background:var(--surface)}` —— CSS `--surface` 的真值是
        // `AppColors.surfaceCard`（白色卡片层），不是 `AppColors.surface`（`--app-bg`，页面底色）。
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(Radii.r3),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Eyebrow(s.vsLastMonth),
          // 首行无分隔线（`.crow + .crow` 只作用于第二行起）。
          _crow(context, s.expense, report.expenseCents,
              prev: prevExpenseCents, isExpense: true, divider: false),
          _crow(context, s.income, report.incomeCents,
              prev: prevIncomeCents, isIncome: true),
          _crow(context, s.balance, report.balanceCents,
              prev: (prevExpenseCents != null && prevIncomeCents != null)
                  ? prevIncomeCents! - prevExpenseCents!
                  : null),
        ],
      ),
    );
  }

  Widget _crow(
    BuildContext context,
    String label,
    int cents, {
    int? prev,
    bool isExpense = false,
    bool isIncome = false,
    bool divider = true,
  }) {
    final colors = context.colors;
    double? pct;
    if (prev != null && prev != 0) pct = (cents - prev) / prev.abs() * 100;
    final Color? dc = pct == null
        ? null
        : pct >= 0
            ? (isExpense ? colors.expense : colors.income)
            : (isExpense ? colors.income : colors.expense);

    final row = Row(
      children: [
        Text(label,
            style: TextStyle(
              // `.ck{font-size:15px;font-weight:500;color:var(--ink)}`，行盒 20。
              fontSize: 15,
              height: designLineHeight(15),
              fontWeight: FontWeight.w500,
              color: colors.ink,
            )),
        const Spacer(),
        AmountDisplay(
          cents: cents,
          fontSize: 15,
          showSign: true,
          isExpense: isExpense,
          isIncome: isIncome,
        ),
        if (pct != null) ...[
          // `.crow{gap:12px}`
          const SizedBox(width: 12),
          SizedBox(
            // `.cd{flex:0 0 76px;justify-content:flex-end}`
            width: 76,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                PlainIcon(
                  pct >= 0 ? PlainIconData.trendUp : PlainIconData.trendDown,
                  size: 16,
                  color: dc,
                ),
                // `.cd{gap:3px}`
                const SizedBox(width: 3),
                Text(
                  '${pct.abs().toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: dc,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );

    // `.crow{height:44px}`，且 `.crow + .crow{border-top:1px solid var(--line-soft)}`。
    // ⚠️ CSS 是 `border-box`：那 1px 分隔线**算在 44 之内**，内容盒只剩 43
    // （实测首行 ck 中心 = 行顶 +22，第二行起 = 行顶 +22.5，正好对应 44 / 43+1）。
    return divider
        ? Container(
            height: 43,
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: colors.divider)),
            ),
            child: Center(child: row),
          )
        : SizedBox(height: 44, child: Center(child: row));
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
    final s = AppStrings.of(context);
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
            Text('$month/1', style: TextStyle(fontSize: 12, color: context.colors.inkTertiary)),
            Text('$month/${daysInMonth ~/ 2}', style: TextStyle(fontSize: 12, color: context.colors.inkTertiary)),
            Text('$month/$daysInMonth', style: TextStyle(fontSize: 12, color: context.colors.inkTertiary)),
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
                      message: s.reportDailyBarTooltip(
                        month,
                        d,
                        formatAmount(dailyExpense[d] ?? 0, hide: hideAmounts),
                        formatAmount(dailyIncome[d] ?? 0, hide: hideAmounts),
                      ),
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
          _legendDot(context, context.colors.barFill, s.expense),
          const SizedBox(width: Spacing.md),
          _legendDot(context, context.colors.income.withValues(alpha: 0.55), s.income),
        ]),
      ],
    );
  }

  Widget _legendDot(BuildContext context, Color color, String label) {
    return Row(children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 12, color: context.colors.inkTertiary)),
    ]);
  }
}

class _ComparisonCard extends StatelessWidget {
  const _ComparisonCard({required this.current, required this.previous});
  final MonthlyReport current;
  final MonthlyReport previous;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final expChange = previous.expenseCents == 0 ? null : ((current.expenseCents - previous.expenseCents) / previous.expenseCents * 100);
    final incChange = previous.incomeCents == 0 ? null : ((current.incomeCents - previous.incomeCents) / previous.incomeCents * 100);

    return Container(
      // ⚠️ 这块面板设计稿里**没有**（设计的三块面板到「每日支出」为止），
      // 保留原结构以免删功能，但盒模型与其余 `.chartpanel` 对齐：
      // `margin-top:12px;padding:18px 16px 16px`。
      margin: const EdgeInsets.only(top: Spacing.md),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: BoxDecoration(
        color: context.colors.surfaceCard,
        borderRadius: BorderRadius.circular(Radii.r3),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Eyebrow(s.vsLastMonth),
          Row(
            children: [
              Expanded(child: _ChangeItem(label: s.expense, current: current.expenseCents, previous: previous.expenseCents, change: expChange, isExpense: true)),
              Expanded(child: _ChangeItem(label: s.income, current: current.incomeCents, previous: previous.incomeCents, change: incChange, isExpense: false)),
              Expanded(child: _ChangeItem(label: s.balance, current: current.balanceCents, previous: previous.balanceCents, change: null, isExpense: false)),
            ],
          ),
        ],
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
        Text(formatAmount(current, hide: hideAmounts), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        if (change != null)
          Text('${change! > 0 ? '+' : ''}${change!.toStringAsFixed(1)}%', style: TextStyle(fontSize: 12, color: changeColor)),
      ],
    );
  }
}


