/// 报表模块文案（`features/reports/`）。
///
/// 只放报表页自身新增的文案；通用文案（保存 / 取消 / 关闭 / 删除 / 支出 /
/// 收入 / 结余 / 报表 …）一律复用 [AppStrings]，枚举与通用兜底复用
/// `strings_domain.dart`。使用方需 `import 'package:plain/app/l10n/strings_reports.dart';`。
library;

import 'package:plain/app/l10n/app_strings.dart';

extension ReportsStrings on AppStrings {
  // ─────────────────── reports_page 标题 / 入口 ───────────────────

  String get reportPrevMonth => isZh ? '上一月' : 'Previous month';
  String get reportNextMonth => isZh ? '下一月' : 'Next month';
  String reportMonthStartNote(int day) =>
      isZh ? '记账月起始：$day 日' : 'Month starts on day $day';
  String reportFilteredToast(String name) => isZh ? '已筛选「$name」' : 'Filtered: "$name"';
  String reportTxCount(int n) => isZh ? '共 $n 笔' : '$n entries in total';
  String reportDailyBarTooltip(int month, int day, String expense, String income) => isZh
      ? '$month月$day日 支出 ¥$expense · 收入 ¥$income'
      : '$month/$day · Spent ¥$expense · Income ¥$income';

  String get reportCategoryShare => isZh ? '分类占比' : 'Category share';
  String get reportDailyExpense => isZh ? '每日支出' : 'Daily spending';
  String get reportMoreAnalysis => isZh ? '更多分析' : 'More analysis';

  // 分析入口标题 / 副标题（跨页共用：reports_page 列表 + 各页 AppBar）
  String get reportWeeklyProfileTitle => isZh ? '本周消费画像' : 'Weekly spending profile';
  String get reportWeeklyProfileSubtitle =>
      isZh ? '周日推送的那份小结，随时可看' : 'The Sunday recap, anytime';
  String get reportSankeyTitle => isZh ? '桑基现金流' : 'Cash flow Sankey';
  String get reportSankeySubtitle => isZh ? '钱从哪来、流到哪去' : 'Where money comes from and goes';
  String get reportCrossTitle => isZh ? '交叉分析' : 'Cross analysis';
  String get reportCrossSubtitle => isZh ? '维度 × 维度的透视表' : 'Dimension × dimension pivot';
  String get reportMoneyAgeTitle => isZh ? '资金年龄' : 'Age of Money';
  String get reportMoneyAgeSubtitle =>
      isZh ? '这笔钱从进账到花掉等了多久' : 'How long money waits before being spent';
  String get reportTaxTitle => isZh ? '税务报表' : 'Tax report';
  String get reportTaxSubtitle =>
      isZh ? '按周期汇总可抵扣支出' : 'Deductible spending by period';

  // ─────────────────────── cross_analysis_page ───────────────────────

  String get reportMineTitle => isZh ? '我的报表' : 'My reports';
  String get reportRowLabel => isZh ? '行' : 'Row';
  String get reportColLabel => isZh ? '列' : 'Col';
  String get reportHeatmap => isZh ? '热力着色' : 'Heatmap';
  String get reportNoDataComboTitle => isZh ? '这个组合下没有数据' : 'No data for this combo';
  String get reportNoDataComboSubtitle =>
      isZh ? '换个维度或时间范围试试' : 'Try another dimension or range';
  String reportMatrixEyebrow(String row, String col, int count) =>
      isZh ? '$row × $col · $count 笔' : '$row × $col · $count';
  String reportComboName(String row, String col) => '$row × $col';
  String reportGrandTotalHint(String amount) => isZh
      ? '合计 $amount · 点任意单元格查看对应账单'
      : 'Total $amount · tap any cell to see its entries';
  String get reportSaveAsTitle => isZh ? '保存为我的报表' : 'Save as my report';
  String get reportNameField => isZh ? '报表名称' : 'Report name';
  String reportSavedToast(String name) => isZh ? '已保存「$name」' : 'Saved "$name"';
  String get reportSaveFailed => isZh ? '保存失败' : 'Save failed';
  String get reportNoSaved => isZh ? '还没有保存的报表' : 'No saved reports yet';
  String get reportDeleteTooltip => isZh ? '删除该报表' : 'Delete this report';
  String reportAppliedToast(String name) => isZh ? '已复现「$name」' : 'Restored "$name"';
  String get reportDeleteTitle => isZh ? '删除报表' : 'Delete report';
  String reportDeleteConfirm(String name) => isZh ? '删除「$name」？' : 'Delete "$name"?';
  String reportCellSheetTitle(String row, String col, int count) =>
      isZh ? '$row · $col（$count 笔）' : '$row · $col ($count)';
  String reportDimSheetTitle(String label) => isZh ? '$label维度' : 'Dimension: $label';
  String reportMatrixHeader(String row, String col) => '$row \\ $col';
  String get reportTotal => isZh ? '合计' : 'Total';
  String reportSavePanelHint(int count) => isZh
      ? '把当前的行列组合与筛选存成「我的报表」，下次一键复现。已保存 $count 份。'
      : 'Save the current row/column combo and filter as "My reports" to restore later. $count saved.';

  // ───────────────────────── tax_report_page ─────────────────────────

  String get taxExportTooltip => isZh ? '导出明细' : 'Export details';
  String get taxPeriodLabel => isZh ? '申报周期' : 'Filing period';
  String taxFiledStatus(String date) => isZh ? '已申报（$date）' : 'Filed ($date)';
  String get taxUnfiledStatus => isZh ? '未申报' : 'Not filed';
  String get taxEmptyTitle => isZh ? '该周期没有可抵扣支出' : 'No deductible spending in this period';
  String get taxEmptySubtitle => isZh
      ? '在分类管理里把相关分类标为「可抵扣」后，它们的支出会自动汇总到这里'
      : 'Mark categories as "deductible" in Category management and their spending will be collected here';
  String taxLinesEyebrow(int n) => isZh ? '可抵扣明细 · $n 类' : 'Deductible details · $n categories';
  String taxTotalRow(int n) => isZh ? '合计（$n 笔）' : 'Total ($n)';
  String get taxUnfileTitle => isZh ? '取消申报' : 'Unmark filed';
  String taxUnfileConfirm(String key) =>
      isZh ? '取消「$key」的已申报标记？' : 'Remove the filed mark for "$key"?';
  String get taxUnfiledToast => isZh ? '已取消申报' : 'Filing mark removed';
  String get taxFiledToast => isZh ? '已标记申报' : 'Marked as filed';
  String get taxMarkFailed => isZh ? '标记失败' : 'Failed to mark';
  String get taxNoExport => isZh ? '该周期没有可导出的明细' : 'Nothing to export in this period';
  String get taxCsvHeader => isZh ? '日期,分类,金额,备注' : 'Date,Category,Amount,Note';
  String taxShareSubject(String key, int n) =>
      isZh ? '可抵扣支出明细 $key（$n 笔）' : 'Deductible spending $key ($n)';
  String taxLineCount(int n) => isZh ? '$n 笔' : '$n';
  String get taxNote1 => isZh
      ? '「可抵扣」是分类上的标记：在分类管理里标记后，该分类的支出会自动汇总到这里。'
      : '"Deductible" is a flag on a category: once marked in Category management, its spending is collected here.';
  String get taxNote2 => isZh
      ? '二级分类继承其根分类的标记，不用逐个设置。'
      : 'Subcategories inherit their root category\'s flag — no need to set each one.';
  String get taxNote3 => isZh
      ? '年度汇总按自然年；记账月汇总按你在设置里定的月起始日。'
      : 'Yearly totals use the calendar year; monthly totals use the month-start day you set.';
  String get taxNoteFiled =>
      isZh ? '该周期已标记申报，取消后可以重新汇总。' : 'This period is marked filed; unmark to re-total.';
  String get taxNoteUnfiled => isZh
      ? '汇总无误后可以标记「已申报」，标记只记录状态，不影响账单。'
      : 'Once the totals look right, mark it "filed" — it only records status and does not affect entries.';

  // ─────────────────────────── sankey_page ───────────────────────────

  String get sankeyRangeThisMonth => isZh ? '本月' : 'This month';
  String get sankeyRangeLast3 => isZh ? '近 3 月' : 'Last 3 months';
  String get sankeyRangeCustom => isZh ? '自定义' : 'Custom';
  String get sankeyNoIncomeHint =>
      isZh ? '该时间段没有收入记录，无法形成「来源 → 去向」的流向。' : 'No income in this range, so no source → sink flow can be drawn.';
  String get sankeyNoExpenseHint =>
      isZh ? '该时间段没有支出记录，只看到收入来源。' : 'No spending in this range — only income sources shown.';
  String get sankeyFlowEyebrow => isZh ? '收入来源 → 汇总 → 支出去向' : 'Income sources → hub → spending targets';
  String get sankeyDetailEyebrow => isZh ? '明细' : 'Details';
  String get sankeyIncomeTotal => isZh ? '收入合计' : 'Total income';
  String get sankeyExpenseTotal => isZh ? '支出合计' : 'Total spending';
  String get sankeyOver => isZh ? '超支' : 'Overspent';
  String get sankeyEmptyTitle => isZh ? '这段时间没有收支' : 'No income or spending in this range';
  String get sankeyEmptySubtitle => isZh ? '换个时间范围或先记几笔' : 'Try another range or record a few first';
  String sankeyNodeSheetTitle(String label, int n) => isZh ? '$label · $n 笔' : '$label · $n';
  String get sankeyOtherHint => isZh
      ? '「其他」是多个小占比项合并而来，请切换到更细的维度查看。'
      : '"Other" merges several small shares — switch to a finer dimension to see them.';
  String get sankeyNoEntries => isZh ? '该节点下没有可展示的账单。' : 'No entries to show under this node.';
  String sankeyNoteDimension(String dim) => isZh
      ? '当前维度：$dim。点任意节点条可看该节点的账单明细。'
      : 'Current dimension: $dim. Tap any node bar to see its entries.';
  String get sankeyNoteThreshold =>
      isZh ? '占比不足 1% 的项会并入「其他」，避免图形被碎块淹没。' : 'Items under 1% are merged into "Other" so the chart stays readable.';
  String get sankeyNoteOtherNode => isZh
      ? '图中存在「其他」节点，切换到更细的维度可以看到具体分类。'
      : 'The chart has an "Other" node — switch to a finer dimension to see the categories.';
  String get sankeyNoteSurplus => isZh
      ? '这段时间收入大于支出，差额作为结余留在账户里，不流向任何支出。'
      : 'Income exceeded spending; the surplus stays in your accounts and flows to no target.';
  String get sankeyNoteDeficit => isZh
      ? '这段时间支出大于收入，超出部分来自既有余额。'
      : 'Spending exceeded income; the excess came from existing balances.';

  // ─────────────────────── weekly_report_page ───────────────────────

  String get weeklyNoRecordsTitle => isZh ? '本周还没有记录' : 'No records this week yet';
  String get weeklyNoRecordsSubtitle =>
      isZh ? '记一笔之后，这里会显示本周的消费画像。' : 'Record one and this week\'s spending profile will show here.';
  String get weeklySummaryEyebrow => isZh ? '本周小结' : 'Weekly recap';
  String get weeklyPushSection => isZh ? '推送设置' : 'Push settings';
  String get weeklyPushTitle => isZh ? '每周日晚推送' : 'Push every Sunday evening';
  String get weeklyEnabledOn => isZh ? '已开启' : 'On';
  String get weeklyEnabledOff => isZh ? '已关闭' : 'Off';
  String get weeklyLevelTitle => isZh ? '提醒方式' : 'Alert style';
  String get weeklyLevelRing => isZh ? '响铃' : 'Ring';
  String get weeklyLevelSilent => isZh ? '静默' : 'Silent';
  String weeklyPushNote(String weekEnd) => isZh
      ? '推送时间：$weekEnd 周日 20:00 起，到点后首次打开素记时送达（素记不常驻后台）。'
      : 'Delivery: from Sunday 20:00 on $weekEnd, on your first launch after the time (SuJi runs no background daemon).';
  String get weeklyExpenseLabel => isZh ? '本周支出' : 'Spent this week';
  String weeklyRangeLine(String start, String end, int count, String income) =>
      isZh ? '$start ~ $end · 共 $count 笔 · 收入 ¥$income' : '$start ~ $end · $count entries · Income ¥$income';
  String weeklyCompareLine(String dir, String pct) =>
      isZh ? '与上周同期相比：$dir $pct%' : 'vs same time last week: $dir $pct%';

  // ────────────────────────── money_age_page ──────────────────────────

  String get moneyAgeTrendEyebrow => isZh ? '近 6 个月趋势' : 'Last 6 months';
  String get moneyAgeCurrentLabel => isZh ? '当前资金年龄' : 'Current age of money';
  String get moneyAgeUnit => isZh ? '天' : 'days';
  String get moneyAgeNoExpense => isZh ? '无支出' : 'No spending';
  String moneyAgeDays(int n) => isZh ? '$n 天' : '$n days';
  String moneyAgeEmptySubtitle(int income, int expense) => isZh
      ? '资金年龄需要至少 5 笔收入、跨度约两个月的数据。当前收入 $income 笔、支出 $expense 笔。'
      : 'Age of Money needs at least 5 income entries spanning about two months. Currently $income income and $expense expense entries.';
  String get moneyAgeNote1 => isZh
      ? '资金年龄 = 花掉的每一块钱，其来源收入距花掉那天有多久，按金额加权平均。'
      : 'Age of Money = how long each yuan waited, from the income that funded it to the day it was spent, amount-weighted.';
  String get moneyAgeNote2 =>
      isZh ? '算法是 FIFO：每笔支出消耗最早尚未用完的那笔收入。' : 'The algorithm is FIFO: each expense consumes the earliest income not yet used up.';
  String get moneyAgeNote3 =>
      isZh ? '年龄越大越从容——说明钱在手里待得久，不靠当月工资过日子。' : 'A larger age is more comfortable — money stays longer, not living off this month\'s paycheck.';
  String moneyAgeNoteCounts(int income, int expense) =>
      isZh ? '当前参与计算：收入 $income 笔、支出 $expense 笔。' : 'Included: $income income and $expense expense entries.';
  String get moneyAgeNoteTrend => isZh
      ? '趋势里每月是当月支出的加权平均；当月没花钱显示「无支出」。'
      : 'Each bar is that month\'s amount-weighted average; months with no spending show "No spending".';
}
