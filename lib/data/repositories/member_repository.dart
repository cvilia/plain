/// STORY-8.2 家庭成员 + AA 参与人仓储。
///
/// 成员进 change_log（8.1 同步范围表里成员是数据资产）；
/// **AA 参与人不进 change_log**（PRD 的同步清单未列它，且它是一笔账单的
/// 附属标记，等 8.1 的三方合并落地再决定怎么合并）。
library;

import 'package:plain/core/id/uuid_v7.dart';
import 'package:plain/core/result/result.dart';
import 'package:plain/core/time/clock.dart';
import 'package:plain/data/db/database.dart';
import 'package:plain/data/db/row_x.dart';
import 'package:plain/data/sync/change_log_writer.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/entities/member.dart';
import 'package:plain/domain/repositories/repositories.dart';

class MemberRepositoryImpl implements MemberRepository {
  MemberRepositoryImpl({
    required AppDatabase db,
    required ChangeLogWriter changeLogWriter,
    required UuidV7 idGen,
    Clock? clock,
  })  : _db = db,
        _changeLog = changeLogWriter,
        _idGen = idGen,
        _clock = clock ?? SystemClock();

  final AppDatabase _db;
  final ChangeLogWriter _changeLog;
  final UuidV7 _idGen;
  final Clock _clock;

  @override
  Future<Result<List<Member>>> listByBook(String bookId, {bool includeLeft = true}) async {
    try {
      final rows = _db.raw.select(
        'SELECT * FROM members WHERE book_id = ? AND deleted_at IS NULL '
        '${includeLeft ? '' : "AND status = 'active' "}'
        'ORDER BY is_me DESC, sort_order, joined_at',
        [bookId],
      );
      return ok([for (final r in rows) _fromRow(r)]);
    } on Exception catch (e) {
      return err(StorageFailure('db.query_failed', e.toString(), isRetryable: true));
    }
  }

  @override
  Future<Result<int>> countActive(String bookId) async {
    try {
      final rows = _db.raw.select(
        "SELECT COUNT(*) AS c FROM members WHERE book_id = ? AND deleted_at IS NULL "
        "AND status = 'active'",
        [bookId],
      );
      return ok((rows.first['c'] as int?) ?? 0);
    } on Exception catch (e) {
      return err(StorageFailure('db.query_failed', e.toString(), isRetryable: true));
    }
  }

  @override
  Future<Result<Member>> getById(String id) async {
    try {
      final rows = _db.raw.select('SELECT * FROM members WHERE id = ?', [id]);
      if (rows.isEmpty) return err<Member>(const NotFoundFailure('member.not_found', 'nf'));
      return ok(_fromRow(rows.first));
    } on Exception catch (e) {
      return err(StorageFailure('db.query_failed', e.toString(), isRetryable: true));
    }
  }

  @override
  Future<Result<Member?>> getMe(String bookId) async {
    try {
      final rows = _db.raw.select(
        'SELECT * FROM members WHERE book_id = ? AND is_me = 1 AND deleted_at IS NULL '
        'ORDER BY joined_at LIMIT 1',
        [bookId],
      );
      return ok(rows.isEmpty ? null : _fromRow(rows.first));
    } on Exception catch (e) {
      return err(StorageFailure('db.query_failed', e.toString(), isRetryable: true));
    }
  }

  @override
  Future<Result<Member>> create(Member member) async {
    try {
      final dup = _db.raw.select(
        'SELECT id FROM members WHERE book_id = ? AND name = ? AND deleted_at IS NULL',
        [member.bookId, member.name],
      );
      if (dup.isNotEmpty) {
        return err<Member>(
            const ConflictFailure('member.name_taken', 'duplicated member name'));
      }
      _db.transaction(() {
        _insert(member);
        _changeLog.write(
          entityType: EntityType.member,
          entityId: member.id,
          op: ChangeOp.insert,
          deviceId: member.deviceId,
          baseRevision: 0,
          before: const {},
          after: _payload(member),
        );
      });
      return ok(member);
    } on Exception catch (e) {
      return err(StorageFailure('db.insert_failed', e.toString(), isRetryable: true));
    }
  }

  @override
  Future<Result<Member>> update(Member member) async {
    try {
      final rows = _db.raw.select('SELECT * FROM members WHERE id = ?', [member.id]);
      if (rows.isEmpty) return err<Member>(const NotFoundFailure('member.not_found', 'nf'));
      final old = _fromRow(rows.first);
      final next = member.copyWith(
        revision: old.revision + 1,
        baseRevision: old.revision,
      );
      _db.transaction(() {
        _update(next);
        _changeLog.write(
          entityType: EntityType.member,
          entityId: next.id,
          op: ChangeOp.update,
          deviceId: next.deviceId,
          baseRevision: old.revision,
          before: _payload(old),
          after: _payload(next),
        );
      });
      return ok(next);
    } on Exception catch (e) {
      return err(StorageFailure('db.update_failed', e.toString(), isRetryable: true));
    }
  }

  @override
  Future<Result<void>> softDelete(String id) async {
    try {
      final rows = _db.raw.select('SELECT * FROM members WHERE id = ?', [id]);
      if (rows.isEmpty) return err<void>(const NotFoundFailure('member.not_found', 'nf'));
      final old = _fromRow(rows.first);
      if (old.isMe) {
        // 「我」是账本的所有者锚点，删掉会让历史归属与权限判定失去支点
        return err<void>(const ValidationFailure('member.cannot_delete_me', 'self'));
      }
      final now = _clock.now();
      final deleted = old.copyWith(
        deletedAt: now,
        updatedAt: now,
        status: MemberStatus.left,
        leftAt: now,
        revision: old.revision + 1,
        baseRevision: old.revision,
      );
      _db.transaction(() {
        _update(deleted);
        _changeLog.write(
          entityType: EntityType.member,
          entityId: id,
          op: ChangeOp.delete,
          deviceId: old.deviceId,
          baseRevision: old.revision,
          before: _payload(old),
          after: const {},
        );
      });
      return ok(null);
    } on Exception catch (e) {
      return err(StorageFailure('db.delete_failed', e.toString(), isRetryable: true));
    }
  }

  @override
  Future<Result<void>> leave(String id, DateTime at) async {
    try {
      final rows = _db.raw.select('SELECT * FROM members WHERE id = ?', [id]);
      if (rows.isEmpty) return err<void>(const NotFoundFailure('member.not_found', 'nf'));
      final old = _fromRow(rows.first);
      if (old.isMe) {
        return err<void>(const ValidationFailure('member.cannot_leave_me', 'self'));
      }
      // 至少留 1 名管理员：最后一名所有者不能退出（PRD §7 边界）
      if (old.role == MemberRole.owner) {
        final owners = _db.raw.select(
          "SELECT COUNT(*) AS c FROM members WHERE book_id = ? AND deleted_at IS NULL "
          "AND status = 'active' AND role = 'owner'",
          [old.bookId],
        );
        if (((owners.first['c'] as int?) ?? 0) <= 1) {
          return err<void>(const ConflictFailure('member.last_owner', 'transfer first'));
        }
      }
      final next = old.copyWith(
        status: MemberStatus.left,
        leftAt: at,
        updatedAt: at,
        revision: old.revision + 1,
        baseRevision: old.revision,
      );
      _db.transaction(() {
        _update(next);
        _changeLog.write(
          entityType: EntityType.member,
          entityId: id,
          op: ChangeOp.update,
          deviceId: old.deviceId,
          baseRevision: old.revision,
          before: _payload(old),
          after: _payload(next),
        );
      });
      return ok(null);
    } on Exception catch (e) {
      return err(StorageFailure('db.update_failed', e.toString(), isRetryable: true));
    }
  }

  @override
  Future<Result<List<EntryParticipant>>> participantsOf(String entryId) async {
    try {
      final rows = _db.raw.select(
        'SELECT * FROM entry_participants WHERE entry_id = ? AND deleted_at IS NULL '
        'ORDER BY sort_order, created_at',
        [entryId],
      );
      return ok([for (final r in rows) _participantFromRow(r)]);
    } on Exception catch (e) {
      return err(StorageFailure('db.query_failed', e.toString(), isRetryable: true));
    }
  }

  @override
  Future<Result<void>> setParticipants({
    required String entryId,
    required String bookId,
    required List<String> memberIds,
    required String deviceId,
  }) async {
    try {
      final now = _clock.now();
      // 整组替换：先逻辑删掉旧行（保留 revision 轨迹），再插入新行
      final olds = _db.raw.select(
        'SELECT * FROM entry_participants WHERE entry_id = ? AND deleted_at IS NULL',
        [entryId],
      );
      _db.transaction(() {
        _db.raw.execute(
          'UPDATE entry_participants SET deleted_at = ?, updated_at = ? '
          'WHERE entry_id = ? AND deleted_at IS NULL',
          [now.millisecondsSinceEpoch, now.millisecondsSinceEpoch, entryId],
        );
        // 删旧也要记日志：不记的话对端会一直保留旧参与人，AA 分摊越攒越多
        for (final row in olds) {
          final old = _participantFromRow(row);
          _changeLog.write(
            entityType: EntityType.entryParticipant,
            entityId: old.id,
            op: ChangeOp.delete,
            deviceId: old.deviceId,
            baseRevision: old.revision,
            before: _participantPayload(old),
            after: const {},
            changedAt: now,
          );
        }
        var order = 0;
        for (final mid in memberIds) {
          final p = EntryParticipant(
            id: _idGen.generate(at: now),
            entryId: entryId,
            bookId: bookId,
            memberId: mid,
            sortOrder: order++,
            createdAt: now,
            updatedAt: now,
            deviceId: deviceId,
          );
          _insertParticipant(p);
          _changeLog.write(
            entityType: EntityType.entryParticipant,
            entityId: p.id,
            op: ChangeOp.insert,
            deviceId: deviceId,
            baseRevision: 0,
            before: const {},
            after: _participantPayload(p),
            changedAt: now,
          );
        }
      });
      return ok(null);
    } on Exception catch (e) {
      return err(StorageFailure('db.update_failed', e.toString(), isRetryable: true));
    }
  }

  void _insert(Member m) {
    _db.raw.execute(
      'INSERT INTO members (id,book_id,name,role,status,is_me,joined_at,left_at,sort_order,'
      'created_at,updated_at,deleted_at,revision,device_id,base_revision) '
      'VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
      [
        m.id, m.bookId, m.name, m.role.wire, m.status.wire, m.isMe ? 1 : 0,
        m.joinedAt.millisecondsSinceEpoch, m.leftAt?.millisecondsSinceEpoch,
        m.sortOrder, m.createdAt.millisecondsSinceEpoch,
        m.updatedAt.millisecondsSinceEpoch, m.deletedAt?.millisecondsSinceEpoch,
        m.revision, m.deviceId, m.baseRevision,
      ],
    );
  }

  void _update(Member m) {
    _db.raw.execute(
      'UPDATE members SET name=?,role=?,status=?,is_me=?,left_at=?,sort_order=?,'
      'updated_at=?,deleted_at=?,revision=?,base_revision=? WHERE id=?',
      [
        m.name, m.role.wire, m.status.wire, m.isMe ? 1 : 0,
        m.leftAt?.millisecondsSinceEpoch, m.sortOrder,
        m.updatedAt.millisecondsSinceEpoch, m.deletedAt?.millisecondsSinceEpoch,
        m.revision, m.baseRevision, m.id,
      ],
    );
  }

  void _insertParticipant(EntryParticipant p) {
    _db.raw.execute(
      'INSERT INTO entry_participants (id,entry_id,book_id,member_id,sort_order,'
      'created_at,updated_at,deleted_at,revision,device_id,base_revision) '
      'VALUES (?,?,?,?,?,?,?,?,?,?,?)',
      [
        p.id, p.entryId, p.bookId, p.memberId, p.sortOrder,
        p.createdAt.millisecondsSinceEpoch, p.updatedAt.millisecondsSinceEpoch,
        p.deletedAt?.millisecondsSinceEpoch, p.revision, p.deviceId, p.baseRevision,
      ],
    );
  }

  Member _fromRow(Map<String, Object?> row) => Member(
        id: row['id']! as String,
        bookId: row['book_id']! as String,
        name: row['name']! as String,
        role: MemberRole.fromWire(row['role'] as String?),
        status: MemberStatus.fromWire(row['status'] as String?),
        isMe: row.intOr('is_me', 0) == 1,
        joinedAt: row.dateTime('joined_at'),
        leftAt: row.nullableDateTime('left_at'),
        sortOrder: row.intOr('sort_order', 0),
        createdAt: row.dateTime('created_at'),
        updatedAt: row.dateTime('updated_at'),
        deletedAt: row.nullableDateTime('deleted_at'),
        revision: row.intOr('revision', 1),
        deviceId: row['device_id']! as String,
        baseRevision: row.intOr('base_revision', 0),
      );

  EntryParticipant _participantFromRow(Map<String, Object?> row) => EntryParticipant(
        id: row['id']! as String,
        entryId: row['entry_id']! as String,
        bookId: row['book_id']! as String,
        memberId: row['member_id']! as String,
        sortOrder: row.intOr('sort_order', 0),
        createdAt: row.dateTime('created_at'),
        updatedAt: row.dateTime('updated_at'),
        deletedAt: row.nullableDateTime('deleted_at'),
        revision: row.intOr('revision', 1),
        deviceId: row['device_id']! as String,
        baseRevision: row.intOr('base_revision', 0),
      );

  Map<String, Object?> _participantPayload(EntryParticipant p) => {
        'id': p.id,
        'entry_id': p.entryId,
        'book_id': p.bookId,
        'member_id': p.memberId,
        'sort_order': p.sortOrder,
        'created_at': p.createdAt.millisecondsSinceEpoch,
        'updated_at': p.updatedAt.millisecondsSinceEpoch,
        'deleted_at': p.deletedAt?.millisecondsSinceEpoch,
        'revision': p.revision,
        'device_id': p.deviceId,
        'base_revision': p.baseRevision,
      };

  Map<String, Object?> _payload(Member m) => {
        'id': m.id,
        'book_id': m.bookId,
        'name': m.name,
        'role': m.role.wire,
        'status': m.status.wire,
        'is_me': m.isMe,
        // 生命周期字段也要同步：漏列会让对端看不到「已退出」与加入时间，
        // AC4 的「已退出成员」在另一台设备上就显示不出来（audit 2026-10-15）
        'joined_at': m.joinedAt.millisecondsSinceEpoch,
        'left_at': m.leftAt?.millisecondsSinceEpoch,
        'sort_order': m.sortOrder,
      };
}
