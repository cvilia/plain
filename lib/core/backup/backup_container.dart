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
import 'package:plain/app/l10n/app_strings.dart';
import 'package:plain/app/l10n/strings_core.dart';
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
  required AppStrings s,
  required String sourceDbPath,
  required String outPath,
  required String password,
  String? sourceKeyLiteral,
}) async {
  final src = File(sourceDbPath);
  if (!src.existsSync()) {
    throw FileSystemException(s.backupSourceMissing, sourceDbPath);
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

/// 恢复结果：明文库路径。
///
/// 附件功能已下线（原 STORY-1.5）：备份不再打包附件字节，恢复也不再写回。
/// 老备份里若带 `attachment_blobs` 表，会随 `attachments` 表一起被 DB 迁移清掉
/// 的口径处理——它只是副本里的暂存表，不进运行库的主表清单。
class BackupExtractResult {
  const BackupExtractResult({required this.dbPath});
  final String dbPath;
}

/// 恢复用：把备份解成明文库到 [outPath]。
Future<BackupExtractResult> extractBackup({
  required String backupPath,
  required String password,
  required String outPath,
}) async {
  final opened = await openEncryptedBackup(backupPath: backupPath, password: password);
  try {
    final esc = outPath.replaceAll("'", "''");
    opened.db.execute("VACUUM INTO '$esc'");
    return BackupExtractResult(dbPath: outPath);
  } finally {
    opened.close();
  }
}
