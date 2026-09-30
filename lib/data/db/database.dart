/// SQLite database layer (native only, no web). See 08-6, 9.
library;

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

const int kSchemaVersion = 2;

class AppDatabase {
  AppDatabase._(this._db);
  final Database _db;

  Database get raw => _db;

  static Future<AppDatabase> open() async {
    final dir = await getApplicationDocumentsDirectory();
    final db = sqlite3.open(p.join(dir.path, 'plain.sqlite'));
    final handle = AppDatabase._(db);
    handle._init();
    return handle;
  }

  static AppDatabase inMemory() {
    final db = sqlite3.openInMemory();
    final handle = AppDatabase._(db);
    handle._init();
    return handle;
  }

  void _init() {
    _db.execute('PRAGMA journal_mode = WAL');
    _db.execute(_ddlTransactions);
    _db.execute(_ddlCategories);
    _db.execute(_ddlAccounts);
    _db.execute(_ddlChangeLogs);
    _db.execute(_ddlAppMeta);
    _db.execute(_ddlDailyStats);
    _db.execute(_ddlBudgets);
    _db.execute(_ddlRecurringRules);
    _migrate();
    for (final sql in _indexes) {
      _db.execute(sql);
    }
    _db.execute('PRAGMA user_version = $kSchemaVersion');
  }

  void _migrate() {
    final cols = _db.select('PRAGMA table_info(transactions)');
    final hasBatchId = cols.any((r) => r['name'] == 'batch_id');
    if (!hasBatchId) {
      _db.execute('ALTER TABLE transactions ADD COLUMN batch_id TEXT NULL');
    }
  }

  void transaction(void Function() action) {
    _db.execute('BEGIN');
    try {
      action();
      _db.execute('COMMIT');
    } on Exception {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  void close() => _db.close();
}

const String _ddlTransactions = '''
CREATE TABLE IF NOT EXISTS transactions (
  id TEXT NOT NULL PRIMARY KEY, book_id TEXT NOT NULL, type TEXT NOT NULL,
  amount_cents INTEGER NOT NULL CHECK (amount_cents > 0),
  currency TEXT NOT NULL DEFAULT 'CNY',
  category_id TEXT NULL, account_id TEXT NULL, to_account_id TEXT NULL,
  occurred_at INTEGER NOT NULL, note TEXT NULL, source TEXT NOT NULL,
  batch_id TEXT NULL,
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, deleted_at INTEGER NULL,
  revision INTEGER NOT NULL DEFAULT 1, device_id TEXT NOT NULL, base_revision INTEGER NOT NULL DEFAULT 0
)''';

const String _ddlCategories = '''
CREATE TABLE IF NOT EXISTS categories (
  id TEXT NOT NULL PRIMARY KEY, parent_id TEXT NULL, name TEXT NOT NULL,
  kind TEXT NOT NULL, icon_ref TEXT NOT NULL, icon_asset TEXT NULL,
  sort_order INTEGER NOT NULL, is_hidden INTEGER NOT NULL DEFAULT 0,
  is_preset INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, deleted_at INTEGER NULL,
  revision INTEGER NOT NULL DEFAULT 1, device_id TEXT NOT NULL, base_revision INTEGER NOT NULL DEFAULT 0
)''';

const String _ddlAccounts = '''
CREATE TABLE IF NOT EXISTS accounts (
  id TEXT NOT NULL PRIMARY KEY, name TEXT NOT NULL, type TEXT NOT NULL,
  currency TEXT NOT NULL DEFAULT 'CNY', opening_balance_cents INTEGER NOT NULL DEFAULT 0,
  note TEXT NULL, sort_order INTEGER NOT NULL, is_hidden INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, deleted_at INTEGER NULL,
  revision INTEGER NOT NULL DEFAULT 1, device_id TEXT NOT NULL, base_revision INTEGER NOT NULL DEFAULT 0
)''';

const String _ddlChangeLogs = '''
CREATE TABLE IF NOT EXISTS change_log (
  local_revision INTEGER PRIMARY KEY AUTOINCREMENT,
  entity_type TEXT NOT NULL, entity_id TEXT NOT NULL, op TEXT NOT NULL,
  device_id TEXT NOT NULL, base_revision INTEGER NOT NULL DEFAULT 0,
  payload TEXT NOT NULL, payload_hash TEXT NOT NULL, changed_at INTEGER NOT NULL
)''';

const String _ddlAppMeta = '''
CREATE TABLE IF NOT EXISTS app_meta (
  key TEXT NOT NULL PRIMARY KEY, value TEXT NOT NULL, updated_at INTEGER NOT NULL
)''';

const String _ddlDailyStats = '''
CREATE TABLE IF NOT EXISTS daily_stats (
  book_id TEXT NOT NULL, day_key TEXT NOT NULL, category_id TEXT NOT NULL,
  account_id TEXT NOT NULL, expense_cents INTEGER NOT NULL DEFAULT 0,
  income_cents INTEGER NOT NULL DEFAULT 0, tx_count INTEGER NOT NULL DEFAULT 0,
  updated_at INTEGER NOT NULL,
  PRIMARY KEY (book_id, day_key, category_id, account_id)
)''';

const String _ddlBudgets = '''
CREATE TABLE IF NOT EXISTS budgets (
  id TEXT NOT NULL PRIMARY KEY, book_id TEXT NOT NULL,
  scope TEXT NOT NULL, category_id TEXT NULL,
  period_type TEXT NOT NULL DEFAULT 'monthly',
  start_day INTEGER NOT NULL DEFAULT 1,
  amount_cents INTEGER NOT NULL CHECK (amount_cents > 0),
  rollover INTEGER NOT NULL DEFAULT 0,
  is_enabled INTEGER NOT NULL DEFAULT 1,
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, deleted_at INTEGER NULL,
  revision INTEGER NOT NULL DEFAULT 1, device_id TEXT NOT NULL, base_revision INTEGER NOT NULL DEFAULT 0
)''';

const String _ddlRecurringRules = '''
CREATE TABLE IF NOT EXISTS recurring_rules (
  id TEXT NOT NULL PRIMARY KEY, book_id TEXT NOT NULL, name TEXT NULL,
  frequency TEXT NOT NULL, interval_n INTEGER NOT NULL DEFAULT 1,
  anchor_day INTEGER NULL, weekday INTEGER NULL,
  skip_strategy TEXT NOT NULL DEFAULT 'clamp',
  auto_confirm INTEGER NOT NULL DEFAULT 1,
  end_type TEXT NOT NULL DEFAULT 'never',
  end_at INTEGER NULL, end_count INTEGER NULL,
  generated_count INTEGER NOT NULL DEFAULT 0,
  next_run_at INTEGER NOT NULL,
  entry_type TEXT NOT NULL, amount_cents INTEGER NOT NULL,
  category_id TEXT NULL, account_id TEXT NULL, to_account_id TEXT NULL,
  note TEXT NULL, last_batch_id TEXT NULL,
  is_enabled INTEGER NOT NULL DEFAULT 1,
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, deleted_at INTEGER NULL,
  revision INTEGER NOT NULL DEFAULT 1, device_id TEXT NOT NULL, base_revision INTEGER NOT NULL DEFAULT 0
)''';

final List<String> _indexes = [
  'CREATE INDEX IF NOT EXISTS idx_entry_book_time ON transactions(book_id, occurred_at DESC, id DESC) WHERE deleted_at IS NULL',
  'CREATE INDEX IF NOT EXISTS idx_entry_category ON transactions(category_id, occurred_at DESC) WHERE deleted_at IS NULL',
  'CREATE INDEX IF NOT EXISTS idx_entry_account ON transactions(account_id, occurred_at DESC) WHERE deleted_at IS NULL',
  'CREATE INDEX IF NOT EXISTS idx_entry_to_account ON transactions(to_account_id, occurred_at DESC) WHERE to_account_id IS NOT NULL AND deleted_at IS NULL',
  'CREATE INDEX IF NOT EXISTS idx_entry_batch ON transactions(batch_id) WHERE batch_id IS NOT NULL',
  "CREATE UNIQUE INDEX IF NOT EXISTS uq_category_name ON categories(COALESCE(parent_id, ''), name) WHERE deleted_at IS NULL",
  'CREATE INDEX IF NOT EXISTS idx_category_parent ON categories(parent_id, sort_order) WHERE deleted_at IS NULL',
  'CREATE UNIQUE INDEX IF NOT EXISTS uq_account_name ON accounts(name) WHERE deleted_at IS NULL',
  'CREATE INDEX IF NOT EXISTS idx_account_sort ON accounts(sort_order) WHERE deleted_at IS NULL',
  'CREATE INDEX IF NOT EXISTS idx_change_entity ON change_log(entity_type, entity_id, local_revision)',
  'CREATE UNIQUE INDEX IF NOT EXISTS uq_budget_total ON budgets(book_id) WHERE scope = \'total\' AND deleted_at IS NULL',
  'CREATE UNIQUE INDEX IF NOT EXISTS uq_budget_category ON budgets(book_id, category_id) WHERE scope = \'category\' AND deleted_at IS NULL',
  'CREATE INDEX IF NOT EXISTS idx_budget_book ON budgets(book_id) WHERE deleted_at IS NULL',
  'CREATE INDEX IF NOT EXISTS idx_recurring_due ON recurring_rules(next_run_at) WHERE is_enabled = 1 AND deleted_at IS NULL',
  'CREATE INDEX IF NOT EXISTS idx_recurring_book ON recurring_rules(book_id) WHERE deleted_at IS NULL',
];
