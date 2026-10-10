/// 信用卡账单周期（STORY-2.2）。
library;

import 'package:plain/core/constants/app_constants.dart';
import 'package:plain/core/id/uuid_v7.dart';
import 'package:plain/core/money/money.dart';
import 'package:plain/core/result/result.dart';
import 'package:plain/core/time/clock.dart';
import 'package:plain/domain/entities/category.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/entities/ledger_entry.dart';
import 'package:plain/domain/repositories/repositories.dart';

class CreditBillPeriod {
  const CreditBillPeriod({
    required this.billDate,
    required this.dueDate,
    required this.interestFreeDays,
  });

  /// 出账日（账单日）。
  final DateTime billDate;

  /// 到期还款日。
  final DateTime dueDate;

  /// 从消费日到还款日的免息天数（由调用方按消费日算时填）。
  final int interestFreeDays;
}

class CreditCardService {
  /// 某笔消费归属的账单日：消费日之后的下一个账单日。
  /// 账单日为 5 日，6 月 8 日消费 → 7 月 5 日账单（AC3）。
  static DateTime billDateForPurchase({
    required DateTime purchaseAt,
    required int billDay,
  }) {
    final d = billDay.clamp(CreditCardRules.minDay, CreditCardRules.maxDay);
    final y = purchaseAt.year;
    final m = purchaseAt.month;
    var bill = DateTime(y, m, d);
    if (!purchaseAt.isBefore(bill)) {
      bill = DateTime(y, m + 1, d);
    }
    return bill;
  }

  /// 还款日：账单月的 [dueDay]（若未配置则默认账单日后 20 天）。
  static DateTime dueDateForBill({
    required DateTime billDate,
    int? dueDay,
  }) {
    if (dueDay != null) {
      return DateTime(billDate.year, billDate.month, dueDay.clamp(CreditCardRules.minDay, CreditCardRules.maxDay));
    }
    return billDate.add(Duration(days: CreditCardRules.defaultGraceDays));
  }

  /// 免息期：消费日 → 到期还款日。
  static int interestFreeDays({
    required DateTime purchaseAt,
    required DateTime dueDate,
  }) {
    final d = dueDate.difference(purchaseAt).inDays;
    return d > 0 ? d : 0;
  }

  /// 本期应还 = 上期未还 + 本期新增 − 本期已还（AC4，只读汇总）。
  static int amountDue({
    required int previousUnpaidCents,
    required int currentNewCents,
    required int currentPaidCents,
  }) {
    return previousUnpaidCents + currentNewCents - currentPaidCents;
  }

  /// 可用额度派生（AC2）。
  static int availableLimit(Account account) => account.creditAvailableCents;

  /// 按账单聚合的欠款：信用卡余额为负即欠款（消费使余额下降）。
  static int aggregatedDebtCents({required int balanceCents}) {
    return balanceCents < 0 ? -balanceCents : 0;
  }

  /// 聚合 vs 存储差额（AC8）：正 = 聚合大于存储。
  static int aggregateDiff({
    required int storedDebtCents,
    required int balanceCents,
  }) {
    return aggregatedDebtCents(balanceCents: balanceCents) - storedDebtCents;
  }
}

/// 信用卡对账：直接写欠款余额（存储值）+ 生成对账调整凭证（AC7）。
class CreditReconcileResult {
  const CreditReconcileResult({
    required this.newDebtCents,
    required this.adjustmentCents,
  });

  final int newDebtCents;
  final int adjustmentCents;
}

class CreditReconcileService {
  CreditReconcileService({
    required AccountRepository accountRepository,
    required LedgerRepository ledgerRepository,
    required Clock clock,
    required UuidV7 idGen,
  })  : _accounts = accountRepository,
        _ledger = ledgerRepository,
        _clock = clock,
        _idGen = idGen;

  final AccountRepository _accounts;
  final LedgerRepository _ledger;
  final Clock _clock;
  final UuidV7 _idGen;

  /// 将欠款修正为 [actualDebtCents]，并生成对账调整账单（不计入收支 G-2）。
  Future<Result<CreditReconcileResult>> reconcile({
    required Account account,
    required int actualDebtCents,
    required String bookId,
    required String deviceId,
  }) async {
    final stored = account.creditDebtCents;
    final diff = actualDebtCents - stored;
    final now = _clock.now();

    // 1) 直接写欠款余额（存储值）
    final updated = account.copyWith(
      creditDebtCents: actualDebtCents,
      updatedAt: now,
      revision: account.revision + 1,
      baseRevision: account.revision,
    );
    final u = await _accounts.update(updated);
    final f = u.failureOrNull;
    if (f != null) return err(f);

    // 2) 差额不为 0 时生成对账调整凭证
    if (diff != 0) {
      final isExpense = diff > 0; // 欠款变多 = 一笔支出侧调整
      final entry = LedgerEntry(
        id: _idGen.generate(at: now),
        bookId: bookId,
        type: isExpense ? EntryType.expense : EntryType.income,
        amount: Money(diff.abs()),
        currency: account.currency,
        accountId: account.id,
        occurredAt: now,
        note: '对账调整',
        source: EntrySource.reconcile,
        createdAt: now,
        updatedAt: now,
        deviceId: deviceId,
      );
      final c = await _ledger.create(entry);
      final cf = c.failureOrNull;
      if (cf != null) return err(cf);
    }

    return ok(CreditReconcileResult(
      newDebtCents: actualDebtCents,
      adjustmentCents: diff,
    ));
  }
}
