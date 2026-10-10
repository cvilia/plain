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
  loanOut('loan_out'), loanIn('loan_in'), investment('investment'), unknown('unknown');

  const AccountType(this.wire);
  final String wire;
  static AccountType fromWire(String? v) =>
      wireEnumFrom(v, values, AccountType.unknown, (e) => e.wire);

  bool get enabledInV1 =>
    this == AccountType.cash ||
    this == AccountType.debit ||
    this == AccountType.credit ||
    this == AccountType.investment;
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
  savingsGoal('savings_goal'), unknown('unknown');

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

/// How to handle months without the anchor day (e.g. 31 in February).
enum RecurringSkipStrategy {
  /// Clamp to last day of month (31 → 28/29). PRD F6.1 default.
  clamp('clamp'),
  /// Skip the month entirely.
  skip('skip'),
  unknown('unknown');

  const RecurringSkipStrategy(this.wire);
  final String wire;
  static RecurringSkipStrategy fromWire(String? v) =>
      wireEnumFrom(v, values, RecurringSkipStrategy.unknown, (e) => e.wire);
}
