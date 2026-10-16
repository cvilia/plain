/// 储蓄目标（STORY-7.1）。
library;

import 'package:plain/core/constants/app_constants.dart';

/// STORY-7.2 目标类型。
enum GoalType {
  savings('savings'),
  debt('debt');

  const GoalType(this.wire);
  final String wire;
  static GoalType fromWire(String? v) => v == 'debt' ? GoalType.debt : GoalType.savings;
}

class SavingsGoal {
  const SavingsGoal({
    required this.id,
    required this.bookId,
    required this.name,
    required this.targetCents,
    required this.savedCents,
    this.goalType = GoalType.savings,
    this.remainingTerms,
    this.goalAccountId,
    this.dueAt,
    this.accountId,
    this.autoTransfer = false,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.revision = 1,
    required this.deviceId,
    this.baseRevision = 0,
  });

  final String id;
  final String bookId;
  final String name;
  final int targetCents;
  final int savedCents;

  /// 储蓄 / 还债（限额复用分类预算，不建目标）。
  final GoalType goalType;

  /// 还债：剩余期数。
  final int? remainingTerms;

  /// STORY-7.1：目标的**虚拟账户** id（`accounts.type = 'goal'`）。
  /// 存款是「可用账户 → 该虚拟账户」的内部转账，转入端就是它。
  /// null = 还没存过（首次存入时惰性创建）。
  final String? goalAccountId;

  final DateTime? dueAt;
  final String? accountId;

  /// 存款的转出端（G-2：转账不计入收支）。未关联账户时无法执行存入。
  bool get canDeposit => accountId != null && accountId!.isNotEmpty;

  /// 还债目标（STORY-7.2）：关联到贷款账户后可显示剩余利息与预计还清日，
  /// 且**不做「存入」**——还债靠还款，不是往目标里存钱。
  bool get isDebt => goalType == GoalType.debt;

  /// 自动按月划拨（走周期调度器）。
  final bool autoTransfer;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int revision;
  final String deviceId;
  final int baseRevision;

  bool get isDeleted => deletedAt != null;
  bool get isAchieved => savedCents >= targetCents && targetCents > 0;

  bool isOverdueAt(DateTime now) {
    final d = dueAt;
    if (d == null || isAchieved) return false;
    return now.isAfter(d);
  }

  /// 还债：已还 ÷ 总欠款；储蓄：已存 ÷ 目标。
  double get progress {
    if (targetCents <= 0) return 0;
    return (savedCents / targetCents).clamp(0, 1);
  }

  /// 还债剩余本金（总欠款 − 已还）。
  int get remainingCents {
    final r = targetCents - savedCents;
    return r > 0 ? r : 0;
  }

  /// 每月需存（AC1）。[now] 用于算剩余月数（G-4）。
  int monthlyRequiredCentsAt(DateTime now) {
    final remain = targetCents - savedCents;
    if (remain <= 0) return 0;
    final d = dueAt;
    if (d == null) {
      const defaultMonths = 12;
      return (remain / defaultMonths).ceil();
    }
    // 含当月与到期月（1 月起存、12 月底截止 → 12 个月）
    var months = (d.year - now.year) * 12 + (d.month - now.month) + 1;
    if (months < SavingsRules.minRemainingMonths) {
      months = SavingsRules.minRemainingMonths;
    }
    return (remain / months).ceil();
  }

  /// 本月是否已存满「待存」额度。
  int remainingThisMonth(int monthIndex, DateTime now) {
    final targetToMonth = monthlyRequiredCentsAt(now) * monthIndex;
    final lack = targetToMonth - savedCents;
    return lack > 0 ? lack : 0;
  }

  SavingsGoal copyWith({
    String? name,
    int? targetCents,
    int? savedCents,
    GoalType? goalType,
    int? remainingTerms,
    String? goalAccountId,
    DateTime? dueAt,
    String? accountId,
    bool? autoTransfer,
    DateTime? updatedAt,
    DateTime? deletedAt,
    int? revision,
    int? baseRevision,
    bool clearDueAt = false,
  }) {
    return SavingsGoal(
      id: id,
      bookId: bookId,
      name: name ?? this.name,
      targetCents: targetCents ?? this.targetCents,
      savedCents: savedCents ?? this.savedCents,
      goalType: goalType ?? this.goalType,
      remainingTerms: remainingTerms ?? this.remainingTerms,
      goalAccountId: goalAccountId ?? this.goalAccountId,
      dueAt: clearDueAt ? null : (dueAt ?? this.dueAt),
      accountId: accountId ?? this.accountId,
      autoTransfer: autoTransfer ?? this.autoTransfer,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      revision: revision ?? this.revision,
      deviceId: deviceId,
      baseRevision: baseRevision ?? this.baseRevision,
    );
  }
}
