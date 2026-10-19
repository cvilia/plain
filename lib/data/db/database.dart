/// SQLite database layer (native only, no web). See 08-6, 9.
library;

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:plain/core/security/db_passphrase.dart';
import 'package:plain/data/seed/preset_promotions.dart';
import 'package:sqlite3/sqlite3.dart';

const int kSchemaVersion = 26;

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
    // v15: 投资持仓（STORY-10.1）。纯追加新表。
    _db.execute(_ddlHoldings);
    // v18: 保存的交叉分析报表（STORY-11.3）。纯追加新表。
    _db.execute(_ddlSavedReports);
    // v19: 税务申报状态（STORY-11.5）。纯追加新表。
    _db.execute(_ddlTaxFilings);
    // v20: 锁定汇率（STORY-9.3）。纯追加新表。
    _db.execute(_ddlCurrencyRates);
    // v21 曾为账单附件（STORY-1.5）建 `attachments` 表，该功能已整体移除：
    // 表在 `_migrate()` 里 DROP，这里不再建。
    // v22: 家庭共享（STORY-8.2）。纯追加新表。
    _db.execute(_ddlMembers);
    _db.execute(_ddlEntryParticipants);
    // v23: 增量同步（STORY-8.1）。纯追加新表。
    _db.execute(_ddlSyncConflicts);
    _db.execute(_ddlSyncState);
    // v24: 提醒历史（STORY-6.3）。纯追加新表——去重与近 90 天可查都靠它。
    _db.execute(_ddlReminders);
    _migrate();
    for (final sql in _indexes) {
      _db.execute(sql);
    }
    _db.execute('PRAGMA user_version = $kSchemaVersion');
  }

  void _migrate() {
    // 附件功能已整体移除（原 STORY-1.5）：表与索引一次性 DROP。
    //
    // ⚠️ 这是**不可逆**的 —— 老库里 `attachments` 的元数据行在这里被清空，
    // 文件本体由 `purgeAttachmentDirectory()`（main.dart 首帧后）删除。
    // 之所以不保留表：功能已下线，留着就是无人读取的死数据，且它会让
    // 备份包继续把已失效的元数据打进去。DROP 是幂等的（IF EXISTS）。
    _db.execute('DROP TABLE IF EXISTS attachments');
    // 自定义分类图标同批下线（原 F1.2）：清空 `categories.icon_asset`。
    // 列**保留不 DROP** —— SQLite 的 DROP COLUMN 要 3.35+，低版本整库会炸；
    // 空列不影响任何读写，风险为零。文件本体由 `purgeCustomIconDirectory()` 删。
    _db.execute('UPDATE categories SET icon_asset = NULL WHERE icon_asset IS NOT NULL');
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
    // v12: 手动标记「不计入收支」（G-2）。它只改统计口径，
    // **不影响账户余额**——所以与 split_role 一样是纯加法列。
    if (!txCols.any((r) => r['name'] == 'exclude_from_stats')) {
      _db.execute(
          'ALTER TABLE transactions ADD COLUMN exclude_from_stats INTEGER NOT NULL DEFAULT 0');
    }
    // v20: 多币种（STORY-9.3）。原币金额与锁定汇率；两者为 null 表示本位币记账。
    // `amount_cents` 始终是**本位币**金额，所有统计口径不变。
    if (!txCols.any((r) => r['name'] == 'original_amount_cents')) {
      _db.execute('ALTER TABLE transactions ADD COLUMN original_amount_cents INTEGER NULL');
    }
    if (!txCols.any((r) => r['name'] == 'exchange_rate_micro')) {
      _db.execute('ALTER TABLE transactions ADD COLUMN exchange_rate_micro INTEGER NULL');
    }
    // v22: 账单归属成员（STORY-8.2）。null = 未指定归属（V2.0 之前的老数据）。
    if (!txCols.any((r) => r['name'] == 'member_id')) {
      _db.execute('ALTER TABLE transactions ADD COLUMN member_id TEXT NULL');
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
      // v14: 贷款参数（STORY-10.2）。摊销表本身不落库，这里只存参数。
      if (!accCols.any((r) => r['name'] == 'loan_principal_cents')) {
        _db.execute(
            'ALTER TABLE accounts ADD COLUMN loan_principal_cents INTEGER NOT NULL DEFAULT 0');
      }
      if (!accCols.any((r) => r['name'] == 'loan_annual_rate_bp')) {
        _db.execute(
            'ALTER TABLE accounts ADD COLUMN loan_annual_rate_bp INTEGER NOT NULL DEFAULT 0');
      }
      if (!accCols.any((r) => r['name'] == 'loan_term_months')) {
        _db.execute('ALTER TABLE accounts ADD COLUMN loan_term_months INTEGER NULL');
      }
      if (!accCols.any((r) => r['name'] == 'loan_repay_method')) {
        _db.execute('ALTER TABLE accounts ADD COLUMN loan_repay_method TEXT NULL');
      }
      if (!accCols.any((r) => r['name'] == 'loan_first_payment_at')) {
        _db.execute('ALTER TABLE accounts ADD COLUMN loan_first_payment_at INTEGER NULL');
      }
      // v16: 资产估值模式（STORY-10.3）。折旧/增值是**纯估算**，不碰账单。
      if (!accCols.any((r) => r['name'] == 'valuation_mode')) {
        _db.execute(
            "ALTER TABLE accounts ADD COLUMN valuation_mode TEXT NOT NULL DEFAULT 'none'");
      }
      if (!accCols.any((r) => r['name'] == 'valuation_base_cents')) {
        _db.execute(
            'ALTER TABLE accounts ADD COLUMN valuation_base_cents INTEGER NOT NULL DEFAULT 0');
      }
      if (!accCols.any((r) => r['name'] == 'valuation_rate_bp')) {
        _db.execute(
            'ALTER TABLE accounts ADD COLUMN valuation_rate_bp INTEGER NOT NULL DEFAULT 0');
      }
      if (!accCols.any((r) => r['name'] == 'valuation_manual_cents')) {
        _db.execute(
            'ALTER TABLE accounts ADD COLUMN valuation_manual_cents INTEGER NOT NULL DEFAULT 0');
      }
      if (!accCols.any((r) => r['name'] == 'valuation_started_at')) {
        _db.execute('ALTER TABLE accounts ADD COLUMN valuation_started_at INTEGER NULL');
      }
      // v17: 债务优化的输入（STORY-10.5）。信用卡的最低还款额与循环年利率
      // 是用户在账单上看到的事实，无法从现有字段派生。
      if (!accCols.any((r) => r['name'] == 'min_payment_cents')) {
        _db.execute(
            'ALTER TABLE accounts ADD COLUMN min_payment_cents INTEGER NOT NULL DEFAULT 0');
      }
      if (!accCols.any((r) => r['name'] == 'credit_annual_rate_bp')) {
        _db.execute(
            'ALTER TABLE accounts ADD COLUMN credit_annual_rate_bp INTEGER NOT NULL DEFAULT 0');
      }
    }
    if (!catCols.any((r) => r['name'] == 'is_rigid')) {
      _db.execute(
          'ALTER TABLE categories ADD COLUMN is_rigid INTEGER NOT NULL DEFAULT 0');
    }
    // v19: 分类「可抵扣」（STORY-11.5）。纯加法列。
    if (!catCols.any((r) => r['name'] == 'is_deductible')) {
      _db.execute(
          'ALTER TABLE categories ADD COLUMN is_deductible INTEGER NOT NULL DEFAULT 0');
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
      // v13: 目标虚拟账户（STORY-7.1 存入划拨的转入端）。null = 尚未划拨过。
      if (!sgCols.any((r) => r['name'] == 'goal_account_id')) {
        _db.execute('ALTER TABLE savings_goals ADD COLUMN goal_account_id TEXT NULL');
      }
    }
    // v5: automation rules table is created in _init (CREATE IF NOT EXISTS);
    // no ALTER needed for existing DBs.
    // v13: 周期规则的生成来源类型（STORY-7.3）。全产品一套调度器，
    // 三类自动生成（周期记账 / 储蓄目标划拨 / 贷款还款）用它区分。
    final rrCols = _db.select('PRAGMA table_info(recurring_rules)');
    if (rrCols.isNotEmpty) {
      if (!rrCols.any((r) => r['name'] == 'kind')) {
        _db.execute(
            "ALTER TABLE recurring_rules ADD COLUMN kind TEXT NOT NULL DEFAULT 'recurring'");
      }
      if (!rrCols.any((r) => r['name'] == 'goal_id')) {
        _db.execute('ALTER TABLE recurring_rules ADD COLUMN goal_id TEXT NULL');
      }
    }
    // v25: `uq_category_name` 漏了 kind，收入侧「其他」与支出侧「其他」撞名 →
    // 空库上 `preset_income_other`（收入兜底分类）从来没建成过；而 App 的重名
    // 校验按 kind 分域，于是「校验通过的名字」写库时被索引拒掉（静默丢行）。
    // 只在旧定义还在时重建一次，之后由 `_indexes` 维护。
    final uqCat = _db.select(
        "SELECT sql FROM sqlite_master WHERE type='index' AND name='uq_category_name'");
    final uqSql = uqCat.isEmpty ? null : uqCat.first['sql'] as String?;
    if (uqSql != null && !uqSql.contains('kind')) {
      _db.execute('DROP INDEX uq_category_name');
    }

    // v26（2026-10-19）：分类树重构 —— 30 个支出一级 + 每个一级都有二级。
    //
    // 老库里 9 个预置二级（服饰/美妆/数码/家居/游戏/旅行/运动健身/书籍/水电气）
    // 被提升为一级：只把 parent_id 置空，**id 不变** → 账单引用、change_log、
    // 同步数据全部照旧。判据是「父级仍是当初那个」，用户手动挪过的绝不覆盖。
    // 新结构下这些分类的二级由 `backfillPresetCategories` 在首帧后补插。
    for (final entry in kPromotedPresetIds.entries) {
      _db.execute(
        'UPDATE categories SET parent_id = NULL WHERE id = ? AND parent_id = ?',
        [entry.key, entry.value],
      );
    }
    // 同步改名（只在用户没改过名时生效）
    for (final entry in kRenamedPresetIds.entries) {
      final (oldName, newName) = entry.value;
      _db.execute(
        'UPDATE categories SET name = ? WHERE id = ? AND name = ?',
        [newName, entry.key, oldName],
      );
    }
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
        // 08 C21：以下表此前漏在还原清单外，备份里有数据却搬不回来。
        'rules',
        'savings_goals',
        'merchant_rules',
        // v15 / v18 新增表：同样必须并入，否则备份还原会丢
        'holdings',
        'saved_reports',
        'tax_filings',
        'currency_rates',
        // v21 的 `attachments` 已随附件功能移除，不再进备份包。
        // v22 新增表：家庭成员与 AA 参与人（STORY-8.2）
        'members',
        'entry_participants',
        // v23：冲突是用户可见数据，随备份走；`sync_state`（位点）是设备本地状态，
        // 刻意**不**在还原清单里——换机后从零开始拉取即可。
        'sync_conflicts',
        // v24：提醒历史。它是设备产生的提醒日志，换机后能接着看近 90 天记录，
        // 因此并入还原清单（`backup.last_at` 也随之走，见 AppMetaRepository）。
        'reminders',
      ];
      // 还原会把 app_meta 整表换掉，所以先记住本机的设备身份
      final deviceRows = _db.select("SELECT value FROM app_meta WHERE key = 'device.id'");
      final localDeviceId = deviceRows.isEmpty ? null : (deviceRows.first['value'] as String?);
      _db.execute('BEGIN');
      for (final table in tables) {
        // Older backups may miss newer tables (e.g. budgets) — skip those.
        final exists = _db.select(
          "SELECT name FROM backup.sqlite_master WHERE type='table' AND name = ?",
          [table],
        );
        if (exists.isEmpty) continue;
        // 备份也可能来自更早的 schema（例如 v11 的 transactions 没有
        // exclude_from_stats）。`SELECT *` 会因列数不匹配让整表恢复失败，
        // 因此只迁移**两边都存在**的列，新增列由其 NOT NULL DEFAULT 兜底。
        final localCols = _db
            .select('SELECT name FROM pragma_table_info(?)', [table])
            .map((r) => r['name']! as String)
            .toSet();
        final shared = _db
            .select('SELECT name FROM pragma_table_info(?, ?)', [table, 'backup'])
            .map((r) => r['name']! as String)
            .where(localCols.contains)
            .toList();
        if (shared.isEmpty) continue;
        final cols = shared.join(',');
        _db.execute('DELETE FROM $table');
        _db.execute('INSERT INTO $table ($cols) SELECT $cols FROM backup.$table');
      }
      // ⚠️ 设备身份属于「这台设备是谁」，不是「数据是什么」——**不能**被备份覆盖。
      // 覆盖后本机 deviceId 变成备份机的：两台设备 id 相同 → 增量同步把对方日志
      // 当成「自己写的」全部跳过，同步永久失效（audit 2026-10-15 发现）。
      // 注意 `book.default_id` 必须跟着备份走：所有行都按 book_id 过滤，
      // 换成本机账本 id 会让恢复后的数据全部查不到。
      if (localDeviceId != null && localDeviceId.isNotEmpty) {
        final now = DateTime.now().toUtc().millisecondsSinceEpoch;
        _db.execute(
          'INSERT INTO app_meta (key,value,updated_at) VALUES (?,?,?) '
          'ON CONFLICT(key) DO UPDATE SET value=?,updated_at=?',
          ['device.id', localDeviceId, now, localDeviceId, now],
        );
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
  exclude_from_stats INTEGER NOT NULL DEFAULT 0,
  original_amount_cents INTEGER NULL,
  exchange_rate_micro INTEGER NULL,
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
  is_deductible INTEGER NOT NULL DEFAULT 0,
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
  credit_annual_rate_bp INTEGER NOT NULL DEFAULT 0,
  min_payment_cents INTEGER NOT NULL DEFAULT 0,
  bill_day INTEGER NULL, due_day INTEGER NULL,
  loan_principal_cents INTEGER NOT NULL DEFAULT 0,
  loan_annual_rate_bp INTEGER NOT NULL DEFAULT 0,
  loan_term_months INTEGER NULL,
  loan_repay_method TEXT NULL,
  loan_first_payment_at INTEGER NULL,
  valuation_mode TEXT NOT NULL DEFAULT 'none',
  valuation_base_cents INTEGER NOT NULL DEFAULT 0,
  valuation_rate_bp INTEGER NOT NULL DEFAULT 0,
  valuation_manual_cents INTEGER NOT NULL DEFAULT 0,
  valuation_started_at INTEGER NULL,
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
  kind TEXT NOT NULL DEFAULT 'recurring',
  goal_id TEXT NULL,
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
  goal_account_id TEXT NULL,
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

/// STORY-10.1 投资持仓（v15）。
///
/// `shares_x10000` = 份额 × 10000（万分之一份，整数）；`cost_price_cents` 是
/// **加权平均成本单价**；摊销/市值全部派生，不落表。
const String _ddlHoldings = '''
CREATE TABLE IF NOT EXISTS holdings (
  id TEXT NOT NULL PRIMARY KEY, book_id TEXT NOT NULL, account_id TEXT NOT NULL,
  name TEXT NOT NULL, code TEXT NULL,
  asset_type TEXT NOT NULL DEFAULT 'other',
  shares_x10000 INTEGER NOT NULL DEFAULT 0,
  cost_price_cents INTEGER NOT NULL DEFAULT 0,
  last_price_cents INTEGER NOT NULL DEFAULT 0,
  price_updated_at INTEGER NULL,
  realized_pnl_cents INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, deleted_at INTEGER NULL,
  revision INTEGER NOT NULL DEFAULT 1, device_id TEXT NOT NULL, base_revision INTEGER NOT NULL DEFAULT 0
)''';

/// STORY-11.3「我的报表」（v18）：保存交叉分析的维度组合与筛选。
const String _ddlSavedReports = '''
CREATE TABLE IF NOT EXISTS saved_reports (
  id TEXT NOT NULL PRIMARY KEY, book_id TEXT NOT NULL,
  name TEXT NOT NULL,
  row_dim TEXT NOT NULL, col_dim TEXT NOT NULL,
  from_ms INTEGER NOT NULL, to_ms INTEGER NOT NULL,
  entry_filter TEXT NOT NULL DEFAULT 'expense',
  heatmap INTEGER NOT NULL DEFAULT 1,
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, deleted_at INTEGER NULL,
  revision INTEGER NOT NULL DEFAULT 1, device_id TEXT NOT NULL, base_revision INTEGER NOT NULL DEFAULT 0
)''';

/// STORY-11.5 税务申报状态（v19）。
///
/// 一个记账月或一个年度被标记「已申报」即落一行；取消申报则软删该行。
const String _ddlTaxFilings = '''
CREATE TABLE IF NOT EXISTS tax_filings (
  id TEXT NOT NULL PRIMARY KEY, book_id TEXT NOT NULL,
  period_key TEXT NOT NULL, period_kind TEXT NOT NULL DEFAULT 'month',
  filed_at INTEGER NOT NULL, note TEXT NULL,
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, deleted_at INTEGER NULL,
  revision INTEGER NOT NULL DEFAULT 1, device_id TEXT NOT NULL, base_revision INTEGER NOT NULL DEFAULT 0
)''';

/// STORY-9.3 锁定汇率（v20）。
///
/// 用户手填的「原币 → 本位币」汇率，跨重启保留（原先只存在内存 Map 里，重启即丢）。
/// 无外部汇率源，因此这里只有用户手动设定的值。
const String _ddlCurrencyRates = '''
CREATE TABLE IF NOT EXISTS currency_rates (
  id TEXT NOT NULL PRIMARY KEY, book_id TEXT NOT NULL,
  from_currency TEXT NOT NULL, to_currency TEXT NOT NULL,
  rate_micro INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  revision INTEGER NOT NULL DEFAULT 1, device_id TEXT NOT NULL, base_revision INTEGER NOT NULL DEFAULT 0
)''';

/// STORY-8.2 家庭成员。
///
/// 成员是**软删除**：退出（`status='left'`）后记录保留，历史账单的
/// `member_id` 仍指向它（不产生悬空外键），只是不再占 6 人名额（AC4）。
const String _ddlMembers = '''
CREATE TABLE IF NOT EXISTS members (
  id TEXT NOT NULL PRIMARY KEY, book_id TEXT NOT NULL,
  name TEXT NOT NULL, role TEXT NOT NULL DEFAULT 'member',
  status TEXT NOT NULL DEFAULT 'active', is_me INTEGER NOT NULL DEFAULT 0,
  joined_at INTEGER NOT NULL, left_at INTEGER NULL,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, deleted_at INTEGER NULL,
  revision INTEGER NOT NULL DEFAULT 1, device_id TEXT NOT NULL, base_revision INTEGER NOT NULL DEFAULT 0
)''';

/// STORY-8.2 AA 分摊参与人（一笔账单标了哪些人一起花的）。
const String _ddlEntryParticipants = '''
CREATE TABLE IF NOT EXISTS entry_participants (
  id TEXT NOT NULL PRIMARY KEY,
  entry_id TEXT NOT NULL, book_id TEXT NOT NULL, member_id TEXT NOT NULL,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, deleted_at INTEGER NULL,
  revision INTEGER NOT NULL DEFAULT 1, device_id TEXT NOT NULL, base_revision INTEGER NOT NULL DEFAULT 0
)''';

/// STORY-8.1 同步冲突（「冲突中心」的数据源）。
///
/// 三方合并中**同一字段**两端改成不同值时才落一条；`winner` 记录
/// 「最后写入」判定的结果，`resolution` 记录用户的裁决。
const String _ddlSyncConflicts = '''
CREATE TABLE IF NOT EXISTS sync_conflicts (
  id TEXT NOT NULL PRIMARY KEY, book_id TEXT NOT NULL,
  entity_type TEXT NOT NULL, entity_id TEXT NOT NULL,
  field TEXT NOT NULL,
  ancestor_value TEXT NULL, local_value TEXT NULL, remote_value TEXT NULL,
  local_payload TEXT NOT NULL, remote_payload TEXT NOT NULL,
  local_changed_at INTEGER NULL, remote_changed_at INTEGER NULL,
  winner TEXT NOT NULL,
  resolution TEXT NOT NULL DEFAULT 'unresolved',
  resolved_at INTEGER NULL,
  created_at INTEGER NOT NULL
)''';

/// STORY-8.1 同步位点：每个远端设备读到哪一条（`cursor.<deviceId>`）。
///
/// **设备本地状态**，不进 change_log、不参与同步——位点是「这台设备读到哪」，
/// 属于「这台设备怎么看数据」，按 8.1 的判定原则不该同步。
const String _ddlSyncState = '''
CREATE TABLE IF NOT EXISTS sync_state (
  key TEXT NOT NULL PRIMARY KEY, value TEXT NOT NULL, updated_at INTEGER NOT NULL
)''';

/// STORY-6.3 提醒历史（v24）。
///
/// `requested_level` 是**级别表定死的级别**，`level` 是夜间免打扰处理后的
/// **实际级别**：两者不同即「响铃被降级为静默」，次日 08:00 的汇总摘要按它统计。
/// `dedup_key` 是同类去重的唯一依据（如 `budget_warn:<budget>:<周期>:100`）。
///
/// 这是设备本地的提醒日志（不是账本数据）：不写 change_log、不进云同步，
/// 但随备份/恢复走。
const String _ddlReminders = '''
CREATE TABLE IF NOT EXISTS reminders (
  id TEXT NOT NULL PRIMARY KEY, book_id TEXT NOT NULL,
  kind TEXT NOT NULL, title TEXT NOT NULL, body TEXT NOT NULL,
  requested_level TEXT NOT NULL, level TEXT NOT NULL,
  dedup_key TEXT NOT NULL,
  triggered_at INTEGER NOT NULL,
  is_read INTEGER NOT NULL DEFAULT 0,
  digested INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL
)''';

final List<String> _indexes = [
  'CREATE INDEX IF NOT EXISTS idx_entry_book_time ON transactions(book_id, occurred_at DESC, id DESC) WHERE deleted_at IS NULL',
  'CREATE INDEX IF NOT EXISTS idx_entry_category ON transactions(category_id, occurred_at DESC) WHERE deleted_at IS NULL',
  'CREATE INDEX IF NOT EXISTS idx_entry_account ON transactions(account_id, occurred_at DESC) WHERE deleted_at IS NULL',
  'CREATE INDEX IF NOT EXISTS idx_entry_to_account ON transactions(to_account_id, occurred_at DESC) WHERE to_account_id IS NOT NULL AND deleted_at IS NULL',
  'CREATE INDEX IF NOT EXISTS idx_entry_batch ON transactions(batch_id) WHERE batch_id IS NOT NULL',
  'CREATE INDEX IF NOT EXISTS idx_entry_parent ON transactions(parent_id, occurred_at DESC) WHERE parent_id IS NOT NULL AND deleted_at IS NULL',
  // ⚠️ 唯一性按 **kind 分域**（支出/收入是两套独立命名空间，见
  // `category_naming.dart` 的 `categoryTitleConflictMessage`）。索引漏了 kind 时，
  // 收入侧的「其他」与支出侧的「其他」撞名 → 空库上 `preset_income_other`
  // 从来没建成过；而 App 里的重名校验是按 kind 判的，于是「允许过的名字」
  // 一到写库就失败（且 `create` 的返回值没人检查，静默丢行）。
  "CREATE UNIQUE INDEX IF NOT EXISTS uq_category_name ON categories(kind, COALESCE(parent_id, ''), name) WHERE deleted_at IS NULL",
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
  'CREATE INDEX IF NOT EXISTS idx_holding_account ON holdings(account_id) WHERE deleted_at IS NULL',
  'CREATE UNIQUE INDEX IF NOT EXISTS uq_member_name ON members(book_id, name) WHERE deleted_at IS NULL',
  'CREATE INDEX IF NOT EXISTS idx_member_active ON members(book_id, status) WHERE deleted_at IS NULL',
  'CREATE UNIQUE INDEX IF NOT EXISTS uq_entry_participant ON entry_participants(entry_id, member_id) WHERE deleted_at IS NULL',
  'CREATE INDEX IF NOT EXISTS idx_participant_member ON entry_participants(member_id) WHERE deleted_at IS NULL',
  'CREATE INDEX IF NOT EXISTS idx_entry_member ON transactions(member_id, occurred_at DESC) WHERE member_id IS NOT NULL AND deleted_at IS NULL',
  'CREATE INDEX IF NOT EXISTS idx_sync_conflict_open ON sync_conflicts(resolution, created_at) WHERE resolution = \'unresolved\'',
  'CREATE INDEX IF NOT EXISTS idx_sync_conflict_entity ON sync_conflicts(entity_type, entity_id)',
  'CREATE INDEX IF NOT EXISTS idx_saved_report_book ON saved_reports(book_id) WHERE deleted_at IS NULL',
  'CREATE UNIQUE INDEX IF NOT EXISTS uq_tax_filing_period ON tax_filings(book_id, period_key, period_kind) WHERE deleted_at IS NULL',
  'CREATE UNIQUE INDEX IF NOT EXISTS uq_currency_pair ON currency_rates(book_id, from_currency, to_currency)',
  // STORY-1.6：学习是「同一商户累加命中次数」，因此按 (book, merchant) 唯一。
  // 该表此前无写入路径（无仓储），故无历史重复行，加唯一索引是安全的。
  'CREATE UNIQUE INDEX IF NOT EXISTS uq_merchant_rule ON merchant_rules(book_id, merchant) WHERE deleted_at IS NULL',
  // v24：提醒历史。去重查 (book_id, dedup_key)；历史列表与 GC 查 (book_id, triggered_at)。
  'CREATE INDEX IF NOT EXISTS idx_reminder_dedup ON reminders(book_id, dedup_key, triggered_at DESC)',
  'CREATE INDEX IF NOT EXISTS idx_reminder_book_time ON reminders(book_id, triggered_at DESC)',
];
