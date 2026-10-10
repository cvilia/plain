/// 06-C3：change_log GC（30 天 / 5 万行）。
library;
import 'package:flutter_test/flutter_test.dart';
import 'package:plain/data/db/database.dart';
import 'package:plain/data/repositories/change_log_repository.dart';

void main() {
  late AppDatabase db;
  late ChangeLogRepository repo;

  setUp(() {
    db = AppDatabase.inMemory();
    repo = ChangeLogRepository(db);
  });

  tearDown(() => db.close());

  void insertLog({required int rev, required int changedAtMs}) {
    db.raw.execute(
      'INSERT INTO change_log (local_revision,entity_type,entity_id,op,device_id,base_revision,payload,payload_hash,changed_at) '
      "VALUES (?, 'transaction', 'e$rev', 'insert', 'd1', 0, '{}', 'h', ?)",
      [rev, changedAtMs],
    );
  }

  test('GC drops rows older than 30 days', () async {
    final now = DateTime.utc(2026, 9, 30);
    final oldMs = now.subtract(const Duration(days: 40)).millisecondsSinceEpoch;
    final freshMs = now.subtract(const Duration(days: 1)).millisecondsSinceEpoch;
    insertLog(rev: 1, changedAtMs: oldMs);
    insertLog(rev: 2, changedAtMs: freshMs);

    final r = await repo.gc(now: now);
    expect(r.isSuccess, true);
    expect(r.successOrNull, 1);
    final left = db.raw.select('SELECT COUNT(*) AS c FROM change_log');
    expect(left.first['c'], 1);
  });

  test('GC keeps newest maxRows when over cap', () async {
    final now = DateTime.utc(2026, 9, 30);
    final freshMs = now.millisecondsSinceEpoch;
    for (var i = 1; i <= 10; i++) {
      insertLog(rev: i, changedAtMs: freshMs);
    }
    final r = await repo.gc(now: now, maxRows: 4);
    expect(r.isSuccess, true);
    final left = db.raw.select(
        'SELECT local_revision FROM change_log ORDER BY local_revision DESC');
    expect(left.length, 4);
    expect(left.first['local_revision'], 10);
    expect(left.last['local_revision'], 7);
  });

  test('GC is a no-op when under limits', () async {
    final now = DateTime.utc(2026, 9, 30);
    insertLog(rev: 1, changedAtMs: now.millisecondsSinceEpoch);
    final r = await repo.gc(now: now);
    expect(r.successOrNull, 0);
  });

  test('native lib exposes SQLCipher cipher_version (C6)', () {
    // pubspec hooks.user_defines.sqlite3.source = sqlcipher
    final rows = db.raw.select('PRAGMA cipher_version');
    expect(rows, isNotEmpty,
        reason: 'SQLCipher library should report cipher_version');
  });
}
