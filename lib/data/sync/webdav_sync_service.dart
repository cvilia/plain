/// WebDAV sync service: upload/download database backup.
/// Simple full-file sync for V1.2. Incremental change_log sync comes later.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:plain/core/logging/app_log.dart';
import 'package:plain/data/db/database.dart';
import 'package:plain/data/sync/webdav_client.dart';

class WebDavSyncResult {
  const WebDavSyncResult({required this.success, this.message, this.fileSize});
  final bool success;
  final String? message;
  final int? fileSize;
}

class WebDavSyncService {
  WebDavSyncService({
    required AppDatabase db,
    required WebDavClient client,
    AppLog? log,
  })  : _db = db, _client = client, _log = log;

  final AppDatabase _db;
  final WebDavClient _client;
  final AppLog? _log;

  static const String _backupFileName = 'plain_sync.db';

  /// Upload current database as a backup to WebDAV.
  Future<WebDavSyncResult> upload(WebDavConfig config) async {
    try {
      final ok = await _client.ensureCollection(config);
      if (!ok) return const WebDavSyncResult(success: false, message: '无法创建远程目录');

      final docsDir = await getApplicationDocumentsDirectory();
      final tmpPath = p.join(docsDir.path, 'sync_upload_${DateTime.now().millisecondsSinceEpoch}.db');
      _db.raw.execute("VACUUM INTO '$tmpPath'");

      final file = File(tmpPath);
      if (!await file.exists()) {
        return const WebDavSyncResult(success: false, message: '备份文件生成失败');
      }
      final bytes = await file.readAsBytes();
      final size = bytes.length;
      await file.delete();

      final uploaded = await _client.put(config, _backupFileName, bytes);
      if (!uploaded) return const WebDavSyncResult(success: false, message: '上传失败');

      _log?.info('webdav.upload', fields: {'size': size});
      return WebDavSyncResult(success: true, message: '上传成功', fileSize: size);
    } on Exception catch (e) {
      return WebDavSyncResult(success: false, message: '上传异常: $e');
    }
  }

  /// Download backup from WebDAV and replace local database.
  /// Returns success/failure with message.
  Future<WebDavSyncResult> download(WebDavConfig config) async {
    try {
      final bytes = await _client.get(config, _backupFileName);
      if (bytes == null || bytes.isEmpty) {
        return const WebDavSyncResult(success: false, message: '远程无备份文件或下载失败');
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
          return const WebDavSyncResult(success: false, message: '远程文件不是有效的数据库');
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

      return WebDavSyncResult(success: true, message: '下载成功，请重启应用', fileSize: bytes.length);
    } on Exception catch (e) {
      return WebDavSyncResult(success: false, message: '下载异常: $e');
    }
  }

  /// Test WebDAV connection.
  Future<bool> testConnection(WebDavConfig config) => _client.testConnection(config);

  void dispose() => _client.dispose();
}
