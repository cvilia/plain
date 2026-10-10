/// Default cash account seed tests.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:plain/core/time/clock.dart';
import 'package:plain/data/db/database.dart';
import 'package:plain/data/seed/default_account.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.inMemory();
    addTearDown(db.close);
    // Seed function requires device.id in app_meta.
    db.raw.execute(
      "INSERT INTO app_meta (key,value,updated_at) VALUES ('device.id','dev-test',0)",
    );
  });

  test('seeds 现金 when accounts table is empty', () async {
    final id = await seedDefaultAccount(db, SystemClock());
    expect(id, 'default_cash');
    final rows = db.raw.select('SELECT * FROM accounts WHERE id = ?', ['default_cash']);
    expect(rows, hasLength(1));
    expect(rows.first['name'], '现金');
    expect(rows.first['type'], 'cash');
    expect(rows.first['opening_balance_cents'], 0);
    expect(rows.first['deleted_at'], isNull);
  });

  test('is idempotent — second call returns existing id, no duplicate', () async {
    await seedDefaultAccount(db, SystemClock());
    final id2 = await seedDefaultAccount(db, SystemClock());
    expect(id2, 'default_cash');
    final count = db.raw.select('SELECT COUNT(*) AS c FROM accounts');
    expect(count.first['c'], 1);
  });

  test('returns first existing account when accounts already exist', () async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    db.raw.execute(
      'INSERT INTO accounts (id,name,type,currency,opening_balance_cents,sort_order,is_hidden,'
      'credit_limit_cents,credit_debt_cents,created_at,updated_at,revision,device_id,base_revision) '
      'VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
      ['my_cash', '我的现金', 'cash', 'CNY', 100, 0, 0, 0, 0, now, now, 1, 'dev-test', 0],
    );
    final id = await seedDefaultAccount(db, SystemClock());
    expect(id, 'my_cash');
    final count = db.raw.select('SELECT COUNT(*) AS c FROM accounts');
    expect(count.first['c'], 1);
  });

  test('returns null when device.id is missing', () async {
    final bare = AppDatabase.inMemory();
    addTearDown(bare.close);
    final id = await seedDefaultAccount(bare, SystemClock());
    expect(id, isNull);
  });
}
