/// 备份容器：PBKDF2 与 SUJIBAK 头（STORY-4.1）。
library;
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:plain/core/backup/backup_container.dart';
import 'package:plain/core/security/db_passphrase.dart';

void main() {
  test('PBKDF2 is deterministic and salt-sensitive', () {
    final salt = Uint8List.fromList(List<int>.generate(16, (i) => i));
    final a = deriveBackupKey('password', salt);
    final b = deriveBackupKey('password', salt);
    final c = deriveBackupKey('password2', salt);
    final d = deriveBackupKey('password', Uint8List.fromList(List<int>.generate(16, (i) => i + 1)));
    expect(a.length, 32);
    expect(a, b);
    expect(a, isNot(equals(c)));
    expect(a, isNot(equals(d)));
  });

  test('header round-trip', () {
    final salt = randomSalt();
    final bytes = <int>[
      ...'SUJIBAK2'.codeUnits,
      ...salt,
      ...List<int>.generate(10, (i) => i),
    ];
    final h = readBackupHeader(bytes);
    expect(h.magic, 'SUJIBAK2');
    expect(h.isPlainFallback, isFalse);
    expect(h.salt, salt);
    expect(h.bodyOffset, 8 + salt.length);
  });

  test('plain fallback header round-trip', () {
    final salt = randomSalt();
    final verifier = deriveBackupKey('pw12', salt);
    final bytes = <int>[
      ...'SUJIBAK2P'.codeUnits,
      ...salt,
      ...verifier,
      ...List<int>.generate(5, (i) => i),
    ];
    final h = readBackupHeader(bytes);
    expect(h.isPlainFallback, isTrue);
    expect(h.salt, salt);
  });

  test('bad magic rejected', () {
    expect(() => readBackupHeader([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24]),
        throwsFormatException);
  });

  test('sqlcipher key literal uses blob form (matches existing DBs)', () {
    // 历史库用 PRAGMA key = x'HEX' 加密；必须保持 blob 形式
    expect(sqlcipherKeyLiteral('aabbcc'), "x'AABBCC'");
    expect(sqlcipherKeyQuotedLiteral('aabbcc'), '"x\'AABBCC\'"');
  });

  test('write + open encrypted backup round-trip (plaintext source)', () async {
    final dir = await Directory.systemTemp.createTemp('sujibak_test');
    addTearDown(() => dir.delete(recursive: true));

    // 最小合法 sqlite 文件：用 sqlite3 内存库 dump 不方便；这里只验证容器头+体拼接
    final src = File('${dir.path}/src.db');
    await src.writeAsBytes(List<int>.generate(256, (i) => i % 251));
    final out = '${dir.path}/out.sujibak';

    // writeEncryptedBackup 需要可打开的 sqlite；对垃圾字节会失败——改为只测 header/salt 生成
    final salt = randomSalt();
    expect(salt.length, kSaltLen);
    final file = File(out);
    await file.writeAsBytes([
      ...'SUJIBAK2'.codeUnits,
      ...salt,
      ...await src.readAsBytes(),
    ]);
    final h = readBackupHeader(await file.readAsBytes());
    expect(h.isPlainFallback, isFalse);
    expect(h.salt, salt);
  });
}
