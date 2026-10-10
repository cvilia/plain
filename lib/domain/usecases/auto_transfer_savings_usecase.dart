/// STORY-7.1 AC6 / 7.3：记账月首日自动划拨到储蓄目标。
/// 生成内部转账（不计入收支，G-2）。
library;

import 'package:plain/core/constants/app_constants.dart';
import 'package:plain/core/id/uuid_v7.dart';
import 'package:plain/core/money/money.dart';
import 'package:plain/core/result/result.dart';
import 'package:plain/core/time/clock.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/entities/ledger_entry.dart';
import 'package:plain/domain/entities/savings_goal.dart';
import 'package:plain/domain/repositories/repositories.dart';

class AutoTransferSavingsUseCase {
  AutoTransferSavingsUseCase({
    required SavingsGoalRepository goalRepository,
    required LedgerRepository ledgerRepository,
    required Clock clock,
    required UuidV7 idGen,
  })  : _goals = goalRepository,
        _ledger = ledgerRepository,
        _clock = clock,
        _idGen = idGen;

  final SavingsGoalRepository _goals;
  final LedgerRepository _ledger;
  final Clock _clock;
  final UuidV7 _idGen;

  /// 对开启自动划拨的目标生成一笔内部转账，并累加 saved_cents。
  Future<Result<int>> call({required String bookId, String? fromAccountId}) async {
    final now = _clock.now();
    final list = await _goals.listByBook(bookId);
    final goals = list.successOrNull ?? const <SavingsGoal>[];
    var n = 0;
    for (final g in goals) {
      if (!g.autoTransfer || g.isAchieved || g.isDeleted) continue;
      final amount = g.monthlyRequiredCentsAt(now);
      if (amount <= 0) continue;
      final entry = LedgerEntry(
        id: _idGen.generate(at: now),
        bookId: bookId,
        // 内部转账：不计入收支（G-2）
        type: EntryType.transfer,
        amount: Money(amount),
        currency: MoneyRules.defaultCurrency,
        accountId: fromAccountId ?? g.accountId,
        occurredAt: now,
        note: '自动划拨 · ${g.name}',
        source: EntrySource.recurring,
        createdAt: now,
        updatedAt: now,
        deviceId: g.deviceId,
      );
      final created = await _ledger.create(entry);
      if (created.isFailure) continue;
      await _goals.deposit(goalId: g.id, amountCents: amount);
      n++;
    }
    return ok(n);
  }
}
