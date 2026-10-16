/// STORY-1.5 AC4：附件随备份打包 / 还原。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:plain/core/backup/backup_container.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('plain_bak_attach');
  });

  tearDown(() async {
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  /// 造一个含 attachments 表的明文库（备份源）。
  Future<String> makeSourceDb() async {
    final path = '${tmp.path}/src.db';
    final db = sqlite3.open(path);
    db.execute('CREATE TABLE attachments (id TEXT PRIMARY KEY, stored_name TEXT NOT NULL, '
        'thumbnail_name TEXT NULL, deleted_at INTEGER NULL)');
    db.execute(
      "INSERT INTO attachments VALUES ('a1','a1.png','a1.thumb.png',NULL),"
      "('a2','a2.pdf',NULL,NULL),"
      // 已删除的附件不打包
      "('a3','a3.png',NULL,123)",
    );
    db.close();
    return path;
  }

  test('打包：附件字节写进副本的暂存表，已删除的不打包', () async {
    final src = await makeSourceDb();
    final dir = Directory('${tmp.path}/attachments')..createSync();
    File('${dir.path}/a1.png').writeAsBytesSync([1, 2, 3]);
    File('${dir.path}/a1.thumb.png').writeAsBytesSync([9]);
    File('${dir.path}/a2.pdf').writeAsBytesSync([4, 5]);
    File('${dir.path}/a3.png').writeAsBytesSync([6]);

    final packed = await packAttachmentsIntoCopy(dbCopyPath: src, attachmentDir: dir);
    expect(packed, 3); // a1 + a1.thumb + a2

    final db = sqlite3.open(src);
    final rows = db.select('SELECT name, bytes FROM $kAttachmentBlobTable ORDER BY name');
    expect(rows.length, 3);
    expect(rows.first['name'], 'a1.png');
    expect(rows.first['bytes'], [1, 2, 3]);
    expect(rows.any((r) => r['name'] == 'a3.png'), isFalse);
    db.close();
  });

  test('附件文件缺失时不阻断备份打包', () async {
    final src = await makeSourceDb();
    final dir = Directory('${tmp.path}/attachments')..createSync();
    // 只有 a1.png 在，a2.pdf 与缩略图都缺
    File('${dir.path}/a1.png').writeAsBytesSync([1, 2, 3]);
    expect(await packAttachmentsIntoCopy(dbCopyPath: src, attachmentDir: dir), 1);
  });

  test('备份 → 还原：附件字节原样回来', () async {
    final src = await makeSourceDb();
    final dir = Directory('${tmp.path}/attachments')..createSync();
    File('${dir.path}/a1.png').writeAsBytesSync([1, 2, 3]);
    File('${dir.path}/a2.pdf').writeAsBytesSync([7, 8, 9]);

    await packAttachmentsIntoCopy(dbCopyPath: src, attachmentDir: dir);
    final bak = '${tmp.path}/out.sujibak';
    await writeEncryptedBackup(sourceDbPath: src, outPath: bak, password: 'pw123456');

    // 模拟换机：附件目录是空的
    final fresh = Directory('${tmp.path}/fresh/attachments');
    final out = '${tmp.path}/restored.db';
    final r = await extractBackup(
      backupPath: bak,
      password: 'pw123456',
      outPath: out,
      attachmentDir: fresh,
    );

    expect(r.restoredAttachments, 2);
    expect(File('${fresh.path}/a1.png').readAsBytesSync(), [1, 2, 3]);
    expect(File('${fresh.path}/a2.pdf').readAsBytesSync(), [7, 8, 9]);
    expect(File(r.dbPath).existsSync(), isTrue);
    // 还原出来的库带着附件元数据
    final db = sqlite3.open(r.dbPath);
    final n = db.select('SELECT COUNT(*) AS c FROM attachments');
    expect(n.first['c'], 3);
    db.close();
  });

  test('老备份（没有附件表）还原时不报错，附件数为 0', () async {
    final path = '${tmp.path}/old.db';
    final db = sqlite3.open(path);
    db.execute('CREATE TABLE transactions (id TEXT PRIMARY KEY)');
    db.close();
    final bak = '${tmp.path}/old.sujibak';
    await writeEncryptedBackup(sourceDbPath: path, outPath: bak, password: 'pw123456');

    final r = await extractBackup(
      backupPath: bak,
      password: 'pw123456',
      outPath: '${tmp.path}/old_restored.db',
      attachmentDir: Directory('${tmp.path}/nowhere'),
    );
    expect(r.restoredAttachments, 0);
  });
}
