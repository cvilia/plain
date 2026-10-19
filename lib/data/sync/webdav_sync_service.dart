/// WebDAV sync service: upload/download database backup.
/// Simple full-file sync for V1.2. Incremental change_log sync comes later.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:plain/app/l10n/app_strings.dart';
import 'package:plain/app/l10n/strings_core.dart';
import 'package:plain/core/logging/app_log.dart';
import 'package:plain/data/db/database.dart';
import 'package:plain/data/sync/webdav_client.dart';

class WebDavSyncResult {
  const WebDavSyncResult({
    required this.success,
    this.message,
    this.fileSize,
    this.syncedAt,
  });
  final bool success;
  final String? message;
  final int? fileSize;
  final DateTime? syncedAt;
}

class WebDavSyncService {
  WebDavSyncService({
    required AppDatabase db,
    required WebDavClient client,
    AppLog? log,
    AppStrings? strings,
  })  : _db = db, _client = client, _log = log, _s = strings ?? kDefaultAppStrings;

  final AppDatabase _db;
  final WebDavClient _client;
  final AppLog? _log;

  /// 返回给 UI 展示的文案来源。UI 应传 `AppStrings.of(context)`；
  /// 后台/无 context 场景回退到 [kDefaultAppStrings]。
  final AppStrings _s;

  static const String _backupFileName = 'plain_sync.db';

  /// Upload current database as a backup to WebDAV.
  Future<WebDavSyncResult> upload(WebDavConfig config) async {
    try {
      final ok = await _client.ensureCollection(config);
      if (!ok) return WebDavSyncResult(success: false, message: _s.remoteDirCreateFailed);

      final docsDir = await getApplicationDocumentsDirectory();
      final tmpPath = p.join(docsDir.path, 'sync_upload_${DateTime.now().millisecondsSinceEpoch}.db');
      // VACUUM INTO requires a literal path — escape quotes (same as backup_page).
      final escaped = tmpPath.replaceAll("'", "''");
      _db.raw.execute("VACUUM INTO '$escaped'");

      final file = File(tmpPath);
      if (!await file.exists()) {
        return WebDavSyncResult(success: false, message: _s.backupFileGenFailed);
      }
      final bytes = await file.readAsBytes();
      final size = bytes.length;
      await file.delete();

      final uploaded = await _client.put(config, _backupFileName, bytes);
      if (!uploaded) return WebDavSyncResult(success: false, message: _s.uploadFailed);

      _log?.info('webdav.upload', fields: {'size': size});
      return WebDavSyncResult(
    success: true,
    message: _s.uploadSuccess,
    fileSize: size,
    syncedAt: DateTime.now().toUtc(),
  );
    } on Exception catch (e) {
      return WebDavSyncResult(success: false, message: _s.uploadException(e));
    }
  }

  /// Download backup from WebDAV and replace local database.
  /// Returns success/failure with message.
  Future<WebDavSyncResult> download(WebDavConfig config) async {
    try {
      final bytes = await _client.get(config, _backupFileName);
      if (bytes == null || bytes.isEmpty) {
        return WebDavSyncResult(success: false, message: _s.remoteNoBackup);
      }

      final docsDir = await getApplicationDocumentsDirectory();
      final tmpPath = p.join(docsDir.path, 'sync_download_${DateTime.now().millisecondsSinceEpoch}.db');
      await File(tmpPath).writeAsBytes(bytes);

      // Verify it's a valid SQLite file
      final tmpFile = File(tmpPath);
      final header = await tmpFile.open();
      try {
        final sig = await header.read(16);
        final sigStr = String.fromCharCodes(sig);
        if (!sigStr.startsWith('SQLite format 3')) {
          await tmpFile.delete();
          return WebDavSyncResult(success: false, message: _s.remoteInvalidDb);
        }
      } finally {
        await header.close();
      }

      // Replace local database file
      final dbPath = p.join(docsDir.path, 'plain.sqlite');
      _db.close();

      // Backup current db just in case
      final bakPath = '$dbPath.bak';
      if (await File(dbPath).exists()) {
        await File(dbPath).copy(bakPath);
      }

      // Write WAL checkpoint before replace is handled by close()
      await tmpFile.copy(dbPath);
      await tmpFile.delete();

      return WebDavSyncResult(
    success: true,
    message: _s.downloadSuccessRestart,
    fileSize: bytes.length,
    syncedAt: DateTime.now().toUtc(),
  );
    } on Exception catch (e) {
      return WebDavSyncResult(success: false, message: _s.downloadException(e));
    }
  }

  /// Test WebDAV connection.
  Future<bool> testConnection(WebDavConfig config) => _client.testConnection(config);

  void dispose() => _client.dispose();
}
