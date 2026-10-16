/// STORY-10.2 贷款用例。
library;

import 'package:plain/core/id/uuid_v7.dart';
import 'package:plain/core/money/money.dart';
import 'package:plain/core/result/result.dart';
import 'package:plain/core/time/clock.dart';
import 'package:plain/domain/entities/category.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/entities/recurring_rule.dart';
import 'package:plain/domain/repositories/repositories.dart';
import 'package:plain/domain/services/loan_amortization_service.dart';

/// 为贷款账户建立「每期还款」周期规则（STORY-10.2 AC4）。
///
/// 走**统一周期引擎**（STORY-7.3），`kind = loanRepayment`：
/// - 规则只承载调度与账户指向：`account_id` = 还款来源账户，`to_account_id` = 贷款账户；
/// - 每期的「利息 + 本金」拆分**在生成时按摊销表算**，所以规则上的 `amount_cents`
///   只是首期月供（显示用），不是真正入账金额；
/// - `auto_confirm = false`：生成的是**待确认**账单（PRD：「用户确认后入账」）。
class SetLoanRepaymentScheduleUseCase {
  SetLoanRepaymentScheduleUseCase({
    required RecurringRepository recurringRepository,
    required Clock clock,
    required UuidV7 idGen,
    LoanAmortizationService amortization = const LoanAmortizationService(),
  })  : _recurring = recurringRepository,
        _clock = clock,
        _idGen = idGen,
        _amortization = amortization;

  final RecurringRepository _recurring;
  final Clock _clock;
  final UuidV7 _idGen;
  final LoanAmortizationService _amortization;

  /// [interestCategoryId]：利息那笔账单的分类（真实资金成本，计入收支）。
  /// [bookId]：账户表不带 `book_id`，故由调用方传入当前账本。
  Future<Result<RecurringRule>> call({
    required Account loanAccount,
    required String bookId,
    required String repayAccountId,
    required String interestCategoryId,
    bool autoConfirm = false,
    bool replaceExisting = true,
  }) async {
    final terms = LoanTerms.ofAccount(loanAccount);
    if (terms == null) {
      return err<RecurringRule>(
          const ValidationFailure('loan.terms_incomplete', 'missing terms'));
    }
    if (repayAccountId == loanAccount.id) {
      return err<RecurringRule>(
          const ValidationFailure('loan.repay_account_same', 'same'));
    }

    final now = _clock.now();
    final schedule = _amortization.schedule(terms);
    if (schedule.isEmpty) {
      return err<RecurringRule>(
          const ValidationFailure('loan.schedule_empty', 'empty'));
    }

    // 参数变更后重建：停用该贷款既有的还款规则（保留历史，不删除）
    if (replaceExisting) {
      final existing = await _recurring.listByBook(bookId);
      for (final r in existing.successOrNull ?? const <RecurringRule>[]) {
        if (r.kind != RecurringKind.loanRepayment ||
            r.toAccountId != loanAccount.id) {
          continue;
        }
        if (!r.isEnabled) continue;
        await _recurring.update(r.copyWith(
          isEnabled: false,
          updatedAt: now,
          revision: r.revision + 1,
          baseRevision: r.revision,
        ));
      }
    }

    final first = terms.firstPaymentAt;
    final rule = RecurringRule(
      id: _idGen.generate(at: now),
      bookId: bookId,
      name: '还款「${loanAccount.name}」',
      frequency: RecurringFrequency.monthly,
      anchorDay: first.day,
      // 短月顺延到月末（31 号还款日 → 2 月 28 日），G-4
      skipStrategy: RecurringSkipStrategy.clamp,
      autoConfirm: autoConfirm,
      endType: RecurringEndType.count,
      endCount: terms.termMonths,
      nextRunAt: first,
      entryType: EntryType.transfer,
      // 显示用：首期月供
      amount: Money(schedule.periods.first.paymentCents),
      categoryId: interestCategoryId,
      accountId: repayAccountId,
      toAccountId: loanAccount.id,
      note: '每期还款',
      kind: RecurringKind.loanRepayment,
      createdAt: now,
      updatedAt: now,
      deviceId: loanAccount.deviceId,
    );
    return _recurring.create(rule);
  }
}
