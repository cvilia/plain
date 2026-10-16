/// STORY-8.2 家庭共享（基础）：成员与 AA 参与人。
library;

import 'package:plain/domain/entities/enums.dart';

class Member {
  const Member({
    required this.id,
    required this.bookId,
    required this.name,
    this.role = MemberRole.member,
    this.status = MemberStatus.active,
    this.isMe = false,
    required this.joinedAt,
    this.leftAt,
    this.sortOrder = 0,
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
  final MemberRole role;
  final MemberStatus status;

  /// 本机用户（「我」）。账本里最多一条。
  final bool isMe;

  final DateTime joinedAt;
  final DateTime? leftAt;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int revision;
  final String deviceId;
  final int baseRevision;

  bool get isDeleted => deletedAt != null;
  bool get isActive => status == MemberStatus.active && !isDeleted;

  /// AC4：退出者的历史账单归属显示为「已退出成员」。
  String get attributionLabel =>
      isActive ? name : '已退出成员（$name）';

  /// 是否占用 6 人名额（只看活跃成员）。
  bool get occupiesSeat => isActive;

  Member copyWith({
    String? name,
    MemberRole? role,
    MemberStatus? status,
    bool? isMe,
    DateTime? leftAt,
    bool clearLeftAt = false,
    int? sortOrder,
    DateTime? updatedAt,
    DateTime? deletedAt,
    int? revision,
    int? baseRevision,
  }) =>
      Member(
        id: id,
        bookId: bookId,
        name: name ?? this.name,
        role: role ?? this.role,
        status: status ?? this.status,
        isMe: isMe ?? this.isMe,
        joinedAt: joinedAt,
        leftAt: clearLeftAt ? null : (leftAt ?? this.leftAt),
        sortOrder: sortOrder ?? this.sortOrder,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deletedAt: deletedAt ?? this.deletedAt,
        revision: revision ?? this.revision,
        deviceId: deviceId,
        baseRevision: baseRevision ?? this.baseRevision,
      );

  @override
  bool operator ==(Object other) =>
      other is Member && other.id == id && other.revision == revision;
  @override
  int get hashCode => Object.hash(id, revision);
}

/// AA 分摊的参与人（STORY-8.2：「标记参与人自动算账」）。
class EntryParticipant {
  const EntryParticipant({
    required this.id,
    required this.entryId,
    required this.bookId,
    required this.memberId,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.revision = 1,
    required this.deviceId,
    this.baseRevision = 0,
  });

  final String id;
  final String entryId;
  final String bookId;
  final String memberId;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int revision;
  final String deviceId;
  final int baseRevision;

  bool get isDeleted => deletedAt != null;
}

/// 按成员汇总（AC3：各成员笔数与金额）。
class MemberAgg {
  const MemberAgg({
    required this.memberId,
    required this.txCount,
    required this.expenseCents,
    required this.incomeCents,
    this.participatedCount = 0,
    this.participatedShareCents = 0,
  });

  /// 归属成员 id；为空表示未指定归属（老数据）。
  final String memberId;
  final int txCount;
  final int expenseCents;
  final int incomeCents;

  /// AA：作为参与人**参与**的笔数与平均分摊金额。
  final int participatedCount;
  final int participatedShareCents;

  int get balanceCents => incomeCents - expenseCents;
}
