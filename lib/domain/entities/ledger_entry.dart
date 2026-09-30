/// LedgerEntry entity. See 08-5.1.
library;

import 'package:plain/core/money/money.dart';
import 'package:plain/domain/entities/enums.dart';

class LedgerEntry {
  const LedgerEntry({
    required this.id, required this.bookId, required this.type,
    required this.amount, required this.currency,
    this.categoryId, this.accountId, this.toAccountId,
    required this.occurredAt, this.note, required this.source,
    this.batchId,
    required this.createdAt, required this.updatedAt,
    this.deletedAt, this.revision = 1,
    required this.deviceId, this.baseRevision = 0,
  });

  final String id;
  final String bookId;
  final EntryType type;
  final Money amount;
  final String currency;
  final String? categoryId;
  final String? accountId;
  final String? toAccountId;
  final DateTime occurredAt;
  final String? note;
  final EntrySource source;
  final String? batchId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int revision;
  final String deviceId;
  final int baseRevision;

  bool get isDeleted => deletedAt != null;
  bool get isTransfer => type == EntryType.transfer;

  int get signedCentsForFlow => switch (type) {
        EntryType.expense => -amount.cents,
        EntryType.income => amount.cents,
        _ => 0,
      };

  LedgerEntry copyWith({
    Money? amount, String? categoryId, String? accountId, String? toAccountId,
    DateTime? occurredAt, String? note, EntryType? type,
    DateTime? updatedAt, DateTime? deletedAt, int? revision, int? baseRevision,
    bool clearNote = false, bool clearCategoryId = false, bool clearDeletedAt = false,
  }) {
    return LedgerEntry(
      id: id, bookId: bookId, type: type ?? this.type,
      amount: amount ?? this.amount, currency: currency,
      categoryId: clearCategoryId ? null : (categoryId ?? this.categoryId),
      accountId: accountId ?? this.accountId,
      toAccountId: toAccountId ?? this.toAccountId,
      occurredAt: occurredAt ?? this.occurredAt,
      note: clearNote ? null : (note ?? this.note),
      source: source, batchId: batchId, createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      revision: revision ?? this.revision, deviceId: deviceId,
      baseRevision: baseRevision ?? this.baseRevision,
    );
  }

  @override
  bool operator ==(Object other) => other is LedgerEntry && other.id == id && other.revision == revision;
  @override
  int get hashCode => Object.hash(id, revision);
}
