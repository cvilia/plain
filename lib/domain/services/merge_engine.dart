/// STORY-8.1 账单级三方合并（基于共同祖先）。
///
/// 纯函数，不碰数据库。输入三份**列形态**的 payload（键 = 表列名）：
/// - [ancestor]：远端这条变更所基于的版本（即远端 change_log 里的 `before`）
/// - [local]：本机当前行的列值
/// - [remote]：远端这条变更的结果（`after`）
///
/// 规则（PRD AC2/AC3）：
/// - 只有一边改了 → 取改过的那边（**不产生冲突**）
/// - 两边改成同一个值 → 取该值
/// - 两边改成不同值 → 冲突：**最后写入者胜**，并记一条冲突待用户裁决
///
/// ⚠️ 时间戳完全相同时不能各自判「本地胜」——那样两端会各自留下自己的版本，
/// 永久分叉。因此平局用 deviceId 字典序兜底，两端算出同一个赢家。
library;

enum ConflictWinner {
  local('local'),
  remote('remote');

  const ConflictWinner(this.wire);
  final String wire;
}

class FieldConflict {
  const FieldConflict({
    required this.field,
    required this.ancestorValue,
    required this.localValue,
    required this.remoteValue,
    required this.winner,
  });

  final String field;
  final Object? ancestorValue;
  final Object? localValue;
  final Object? remoteValue;
  final ConflictWinner winner;
}

class MergeOutcome {
  const MergeOutcome({required this.merged, required this.conflicts});

  /// 合并后的列值。
  final Map<String, Object?> merged;

  /// 需要用户裁决的字段冲突（空 = 无冲突）。
  final List<FieldConflict> conflicts;

  bool get hasConflicts => conflicts.isNotEmpty;
}

class MergeEngine {
  /// 这些列是**本地记账**，不参与字段级仲裁也不报冲突：
  /// - `revision` / `base_revision`：由落库方按合并结果自己算
  /// - `updated_at` / `created_at` / `device_id`：审计列，取「更晚的 updated_at」
  ///
  /// 之前把它们当普通字段比，结果同一笔账单的两端时间戳必然不同 →
  /// 每次同步都凭空多出一条 `updated_at` 冲突（实测：一次改动冒出 2 条冲突）。
  static const Set<String> managedFields = {
    'id',
    'revision',
    'base_revision',
    'updated_at',
    'created_at',
    'device_id',
  };

  /// 字段级三方合并。
  ///
  /// [localChangedAt] 本机该行的 `updated_at`；[remoteChangedAt] 远端记录的
  /// `changed_at`（谁更晚谁赢）。
  static MergeOutcome merge({
    Map<String, Object?>? ancestor,
    required Map<String, Object?> local,
    required Map<String, Object?> remote,
    required DateTime localChangedAt,
    required DateTime remoteChangedAt,
    String localDeviceId = '',
    String remoteDeviceId = '',
  }) {
    final merged = <String, Object?>{};
    final conflicts = <FieldConflict>[];

    final fields = <String>{
      ...local.keys,
      ...remote.keys,
      if (ancestor != null) ...ancestor.keys,
    };

    for (final f in fields) {
      if (managedFields.contains(f)) continue;
      final l = local[f];
      final r = remote[f];
      if (_same(l, r)) {
        merged[f] = l;
        continue;
      }
      if (ancestor != null) {
        final a = ancestor[f];
        if (_same(l, a)) {
          // 本地没动，远端改了
          merged[f] = r;
          continue;
        }
        if (_same(r, a)) {
          // 远端没动，本地改了
          merged[f] = l;
          continue;
        }
      }
      // 两边都动了且不同 → 冲突，最后写入者胜
      final winner = _winnerOf(
        localChangedAt: localChangedAt,
        remoteChangedAt: remoteChangedAt,
        localDeviceId: localDeviceId,
        remoteDeviceId: remoteDeviceId,
      );
      merged[f] = winner == ConflictWinner.local ? l : r;
      conflicts.add(FieldConflict(
        field: f,
        ancestorValue: ancestor?[f],
        localValue: l,
        remoteValue: r,
        winner: winner,
      ));
    }

    return MergeOutcome(merged: merged, conflicts: conflicts);
  }

  /// 同一实体、无共同祖先（两端各自新建）时：整体冲突，最后写入者胜。
  static ConflictWinner winnerOf({
    required DateTime localChangedAt,
    required DateTime remoteChangedAt,
    String localDeviceId = '',
    String remoteDeviceId = '',
  }) =>
      _winnerOf(
        localChangedAt: localChangedAt,
        remoteChangedAt: remoteChangedAt,
        localDeviceId: localDeviceId,
        remoteDeviceId: remoteDeviceId,
      );

  static ConflictWinner _winnerOf({
    required DateTime localChangedAt,
    required DateTime remoteChangedAt,
    required String localDeviceId,
    required String remoteDeviceId,
  }) {
    if (remoteChangedAt.isAfter(localChangedAt)) return ConflictWinner.remote;
    if (localChangedAt.isAfter(remoteChangedAt)) return ConflictWinner.local;
    // 平局：deviceId 大者胜（两端必然算出同一结果）
    return remoteDeviceId.compareTo(localDeviceId) > 0
        ? ConflictWinner.remote
        : ConflictWinner.local;
  }

  /// 值相等判定：JSON 里的 `true/false` 与库里的 `1/0` 视为同一个值，
  /// `num` 之间按数值比较（1 == 1.0）。
  static bool _same(Object? a, Object? b) => _norm(a) == _norm(b);

  static Object? _norm(Object? v) {
    if (v is bool) return v ? 1 : 0;
    if (v is num) return v;
    return v;
  }
}
