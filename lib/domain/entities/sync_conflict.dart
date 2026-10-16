/// STORY-8.1 同步冲突（冲突中心的条目）。
library;

enum ConflictResolution {
  unresolved('unresolved'),
  keepLocal('local'),
  keepRemote('remote'),
  keepBoth('both');

  const ConflictResolution(this.wire);
  final String wire;

  static ConflictResolution fromWire(String? v) {
    for (final e in values) {
      if (e.wire == v) return e;
    }
    return ConflictResolution.unresolved;
  }

  String get label => switch (this) {
        ConflictResolution.unresolved => '待裁决',
        ConflictResolution.keepLocal => '保留本机版本',
        ConflictResolution.keepRemote => '保留远端版本',
        ConflictResolution.keepBoth => '都保留',
      };
}

class SyncConflict {
  const SyncConflict({
    required this.id,
    required this.bookId,
    required this.entityType,
    required this.entityId,
    required this.field,
    this.ancestorValue,
    this.localValue,
    this.remoteValue,
    required this.localPayload,
    required this.remotePayload,
    this.localChangedAt,
    this.remoteChangedAt,
    required this.winner,
    this.resolution = ConflictResolution.unresolved,
    this.resolvedAt,
    required this.createdAt,
  });

  final String id;
  final String bookId;
  final String entityType;
  final String entityId;
  final String field;
  final String? ancestorValue;
  final String? localValue;
  final String? remoteValue;

  /// 两端各自的完整快照（JSON），裁决时按原样重放。
  final String localPayload;
  final String remotePayload;

  final DateTime? localChangedAt;
  final DateTime? remoteChangedAt;

  /// 自动合并时的「最后写入者胜」结果。
  final String winner;
  final ConflictResolution resolution;
  final DateTime? resolvedAt;
  final DateTime createdAt;

  bool get isOpen => resolution == ConflictResolution.unresolved;

  String get entityLabel => switch (entityType) {
        'transaction' => '账单',
        'category' => '分类',
        'account' => '账户',
        'budget' => '预算',
        'member' => '成员',
        'attachment' => '附件',
        'savings_goal' => '储蓄目标',
        'recurring_rule' => '周期规则',
        'currency_rate' => '锁定汇率',
        _ => entityType,
      };

  SyncConflict copyWith({
    ConflictResolution? resolution,
    DateTime? resolvedAt,
  }) =>
      SyncConflict(
        id: id,
        bookId: bookId,
        entityType: entityType,
        entityId: entityId,
        field: field,
        ancestorValue: ancestorValue,
        localValue: localValue,
        remoteValue: remoteValue,
        localPayload: localPayload,
        remotePayload: remotePayload,
        localChangedAt: localChangedAt,
        remoteChangedAt: remoteChangedAt,
        winner: winner,
        resolution: resolution ?? this.resolution,
        resolvedAt: resolvedAt ?? this.resolvedAt,
        createdAt: createdAt,
      );
}
