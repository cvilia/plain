/// Settings 模块 A 组（i18n-settings-a）文案。
///
/// 归属页面：savings_goals / category_manage / recurring / automation_rules /
/// home_layout / privacy_policy / action_log / onboarding / conflict_center / theme。
///
/// 约定：`app_strings.dart` 已有的 key（保存 / 取消 / 删除 / 分类 / 账户 …）直接复用；
/// `strings_domain.dart` 已定义的通用枚举 key（EntryType / CategoryKind / ConflictResolution
/// / EntityType 等）只引用不重复定义。
library;

import 'package:plain/app/l10n/app_strings.dart';

extension SettingsAStrings on AppStrings {
  // ── 通用小词（本组内多页复用） ──
  String get amountLabel => isZh ? '金额' : 'Amount';
  String get newAction => isZh ? '新建' : 'New';
  String get newRuleLabel => isZh ? '新建规则' : 'New rule';
  String get localPreference => isZh ? '本机偏好' : 'device preference';

  // ══════════════════════════ privacy_policy_page ══════════════════════════

  String get privacyTitle => isZh ? '素记 · 隐私承诺' : 'SuJi · Privacy Promise';
  String get privacyUpdatedAt => isZh ? '更新日期：2026-10' : 'Updated: 2026-10';

  List<(String, String)> get privacySections => [
        (
          isZh ? '无广告、无开屏、无金融导流' : 'No ads, no splash ads, no financial steering',
          isZh
              ? '素记不展示广告，没有开屏广告，也不会向你推荐贷款、理财等金融产品。'
              : 'SuJi shows no ads, has no splash ads, and never recommends loans, wealth products, or other financial products.',
        ),
        (
          isZh ? '数据默认本地' : 'Local by default',
          isZh
              ? '账单、分类、账户等数据默认只保存在你的设备上。未登录即可使用全部记账功能。'
              : 'Entries, categories, accounts and more are stored only on your device by default. All tracking features work without signing in.',
        ),
        (
          isZh ? '数据库加密' : 'Encrypted database',
          isZh
              ? '本地数据库使用 SQLCipher 全库加密，密钥保存在系统安全区（Keychain / Keystore），不上传、不同步密钥。'
              : 'The local database is fully encrypted with SQLCipher. The key stays in the system secure area (Keychain / Keystore) and is never uploaded or synced.',
        ),
        (
          isZh ? '不申请无关权限' : 'No unrelated permissions',
          isZh
              ? '只申请与功能直接相关的权限（如通知、相册）。短信自动记账等敏感能力为可选且需你主动开启。'
              : 'We only request permissions directly tied to a feature (e.g. notifications, photos). Sensitive capabilities such as SMS auto-tracking are optional and off unless you turn them on.',
        ),
        (
          isZh ? '不做用户画像' : 'No user profiling',
          isZh ? '不采集设备指纹用于广告画像，不把账单数据用于任何第三方分析或变现。' : 'We do not collect device fingerprints for ad profiling, and never use your ledger data for third-party analytics or monetization.',
        ),
        (
          isZh ? '备份与同步' : 'Backup & sync',
          isZh
              ? '备份文件由你自行保管或分享。云同步（若启用）只传输记账数据本身；主题与外观等本地偏好不同步。'
              : 'Backup files are kept or shared by you. Cloud sync (if enabled) transfers only the ledger data itself; local preferences like theme and appearance are not synced.',
        ),
        (
          isZh ? '你的数据你做主' : 'Your data, your call',
          isZh ? '支持导出与删除。卸载应用会删除本地数据；备份文件请自行妥善保存。' : 'Export and delete are supported. Uninstalling removes local data; please keep backup files safe yourself.',
        ),
      ];

  // ══════════════════════════ action_log_page ══════════════════════════

  String get actionLogTitle => isZh ? '操作日志' : 'Action Log';
  String get actionLogEntityRecurring => isZh ? '周期记账' : 'Recurring';
  String get actionLogOpInsert => isZh ? '新增' : 'Added';
  String get actionLogOpUpdate => isZh ? '修改' : 'Edited';
  String get actionLogEmptyTitle => isZh ? '暂无操作记录' : 'No actions yet';
  String get actionLogEmptySubtitle => isZh ? '记账、改分类等操作会记录在这里' : 'Recording entries, editing categories and more are logged here';

  // ══════════════════════════ onboarding_page ══════════════════════════

  String get onboardingWordmark => isZh ? '素记 Plain' : 'SuJi Plain';
  String get onboardingClaim => isZh ? '记账，三秒钟的事' : 'Tracking in three seconds';
  String get onboardingSub => isZh ? '本地存储 · 无广告 · 无理财' : 'Local · No ads · No finance';
  String get onboardingSampleBalance => isZh ? '本月结余' : 'This Month';
  String get onboardingFeature1Title => isZh ? '三秒记一笔' : 'Record in three seconds';
  String get onboardingFeature1Sub => isZh ? '只记数字，不填表格' : 'Just numbers, no forms';
  String get onboardingFeature2Title => isZh ? '数据只在你手机里' : 'Data stays on your phone';
  String get onboardingFeature2Sub => isZh ? '没有账号，没有服务器' : 'No account, no server';
  String get onboardingFeature3Title => isZh ? '十套配色，昼夜两态' : 'Ten palettes, day & night';
  String get onboardingFeature3Sub => isZh ? '冷底暖点，久看不累' : 'Cool base, warm accents — easy on the eyes';
  String get onboardingCta => isZh ? '开始记账' : 'Start tracking';
  String get onboardingFooter => isZh ? '数据全部本地存储 · 卸载前请先备份' : 'All data is stored locally · back up before uninstalling';

  // ══════════════════════════ theme_page ══════════════════════════

  String themeSwitched(String name) => isZh ? '已切换主题：$name' : 'Theme switched: $name';
  String get themeCountLabel => isZh ? '10 套主题' : '10 themes';
  String get themeAllFree => isZh ? '全部免费' : 'all free';
  String get themeNote1Suffix => isZh ? '，每套含浅色 / 深色两态，切换即时生效、无需重启。' : ', each with light / dark modes — switch instantly, no restart.';
  String get themeNote2Prefix => isZh ? '主题只改外观：分类色板与收入 / 支出语义色' : 'Themes only change appearance: the category palette and income / expense semantic colors';
  String get themeCrossFixed => isZh ? '跨主题固定' : 'stay fixed across themes';
  String get themeNote2Suffix => isZh ? '；主题属本机偏好，多端同步时不覆盖其他设备。' : '; themes are device preferences and never overwrite other devices when syncing.';

  // ══════════════════════════ home_layout_page ══════════════════════════

  String get homeLayoutTitle => isZh ? '首页卡片自定义' : 'Home Card Settings';
  String get homeLayoutNoteHintPlain => isZh ? '勾选要常驻首页的卡片。，长按可拖动排序。' : 'Check the cards to keep on the home screen.，long-press to reorder.';
  String get homeLayoutNoteHintA => isZh ? '勾选要常驻首页的卡片。' : 'Check the cards to keep on the home screen.';
  String get homeLayoutNoteHintB => isZh ? '至少保留 1 张、最多 4 张' : 'keep at least 1, up to 4';
  String get homeLayoutNoteHintC => isZh ? '，长按可拖动排序。' : ', long-press to reorder.';
  String homeLayoutOptionalCards(int n) => isZh ? '可选卡片 · 已选 $n / 4' : 'Available cards · $n / 4 selected';
  String get homeLayoutNoteLocalPlain => isZh ? '首页卡片顺序与开关属，多端同步时不覆盖其他设备。' : 'Card order and toggles are device preferences and never overwrite other devices when syncing.';
  String get homeLayoutNoteLocalA => isZh ? '首页卡片顺序与开关属' : 'Card order and toggles are';
  String get homeLayoutNoteLocalC => isZh ? '，多端同步时不覆盖其他设备。' : ' and never overwrite other devices when syncing.';

  String get homeLayoutCardMonthlyTitle => isZh ? '记账月结余' : 'Monthly Balance';
  String get homeLayoutCardMonthlySub => isZh ? '收入 / 支出 / 结余三数值' : 'Income / expense / balance';
  String get homeLayoutCardBudgetTitle => isZh ? '预算进度' : 'Budget Progress';
  String get homeLayoutCardBudgetSub => isZh ? '本月预算总进度条' : "This month's budget bar";
  String get homeLayoutCardSafeTitle => isZh ? '安全可花' : 'Safe to Spend';
  String get homeLayoutCardSafeSub => isZh ? '扣除预留后的日均可支配' : 'Daily spendable after reservations';
  String get homeLayoutCardGoalTitle => isZh ? '目标进度' : 'Goal Progress';
  String get homeLayoutCardGoalSub => isZh ? '最近一个储蓄目标的进度' : 'Progress of the most recent savings goal';
  String get homeLayoutCardNetTitle => isZh ? '净值' : 'Net Worth';
  String get homeLayoutCardNetSub => isZh ? '净资产与较上月变化' : 'Net assets vs last month';
  String get homeLayoutCardHeatTitle => isZh ? '近 7 天热力图' : 'Last 7 Days';
  String get homeLayoutCardHeatSub => isZh ? '按日消费强度色块' : 'Daily spending heatmap';

  // ══════════════════════════ conflict_center_page ══════════════════════════

  String get conflictCenterTitle => isZh ? '冲突中心' : 'Conflict Center';
  String get conflictEmptyTitle => isZh ? '没有待裁决的冲突' : 'No conflicts to resolve';
  String get conflictEmptySubtitle => isZh ? '两端改到同一个字段的不同值时，才会在这里出现。' : 'They appear here only when both sides changed the same field to different values.';
  String conflictBanner(int n) => isZh
      ? '共 $n 条待裁决。合并时默认取了「最后写入」的一版，下面可以改成另一版；选「都保留」会另存一笔冲突副本。'
      : '$n awaiting resolution. Merge kept the "last write" by default; you can switch below. Choosing "keep both" saves a conflict copy.';
  String conflictResolveFailed(String code) => isZh ? '裁决失败：$code' : 'Resolve failed: $code';
  String conflictResolved(String choice) => isZh ? '已$choice' : 'Done: $choice';
  String get conflictLocal => isZh ? '本机' : 'Local';
  String get conflictRemote => isZh ? '远端' : 'Remote';
  String get conflictKeepLocalAction => isZh ? '保留本机' : 'Keep local';
  String get conflictKeepRemoteAction => isZh ? '保留远端' : 'Keep remote';

  // ══════════════════════════ recurring_page ══════════════════════════

  String get recurringTitle => isZh ? '周期记账' : 'Recurring';
  String get recurringNewTitle => isZh ? '新建周期记账' : 'New Recurring Rule';
  String get recurringNewRuleTooltip => isZh ? '新建规则' : 'New rule';
  String get recurringRunDueTooltip => isZh ? '立即执行到期规则' : 'Run due rules now';
  String get recurringEmptyTitle => isZh ? '还没有周期记账' : 'No recurring rules yet';
  String get recurringEmptySubtitle => isZh ? '房租、订阅、工资都可以自动入账' : 'Rent, subscriptions and salary can post automatically';
  String get recurringNoDue => isZh ? '当前没有到期的周期记账' : 'No recurring entries are due';
  String get recurringPostedTitle => isZh ? '周期记账已入账' : 'Recurring entries posted';
  String recurringPostedBody(int n) => isZh ? '已自动生成 $n 笔账单' : '$n entries created automatically';
  String get recurringPendingTitle => isZh ? '周期记账待确认' : 'Recurring entries to confirm';
  String recurringPendingBody(int n) => isZh ? '有 $n 笔到期账单需要你确认入账' : '$n due entries need your confirmation';
  String recurringToastGenerated(int n) => isZh ? '已生成 $n 笔' : '$n created';
  String recurringToastPending(int n) => isZh ? '$n 笔待确认' : '$n to confirm';
  String get recurringSkipped => isZh ? '已跳过本期' : 'Skipped this period';
  String get recurringConfirmed => isZh ? '已确认入账' : 'Confirmed';
  String recurringOpFailed(String code) => isZh ? '操作失败: $code' : 'Operation failed: $code';
  String get recurringNothingToUndo => isZh ? '没有可撤销的账单' : 'Nothing to undo';
  String recurringUndone(int n) => isZh ? '已撤销 $n 笔账单' : 'Undid $n entries';
  String recurringPendingSuffix(String amount) => isZh ? '$amount · 待确认入账' : '$amount · awaiting confirmation';
  String get recurringConfirmAction => isZh ? '确认入账' : 'Confirm';
  String get recurringSkipAction => isZh ? '跳过本期' : 'Skip';
  String get recurringFinishedSuffix => isZh ? ' · 已结束' : ' · finished';
  String get recurringDisabledSuffix => isZh ? ' · 已停用' : ' · disabled';
  String get recurringUndoTooltip => isZh ? '撤销上次生成' : 'Undo last batch';

  String get recurringFreqDaily => isZh ? '每天' : 'Daily';
  String get recurringFreqWeekly => isZh ? '每周' : 'Weekly';
  String get recurringFreqMonthly => isZh ? '每月' : 'Monthly';
  String get recurringFreqYearly => isZh ? '每年' : 'Yearly';
  String recurringEveryDays(int n) => isZh ? '每 $n 天' : 'Every $n days';
  String recurringEveryWeeks(int n) => isZh ? '每 $n 周' : 'Every $n weeks';
  String recurringMonthlyOnDay(int n) => isZh ? '每月 $n 日' : 'Monthly on day $n';
  String get recurringEndNever => isZh ? '不结束' : 'Never';
  String get recurringEndCount => isZh ? '生成 N 次后结束' : 'After N times';

  String get recurringNameLabel => isZh ? '名称（可选）' : 'Name (optional)';
  String get recurringNameHint => isZh ? '如：房租' : 'e.g. Rent';
  String get recurringInvalidAmount => isZh ? '请输入有效金额' : 'Enter a valid amount';
  String get recurringTypeLabel => isZh ? '类型' : 'Type';
  String get recurringFrequencyLabel => isZh ? '频率' : 'Frequency';
  String get recurringAnchorLabel => isZh ? '锚定日（1–31）' : 'Anchor day (1–31)';
  String get recurringAnchorHelper => isZh ? '短月自动顺延到月末，如 31 日 → 2 月 28 日' : 'Short months roll to month-end, e.g. 31 → Feb 28';
  String get recurringAnchorInvalid => isZh ? '请输入 1–31' : 'Enter 1–31';
  String get recurringIntervalLabel => isZh ? '间隔天数' : 'Interval (days)';
  String get recurringAutoConfirmTitle => isZh ? '免确认直接入账' : 'Post without confirmation';
  String get recurringAutoConfirmSubtitle => isZh ? '关闭后生成的账单可在列表中手动确认' : 'When off, generated entries can be confirmed manually in the list';
  String get recurringEndLabel => isZh ? '结束条件' : 'End condition';
  String get recurringCountLabel => isZh ? '次数' : 'Times';
  String get recurringCountInvalid => isZh ? '请输入正整数' : 'Enter a positive integer';
  String get recurringSaving => isZh ? '保存中…' : 'Saving…';
  String get recurringSaveFailed => isZh ? '保存失败，请检查金额与规则' : 'Save failed — check the amount and rule';

  // ══════════════════════════ automation_rules_page ══════════════════════════

  String get automationTitle => isZh ? '自动规则' : 'Automation Rules';
  String get automationRuleEqPrefix => isZh ? '规则 = ' : 'Rule = ';
  String get automationCondIf => isZh ? '条件（IF）' : 'Condition (IF)';
  String get automationActionThen => isZh ? '动作（THEN）' : 'Action (THEN)';
  String get automationRuleEqSuffix => isZh ? '。一条账单可在保存时命中多条规则，按优先级顺序执行，后者可覆盖前者。' : '. An entry can match multiple rules on save; they run by priority and later ones override earlier ones.';
  String get automationHitLogNote => isZh ? '每次命中都会记入「规则执行日志」，可查看、可撤销。' : 'Every hit is logged in the rule run log — viewable and reversible.';
  String get automationEmptyTitle => isZh ? '还没有自动规则' : 'No automation rules yet';
  String get automationEmptySubtitle => isZh ? '例如「备注含房租 → 分类设为居住-房租」' : 'e.g. "note contains rent → set category to Housing/Rent"';
  String automationRuleCount(int n) => isZh ? '规则 · $n 条' : 'Rules · $n';
  String get automationStageNotePrefix => isZh ? '执行阶段：' : 'Run stage: ';
  String get automationStageBefore => isZh ? '保存前' : 'Before save';
  String get automationStageBetween => isZh ? '（可改写分类 / 账户） / ' : '(may rewrite category / account) / ';
  String get automationStageAfter => isZh ? '保存后' : 'After save';
  String get automationStageSuffix => isZh ? '（只做标记与通知）。' : '(marks and notifications only).';
  String get automationScopePrefix => isZh ? '改动仅作用于规则生效之后的新账单，' : 'Changes apply only to new entries after the rule takes effect,';
  String get automationScopeBold => isZh ? '不回改历史' : 'history is untouched';
  String get automationScopeSuffix => isZh ? '。' : '.';
  String get automationDeleteTitle => isZh ? '删除规则' : 'Delete Rule';
  String get automationDeleteMessage => isZh ? '确定删除该规则？不影响已记账单。' : 'Delete this rule? Existing entries are unaffected.';
  String get automationRuleFallback => isZh ? '规则' : 'Rule';
  String automationRuleIndexed(int i) => isZh ? '规则 $i' : 'Rule $i';
  String automationDryRunTitle(String name) => isZh ? '试运行 · $name' : 'Dry run · $name';
  String get automationDryRunEmpty => isZh ? '最近 100 笔中没有命中' : 'No matches in the last 100 entries';
  String get automationDryRunHint => isZh ? '仅预览，未修改数据' : 'Preview only — no data changed';
  String get automationCreateTitle => isZh ? '新建规则（备注 → 分类）' : 'New rule (note → category)';
  String get automationNoteKeyword => isZh ? '备注关键词' : 'Note keyword';
  String get automationTargetCategory => isZh ? '目标分类 ID（或名称，暂填 ID）' : 'Target category ID (or name; use ID for now)';
  String get automationPreviewCount => isZh ? '预览命中数（最近 500 笔）' : 'Preview matches (last 500)';
  String automationWillHit(int n) => isZh ? '将命中 $n 笔' : 'Will match $n';
  String get automationRetroTitle => isZh ? '回溯历史账单' : 'Apply to past entries';
  String get automationRetroSubtitleIdle => isZh ? '保存后套用到最近 500 笔（默认不回溯）' : 'Applies to the last 500 after saving (off by default)';
  String automationRetroSubtitle(int n) => isZh ? '将更新约 $n 笔历史账单' : 'Will update about $n past entries';
  String get automationSaveRule => isZh ? '保存规则' : 'Save Rule';
  String automationCreatedRetro(int n) => isZh ? '规则已创建，已回溯 $n 笔' : 'Rule created, $n entries retro-applied';
  String get automationCreated => isZh ? '规则已创建' : 'Rule created';
  String get automationNewRuleName => isZh ? '新规则' : 'New rule';

  String get ruleFieldMerchant => isZh ? '商户' : 'Merchant';
  String get ruleFieldType => isZh ? '类型' : 'Type';
  String get ruleAlwaysMatch => isZh ? '总是命中' : 'Always matches';
  String get ruleActionSetCategory => isZh ? '设分类' : 'Set category';
  String get ruleActionSetAccount => isZh ? '设账户' : 'Set account';
  String get ruleActionSetNotePrefix => isZh ? '备注前缀' : 'Note prefix';
  String get ruleActionSetNotInOutflow => isZh ? '不计入收支' : 'Exclude from flow';
  String get ruleActionSetReimbursable => isZh ? '待报销' : 'Reimbursable';

  String get matchContains => isZh ? '包含' : 'Contains';
  String get matchEquals => isZh ? '等于' : 'Equals';
  String get matchMethod => isZh ? '匹配方式' : 'Match method';

  // ══════════════════════════ category_manage_page ══════════════════════════

  String get categoryNewTooltip => isZh ? '新建分类' : 'New category';
  String get categorySearchHint => isZh ? '搜索分类名称' : 'Search category name';
  String get categoryClearSearch => isZh ? '清除搜索' : 'Clear search';
  String categoryNoMatch(String q) => isZh ? '没有匹配「$q」的分类' : 'No categories match "$q"';
  String get categoryPresetReadonly => isZh ? '默认分类不可修改' : 'Default categories cannot be edited';
  String get categoryRigidTitle => isZh ? '标记为刚性支出' : 'Mark as essential';
  String get categoryRigidSubtitle => isZh ? '房租、水电等固定必要支出，用于安全可花计算' : 'Fixed essentials like rent and utilities; used for safe-to-spend';
  String get categoryDeductibleTitle => isZh ? '标记为可抵扣' : 'Mark as deductible';
  String get categoryDeductibleSubtitle => isZh ? '自由职业者可抵扣的支出，税务报表按此汇总' : 'Deductible for freelancers; tax reports aggregate by this';
  String categoryAdded(String name) => isZh ? '已添加「$name」' : 'Added "$name"';
  String get categoryAddUnder => isZh ? '添加到分类下' : 'Add under a category';
  String get categoryAddUnderSub => isZh ? '在已有的一级分类下新增二级条目' : 'Add a subcategory under an existing top-level category';
  String get categoryNewRootSub => isZh ? '需同时录入至少一个二级条目' : 'Also requires at least one subcategory';
  String get categoryCreateRootFirst => isZh ? '请先新建一级分类' : 'Create a top-level category first';
  String get categoryAddSubTitle => isZh ? '添加二级分类' : 'Add Subcategory';
  String get categoryParentLabel => isZh ? '归属一级分类' : 'Parent category';
  String get categoryNameHintCoffee => isZh ? '如：咖啡' : 'e.g. Coffee';
  String get categoryAddAction => isZh ? '添加' : 'Add';
  String get categoryDeleteGroupTitle => isZh ? '删除分类组' : 'Delete Category Group';
  String get categoryDeleteTitle => isZh ? '删除分类' : 'Delete Category';
  String categoryDeleteScope(int n) => isZh ? '及其 $n 个下级分类' : 'and its $n subcategories';
  String categoryDeleteEntries(String name, String scope, int count, String fallback) => isZh
      ? '「$name」$scope下有 $count 笔账单。\n删除后账单将归入「$fallback」分类。'
      : '"$name" $scope has $count entries.\nThey will be moved to "$fallback" after deletion.';
  String categoryDeleteGroupConfirm(String name, int n) => isZh ? '将删除「$name」及其 $n 个下级分类。' : 'This will delete "$name" and its $n subcategories.';
  String categoryDeleteConfirm(String name) => isZh ? '确定删除「$name」？' : 'Delete "$name"?';
  String categoryDeletedMoved(int n, String fallback) => isZh ? '已删除，$n 笔账单归入「$fallback」' : 'Deleted, $n entries moved to "$fallback"';
  String categoryDeletedNamed(String name) => isZh ? '已删除「$name」' : 'Deleted "$name"';
  String categoryDeleteFailed(String code) => isZh ? '删除失败: $code' : 'Delete failed: $code';
  String categoryRootLabel(String name, String kind) => isZh ? '$name · $kind' : '$name · $kind';
  String get categoryRootNotMovable => isZh ? '一级分类不能移动' : 'Top-level categories cannot be moved';
  String get categoryNoMoveTarget => isZh ? '没有可移动到的一级分类' : 'No top-level category to move to';
  String categoryMoveToTitle(String name) => isZh ? '将「$name」移动到：' : 'Move "$name" to:';
  String get categoryNoMergeTarget => isZh ? '没有可合并的同级分类' : 'No same-level category to merge into';
  String categoryMergeToTitle(String name) => isZh ? '将「$name」合并到：' : 'Merge "$name" into:';
  String get categoryMergeTitle => isZh ? '合并分类' : 'Merge Categories';
  String get categoryMergeRootClause => isZh ? '，下级同名分类会并入目标同名项' : '; subcategories with the same name merge into the target';
  String categoryMergeMessage(String source, String target, int n,
          [String clause = '']) =>
      isZh
          ? '将「$source」合并到「$target」。\n涉及账单约 $n 笔将改归目标分类$clause。\n合并后不可撤销，确定继续？'
          : 'Merge "$source" into "$target".\nAbout $n entries will be reassigned to the target$clause.\nThis cannot be undone — continue?';
  String get categoryMergeAction => isZh ? '合并' : 'Merge';
  String categoryMerged(int n, String name) => isZh ? '已合并，$n 笔账单改归「$name」' : 'Merged, $n entries moved to "$name"';
  String categoryMergeFailed(String code) => isZh ? '合并失败: $code' : 'Merge failed: $code';
  String get categoryMoveTitle => isZh ? '移动分类' : 'Move Category';
  String categoryMoveConfirm(String source, String target) => isZh ? '将「$source」移动到「$target」下？' : 'Move "$source" under "$target"?';
  String get categoryMoveAction => isZh ? '移动' : 'Move';
  String categoryMoved(String name) => isZh ? '已移动到「$name」' : 'Moved to "$name"';
  String categoryMoveFailed(String code) => isZh ? '移动失败: $code' : 'Move failed: $code';
  String get categoryMoveMenu => isZh ? '移动到…' : 'Move to…';
  String get categoryMergeMenu => isZh ? '合并到…' : 'Merge into…';

  // ══════════════════════════ savings_goals_page ══════════════════════════

  String get goalSystemTitle => isZh ? '目标体系' : 'Goals';
  String get goalEmptyTitle => isZh ? '还没有目标' : 'No goals yet';
  String get goalEmptySubtitle => isZh ? '建一个储蓄目标攒钱、关联贷款做还债目标，或用限额目标控制某类开销' : 'Create a savings goal, link a loan for a debt goal, or use a limit goal to cap a spending category';
  String get goalNew => isZh ? '新建目标' : 'New Goal';
  String goalCount(int n) => isZh ? '目标 · $n 个' : 'Goals · $n';
  String goalForeignDebtNote(String names) => isZh
      ? '$names 关联的是外币贷款，未参与进度测算（本金外币、流水本位币对不上），请手动维护还款进度。'
      : '$names linked to foreign-currency loans are excluded from progress estimates (foreign principal vs. base-currency flows); please maintain repayment progress manually.';
  String goalLimitCount(int n) => isZh ? '限额目标 · $n 个' : 'Limit goals · $n';
  String get goalLimitEmptyNote => isZh
      ? '想控制某类开销（例如「本月餐饮 ≤ 2000」）就建一个限额目标。它的底层就是分类预算，和预算页看到的是同一份数据。'
      : 'To cap a spending category (e.g. "dining ≤ 2000 this month"), create a limit goal. It is backed by a category budget — the same data the budget page shows.';
  String get goalAddLimit => isZh ? '添加限额目标' : 'Add Limit Goal';
  String get goalLimitReuseNote => isZh ? '限额目标复用分类预算，不产生第二套数据；切换预算方法论时它照常生效。' : 'Limit goals reuse category budgets with no duplicate data; they keep working when you switch budget methodology.';
  String goalMonthlyLimitTitle(String name) => isZh ? '「$name」每月上限' : '"$name" monthly limit';
  String get goalNoExpenseCategory => isZh ? '还没有可用的支出分类' : 'No expense categories available yet';
  String goalSetFailed(String code) => isZh ? '设置失败：$code' : 'Set failed: $code';
  String get goalLimitDeleted => isZh ? '已删除限额目标' : 'Limit goal deleted';
  String goalUpdateFailed(String code) => isZh ? '修改失败：$code' : 'Update failed: $code';
  String get goalAccountRequired => isZh ? '请先给该目标关联一个账户' : 'Link an account to this goal first';
  String get goalDebtNoDeposit => isZh ? '还债目标通过还款推进，不能存入' : 'Debt goals progress via repayments — you cannot deposit';
  String goalDepositTitle(String name) => isZh ? '存入「$name」' : 'Deposit to "$name"';
  String get goalDeposited => isZh ? '已存入' : 'Deposited';
  String get goalDepositFailed => isZh ? '存入失败' : 'Deposit failed';
  String get goalNothingToTransfer => isZh ? '该目标已存满，无需划拨' : 'This goal is already full — no transfer needed';
  String get goalOpFailed => isZh ? '操作失败' : 'Operation failed';
  String get goalAutoOff => isZh ? '已关闭自动划拨' : 'Auto-transfer off';
  String get goalAutoOn => isZh ? '已开启自动划拨' : 'Auto-transfer on';
  String get goalLoanMissingParams => isZh ? '关联的贷款账户缺少参数，无法测算' : 'The linked loan account is missing parameters — cannot estimate';
  String goalPrepayTitle(String name) => isZh ? '提前还款测算「$name」' : 'Prepayment Estimate "$name"';
  String get goalExtraMonthly => isZh ? '每月额外还' : 'Extra monthly';
  String get goalLumpSum => isZh ? '一次性还本' : 'Lump-sum principal';
  String goalPrepayResult(int months, String amount) => isZh ? '可提前 $months 个月还清，少付利息 $amount' : 'Pay off $months months early, saving $amount in interest';
  String goalPrepayBaseline(int months, String amount) => isZh ? '基准剩余 $months 期、利息 $amount' : 'Baseline: $months periods left, $amount interest';
  String get goalCreateTitle => isZh ? '新建储蓄目标' : 'New Savings Goal';
  String get goalTargetAmount => isZh ? '目标金额' : 'Target amount';
  String get goalTypeLabel => isZh ? '目标类型' : 'Goal type';
  String get goalTypeDebt => isZh ? '还债目标' : 'Debt goal';
  String get goalTypeSavings => isZh ? '储蓄目标' : 'Savings goal';
  String get goalLinkLoan => isZh ? '关联贷款' : 'Linked loan';
  String get goalLinkAccount => isZh ? '关联账户' : 'Linked account';
  String get goalDueDate => isZh ? '截止日期' : 'Due date';
  String get goalCreated => isZh ? '目标已创建' : 'Goal created';
  String goalLimitOver(String amount) => isZh ? '已超支 ¥$amount' : 'Over by ¥$amount';
  String goalLimitRemaining(String amount, int pct) => isZh ? '剩余 ¥$amount · 已用 $pct%' : '¥$amount left · $pct% used';
  String get goalHeroSavedOfTarget => isZh ? '目标已存 / 目标总额' : 'Saved / Target';
  String get goalTotalProgress => isZh ? '总进度' : 'Overall progress';
  String get goalMonthlyNeed => isZh ? '月需存入' : 'Monthly need';
  String goalRemainingPct(int pct, String amount) => isZh ? '$pct% · 还差 $amount' : '$pct% · $amount to go';
  String goalMonthlySave(String amount) => isZh ? '月存 $amount' : 'Save $amount/mo';
  String get goalDepositAction => isZh ? '存入' : 'Deposit';
  String get goalAutoTransfer => isZh ? '自动按月划拨' : 'Auto monthly transfer';
  String get goalPrepayAction => isZh ? '提前还款测算' : 'Prepayment estimate';
  String get goalDebtSettled => isZh ? '已结清' : 'Settled';
  String goalDebtRemaining(int n, String interest, String payoff) => isZh ? '剩余 $n 期 · 剩余利息 $interest · 预计还清 $payoff' : '$n periods left · $interest interest left · payoff $payoff';
  String get goalLoanIncomplete => isZh ? '关联的贷款账户缺少本金/利率/期数，无法测算' : 'The linked loan account is missing principal/rate/term — cannot estimate';
  String get goalOverdue => isZh ? '未达成（截止日已过）' : 'Not reached (past due)';
  String get goalFundPlain => isZh ? '把「一年一次的大额支出」拆成月存（保险费、旅行、年检）， 避免某个月突然被击穿。' : 'Spread the "once-a-year big expenses" (insurance, travel, inspection) into monthly savings so no single month gets blindsided.';
  String get goalFundBold => isZh ? '沉淀基金' : 'Sinking fund';
  String get goalDeductPlain => isZh ? '目标里的钱 —— 否则你会以为自己很有钱。' : 'Money inside goals — otherwise you will think you are richer than you are.';
  String get goalDeductA => isZh ? '目标里的钱' : 'Money inside goals';
  String get goalDeductB => isZh ? '从「安全可花」基数中扣除' : 'is deducted from the safe-to-spend base';
  String get goalDeductC => isZh ? ' —— 否则你会以为自己很有钱。' : ' — otherwise you will think you are richer than you are.';
}
