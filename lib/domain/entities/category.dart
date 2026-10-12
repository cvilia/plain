/// Category and Account entities. See 08-5.2, 5.3.
library;

import 'package:plain/domain/entities/enums.dart';

class Category {
  const Category({
    required this.id, this.parentId, required this.name,
    required this.kind, required this.iconRef, this.iconAsset,
    this.note,
    required this.sortOrder, this.isHidden = false, this.isPreset = false,
    this.isRigid = false,
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

  /// Category boundary note (≤30 chars). Distinct from transactions.note.
  final String? note;
  final int sortOrder;
  final bool isHidden;
  final bool isPreset;

  /// STORY-3.3：刚性支出标记。仅一级分类可标，二级继承。
  /// 仅用于安全可花的「刚性支出预留」计算。
  final bool isRigid;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int revision;
  final String deviceId;
  final int baseRevision;

  bool get isDeleted => deletedAt != null;
  bool get isRoot => parentId == null;

  /// Note cannot be cleared via [copyWith] (`??` treats null as "unset").
  /// Use this when the user empties the note field.
  Category withNote(String? note) => Category(
        id: id, parentId: parentId, name: name, kind: kind,
        iconRef: iconRef, iconAsset: iconAsset, note: note,
        sortOrder: sortOrder, isHidden: isHidden, isPreset: isPreset, isRigid: isRigid,
        createdAt: createdAt, updatedAt: updatedAt, deletedAt: deletedAt,
        revision: revision, deviceId: deviceId, baseRevision: baseRevision,
      );

  /// Reparent this category (used by 移动二级分类).
  Category withParent(String? parentId) => Category(
        id: id, parentId: parentId, name: name, kind: kind,
        iconRef: iconRef, iconAsset: iconAsset, note: note,
        sortOrder: sortOrder, isHidden: isHidden, isPreset: isPreset, isRigid: isRigid,
        createdAt: createdAt, updatedAt: updatedAt, deletedAt: deletedAt,
        revision: revision, deviceId: deviceId, baseRevision: baseRevision,
      );

  Category copyWith({
    String? name, String? iconRef, String? iconAsset, int? sortOrder,
    bool? isHidden, bool? isRigid, DateTime? updatedAt, DateTime? deletedAt,
    int? revision, int? baseRevision, bool clearIconAsset = false,
  }) {
    return Category(
      id: id, parentId: parentId, name: name ?? this.name, kind: kind,
      iconRef: iconRef ?? this.iconRef,
      iconAsset: clearIconAsset ? null : (iconAsset ?? this.iconAsset),
      note: note,
      sortOrder: sortOrder ?? this.sortOrder, isHidden: isHidden ?? this.isHidden,
      isPreset: isPreset, isRigid: isRigid ?? this.isRigid,
      createdAt: createdAt, updatedAt: updatedAt ?? this.updatedAt,
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
    this.creditLimitCents = 0,
    this.creditDebtCents = 0,
    this.billDay,
    this.dueDay,
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

  /// STORY-2.2 信用卡：总额度 / 欠款余额（存储值）/ 账单日 / 还款日。
  final int creditLimitCents;
  final int creditDebtCents;
  final int? billDay;
  final int? dueDay;

  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int revision;
  final String deviceId;
  final int baseRevision;

  bool get isDeleted => deletedAt != null;
  bool get isCredit => type == AccountType.credit;

  /// 可用额度 = 总额度 − 欠款（派生，只读）。
  int get creditAvailableCents {
    final a = creditLimitCents - creditDebtCents;
    return a > 0 ? a : 0;
  }

  /// 是否刷爆（AC6 橙标）。
  bool get isOverLimit => isCredit && creditDebtCents > creditLimitCents;

  Account copyWith({
    String? name, int? openingBalance, String? note, int? sortOrder,
    bool? isHidden, int? creditLimitCents, int? creditDebtCents,
    int? billDay, int? dueDay,
    DateTime? updatedAt, DateTime? deletedAt,
    int? revision, int? baseRevision,
  }) {
    return Account(
      id: id, name: name ?? this.name, type: type, currency: currency,
      openingBalance: openingBalance ?? this.openingBalance, note: note ?? this.note,
      sortOrder: sortOrder ?? this.sortOrder, isHidden: isHidden ?? this.isHidden,
      creditLimitCents: creditLimitCents ?? this.creditLimitCents,
      creditDebtCents: creditDebtCents ?? this.creditDebtCents,
      billDay: billDay ?? this.billDay,
      dueDay: dueDay ?? this.dueDay,
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

/// Helpers for selectable category lists (entry grid, budget, pickers).
extension CategoryListX on List<Category> {
  /// Ids that have at least one live child in this list.
  Set<String> get _parentIds {
    final s = <String>{};
    for (final c in this) {
      final pid = c.parentId;
      if (pid != null) s.add(pid);
    }
    return s;
  }

  /// Only second-level / ungrouped items — never first-level groups.
  List<Category> get leaves {
    final parents = _parentIds;
    return where((c) => !c.isDeleted && !parents.contains(c.id)).toList();
  }
}
