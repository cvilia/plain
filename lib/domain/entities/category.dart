/// Category and Account entities. See 08-5.2, 5.3.
library;

import 'package:plain/domain/entities/enums.dart';

class Category {
  const Category({
    required this.id, this.parentId, required this.name,
    required this.kind, required this.iconRef, this.iconAsset,
    required this.sortOrder, this.isHidden = false, this.isPreset = false,
    required this.createdAt, required this.updatedAt,
    this.deletedAt, this.revision = 1,
    required this.deviceId, this.baseRevision = 0,
  });

  final String id;
  final String? parentId;
  final String name;
  final CategoryKind kind;
  final String iconRef;
  final String? iconAsset;
  final int sortOrder;
  final bool isHidden;
  final bool isPreset;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int revision;
  final String deviceId;
  final int baseRevision;

  bool get isDeleted => deletedAt != null;
  bool get isRoot => parentId == null;

  Category copyWith({
    String? name, String? iconRef, String? iconAsset, int? sortOrder,
    bool? isHidden, DateTime? updatedAt, DateTime? deletedAt,
    int? revision, int? baseRevision,
  }) {
    return Category(
      id: id, parentId: parentId, name: name ?? this.name, kind: kind,
      iconRef: iconRef ?? this.iconRef, iconAsset: iconAsset ?? this.iconAsset,
      sortOrder: sortOrder ?? this.sortOrder, isHidden: isHidden ?? this.isHidden,
      isPreset: isPreset, createdAt: createdAt, updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt, revision: revision ?? this.revision,
      deviceId: deviceId, baseRevision: baseRevision ?? this.baseRevision,
    );
  }

  @override
  bool operator ==(Object other) => other is Category && other.id == id && other.revision == revision;
  @override
  int get hashCode => Object.hash(id, revision);
}

class Account {
  const Account({
    required this.id, required this.name, required this.type,
    required this.currency, required this.openingBalance, this.note,
    required this.sortOrder, this.isHidden = false,
    required this.createdAt, required this.updatedAt,
    this.deletedAt, this.revision = 1,
    required this.deviceId, this.baseRevision = 0,
  });

  final String id;
  final String name;
  final AccountType type;
  final String currency;
  final int openingBalance;
  final String? note;
  final int sortOrder;
  final bool isHidden;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int revision;
  final String deviceId;
  final int baseRevision;

  bool get isDeleted => deletedAt != null;

  Account copyWith({
    String? name, int? openingBalance, String? note, int? sortOrder,
    bool? isHidden, DateTime? updatedAt, DateTime? deletedAt,
    int? revision, int? baseRevision,
  }) {
    return Account(
      id: id, name: name ?? this.name, type: type, currency: currency,
      openingBalance: openingBalance ?? this.openingBalance, note: note ?? this.note,
      sortOrder: sortOrder ?? this.sortOrder, isHidden: isHidden ?? this.isHidden,
      createdAt: createdAt, updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt, revision: revision ?? this.revision,
      deviceId: deviceId, baseRevision: baseRevision ?? this.baseRevision,
    );
  }

  @override
  bool operator ==(Object other) => other is Account && other.id == id && other.revision == revision;
  @override
  int get hashCode => Object.hash(id, revision);
}

class AccountBalance {
  const AccountBalance({required this.accountId, required this.balanceCents, required this.openingCents, required this.txCount});
  final String accountId;
  final int balanceCents;
  final int openingCents;
  final int txCount;
}
