/// STORY-8.1 增量同步：change_log → 远端 JSONL → 三方合并落库。
///
/// 传输仍是 WebDAV（本项目没有官方云服务端），但同步粒度从「整库文件」
/// 变成「**账单级变更**」：每台设备上传自己的日志文件，拉取别人的日志并按
/// `local_revision` 位点增量应用。整库文件级同步保留为「备份/换机」用，不再是同步主路径。
///
/// 延迟（AC1 ≤10s）：本地写入后立即 push + 前台每
/// [SyncRules.pollInterval] 轮询拉取。WebDAV 没有服务端推送通道，这是可达的最优解；
/// 换官方云时只替换本文件的传输部分。
library;

import 'dart:convert';

import 'package:plain/core/constants/app_constants.dart';
import 'package:plain/core/logging/app_log.dart';
import 'package:plain/core/time/clock.dart';
import 'package:plain/data/db/database.dart';
import 'package:plain/data/db/row_x.dart';
import 'package:plain/data/sync/change_log_writer.dart';
import 'package:plain/data/sync/sync_applier.dart';
import 'package:plain/data/sync/sync_wire.dart';
import 'package:plain/data/sync/webdav_client.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/services/sync_scope.dart';

class SyncRunResult {
  const SyncRunResult({
    required this.success,
    required this.pushed,
    required this.pulled,
    required this.conflicts,
    this.message,
    this.at,
  });

  final bool success;
  final int pushed;
  final int pulled;
  final int conflicts;
  final String? message;
  final DateTime? at;

  /// 任何一端发生了实际变更（决定要不要刷新界面）。
  bool get changed => pulled > 0;
}

class IncrementalSyncService {
  IncrementalSyncService({
    required AppDatabase db,
    required SyncTransport client,
    required SyncApplier applier,
    required Clock clock,
    required String deviceId,
    AppLog? log,
  })  : _db = db,
        _client = client,
        _applier = applier,
        _clock = clock,
        _deviceId = deviceId,
        _log = log;

  final AppDatabase _db;
  final SyncTransport _client;
  final SyncApplier _applier;
  final Clock _clock;
  final String _deviceId;
  final AppLog? _log;

  String get _fileName =>
      SyncRules.logFileNameOf(_deviceId, generation: _generation);

  /// 日志世代（设备本地事实，存 `sync_state`，不随备份还原搬走）。
  /// 备份还原后由 [invalidateSyncPeerView] 抬高，对端据此全量重放。
  int get _generation {
    final rows = _db.raw
        .select("SELECT value FROM sync_state WHERE key = 'log_gen'");
    if (rows.isEmpty) return 0;
    return int.tryParse(rows.first['value']! as String) ?? 0;
  }

  /// 推送：把本机**同步范围内**的 change_log 全量写成 JSONL 上传。
  ///
  /// 全量而不是增量：change_log 已被 GC 限制在 30 天 / 5 万行内，
  /// 而「哪些行已经推过」一旦记错就得做复杂补偿；重传是幂等的（对端按位点去重）。
  Future<SyncRunResult> push(WebDavConfig config) async {
    try {
      final ok = await _client.ensureCollection(config);
      if (!ok) {
        return const SyncRunResult(
            success: false, pushed: 0, pulled: 0, conflicts: 0, message: '无法创建远程目录');
      }
      final records = SyncWire.filterSyncable(_readLocalRecords());
      final bytes = SyncWire.encodeLines(records);
      final uploaded = await _client.put(config, _fileName, bytes);
      if (!uploaded) {
        return const SyncRunResult(
            success: false, pushed: 0, pulled: 0, conflicts: 0, message: '上传失败');
      }
      _log?.info('sync.push', fields: {'records': records.length});
      return SyncRunResult(
        success: true,
        pushed: records.length,
        pulled: 0,
        conflicts: 0,
        at: _clock.now(),
      );
    } on Exception catch (e) {
      return SyncRunResult(
          success: false, pushed: 0, pulled: 0, conflicts: 0, message: '推送异常: $e');
    }
  }

  /// 拉取：列目录 → 逐个别人的日志 → 按位点增量应用 → 推进位点。
  Future<SyncRunResult> pull(WebDavConfig config) async {
    try {
      final names = await _client.list(config);
      final others = <String>[];
      for (final n in names) {
        // 位点 key = 「设备 + 世代」：世代变了就是新文件，必须从 0 重放
        // （`generationKeyOf` 已排除本机自己的文件，含本机旧世代的）
        final key = SyncRules.generationKeyOf(n, _deviceId);
        if (key == null) continue;
        others.add(key);
      }
      if (others.isEmpty) {
        return SyncRunResult(
            success: true, pushed: 0, pulled: 0, conflicts: 0, at: _clock.now());
      }

      var pulled = 0;
      var conflicts = 0;
      for (final dev in others) {
        final bytes = await _client.get(config, SyncRules.logFileNameOf(dev));
        if (bytes == null || bytes.isEmpty) continue;
        final all = SyncWire.decodeLines(bytes);
        if (all.isEmpty) continue;
        final cursor = _cursorOf(dev);
        final fresh = [
          for (final r in SyncWire.filterSyncable(all))
            if (r.localRevision > cursor) r,
        ];
        // 位点推进到「已看过的最大序号」，**跳过的不再重扫**（否则每次都要重放）
        final maxSeen = all.fold<int>(cursor, (m, r) => r.localRevision > m ? r.localRevision : m);
        if (fresh.isNotEmpty) {
          final res = await _applier.applyAll(fresh, writerDeviceId: dev);
          if (res.isFailure) {
            return SyncRunResult(
              success: false,
              pushed: 0,
              pulled: pulled,
              conflicts: conflicts,
              message: res.failureOrNull!.code,
            );
          }
          pulled += res.requireValue.applied;
          conflicts += res.requireValue.conflicts;
        }
        _setCursor(dev, maxSeen);
      }
      _log?.info('sync.pull', fields: {'pulled': pulled, 'conflicts': conflicts});
      return SyncRunResult(
        success: true,
        pushed: 0,
        pulled: pulled,
        conflicts: conflicts,
        at: _clock.now(),
      );
    } on Exception catch (e) {
      return SyncRunResult(
          success: false, pushed: 0, pulled: 0, conflicts: 0, message: '拉取异常: $e');
    }
  }

  /// 一轮完整同步：先推后拉（先把自己的变更发布出去，再吸收别人的）。
  Future<SyncRunResult> syncNow(WebDavConfig config) async {
    final pushed = await push(config);
    if (!pushed.success) return pushed;
    final pulledRes = await pull(config);
    return SyncRunResult(
      success: pulledRes.success,
      pushed: pushed.pushed,
      pulled: pulledRes.pulled,
      conflicts: pulledRes.conflicts,
      message: pulledRes.message,
      at: pulledRes.at ?? _clock.now(),
    );
  }

  /// 用完即弃（内部持有 HttpClient）。
  void dispose() => _client.dispose();

  int _cursorOf(String deviceId) {    final rows = _db.raw.select('SELECT value FROM sync_state WHERE key = ?', ['cursor.$deviceId']);
    if (rows.isEmpty) return 0;
    return int.tryParse(rows.first['value']! as String) ?? 0;
  }

  void _setCursor(String deviceId, int revision) {
    _db.raw.execute(
      'INSERT INTO sync_state (key,value,updated_at) VALUES (?,?,?) '
      'ON CONFLICT(key) DO UPDATE SET value=?,updated_at=?',
      [
        'cursor.$deviceId', '$revision', _clock.now().millisecondsSinceEpoch,
        '$revision', _clock.now().millisecondsSinceEpoch,
      ],
    );
  }

  /// 本机 change_log 的**最新** [SyncRules.maxRecordsPerPush] 条（含 `before` / `after`）。
  ///
  /// ⚠️ 必须取最新而不是最旧：`LIMIT` 配 `ORDER BY local_revision` 升序会永远只发
  /// 最旧的 N 条，超过上限后的新变更**再也发不出去且不报错**（GC 上限 5 万行、
  /// 单次上限 2 万行，重度用户能踩到）。取最新则最坏情况是丢掉极旧的历史，
  /// 而对端早已应用过它们。
  List<SyncRecord> _readLocalRecords() {
    final rows = _db.raw.select(
      'SELECT local_revision, entity_type, entity_id, op, device_id, base_revision, '
      'payload, changed_at FROM change_log ORDER BY local_revision DESC LIMIT ?',
      [SyncRules.maxRecordsPerPush],
    ).toList().reversed.toList();
    final out = <SyncRecord>[];
    for (final row in rows) {
      final raw = (row['payload'] as String?) ?? '';
      if (raw.isEmpty) continue;
      Object? decoded;
      try {
        decoded = jsonDecode(raw);
      } on FormatException {
        continue;
      }
      if (decoded is! Map<String, Object?>) continue;
      final before = decoded['before'];
      final after = decoded['after'];
      out.add(SyncRecord(
        localRevision: row['local_revision']! as int,
        entityType: row['entity_type']! as String,
        entityId: row['entity_id']! as String,
        op: ChangeOp.fromWire(row['op'] as String?),
        deviceId: (row['device_id'] as String?) ?? _deviceId,
        baseRevision: row.intOr('base_revision', 0),
        changedAt: row.dateTime('changed_at'),
        before: before is Map<String, Object?> ? before : const {},
        after: after is Map<String, Object?> ? after : const {},
      ));
    }
    return out;
  }
}

/// 备份还原后调用：本机 change_log 被换成了备份里的旧行，而各端记的位点还在高位，
/// 若不换世代，「被还原掉的变更」就永远推不出去（对端位点 > 本机最大序号）。
/// 换一个日志文件名 = 对端把它当新设备，位点从 0 开始全量重放。
///
/// 世代存 `sync_state`（设备本地事实，不随备份搬运），因此还原不会把它带回旧值。
void invalidateSyncPeerView({required AppDatabase db, required Clock clock}) {
  final gen = clock.now().millisecondsSinceEpoch;
  db.raw.execute(
    'INSERT INTO sync_state (key,value,updated_at) VALUES (?,?,?) '
    'ON CONFLICT(key) DO UPDATE SET value=?,updated_at=?',
    ['log_gen', '$gen', gen, '$gen', gen],
  );
}

/// 可同步设置的写入（月起始日等）：值落 `app_meta` + 记一条 `setting` 变更。
///
/// ⚠️ 只有 [isSyncedSetting] 认可的键才会记；WebDAV 凭据这类键永远不出设备。
void writeSyncedSetting({
  required AppDatabase db,
  required ChangeLogWriter changeLog,
  required String deviceId,
  required String key,
  required String value,
  Clock? clock,
}) {
  final rows = db.raw.select('SELECT value FROM app_meta WHERE key = ?', [key]);
  final before = rows.isEmpty ? null : (rows.first['value'] as String?);
  if (!isSyncedSetting(key)) return;
  if (before == value) return;
  changeLog.write(
    entityType: EntityType.setting,
    entityId: key,
    op: ChangeOp.update,
    deviceId: deviceId,
    baseRevision: 0,
    before: before == null ? const {} : {'key': key, 'value': before},
    after: {'key': key, 'value': value},
  );
}
