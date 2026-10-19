/// 资产 / 账户 / 家庭 / 安全 文案。
///
/// 归属：`features/accounts/`、`features/assets/`、`features/family/`、
/// `features/security/`。通用文案（保存/取消/删除/确定/账户/现金/储蓄卡 …）
/// 一律复用 [AppStrings]，枚举文案（AssetType / AccountType / MemberRole …）
/// 复用 `strings_domain.dart`，本文件只放页面私有文案。
library;

import 'package:plain/app/l10n/app_strings.dart';

extension AccountsStrings on AppStrings {
  // ───────────────────────────── 账户通用 ─────────────────────────────
  String get netWorth => isZh ? '净值' : 'Net worth';
  String get liabilities => isZh ? '负债' : 'Liabilities';
  String get editAccount => isZh ? '编辑账户' : 'Edit account';
  String get nameLabel => isZh ? '名称' : 'Name';
  String get nameHintCash => isZh ? '如：现金' : 'e.g. Cash';
  String get currency => isZh ? '币种' : 'Currency';
  String get notSelected => isZh ? '未选择' : 'Not selected';
  String get saveChanges => isZh ? '保存修改' : 'Save changes';
  String get openingDebt => isZh ? '期初欠款' : 'Opening debt';
  String get noteOptional => isZh ? '备注（可选）' : 'Note (optional)';
  String pendingReconcileCount(int n) => isZh ? '待对账 $n 笔' : '$n to reconcile';
  String reconcileFailed(String code) => isZh ? '对账失败：$code' : 'Reconcile failed: $code';

  // 期初余额说明（信用卡 / 贷款 / 外币）
  String get loanOpeningAutoNote =>
      isZh ? '期初余额按 −贷款总额 自动记入（负债为负）' : 'Opening balance auto-set to −principal (liability is negative)';
  String get creditDebtMaintainedNote => isZh
      ? '欠款余额由账单与对账页维护，如需修正请到信用卡对账页'
      : 'Debt balance is maintained by bills and the reconcile page; adjust it there.';
  String foreignOpeningNote(String currency) => isZh
      ? '外币账户的期初按 $currency 记，不并入本位币余额；'
          '净值里按「汇率锁定」设定的人民币汇率折算参与。'
      : 'The opening balance is kept in $currency and not merged into base-currency '
          'balance; net worth converts it via the locked CNY rate.';

  // ─────────────────────────── 信用卡参数 ───────────────────────────
  String get creditLimit => isZh ? '总额度' : 'Credit limit';
  String get billDayLabel => isZh ? '账单日 (1–28)' : 'Bill day (1–28)';
  String get dueDayLabel => isZh ? '还款日 (1–28)' : 'Due day (1–28)';
  String get minPayment => isZh ? '最低还款' : 'Min payment';
  String get creditAnnualRateLabel => isZh ? '循环年利率 %' : 'Revolving rate %';

  // ─────────────────────────── 贷款参数 ───────────────────────────
  String get loanPrincipal => isZh ? '贷款总额' : 'Loan principal';
  String get annualRateLabel => isZh ? '年利率 %' : 'Annual rate %';
  String get termMonthsLabel => isZh ? '期数（月）' : 'Term (months)';
  String get repayMethod => isZh ? '还款方式' : 'Repayment method';
  String get equalInstallmentDesc =>
      isZh ? '每期还款额一致，前期利息占比高' : 'Equal payments; more interest up front';
  String get equalPrincipalDesc => isZh
      ? '每期本金一致，利息逐期递减，总利息更少'
      : 'Equal principal; interest declines each period, less total interest';
  String get firstPaymentDate => isZh ? '首次还款日' : 'First payment date';
  String get repayAccount => isZh ? '还款账户' : 'Repayment account';
  String get interestCategory => isZh ? '利息分类' : 'Interest category';
  String get interestCategoryLabel => isZh ? '利息分类（计入支出）' : 'Interest category (counts as expense)';
  String get fillLoanPrincipal => isZh ? '请填写贷款总额' : 'Enter the loan principal';
  String get fillTermAndFirstPayment =>
      isZh ? '请填写期数与首次还款日' : 'Enter the term and first payment date';
  String get selectRepayAccount => isZh ? '请选择还款账户' : 'Select a repayment account';
  String repayScheduleFailed(String code) =>
      isZh ? '还款计划建立失败：$code' : 'Failed to build repayment plan: $code';

  // ─────────────────────────── 资产估值 ───────────────────────────
  String get valuationMode => isZh ? '资产估值方式' : 'Valuation mode';
  String get valuationNoneDesc => isZh ? '账户按收支派生余额计入' : 'Account counts by its derived balance';
  String get valuationFixedDesc => isZh ? '始终等于你设定的固定金额' : 'Always equals your fixed amount';
  String get valuationDepreciateDesc => isZh ? '按持有月数复利递减' : 'Compounds down by months held';
  String get valuationAppreciateDesc => isZh ? '按持有月数复利递增' : 'Compounds up by months held';
  String get valuationManualDesc => isZh ? '等于你手填的当前估值' : 'Equals the value you entered';
  String get valuationBase => isZh ? '原值' : 'Cost basis';
  String get valuationDepreciateRate => isZh ? '年折旧率 %' : 'Annual depreciation %';
  String get valuationAppreciateRate => isZh ? '年增值率 %' : 'Annual appreciation %';
  String get holdingStartDate => isZh ? '持有起始日' : 'Holding start date';
  String get currentValuation => isZh ? '当前估值' : 'Current value';

  // ─────────────────────── 信用卡对账页（credit_reconcile） ───────────────────────
  String get loadAccountFailed => isZh ? '账户加载失败' : 'Failed to load account';
  String get creditBillTitle => isZh ? '信用卡账单' : 'Credit card bill';
  String get currentDueHero => isZh ? '本期应还 · 还款日 10月8日' : 'Due this period · due on Oct 8';
  String get availableLimit => isZh ? '可用额度' : 'Available limit';
  String get usedLimit => isZh ? '已用额度' : 'Used limit';
  String get usedLabel => isZh ? '已用' : 'Used';
  String get accountParams => isZh ? '账户参数' : 'Account details';
  String get billDay => isZh ? '账单日' : 'Bill day';
  String get monthlyBillDay => isZh ? '每月 25 日' : 'The 25th monthly';
  String get dueDay => isZh ? '还款日' : 'Due day';
  String get nextMonthDueDay => isZh ? '次月 8 日' : 'The 8th next month';
  String get cycleInterest => isZh ? '循环利息' : 'Revolving interest';
  String get noCycleInterest => isZh ? '无（全额还款）' : 'None (paid in full)';
  String get usedHealthy => isZh ? '已用 25.0%，额度使用健康' : '25.0% used — healthy';
  String get unbilledLabel => isZh ? '本期未出账消费 · ¥1,899.50' : 'Unbilled spend · ¥1,899.50';
  String get noCreditEntries => isZh ? '该信用卡还没有账单' : 'No entries on this credit card yet';
  String get creditAuthNote =>
      isZh ? '「欠款余额」是可写的唯一权威量；「可用额度」由总额度派生，' : '"Debt balance" is the only writable authority; "available limit" derives from the total, ';
  String get dualModelLabel => isZh ? '双数模型：' : 'a dual-value model: ';
  String get readOnlyLabel => isZh ? '只读' : 'read-only';
  String get reconcileScopeNote => isZh
      ? '本期应还 ¥5,000.00 与未出账 ¥1,899.50 是两个口径： 前者是上一账单周期的结算结果，后者是本期新增。'
      : 'Due this period (¥5,000.00) and unbilled (¥1,899.50) are two scopes: the former settles the previous cycle, the latter is new this cycle.';
  String get creditSpendSpent => isZh ? '信用卡消费（钱确实花了）' : 'Credit spend (money actually spent)';
  String get creditSpendRepay => isZh ? ' 还信用卡（只减少欠款）' : ' Repay credit (only reduces debt)';
  String get countedInExpense => isZh ? '计入支出统计' : 'counts as expense';
  String get notInStats => isZh ? '不计入收支' : 'not in income/expense';
  String get bankAppDebt => isZh ? '银行 App 显示欠款' : 'Debt shown in bank app';
  String get actualDebt => isZh ? '实际欠款' : 'Actual debt';
  String get writeDebtAction => isZh ? '写入欠款并生成调整凭证' : 'Write debt and create adjustment';
  String get invalidDebtAmount => isZh ? '请输入有效欠款金额' : 'Enter a valid debt amount';
  String get debtUpdated => isZh ? '欠款已更新' : 'Debt updated';
  String debtWrittenWithAdjustment(String amount) =>
      isZh ? '已写入欠款，生成调整 $amount' : 'Debt written, adjustment $amount created';
  String creditReconcileFailed(String code) =>
      isZh ? '对账失败: $code' : 'Reconcile failed: $code';

  // ─────────────────────── 逐笔对账（reconcile_mode） ───────────────────────
  String get operationFailed => isZh ? '操作失败' : 'Operation failed';
  String reconcileWithName(String name) => isZh ? '对账 · $name' : 'Reconcile · $name';
  String reconciledUpTo(String label) => isZh ? '已对账至 $label' : 'Reconciled up to $label';
  String get noBills => isZh ? '没有账单' : 'No entries';
  String get reconcileEmptyHint => isZh ? '先在流水页记几笔再回来对账' : 'Record a few entries first, then reconcile';
  String checkedCount(int done, int total) => isZh ? '已核对 $done / $total' : 'Checked $done / $total';
  String get allChecked => isZh ? '已全部核对' : 'All checked';
  String get checkAll => isZh ? '全部勾选' : 'Check all';

  // ─────────────────────── 投资持仓（investment_page） ───────────────────────
  String get addLabel => isZh ? '新增' : 'Add';
  String get addHolding => isZh ? '新增持仓' : 'Add holding';
  String get noHoldings => isZh ? '还没有持仓' : 'No holdings yet';
  String get holdingsHint =>
      isZh ? '录入名称、份额与成本单价即可追踪市值与盈亏' : 'Enter name, shares and cost price to track value and P&L';
  String holdingsCount(int n) => isZh ? '持仓 · $n 个' : 'Holdings · $n';
  String get codeOptionalLabel => isZh ? '代码（选填）' : 'Code (optional)';
  String get typeLabel => isZh ? '类型' : 'Type';
  String get shares => isZh ? '份额' : 'Shares';
  String get costPrice => isZh ? '成本单价' : 'Cost price';
  String get saveFailed => isZh ? '保存失败' : 'Save failed';
  String get buy => isZh ? '买入' : 'Buy';
  String get sell => isZh ? '卖出' : 'Sell';
  String get updatePrice => isZh ? '更新价格' : 'Update price';
  String get deleteHolding => isZh ? '删除持仓' : 'Delete holding';
  String get deleteHoldingMessage => isZh
      ? '删除后该持仓不再计入市值与盈亏，历史已实现盈亏一并移除。'
      : 'After deletion the holding no longer counts toward value or P&L, and its realized P&L is removed too.';
  String holdingSubtitle(String shares, String cost) =>
      isZh ? '$shares 份 · 成本 $cost' : '$shares shares · cost $cost';
  String tradeTitle(String action, String name) => isZh ? '$action「$name」' : '$action "$name"';
  String currentHolding(String shares) => isZh ? '当前持有 $shares 份' : 'Currently holding $shares shares';
  String currentHoldingWithAvg(String shares, String avg) =>
      isZh ? '当前持有 $shares 份，均价 $avg' : 'Currently holding $shares shares, average $avg';
  String get sellPrice => isZh ? '卖价' : 'Sell price';
  String get buyPrice => isZh ? '买价' : 'Buy price';
  String get sellExceedsHolding => isZh ? '卖出份额超过持有量' : 'Sell amount exceeds holdings';
  String updatePriceTitle(String name) => isZh ? '更新价格「$name」' : 'Update price "$name"';
  String lastPriceUpdatedAt(String stamp) =>
      isZh ? '上次价格更新于 $stamp' : 'Last price updated $stamp';
  String get latestPrice => isZh ? '最新单价' : 'Latest price';
  String get updateFailed => isZh ? '更新失败' : 'Update failed';
  String get investmentNetValueLabel => isZh ? '账户净值（持仓市值 + 现金）' : 'Account value (holdings + cash)';
  String get marketValue => isZh ? '持仓市值' : 'Market value';
  String get cashBalance => isZh ? '现金余额' : 'Cash balance';
  String get unrealizedPnl => isZh ? '浮动盈亏' : 'Unrealized P&L';
  String holdingSummary(String type, String shares, String cost) =>
      isZh ? '$type · $shares 份 · 成本 $cost' : '$type · $shares shares · cost $cost';
  String get noPrice => isZh ? '未录入现价' : 'No current price';
  String get unpricedNote => isZh
      ? '有持仓还没录入现价，市值与浮动盈亏暂按 0 计。点持仓 → 更新价格即可。'
      : 'Some holdings have no current price, so value and P&L count as 0. Tap a holding → Update price.';
  String get priceNote => isZh
      ? '价格由手动录入并记录更新时间；本项目不接外部行情源，不会发起任何网络请求。'
      : 'Prices are entered manually with an update time; this app uses no market data source and makes no network requests.';

  // ─────────────────────── 贷款摊销（loan_page） ───────────────────────
  /// 空态的下一步：跳到账户页补全信息
  String get goToAccounts => isZh ? '去账户页补全' : 'Open accounts';
  String get loanAmortization => isZh ? '贷款摊销' : 'Loan amortization';
  String get accountNotFound => isZh ? '账户不存在' : 'Account not found';
  String get noLoanParams => isZh ? '还没有贷款参数' : 'No loan parameters yet';
  String get loanParamsHint =>
      isZh ? '在账户里补全本金、利率、期数与首次还款日' : 'Fill in principal, rate, term and first payment date in the account';
  String get remainingPrincipal => isZh ? '剩余本金' : 'Remaining principal';
  String get nextPayment => isZh ? '下期应还' : 'Next payment';
  String get paidPeriods => isZh ? '已还期数' : 'Paid periods';
  String get annualRate => isZh ? '年利率' : 'Annual rate';
  String get loanParams => isZh ? '贷款参数' : 'Loan details';
  String get totalInterest => isZh ? '利息总额' : 'Total interest';
  String get paidInterest => isZh ? '已还利息' : 'Paid interest';
  String repayProgress(String pct, int paid, int total) =>
      isZh ? '还款进度 $pct%（$paid / $total 期）' : 'Repayment progress $pct% ($paid / $total)';
  String get remainingOverview => isZh ? '剩余还款概况' : 'Remaining overview';
  String get remainingPeriods => isZh ? '剩余期数' : 'Remaining periods';
  String periodsCount(int n) => isZh ? '$n 期' : '$n periods';
  String get remainingInterest => isZh ? '剩余利息' : 'Remaining interest';
  String get expectedPayoff => isZh ? '预计还清' : 'Expected payoff';
  String get settled => isZh ? '已结清' : 'Settled';
  String get prepayCalc => isZh ? '提前还款测算' : 'Prepayment estimate';
  String get extraMonthly => isZh ? '每月额外还' : 'Extra monthly';
  String get lumpSum => isZh ? '一次性还本' : 'Lump sum';
  String get futureSchedule => isZh ? '未来还款计划' : 'Upcoming schedule';
  String get prepayPossible => isZh ? '可提前还清' : 'Can pay off early';
  String get fillAmountToCalc => isZh ? '填入金额后测算' : 'Enter an amount to estimate';
  String get baselinePeriods => isZh ? '基准剩余期数' : 'Baseline periods left';
  String get planPeriods => isZh ? '方案剩余期数' : 'With-plan periods left';
  String get interestSaved => isZh ? '少付利息' : 'Interest saved';
  String monthsCount(int n) => isZh ? '$n 个月' : '$n months';
  String periodNo(int i) => isZh ? '第 $i 期' : 'Period $i';
  String get loanSettledNoPeriods => isZh ? '贷款已结清，没有待还期数' : 'Loan settled — no periods left';
  String get colPeriod => isZh ? '期次' : 'Period';
  String get colPrincipal => isZh ? '本金' : 'Principal';
  String get colInterest => isZh ? '利息' : 'Interest';
  String get colRemaining => isZh ? '剩余余额' : 'Remaining balance';
  String get loanRepayNotePrefix => isZh ? '每期还款自动生成两笔账单：' : 'Each payment creates two entries: ';
  String get interestCountedInExpense => isZh ? '利息计入支出' : 'interest counts as expense';
  String get principalOnlyReducesDebtPart => isZh ? '，本金只减少负债、' : ', principal only reduces debt and ';
  String get notCountedAsExpense => isZh ? '不计入支出' : 'is not an expense';
  String get loanRepayNoteBody => isZh
      ? '这样你看到的是「这个月真的花了多少利息」， 而不是「我把本金挪了个地方也算花掉」。'
      : 'So you see how much interest you actually spent this month, not principal moved around counted as spend.';

  // ─────────────────────── 净值追踪（net_worth_page） ───────────────────────
  String get netWorthTracking => isZh ? '净值追踪' : 'Net worth tracking';
  String get debtOptimize => isZh ? '债务优化' : 'Debt optimizer';
  String get noAssetAccounts => isZh ? '还没有资产账户' : 'No asset accounts yet';
  String get noLiabilityAccounts => isZh ? '没有负债账户' : 'No liability accounts';
  String get netWorthTrend => isZh ? '净值走势 · 近 12 个月' : 'Net worth · last 12 months';
  String get noData => isZh ? '暂无数据' : 'No data';
  String get noDataYet => isZh ? '还没有数据' : 'No data yet';
  String get netWorthEmptyHint =>
      isZh ? '添加账户后这里会显示资产、负债与净值' : 'Add accounts to see assets, liabilities and net worth here';
  String accountEntriesCount(String name, int n) =>
      isZh ? '$name · $n 笔' : '$name · $n entries';
  String get noAccountEntries => isZh ? '该账户还没有流水' : 'No entries on this account yet';
  String get currentNetWorth => isZh ? '当前净值（资产 − 负债）' : 'Current net worth (assets − liabilities)';
  String get totalAssets => isZh ? '资产合计' : 'Total assets';
  String get totalLiabilities => isZh ? '负债合计' : 'Total liabilities';
  String originalValue(String amount) => isZh ? '原值 $amount' : 'Cost $amount';
  String get netWorthTrendNote =>
      isZh ? '走势的账户余额按交易日历回算，历史每个点都是可追溯的真实值。' : 'Trend account balances are replayed by the trading calendar; every point is a traceable real value.';
  String unpricedHoldingsNote(int n) =>
      isZh ? '有 $n 个投资账户的持仓未录入价格，市值暂按 0 计。' : '$n investment accounts have unpriced holdings; value counts as 0 for now.';
  String unconvertedRatesNote(String names) => isZh
      ? '$names 是外币账户，还没有设定「原币 → 本位币」的锁定汇率，'
          '因此未计入净值（账户余额本身不受影响，只算本位币口径）。'
          '在设置 → 记账 → 汇率锁定里填一次即可参与。'
      : '$names are foreign-currency accounts with no locked "original → base" rate, so they are excluded '
          'from net worth (account balances are unaffected; base currency only). Set it once under Settings → Ledger → Locked rates.';
  String skippedForeignDebtsNote(int n) => isZh
      ? '有 $n 个外币负债账户未计入净值'
          '（贷款本金是原币、流水是本位币，折算不出可信的剩余本金），'
          '这部分请手动核对维护。'
      : '$n foreign-currency liability accounts are excluded from net worth '
          '(principal is in foreign currency, entries in base currency, so remaining principal cannot be derived reliably). '
          'Please maintain them manually.';
  String get valuationNote =>
      isZh ? '固定资产使用估值估算值（原始成本并列展示），估值是纯估算，不改动任何账单。' : 'Fixed assets use an estimated value (cost shown alongside); estimates never change any entry.';
  String get holdingHistoryNote =>
      isZh ? '持仓没有历史价格，近 12 个月走势中持仓一律按当前市值计入，不代表当时市值。' : 'Holdings have no price history, so the last-12-month trend counts every point at current value, not the historical value.';

  // ─────────────────────── 债务优化（debt_optimize_page） ───────────────────────
  String get noDebtsToCalc => isZh ? '没有可测算的债务' : 'No debts to estimate';
  String get noDebtsHint =>
      isZh ? '有欠款的信用卡或贷款账户会出现在这里' : 'Credit cards or loans with debt will appear here';
  String incompleteDebtsHint(String names) => isZh
      ? '以下账户缺少年利率/最低还款：$names'
      : 'These accounts lack an annual rate / min payment: $names';
  String get extraMonthlyRepay => isZh ? '每月额外还款' : 'Extra monthly payment';
  String get extraBeyondMinLabel =>
      isZh ? '在最低还款之外，每月还能多还' : 'Beyond the minimum, you can also pay monthly';
  String debtsCount(int n) => isZh ? '参与测算的债务 · $n 笔' : 'Debts in estimate · $n';
  String incompleteNote(String names) => isZh
      ? '以下账户缺少年利率或最低还款，未参与测算：$names。在账户里补全后即可加入对比。'
      : 'These accounts lack an annual rate or min payment and are excluded: $names. Complete them in the account to join the comparison.';
  String foreignDebtsNote(String names) => isZh
      ? '以下外币负债未参与测算：$names。'
          '它们的本金是外币、流水记的是本位币，折算不出可信的剩余本金，'
          '请手动维护余额与还款计划。'
      : 'These foreign-currency liabilities are excluded: $names. '
          'Their principal is in foreign currency and entries in base currency, so a reliable remaining principal '
          'cannot be derived — please maintain balances and plans manually.';
  String get debtMethodNoteA => isZh
      ? '两种方法都是「每月预算固定 = Σ最低还款 + 额外还款」，某笔结清后它让出的最低还款自动滚向下一个目标。'
      : 'Both methods fix the monthly budget = Σ minimum payments + extra; when one is settled its minimum rolls to the next target.';
  String get debtMethodNoteB => isZh
      ? '雪球法优先清余额最小的（先看到成果），雪崩法优先清利率最高的（总利息更省）。'
      : 'Snowball clears the smallest balance first (quick wins); avalanche clears the highest rate first (less total interest).';
  String get debtMethodNoteC => isZh
      ? '当前未填额外还款：此时没有余钱可调度，两种方法的推进方式相同，要看出差异请填入额外还款。'
      : 'No extra payment entered: with no spare money the two methods behave the same — enter an extra amount to see the difference.';
  String get strategyCompare => isZh ? '两种策略对比' : 'Strategy comparison';
  String orderItem(String name, int month) => isZh ? '$name($month月)' : '$name(m$month)';
  String get cheaper => isZh ? '更省' : 'Cheaper';
  String settledSummary(int months, String interest) =>
      isZh ? '$months 个月还清 · 总利息 $interest' : 'Paid off in $months months · total interest $interest';
  String notSettledSummary(int months) =>
      isZh ? '月供不足以覆盖利息，$months 个月内未还清' : 'Payment does not cover interest — not settled within $months months';
  String orderLabel(String order) => isZh ? '结清顺序：$order' : 'Payoff order: $order';
  String debtRateLine(String rate, String minPayment) => isZh
      ? '年利率 $rate% · 最低还款 $minPayment'
      : 'Rate $rate% · min payment $minPayment';

  // ─────────────────────── 家庭与成员（family_page） ───────────────────────
  String get familyTitle => isZh ? '家庭与成员' : 'Family & Members';
  String get inviteMember => isZh ? '邀请成员' : 'Invite member';
  String get sharedLedgerGap => isZh
      ? '共享账本：多人共同记同一本账，数据实时互见。 —— 伙伴只是别人帮你记，不共享你的账本（G-5，两套边界不共用）。'
      : 'Shared ledger: several people keep the same ledger, seeing data live. — A partner only records for you and does not share your ledger (G-5, separate boundaries).';
  String get sharedLedgerPart => isZh ? '共享账本：多人共同记同一本账，数据实时互见。 ' : 'Shared ledger: several people keep the same ledger, seeing data live. ';
  String get differentFromPartner => isZh ? '与「记账伙伴」不同' : 'Different from a "recording partner"';
  String get partnerBoundaryPart =>
      isZh ? ' —— 伙伴只是别人帮你记，不共享你的账本（G-5，两套边界不共用）。' : ' — a partner only records for you and does not share your ledger (G-5, separate boundaries).';
  String get inviteCode => isZh ? '邀请码' : 'Invite code';
  String get localInviteCode => isZh ? '本机邀请码' : 'Local invite code';
  String get tapToGenerate => isZh ? '点右侧生成' : 'Tap the right to generate';
  String get copyInviteCode => isZh ? '复制邀请码' : 'Copy invite code';
  String get joinMember => isZh ? '加入成员' : 'Join member';
  String maxMembersHint(int n) => isZh ? '最多 $n 人（只数在册成员）' : 'Up to $n (active members only)';
  String get crossDeviceJoinNote => isZh
      ? '跨设备加入需要官方云同步（8.1）——当前邀请码用于线下告知家人，校验后在本机登记成员。'
      : 'Cross-device joining needs official cloud sync (8.1) — the current invite code is for telling family offline; on success the member is registered locally.';
  String membersPermsEyebrow(int active, int max) =>
      isZh ? '成员与权限 · $active/$max 人' : 'Members & permissions · $active/$max';
  String get noMemberRecords => isZh ? '还没有成员记录' : 'No member records yet';
  String get autoRegisterMeHint => isZh ? '下一次记账时会自动登记「我」。' : '"Me" is auto-registered on your next entry.';
  String get leftMembers => isZh ? '已退出成员' : 'Left members';
  String get leftMemberHint => isZh ? '历史账单归属保留、不占名额' : 'Historical attribution kept, does not count toward the quota';
  String get rolesGap => isZh
      ? '三种角色：（可增删成员、改权限、删除账本） / （可记账、可改自己的账） / （只能看）。'
      : 'Three roles: (add/remove members, change permissions, delete ledger) / (record, edit own entries) / (view only).';
  String get memberPrefsGap =>
      isZh ? '成员看到的分类与主题仍是，不会被账本同步覆盖。' : 'Members still see their own categories and themes; not overwritten by ledger sync.';
  String get rolesPrefix => isZh ? '三种角色：' : 'Three roles: ';
  String get ownerPermsPart => isZh ? '（可增删成员、改权限、删除账本） / ' : '(add/remove members, change permissions, delete ledger) / ';
  String get memberPermsPart => isZh ? '（可记账、可改自己的账） / ' : '(record, edit own entries) / ';
  String get viewerPermsPart => isZh ? '（只能看）。' : '(view only).';
  String get memberPrefsPrefix => isZh ? '成员看到的分类与主题仍是' : 'Members still see their own ';
  String get localPrefsBold => isZh ? '各自本机偏好' : 'local preferences';
  String get notOverriddenPart => isZh ? '，不会被账本同步覆盖。' : ', not overwritten by ledger sync.';
  String get me => isZh ? '我' : 'Me';
  String entriesCount(int n) => isZh ? '$n 笔' : '$n entries';
  String expenseWithAmount(String amount) => isZh ? '支出 ¥$amount' : 'Expense ¥$amount';
  String get noRecordsShort => isZh ? '暂无记录' : 'no records';
  String get memberActions => isZh ? '成员操作' : 'Member actions';
  String filteredByMember(String name) => isZh ? '已按「$name」筛选流水' : 'Filtered entries by "$name"';
  String roleSetTo(String role) => isZh ? '已设为「$role」' : 'Set to "$role"';
  String get setLeft => isZh ? '设为已退出' : 'Set as left';
  String get setLeftHint => isZh ? '记录保留、历史归属不变，但不再占名额' : 'Records and historical attribution stay, but it no longer counts toward the quota';
  String memberLeft(String name) => isZh ? '$name 已退出' : '$name has left';
  String get memberNameLabel => isZh ? '成员称呼' : 'Member name';
  String get join => isZh ? '加入' : 'Join';
  String joinedMember(String name) => isZh ? '已加入 $name' : 'Joined $name';
  String get inviteCodeCopied => isZh ? '邀请码已复制' : 'Invite code copied';
  String get inviteCodeGenFailed => isZh ? '邀请码生成失败' : 'Failed to generate invite code';
  String inviteCodeIs(String code) => isZh ? '邀请码：$code' : 'Invite code: $code';
  String maxMembers(int n) => isZh ? '最多 $n 人' : 'Up to $n';
  String get inviteCodeInvalid => isZh ? '邀请码不正确' : 'Invalid invite code';
  String get memberNameRequired => isZh ? '请填写成员称呼' : 'Enter the member name';
  String get memberNameTaken => isZh ? '已经有同名成员了' : 'A member with this name already exists';
  String get lastOwnerCannotLeave => isZh ? '最后一名所有者不能退出，请先转让' : 'The last owner cannot leave — transfer ownership first';
  String get cannotDeleteMe => isZh ? '「我」不能删除' : '"Me" cannot be deleted';
  String get cannotLeaveMe => isZh ? '「我」不能退出' : '"Me" cannot leave';
  String get operationFailedRetry => isZh ? '操作失败，请重试' : 'Operation failed, please retry';

  // ─────────────────────── 应用锁（app_lock_screen） ───────────────────────
  String get unlockApp => isZh ? '解锁素记' : 'Unlock SuJi';
  String failedAttemptsCount(int n, int max) =>
      isZh ? '失败次数: $n/$max' : 'Failed attempts: $n/$max';
  String get unlockWithBiometricOrPin =>
      isZh ? '使用生物识别或 PIN 解锁' : 'Unlock with biometrics or PIN';
  String get orEnterPin => isZh ? '或输入 PIN 码' : 'Or enter PIN';
  String get unlock => isZh ? '解锁' : 'Unlock';
  String get pinMinLength => isZh ? 'PIN 至少 4 位数字' : 'PIN needs at least 4 digits';
  String get pinMismatch => isZh ? '两次输入的 PIN 不一致' : 'The two PINs do not match';
  String get setupAppLock => isZh ? '设置应用锁' : 'Set up app lock';
  String get setupAppLockDesc => isZh
      ? '设置数字密码后才会开启应用锁。请牢记 PIN，忘记后只能清除应用数据。'
      : 'App lock turns on only after you set a numeric PIN. Remember it — if forgotten, the only option is to clear app data.';
  String get pinLabel => isZh ? 'PIN（4–6 位）' : 'PIN (4–6 digits)';
  String get confirmPin => isZh ? '确认 PIN' : 'Confirm PIN';
  String get enableBiometric => isZh ? '同时启用生物识别' : 'Also enable biometrics';
  String get enable => isZh ? '开启' : 'Enable';
}
