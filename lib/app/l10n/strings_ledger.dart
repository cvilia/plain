/// Ledger feature UI strings（`lib/features/ledger/`）。
///
/// 归属：记账模块页面/控制器新增的文案。通用文案（保存 / 取消 / 删除 / 确定 /
/// 账户 / 分类 / 支出 / 收入 …）一律复用 [AppStrings]；枚举文案复用
/// `strings_domain.dart`，本文件不重复定义。
library;

import 'package:plain/app/l10n/app_strings.dart';

extension LedgerStrings on AppStrings {
  // ─────────────────────── entry_input_page.dart ───────────────────────

  String get ocrSheetTitle => isZh ? 'AI 识别记账' : 'AI recognition';
  String monthlyQuotaLabel(String label) => isZh ? '本月额度 $label' : 'Monthly quota $label';
  String get ocrDescription =>
      isZh ? '粘贴文字、截图或语音识别结果，自动预填金额和商户。' : 'Paste text, a screenshot, or speech — amount and merchant are pre-filled.';
  String get ocrInputHint => isZh ? '例如：星巴克 ¥128.50 2026-01-15' : 'e.g. Starbucks ¥128.50 2026-01-15';
  String quotaExhaustedRestore(int day) =>
      isZh ? '本月额度已用完，下月 $day 日恢复' : 'Quota used up; resets on day $day next month';
  String get ocrAmountNotFound => isZh ? '未能识别金额，请手动录入' : 'No amount recognized — please enter it manually';
  String get ocrPrefilled => isZh ? '已预填，请确认或修正' : 'Pre-filled — please confirm or fix';
  String get ocrRecognizeAction => isZh ? '识别并预填' : 'Recognize & fill';

  String foreignMissingRate(String currency) =>
      isZh ? '按 $currency 记账 · 未设汇率，请先到设置里锁定' : 'Recording in $currency · no rate set — lock it in Settings first';
  String foreignRecording(String currency, String rateText) =>
      isZh ? '按 $currency 记账$rateText' : 'Recording in $currency$rateText';
  String foreignRateInline(String currency, String rate) =>
      isZh ? ' · 1 $currency ≈ $rate' : ' · 1 $currency ≈ $rate';

  String get cannotCompute => isZh ? '无法计算' : 'Cannot compute';
  String get transferAccountsRequired => isZh ? '请选择转出与转入账户' : 'Select both source and destination accounts';
  String get fxRateRequired => isZh ? '请先设定该币种的汇率' : 'Set the exchange rate for this currency first';
  String get readOnlyNoPermission => isZh ? '你是「只读」成员，没有记账权限' : 'You are a read-only member and cannot edit the ledger';
  String get invalidInput => isZh ? '输入有误' : 'Invalid input';
  String get undone => isZh ? '已撤销' : 'Undone';
  String get categoryLoadFailed => isZh ? '分类加载失败' : 'Failed to load categories';

  String get borrowOutCounterparty => isZh ? '借出往来对象' : 'Lend counterparty';
  String get borrowInCounterparty => isZh ? '借入往来对象' : 'Borrow counterparty';
  String get counterpartyRequired => isZh ? '往来对象（必填）' : 'Counterparty (required)';
  String get counterpartyHint => isZh ? '如：张三' : 'e.g. John';
  String get saveImpactTitle => isZh ? '保存后的影响' : 'Impact after saving';
  String get thisAccount => isZh ? '本账户' : 'This account';
  String get counterpartyRowLabel => isZh ? '往来对象' : 'Counterparty';
  String get counterpartyRecordOnly => isZh ? '仅记录，不建账户' : 'Recorded only — no account created';
  String get increaseAction => isZh ? '增加' : 'increase';
  String get decreaseAction => isZh ? '减少' : 'decrease';
  String get statsAndBudget => isZh ? '收支与预算' : 'Income, expense & budget';
  String get notCounted => isZh ? '不计入' : 'Not counted';
  String get confirmBorrowOut => isZh ? '确认借出' : 'Confirm lend';
  String get confirmBorrowIn => isZh ? '确认借入' : 'Confirm borrow';

  String get transferAccountsTitle => isZh ? '转账账户' : 'Transfer accounts';
  String get fromAccountLabel => isZh ? '转出账户' : 'From account';
  String get toAccountLabel => isZh ? '转入账户' : 'To account';
  String get unchanged => isZh ? '不变' : 'unchanged';
  String get transferNotePlain =>
      isZh ? '涉及的记账不走「点分类即保存」，需要显式确认（G-6）。' : 'These entries do not use "tap category to save" — explicit confirmation is required (G-6).';
  String get transferNotePrefix => isZh ? '涉及' : 'Entries involving ';
  String get transferNoteBold => isZh ? '两个账户' : 'two accounts';
  String get transferNoteSuffix =>
      isZh ? '的记账不走「点分类即保存」，需要显式确认（G-6）。' : ' do not use "tap category to save" — explicit confirmation is required (G-6).';
  String get transferExplanation => isZh
      ? '转账只是钱换了地方 —— 计入收支会让你的「支出」凭空翻倍（G-2）。'
      : 'A transfer just moves money — counting it as income/expense would double your totals (G-2).';
  String get confirmTransfer => isZh ? '确认转账' : 'Confirm transfer';

  String get selectedValue => isZh ? '已选择' : 'Selected';
  String get selectFromAccount => isZh ? '选择转出' : 'Pick source';
  String get selectToAccount => isZh ? '选择转入' : 'Pick destination';
  String get addNote => isZh ? '添加备注' : 'Add note';
  String get countedInStats => isZh ? '计入收支' : 'Include in income/expense';
  String get notCountedInStats => isZh ? '不计入收支' : 'Exclude from income/expense';
  String get reimburseFieldTitle => isZh ? '报销' : 'Reimbursement';
  String get includeInStatsTitle => isZh ? '是否计入收支' : 'Include in income/expense?';
  String get selectAccountTitle => isZh ? '选择账户' : 'Select account';
  String get selectToAccountTitle => isZh ? '选择转入账户' : 'Select destination account';
  String get noAccountSpecified => isZh ? '不指定账户' : 'No account';

  // ─────────────────────── flow_list_page.dart ───────────────────────

  String get searchOrFilter => isZh ? '搜索 / 筛选' : 'Search / Filter';
  String filteredBy(String name) => isZh ? '已筛选：$name' : 'Filtered: $name';
  String get thisCategory => isZh ? '该分类' : 'this category';
  String get showAll => isZh ? '显示全部' : 'Show all';
  String get flowLoadFailed => isZh ? '流水加载失败' : 'Failed to load flow';
  String flowLoadFailedSubtitle(String code) =>
      isZh ? '数据还在本机，重试一下就好（$code）' : 'Data is still on this device — just retry ($code)';
  String get thisMonthBalance => isZh ? '本月结余' : 'This month balance';
  String monthStartNote(int day) => isZh ? '记账月起始：$day 日' : 'Month starts on day $day';
  String get deleteFailed => isZh ? '删除失败' : 'Delete failed';

  // ─────────────────────── safe_to_spend_card.dart ───────────────────────

  String get todaySpendable => isZh ? '今日可花' : 'Safe to spend today';
  String get dailyAverage => isZh ? '日均' : 'Daily avg';
  String remainingDays(int n) => isZh ? '剩 $n 天' : '$n days left';
  String get overspentThisMonth => isZh ? '本月已超支，建议暂停非必要支出' : 'Over budget this month — consider pausing non-essential spending';
  String get availableFunds => isZh ? '可用资金' : 'Available funds';
  String get futureBillsReserved => isZh ? '未来账单预留' : 'Reserved for future bills';
  String get goalPendingAllocation => isZh ? '目标待拨付' : 'Goals pending allocation';
  String get rigidReserved => isZh ? '刚性支出预留' : 'Reserved for fixed costs';
  String get collapseDetails => isZh ? '收起明细' : 'Collapse details';
  String get expandDetails => isZh ? '展开明细' : 'Expand details';

  // ─────────────────────── home_shell.dart ───────────────────────

  String get navMine => isZh ? '我的' : 'Mine';

  // ─────────────────────── advanced_filter_page.dart ───────────────────────

  String get advancedFilterTitle => isZh ? '高级筛选' : 'Advanced filter';
  String get exportCsv => isZh ? '导出 CSV' : 'Export CSV';
  String get clearAllAction => isZh ? '清空' : 'Clear';
  String get filterTypeLabel => isZh ? '类型' : 'Type';
  String get minAmountLabel => isZh ? '最低' : 'Min';
  String get maxAmountLabel => isZh ? '最高' : 'Max';
  String get keywordLabel => isZh ? '关键词' : 'Keyword';
  String get keywordHint => isZh ? '备注 / 分类名' : 'Note / category name';
  String get timeRangeLabel => isZh ? '时间范围' : 'Date range';
  String get startDateLabel => isZh ? '开始' : 'Start';
  String get endDateLabel => isZh ? '结束' : 'End';
  String get applyFilter => isZh ? '应用筛选' : 'Apply filter';
  String resultCount(int n) => isZh ? '结果 $n 条' : '$n results';
  String get noMatchingEntries => isZh ? '没有符合条件的账单' : 'No matching entries';
  String get tryAdjustingFilter => isZh ? '试试调整筛选条件' : 'Try adjusting the filters';
  String get allCategoriesOption => isZh ? '全部分类' : 'All categories';
  String get selectDateHint => isZh ? '选择日期' : 'Select date';
  String get csvExportHeader => isZh ? '日期,类型,分类,金额,备注\n' : 'Date,Type,Category,Amount,Note\n';
  String exportSubject(int n) => isZh ? '筛选结果 $n 条' : '$n filter results';

  // ─────────────────────── split_editor_page.dart ───────────────────────

  String get splitDemoTitle1 => isZh ? '餐饮 · 午餐' : 'Dining · Lunch';
  String get splitDemoSub1 => isZh ? '工作餐' : 'Work meal';
  String get splitDemoTitle2 => isZh ? '人情 · 请客' : 'Social · Treat';
  String get splitDemoSub2 => isZh ? '招待同事' : 'Treating colleagues';
  String get splitNewChildTitle => isZh ? '新子项' : 'New item';
  String get splitNewChildSub => isZh ? '待填写' : 'To fill';
  String childCountLabel(int n) => isZh ? '子项（$n）' : 'Items ($n)';
  String get splitThisEntry => isZh ? '分割这笔账单' : 'Split this entry';
  String get originalAmountLabel => isZh ? '账单原始金额' : 'Original amount';
  String get assignedAmountLabel => isZh ? '已分配' : 'Assigned';
  String get splitBalancedOk => isZh ? '已对平，可以保存' : 'Balanced — ready to save';
  String splitShortBy(String amount) => isZh ? '还差 ¥$amount' : '¥$amount short';
  String splitOverBy(String amount) => isZh ? '超出 ¥$amount' : '¥$amount over';
  String get splitNoteParentChild =>
      isZh ? '父子结构：父单不被删除，子项独立统计。父单金额。' : 'Parent/child: the parent is kept, children are counted separately. Parent amount';
  String get splitNoteBold =>
      isZh ? '恒等于 Σ 子项金额' : 'always equals the sum of child amounts';
  String get splitNoteAnchorParentAmount => isZh ? '父单金额' : 'Parent amount';
  String get splitNoteReport => isZh
      ? '报表中各子项按自己的分类计数，父单、不参与分类统计 （避免双算）；父单只计入账户余额一次。'
      : 'In reports each child counts under its own category, while the parent ';
  String get splitNoteBold2 => isZh ? '分类置空' : 'has no category';
  String get splitNoteAnchorParent => isZh ? '父单' : 'parent';
  String get addChildLine => isZh ? '再分一项' : 'Add another item';

  // ─────────────────────── category_picker_page.dart ───────────────────────

  String get searchCategoryHint => isZh ? '搜索分类...' : 'Search categories...';
  String get noCategories => isZh ? '暂无分类' : 'No categories yet';
  String get noMatchingCategory => isZh ? '未找到匹配分类' : 'No matching category';
  String get addUnderCategory => isZh ? '添加到分类下' : 'Add under a category';
  String get addUnderCategoryDesc =>
      isZh ? '在已有的一级分类下新增二级条目' : 'Add a subcategory under an existing top-level category';
  String get rootNeedLeafDesc => isZh ? '需同时录入至少一个二级条目' : 'At least one subcategory is required';
  String get noRootCategoryHint =>
      isZh ? '暂无一级分类，可用「新建一级分类」创建' : 'No top-level category yet — create one with "New top-level category"';
  String get newCategoryEntryTitle => isZh ? '新增分类条目' : 'New category item';
  String get parentCategoryLabel => isZh ? '归属一级分类' : 'Top-level category';
  String get notSelectedValue => isZh ? '未选择' : 'Not selected';
  String get nameFieldLabel => isZh ? '名称' : 'Name';
  String get nameFieldHint => isZh ? '如：咖啡' : 'e.g. Coffee';
  String get noteOptionalLabel => isZh ? '备注（可选）' : 'Note (optional)';
  String get addAndSelect => isZh ? '添加并选用' : 'Add & use';
  String get createAndSelect => isZh ? '创建并选用' : 'Create & use';

  /// 保存成功 toast：`已记 ¥12.00`
  String savedAmount(String amount) => isZh ? '已记 ¥$amount' : 'Saved ¥$amount';

  /// 保存成功 toast（表达式不完整，按前缀处理）
  String savedAmountPrefix(String amount) =>
      isZh ? '已记 ¥$amount（前缀）' : 'Saved ¥$amount (prefix)';

  String get addAction => isZh ? '添加' : 'Add';
  // ─────────────────────── entry_participants_row.dart ───────────────────────

  String get whoSpentTogether => isZh ? '谁一起花的' : 'Who shared this';
  String splitEquallyPrompt(String amount) =>
      isZh ? '选中的每个人平均分摊（共 ¥$amount）' : 'Split equally among those selected (¥$amount total)';
  String get participantsUpdated => isZh ? '已更新参与人' : 'Participants updated';
  String get notMarked => isZh ? '未标记' : 'Not marked';
  String eachPersonShare(String amount) => isZh ? ' · 每人 ¥$amount' : ' · ¥$amount each';
  String get participantsRowLabel => isZh ? '参与分摊' : 'Participants';

  // ─────────────────────── entry_detail_page.dart ───────────────────────

  String get entryDetailTitle => isZh ? '账单详情' : 'Entry detail';
  String get amountFieldLabel => isZh ? '金额' : 'Amount';
  String get originalAmountFieldLabel => isZh ? '原币金额' : 'Original amount';
  String get lockedRateLabel => isZh ? '锁定汇率' : 'Locked rate';
  String get reimburseRowLabel => isZh ? '报销' : 'Reimbursement';
  String get statsRowLabel => isZh ? '收支' : 'Income/expense';
  String get splitRowLabel => isZh ? '分割' : 'Split';
  String get splitParentValue => isZh ? '父笔（不进分类统计）' : 'Parent (excluded from category totals)';
  String get splitChildValue => isZh ? '子笔' : 'Child';
  String splitSheetTitle(String amount) => isZh ? '拆分 $amount（合计需对平）' : 'Split $amount (must balance)';
  String childAmountFieldLabel(int n) => isZh ? '子笔 $n 金额' : 'Child $n amount';
  String get categoryIdFieldLabel => isZh ? '分类 ID' : 'Category ID';
  String get addChildAction => isZh ? '加子笔' : 'Add child';
  String get splitDone => isZh ? '已拆分' : 'Split done';
  String splitFailed(String code) => isZh ? '拆分失败: $code' : 'Split failed: $code';
  String get saveSplitAction => isZh ? '保存拆分' : 'Save split';
  String get mergeDone => isZh ? '已合并回父笔，请补充分类' : 'Merged back into parent — please add a category';
  String mergeFailed(String code) => isZh ? '合并失败: $code' : 'Merge failed: $code';
  String get deleteThisEntry => isZh ? '删除这笔账单' : 'Delete this entry';
  String get deleteTrashContent => isZh ? '删除后可在回收站恢复（保留 30 天）。' : 'Moved to Trash — restorable for 30 days.';
  String get mergeBackParent => isZh ? '合并回父笔' : 'Merge into parent';
  String get splitActionLabel => isZh ? '拆分这笔账单' : 'Split this entry';
  String get sourceManual => isZh ? '手动录入' : 'Manual';
  String get sourceImport => isZh ? '导入' : 'Import';
  String get sourceRecurring => isZh ? '周期' : 'Recurring';
}
