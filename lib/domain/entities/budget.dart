/// Budget entity and period status. See PRD F5.1/F5.2, 01-M5.
library;

import 'package:plain/core/money/money.dart';
import 'package:plain/domain/entities/enums.dart';

class Budget {
  const Budget({
    required this.id, required this.bookId, required this.scope,
    this.categoryId, this.periodType = BudgetPeriod.monthly,
    this.startDay = 1, required this.amount, this.rollover = false,
    this.isEnabled = true, required this.createdAt, required this.updatedAt,
    this.deletedAt, this.revision = 1,
    required this.deviceId, this.baseRevision = 0,
  });

  final String id;
  final String bookId;
  final BudgetScope scope;
  final String? categoryId;
  final BudgetPeriod periodType;
  final int startDay;
  final Money amount;
  final bool rollover;
  final bool isEnabled;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int revision;
  final String deviceId;
  final int baseRevision;

  bool get isDeleted => deletedAt != null;
  bool get isTotal => scope == BudgetScope.total;

  Budget copyWith({
    Money? amount, int? startDay, bool? rollover, bool? isEnabled,
    String? categoryId, DateTime? updatedAt, DateTime? deletedAt,
    int? revision, int? baseRevision,
  }) {
    return Budget(
      id: id, bookId: bookId, scope: scope,
      categoryId: categoryId ?? this.categoryId, periodType: periodType,
      startDay: startDay ?? this.startDay, amount: amount ?? this.amount,
      rollover: rollover ?? this.rollover, isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt, updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      revision: revision ?? this.revision, deviceId: deviceId,
      baseRevision: baseRevision ?? this.baseRevision,
    );
  }

  @override
  bool operator ==(Object other) => other is Budget && other.id == id && other.revision == revision;
  @override
  int get hashCode => Object.hash(id, revision);
}

/// Derived budget status for a period. Not persisted.
class BudgetStatus {
  const BudgetStatus({
    required this.budget, required this.spentCents,
    required this.periodStart, required this.periodEnd, required this.today,
    this.carryOverCents = 0,
  });

  final Budget budget;
  final int spentCents;
  final DateTime periodStart;
  final DateTime periodEnd;
  final DateTime today;

  /// Unused budget rolled forward from the previous period (rollover budgets).
  final int carryOverCents;

  /// Base allowance plus carry — the user's real spending headroom.
  int get limitCents => budget.amount.cents + carryOverCents;
  int get remainingCents => limitCents - spentCents;
  double get ratio => limitCents == 0 ? 0 : spentCents / limitCents;

  /// Calendar days left in the period including today.
  int get daysLeft {
    final endDay = DateTime(periodEnd.year, periodEnd.month, periodEnd.day);
    final todayDay = DateTime(today.year, today.month, today.day);
    return endDay.difference(todayDay).inDays + 1;
  }

  /// Average daily budget left. 0 when over or no days left.
  int get dailyAvailableCents {
    if (remainingCents <= 0 || daysLeft <= 0) return 0;
    return remainingCents ~/ daysLeft;
  }

  BudgetLevel get level {
    if (spentCents >= limitCents) return BudgetLevel.over;
    if (ratio >= 0.8) return BudgetLevel.warn;
    return BudgetLevel.ok;
  }

  bool get isOver => level == BudgetLevel.over;
  bool get isNear => level == BudgetLevel.warn;
}

/// Resolve the [start, end) window for a budget period containing [today].
({DateTime start, DateTime end}) budgetPeriodWindow({
  required DateTime today, required int startDay,
}) {
  final local = today.toLocal();
  final day = startDay.clamp(1, 28);
  DateTime start;
  if (local.day >= day) {
    start = DateTime(local.year, local.month, day);
  } else {
    final prev = DateTime(local.year, local.month - 1, day);
    start = prev;
  }
  final end = DateTime(start.year, start.month + 1, start.day);
  return (start: start, end: end);
}
