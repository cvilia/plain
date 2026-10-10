/// Default account seed: create one "现金" account when the accounts table is empty.
/// Idempotent — runs on every cold start, no-ops once any account exists.
library;

import 'package:plain/core/time/clock.dart';
import 'package:plain/data/db/database.dart';

/// Returns the id of the default cash account (existing or newly seeded),
/// or null when seeding is not possible (no device id).
Future<String?> seedDefaultAccount(AppDatabase db, Clock clock) async {
  final deviceRows = db.raw.select('SELECT value FROM app_meta WHERE key = ?', ['device.id']);
  final deviceId = deviceRows.isEmpty ? '' : deviceRows.first['value']! as String;
  if (deviceId.isEmpty) return null;

  final existing = db.raw.select('SELECT id FROM accounts WHERE deleted_at IS NULL ORDER BY sort_order ASC LIMIT 1');
  if (existing.isNotEmpty) return existing.first['id']! as String;

  final now = clock.now();
  const id = 'default_cash';
  db.raw.execute(
    'INSERT OR IGNORE INTO accounts '
    '(id,name,type,currency,opening_balance_cents,note,sort_order,is_hidden,'
    'credit_limit_cents,credit_debt_cents,'
    'created_at,updated_at,revision,device_id,base_revision) '
    'VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
    [id, '现金', 'cash', 'CNY', 0, null, 0, 0, 0, 0,
     now.millisecondsSinceEpoch, now.millisecondsSinceEpoch, 1, deviceId, 0],
  );
  return id;
}
