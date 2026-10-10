/// Recurring rule use cases: create/update and due-entry generation. See PRD F6.1.
library;

import 'package:plain/core/id/uuid_v7.dart';
import 'package:plain/core/money/money.dart';
import 'package:plain/core/result/result.dart';
import 'package:plain/core/time/clock.dart';
import 'package:plain/domain/entities/automation_rule.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/entities/ledger_entry.dart';
import 'package:plain/domain/entities/recurring_rule.dart';
import 'package:plain/domain/repositories/repositories.dart';
import 'package:plain/domain/services/recurring_scheduler.dart';
import 'package:plain/domain/services/rule_applier.dart';

class CreateRecurringRuleInput {
  const CreateRecurringRuleInput({
    required this.bookId, required this.deviceId,
    this.name, required this.frequency, this.intervalN = 1,
    this.anchorDay, this.weekday,
    this.skipStrategy = RecurringSkipStrategy.clamp,
    this.autoConfirm = true,
    this.endType = RecurringEndType.never,
    this.endAt, this.endCount,
    required this.entryType, required this.amountCents,
    this.categoryId, this.accountId, this.toAccountId, this.note,
    DateTime? firstRunAt,
  }) : _firstRunAt = firstRunAt;

  final String bookId;
  final String deviceId;
  final String? name;
  final RecurringFrequency frequency;
  final int intervalN;
  final int? anchorDay;
  final int? weekday;
  final RecurringSkipStrategy skipStrategy;
  final bool autoConfirm;
  final RecurringEndType endType;
  final DateTime? endAt;
  final int? endCount;
  final EntryType entryType;
  final int amountCents;
  final String? categoryId;
  final String? accountId;
  final String? toAccountId;
  final String? note;
  final DateTime? _firstRunAt;
}

class CreateRecurringRuleUseCase {
  CreateRecurringRuleUseCase({
    required RecurringRepository repository, required Clock clock,
    required UuidV7 idGen, RecurringScheduler scheduler = const RecurringScheduler(),
  })  : _repository = repository, _clock = clock, _idGen = idGen, _scheduler = scheduler;

  final RecurringRepository _repository;
  final Clock _clock;
  final UuidV7 _idGen;
  final RecurringScheduler _scheduler;

  Future<Result<RecurringRule>> call(CreateRecurringRuleInput input) async {
    final amount = Money(input.amountCents.abs());
    if (amount.isZero || !amount.withinProductLimit) {
      return err<RecurringRule>(const ValidationFailure('recurring.amount_invalid', 'invalid'));
    }
    if (input.entryType == EntryType.unknown || !input.entryType.enabledInV1) {
      return err<RecurringRule>(const ValidationFailure('recurring.type_invalid', 'invalid'));
    }
    if (input.frequency == RecurringFrequency.unknown) {
      return err<RecurringRule>(const ValidationFailure('recurring.frequency_invalid', 'invalid'));
    }
    if (input.endType == RecurringEndType.count && (input.endCount == null || input.endCount! <= 0)) {
      return err<RecurringRule>(const ValidationFailure('recurring.end_count_invalid', 'invalid'));
    }
    final now = _clock.now();
    final first = input._firstRunAt ??
        _scheduler.initialNextRun(
          frequency: input.frequency, now: now,
          intervalN: input.intervalN, anchorDay: input.anchorDay,
          weekday: input.weekday, skipStrategy: input.skipStrategy);
    final rule = RecurringRule(
      id: _idGen.generate(at: first), bookId: input.bookId, name: input.name,
      frequency: input.frequency, intervalN: input.intervalN,
      anchorDay: input.anchorDay, weekday: input.weekday,
      skipStrategy: input.skipStrategy, autoConfirm: input.autoConfirm,
      endType: input.endType, endAt: input.endAt, endCount: input.endCount,
      generatedCount: 0, nextRunAt: first.toUtc(),
      entryType: input.entryType, amount: amount,
      categoryId: input.categoryId, accountId: input.accountId,
      toAccountId: input.toAccountId, note: input.note,
      createdAt: now, updatedAt: now, deviceId: input.deviceId,
    );
    return _repository.create(rule);
  }
}

class GenerateDueRecurringUseCase {
  GenerateDueRecurringUseCase({
    required RecurringRepository recurringRepository,
    required LedgerRepository ledgerRepository,
    required Clock clock, required UuidV7 idGen,
    RecurringScheduler scheduler = const RecurringScheduler(),
    this.ruleRepository,
  })  : _recurring = recurringRepository, _ledger = ledgerRepository,
        _clock = clock, _idGen = idGen, _scheduler = scheduler;

  final RecurringRepository _recurring;
  final LedgerRepository _ledger;
  final Clock _clock;
  final UuidV7 _idGen;
  final AutomationRuleRepository? ruleRepository;
  final RecurringScheduler _scheduler;

  /// Generate all due entries. One batch id per rule run so it can be undone as a unit.
  Future<Result<GenerateResult>> call() async {
    final now = _clock.now();
    final dueRes = await _recurring.listDue(now: now);
    if (dueRes.isFailure) return err(dueRes.failureOrNull!);
    final rules = dueRes.requireValue;
    final created = <LedgerEntry>[];
    final updatedRules = <RecurringRule>[];
    final needConfirm = <RecurringRule>[];

    for (final rule in rules) {
      if (rule.isFinished) continue;
      // auto_confirm=false waits for user confirm (in-app or notification action).
      // nextRunAt is not advanced until confirmed or skipped.
      if (!rule.autoConfirm) {
        needConfirm.add(rule);
        continue;
      }
      final batchId = _idGen.generate();
      final occurred = rule.nextRunAt;
      var entry = LedgerEntry(
        id: _idGen.generate(at: occurred), bookId: rule.bookId,
        type: rule.entryType, amount: rule.amount, currency: 'CNY',
        categoryId: rule.categoryId, accountId: rule.accountId,
        toAccountId: rule.toAccountId, occurredAt: occurred,
        note: rule.note, source: EntrySource.recurring, batchId: batchId,
        createdAt: now, updatedAt: now, deviceId: rule.deviceId,
      );
      if (ruleRepository != null) {
        entry = await applyAutomationRules(
          ruleRepository: ruleRepository!,
          entry: entry,
          scope: RuleScope.recurring,
        );
      }
      final createdRes = await _ledger.create(entry);
      if (createdRes.isFailure) return err(createdRes.failureOrNull!);
      created.add(createdRes.requireValue);

      final next = _scheduler.nextAfter(rule, rule.nextRunAt);
      final count = rule.generatedCount + 1;
      final finished = next == null ||
          (rule.endType == RecurringEndType.count && rule.endCount != null && count >= rule.endCount!);
      final updated = rule.copyWith(
        generatedCount: count,
        nextRunAt: next ?? rule.nextRunAt,
        lastBatchId: batchId,
        isEnabled: !finished,
        updatedAt: now,
        revision: rule.revision + 1,
        baseRevision: rule.revision,
      );
      final updRes = await _recurring.update(updated);
      if (updRes.isFailure) return err(updRes.failureOrNull!);
      updatedRules.add(updRes.requireValue);
    }
    return ok(GenerateResult(
      created: created, updatedRules: updatedRules, needConfirm: needConfirm,
    ));
  }
}

class GenerateResult {
  const GenerateResult({
    required this.created,
    required this.updatedRules,
    this.needConfirm = const [],
  });
  final List<LedgerEntry> created;
  final List<RecurringRule> updatedRules;
  /// Rules due but autoConfirm=false — wait for user confirm/skip.
  final List<RecurringRule> needConfirm;
}

class UndoRecurringBatchUseCase {
  UndoRecurringBatchUseCase({
    required RecurringRepository repository, required Clock clock,
  }) : _repository = repository, _clock = clock;

  final RecurringRepository _repository;
  final Clock _clock;

  Future<Result<int>> call(String batchId) {
    return _repository.undoBatch(batchId: batchId, deletedAt: _clock.now());
  }
}


/// Confirm or skip a due rule that has autoConfirm=false.
class ConfirmRecurringRuleUseCase {
  ConfirmRecurringRuleUseCase({
    required RecurringRepository repository,
    required LedgerRepository ledgerRepository,
    required Clock clock,
    required UuidV7 idGen,
    RecurringScheduler scheduler = const RecurringScheduler(),
  })  : _repository = repository,
        _ledger = ledgerRepository,
        _clock = clock,
        _idGen = idGen,
        _scheduler = scheduler;

  final RecurringRepository _repository;
  final LedgerRepository _ledger;
  final Clock _clock;
  final UuidV7 _idGen;
  final RecurringScheduler _scheduler;

  /// [skip]=true advances the schedule without creating a ledger entry.
  Future<Result<LedgerEntry?>> call(RecurringRule rule, {bool skip = false}) async {
    if (rule.isFinished) {
      return err<LedgerEntry?>(const ValidationFailure('recurring.finished', 'done'));
    }
    final now = _clock.now();
    LedgerEntry? entry;
    String? batchId;
    if (!skip) {
      batchId = _idGen.generate();
      final occurred = rule.nextRunAt;
      entry = LedgerEntry(
        id: _idGen.generate(at: occurred), bookId: rule.bookId,
        type: rule.entryType, amount: rule.amount, currency: 'CNY',
        categoryId: rule.categoryId, accountId: rule.accountId,
        toAccountId: rule.toAccountId, occurredAt: occurred,
        note: rule.note, source: EntrySource.recurring, batchId: batchId,
        createdAt: now, updatedAt: now, deviceId: rule.deviceId,
      );
      final createdRes = await _ledger.create(entry);
      if (createdRes.isFailure) return err(createdRes.failureOrNull!);
      entry = createdRes.requireValue;
    }

    final next = _scheduler.nextAfter(rule, rule.nextRunAt);
    final count = rule.generatedCount + (skip ? 0 : 1);
    final finished = next == null ||
        (rule.endType == RecurringEndType.count && rule.endCount != null && count >= rule.endCount!);
    final updated = rule.copyWith(
      generatedCount: count,
      nextRunAt: next ?? rule.nextRunAt,
      lastBatchId: batchId ?? rule.lastBatchId,
      isEnabled: !finished,
      updatedAt: now,
      revision: rule.revision + 1,
      baseRevision: rule.revision,
    );
    final updRes = await _repository.update(updated);
    if (updRes.isFailure) return err(updRes.failureOrNull!);
    return ok(entry);
  }
}
