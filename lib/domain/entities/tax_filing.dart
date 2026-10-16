/// STORY-11.5 税务申报状态。
library;

import 'package:plain/domain/entities/enums.dart';

class TaxFiling {
  const TaxFiling({
    required this.id,
    required this.bookId,
    required this.periodKey,
    this.periodKind = TaxPeriodKind.month,
    required this.filedAt,
    this.note,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.revision = 1,
    required this.deviceId,
    this.baseRevision = 0,
  });

  final String id;
  final String bookId;

  /// 记账月 `YYYY-MM` 或年度 `YYYY`。
  final String periodKey;
  final TaxPeriodKind periodKind;
  final DateTime filedAt;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int revision;
  final String deviceId;
  final int baseRevision;

  bool get isDeleted => deletedAt != null;

  TaxFiling copyWith({
    DateTime? filedAt,
    String? note,
    DateTime? updatedAt,
    DateTime? deletedAt,
    int? revision,
    int? baseRevision,
  }) =>
      TaxFiling(
        id: id,
        bookId: bookId,
        periodKey: periodKey,
        periodKind: periodKind,
        filedAt: filedAt ?? this.filedAt,
        note: note ?? this.note,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deletedAt: deletedAt ?? this.deletedAt,
        revision: revision ?? this.revision,
        deviceId: deviceId,
        baseRevision: baseRevision ?? this.baseRevision,
      );

  @override
  bool operator ==(Object other) =>
      other is TaxFiling && other.id == id && other.revision == revision;
  @override
  int get hashCode => Object.hash(id, revision);
}
