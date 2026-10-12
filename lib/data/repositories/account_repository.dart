/// Account repository implementation. Balance is derived (see 08-7.2).
library;

import 'package:plain/core/result/result.dart';
import 'package:plain/core/time/clock.dart';
import 'package:plain/data/db/database.dart';
import 'package:plain/data/db/row_x.dart';
import 'package:plain/data/db/run_write.dart';
import 'package:plain/data/sync/change_log_writer.dart';
import 'package:plain/domain/entities/category.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/repositories/repositories.dart';

class AccountRepositoryImpl implements AccountRepository {
  AccountRepositoryImpl({
    required AppDatabase db,
    required ChangeLogWriter changeLogWriter,
    required Clock clock,
  })  : _db = db,
        _changeLog = changeLogWriter,
        _clock = clock;

  final AppDatabase _db;
  final ChangeLogWriter _changeLog;
  final Clock _clock;

  @override
  Future<Result<List<Account>>> listAll() async {
    try {
      final rows = _db.raw.select(
        'SELECT * FROM accounts WHERE deleted_at IS NULL ORDER BY sort_order ASC',
      );
      return ok(rows.map(_fromRow).toList());
    } on Exception catch (e) {
      return err(StorageFailure('db.query_failed', e.toString(), isRetryable: true));
    }
  }

  @override
  Future<Result<List<AccountWithBalance>>> listWithBalances() async {
    try {
      final rows = _db.raw.select(
        'SELECT * FROM accounts WHERE deleted_at IS NULL ORDER BY sort_order ASC',
      );
      // One grouped query instead of 2N+1. STORY-6.2：子笔不计余额。
      final sums = _db.raw.select(
        'SELECT account_id, to_account_id, type, SUM(amount_cents) AS s '
        "FROM transactions WHERE deleted_at IS NULL AND split_role <> 'child' "
        'GROUP BY account_id, to_account_id, type',
      );
      final expenseBy = <String, int>{};
      final incomeBy = <String, int>{};
      final transferOutBy = <String, int>{};
      final transferInBy = <String, int>{};
      for (final r in sums) {
        final acc = r['account_id'] as String?;
        final to = r['to_account_id'] as String?;
        final type = r['type']! as String;
        final s = (r['s'] as int?) ?? 0;
        if (type == EntryType.expense.wire && acc != null) {
          expenseBy[acc] = (expenseBy[acc] ?? 0) + s;
        } else if (type == EntryType.income.wire && acc != null) {
          incomeBy[acc] = (incomeBy[acc] ?? 0) + s;
        } else if (type == EntryType.transfer.wire) {
          if (acc != null) transferOutBy[acc] = (transferOutBy[acc] ?? 0) + s;
          if (to != null) transferInBy[to] = (transferInBy[to] ?? 0) + s;
        }
      }
      final out = <AccountWithBalance>[];
      for (final row in rows) {
        final a = _fromRow(row);
        final bal = a.openingBalance -
            (expenseBy[a.id] ?? 0) +
            (incomeBy[a.id] ?? 0) -
            (transferOutBy[a.id] ?? 0) +
            (transferInBy[a.id] ?? 0);
        out.add(AccountWithBalance(account: a, balanceCents: bal));
      }
      return ok(out);
    } on Exception catch (e) {
      return err(StorageFailure('db.query_failed', e.toString(), isRetryable: true));
    }
  }

  @override
  Future<Result<Account>> getById(String id) async {
    final rows = _db.raw.select(
      'SELECT * FROM accounts WHERE id = ? AND deleted_at IS NULL',
      [id],
    );
    if (rows.isEmpty) {
      return err<Account>(const NotFoundFailure('account.not_found', 'not found'));
    }
    return ok(_fromRow(rows.first));
  }

  @override
  Future<Result<Account>> create(Account account) async {
    return runWrite(
      _db,
      failCode: 'db.insert_failed',
      result: account,
      body: () {
        _insert(account);
        _changeLog.write(
          entityType: EntityType.account,
          entityId: account.id,
          op: ChangeOp.insert,
          deviceId: account.deviceId,
          baseRevision: 0,
          before: const {},
          after: _payload(account),
        );
      },
    );
  }

  @override
  Future<Result<Account>> update(Account account) async {
    final existing = await getById(account.id);
    final f = existing.failureOrNull;
    if (f != null) return err<Account>(f);
    final old = existing.successOrNull!;
    return runWrite(
      _db,
      failCode: 'db.update_failed',
      result: account,
      body: () {
        _update(account);
        _changeLog.write(
          entityType: EntityType.account,
          entityId: account.id,
          op: ChangeOp.update,
          deviceId: account.deviceId,
          baseRevision: account.baseRevision,
          before: _payload(old),
          after: _payload(account),
        );
      },
    );
  }

  @override
  Future<Result<void>> softDelete(String id) async {
    // STORY-2.1 AC2/AC6：有引用（账单/转入/周期/预算）不可删，应迁移或隐藏
    final refs = await countReferences(id);
    final counts = refs.successOrNull;
    if (counts != null && !counts.isEmpty) {
      return err<void>(const ConflictFailure(
        'account.has_references',
        'Account has transactions/rules. Migrate or hide instead.',
      ));
    }

    final existing = await getById(id);
    final f = existing.failureOrNull;
    if (f != null) return err<void>(f);

    final acct = existing.successOrNull!;
    final now = _clock.now();
    final deleted = acct.copyWith(
      deletedAt: now,
      updatedAt: now,
      revision: acct.revision + 1,
      baseRevision: acct.revision,
    );

    return runWrite<void>(
      _db,
      failCode: 'db.delete_failed',
      result: null,
      body: () {
        _update(deleted);
        _changeLog.write(
          entityType: EntityType.account,
          entityId: id,
          op: ChangeOp.delete,
          deviceId: acct.deviceId,
          baseRevision: acct.revision,
          before: _payload(acct),
          after: const {},
        );
      },
    );
  }

  @override
  Future<Result<AccountRefCounts>> countReferences(String accountId) async {
    try {
      int count(String sql, List<Object?> args) {
        final rows = _db.raw.select(sql, args);
        return (rows.first['c'] as int?) ?? 0;
      }

      final tx = count(
        'SELECT COUNT(*) AS c FROM transactions '
        'WHERE account_id = ? AND deleted_at IS NULL',
        [accountId],
      );
      final transferIn = count(
        'SELECT COUNT(*) AS c FROM transactions '
        'WHERE to_account_id = ? AND deleted_at IS NULL',
        [accountId],
      );
      final recurring = count(
        'SELECT COUNT(*) AS c FROM recurring_rules '
        'WHERE (account_id = ? OR to_account_id = ?) AND deleted_at IS NULL',
        [accountId, accountId],
      );
      // budgets 表当前无 account_id 维度（只按 book/category），故恒为 0。
      const budgets = 0;
      return ok(AccountRefCounts(
        transactions: tx,
        transferIn: transferIn,
        recurringRules: recurring,
        budgets: budgets,
      ));
    } on Object catch (e) {
      return err(StorageFailure('db.query_failed', e.toString(), isRetryable: true));
    }
  }

  @override
  Future<Result<int>> migrateTransactions({required String fromId, required String toId}) async {
    if (fromId == toId) {
      return err(const ValidationFailure('account.migrate_same', 'same'));
    }
    try {
      var moved = 0;
      _db.transaction(() {
        final before = _db.raw.select(
          'SELECT COUNT(*) AS c FROM transactions '
          'WHERE (account_id = ? OR to_account_id = ?) AND deleted_at IS NULL',
          [fromId, fromId],
        );
        final countBefore = (before.first['c'] as int?) ?? 0;
        _db.raw.execute(
          'UPDATE transactions SET account_id = ? WHERE account_id = ?',
          [toId, fromId],
        );
        _db.raw.execute(
          'UPDATE transactions SET to_account_id = ? WHERE to_account_id = ?',
          [toId, fromId],
        );
        _db.raw.execute(
          'UPDATE recurring_rules SET account_id = ? WHERE account_id = ? AND deleted_at IS NULL',
          [toId, fromId],
        );
        _db.raw.execute(
          'UPDATE recurring_rules SET to_account_id = ? WHERE to_account_id = ? AND deleted_at IS NULL',
          [toId, fromId],
        );
        final after = _db.raw.select(
          'SELECT COUNT(*) AS c FROM transactions '
          'WHERE (account_id = ? OR to_account_id = ?) AND deleted_at IS NULL',
          [fromId, fromId],
        );
        final countAfter = (after.first['c'] as int?) ?? 0;
        moved = countBefore - countAfter;
      });
      return ok(moved);
    } on Object catch (e) {
      return err(StorageFailure('db.migrate_failed', e.toString(), isRetryable: true));
    }
  }

  @override
  Future<Result<int>> detachFromAccount(String accountId) async {
    try {
      var affected = 0;
      _db.transaction(() {
        final before = _db.raw.select(
          'SELECT COUNT(*) AS c FROM transactions '
          'WHERE (account_id = ? OR to_account_id = ?) AND deleted_at IS NULL',
          [accountId, accountId],
        );
        affected = (before.first['c'] as int?) ?? 0;
        // 把引用该账户的账单和周期规则改为「不指定账户」
        _db.raw.execute(
          'UPDATE transactions SET account_id = NULL WHERE account_id = ?',
          [accountId],
        );
        _db.raw.execute(
          'UPDATE transactions SET to_account_id = NULL WHERE to_account_id = ?',
          [accountId],
        );
        _db.raw.execute(
          'UPDATE recurring_rules SET account_id = NULL WHERE account_id = ? AND deleted_at IS NULL',
          [accountId],
        );
        _db.raw.execute(
          'UPDATE recurring_rules SET to_account_id = NULL WHERE to_account_id = ? AND deleted_at IS NULL',
          [accountId],
        );
      });
      return ok(affected);
    } on Object catch (e) {
      return err(StorageFailure('db.detach_failed', e.toString(), isRetryable: true));
    }
  }

  @override
  Future<Result<AccountBalance>> balanceOf(String accountId) async {
    try {
      final acct = await getById(accountId);
      final f = acct.failureOrNull;
      if (f != null) return err(f);

      final opening = acct.successOrNull!.openingBalance;

      // Sum expenses (negative) and income (positive) for this account.
      // STORY-6.2：子笔不计余额（仅父笔/普通）。
      const notChild = "AND split_role <> 'child'";
      final expenseRow = _db.raw.select(
        'SELECT COALESCE(SUM(amount_cents), 0) AS s FROM transactions '
        'WHERE account_id = ? AND type = ? AND deleted_at IS NULL $notChild',
        [accountId, EntryType.expense.wire],
      );
      final incomeRow = _db.raw.select(
        'SELECT COALESCE(SUM(amount_cents), 0) AS s FROM transactions '
        'WHERE account_id = ? AND type = ? AND deleted_at IS NULL $notChild',
        [accountId, EntryType.income.wire],
      );
      final countRow = _db.raw.select(
        'SELECT COUNT(*) AS c FROM transactions '
        'WHERE (account_id = ? OR to_account_id = ?) AND deleted_at IS NULL $notChild',
        [accountId, accountId],
      );

      final totalExpense = expenseRow.first['s']! as int;
      final totalIncome = incomeRow.first['s']! as int;
      final txCount = countRow.first['c']! as int;

      // Transfers: subtract outgoing, add incoming
      final transferOut = _db.raw.select(
        'SELECT COALESCE(SUM(amount_cents), 0) AS s FROM transactions '
        'WHERE account_id = ? AND type = ? AND deleted_at IS NULL $notChild',
        [accountId, EntryType.transfer.wire],
      );
      final transferIn = _db.raw.select(
        'SELECT COALESCE(SUM(amount_cents), 0) AS s FROM transactions '
        'WHERE to_account_id = ? AND type = ? AND deleted_at IS NULL $notChild',
        [accountId, EntryType.transfer.wire],
      );

      final balance = opening -
          totalExpense +
          totalIncome -
          (transferOut.first['s']! as int) +
          (transferIn.first['s']! as int);

      return ok(AccountBalance(
        accountId: accountId,
        balanceCents: balance,
        openingCents: opening,
        txCount: txCount,
      ));
    } on Exception catch (e) {
      return err(StorageFailure('db.query_failed', e.toString(), isRetryable: true));
    }
  }

  @override
  Future<Result<void>> reconcile({
    required String accountId,
    required int actualBalanceCents,
    required String deviceId,
    required String bookId,
    required String otherCategoryId,
  }) async {
    try {
      final balanceResult = await balanceOf(accountId);
      final f = balanceResult.failureOrNull;
      if (f != null) return err(f);

      final currentBalance = balanceResult.successOrNull!.balanceCents;
      final diff = actualBalanceCents - currentBalance;

      if (diff == 0) return ok(null);

      // Create adjustment entry (PRD STORY-2.1 AC3).
      // Prefer CreateEntryUseCase at call sites — this is a lower-level fallback
      // and must keep change_log + unique id intact. **不写 daily_stats**（G-2/C11）。
      final now = _clock.now();
      final isExpense = diff < 0;
      final adjType = isExpense ? EntryType.expense : EntryType.income;
      final adjAmount = diff.abs();
      // Time-ordered unique id (millis + sub-ms avoids same-ms collisions).
      final adjId = 'recon_${now.millisecondsSinceEpoch}'
          '_${now.microsecondsSinceEpoch % 1000000}';

      return runWrite(
        _db,
        failCode: 'db.reconcile_failed',
        result: null,
        body: () {
          _db.raw.execute(
            'INSERT INTO transactions '
            '(id,book_id,type,amount_cents,currency,category_id,account_id,'
            'occurred_at,note,source,created_at,updated_at,revision,device_id,base_revision) '
            'VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
            [
              adjId,
              bookId,
              adjType.wire,
              adjAmount,
              'CNY',
              otherCategoryId,
              accountId,
              now.millisecondsSinceEpoch,
              '对账调整',
              EntrySource.reconcile.wire,
              now.millisecondsSinceEpoch,
              now.millisecondsSinceEpoch,
              1,
              deviceId,
              0,
            ],
          );
          // G-2 / C11：对账调整不写 daily_stats——它只修余额，
          // 进统计会污染消费与分类口径。分类计数/报表/预算一律排除 source=reconcile。
          _changeLog.write(
            entityType: EntityType.transaction,
            entityId: adjId,
            op: ChangeOp.insert,
            deviceId: deviceId,
            baseRevision: 0,
            before: const {},
            after: {
              'id': adjId, 'book_id': bookId, 'type': adjType.wire,
              'amount_cents': adjAmount, 'category_id': otherCategoryId,
              'account_id': accountId, 'source': 'reconcile',
            },
          );
        },
      );
    } on Exception catch (e) {
      return err(StorageFailure('db.reconcile_failed', e.toString(), isRetryable: true));
    }
  }

  void _insert(Account a) {
    _db.raw.execute(
      'INSERT INTO accounts '
      '(id,name,type,currency,opening_balance_cents,note,sort_order,is_hidden,'
      'credit_limit_cents,credit_debt_cents,bill_day,due_day,'
      'created_at,updated_at,revision,device_id,base_revision) '
      'VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
      [
        a.id, a.name, a.type.wire, a.currency, a.openingBalance,
        a.note, a.sortOrder, a.isHidden ? 1 : 0,
        a.creditLimitCents, a.creditDebtCents, a.billDay, a.dueDay,
        a.createdAt.millisecondsSinceEpoch, a.updatedAt.millisecondsSinceEpoch,
        a.revision, a.deviceId, a.baseRevision,
      ],
    );
  }

  void _update(Account a) {
    _db.raw.execute(
      'UPDATE accounts SET name=?,type=?,currency=?,opening_balance_cents=?,'
      'note=?,sort_order=?,is_hidden=?,credit_limit_cents=?,credit_debt_cents=?,'
      'bill_day=?,due_day=?,updated_at=?,deleted_at=?,revision=?,'
      'base_revision=? WHERE id=?',
      [
        a.name, a.type.wire, a.currency, a.openingBalance, a.note, a.sortOrder,
        a.isHidden ? 1 : 0,
        a.creditLimitCents, a.creditDebtCents, a.billDay, a.dueDay,
        a.updatedAt.millisecondsSinceEpoch,
        a.deletedAt?.millisecondsSinceEpoch,
        a.revision, a.baseRevision, a.id,
      ],
    );
  }

  Account _fromRow(Map<String, Object?> row) => Account(
        id: row['id']! as String,
        name: row['name']! as String,
        type: AccountType.fromWire(row['type'] as String?),
        currency: (row['currency'] as String?) ?? 'CNY',
        openingBalance: (row['opening_balance_cents'] as int?) ?? 0,
        note: row['note'] as String?,
        sortOrder: row['sort_order']! as int,
        isHidden: row.boolOr('is_hidden'),
        creditLimitCents: row.intOr('credit_limit_cents', 0),
        creditDebtCents: row.intOr('credit_debt_cents', 0),
        billDay: row['bill_day'] as int?,
        dueDay: row['due_day'] as int?,
        createdAt: row.dateTime('created_at'),
        updatedAt: row.dateTime('updated_at'),
        deletedAt: row.nullableDateTime('deleted_at'),
        revision: row.intOr('revision', 1),
        deviceId: row['device_id']! as String,
        baseRevision: row.intOr('base_revision', 0),
      );

  Map<String, Object?> _payload(Account a) => {
        'id': a.id, 'name': a.name, 'type': a.type.wire,
        'opening_balance_cents': a.openingBalance,
        'sort_order': a.sortOrder, 'is_hidden': a.isHidden,
        'credit_limit_cents': a.creditLimitCents,
        'credit_debt_cents': a.creditDebtCents,
        'bill_day': a.billDay, 'due_day': a.dueDay,
      };
}
