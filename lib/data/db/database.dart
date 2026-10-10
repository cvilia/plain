/// SQLite database layer (native only, no web). See 08-6, 9.
library;

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:plain/core/security/db_passphrase.dart';
import 'package:sqlite3/sqlite3.dart';

const int kSchemaVersion = 11;

class AppDatabase {
  AppDatabase._(this._db);
  final Database _db;

  Database get raw => _db;

  static Future<AppDatabase> open() async {
    // C6 / 04-§10.1 方案 A：native lib 由 sqlite3 hook 以 `source: sqlcipher`
    // 提供（见 pubspec hooks.user_defines），@Native 直接绑定 SQLCipher，
    // 无需 open.overrideFor。这里用 `PRAGMA cipher_version` 做运行时自检。
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'plain.sqlite');

    String? keyLiteral;
    try {
      keyLiteral = sqlcipherKeyLiteral(await loadOrCreateDbPassphrase());
    } catch (_) {
      keyLiteral = null;
    }

    if (keyLiteral != null) {
      final encrypted = _tryOpenEncrypted(path, keyLiteral);
      if (encrypted != null) return encrypted.._init();
    }

    final db = sqlite3.open(path);
    return AppDatabase._(db).._init();
  }

  /// Open with [keyLiteral]. If the file is legacy plaintext, rekey in place.
  /// Returns null when encryption cannot be applied (no SQLCipher runtime).
  static AppDatabase? _tryOpenEncrypted(String path, String keyLiteral) {
    // Already encrypted with our key?
    try {
      final db = sqlite3.open(path);
      try {
        if (!_cipherAvailable(db)) {
          db.close();
          return null;
        }
        db.execute('PRAGMA key = $keyLiteral');
        db.select('SELECT count(*) FROM sqlite_master');
        return AppDatabase._(db);
      } catch (_) {
        db.close();
      }
    } catch (_) {}

    // Legacy plaintext → rekey, then open with key.
    try {
      final plain = sqlite3.open(path);
      try {
        if (!_cipherAvailable(plain)) return null;
        plain.select('SELECT count(*) FROM sqlite_master');
        plain.execute('PRAGMA rekey = $keyLiteral');
        plain.select('SELECT count(*) FROM sqlite_master');
      } finally {
        plain.close();
      }
      final db = sqlite3.open(path);
      db.execute('PRAGMA key = $keyLiteral');
      db.select('SELECT count(*) FROM sqlite_master');
      return AppDatabase._(db);
    } catch (_) {
      return null;
    }
  }

  /// SQLCipher exposes `cipher_version`; stock sqlite3 does not.
  static bool _cipherAvailable(Database db) {
    try {
      final rows = db.select('PRAGMA cipher_version');
      return rows.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static AppDatabase inMemory() {
    // Tests / benchmarks: stock sqlite3, no keystore dependency.
    final db = sqlite3.openInMemory();
    final handle = AppDatabase._(db);
    handle._init();
    return handle;
  }

  void _init() {
    _db.execute('PRAGMA journal_mode = WAL');
    // Reject orphan rows at the DB layer (PRD: no orphan entries).
    _db.execute('PRAGMA foreign_keys = ON');
    // Concurrent writer (sync + UI) waits instead of throwing immediately.
    _db.execute('PRAGMA busy_timeout = 5000');
    // WAL + NORMAL is the standard mobile durability/throughput tradeoff.
    _db.execute('PRAGMA synchronous = NORMAL');
    _db.execute(_ddlTransactions);
    _db.execute(_ddlCategories);
    _db.execute(_ddlAccounts);
    _db.execute(_ddlChangeLogs);
    _db.execute(_ddlAppMeta);
    _db.execute(_ddlDailyStats);
    _db.execute(_ddlBudgets);
    _db.execute(_ddlRecurringRules);
    _db.execute(_ddlRules);
    _db.execute(_ddlSavingsGoals);
    _db.execute(_ddlMerchantRules);
    _migrate();
    for (final sql in _indexes) {
      _db.execute(sql);
    }
    _db.execute('PRAGMA user_version = $kSchemaVersion');
  }

  void _migrate() {
    final txCols = _db.select('PRAGMA table_info(transactions)');
    if (!txCols.any((r) => r['name'] == 'batch_id')) {
      _db.execute('ALTER TABLE transactions ADD COLUMN batch_id TEXT NULL');
    }
    // v3: category boundary notes (12-分类体系设计). Pure additive; no backfill.
    // Must check existence first — _init() creates the table WITH note on fresh
    // installs, so unconditional ALTER would throw duplicate column.
    final catCols = _db.select('PRAGMA table_info(categories)');
    if (!catCols.any((r) => r['name'] == 'note')) {
      _db.execute('ALTER TABLE categories ADD COLUMN note TEXT NULL');
    }
    // v4: split-transaction roles + rigid-expense flag (08-§9.1).
    // Pure additive; defaults keep historical rows semantically correct.
    if (!txCols.any((r) => r['name'] == 'split_role')) {
      _db.execute(
          "ALTER TABLE transactions ADD COLUMN split_role TEXT NOT NULL DEFAULT 'normal'");
    }
    if (!txCols.any((r) => r['name'] == 'parent_id')) {
      _db.execute('ALTER TABLE transactions ADD COLUMN parent_id TEXT NULL');
    }
    if (!txCols.any((r) => r['name'] == 'reimburse_status')) {
      _db.execute(
          "ALTER TABLE transactions ADD COLUMN reimburse_status TEXT NOT NULL DEFAULT 'none'");
    }
    // v11: 对账模式逐笔勾选（STORY-2.3）。
    if (!txCols.any((r) => r['name'] == 'reconciled_at')) {
      _db.execute('ALTER TABLE transactions ADD COLUMN reconciled_at INTEGER NULL');
    }
    // v10: 信用卡参数与欠款余额（STORY-2.2）。
    final accCols = _db.select('PRAGMA table_info(accounts)');
    if (accCols.isNotEmpty) {
      if (!accCols.any((r) => r['name'] == 'credit_limit_cents')) {
        _db.execute(
            'ALTER TABLE accounts ADD COLUMN credit_limit_cents INTEGER NOT NULL DEFAULT 0');
      }
      if (!accCols.any((r) => r['name'] == 'credit_debt_cents')) {
        _db.execute(
            'ALTER TABLE accounts ADD COLUMN credit_debt_cents INTEGER NOT NULL DEFAULT 0');
      }
      if (!accCols.any((r) => r['name'] == 'bill_day')) {
        _db.execute('ALTER TABLE accounts ADD COLUMN bill_day INTEGER NULL');
      }
      if (!accCols.any((r) => r['name'] == 'due_day')) {
        _db.execute('ALTER TABLE accounts ADD COLUMN due_day INTEGER NULL');
      }
    }
    if (!catCols.any((r) => r['name'] == 'is_rigid')) {
      _db.execute(
          'ALTER TABLE categories ADD COLUMN is_rigid INTEGER NOT NULL DEFAULT 0');
    }
    // v7: savings_goals 目标类型与剩余期数（STORY-7.2）。
    final sgCols = _db.select('PRAGMA table_info(savings_goals)');
    if (sgCols.isNotEmpty) {
      if (!sgCols.any((r) => r['name'] == 'goal_type')) {
        _db.execute(
            "ALTER TABLE savings_goals ADD COLUMN goal_type TEXT NOT NULL DEFAULT 'savings'");
      }
      if (!sgCols.any((r) => r['name'] == 'remaining_terms')) {
        _db.execute('ALTER TABLE savings_goals ADD COLUMN remaining_terms INTEGER NULL');
      }
    }
    // v5: automation rules table is created in _init (CREATE IF NOT EXISTS);
    // no ALTER needed for existing DBs.
  }

  /// Runs [action] inside a BEGIN/COMMIT transaction.
  ///
  /// Not re-entrant: nested calls will throw from SQLite (a connection cannot
  /// open a transaction inside a transaction). Catches all [Object]s so that
  /// [Error]s (TypeError/StateError from row casts) also roll back — catching
  /// only [Exception] would leave the transaction hanging.
  void transaction(void Function() action) {
    _db.execute('BEGIN');
    try {
      action();
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  /// PRD STORY-4.1：恢复前预览（schema 版本 / 账单数 / 时间范围）。
  /// 只读打开备份文件；打不开或结构不对则返回 null，由调用方降级为简单确认。
  static BackupPreview? previewBackup(String backupPath) {
    try {
      final db = sqlite3.open(backupPath);
      try {
        // 若备份是加密库，尝试用同一把 key 打开（与本机一致）。
        return () {
          try {
            final ver = db.select('PRAGMA user_version').first.values.first as int?;
            final countRow = db.select(
                'SELECT COUNT(*) AS c FROM transactions WHERE deleted_at IS NULL');
            final entryCount = (countRow.first['c'] as int?) ?? 0;
            int? minMs;
            int? maxMs;
            try {
              final range = db.select(
                  'SELECT MIN(occurred_at) AS lo, MAX(occurred_at) AS hi FROM transactions WHERE deleted_at IS NULL');
              minMs = range.first['lo'] as int?;
              maxMs = range.first['hi'] as int?;
            } catch (_) {}
            return BackupPreview(
              schemaVersion: ver ?? 0,
              entryCount: entryCount,
              earliestMs: minMs,
              latestMs: maxMs,
            );
          } catch (_) {
            return null;
          }
        }();
      } finally {
        db.close();
      }
    } catch (_) {
      return null;
    }
  }

  /// Replace all app data with the contents of a backup `.db` file.
  ///
  /// The backup is attached read-only; every user table is cleared and
  /// refilled in one transaction. Callers should bump all data scopes after.
  void restoreFrom(String backupPath) {
    final escaped = backupPath.replaceAll("'", "''");
    _db.execute("ATTACH DATABASE '$escaped' AS backup");
    try {
      const tables = [
        'transactions',
        'categories',
        'accounts',
        'change_log',
        'daily_stats',
        'budgets',
        'recurring_rules',
        'app_meta',
      ];
      _db.execute('BEGIN');
      for (final table in tables) {
        // Older backups may miss newer tables (e.g. budgets) — skip those.
        final exists = _db.select(
          "SELECT name FROM backup.sqlite_master WHERE type='table' AND name = ?",
          [table],
        );
        if (exists.isEmpty) continue;
        _db.execute('DELETE FROM $table');
        _db.execute('INSERT INTO $table SELECT * FROM backup.$table');
      }
      _db.execute('COMMIT');
    } catch (_) {
      try {
        _db.execute('ROLLBACK');
      } on Exception {
        // transaction may not have started
      }
      rethrow;
    } finally {
      _db.execute('DETACH DATABASE backup');
    }
  }

  void close() => _db.close();
}

/// PRD STORY-4.1 恢复前预览摘要。
class BackupPreview {
  const BackupPreview({
    required this.schemaVersion,
    required this.entryCount,
    this.earliestMs,
    this.latestMs,
  });

  final int schemaVersion;
  final int entryCount;
  final int? earliestMs;
  final int? latestMs;

  String describe() {
    final buf = StringBuffer('schema v$schemaVersion · $entryCount 笔账单');
    if (earliestMs != null && latestMs != null && entryCount > 0) {
      final lo = DateTime.fromMillisecondsSinceEpoch(earliestMs!);
      final hi = DateTime.fromMillisecondsSinceEpoch(latestMs!);
      buf.write(' · ${lo.year}-${lo.month.toString().padLeft(2, '0')}-${lo.day.toString().padLeft(2, '0')}'
          ' ~ ${hi.year}-${hi.month.toString().padLeft(2, '0')}-${hi.day.toString().padLeft(2, '0')}');
    }
    return buf.toString();
  }
}

const String _ddlTransactions = '''
CREATE TABLE IF NOT EXISTS transactions (
  id TEXT NOT NULL PRIMARY KEY, book_id TEXT NOT NULL, type TEXT NOT NULL,
  amount_cents INTEGER NOT NULL CHECK (amount_cents > 0),
  currency TEXT NOT NULL DEFAULT 'CNY',
  category_id TEXT NULL, account_id TEXT NULL, to_account_id TEXT NULL,
  occurred_at INTEGER NOT NULL, note TEXT NULL, source TEXT NOT NULL,
  batch_id TEXT NULL,
  split_role TEXT NOT NULL DEFAULT 'normal',
  parent_id TEXT NULL,
  reimburse_status TEXT NOT NULL DEFAULT 'none',
  reconciled_at INTEGER NULL,
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, deleted_at INTEGER NULL,
  revision INTEGER NOT NULL DEFAULT 1, device_id TEXT NOT NULL, base_revision INTEGER NOT NULL DEFAULT 0
)''';

const String _ddlCategories = '''
CREATE TABLE IF NOT EXISTS categories (
  id TEXT NOT NULL PRIMARY KEY, parent_id TEXT NULL, name TEXT NOT NULL,
  kind TEXT NOT NULL, icon_ref TEXT NOT NULL, icon_asset TEXT NULL,
  note TEXT NULL,
  is_rigid INTEGER NOT NULL DEFAULT 0,
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
  credit_limit_cents INTEGER NOT NULL DEFAULT 0,
  credit_debt_cents INTEGER NOT NULL DEFAULT 0,
  bill_day INTEGER NULL, due_day INTEGER NULL,
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

/// STORY-6.1 自动化规则（V2.0）。
const String _ddlRules = '''
CREATE TABLE IF NOT EXISTS rules (
  id TEXT NOT NULL PRIMARY KEY, book_id TEXT NOT NULL,
  name TEXT NULL,
  stage TEXT NOT NULL DEFAULT 'post',
  priority INTEGER NOT NULL DEFAULT 0,
  scope TEXT NOT NULL DEFAULT 'manual',
  conditions TEXT NOT NULL,
  actions TEXT NOT NULL,
  is_enabled INTEGER NOT NULL DEFAULT 1,
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, deleted_at INTEGER NULL,
  revision INTEGER NOT NULL DEFAULT 1, device_id TEXT NOT NULL, base_revision INTEGER NOT NULL DEFAULT 0
)''';

/// STORY-7.1 储蓄目标（V2.0）。
const String _ddlSavingsGoals = '''
CREATE TABLE IF NOT EXISTS savings_goals (
  id TEXT NOT NULL PRIMARY KEY, book_id TEXT NOT NULL,
  name TEXT NOT NULL,
  goal_type TEXT NOT NULL DEFAULT 'savings',
  target_cents INTEGER NOT NULL,
  saved_cents INTEGER NOT NULL DEFAULT 0,
  remaining_terms INTEGER NULL,
  due_at INTEGER NULL,
  account_id TEXT NULL,
  auto_transfer INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, deleted_at INTEGER NULL,
  revision INTEGER NOT NULL DEFAULT 1, device_id TEXT NOT NULL, base_revision INTEGER NOT NULL DEFAULT 0
)''';

/// STORY-1.6 商户学习记录（V2.0）。
const String _ddlMerchantRules = '''
CREATE TABLE IF NOT EXISTS merchant_rules (
  id TEXT NOT NULL PRIMARY KEY, book_id TEXT NOT NULL,
  merchant TEXT NOT NULL,
  category_id TEXT NULL,
  hit_count INTEGER NOT NULL DEFAULT 1,
  last_corrected_at INTEGER NULL,
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, deleted_at INTEGER NULL,
  revision INTEGER NOT NULL DEFAULT 1, device_id TEXT NOT NULL, base_revision INTEGER NOT NULL DEFAULT 0
)''';

final List<String> _indexes = [
  'CREATE INDEX IF NOT EXISTS idx_entry_book_time ON transactions(book_id, occurred_at DESC, id DESC) WHERE deleted_at IS NULL',
  'CREATE INDEX IF NOT EXISTS idx_entry_category ON transactions(category_id, occurred_at DESC) WHERE deleted_at IS NULL',
  'CREATE INDEX IF NOT EXISTS idx_entry_account ON transactions(account_id, occurred_at DESC) WHERE deleted_at IS NULL',
  'CREATE INDEX IF NOT EXISTS idx_entry_to_account ON transactions(to_account_id, occurred_at DESC) WHERE to_account_id IS NOT NULL AND deleted_at IS NULL',
  'CREATE INDEX IF NOT EXISTS idx_entry_batch ON transactions(batch_id) WHERE batch_id IS NOT NULL',
  'CREATE INDEX IF NOT EXISTS idx_entry_parent ON transactions(parent_id, occurred_at DESC) WHERE parent_id IS NOT NULL AND deleted_at IS NULL',
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
  'CREATE INDEX IF NOT EXISTS idx_rule_book ON rules(book_id, priority DESC) WHERE deleted_at IS NULL AND is_enabled = 1',
];
