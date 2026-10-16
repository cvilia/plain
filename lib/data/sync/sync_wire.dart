/// STORY-8.1 增量同步的线上格式与范围过滤。
library;

import 'dart:convert';

import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/services/sync_scope.dart';

/// 一条可同步的变更（change_log 的行形态）。
class SyncRecord {
  const SyncRecord({
    required this.localRevision,
    required this.entityType,
    required this.entityId,
    required this.op,
    required this.deviceId,
    required this.baseRevision,
    required this.changedAt,
    required this.before,
    required this.after,
  });

  /// 来源设备上这条记录的序号（位点比较用）。
  final int localRevision;
  final String entityType;
  final String entityId;
  final ChangeOp op;
  final String deviceId;
  final int baseRevision;
  final DateTime changedAt;

  /// 变更前的列值（= 共同祖先；删除时非空，新增时为空）。
  final Map<String, Object?> before;

  /// 变更后的列值（删除时为空）。
  final Map<String, Object?> after;

  Map<String, Object?> toJson() => {
        'r': localRevision,
        't': entityType,
        'id': entityId,
        'op': op.wire,
        'dev': deviceId,
        'base': baseRevision,
        'at': changedAt.millisecondsSinceEpoch,
        'before': before,
        'after': after,
      };

  static SyncRecord? fromJson(Map<String, Object?> json) {
    final type = json['t'] as String?;
    final id = json['id'] as String?;
    final data = json['after'] as Map<String, Object?>? ?? const {};
    final before = json['before'] as Map<String, Object?>? ?? const {};
    if (type == null || id == null) return null;
    return SyncRecord(
      localRevision: (json['r'] as num?)?.toInt() ?? 0,
      entityType: type,
      entityId: id,
      op: ChangeOp.fromWire(json['op'] as String?),
      deviceId: (json['dev'] as String?) ?? '',
      baseRevision: (json['base'] as num?)?.toInt() ?? 0,
      changedAt: DateTime.fromMillisecondsSinceEpoch(
          (json['at'] as num?)?.toInt() ?? 0, isUtc: true),
      before: _asMap(before),
      after: _asMap(data),
    );
  }

  static Map<String, Object?> _asMap(Map<String, Object?> m) =>
      {for (final e in m.entries) e.key: e.value};
}

class SyncWire {
  /// 一台设备一个日志文件，逐行一条 JSON（JSONL）。
  static List<int> encodeLines(List<SyncRecord> records) {
    final buf = StringBuffer();
    for (final r in records) {
      buf.writeln(jsonEncode(r.toJson()));
    }
    return utf8.encode(buf.toString());
  }

  static List<SyncRecord> decodeLines(List<int> bytes) {
    final text = utf8.decode(bytes, allowMalformed: true);
    final out = <SyncRecord>[];
    for (final line in text.split('\n')) {
      final t = line.trim();
      if (t.isEmpty) continue;
      try {
        final json = jsonDecode(t);
        if (json is! Map<String, Object?>) continue;
        final rec = SyncRecord.fromJson(json);
        if (rec != null) out.add(rec);
      } on FormatException {
        // 单行坏了不影响其余
      }
    }
    return out;
  }

  /// AC5：只留同步范围内的记录。
  ///
  /// 本地偏好（主题 / 外观模式 / 首页卡片布局 / 记账页布局）根本不在
  /// `kSyncedEntityTypes` 里，因此**不可能**出现在上传内容中。
  static List<SyncRecord> filterSyncable(List<SyncRecord> records) =>
      [for (final r in records) if (isSyncableTable(r.entityType)) r];

  /// 上传内容里出现这些键就是越界（AC5 的断言口径）。
  static const List<String> forbiddenKeys = [
    'themeId',
    'themeMode',
    'homeCardLayout',
    'entryLayout',
  ];
}
