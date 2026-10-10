/// 提醒中心（STORY-6.3 / G-3）。
library;

import 'package:plain/core/constants/app_constants.dart';

enum ReminderKind {
  creditDue('credit_due'),
  subscription('subscription'),
  budgetWarn('budget_warn'),
  lowBalance('low_balance'),
  anomalySpend('anomaly_spend'),
  recurringPosted('recurring_posted'),
  reconcile('reconcile'),
  savingsGoal('savings_goal'),
  backup('backup');

  const ReminderKind(this.wire);
  final String wire;
  static ReminderKind fromWire(String? v) {
    for (final e in values) {
      if (e.wire == v) return e;
    }
    return ReminderKind.backup;
  }
}

enum ReminderLevel {
  ring('ring'),
  silent('silent');

  const ReminderLevel(this.wire);
  final String wire;
}

class AppReminder {
  const AppReminder({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.level,
    required this.triggeredAt,
    this.read = false,
  });

  final String id;
  final ReminderKind kind;
  final String title;
  final String body;
  final ReminderLevel level;
  final DateTime triggeredAt;
  final bool read;

  /// G-3：夜间免打扰，响铃降级为静默。
  AppReminder applyQuietHours() {
    final h = triggeredAt.toLocal().hour;
    final quiet = h >= ReminderRules.quietStartHour || h < ReminderRules.quietEndHour;
    if (!quiet || level == ReminderLevel.silent) return this;
    return AppReminder(
      id: id,
      kind: kind,
      title: title,
      body: body,
      level: ReminderLevel.silent,
      triggeredAt: triggeredAt,
      read: read,
    );
  }
}

/// 各类提醒开关（本地偏好）。
class ReminderPrefs {
  const ReminderPrefs({
    this.allMuted = false,
    Set<ReminderKind>? disabled,
  }) : _disabled = disabled ?? const {};

  final bool allMuted;
  final Set<ReminderKind> _disabled;

  bool isEnabled(ReminderKind kind) => !allMuted && !_disabled.contains(kind);

  ReminderPrefs copyWith({bool? allMuted, Set<ReminderKind>? disabled}) {
    return ReminderPrefs(
      allMuted: allMuted ?? this.allMuted,
      disabled: disabled ?? _disabled,
    );
  }

  ReminderPrefs toggle(ReminderKind kind) {
    final next = {..._disabled};
    if (!next.remove(kind)) next.add(kind);
    return copyWith(disabled: next);
  }
}
