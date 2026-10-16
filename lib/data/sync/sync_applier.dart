/// STORY-8.1：把远端变更应用到本地库（三方合并 + 冲突落库）。
library;

import 'dart:convert';

import 'package:plain/core/id/uuid_v7.dart';
import 'package:plain/core/result/result.dart';
import 'package:plain/core/time/clock.dart';
import 'package:plain/data/db/column_writer.dart';
import 'package:plain/data/db/database.dart';
import 'package:plain/data/repositories/sync_conflict_repository.dart';
import 'package:plain/data/sync/change_log_writer.dart';
import 'package:plain/data/sync/sync_wire.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/entities/sync_conflict.dart';
import 'package:plain/domain/repositories/repositories.dart';
import 'package:plain/domain/services/merge_engine.dart';
import 'package:plain/domain/services/sync_scope.dart';

class SyncApplyStats {
  const SyncApplyStats({
    this.inserted = 0,
    this.updated = 0,
    this.deleted = 0,
    this.skipped = 0,
    this.conflicts = 0,
  });

  final int inserted;
  final int updated;
  final int deleted;
  final int skipped;
  final int conflicts;

  int get applied => inserted + updated + deleted;

  SyncApplyStats merge(SyncApplyStats other) => SyncApplyStats(
        inserted: inserted + other.inserted,
        updated: updated + other.updated,
        deleted: deleted + other.deleted,
        skipped: skipped + other.skipped,
        conflicts: conflicts + other.conflicts,
      );

  Map<String, int> toMap() => {
        'inserted': inserted,
        'updated': updated,
        'deleted': deleted,
        'skipped': skipped,
        'conflicts': conflicts,
      };
}

class SyncApplier {
  SyncApplier({
    required AppDatabase db,
    required LedgerRepository ledger,
    required SyncConflictRepositoryImpl conflicts,
    required UuidV7 idGen,
    required Clock clock,
    required String localDeviceId,
    ChangeLogWriter? changeLog,
  })  : _db = db,
        _ledger = ledger,
        _conflicts = conflicts,
        _idGen = idGen,
        _clock = clock,
        _localDeviceId = localDeviceId,
        _changeLog = changeLog;

  final AppDatabase _db;
  final LedgerRepository _ledger;
  final SyncConflictRepositoryImpl _conflicts;
  final UuidV7 _idGen;
  final Clock _clock;
  final String _localDeviceId;

  /// 仅用于「冲突裁决」：裁决是用户的显式决定，必须作为**本地变更**记一笔，
  /// 否则第三个设备永远看不到这次裁决结果。
  final ChangeLogWriter? _changeLog;

  String get localDeviceId => _localDeviceId;

  /// 按 `local_revision` 升序应用（同设备内顺序 = 因果顺序）。
  ///
  /// [writerDeviceId] 是**产出这份日志的设备**（日志文件名里带的那个），
  /// 不是记录里的 `device_id`——后者是实体归属设备（谁建的账单），
  /// 跨端改一笔别人建的账单时两者不同，混淆会把对端的改动当成自己的而整条跳过。
  Future<Result<SyncApplyStats>> applyAll(
    List<SyncRecord> records, {
    required String writerDeviceId,
  }) async {
    var stats = const SyncApplyStats();
    final sorted = [...records]..sort((a, b) => a.localRevision.compareTo(b.localRevision));
    for (final r in sorted) {
      final res = await apply(r, writerDeviceId: writerDeviceId);
      if (res.isFailure) return err(res.failureOrNull!);
      stats = stats.merge(res.requireValue);
    }
    return ok(stats);
  }

  Future<Result<SyncApplyStats>> apply(
    SyncRecord record, {
    required String writerDeviceId,
  }) async {
    // 自己写的日志不回头应用（防御性：正常情况下不会出现在别人的文件里）
    if (writerDeviceId == _localDeviceId) return ok(const SyncApplyStats(skipped: 1));
    if (record.entityType == 'setting') {
      return _applySetting(record, writerDeviceId: writerDeviceId);
    }

    final table = kEntityTables[record.entityType];
    if (table == null || !isSyncableTable(record.entityType)) {
      return ok(const SyncApplyStats(skipped: 1));
    }

    try {
      final localRow = _rowOf(table, record.entityId);

      if (record.op == ChangeOp.delete) {
        // 「已经删过」只对有 deleted_at 列的表成立——按列清单判断，不要直接读该列
        // （`currency_rates` 之类没有 deleted_at 的表读它会拿到 null，语义上也不是「已删」）。
        final softDeletable = ColumnWriter.columnsOf(_db, table).contains('deleted_at');
        if (localRow == null || (softDeletable && localRow['deleted_at'] != null)) {
          return ok(const SyncApplyStats(skipped: 1));
        }
        if (record.entityType == 'transaction') {
          final res = await _ledger.applySyncedEntry(
            id: record.entityId,
            softDelete: true,
            changedAt: record.changedAt,
          );
          if (res.isFailure) return err(res.failureOrNull!);
        } else {
          // 有 deleted_at 的表软删；没有该列的表（currency_rates）物理删——
          // 否则「解除汇率锁定」这类删除在对端静默无效。
          ColumnWriter.deleteRow(_db, table, record.entityId, record.changedAt);
        }
        return ok(const SyncApplyStats(deleted: 1));
      }

      final remote = record.after;
      if (remote.isEmpty) return ok(const SyncApplyStats(skipped: 1));

      // 本地没有 → 直接落地（无共同祖先，天然不冲突）
      if (localRow == null) {
        final cols = _withRevision(remote, revision: _intOf(remote['revision'], 1), base: record.baseRevision);
        await _write(record.entityType, table, record.entityId, cols);
        return ok(const SyncApplyStats(inserted: 1));
      }

      // 共同祖先 = 这条变更的 `before`（写入方语义：before 就是改动前的行）。
      // 新增（insert）的 before 是空的 → 没有祖先，天然不冲突。
      //
      // ⚠️ 不能用 `base_revision > 0` 来判断：新增落地后行的 base_revision 仍是 0，
      //    对端接着改一次，这条更新的 base_revision 也会是 0 —— 于是第三端
      //    会把一次普通修改误判成「无共同祖先」的冲突（实测：把该保留的本地改动覆盖掉）。
      final ancestry = record.before.isEmpty ? null : record.before;
      final localChangedAt =
          _dateOf(localRow['updated_at']) ?? _clock.now();
      final outcome = MergeEngine.merge(
        ancestor: ancestry,
        local: localRow,
        remote: remote,
        localChangedAt: localChangedAt,
        remoteChangedAt: record.changedAt,
        localDeviceId: _localDeviceId,
        // 平局用「产出日志的设备」判定：两端才能算出同一个赢家
        remoteDeviceId: writerDeviceId,
      );

      // ⚠️ 可空列要把 null 一起写下去：远端「清空备注 / 解绑账户」就是置空，
      // 过滤掉 null 等于这类改动永远传不到对端（audit 2026-10-15 发现）。
      // 非空列仍跳过（写了整条会失败，由 NOT NULL 兜底默认值）。
      final notNull = ColumnWriter.notNullColumnsOf(_db, table);
      final mergedColumns = {
        'id': record.entityId,
        for (final e in outcome.merged.entries)
          if (e.key != 'id' && (e.value != null || !notNull.contains(e.key)))
            e.key: e.value,
      };

      final localRev = _intOf(localRow['revision'], 1);
      final remoteRev = _intOf(remote['revision'], localRev);
      final base = localRev > remoteRev ? localRev : remoteRev;
      // 纯快进（结果与远端一致）→ 直接采用远端版本号；
      // 合并出了新值（本地在某些字段上胜出）→ 记成一个新版本。
      final tookRemoteWholesale = outcome.conflicts.isEmpty;
      final revision = tookRemoteWholesale ? base : base + 1;
      final differsFromLocal = !_sameValues(outcome.merged, localRow, table);
      if (!differsFromLocal && outcome.conflicts.isEmpty) {
        return ok(const SyncApplyStats(skipped: 1));
      }
      mergedColumns['revision'] = revision;
      mergedColumns['base_revision'] = base;
      // 审计列不参与仲裁：取更晚的 updated_at，created_at / device_id 保持本机原值
      final remoteUpdatedAt = _dateOf(remote['updated_at']);
      final newest = remoteUpdatedAt != null && remoteUpdatedAt.isAfter(localChangedAt)
          ? remoteUpdatedAt
          : localChangedAt;
      mergedColumns['updated_at'] = newest.millisecondsSinceEpoch;

      await _write(record.entityType, table, record.entityId, mergedColumns);

      var conflictCount = 0;
      for (final c in outcome.conflicts) {
        conflictCount += await _recordConflict(record, c, localRow, ancestry);
      }
      return ok(SyncApplyStats(
        updated: 1,
        conflicts: conflictCount,
      ));
    } on Exception catch (e) {
      return err(StorageFailure('db.sync_apply_failed', e.toString(), isRetryable: true));
    }
  }

  /// 可同步设置（`app_meta`）：主键是 key，走单独分支。
  Future<Result<SyncApplyStats>> _applySetting(
    SyncRecord record, {
    required String writerDeviceId,
  }) async {
    try {
      final key = (record.after['key'] as String?) ?? record.entityId;
      if (key.isEmpty || !isSyncedSetting(key)) {
        return ok(const SyncApplyStats(skipped: 1));
      }
      final rows = _db.raw.select(
          'SELECT value, updated_at FROM app_meta WHERE key = ?', [key]);
      final localValue = rows.isEmpty ? null : (rows.first['value'] as String?);
      final remoteValue = record.after['value'] as String?;
      if (remoteValue == null || localValue == remoteValue) {
        return ok(const SyncApplyStats(skipped: 1));
      }

      final ancestor = record.before.isEmpty ? null : (record.before['value'] as String?);
      if (ancestor != null && localValue == ancestor) {
        _writeSetting(key, remoteValue);
        return ok(const SyncApplyStats(updated: 1));
      }
      if (ancestor != null && remoteValue == ancestor) {
        return ok(const SyncApplyStats(skipped: 1));
      }

      final localAt = rows.isEmpty
          ? _clock.now()
          : (_dateOf(rows.first['updated_at']) ?? _clock.now());
      final winner = MergeEngine.winnerOf(
        localChangedAt: localAt,
        remoteChangedAt: record.changedAt,
        localDeviceId: _localDeviceId,
        remoteDeviceId: writerDeviceId,
      );
      if (winner == ConflictWinner.remote) {
        _writeSetting(key, remoteValue);
      }
      final conflict = await _conflicts.insert(SyncConflict(
        id: _idGen.generate(at: _clock.now()),
        bookId: '',
        entityType: 'setting',
        entityId: key,
        field: 'value',
        ancestorValue: ancestor,
        localValue: localValue,
        remoteValue: remoteValue,
        localPayload: jsonEncode({'key': key, 'value': localValue ?? ''}),
        remotePayload: jsonEncode({'key': key, 'value': remoteValue}),
        localChangedAt: localAt,
        remoteChangedAt: record.changedAt,
        winner: winner.wire,
        createdAt: _clock.now(),
      ));
      return ok(SyncApplyStats(updated: 1, conflicts: conflict.isSuccess ? 1 : 0));
    } on Exception catch (e) {
      return err(StorageFailure('db.sync_apply_failed', e.toString(), isRetryable: true));
    }
  }

  void _writeSetting(String key, String value) {
    _db.raw.execute(
      'INSERT INTO app_meta (key,value,updated_at) VALUES (?,?,?) '
      'ON CONFLICT(key) DO UPDATE SET value=?,updated_at=?',
      [
        key, value, _clock.now().millisecondsSinceEpoch,
        value, _clock.now().millisecondsSinceEpoch,
      ],
    );
  }

  /// 裁决用：按指定快照**强制写入**（不做合并）。
  ///
  /// 用户已经在冲突中心明确表态，这里只负责把那一版落回去，并把版本号推高
  /// （`updated_at` 取当前时间）— 让这次裁决成为「最后写入」，不会被下一轮同步翻回去。
  Future<Result<void>> forceWrite({
    required String entityType,
    required String entityId,
    required Map<String, Object?> payload,
  }) async {
    try {
      if (entityType == 'setting') {
        final key = (payload['key'] as String?) ?? entityId;
        final value = payload['value'] as String?;
        if (key.isNotEmpty && value != null) _writeSetting(key, value);
        return ok(null);
      }
      final table = kEntityTables[entityType];
      if (table == null || !isSyncableTable(entityType)) {
        return err<void>(const ValidationFailure('sync.unsupported_entity', 'entity'));
      }
      final localRow = _rowOf(table, entityId);
      final localRev = _intOf(localRow?['revision'], 0);
      final columns = <String, Object?>{
        for (final e in payload.entries)
          if (e.key != 'id' && e.value != null) e.key: e.value,
        'id': entityId,
        'revision': localRev + 1,
        'base_revision': localRev,
        'updated_at': _clock.now().millisecondsSinceEpoch,
      };
      await _write(entityType, table, entityId, columns);
      // 裁决要作为本地变更传出去（第三端才能看到）
      _changeLog?.write(
        entityType: EntityType.fromWire(entityType),
        entityId: entityId,
        op: ChangeOp.update,
        deviceId: _localDeviceId,
        baseRevision: localRev,
        before: localRow ?? const {},
        after: columns,
      );
      return ok(null);
    } on Exception catch (e) {
      return err(StorageFailure('db.sync_apply_failed', e.toString(), isRetryable: true));
    }
  }

  /// 账单走仓储（维护 daily_stats / 信用卡欠款）；其余表直接列写。
  Future<void> _write(
    String entityType,
    String table,
    String id,
    Map<String, Object?> columns,
  ) async {
    if (entityType == 'transaction') {
      final res = await _ledger.applySyncedEntry(
        id: id,
        softDelete: false,
        changedAt: _clock.now(),
        columns: columns,
      );
      if (res.isFailure) {
        throw StateError(res.failureOrNull!.code);
      }
      return;
    }
    ColumnWriter.upsert(_db, table, columns);
  }

  Future<int> _recordConflict(
    SyncRecord record,
    FieldConflict field,
    Map<String, Object?> localRow,
    Map<String, Object?>? ancestry,
  ) async {
    final localValue = field.localValue?.toString();
    final remoteValue = field.remoteValue?.toString();
    final dup = await _conflicts.exists(
      entityType: record.entityType,
      entityId: record.entityId,
      field: field.field,
      localValue: localValue,
      remoteValue: remoteValue,
    );
    if (dup.successOrNull == true) return 0;

    final res = await _conflicts.insert(SyncConflict(
      id: _idGen.generate(at: _clock.now()),
      bookId: (localRow['book_id'] as String?) ?? '',
      entityType: record.entityType,
      entityId: record.entityId,
      field: field.field,
      ancestorValue: field.ancestorValue?.toString(),
      localValue: localValue,
      remoteValue: remoteValue,
      // 两份完整快照：裁决时按原样重放（含 id / book_id）
      localPayload: jsonEncode({...localRow, 'id': record.entityId}),
      remotePayload: jsonEncode({...record.after, 'id': record.entityId}),
      localChangedAt: _dateOf(localRow['updated_at']),
      remoteChangedAt: record.changedAt,
      winner: field.winner.wire,
      createdAt: _clock.now(),
    ));
    return res.isSuccess ? 1 : 0;
  }

  Map<String, Object?>? _rowOf(String table, String id) {
    final rows = _db.raw.select('SELECT * FROM $table WHERE id = ?', [id]);
    return rows.isEmpty ? null : rows.first;
  }

  Map<String, Object?> _withRevision(
    Map<String, Object?> payload, {
    required int revision,
    required int base,
  }) {
    final out = <String, Object?>{
      for (final e in payload.entries)
        if (e.value != null) e.key: e.value,
    };
    out['revision'] = revision;
    out['base_revision'] = base;
    return out;
  }

  bool _sameValues(
    Map<String, Object?> merged,
    Map<String, Object?> localRow,
    String table,
  ) {
    final allowed = ColumnWriter.columnsOf(_db, table);
    for (final e in merged.entries) {
      if (!allowed.contains(e.key)) continue;
      final l = localRow[e.key];
      final a = e.value is bool ? ((e.value! as bool) ? 1 : 0) : e.value;
      final b = l is bool ? (l ? 1 : 0) : l;
      // null 也要比：把「远端置空」当成「没变化」会让清空类改动静默丢失
      if (a != b) return false;
    }
    return true;
  }

  static int _intOf(Object? v, int fallback) =>
      v is num ? v.toInt() : (v is String ? (int.tryParse(v) ?? fallback) : fallback);

  static DateTime? _dateOf(Object? v) {
    if (v is num) return DateTime.fromMillisecondsSinceEpoch(v.toInt(), isUtc: true);
    if (v is String) {
      final n = int.tryParse(v);
      if (n != null) return DateTime.fromMillisecondsSinceEpoch(n, isUtc: true);
    }
    return null;
  }
}
