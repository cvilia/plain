/// Domain 层文案（枚举 + services + usecases）。
///
/// 见 i18n 规范 5.1：跨字段复用的通用枚举 key 一律定义在本文件，
/// 其它任务只引用不重复定义。
///
/// 约定：`AppStrings` 已有的 key（支出/收入/转账/账户/分类/现金/储蓄卡/
/// 未分类 等）直接复用，本文件不重复定义。
library;

import 'package:plain/app/l10n/app_strings.dart';

extension DomainStrings on AppStrings {
  // ─────────────────────────── 通用兜底 ───────────────────────────
  String get other => isZh ? '其他' : 'Other';
  String get unknownCategory => isZh ? '未知分类' : 'Unknown category';
  String get unknownAccount => isZh ? '未知账户' : 'Unknown account';
  String get noAccount => isZh ? '未指定账户' : 'No account';
  String get noMerchant => isZh ? '未填商户' : 'No merchant';
  String get unnamedCategory => isZh ? '未命名分类' : 'Unnamed category';
  String get unknownMember => isZh ? '未知成员' : 'Unknown member';
  String get ungrouped => isZh ? '未分组' : 'Ungrouped';

  // ─────────────────────────── AssetType ───────────────────────────
  String get assetStock => isZh ? '股票' : 'Stock';
  String get assetFund => isZh ? '基金' : 'Fund';
  String get assetBond => isZh ? '债券' : 'Bond';
  String get assetCrypto => isZh ? '加密' : 'Crypto';
  String get assetOther => isZh ? '其他' : 'Other';

  // ─────────────────────── AssetValuationMode ───────────────────────
  String get valuationNone => isZh ? '不估值' : 'None';
  String get valuationFixed => isZh ? '固定值' : 'Fixed';
  String get valuationDepreciate => isZh ? '年折旧率' : 'Depreciation';
  String get valuationAppreciate => isZh ? '年增值率' : 'Appreciation';
  String get valuationManual => isZh ? '手动调整' : 'Manual';

  // ─────────────────────── BudgetMethodology ───────────────────────
  String get budgetMethodCustom => isZh ? '分类限额' : 'Custom';
  String get budgetMethodEnvelope => isZh ? '信封预算' : 'Envelope';
  String get budgetMethodZeroBased => isZh ? '零基预算' : 'Zero-based';
  String get budgetMethodFiftyThirtyTwenty => isZh ? '50-30-20' : '50-30-20';

  // ────────────────────────── RatioBucketKind ──────────────────────────
  String get ratioNeeds => isZh ? '需要' : 'Needs';
  String get ratioWants => isZh ? '想要' : 'Wants';
  String get ratioSavings => isZh ? '储蓄' : 'Savings';

  // ───────────────────────── TaxPeriodKind ─────────────────────────
  String get taxPeriodMonth => isZh ? '记账月' : 'Month';
  String get taxPeriodYear => isZh ? '年度' : 'Year';

  // ─────────────────────── ReportEntryFilter ───────────────────────
  String get reportFilterAll => isZh ? '全部' : 'All';
  String get reportFilterExpense => isZh ? '只看支出' : 'Expense only';
  String get reportFilterIncome => isZh ? '只看收入' : 'Income only';

  // ───────────────────────── CrossDimension ─────────────────────────
  // 「分类」「账户」复用 app_strings 的 category / account。
  String get crossMonth => isZh ? '月份' : 'Month';
  String get crossMerchant => isZh ? '商户' : 'Merchant';
  String get crossAmountRange => isZh ? '金额区间' : 'Amount range';
  String crossRangeLabel(int from, int to) => isZh ? '$from–$to 元' : '¥$from–$to';

  // ───────────────────────── LoanRepayMethod ─────────────────────────
  String get repayEqualInstallment => isZh ? '等额本息' : 'Equal installment';
  String get repayEqualPrincipal => isZh ? '等额本金' : 'Equal principal';
  String get repayNotSet => isZh ? '未设置' : 'Not set';

  // ─────────────────────────── MemberRole ───────────────────────────
  String get memberRoleOwner => isZh ? '所有者' : 'Owner';
  String get memberRoleMember => isZh ? '成员' : 'Member';
  String get memberRoleViewer => isZh ? '只读' : 'Viewer';

  // ─────────────────────────── MemberStatus ───────────────────────────
  String get memberStatusActive => isZh ? '在册' : 'Active';
  String get memberStatusLeft => isZh ? '已退出' : 'Left';
  String memberLeftAttribution(String name) =>
      isZh ? '已退出成员（$name）' : '$name (left)';

  // ──────────────────── EntryType（支出/收入/转账 复用） ────────────────────
  String get entryBorrowOut => isZh ? '借出' : 'Lend';
  String get entryBorrowIn => isZh ? '借入' : 'Borrow';
  String get entryRepayCredit => isZh ? '还款' : 'Repay';
  String get entryUnknown => isZh ? '未知' : 'Unknown';

  // ────────────────── AccountType（现金/储蓄卡 复用） ──────────────────
  String get accountTypeCredit => isZh ? '信用卡' : 'Credit card';
  String get accountTypeInvestment => isZh ? '投资' : 'Investment';
  String get accountTypeLoan => isZh ? '贷款' : 'Loan';
  String get accountTypeLend => isZh ? '借出' : 'Lend';
  String get accountTypeGoal => isZh ? '目标' : 'Goal';

  // ────────────────────────── ReimburseStatus ──────────────────────────
  String get reimburseNone => isZh ? '不报销' : 'No';
  String get reimbursePending => isZh ? '待报销' : 'Pending';
  String get reimburseSubmitted => isZh ? '已提交' : 'Submitted';
  String get reimbursePartial => isZh ? '部分回款' : 'Partial';
  String get reimburseDone => isZh ? '已回款' : 'Reimbursed';
  String get reimburseAbandoned => isZh ? '已放弃' : 'Abandoned';

  // ───────────────────────────── SplitRole ─────────────────────────────
  String get splitNormal => isZh ? '正常' : 'Normal';
  String get splitParent => isZh ? '拆分主笔' : 'Split parent';
  String get splitChild => isZh ? '拆分子笔' : 'Split child';

  // ─────────────────────── ReminderKind ───────────────────────
  String get reminderCreditDue => isZh ? '信用卡还款' : 'Credit due';
  String get reminderSubscription => isZh ? '订阅到期' : 'Subscription';
  String get reminderBudgetWarn => isZh ? '预算预警' : 'Budget alert';
  String get reminderLowBalance => isZh ? '余额不足' : 'Low balance';
  String get reminderAnomalySpend => isZh ? '异常支出' : 'Unusual spend';
  String get reminderRecurringPosted => isZh ? '周期账单' : 'Recurring posted';
  String get reminderReconcile => isZh ? '对账提醒' : 'Reconcile';
  String get reminderSavingsGoal => isZh ? '储蓄目标' : 'Savings goal';
  String get reminderBackup => isZh ? '备份提醒' : 'Backup';

  // ─────────────────── ReminderService 提醒标题/正文 ───────────────────
  String get remCreditDueSoonTitle => isZh ? '信用卡还款日临近' : 'Credit card due soon';
  String remCreditDueSoonBody(String name, String dueKey, String amount) =>
      isZh ? '「$name」$dueKey 到期，欠款 $amount' : '"$name" is due $dueKey, owed $amount';
  String get remCreditDueTodayTitle => isZh ? '今天信用卡还款日' : 'Credit card due today';
  String remCreditDueTodayBody(String name, String dueKey, String amount) =>
      isZh
          ? '「$name」$dueKey 今天到期，欠款 $amount'
          : '"$name" is due today ($dueKey), owed $amount';
  String get remSubscriptionTitle => isZh ? '订阅即将扣款' : 'Subscription charging soon';
  String get remRecurringCharge => isZh ? '周期扣款' : 'Recurring charge';
  String remSubscriptionBody(String name, String key, String amount) => isZh
      ? '「$name」$key 将扣款 $amount。不再需要的话，先到原扣款渠道取消自动续费，'
          '再点这里的「不再需要」关掉这条周期规则。'
      : '"$name" will charge $amount on $key. If no longer needed, cancel auto-renew '
          'at the original channel, then tap "Not needed" here to disable this rule.';
  String get remTotalBudget => isZh ? '总预算' : 'Total budget';
  String remCategoryLabel(String name) => isZh ? '「$name」' : '"$name"';
  String get remBudgetOverTitle => isZh ? '预算已超支' : 'Budget exceeded';
  String remBudgetOverBody(String label, String pct, String amount) => isZh
      ? '$label 本期已用 $pct%，超出 $amount'
      : '$label used $pct% this period, over by $amount';
  String get remBudgetWarnTitle => isZh ? '预算预警' : 'Budget alert';
  String remBudgetWarnBody(String label, String pct, String amount) => isZh
      ? '$label 本期已用 $pct%，剩余 $amount'
      : '$label used $pct% this period, $amount left';
  String get remLowBalanceTitle => isZh ? '余额不足预警' : 'Low balance alert';
  String remLowBalanceBody(String amount) => isZh
      ? '安全可花为负（$amount），本月可用资金已被预留项吃掉'
      : 'Safe-to-spend is negative ($amount); reserved items consumed this month\'s funds';
  String get remAnomalyTitle => isZh ? '异常支出' : 'Unusual spend';
  String remAnomalyBody(String amount) => isZh
      ? '$amount 高于该分类近 90 天的常见水平'
      : '$amount is above this category\'s usual level in the last 90 days';
  String get remAnomalyDayTitle => isZh ? '当日支出偏高' : 'High spend today';
  String remAnomalyDayBody(String today, String avg) => isZh
      ? '今日已支出 $today，高于近 30 天日均 $avg'
      : 'Spent $today today, above the 30-day daily average of $avg';
  String get remRecurringPostedTitle => isZh ? '周期账单已入账' : 'Recurring entries posted';
  String remRecurringPostedBody(int n) =>
      isZh ? '已自动入账 $n 笔周期账单' : '$n recurring entries auto-posted';
  String get remReconcileTitle => isZh ? '对账提醒' : 'Reconcile reminder';
  String remReconcileBody(String period, int n) =>
      isZh ? '$period 有 $n 笔账单未对账' : '$n entries unreconciled in $period';
  String get remSavingsGoalTitle => isZh ? '储蓄目标待存' : 'Savings goal deposit due';
  String remSavingsGoalBody(String name, String amount) =>
      isZh ? '「$name」本月需存 $amount' : '"$name" needs $amount this month';
  String get remBackupTitle => isZh ? '备份提醒' : 'Backup reminder';
  String remBackupBody(int days) => isZh
      ? '距上次备份已 $days 天，建议导出一次整库备份'
      : '$days days since last backup; consider exporting a full backup';

  // ────────────────── ReminderDigest / AppReminder ──────────────────
  String get reminderNotNeeded => isZh ? '不再需要' : 'Not needed';
  String get reminderDigestTitle => isZh ? '夜间提醒汇总' : 'Nightly reminder digest';
  String reminderDigestPosted(int n) => isZh ? '已入账 $n 笔' : '$n posted';
  String reminderDigestBudgetWarn(int n) => isZh ? '预算预警 $n 条' : '$n budget alerts';
  String reminderDigestDowngraded(int n) => isZh ? '响铃降级 $n 条' : '$n downgraded';
  String get reminderDigestEmpty =>
      isZh ? '夜间免打扰期间产生的提醒已进提醒中心' : 'Reminders from quiet hours are in the reminder center';
  String reminderDigestBody(int total, String parts) =>
      isZh ? '夜间 $total 条提醒：$parts' : '$total reminders overnight: $parts';

  // ─────────────────────── 消费周报（WeeklyReport） ───────────────────────
  String get wrSummaryTitle => isZh ? '本周消费画像' : 'Weekly spending profile';
  String wrExpenseLine(String amount, int count) =>
      isZh ? '支出 ¥$amount · $count 笔' : 'Spent ¥$amount · $count entries';
  String get wrUp => isZh ? '上升' : 'up';
  String get wrDown => isZh ? '下降' : 'down';
  String wrMonthOverMonth(String dir, String pct) =>
      isZh ? '环比$dir $pct%' : '$dir $pct% vs last week';
  String get wrNoRecords =>
      isZh ? '本周还没有记录，随时可以补一笔' : 'No records this week yet — add one anytime';
  String wrExpenseOnly(String amount) => isZh ? '支出 ¥$amount' : 'Spent ¥$amount';
  String wrMainCategory(String name) => isZh ? '主要「$name」' : 'Top "$name"';
  String wrCountLine(int n) => isZh ? '$n 笔' : '$n entries';
  String get wrHighlightLess => isZh
      ? '支出比上周同期有所减少，继续保持'
      : 'Spending is down from the same time last week — keep it up';
  String get wrHighlightMore =>
      isZh ? '本周比上周同期多花了一些' : 'Spent a bit more than the same time last week';
  String wrTopCategory(String name, int share) => isZh
      ? '「$name」是本周主要支出，占 $share%'
      : '"$name" is this week\'s top category at $share%';
  String wrShareShift(String name, int prev, int cur) =>
      isZh ? '「$name」占比 $prev% → $cur%' : '"$name" share $prev% → $cur%';
  String wrLargest(String amount) =>
      isZh ? '本周单笔最大 ¥$amount' : 'Largest single spend this week ¥$amount';

  // ───────────────────────── NetWorthBucket ─────────────────────────
  // 「现金」复用 app_strings.cash，「投资」复用 accountTypeInvestment。
  String get nwSavings => isZh ? '储蓄' : 'Savings';
  String get nwFixedAsset => isZh ? '固定资产' : 'Fixed assets';
  String get nwReceivable => isZh ? '借出' : 'Receivable';
  String get nwCredit => isZh ? '信用卡' : 'Credit card';
  String get nwLoan => isZh ? '贷款' : 'Loan';
  String get nwPayable => isZh ? '借入' : 'Payable';
  String get nwGoal => isZh ? '目标预留' : 'Goal reserved';
  String nwMonths(int n) => isZh ? '$n 个月' : '$n months';
  String nwHoldingCount(int n) => isZh ? '含 $n 个持仓' : '$n holdings';

  // ───────────────────────── SankeyDimension ─────────────────────────
  // 「账户」复用 app_strings.account。
  String get sankeyTopCategory => isZh ? '一级分类' : 'Top category';
  String get sankeyLeafCategory => isZh ? '二级分类' : 'Subcategory';

  // ─────────────────── BudgetMethodologyService ───────────────────
  String bmEnvelopeNoBorrow(String categoryName, String spent) => isZh
      ? '信封法下不可跨类挪用：「$categoryName」已花 $spent 元，额度不能低于该值'
      : 'Envelope method forbids cross-category borrowing: "$categoryName" has spent ¥$spent, so the limit cannot be lower';
  String bmShapeCustom(int n) => isZh ? '总预算 + $n 条分类限额' : 'Total budget + $n category limits';
  String bmShapeEnvelope(int n) => isZh ? '$n 个信封（各自滚存）' : '$n envelopes (each rolling)';
  String bmShapeZeroBased(int n) => isZh ? '$n 项已分配 + 待分配余额' : '$n allocated + unallocated balance';
  String bmShapeFTT(int n) => isZh
      ? '需要 / 想要 / 储蓄三档（$n 条限额按刚性标记归入前两档）'
      : 'Needs / Wants / Savings ($n limits bucketed by the rigid flag)';
  String bmSwitchPreview(String from, String to, String shapeFrom, String shapeTo) => isZh
      ? '从「$from」切到「$to」：同样的数据由「$shapeFrom」呈现为「$shapeTo」。账单与报表不受影响。'
      : 'Switch from "$from" to "$to": the same data goes from "$shapeFrom" to "$shapeTo". Entries and reports are unaffected.';

  // ─────────────────────────── CSV 导入 ───────────────────────────
  String csvErrTooFewColumns(int lineNo) =>
      isZh ? '第 $lineNo 行: 列数不足' : 'Row $lineNo: not enough columns';
  String csvErrBadDate(int lineNo, String raw) =>
      isZh ? '第 $lineNo 行: 无法解析日期 "$raw"' : 'Row $lineNo: cannot parse date "$raw"';
  String csvErrBadAmount(int lineNo, String raw) =>
      isZh ? '第 $lineNo 行: 无法解析金额 "$raw"' : 'Row $lineNo: cannot parse amount "$raw"';
  String importFailed(String fingerprint) =>
      isZh ? '导入失败: $fingerprint' : 'Import failed: $fingerprint';

  // ───────────────────────── MoneyAgeResult ─────────────────────────
  String get maAccumulating => isZh ? '数据积累中' : 'Collecting data';
  String maCurrentOnly(int days) => isZh
      ? '当前约 $days 天：这笔钱从进账到花掉平均等了这么久。'
      : 'About $days days now: that is how long money waits on average from income to spend.';
  String maStable(int days) => isZh
      ? '与上月基本持平（约 $days 天），节奏很稳。'
      : 'Roughly flat vs last month (about $days days) — a steady pace.';
  String maMoreRelaxed(int prev, int cur, int diff) => isZh
      ? '比上月更从容：$prev 天 → $cur 天，钱在手里多留了约 $diff 天。'
      : 'More comfortable than last month: $prev → $cur days, money stayed about $diff days longer.';
  String maTighter(int prev, int cur, int diff) => isZh
      ? '比上月吃紧：$prev 天 → $cur 天，钱花得比上个月快约 $diff 天。'
      : 'Tighter than last month: $prev → $cur days, spending about $diff days faster.';

  // ─────────────────────────── RuleEngine ───────────────────────────
  String ruleSetCategory(String value) => isZh ? '设分类 → $value' : 'Set category → $value';
  String ruleSetAccount(String value) => isZh ? '设账户 → $value' : 'Set account → $value';
  String ruleSetNotePrefix(String prefix) => isZh ? '备注前缀「$prefix」' : 'Note prefix "$prefix"';
  String get ruleMarkExcluded => isZh ? '标不计入收支' : 'Mark excluded';
  String get ruleMarkReimbursable => isZh ? '标待报销' : 'Mark reimbursable';
  String ruleRegexInvalid(int n, String message) =>
      isZh ? '条件 $n 正则非法: $message' : 'Condition $n has an invalid regex: $message';

  // ───────────────────────── 债务优化（DebtStrategy） ─────────────────────────
  String get debtSnowball => isZh ? '雪球法' : 'Snowball';
  String get debtAvalanche => isZh ? '雪崩法' : 'Avalanche';
  String debtReasonRecommended(String strategy, String saving) => isZh
      ? '推荐$strategy：总利息比另一种少 $saving 元'
      : 'Recommended $strategy: ¥$saving less total interest than the other';
  String get debtReasonTie => isZh
      ? '两种策略总利息相同，任选其一即可'
      : 'Both strategies have the same total interest — pick either';

  // ─────────────────────────── ReceiptParser ───────────────────────────
  String ocrAmount(String amount) => isZh ? '金额 $amount' : 'Amount $amount';
  String ocrMerchant(String name) => isZh ? '商户「$name」' : 'Merchant "$name"';
  String ocrDate(String date) => isZh ? '日期 $date' : 'Date $date';
  String get ocrEmpty => isZh ? '没有识别到可用信息' : 'No usable info recognized';
  String ocrRecognized(String parts) => isZh ? '识别到：$parts' : 'Recognized: $parts';

  // ───────────────────────── CategoryNaming ─────────────────────────
  String get catRootDuplicate =>
      isZh ? '已有同名一级分类' : 'A top-level category with this name already exists';
  String catSubDuplicate(String parentName) => isZh
      ? '「$parentName」下已有同名分类'
      : 'A category with this name already exists under "$parentName"';
  String catRootNameDuplicate(String n) =>
      isZh ? '与一级分类「$n」同名' : 'Same name as top-level category "$n"';

  // ───────────────────────── EmotionFeedback ─────────────────────────
  String get emotionGoalAchieved => isZh ? '目标达成！' : 'Goal reached!';
  String get emotionMonthFirst => isZh ? '新的一月，从这一笔开始' : 'A new month starts with this one';
  String get emotionPositive => isZh ? '这笔记得很稳' : 'Nicely tracked';
  String get emotionLarge => isZh ? '这笔比平时大一些' : 'A bit larger than usual';

  // ────────────────────────── Gamification ──────────────────────────
  String streakMilestone(int days) => isZh ? '连续 $days 天' : '$days-day streak';
  String get streak100 =>
      isZh ? '连续 100 天 · 终身卡抽奖资格' : '100-day streak · lifetime card raffle';
  String accumulateMilestone(int total) => isZh ? '累计 $total 笔' : '$total entries in total';

  // ────────────────────────── CurrencyService ──────────────────────────
  String get currencyRateRequired =>
      isZh ? '需填写两边金额与汇率' : 'Enter both amounts and the exchange rate';

  // ───────────────────────────── TaxService ─────────────────────────────
  String taxYearLabel(int year) => isZh ? '$year 年度' : 'Year $year';

  // ─────────────────────── AiRecognitionService ───────────────────────
  String aiQuotaDisplay(int used, int total) => isZh ? '$used / $total 次' : '$used / $total';

  // ───────────────────────── SyncConflict ─────────────────────────
  String get conflictUnresolved => isZh ? '待裁决' : 'Unresolved';
  String get conflictKeepLocal => isZh ? '保留本机版本' : 'Keep local';
  String get conflictKeepRemote => isZh ? '保留远端版本' : 'Keep remote';
  String get conflictKeepBoth => isZh ? '都保留' : 'Keep both';
  // 实体类型标签（「分类」「账户」复用 category / account）。
  String get entityTransaction => isZh ? '账单' : 'Entry';
  String get entityBudget => isZh ? '预算' : 'Budget';
  String get entityMember => isZh ? '成员' : 'Member';
  String get entitySavingsGoal => isZh ? '储蓄目标' : 'Savings goal';
  String get entityRecurringRule => isZh ? '周期规则' : 'Recurring rule';
  String get entityCurrencyRate => isZh ? '锁定汇率' : 'Locked rate';
  // 操作日志要覆盖 EntityType 全量 wire 值，漏一个界面就会直接打英文枚举串。
  String get entityMerchantRule => isZh ? '商家规则' : 'Merchant rule';
  String get entityAutomationRule => isZh ? '自动化规则' : 'Automation rule';
  String get entityHolding => isZh ? '持仓' : 'Holding';
  String get entitySavedReport => isZh ? '报表存档' : 'Saved report';
  String get entityTaxFiling => isZh ? '税务申报' : 'Tax filing';
  String get entityEntryParticipant => isZh ? '分摊参与人' : 'Participant';
  String get entitySetting => isZh ? '设置' : 'Setting';

  // ─────────────────────── SavedReport.describe ───────────────────────
  String reportDescribe(String row, String col, String filter) =>
      isZh ? '行 $row × 列 $col · $filter' : 'Row $row × Col $col · $filter';
}
