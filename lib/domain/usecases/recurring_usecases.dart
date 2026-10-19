/// Recurring rule use cases: create/update and due-entry generation. See PRD F6.1.
library;

import 'package:plain/app/l10n/app_strings.dart';
import 'package:plain/core/constants/app_constants.dart';
import 'package:plain/core/id/uuid_v7.dart';
import 'package:plain/core/money/money.dart';
import 'package:plain/core/result/result.dart';
import 'package:plain/core/time/clock.dart';
import 'package:plain/domain/entities/automation_rule.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/entities/ledger_entry.dart';
import 'package:plain/domain/entities/recurring_rule.dart';
import 'package:plain/domain/repositories/repositories.dart';
import 'package:plain/domain/services/loan_amortization_service.dart';
import 'package:plain/domain/services/recurring_scheduler.dart';
import 'package:plain/domain/services/rule_applier.dart';
import 'package:plain/domain/usecases/goal_usecases.dart';

/// 按周期规则构造本次要入账的账单。
///
/// 普通规则产出 1 笔；`kind = loanRepayment` 产出 **2 笔**（STORY-10.2 AC4/AC5）：
/// - **利息**：`expense`，计入收支与预算（真实资金成本）；
/// - **本金**：`transfer`（还款账户 → 贷款账户），**不计入收支**，只减负债。
///
/// 两笔共用同一个 [batchId]，因此删除/撤销作用于整个还款批次。
Future<Result<List<LedgerEntry>>> buildEntriesForRule({
  required AppStrings s,
  required RecurringRule rule,
  required String batchId,
  required DateTime now,
  required UuidV7 idGen,
  AccountRepository? accountRepository,
  AutomationRuleRepository? ruleRepository,
  RuleScope scope = RuleScope.recurring,
  LoanAmortizationService amortization = const LoanAmortizationService(),
}) async {
  final occurred = rule.nextRunAt;

  Future<LedgerEntry> withRules(LedgerEntry e) async {
    if (ruleRepository == null) return e;
    return applyAutomationRules(
        s: s, ruleRepository: ruleRepository, entry: e, scope: scope);
  }

  if (rule.kind == RecurringKind.loanRepayment) {
    final split = await _loanSplit(
      rule: rule,
      accounts: accountRepository,
      amortization: amortization,
    );
    if (split != null) {
      final out = <LedgerEntry>[];
      if (split.interestCents > 0) {
        out.add(await withRules(LedgerEntry(
          id: idGen.generate(at: occurred),
          bookId: rule.bookId,
          type: EntryType.expense,
          amount: Money(split.interestCents),
          currency: MoneyRules.defaultCurrency,
          categoryId: rule.categoryId,
          accountId: rule.accountId,
          occurredAt: occurred,
          note: '${rule.note ?? '还贷'}·利息',
          source: EntrySource.recurring,
          batchId: batchId,
          createdAt: now,
          updatedAt: now,
          deviceId: rule.deviceId,
        )));
      }
      if (split.principalCents > 0) {
        out.add(await withRules(LedgerEntry(
          id: idGen.generate(at: occurred),
          bookId: rule.bookId,
          type: EntryType.transfer,
          amount: Money(split.principalCents),
          currency: MoneyRules.defaultCurrency,
          accountId: rule.accountId,
          toAccountId: rule.toAccountId,
          occurredAt: occurred,
          note: '${rule.note ?? '还贷'}·本金',
          source: EntrySource.recurring,
          batchId: batchId,
          createdAt: now,
          updatedAt: now,
          deviceId: rule.deviceId,
        )));
      }
      if (out.isNotEmpty) return ok(out);
    }
    // 贷款参数读不到（账户被删/未配置）时退化为单笔，用规则自身的类型与金额，
    // 不让整批生成失败。规则是校验过参数才建的，这条路径属异常兜底。
  }

  final single = await withRules(LedgerEntry(
    id: idGen.generate(at: occurred),
    bookId: rule.bookId,
    type: rule.entryType,
    amount: rule.amount,
    currency: MoneyRules.defaultCurrency,
    categoryId: rule.categoryId,
    accountId: rule.accountId,
    toAccountId: rule.toAccountId,
    occurredAt: occurred,
    note: rule.note,
    source: EntrySource.recurring,
    batchId: batchId,
    createdAt: now,
    updatedAt: now,
    deviceId: rule.deviceId,
  ));
  return ok([single]);
}

/// 取该期应还的「利息 / 本金」拆分。期号 = 已生成期数 + 1。
Future<({int interestCents, int principalCents})?> _loanSplit({
  required RecurringRule rule,
  required AccountRepository? accounts,
  required LoanAmortizationService amortization,
}) async {
  final loanAccountId = rule.toAccountId;
  if (accounts == null || loanAccountId == null) return null;
  final found = await accounts.getById(loanAccountId);
  final loan = found.successOrNull;
  if (loan == null) return null;
  final terms = LoanTerms.ofAccount(loan);
  if (terms == null) return null;

  final index = rule.generatedCount + 1;
  final schedule = amortization.schedule(terms);
  if (index < 1 || index > schedule.periods.length) return null;
  final period = schedule.periods[index - 1];
  return (
    interestCents: period.interestCents,
    principalCents: period.principalCents,
  );
}

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
    this.savingsGoalRepository,
    this.accountRepository,
  })  : _recurring = recurringRepository, _ledger = ledgerRepository,
        _clock = clock, _idGen = idGen, _scheduler = scheduler;

  final RecurringRepository _recurring;
  final LedgerRepository _ledger;
  final Clock _clock;
  final UuidV7 _idGen;
  final AutomationRuleRepository? ruleRepository;

  /// STORY-7.3：`kind = savingsTransfer` 的规则生成后要把金额记到目标上。
  final SavingsGoalRepository? savingsGoalRepository;

  /// STORY-10.2：`kind = loanRepayment` 的规则要读贷款参数做本息拆分。
  final AccountRepository? accountRepository;

  final RecurringScheduler _scheduler;

  /// Generate all due entries. One batch id per rule run so it can be undone as a unit.
  Future<Result<GenerateResult>> call({required AppStrings s}) async {
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
      final built = await buildEntriesForRule(
        s: s,
        rule: rule,
        batchId: batchId,
        now: now,
        idGen: _idGen,
        accountRepository: accountRepository,
        ruleRepository: ruleRepository,
        scope: RuleScope.recurring,
      );
      if (built.isFailure) return err(built.failureOrNull!);
      for (final e in built.requireValue) {
        final createdRes = await _ledger.create(e);
        if (createdRes.isFailure) return err(createdRes.failureOrNull!);
        created.add(createdRes.requireValue);
      }

      // STORY-7.3：储蓄划拨生成后同步目标进度
      final goalErr = await _syncGoal(rule, now);
      if (goalErr != null) return err(goalErr);

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

  /// 储蓄划拨的账单已经作为 transfer 记入目标虚拟账户，这里补记目标进度。
  /// 返回 null 表示无需处理或已成功。
  Future<Failure?> _syncGoal(RecurringRule rule, DateTime now) async {
    final goals = savingsGoalRepository;
    if (goals == null) return null;
    if (rule.kind != RecurringKind.savingsTransfer) return null;
    final goalId = rule.goalId;
    if (goalId == null) return null;
    final r = await creditGoalForRecurring(
      goals: goals,
      goalId: goalId,
      amountCents: rule.amount.cents,
      updatedAt: now,
    );
    return r.failureOrNull;
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
    required LedgerRepository repository, required Clock clock,
    this.recurringRepository,
    this.savingsGoalRepository,
  }) : _repository = repository, _clock = clock;

  final LedgerRepository _repository;
  final Clock _clock;

  /// 撤销要判断这批账单来自哪条规则（只有 `savingsTransfer` 需要回滚目标进度）。
  final RecurringRepository? recurringRepository;

  /// STORY-7.3：储蓄划拨批次撤销时把目标进度扣回。
  final SavingsGoalRepository? savingsGoalRepository;

  /// 撤销整个批次（含贷款还款的利息 + 本金两笔）。
  ///
  /// 走账本仓储的 `softDeleteBatch`，与单笔删除共用统计/欠款回滚口径；
  /// 之后按规则来源回滚储蓄目标进度（AC：撤销后目标不能虚高）。
  Future<Result<int>> call(String batchId) async {
    final res = await _repository.softDeleteBatch(batchId: batchId, at: _clock.now());
    if (res.isFailure) return res;
    // 没有可撤的账单 = 本来就没生成过，目标进度也就没被记过
    if (res.requireValue == 0) return res;
    await _rollbackGoalProgress(batchId);
    return res;
  }

  /// 储蓄划拨的进度是**生成时补记**的（`creditGoalForRecurring`），撤销时必须跟着回退，
  /// 否则目标已存金额只增不减 → 目标虚高、还会被误判成「已达成」。
  ///
  /// 回退方式**不是做减法**，而是按账本**重算**（`reconcileStoredSavedCents`）：
  /// 减法在规则金额被改过、一期生成多笔、或撤销被重试时会算错，重算是幂等的。
  /// 只处理 `kind = savingsTransfer` 的规则；其余批次（普通周期记账、贷款还款）
  /// 从来没动过目标进度。
  Future<void> _rollbackGoalProgress(String batchId) async {
    final rules = recurringRepository;
    final goals = savingsGoalRepository;
    if (rules == null || goals == null) return;

    final rule = (await rules.findByLastBatchId(batchId)).successOrNull;
    if (rule == null) return;
    if (rule.kind != RecurringKind.savingsTransfer) return;
    final goalId = rule.goalId;
    if (goalId == null) return;

    final goal = (await goals.getById(goalId)).successOrNull;
    if (goal == null) return;
    final recomputed = await reconcileStoredSavedCents(goal: goal, ledger: _repository);
    if (recomputed == null || recomputed == goal.savedCents) return;
    await goals.update(goal.copyWith(
      savedCents: recomputed,
      updatedAt: _clock.now(),
      revision: goal.revision + 1,
      baseRevision: goal.revision,
    ));
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
    this.accountRepository,
    this.savingsGoalRepository,
    this.ruleRepository,
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

  /// STORY-10.2：贷款还款规则需读参数做本息拆分。
  final AccountRepository? accountRepository;

  /// STORY-7.3：储蓄划拨确认后同步目标进度。
  final SavingsGoalRepository? savingsGoalRepository;

  /// STORY-7.3 AC1：确认路径同样要过规则引擎 post 阶段。
  ///
  /// ⚠️ 此前只有「自动生成」路径接了规则，确认路径没接 —— 而**贷款还款规则默认
  /// 就是 `autoConfirm = false`**（必须人工确认），等于主路径上 post 规则全部失效
  /// （audit 2026-10-15 发现）。
  final AutomationRuleRepository? ruleRepository;

  /// [skip]=true advances the schedule without creating a ledger entry.
  ///
  /// 返回本批生成的账单（贷款还款为 2 笔：利息 + 本金）。
  Future<Result<List<LedgerEntry>>> call(
    RecurringRule rule, {
    bool skip = false,
    required AppStrings s,
  }) async {
    if (rule.isFinished) {
      return err<List<LedgerEntry>>(
          const ValidationFailure('recurring.finished', 'done'));
    }
    final now = _clock.now();
    final created = <LedgerEntry>[];
    String? batchId;
    if (!skip) {
      batchId = _idGen.generate();
      final built = await buildEntriesForRule(
        s: s,
        rule: rule,
        batchId: batchId,
        now: now,
        idGen: _idGen,
        accountRepository: accountRepository,
        ruleRepository: ruleRepository,
        scope: RuleScope.recurring,
      );
      if (built.isFailure) return err(built.failureOrNull!);
      for (final e in built.requireValue) {
        final createdRes = await _ledger.create(e);
        if (createdRes.isFailure) return err(createdRes.failureOrNull!);
        created.add(createdRes.requireValue);
      }
      final goalErr = await _syncGoal(rule, now);
      if (goalErr != null) return err(goalErr);
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
    return ok(created);
  }

  Future<Failure?> _syncGoal(RecurringRule rule, DateTime now) async {
    final goals = savingsGoalRepository;
    if (goals == null) return null;
    if (rule.kind != RecurringKind.savingsTransfer) return null;
    final goalId = rule.goalId;
    if (goalId == null) return null;
    final r = await creditGoalForRecurring(
      goals: goals,
      goalId: goalId,
      amountCents: rule.amount.cents,
      updatedAt: now,
    );
    return r.failureOrNull;
  }
}
