/// 备份文件容器（PRD STORY-4.1）。
/// 格式：`SUJIBAK2` 魔数 + SQLCipher 库字节（passphrase 模式，口令即备份密码）。
/// 不额外实现 AES：备份体用 SQLCipher `rekey` 到用户密码，与 App 同一引擎。
/// 若源库无法 rekey（无 SQLCipher），回退为「口令校验 + 原样封装」（SUJIBAK2P）。
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

const String kBackupMagic = 'SUJIBAK2';
const String kBackupMagicPlain = 'SUJIBAK2P';
const int kSaltLen = 16;
const int kPbkdf2Iterations = 100000;

/// PBKDF2-HMAC-SHA256 → 32 字节（口令校验用）。
Uint8List deriveBackupKey(String password, Uint8List salt, {int iterations = kPbkdf2Iterations}) {
  final mac = Hmac(sha256, utf8.encode(password));
  const hLen = 32;
  const dkLen = 32;
  final l = (dkLen / hLen).ceil();
  final output = BytesBuilder();
  for (var i = 1; i <= l; i++) {
    final block = Uint8List(4);
    final bd = ByteData.sublistView(block);
    bd.setUint32(0, i);
    var u = Uint8List.fromList(mac.convert([...salt, ...block]).bytes);
    final t = Uint8List.fromList(u);
    for (var c = 1; c < iterations; c++) {
      u = Uint8List.fromList(mac.convert(u).bytes);
      for (var j = 0; j < hLen; j++) {
        t[j] ^= u[j];
      }
    }
    output.add(t);
  }
  return output.toBytes().sublist(0, dkLen);
}

String _hex(Uint8List bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

/// SQL 字符串字面量：把密码放进 PRAGMA（转义单引号）。
String _sqlStr(String s) => "'${s.replaceAll("'", "''")}'";

Uint8List randomSalt() {
  final rnd = Random.secure();
  return Uint8List.fromList(List<int>.generate(kSaltLen, (_) => rnd.nextInt(256)));
}

class BackupOpenResult {
  const BackupOpenResult({required this.db, required this.tempPath});
  final Database db;
  final String tempPath;
  void close() {
    try {
      db.close();
    } catch (_) {}
    try {
      File(tempPath).deleteSync();
    } catch (_) {}
  }
}

class BackupHeader {
  const BackupHeader({required this.magic, required this.isPlainFallback, required this.salt, required this.bodyOffset});
  final String magic;
  final bool isPlainFallback;
  final Uint8List salt;
  final int bodyOffset;
}

/// 读魔数；兼容 SUJIBAK2（SQLCipher）与 SUJIBAK2P（口令校验+原样）。
BackupHeader readBackupHeader(List<int> bytes) {
  String magicAt(int n) => String.fromCharCodes(bytes.sublist(0, n));
  if (bytes.length < kBackupMagic.length + kSaltLen) {
    throw const FormatException('backup_truncated');
  }
  if (magicAt(kBackupMagicPlain.length) == kBackupMagicPlain) {
    final off = kBackupMagicPlain.length;
    return BackupHeader(
      magic: kBackupMagicPlain,
      isPlainFallback: true,
      salt: Uint8List.fromList(bytes.sublist(off, off + kSaltLen)),
      bodyOffset: off + kSaltLen,
    );
  }
  if (magicAt(kBackupMagic.length) != kBackupMagic) {
    throw const FormatException('backup_bad_magic');
  }
  return BackupHeader(
    magic: kBackupMagic,
    isPlainFallback: false,
    salt: Uint8List.fromList(bytes.sublist(kBackupMagic.length, kBackupMagic.length + kSaltLen)),
    bodyOffset: kBackupMagic.length + kSaltLen,
  );
}

/// 把 [sourceDbPath] 导出为带密码的备份到 [outPath]。
/// 返回 true 表示 SQLCipher 密文体；false 表示口令校验回退体（仍可导入）。
Future<bool> writeEncryptedBackup({
  required String sourceDbPath,
  required String outPath,
  required String password,
  String? sourceKeyLiteral,
}) async {
  final src = File(sourceDbPath);
  if (!src.existsSync()) {
    throw FileSystemException('备份源文件不存在', sourceDbPath);
  }
  final outDir = Directory(p.dirname(outPath));
  final tmp = File(p.join(outDir.path, '.sujibak_tmp_${DateTime.now().millisecondsSinceEpoch}'));
  await src.copy(tmp.path);

  Database? db;
  var usedSqlcipher = false;
  try {
    // 打开源库（设备密钥 / 明文）
    if (sourceKeyLiteral != null && sourceKeyLiteral.isNotEmpty) {
      try {
        final candidate = sqlite3.open(tmp.path);
        candidate.execute('PRAGMA key = $sourceKeyLiteral');
        candidate.select('SELECT count(*) FROM sqlite_master');
        db = candidate;
      } on Exception {
        // 换明文连接
      }
    }
    if (db == null) {
      final plain = sqlite3.open(tmp.path);
      try {
        plain.select('SELECT count(*) FROM sqlite_master');
        db = plain;
      } on Exception {
        try {
          plain.close();
        } catch (_) {}
        throw StateError('backup_source_unreadable');
      }
    }

    // rekey 到用户密码（passphrase 模式，SQLCipher 自带 KDF）
    try {
      db.execute('PRAGMA rekey = ${_sqlStr(password)}');
      db.select('SELECT count(*) FROM sqlite_master');
      usedSqlcipher = true;
    } on Exception {
      usedSqlcipher = false;
    }

    final body = await tmp.readAsBytes();
    final salt = randomSalt();
    final out = File(outPath);
    final sink = out.openWrite();
    if (usedSqlcipher) {
      sink.add(ascii.encode(kBackupMagic));
    } else {
      // 回退：口令校验（不改库体），导入时仍要密码
      sink.add(ascii.encode(kBackupMagicPlain));
    }
    sink.add(salt);
    if (!usedSqlcipher) {
      sink.add(deriveBackupKey(password, salt));
    }
    sink.add(body);
    await sink.flush();
    await sink.close();
    return usedSqlcipher;
  } finally {
    try {
      db?.close();
    } catch (_) {}
    try {
      tmp.deleteSync();
    } catch (_) {}
  }
}

/// 打开备份（预览 / 恢复）。密码错误抛 FormatException。
Future<BackupOpenResult> openEncryptedBackup({
  required String backupPath,
  required String password,
}) async {
  final bytes = await File(backupPath).readAsBytes();
  final header = readBackupHeader(bytes);

  if (header.isPlainFallback) {
    final verifier = bytes.sublist(header.bodyOffset, header.bodyOffset + 32);
    final expect = deriveBackupKey(password, header.salt);
    if (_hex(Uint8List.fromList(verifier)) != _hex(expect)) {
      throw const FormatException('backup_bad_password');
    }
    final body = bytes.sublist(header.bodyOffset + 32);
    final tmpPath = p.join(
      Directory.systemTemp.path,
      'sujibak_open_${DateTime.now().millisecondsSinceEpoch}.db',
    );
    await File(tmpPath).writeAsBytes(body);
    // 库体可能是明文或设备密钥；优先明文打开，失败则无法在本机直接读摘要
    final db = sqlite3.open(tmpPath);
    try {
      db.select('SELECT count(*) FROM sqlite_master');
      return BackupOpenResult(db: db, tempPath: tmpPath);
    } on Exception {
      try {
        db.close();
      } catch (_) {}
      // 让调用方按「文件已校验密码」路径 restoreFrom 原文件体
      rethrow;
    }
  }

  final body = bytes.sublist(header.bodyOffset);
  final tmpPath = p.join(
    Directory.systemTemp.path,
    'sujibak_open_${DateTime.now().millisecondsSinceEpoch}.db',
  );
  await File(tmpPath).writeAsBytes(body);
  final db = sqlite3.open(tmpPath);
  try {
    db.execute('PRAGMA key = ${_sqlStr(password)}');
    db.select('SELECT count(*) FROM sqlite_master');
    return BackupOpenResult(db: db, tempPath: tmpPath);
  } on Exception {
    try {
      db.close();
    } catch (_) {}
    try {
      File(tmpPath).deleteSync();
    } catch (_) {}
    throw const FormatException('backup_bad_password');
  }
}

/// 将备份体解出到 [outPath]（恢复用）。返回是否成功。
Future<String> extractBackupDb({
  required String backupPath,
  required String password,
  required String outPath,
}) async {
  final r = await extractBackup(
    backupPath: backupPath,
    password: password,
    outPath: outPath,
  );
  return r.dbPath;
}

/// STORY-1.5 AC4：附件随备份打包/还原用的暂存表名。
///
/// ⚠️ 这张表**只存在于备份副本里**：打包时把附件字节写进临时副本，
/// 运行库永远不含附件字节 —— 这样「附件不进云同步」（整库上传）
/// 与「附件计入备份」两条约束同时成立，且附图字节照样受 SQLCipher 加密。
const String kAttachmentBlobTable = 'attachment_blobs';

/// 恢复结果：明文库路径 + 还原的附件张数。
class BackupExtractResult {
  const BackupExtractResult({required this.dbPath, required this.restoredAttachments});
  final String dbPath;
  final int restoredAttachments;
}

/// 恢复用：把备份解成明文库到 [outPath]，并把附件字节写回 [attachmentDir]。
Future<BackupExtractResult> extractBackup({
  required String backupPath,
  required String password,
  required String outPath,
  Directory? attachmentDir,
}) async {
  final opened = await openEncryptedBackup(backupPath: backupPath, password: password);
  try {
    var restored = 0;
    if (attachmentDir != null) {
      restored = await _writeAttachmentBlobs(opened.db, attachmentDir);
    }
    final esc = outPath.replaceAll("'", "''");
    opened.db.execute("VACUUM INTO '$esc'");
    return BackupExtractResult(dbPath: outPath, restoredAttachments: restored);
  } finally {
    opened.close();
  }
}

/// 把附件目录里的文件写进**备份副本**（备份前调用）。返回打包张数。
///
/// [dbCopyPath] 是 VACUUM 出来的副本（可能是设备密钥加密的），
/// [attachmentDir] 是附件目录。表里没有的附件（文件被用户删了）跳过。
Future<int> packAttachmentsIntoCopy({
  required String dbCopyPath,
  required Directory attachmentDir,
  String? sourceKeyLiteral,
}) async {
  if (!attachmentDir.existsSync()) return 0;
  Database? db;
  try {
    if (sourceKeyLiteral != null && sourceKeyLiteral.isNotEmpty) {
      final candidate = sqlite3.open(dbCopyPath);
      try {
        candidate.execute('PRAGMA key = $sourceKeyLiteral');
        candidate.select('SELECT count(*) FROM sqlite_master');
        db = candidate;
      } on Exception {
        try {
          candidate.close();
        } catch (_) {}
      }
    }
    db ??= sqlite3.open(dbCopyPath);

    final rows = db.select(
      'SELECT stored_name, thumbnail_name FROM attachments WHERE deleted_at IS NULL',
    );
    db.execute(
      'CREATE TABLE IF NOT EXISTS $kAttachmentBlobTable ('
      'name TEXT NOT NULL PRIMARY KEY, bytes BLOB NOT NULL)',
    );
    var packed = 0;
    for (final r in rows) {
      for (final name in [r['stored_name'] as String?, r['thumbnail_name'] as String?]) {
        if (name == null || name.isEmpty) continue;
        final f = File(p.join(attachmentDir.path, name));
        if (!f.existsSync()) continue;
        db.execute(
          'INSERT OR REPLACE INTO $kAttachmentBlobTable (name, bytes) VALUES (?, ?)',
          [name, f.readAsBytesSync()],
        );
        packed++;
      }
    }
    return packed;
  } catch (_) {
    // 附件打包失败不该让整次备份失败：库还是要导出的
    return 0;
  } finally {
    try {
      db?.close();
    } catch (_) {}
  }
}

/// 把备份库里的附件字节写回附件目录。表不存在（老备份）→ 0。
Future<int> _writeAttachmentBlobs(Database db, Directory attachmentDir) async {
  final has = db.select(
    "SELECT name FROM sqlite_master WHERE type='table' AND name = ?",
    [kAttachmentBlobTable],
  );
  if (has.isEmpty) return 0;
  if (!attachmentDir.existsSync()) {
    await attachmentDir.create(recursive: true);
  }
  final rows = db.select('SELECT name, bytes FROM $kAttachmentBlobTable');
  var written = 0;
  for (final r in rows) {
    final name = r['name'] as String?;
    final bytes = r['bytes'];
    if (name == null || name.isEmpty || bytes is! List<int>) continue;
    try {
      await File(p.join(attachmentDir.path, name)).writeAsBytes(bytes, flush: true);
      written++;
    } on FileSystemException {
      // 单张写不进去不影响其余
    }
  }
  return written;
}
