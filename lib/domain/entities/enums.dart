/// Domain enums. See 08-4.4, 7.7.
library;

/// Shared `fromWire` lookup for wire-serialized enums.
T wireEnumFrom<T>(String? v, List<T> values, T fallback, String Function(T) wireOf) {
  for (final e in values) {
    if (wireOf(e) == v) return e;
  }
  return fallback;
}

enum EntryType {
  expense('expense'), income('income'), transfer('transfer'),
  borrowOut('borrow_out'), borrowIn('borrow_in'), repayCredit('repay_credit'),
  unknown('unknown');

  const EntryType(this.wire);
  final String wire;
  static EntryType fromWire(String? v) =>
      wireEnumFrom(v, values, EntryType.unknown, (e) => e.wire);

  bool get countsInOutflow => this == EntryType.expense || this == EntryType.income;
  bool get enabledInV1 =>
      this == EntryType.expense ||
      this == EntryType.income ||
      this == EntryType.transfer ||
      // V2.0 交易类型化（STORY-1.7）
      this == EntryType.borrowOut ||
      this == EntryType.borrowIn ||
      this == EntryType.repayCredit;
}

enum EntrySource {
  manual('manual'), reconcile('reconcile'), import('import'),
  recurring('recurring'), ocr('ocr'), ai('ai'), unknown('unknown');

  const EntrySource(this.wire);
  final String wire;
  static EntrySource fromWire(String? v) =>
      wireEnumFrom(v, values, EntrySource.unknown, (e) => e.wire);
}

/// STORY-6.2 分割交易角色。
enum SplitRole {
  normal('normal'),
  parent('parent'),
  child('child');

  const SplitRole(this.wire);
  final String wire;
  static SplitRole fromWire(String? v) =>
      wireEnumFrom(v, values, SplitRole.normal, (e) => e.wire);
}

/// STORY-1.8 报销状态机。
enum ReimburseStatus {
  none('none'),
  pending('pending'),
  submitted('submitted'),
  partial('partial'),
  reimbursed('reimbursed'),
  abandoned('abandoned');

  const ReimburseStatus(this.wire);
  final String wire;
  static ReimburseStatus fromWire(String? v) =>
      wireEnumFrom(v, values, ReimburseStatus.none, (e) => e.wire);

  bool get inFlow => this != ReimburseStatus.none && this != ReimburseStatus.abandoned;
}

enum AccountType {
  cash('cash'), debit('debit'), credit('credit'),
  loanOut('loan_out'), loanIn('loan_in'), investment('investment'),
  /// STORY-7.1：储蓄/沉淀目标的**虚拟账户**——存款划拨的转入端。
  /// 不是用户可创建的账户类型（不在 [enabledInV1] 内），由目标创建时自动生成。
  goal('goal'),
  unknown('unknown');

  const AccountType(this.wire);
  final String wire;
  static AccountType fromWire(String? v) =>
      wireEnumFrom(v, values, AccountType.unknown, (e) => e.wire);

  bool get enabledInV1 =>
    this == AccountType.cash ||
    this == AccountType.debit ||
    this == AccountType.credit ||
    this == AccountType.investment;

  /// 目标虚拟账户只承载「已预留金额」，不参与收支，也不该出现在可选账户列表里。
  bool get isVirtual => this == AccountType.goal;
}

enum CategoryKind {
  expense('expense'), income('income'), transfer('transfer'), unknown('unknown');

  const CategoryKind(this.wire);
  final String wire;
  static CategoryKind fromWire(String? v) =>
      wireEnumFrom(v, values, CategoryKind.unknown, (e) => e.wire);
}

enum ChangeOp {
  insert('insert'), update('update'), delete('delete'), unknown('unknown');

  const ChangeOp(this.wire);
  final String wire;
  static ChangeOp fromWire(String? v) =>
      wireEnumFrom(v, values, ChangeOp.unknown, (e) => e.wire);
}

enum EntityType {
  transaction('transaction'), category('category'), account('account'),
  budget('budget'), recurringRule('recurring_rule'), automationRule('rule'),
  savingsGoal('savings_goal'), holding('holding'),
  savedReport('saved_report'), taxFiling('tax_filing'),
  merchantRule('merchant_rule'), member('member'),
  /// STORY-9.3：用户手填的锁定汇率（`currency_rates`）。它是账本数据
  /// （换设备要按同一汇率折算），所以进同步范围。
  currencyRate('currency_rate'),
  /// STORY-1.5 / 8.1 AC6：附件只同步**元数据**（字节不出设备），
  /// 对端据此把附件标为「未同步（仅在原设备）」。
  attachment('attachment'),
  /// STORY-8.1：可同步设置（月起始日等）。键在 `sync_scope.kSyncedSettingKeys` 白名单内。
  setting('setting'),
  /// STORY-8.2：AA 分摊参与人。**整组替换**语义（先删旧再插新），
  /// 因此删与插都要写日志，否则对端会攒出重复参与人。
  entryParticipant('entry_participant'),
  unknown('unknown');

  const EntityType(this.wire);
  final String wire;
  static EntityType fromWire(String? v) =>
      wireEnumFrom(v, values, EntityType.unknown, (e) => e.wire);
}

enum BudgetScope {
  total('total'), category('category'), unknown('unknown');

  const BudgetScope(this.wire);
  final String wire;
  static BudgetScope fromWire(String? v) =>
      wireEnumFrom(v, values, BudgetScope.unknown, (e) => e.wire);
}

enum BudgetPeriod {
  monthly('monthly'), unknown('unknown');

  const BudgetPeriod(this.wire);
  final String wire;
  static BudgetPeriod fromWire(String? v) =>
      wireEnumFrom(v, values, BudgetPeriod.unknown, (e) => e.wire);
}

enum BudgetLevel { ok, warn, over }

enum RecurringFrequency {
  daily('daily'), weekly('weekly'), monthly('monthly'),
  yearly('yearly'), interval('interval'), unknown('unknown');

  const RecurringFrequency(this.wire);
  final String wire;
  static RecurringFrequency fromWire(String? v) =>
      wireEnumFrom(v, values, RecurringFrequency.unknown, (e) => e.wire);
}

enum RecurringEndType {
  never('never'), until('until'), count('count'), unknown('unknown');

  const RecurringEndType(this.wire);
  final String wire;
  static RecurringEndType fromWire(String? v) =>
      wireEnumFrom(v, values, RecurringEndType.unknown, (e) => e.wire);
}

/// STORY-7.3：周期规则的**生成来源类型**。
///
/// 全产品只有一套周期调度器，三类「自动生成账单」都走它，用本字段区分：
/// 普通周期记账 / 储蓄目标自动划拨 / 贷款每期还款。禁止为它们各建一套机制。
enum RecurringKind {
  recurring('recurring'),
  savingsTransfer('savings_transfer'),
  loanRepayment('loan_repayment');

  const RecurringKind(this.wire);
  final String wire;
  static RecurringKind fromWire(String? v) =>
      wireEnumFrom(v, values, RecurringKind.recurring, (e) => e.wire);
}

/// STORY-10.3 资产估值模式。
///
/// 折旧/增值是**纯估算**：只影响资产总览的展示值，**不改动任何账单记录**。
enum AssetValuationMode {
  /// 不估值（默认）：账户按派生余额计入。
  none('none'),

  /// 固定值：始终等于用户设定的固定金额。
  fixed('fixed'),

  /// 年折旧率：按持有月数复利递减。
  depreciate('depreciate'),

  /// 年增值率：按持有月数复利递增。
  appreciate('appreciate'),

  /// 手动调整：等于用户手填的当前估值。
  manual('manual');

  const AssetValuationMode(this.wire);
  final String wire;
  static AssetValuationMode fromWire(String? v) =>
      wireEnumFrom(v, values, AssetValuationMode.none, (e) => e.wire);

  bool get isActive => this != AssetValuationMode.none;

  String get label => switch (this) {
        AssetValuationMode.none => '不估值',
        AssetValuationMode.fixed => '固定值',
        AssetValuationMode.depreciate => '年折旧率',
        AssetValuationMode.appreciate => '年增值率',
        AssetValuationMode.manual => '手动调整',
      };
}

/// STORY-10.1 投资持仓的资产类型。
enum AssetType {
  stock('stock'), fund('fund'), bond('bond'),
  crypto('crypto'), other('other');

  const AssetType(this.wire);
  final String wire;
  static AssetType fromWire(String? v) =>
      wireEnumFrom(v, values, AssetType.other, (e) => e.wire);

  String get label => switch (this) {
        AssetType.stock => '股票',
        AssetType.fund => '基金',
        AssetType.bond => '债券',
        AssetType.crypto => '加密',
        AssetType.other => '其他',
      };
}

/// STORY-11.1 预算方法论。
///
/// 预算引擎分为「方法论层 + 执行层」。切换方法论**不改历史数据**，
/// 只改变预算页的呈现与校验规则；底层的分类预算（= 限额目标）四套下都继续生效。
enum BudgetMethodology {
  /// 当前的总预算 + 分类预算（默认）。
  custom('custom', '分类限额'),

  /// 每类一个信封，独立滚存，超支不许跨类挪用。
  envelope('envelope', '信封预算'),

  /// 收入逐项分配至「归零」，未分配金额必须为 0。
  zeroBased('zero_based', '零基预算'),

  /// 按需 / 想要 / 储蓄三档比例。
  fiftyThirtyTwenty('fifty_thirty_twenty', '50-30-20');

  const BudgetMethodology(this.wire, this.label);
  final String wire;
  final String label;

  static BudgetMethodology fromWire(String? v) =>
      wireEnumFrom(v, values, BudgetMethodology.custom, (e) => e.wire);
}

/// 50/30/20 的三档。
enum RatioBucketKind {
  needs('needs', '需要'),
  wants('wants', '想要'),
  savings('savings', '储蓄');

  const RatioBucketKind(this.wire, this.label);
  final String wire;
  final String label;
}

/// STORY-11.5 申报周期的粒度。
enum TaxPeriodKind {
  month('month', '记账月'),
  year('year', '年度');

  const TaxPeriodKind(this.wire, this.label);
  final String wire;
  final String label;
  static TaxPeriodKind fromWire(String? v) =>
      wireEnumFrom(v, values, TaxPeriodKind.month, (e) => e.wire);
}

/// STORY-11.3 保存的报表里，账单类型的过滤口径。
enum ReportEntryFilter {
  all('all', '全部'),
  expense('expense', '只看支出'),
  income('income', '只看收入');

  const ReportEntryFilter(this.wire, this.label);
  final String wire;
  final String label;
  static ReportEntryFilter fromWire(String? v) =>
      wireEnumFrom(v, values, ReportEntryFilter.expense, (e) => e.wire);
}

/// STORY-11.3 交叉分析的可选维度。
///
/// 只列**当前真有数据**的维度：标签与成员在本项目没有对应实体
/// （无 tags / members 表），不列出以免做出空壳。「商户」沿用既有口径
/// ——用备注承载（见 `rule_engine.dart` 的 `RuleField.merchant`）。
enum CrossDimension {
  category('category', '分类'),
  account('account', '账户'),
  month('month', '月份'),
  merchant('merchant', '商户'),
  amountRange('amount_range', '金额区间');

  const CrossDimension(this.wire, this.label);
  final String wire;
  final String label;
  static CrossDimension fromWire(String? v) =>
      wireEnumFrom(v, values, CrossDimension.category, (e) => e.wire);
}

/// STORY-10.2 贷款还款方式。
enum LoanRepayMethod {
  /// 等额本息：每期还款额一致，前期利息占比高。
  equalInstallment('equal_installment'),

  /// 等额本金：每期本金一致，利息逐期递减，总利息更少。
  equalPrincipal('equal_principal'),

  unknown('unknown');

  const LoanRepayMethod(this.wire);
  final String wire;
  static LoanRepayMethod fromWire(String? v) =>
      wireEnumFrom(v, values, LoanRepayMethod.unknown, (e) => e.wire);

  String get label => switch (this) {
        LoanRepayMethod.equalInstallment => '等额本息',
        LoanRepayMethod.equalPrincipal => '等额本金',
        LoanRepayMethod.unknown => '未设置',
      };
}

/// How to handle months without the anchor day (e.g. 31 in February).
enum RecurringSkipStrategy {  /// Clamp to last day of month (31 → 28/29). PRD F6.1 default.
  clamp('clamp'),
  /// Skip the month entirely.
  skip('skip'),
  unknown('unknown');

  const RecurringSkipStrategy(this.wire);
  final String wire;
  static RecurringSkipStrategy fromWire(String? v) =>
      wireEnumFrom(v, values, RecurringSkipStrategy.unknown, (e) => e.wire);
}

/// STORY-8.2 / G-5：家庭账本角色（所有者 / 成员 / 只读）。
enum MemberRole {
  owner('owner'),
  member('member'),
  viewer('viewer');

  const MemberRole(this.wire);
  final String wire;

  static MemberRole fromWire(String? v) =>
      wireEnumFrom(v, values, MemberRole.member, (e) => e.wire);

  String get label => switch (this) {
        MemberRole.owner => '所有者',
        MemberRole.member => '成员',
        MemberRole.viewer => '只读',
      };

  /// 能否记账（AC2：只读成员保存时被拦）。
  bool get canWrite => this != MemberRole.viewer;

  /// 能否管理成员与权限（仅所有者）。
  bool get canManageMembers => this == MemberRole.owner;
}

/// STORY-8.2：成员状态。**软删除**——退出后记录保留、不占 6 人名额（AC4）。
enum MemberStatus {
  active('active'),
  left('left');

  const MemberStatus(this.wire);
  final String wire;

  static MemberStatus fromWire(String? v) =>
      wireEnumFrom(v, values, MemberStatus.active, (e) => e.wire);

  String get label => switch (this) {
        MemberStatus.active => '在册',
        MemberStatus.left => '已退出',
      };
}
