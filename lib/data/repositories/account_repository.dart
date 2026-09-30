/// Account repository implementation. Balance is derived (see 08-7.2).
library;

import 'package:plain/core/result/result.dart';
import 'package:plain/core/time/clock.dart';
import 'package:plain/data/db/database.dart';
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
    try {
      _db.transaction(() {
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
      });
      return ok(account);
    } on Exception catch (e) {
      return err(StorageFailure('db.insert_failed', e.toString(), isRetryable: true));
    }
  }

  @override
  Future<Result<Account>> update(Account account) async {
    try {
      _db.transaction(() {
        _update(account);
        _changeLog.write(
          entityType: EntityType.account,
          entityId: account.id,
          op: ChangeOp.update,
          deviceId: account.deviceId,
          baseRevision: account.baseRevision,
          before: const {},
          after: _payload(account),
        );
      });
      return ok(account);
    } on Exception catch (e) {
      return err(StorageFailure('db.update_failed', e.toString(), isRetryable: true));
    }
  }

  @override
  Future<Result<void>> softDelete(String id) async {
    try {
      // Check for transaction references (PRD STORY-2.1 AC2)
      final refCount = _db.raw.select(
        'SELECT COUNT(*) AS c FROM transactions '
        'WHERE (account_id = ? OR to_account_id = ?) AND deleted_at IS NULL',
        [id, id],
      );
      if ((refCount.first['c'] as int) > 0) {
        return err<void>(const ConflictFailure(
          'account.has_transactions',
          'Account has transactions. Migrate or hide instead.',
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

      _db.transaction(() {
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
      });
      return ok(null);
    } on Exception catch (e) {
      return err(StorageFailure('db.delete_failed', e.toString(), isRetryable: true));
    }
  }

  @override
  Future<Result<AccountBalance>> balanceOf(String accountId) async {
    try {
      final acct = await getById(accountId);
      final f = acct.failureOrNull;
      if (f != null) return err(f);

      final opening = acct.successOrNull!.openingBalance;

      // Sum expenses (negative) and income (positive) for this account
      final expenseRow = _db.raw.select(
        'SELECT COALESCE(SUM(amount_cents), 0) AS s FROM transactions '
        'WHERE account_id = ? AND type = ? AND deleted_at IS NULL',
        [accountId, EntryType.expense.wire],
      );
      final incomeRow = _db.raw.select(
        'SELECT COALESCE(SUM(amount_cents), 0) AS s FROM transactions '
        'WHERE account_id = ? AND type = ? AND deleted_at IS NULL',
        [accountId, EntryType.income.wire],
      );
      final countRow = _db.raw.select(
        'SELECT COUNT(*) AS c FROM transactions '
        'WHERE (account_id = ? OR to_account_id = ?) AND deleted_at IS NULL',
        [accountId, accountId],
      );

      final totalExpense = expenseRow.first['s']! as int;
      final totalIncome = incomeRow.first['s']! as int;
      final txCount = countRow.first['c']! as int;

      // Transfers: subtract outgoing, add incoming
      final transferOut = _db.raw.select(
        'SELECT COALESCE(SUM(amount_cents), 0) AS s FROM transactions '
        'WHERE account_id = ? AND type = ? AND deleted_at IS NULL',
        [accountId, EntryType.transfer.wire],
      );
      final transferIn = _db.raw.select(
        'SELECT COALESCE(SUM(amount_cents), 0) AS s FROM transactions '
        'WHERE to_account_id = ? AND type = ? AND deleted_at IS NULL',
        [accountId, EntryType.transfer.wire],
      );

      final balance = opening - totalExpense + totalIncome
          - (transferOut.first['s']! as int)
          + (transferIn.first['s']! as int);

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

      // Create adjustment entry (PRD STORY-2.1 AC3)
      final now = _clock.now();
      final isExpense = diff < 0;
      final adjType = isExpense ? EntryType.expense : EntryType.income;
      final adjAmount = diff.abs();
      final adjId = 'reconcile_${now.millisecondsSinceEpoch}';

      _db.transaction(() {
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
            'Reconcile adjustment',
            EntrySource.reconcile.wire,
            now.millisecondsSinceEpoch,
            now.millisecondsSinceEpoch,
            1,
            deviceId,
            0,
          ],
        );
        _changeLog.write(
          entityType: EntityType.transaction,
          entityId: adjId,
          op: ChangeOp.insert,
          deviceId: deviceId,
          baseRevision: 0,
          before: const {},
          after: {'id': adjId, 'amount_cents': adjAmount, 'source': 'reconcile'},
        );
      });

      return ok(null);
    } on Exception catch (e) {
      return err(StorageFailure('db.reconcile_failed', e.toString(), isRetryable: true));
    }
  }

  void _insert(Account a) {
    _db.raw.execute(
      'INSERT INTO accounts '
      '(id,name,type,currency,opening_balance_cents,note,sort_order,is_hidden,'
      'created_at,updated_at,revision,device_id,base_revision) '
      'VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)',
      [
        a.id, a.name, a.type.wire, a.currency, a.openingBalance,
        a.note, a.sortOrder, a.isHidden ? 1 : 0,
        a.createdAt.millisecondsSinceEpoch, a.updatedAt.millisecondsSinceEpoch,
        a.revision, a.deviceId, a.baseRevision,
      ],
    );
  }

  void _update(Account a) {
    _db.raw.execute(
      'UPDATE accounts SET name=?,opening_balance_cents=?,note=?,sort_order=?,'
      'is_hidden=?,updated_at=?,deleted_at=?,revision=?,base_revision=? WHERE id=?',
      [
        a.name, a.openingBalance, a.note, a.sortOrder,
        a.isHidden ? 1 : 0,
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
        isHidden: (row['is_hidden'] as int?) == 1,
        createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at']! as int, isUtc: true),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at']! as int, isUtc: true),
        deletedAt: row['deleted_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(row['deleted_at']! as int, isUtc: true),
        revision: (row['revision'] as int?) ?? 1,
        deviceId: row['device_id']! as String,
        baseRevision: (row['base_revision'] as int?) ?? 0,
      );

  Map<String, Object?> _payload(Account a) => {
        'id': a.id, 'name': a.name, 'type': a.type.wire,
        'opening_balance_cents': a.openingBalance,
        'sort_order': a.sortOrder, 'is_hidden': a.isHidden,
      };
}
