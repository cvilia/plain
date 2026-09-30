/// Recurring rule entity. See PRD F6.1, 01-M5.
library;

import 'package:plain/core/money/money.dart';
import 'package:plain/domain/entities/enums.dart';

class RecurringRule {
  const RecurringRule({
    required this.id, required this.bookId, this.name,
    required this.frequency, this.intervalN = 1,
    this.anchorDay, this.weekday,
    this.skipStrategy = RecurringSkipStrategy.clamp,
    this.autoConfirm = true,
    this.endType = RecurringEndType.never,
    this.endAt, this.endCount,
    this.generatedCount = 0, required this.nextRunAt,
    required this.entryType, required this.amount,
    this.categoryId, this.accountId, this.toAccountId, this.note,
    this.lastBatchId, this.isEnabled = true,
    required this.createdAt, required this.updatedAt,
    this.deletedAt, this.revision = 1,
    required this.deviceId, this.baseRevision = 0,
  });

  final String id;
  final String bookId;
  final String? name;
  final RecurringFrequency frequency;
  final int intervalN;
  final int? anchorDay;
  final int? weekday;
  final RecurringSkipStrategy skipStrategy;
  final bool autoConfirm;
  final RecurringEndType endType;
  final DateTime? endAt;
  final int? endCount;
  final int generatedCount;
  final DateTime nextRunAt;
  final EntryType entryType;
  final Money amount;
  final String? categoryId;
  final String? accountId;
  final String? toAccountId;
  final String? note;
  final String? lastBatchId;
  final bool isEnabled;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int revision;
  final String deviceId;
  final int baseRevision;

  bool get isDeleted => deletedAt != null;

  /// Whether end condition is already satisfied at [generatedCount].
  bool get isFinished {
    return switch (endType) {
      RecurringEndType.count => endCount != null && generatedCount >= endCount!,
      _ => false,
    };
  }

  RecurringRule copyWith({
    String? name, RecurringFrequency? frequency, int? intervalN,
    int? anchorDay, int? weekday, RecurringSkipStrategy? skipStrategy,
    bool? autoConfirm, RecurringEndType? endType, DateTime? endAt,
    int? endCount, int? generatedCount, DateTime? nextRunAt,
    EntryType? entryType, Money? amount, String? categoryId,
    String? accountId, String? toAccountId, String? note,
    String? lastBatchId, bool? isEnabled,
    DateTime? updatedAt, DateTime? deletedAt, int? revision, int? baseRevision,
  }) {
    return RecurringRule(
      id: id, bookId: bookId, name: name ?? this.name,
      frequency: frequency ?? this.frequency, intervalN: intervalN ?? this.intervalN,
      anchorDay: anchorDay ?? this.anchorDay, weekday: weekday ?? this.weekday,
      skipStrategy: skipStrategy ?? this.skipStrategy,
      autoConfirm: autoConfirm ?? this.autoConfirm,
      endType: endType ?? this.endType, endAt: endAt ?? this.endAt,
      endCount: endCount ?? this.endCount,
      generatedCount: generatedCount ?? this.generatedCount,
      nextRunAt: nextRunAt ?? this.nextRunAt,
      entryType: entryType ?? this.entryType, amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
      accountId: accountId ?? this.accountId,
      toAccountId: toAccountId ?? this.toAccountId,
      note: note ?? this.note, lastBatchId: lastBatchId ?? this.lastBatchId,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt, updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      revision: revision ?? this.revision, deviceId: deviceId,
      baseRevision: baseRevision ?? this.baseRevision,
    );
  }

  @override
  bool operator ==(Object other) => other is RecurringRule && other.id == id && other.revision == revision;
  @override
  int get hashCode => Object.hash(id, revision);
}
