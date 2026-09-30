/// Sync provider abstraction. See 04-6.2.
/// Pluggable sync channels: WebDAV (V1.2), iCloud (V1.2), OfficialCloud (V2.0).
library;

/// Cursor into the change stream (local_revision watermark).
class SyncCursor {
  const SyncCursor({this.lastRevision = 0});
  final int lastRevision;

  SyncCursor advance(int to) => SyncCursor(lastRevision: to);
}

/// A single change record from change_log.
class ChangeRecord {
  const ChangeRecord({
    required this.localRevision,
    required this.entityType,
    required this.entityId,
    required this.op,
    required this.deviceId,
    required this.payload,
    required this.changedAtMs,
  });

  final int localRevision;
  final String entityType;
  final String entityId;
  final String op;
  final String deviceId;
  final String payload;
  final int changedAtMs;
}

/// Result of pushing a batch of changes.
class PushResult {
  const PushResult({required this.accepted, this.cursor, this.error});
  final int accepted;
  final SyncCursor? cursor;
  final String? error;
}

/// A batch of changes pulled from remote.
class PullBatch {
  const PullBatch({required this.changes, required this.cursor, this.hasMore = false});
  final List<ChangeRecord> changes;
  final SyncCursor cursor;
  final bool hasMore;
}

/// What the provider can do.
class ProviderCapability {
  const ProviderCapability({this.supportsServerMerge = false, this.supportsIncremental = false});
  final bool supportsServerMerge;
  final bool supportsIncremental;
}

/// Pluggable sync channel. Sync is a background consumer of change_log.
/// Business code must never call sync directly (04-6.4).
abstract interface class SyncProvider {
  Future<PushResult> push(List<ChangeRecord> batch, SyncCursor since);
  Future<PullBatch> pull(SyncCursor since);
  ProviderCapability get capability;
}
