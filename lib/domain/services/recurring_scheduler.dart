/// Recurring occurrence calculator. See PRD F6.1 rule engine.
///
/// Anchor day short-month policy: clamp to last day of month (31 → 28/29)
/// unless [RecurringSkipStrategy.skip].
library;

import 'dart:math' as math;

import 'package:plain/core/money/money.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/entities/recurring_rule.dart';

class RecurringScheduler {
  const RecurringScheduler();

  /// Last calendar day of [year]-[month].
  int lastDayOfMonth(int year, int month) => DateTime(year, month + 1, 0).day;

  /// Resolve anchor day for a month, or null when strategy is skip and day is out of range.
  DateTime? resolveAnchor(int year, int month, int day, RecurringSkipStrategy strategy) {
    final last = lastDayOfMonth(year, month);
    if (day > last) {
      if (strategy == RecurringSkipStrategy.skip) return null;
      return DateTime(year, month, last);
    }
    return DateTime(year, month, day);
  }

  /// Next occurrence strictly after [after], or null when the rule is finished
  /// or the next run would pass the end date.
  DateTime? nextAfter(RecurringRule rule, DateTime after) {
    if (rule.isFinished) return null;
    final from = after.toUtc();
    final candidate = _rawNext(rule, from);
    if (candidate == null) return null;
    if (rule.endType == RecurringEndType.until && rule.endAt != null) {
      if (candidate.isAfter(rule.endAt!.toUtc())) return null;
    }
    return candidate;
  }

  /// Whether the rule is due at [now] (nextRunAt <= now and not finished).
  bool isDue(RecurringRule rule, DateTime now) {
    if (!rule.isEnabled || rule.isDeleted || rule.isFinished) return false;
    return !rule.nextRunAt.toUtc().isAfter(now.toUtc());
  }

  /// First run time for a newly created rule (strictly after [now]).
  DateTime initialNextRun({
    required RecurringFrequency frequency,
    required DateTime now,
    int intervalN = 1,
    int? anchorDay,
    int? weekday,
    RecurringSkipStrategy skipStrategy = RecurringSkipStrategy.clamp,
  }) {
    final seed = RecurringRule(
      id: 'seed', bookId: 'seed', frequency: frequency, intervalN: intervalN,
      anchorDay: anchorDay, weekday: weekday, skipStrategy: skipStrategy,
      nextRunAt: now, entryType: EntryType.expense, amount: Money.zero,
      createdAt: now, updatedAt: now, deviceId: 'seed',
    );
    return nextAfter(seed, now) ?? now.toUtc().add(const Duration(days: 1));
  }

  DateTime? _rawNext(RecurringRule rule, DateTime afterUtc) {
    final local = afterUtc.toLocal();
    switch (rule.frequency) {
      case RecurringFrequency.daily:
        final n = math.max(1, rule.intervalN);
        return DateTime(local.year, local.month, local.day + n).toUtc();
      case RecurringFrequency.weekly:
        final target = rule.weekday ?? local.weekday;
        final n = math.max(1, rule.intervalN);
        var daysAhead = (target - local.weekday) % 7;
        if (daysAhead == 0) daysAhead = 7;
        final base = DateTime(local.year, local.month, local.day + daysAhead);
        return DateTime(base.year, base.month, base.day + 7 * (n - 1)).toUtc();
      case RecurringFrequency.monthly:
        final day = rule.anchorDay ?? local.day;
        final n = math.max(1, rule.intervalN);
        var y = local.year;
        var m = local.month + n;
        DateTime? anchor = resolveAnchor(y, m, day, rule.skipStrategy);
        var guard = 0;
        while (anchor != null &&
            !anchor.isAfter(DateTime(local.year, local.month, local.day, 23, 59, 59)) &&
            guard < 60) {
          m += n;
          if (m > 12) {
            y += (m - 1) ~/ 12;
            m = (m - 1) % 12 + 1;
          }
          anchor = resolveAnchor(y, m, day, rule.skipStrategy);
          guard++;
        }
        return anchor?.toUtc();
      case RecurringFrequency.yearly:
        final day = rule.anchorDay ?? local.day;
        final n = math.max(1, rule.intervalN);
        var y = local.year + n;
        var anchor = resolveAnchor(y, local.month, day, rule.skipStrategy);
        var guard = 0;
        while (anchor != null && !anchor.isAfter(local) && guard < 8) {
          y += n;
          anchor = resolveAnchor(y, local.month, day, rule.skipStrategy);
          guard++;
        }
        return anchor?.toUtc();
      case RecurringFrequency.interval:
        final n = math.max(1, rule.intervalN);
        return DateTime(local.year, local.month, local.day + n).toUtc();
      case RecurringFrequency.unknown:
        return null;
    }
  }
}
