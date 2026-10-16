/// Entry use cases. See PRD STORY-1.1, 04-8.1.
library;

import 'package:plain/core/constants/app_constants.dart';
import 'package:plain/core/id/uuid_v7.dart';
import 'package:plain/core/money/expression_evaluator.dart';
import 'package:plain/core/money/money.dart';
import 'package:plain/core/result/result.dart';
import 'package:plain/core/time/clock.dart';
import 'package:plain/domain/entities/automation_rule.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/entities/ledger_entry.dart';
import 'package:plain/domain/repositories/repositories.dart';
import 'package:plain/domain/services/rule_applier.dart';

class CreateEntryInput {
  const CreateEntryInput({
    required this.amountExpression, required this.type, required this.categoryId,
    this.accountId, this.toAccountId, this.note, this.occurredAt,
    this.source = EntrySource.manual, required this.bookId, required this.deviceId,
    this.reimburseStatus = ReimburseStatus.none,
    this.exchangeRate, this.originalCurrency,
    this.memberId,
  });

  final String amountExpression;
  final EntryType type;
  final String categoryId;
  final String? accountId;
  final String? toAccountId;
  final String? note;
  final DateTime? occurredAt;
  final EntrySource source;
  final String bookId;
  final String deviceId;

  /// STORY-1.8：报销状态。
  final ReimburseStatus reimburseStatus;

  /// STORY-8.2：归属成员；null = 由用例回落到本机成员。
  final String? memberId;

  /// STORY-9.3：账户币种不是本位币时才有值。
  ///
  /// 此时 [amountExpression] 是**原币**金额，[exchangeRate] 是折成本位币的
  /// 锁定汇率；用例据此写入 `originalAmountCents`，并把 `amount` 折算成本位币
  /// （所有统计口径都用 `amount`，因此不受多币种影响）。
  final double? exchangeRate;
  final String? originalCurrency;
}

class CreateEntryUseCase {
  CreateEntryUseCase({
    required LedgerRepository repository, required Clock clock, required UuidV7 idGen,
    ExpressionEvaluator evaluator = const ExpressionEvaluator(),
    this.ruleRepository,
    this.memberRepository,
  })  : _repository = repository, _clock = clock, _idGen = idGen, _evaluator = evaluator;

  final LedgerRepository _repository;
  final Clock _clock;
  final UuidV7 _idGen;
  final ExpressionEvaluator _evaluator;

  /// STORY-6.1：可选规则仓储；非空时在写入前套用 post 阶段规则。
  final AutomationRuleRepository? ruleRepository;

  /// STORY-8.2：可选成员仓储。非空时把新账单归属到本机成员（「我」）。
  final MemberRepository? memberRepository;

  Future<Result<LedgerEntry>> call(CreateEntryInput input) async {
    final eval = _evaluator.eval(input.amountExpression);
    if (eval.money.isZero) return err<LedgerEntry>(const ValidationFailure('entry.amount_zero', 'zero'));
    if (!eval.money.withinProductLimit) return err<LedgerEntry>(const ValidationFailure('entry.amount_over_limit', 'over'));
    if (input.type == EntryType.unknown || !input.type.enabledInV1) {
      return err<LedgerEntry>(const ValidationFailure('entry.type_invalid', 'invalid'));
    }
    if (input.type == EntryType.transfer && input.toAccountId == null) {
      return err<LedgerEntry>(const ValidationFailure('entry.transfer_missing_target', 'missing'));
    }
    // STORY-1.7 AC1：转出与转入不可相同
    if (input.type == EntryType.transfer &&
        input.accountId != null &&
        input.accountId == input.toAccountId) {
      return err<LedgerEntry>(
          const ValidationFailure('entry.transfer_same_account', 'same'));
    }
    // STORY-1.7：借出/借入需往来对象（暂用备注承载）
    if ((input.type == EntryType.borrowOut || input.type == EntryType.borrowIn) &&
        (input.note == null || input.note!.trim().isEmpty)) {
      return err<LedgerEntry>(
          const ValidationFailure('entry.borrow_counterparty_required', 'note'));
    }
    final now = _clock.now();
    final occurred = input.occurredAt?.toUtc() ?? now;

    // STORY-9.3：原币记账时把输入金额视为原币，折算出本位币金额。
    // `amount` 始终是本位币（统计口径不变），原币金额另存一列。
    final typed = Money(eval.money.cents.abs());
    var amount = typed;
    int? originalAmountCents;
    final foreignRate = input.exchangeRate;
    final foreignCurrency = input.originalCurrency;
    if (foreignRate != null &&
        foreignCurrency != null &&
        foreignCurrency != MoneyRules.defaultCurrency) {
      if (foreignRate <= 0) {
        return err<LedgerEntry>(
            const ValidationFailure('entry.fx_rate_invalid', 'rate'));
      }
      originalAmountCents = typed.cents;
      amount = Money((typed.cents * foreignRate).round());
      if (amount.isZero) {
        // 折算后不足 1 分：金额列有 CHECK(>0)，明确拦下来而不是让 DB 抛错
        return err<LedgerEntry>(
            const ValidationFailure('entry.amount_rounds_to_zero', 'zero'));
      }
    }

    var entry = LedgerEntry(
      id: _idGen.generate(at: occurred), bookId: input.bookId, type: input.type,
      amount: amount, currency: MoneyRules.defaultCurrency,
      originalAmountCents: originalAmountCents,
      exchangeRate: originalAmountCents == null ? null : foreignRate,
      categoryId: input.categoryId, accountId: input.accountId, toAccountId: input.toAccountId,
      occurredAt: occurred, note: input.note, source: input.source,
      reimburseStatus: input.reimburseStatus,
      memberId: input.memberId ?? await _currentMemberId(input.bookId),
      createdAt: now, updatedAt: now, revision: 1, deviceId: input.deviceId, baseRevision: 0,
    );

    // STORY-6.1：套用自动化规则（post，手动记账作用域）
    if (ruleRepository != null) {
      entry = await applyAutomationRules(
        ruleRepository: ruleRepository!,
        entry: entry,
        scope: RuleScope.manual,
      );
    }

    return _repository.create(entry);
  }

  /// STORY-8.2：默认归属到本机成员（「我」）。拿不到就留 null（不猜）。
  Future<String?> _currentMemberId(String bookId) async {
    final repo = memberRepository;
    if (repo == null) return null;
    final me = await repo.getMe(bookId);
    return me.successOrNull?.id;
  }
}

class UpdateEntryUseCase {
  UpdateEntryUseCase({required LedgerRepository repository, required Clock clock})
      : _repository = repository, _clock = clock;

  final LedgerRepository _repository;
  final Clock _clock;

  Future<Result<LedgerEntry>> call({
    required LedgerEntry existing, Money? amount, String? categoryId,
    String? accountId, String? toAccountId, String? note,
    DateTime? occurredAt, EntryType? type,
    int? originalAmountCents, double? exchangeRate,
    bool clearNote = false, bool clearCategoryId = false, bool clearAccount = false,
  }) async {
    if (amount != null && !amount.withinProductLimit) {
      return err<LedgerEntry>(const ValidationFailure('entry.amount_over_limit', 'over'));
    }
    return _repository.update(existing.copyWith(
      amount: amount, categoryId: categoryId, accountId: accountId,
      toAccountId: toAccountId, note: note, occurredAt: occurredAt, type: type,
      originalAmountCents: originalAmountCents, exchangeRate: exchangeRate,
      updatedAt: _clock.now(), revision: existing.revision + 1,
      baseRevision: existing.revision, clearNote: clearNote, clearCategoryId: clearCategoryId,
      clearAccount: clearAccount,
    ));
  }
}

class DeleteEntryUseCase {
  DeleteEntryUseCase({required LedgerRepository repository}) : _repository = repository;
  final LedgerRepository _repository;
  Future<Result<void>> call(String id) => _repository.softDelete(id);
}

class RestoreEntryUseCase {
  RestoreEntryUseCase({required LedgerRepository repository}) : _repository = repository;
  final LedgerRepository _repository;
  Future<Result<LedgerEntry>> call(String id) => _repository.restore(id);
}

class PurgeTrashUseCase {
  PurgeTrashUseCase({required LedgerRepository repository, required Clock clock})
      : _repository = repository, _clock = clock;
  final LedgerRepository _repository;
  final Clock _clock;

  /// Physically delete entries soft-deleted more than [TrashRules.trashTtl] ago.
  Future<Result<int>> call() {
    final cutoff = _clock.now().subtract(TrashRules.trashTtl);
    return _repository.purgeExpired(before: cutoff);
  }
}

class ListDeletedEntriesUseCase {
  ListDeletedEntriesUseCase({required LedgerRepository repository}) : _repository = repository;
  final LedgerRepository _repository;
  Future<Result<List<LedgerEntry>>> call({String? bookId, int limit = 100}) =>
      _repository.listDeleted(bookId: bookId, limit: limit);
}

class EntryDraft {
  const EntryDraft({
    required this.amountExpression, this.categoryId, this.accountId,
    this.toAccountId, this.note, this.type = EntryType.expense, required this.savedAt,
  });

  final String amountExpression;
  final String? categoryId;
  final String? accountId;
  final String? toAccountId;
  final String? note;
  final EntryType type;
  final DateTime savedAt;

  bool isExpired(Clock clock) => clock.now().difference(savedAt) > DraftRules.draftTtl;

  Map<String, Object?> toJson() => {
    'amountExpression': amountExpression, 'categoryId': categoryId,
    'accountId': accountId, 'toAccountId': toAccountId, 'note': note,
    'type': type.wire, 'savedAt': savedAt.millisecondsSinceEpoch,
  };

  static EntryDraft? fromJson(Map<String, Object?>? json) {
    if (json == null) return null;
    final savedAtMs = json['savedAt'];
    if (savedAtMs is! int) return null;
    return EntryDraft(
      amountExpression: json['amountExpression'] as String? ?? '',
      categoryId: json['categoryId'] as String?, accountId: json['accountId'] as String?,
      toAccountId: json['toAccountId'] as String?, note: json['note'] as String?,
      type: EntryType.fromWire(json['type'] as String?),
      savedAt: DateTime.fromMillisecondsSinceEpoch(savedAtMs, isUtc: true),
    );
  }
}
