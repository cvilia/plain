/// Domain enums. See 08-4.4, 7.7.
library;

enum EntryType {
  expense('expense'), income('income'), transfer('transfer'),
  borrowOut('borrow_out'), borrowIn('borrow_in'), repayCredit('repay_credit'),
  unknown('unknown');

  const EntryType(this.wire);
  final String wire;
  static EntryType fromWire(String? v) {
    for (final t in values) {
      if (t.wire == v) return t;
    }
    return EntryType.unknown;
  }

  bool get countsInOutflow => this == EntryType.expense || this == EntryType.income;
  bool get enabledInV1 => this == EntryType.expense || this == EntryType.income || this == EntryType.transfer;
}

enum EntrySource {
  manual('manual'), reconcile('reconcile'), import('import'),
  recurring('recurring'), ocr('ocr'), ai('ai'), unknown('unknown');

  const EntrySource(this.wire);
  final String wire;
  static EntrySource fromWire(String? v) {
    for (final t in values) {
      if (t.wire == v) return t;
    }
    return EntrySource.unknown;
  }
}

enum AccountType {
  cash('cash'), debit('debit'), credit('credit'),
  loanOut('loan_out'), loanIn('loan_in'), investment('investment'), unknown('unknown');

  const AccountType(this.wire);
  final String wire;
  static AccountType fromWire(String? v) {
    for (final t in values) {
      if (t.wire == v) return t;
    }
    return AccountType.unknown;
  }

  bool get enabledInV1 => this == AccountType.cash || this == AccountType.debit;
}

enum CategoryKind {
  expense('expense'), income('income'), transfer('transfer'), unknown('unknown');

  const CategoryKind(this.wire);
  final String wire;
  static CategoryKind fromWire(String? v) {
    for (final t in values) {
      if (t.wire == v) return t;
    }
    return CategoryKind.unknown;
  }
}

enum ChangeOp {
  insert('insert'), update('update'), delete('delete'), unknown('unknown');

  const ChangeOp(this.wire);
  final String wire;
  static ChangeOp fromWire(String? v) {
    for (final t in values) {
      if (t.wire == v) return t;
    }
    return ChangeOp.unknown;
  }
}

enum EntityType {
  transaction('transaction'), category('category'), account('account'),
  budget('budget'), recurringRule('recurring_rule'), unknown('unknown');

  const EntityType(this.wire);
  final String wire;
  static EntityType fromWire(String? v) {
    for (final t in values) {
      if (t.wire == v) return t;
    }
    return EntityType.unknown;
  }
}

enum BudgetScope {
  total('total'), category('category'), unknown('unknown');

  const BudgetScope(this.wire);
  final String wire;
  static BudgetScope fromWire(String? v) {
    for (final t in values) {
      if (t.wire == v) return t;
    }
    return BudgetScope.unknown;
  }
}

enum BudgetPeriod {
  monthly('monthly'), unknown('unknown');

  const BudgetPeriod(this.wire);
  final String wire;
  static BudgetPeriod fromWire(String? v) {
    for (final t in values) {
      if (t.wire == v) return t;
    }
    return BudgetPeriod.unknown;
  }
}

enum BudgetLevel { ok, warn, over }

enum RecurringFrequency {
  daily('daily'), weekly('weekly'), monthly('monthly'),
  yearly('yearly'), interval('interval'), unknown('unknown');

  const RecurringFrequency(this.wire);
  final String wire;
  static RecurringFrequency fromWire(String? v) {
    for (final t in values) {
      if (t.wire == v) return t;
    }
    return RecurringFrequency.unknown;
  }
}

enum RecurringEndType {
  never('never'), until('until'), count('count'), unknown('unknown');

  const RecurringEndType(this.wire);
  final String wire;
  static RecurringEndType fromWire(String? v) {
    for (final t in values) {
      if (t.wire == v) return t;
    }
    return RecurringEndType.unknown;
  }
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
  static RecurringSkipStrategy fromWire(String? v) {
    for (final t in values) {
      if (t.wire == v) return t;
    }
    return RecurringSkipStrategy.unknown;
  }
}
