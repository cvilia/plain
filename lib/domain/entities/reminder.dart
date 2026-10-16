/// 提醒中心（STORY-6.3 / G-3）。
library;

import 'dart:convert';

import 'package:plain/core/constants/app_constants.dart';

/// 九类提醒（PRD STORY-6.3 表，顺序即表内顺序）。
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

  /// PRD STORY-6.3 级别表：前四类**响铃**，后五类**静默**。
  /// 级别由种类定死，不由调用方传参覆盖（防止同一个种类在不同调用点级别不一致）。
  ReminderLevel get level => index <= ReminderKind.lowBalance.index
      ? ReminderLevel.ring
      : ReminderLevel.silent;

  bool get rings => level == ReminderLevel.ring;

  String get label => switch (this) {
        ReminderKind.creditDue => '信用卡还款',
        ReminderKind.subscription => '订阅到期',
        ReminderKind.budgetWarn => '预算预警',
        ReminderKind.lowBalance => '余额不足',
        ReminderKind.anomalySpend => '异常支出',
        ReminderKind.recurringPosted => '周期账单',
        ReminderKind.reconcile => '对账提醒',
        ReminderKind.savingsGoal => '储蓄目标',
        ReminderKind.backup => '备份提醒',
      };
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
    this.requestedLevel,
    this.dedupKey = '',
    this.read = false,
    this.actionRef,
  });

  final String id;
  final ReminderKind kind;
  final String title;
  final String body;
  final ReminderLevel level;

  /// 去重键（写进提醒历史）。同一键在去重窗口内只产生一次。
  final String dedupKey;

  /// 降级前的级别。夜间免打扰把响铃打下来时这里仍是 `ring`。
  final ReminderLevel? requestedLevel;
  final DateTime triggeredAt;
  final bool read;

  /// 可执行动作引用的实体 id（如订阅提醒对应的周期规则 id）。
  ///
  /// 有值 = 提醒卡片可以给一个「一键处理」的动作。空 = 只能看着。
  /// 需要它是因为 PRD 要求订阅提醒「可一键标记不再需要」——不给引用的
  /// 话用户只能自己去周期页翻出那条规则。
  final String? actionRef;

  /// 动作按钮文案（null = 不给按钮）。
  String? get actionLabel =>
      actionRef == null ? null : (kind == ReminderKind.subscription ? '不再需要' : null);

  /// 被请求的级别（没降级时等于 [level]）。
  ReminderLevel get effectiveRequestedLevel => requestedLevel ?? level;

  /// 是否「响铃被夜间免打扰降级为静默」——夜间汇总摘要按它统计。
  bool get wasQuietDowngraded =>
      effectiveRequestedLevel == ReminderLevel.ring &&
      level == ReminderLevel.silent;

  /// 是否落在夜间免打扰时段被产生。
  bool get isQuiet => ReminderRules.isQuietHour(triggeredAt.toLocal().hour);

  /// G-3：夜间免打扰，响铃降级为静默（静默项原样返回）。
  AppReminder applyQuietHours() {
    if (!isQuiet || level == ReminderLevel.silent) return this;
    return AppReminder(
      id: id,
      kind: kind,
      title: title,
      body: body,
      level: ReminderLevel.silent,
      requestedLevel: level,
      dedupKey: dedupKey,
      triggeredAt: triggeredAt,
      read: read,
      actionRef: actionRef,
    );
  }
}

/// 各类提醒开关（PRD 边界：逐项开关 + 「全部静音」总开关，默认关）。
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

  Map<String, Object?> toMap() => {
        'allMuted': allMuted,
        'disabled': [for (final k in _disabled) k.wire],
      };

  static ReminderPrefs fromMap(Map<String, Object?> map) {
    final raw = map['disabled'];
    final disabled = <ReminderKind>{};
    if (raw is List) {
      for (final v in raw) {
        if (v is String) disabled.add(ReminderKind.fromWire(v));
      }
    }
    return ReminderPrefs(
      allMuted: map['allMuted'] == true,
      disabled: disabled,
    );
  }

  String encode() => jsonEncode(toMap());

  /// 解析失败一律回落默认（全开、总开关关）——偏好读不出来不该让提醒失效。
  static ReminderPrefs decode(String? raw) {
    if (raw == null || raw.isEmpty) return const ReminderPrefs();
    try {
      final decoded = jsonDecode(raw);
      // jsonDecode 的 Map<String, dynamic> 就是 Map<String, Object?>
      if (decoded is Map<String, Object?>) return fromMap(decoded);
    } catch (_) {
      // 坏数据回落默认
    }
    return const ReminderPrefs();
  }

  @override
  bool operator ==(Object other) =>
      other is ReminderPrefs &&
      other.allMuted == allMuted &&
      other._disabled.length == _disabled.length &&
      other._disabled.containsAll(_disabled);

  @override
  int get hashCode => Object.hash(allMuted, Object.hashAllUnordered(_disabled));
}

/// G-3：夜间降级项的**次日 08:00 汇总**（STORY-6.3 AC4）。
///
/// 汇总项不落提醒历史——它是对夜间那几条的归纳，落库会让历史里出现
/// 「第 10 类」提醒，直接违背「九类提醒」。
class ReminderDigest {
  const ReminderDigest({
    required this.total,
    required this.postedCount,
    required this.budgetWarnCount,
    required this.downgradedCount,
  });

  /// 夜间产生的提醒条数。
  final int total;

  /// 其中「周期账单已入账」的条数。
  final int postedCount;

  /// 其中预算预警条数。
  final int budgetWarnCount;

  /// 其中「响铃被降级为静默」的条数。
  final int downgradedCount;

  String get title => '夜间提醒汇总';

  /// G-3：汇总里含预算跨阈值则升级为响铃，否则静默。
  ReminderLevel get level =>
      budgetWarnCount > 0 ? ReminderLevel.ring : ReminderLevel.silent;

  String get body {
    final parts = <String>[];
    if (postedCount > 0) parts.add('已入账 $postedCount 笔');
    if (budgetWarnCount > 0) parts.add('预算预警 $budgetWarnCount 条');
    if (downgradedCount > 0) parts.add('响铃降级 $downgradedCount 条');
    if (parts.isEmpty) parts.add('夜间免打扰期间产生的提醒已进提醒中心');
    return '夜间 $total 条提醒：${parts.join(' · ')}';
  }
}
