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
}

class CreateEntryUseCase {
  CreateEntryUseCase({
    required LedgerRepository repository, required Clock clock, required UuidV7 idGen,
    ExpressionEvaluator evaluator = const ExpressionEvaluator(),
    this.ruleRepository,
  })  : _repository = repository, _clock = clock, _idGen = idGen, _evaluator = evaluator;

  final LedgerRepository _repository;
  final Clock _clock;
  final UuidV7 _idGen;
  final ExpressionEvaluator _evaluator;

  /// STORY-6.1：可选规则仓储；非空时在写入前套用 post 阶段规则。
  final AutomationRuleRepository? ruleRepository;

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
    var entry = LedgerEntry(
      id: _idGen.generate(at: occurred), bookId: input.bookId, type: input.type,
      amount: Money(eval.money.cents.abs()), currency: MoneyRules.defaultCurrency,
      categoryId: input.categoryId, accountId: input.accountId, toAccountId: input.toAccountId,
      occurredAt: occurred, note: input.note, source: input.source,
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
    bool clearNote = false, bool clearCategoryId = false,
  }) async {
    if (amount != null && !amount.withinProductLimit) {
      return err<LedgerEntry>(const ValidationFailure('entry.amount_over_limit', 'over'));
    }
    return _repository.update(existing.copyWith(
      amount: amount, categoryId: categoryId, accountId: accountId,
      toAccountId: toAccountId, note: note, occurredAt: occurredAt, type: type,
      updatedAt: _clock.now(), revision: existing.revision + 1,
      baseRevision: existing.revision, clearNote: clearNote, clearCategoryId: clearCategoryId,
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
