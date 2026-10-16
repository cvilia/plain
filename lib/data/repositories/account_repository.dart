/// Account repository implementation. Balance is derived (see 08-7.2).
library;

import 'package:plain/core/constants/app_constants.dart';
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

  /// STORY-6.2：拆分子笔不计账户余额（金额已在父笔计入一次）。
  static const String _notChild = "split_role <> 'child'";

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
      // STORY-1.7：借出/借入也要计入账户余额（G-2「计入账户余额 = 是」）——
      // 借出是从所选账户出钱、借入是进钱，方向与转出/转入一致。
      final sums = _db.raw.select(
        'SELECT account_id, to_account_id, type, SUM(amount_cents) AS s '
        "FROM transactions WHERE deleted_at IS NULL AND split_role <> 'child' "
        'GROUP BY account_id, to_account_id, type',
      );
      final expenseBy = <String, int>{};
      final incomeBy = <String, int>{};
      final transferOutBy = <String, int>{};
      final transferInBy = <String, int>{};
      final borrowOutBy = <String, int>{};
      final borrowInBy = <String, int>{};
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
        } else if (type == EntryType.borrowOut.wire && acc != null) {
          borrowOutBy[acc] = (borrowOutBy[acc] ?? 0) + s;
        } else if (type == EntryType.borrowIn.wire && acc != null) {
          borrowInBy[acc] = (borrowInBy[acc] ?? 0) + s;
        }
      }
      final out = <AccountWithBalance>[];
      for (final row in rows) {
        final a = _fromRow(row);
        out.add(AccountWithBalance(
          account: a,
          // G-2.1 例外：信用卡欠款余额是**存储值**，与账户余额互为负值；
          // 其余类型走五段式派生。
          balanceCents: a.isCredit
              ? -a.creditDebtCents
              : _derivedCents(
                  opening: _openingForBalance(a),
                  expense: expenseBy[a.id] ?? 0,
                  income: incomeBy[a.id] ?? 0,
                  transferOut: transferOutBy[a.id] ?? 0,
                  transferIn: transferInBy[a.id] ?? 0,
                  borrowOut: borrowOutBy[a.id] ?? 0,
                  borrowIn: borrowInBy[a.id] ?? 0,
                ),
        ));
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
      final account = acct.successOrNull!;

      // G-2.1：信用卡是唯一例外——欠款余额是存储值（可被对账直接修正），
      // 账户余额与它互为负值，不做派生。
      if (account.isCredit) {
        return ok(AccountBalance(
          accountId: accountId,
          balanceCents: -account.creditDebtCents,
          openingCents: account.openingBalance,
          txCount: _countLiveTx(accountId),
        ));
      }

      return ok(await _derivedBalanceOf(account));
    } on Exception catch (e) {
      return err(StorageFailure('db.query_failed', e.toString(), isRetryable: true));
    }
  }

  /// 恒走五段式派生，**不看账户类型**。
  ///
  /// 信用卡对账页需要「按账单实时聚合」来与存储的欠款余额比对（STORY-2.2 AC8），
  /// 因此这个口径必须能绕开 [balanceOf] 的信用卡分流独立调用。
  @override
  Future<Result<AccountBalance>> derivedBalanceOf(String accountId) async {
    try {
      final acct = await getById(accountId);
      final f = acct.failureOrNull;
      if (f != null) return err(f);
      return ok(await _derivedBalanceOf(acct.successOrNull!));
    } on Exception catch (e) {
      return err(StorageFailure('db.query_failed', e.toString(), isRetryable: true));
    }
  }

  Future<AccountBalance> _derivedBalanceOf(Account account) async {
    final id = account.id;
    return AccountBalance(
      accountId: id,
      balanceCents: _derivedCents(
        opening: _openingForBalance(account),
        expense: _sumAmounts('account_id', id, EntryType.expense.wire),
        income: _sumAmounts('account_id', id, EntryType.income.wire),
        transferOut: _sumAmounts('account_id', id, EntryType.transfer.wire),
        transferIn: _sumAmounts('to_account_id', id, EntryType.transfer.wire),
        // STORY-1.7：借出账户出钱、借入账户进钱（G-2 计入账户余额）
        borrowOut: _sumAmounts('account_id', id, EntryType.borrowOut.wire),
        borrowIn: _sumAmounts('account_id', id, EntryType.borrowIn.wire),
      ),
      openingCents: _openingForBalance(account),
      txCount: _countLiveTx(id),
    );
  }

  /// 账户余额里**参与**的期初金额（分）。
  ///
  /// V3.0 拍板（2026-10-15）：**外币账户按单币种账户处理**，账户余额只走本位币口径。
  /// `transactions.amount_cents` 恒为本位币（STORY-9.3），所以流水部分天然是本位币；
  /// 而 `opening_balance_cents` 是用户在**账户自身币种**下填的数（USD 账户填 1000
  /// 就是 1000 美元），直接相加等于把原币当本位币混加。
  ///
  /// 因此外币账户的期初在这里不参与；它在净值里按锁定汇率折算参与
  /// （`NetWorthService.convertedOpeningCents`），拿不到汇率则该账户不进净值。
  static int _openingForBalance(Account account) =>
      account.currency == MoneyRules.defaultCurrency ? account.openingBalance : 0;

  /// G-2.1 余额恒等式：
  /// 期初 − Σ支出 + Σ收入 − Σ转出 + Σ转入 − Σ借出 + Σ借入。
  ///
  /// 借出/借入与转出/转入**同向**（STORY-1.7）：借出是钱离开所选账户，
  /// 借入是钱进入所选账户；两者都不计入收支统计（G-2），只动余额。
  static int _derivedCents({
    required int opening,
    required int expense,
    required int income,
    required int transferOut,
    required int transferIn,
    int borrowOut = 0,
    int borrowIn = 0,
  }) =>
      opening -
      expense +
      income -
      transferOut +
      transferIn -
      borrowOut +
      borrowIn;

  int _sumAmounts(String accountColumn, String accountId, String type) {
    final rows = _db.raw.select(
      'SELECT COALESCE(SUM(amount_cents), 0) AS s FROM transactions '
      'WHERE $accountColumn = ? AND type = ? AND deleted_at IS NULL AND $_notChild',
      [accountId, type],
    );
    return rows.first['s']! as int;
  }

  int _countLiveTx(String accountId) {
    final rows = _db.raw.select(
      'SELECT COUNT(*) AS c FROM transactions '
      'WHERE (account_id = ? OR to_account_id = ?) '
      'AND deleted_at IS NULL AND $_notChild',
      [accountId, accountId],
    );
    return rows.first['c']! as int;
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
      'credit_annual_rate_bp,min_payment_cents,'
      'loan_principal_cents,loan_annual_rate_bp,loan_term_months,loan_repay_method,loan_first_payment_at,'
      'valuation_mode,valuation_base_cents,valuation_rate_bp,valuation_manual_cents,valuation_started_at,'
      'created_at,updated_at,revision,device_id,base_revision) '
      'VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
      [
        a.id, a.name, a.type.wire, a.currency, a.openingBalance,
        a.note, a.sortOrder, a.isHidden ? 1 : 0,
        a.creditLimitCents, a.creditDebtCents, a.billDay, a.dueDay,
        a.creditAnnualRateBp, a.minPaymentCents,
        a.loanPrincipalCents, a.loanAnnualRateBp, a.loanTermMonths,
        a.loanRepayMethod?.wire, a.loanFirstPaymentAt?.millisecondsSinceEpoch,
        a.valuationMode.wire, a.valuationBaseCents, a.valuationRateBp,
        a.valuationManualCents, a.valuationStartedAt?.millisecondsSinceEpoch,
        a.createdAt.millisecondsSinceEpoch, a.updatedAt.millisecondsSinceEpoch,
        a.revision, a.deviceId, a.baseRevision,
      ],
    );
  }

  void _update(Account a) {
    _db.raw.execute(
      'UPDATE accounts SET name=?,type=?,currency=?,opening_balance_cents=?,'
      'note=?,sort_order=?,is_hidden=?,credit_limit_cents=?,credit_debt_cents=?,'
      'bill_day=?,due_day=?,credit_annual_rate_bp=?,min_payment_cents=?,'
      'loan_principal_cents=?,loan_annual_rate_bp=?,'
      'loan_term_months=?,loan_repay_method=?,loan_first_payment_at=?,'
      'valuation_mode=?,valuation_base_cents=?,valuation_rate_bp=?,'
      'valuation_manual_cents=?,valuation_started_at=?,'
      'updated_at=?,deleted_at=?,revision=?,'
      'base_revision=? WHERE id=?',
      [
        a.name, a.type.wire, a.currency, a.openingBalance, a.note, a.sortOrder,
        a.isHidden ? 1 : 0,
        a.creditLimitCents, a.creditDebtCents, a.billDay, a.dueDay,
        a.creditAnnualRateBp, a.minPaymentCents,
        a.loanPrincipalCents, a.loanAnnualRateBp, a.loanTermMonths,
        a.loanRepayMethod?.wire, a.loanFirstPaymentAt?.millisecondsSinceEpoch,
        a.valuationMode.wire, a.valuationBaseCents, a.valuationRateBp,
        a.valuationManualCents, a.valuationStartedAt?.millisecondsSinceEpoch,
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
        creditAnnualRateBp: row.intOr('credit_annual_rate_bp', 0),
        minPaymentCents: row.intOr('min_payment_cents', 0),
        loanPrincipalCents: row.intOr('loan_principal_cents', 0),
        loanAnnualRateBp: row.intOr('loan_annual_rate_bp', 0),
        loanTermMonths: row['loan_term_months'] as int?,
        loanRepayMethod: row['loan_repay_method'] == null
            ? null
            : LoanRepayMethod.fromWire(row['loan_repay_method'] as String?),
        loanFirstPaymentAt: row.nullableDateTime('loan_first_payment_at'),
        valuationMode: AssetValuationMode.fromWire(row['valuation_mode'] as String?),
        valuationBaseCents: row.intOr('valuation_base_cents', 0),
        valuationRateBp: row.intOr('valuation_rate_bp', 0),
        valuationManualCents: row.intOr('valuation_manual_cents', 0),
        valuationStartedAt: row.nullableDateTime('valuation_started_at'),
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
        'credit_annual_rate_bp': a.creditAnnualRateBp,
        'min_payment_cents': a.minPaymentCents,
        'loan_principal_cents': a.loanPrincipalCents,
        'loan_annual_rate_bp': a.loanAnnualRateBp,
        'loan_term_months': a.loanTermMonths,
        'loan_repay_method': a.loanRepayMethod?.wire,
        'loan_first_payment_at': a.loanFirstPaymentAt?.millisecondsSinceEpoch,
        'valuation_mode': a.valuationMode.wire,
        'valuation_base_cents': a.valuationBaseCents,
        'valuation_rate_bp': a.valuationRateBp,
        'valuation_manual_cents': a.valuationManualCents,
        'valuation_started_at': a.valuationStartedAt?.millisecondsSinceEpoch,
      };
}
