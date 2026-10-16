/// STORY-7.1 储蓄 / 沉淀目标用例。
library;

import 'package:plain/core/constants/app_constants.dart';
import 'package:plain/core/id/uuid_v7.dart';
import 'package:plain/core/money/money.dart';
import 'package:plain/core/result/result.dart';
import 'package:plain/core/time/clock.dart';
import 'package:plain/domain/entities/category.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/entities/ledger_entry.dart';
import 'package:plain/domain/entities/recurring_rule.dart';
import 'package:plain/domain/entities/savings_goal.dart';
import 'package:plain/domain/repositories/repositories.dart';

/// 向目标「存入一笔」。
///
/// 存款是「可用账户 → 目标虚拟账户」的**内部转账**：
/// - 转账按 G-2 不计入收支，所以 AC3 天然成立（收入与支出均不增加）；
/// - 两端都是真实账户余额变动，钱确实被「预留」了出去，不是只改一个数字。
///
/// 目标虚拟账户（`accounts.type = 'goal'`）在首次存入时**惰性创建**，
/// 不作为用户可选账户出现（`AccountType.isVirtual`）。
class DepositToGoalUseCase {
  DepositToGoalUseCase({
    required SavingsGoalRepository goalRepository,
    required LedgerRepository ledgerRepository,
    required AccountRepository accountRepository,
    required Clock clock,
    required UuidV7 idGen,
  })  : _goals = goalRepository,
        _ledger = ledgerRepository,
        _accounts = accountRepository,
        _clock = clock,
        _idGen = idGen;

  final SavingsGoalRepository _goals;
  final LedgerRepository _ledger;
  final AccountRepository _accounts;
  final Clock _clock;
  final UuidV7 _idGen;

  Future<Result<SavingsGoal>> call({
    required String goalId,
    required int amountCents,
    required String deviceId,
  }) async {
    if (amountCents <= 0) {
      return err<SavingsGoal>(
          const ValidationFailure('goal.amount_invalid', 'zero'));
    }

    final found = await _goals.getById(goalId);
    final f = found.failureOrNull;
    if (f != null) return err(f);
    final goal = found.successOrNull!;

    if (!goal.canDeposit) {
      // 没有关联账户就无处可划，先让用户补上
      return err<SavingsGoal>(
          const ValidationFailure('goal.account_required', 'no source account'));
    }

    final now = _clock.now();
    final goalAccountId = goal.goalAccountId ?? _idGen.generate(at: now);

    // 1) 首次存入先建目标虚拟账户
    if (goal.goalAccountId == null) {
      final created = await _accounts.create(Account(
        id: goalAccountId,
        name: goal.name,
        type: AccountType.goal,
        currency: MoneyRules.defaultCurrency,
        openingBalance: 0,
        note: '储蓄目标账户',
        sortOrder: virtualGoalAccountSortOrder,
        createdAt: now,
        updatedAt: now,
        deviceId: deviceId,
      ));
      final cf = created.failureOrNull;
      if (cf != null) return err(cf);
    }

    // 2) 先落权威值（saved_cents 是存储值，见《08》§5.11），再补转账凭证。
    //    与 CreditReconcileService 的次序一致：存储值在前，凭证在后。
    final nextGoal = goal.copyWith(
      goalAccountId: goalAccountId,
      savedCents: goal.savedCents + amountCents,
      updatedAt: now,
      revision: goal.revision + 1,
      baseRevision: goal.revision,
    );
    final updated = await _goals.update(nextGoal);
    final uf = updated.failureOrNull;
    if (uf != null) return err(uf);

    // 3) 内部转账（转出端是目标的关联账户，转入端是虚拟账户）
    final entry = LedgerEntry(
      id: _idGen.generate(at: now),
      bookId: goal.bookId,
      type: EntryType.transfer,
      amount: Money(amountCents),
      currency: MoneyRules.defaultCurrency,
      accountId: goal.accountId,
      toAccountId: goalAccountId,
      occurredAt: now,
      note: '存入「${goal.name}」',
      source: EntrySource.manual,
      createdAt: now,
      updatedAt: now,
      deviceId: deviceId,
    );
    final created = await _ledger.create(entry);
    final ef = created.failureOrNull;
    if (ef != null) return err(ef);

    return ok(nextGoal);
  }
}

/// 目标虚拟账户排在账户列表末尾，不与真实账户混在一起。
const int virtualGoalAccountSortOrder = 9000;

/// 确保 [goal] 已有目标虚拟账户，返回其 id（已存在则直接返回）。
///
/// 手动存入与自动划拨（STORY-7.3）都要先有转入端，故提取为共用步骤。
Future<Result<String>> ensureGoalAccount({
  required AccountRepository accounts,
  required SavingsGoalRepository goals,
  required SavingsGoal goal,
  required DateTime now,
  required String deviceId,
  required UuidV7 idGen,
}) async {
  final existing = goal.goalAccountId;
  if (existing != null) return ok(existing);

  final id = idGen.generate(at: now);
  final created = await accounts.create(Account(
    id: id,
    name: goal.name,
    type: AccountType.goal,
    currency: MoneyRules.defaultCurrency,
    openingBalance: 0,
    note: '储蓄目标账户',
    sortOrder: virtualGoalAccountSortOrder,
    createdAt: now,
    updatedAt: now,
    deviceId: deviceId,
  ));
  final f = created.failureOrNull;
  if (f != null) return err(f);

  final updated = await goals.update(goal.copyWith(
    goalAccountId: id,
    updatedAt: now,
    revision: goal.revision + 1,
    baseRevision: goal.revision,
  ));
  final uf = updated.failureOrNull;
  if (uf != null) return err(uf);
  return ok(id);
}

/// STORY-7.3：周期引擎生成「储蓄划拨」账单后，把该笔记到目标上。
///
/// 把目标存储的「已存」计数按**账本重算**（幂等，可反复调用）。
///
/// 存储值只是缓存，事实来源是账本：目标虚拟账户上的内部转账净流入。
/// 比「按规则金额扣一笔」可靠 —— 后者在规则金额被改过、一期生成了多笔、
/// 或撤销被重试时会算错，而重算怎么调都是同一个结果。
/// 因此撤销批次后与启动巡检都用它，而不是各自做减法。
///
/// 返回重算后的金额；目标还没建虚拟账户（`goalAccountId == null`）时返回 null
/// （老数据：没有账户就没有可追溯的转账，不做猜测）。
Future<int?> reconcileStoredSavedCents({
  required SavingsGoal goal,
  required LedgerRepository ledger,
}) async {
  final accountId = goal.goalAccountId;
  if (accountId == null) return null;

  // 虚拟账户上的转账：流入记正、流出记负（净额既是「已存」）
  final page = await ledger.listPage(
    filter: EntryFilter(accountId: accountId),
    limit: 5000,
  );
  final items = page.successOrNull?.items ?? const <LedgerEntry>[];
  var net = 0;
  for (final e in items) {
    if (e.isDeleted || e.type != EntryType.transfer) continue;
    if (e.toAccountId == accountId) {
      net += e.amount.cents;
    } else if (e.accountId == accountId) {
      net -= e.amount.cents;
    }
  }
  return net < 0 ? 0 : net;
}

/// 金额已由周期引擎作为一笔 transfer 记入虚拟账户（钱确实被预留了），
/// 这里只同步目标的进度计数——与手动存入是同一套语义，不构成双算。
Future<Result<void>> creditGoalForRecurring({
  required SavingsGoalRepository goals,
  required String goalId,
  required int amountCents,
  required DateTime updatedAt,
}) async {
  final found = await goals.getById(goalId);
  final f = found.failureOrNull;
  if (f != null) return err(f);
  final goal = found.successOrNull!;
  final updated = await goals.update(goal.copyWith(
    savedCents: goal.savedCents + amountCents,
    updatedAt: updatedAt,
    revision: goal.revision + 1,
    baseRevision: goal.revision,
  ));
  final uf = updated.failureOrNull;
  if (uf != null) return err(uf);
  return ok(null);
}

/// 开启 / 关闭某个储蓄目标的「自动按月划拨」（STORY-7.1 AC6）。
///
/// 走**统一周期引擎**（STORY-7.3）：生成一条 `kind = savingsTransfer` 的月度规则，
/// 锚定日取记账月首日，账单类型为 transfer（G-2 不计入收支）。
class SetGoalAutoTransferUseCase {
  SetGoalAutoTransferUseCase({
    required SavingsGoalRepository goalRepository,
    required AccountRepository accountRepository,
    required RecurringRepository recurringRepository,
    required Clock clock,
    required UuidV7 idGen,
  })  : _goals = goalRepository,
        _accounts = accountRepository,
        _recurring = recurringRepository,
        _clock = clock,
        _idGen = idGen;

  final SavingsGoalRepository _goals;
  final AccountRepository _accounts;
  final RecurringRepository _recurring;
  final Clock _clock;
  final UuidV7 _idGen;

  /// [monthStartDay] 来自记账设置（G-1），划拨锚定在记账月首日。
  Future<Result<SavingsGoal>> call({
    required String goalId,
    required bool enabled,
    required int monthStartDay,
  }) async {
    final found = await _goals.getById(goalId);
    final f = found.failureOrNull;
    if (f != null) return err(f);
    var goal = found.successOrNull!;

    final now = _clock.now();

    if (!enabled) {
      // 关闭：停用既有规则（保留历史，不删除）
      final rules = await _recurring.listByBook(goal.bookId);
      for (final r in rules.successOrNull ?? const <RecurringRule>[]) {
        if (r.kind != RecurringKind.savingsTransfer || r.goalId != goalId) continue;
        if (!r.isEnabled) continue;
        await _recurring.update(r.copyWith(
          isEnabled: false,
          updatedAt: now,
          revision: r.revision + 1,
          baseRevision: r.revision,
        ));
      }
      final off = await _goals.update(goal.copyWith(
        autoTransfer: false,
        updatedAt: now,
        revision: goal.revision + 1,
        baseRevision: goal.revision,
      ));
      final of = off.failureOrNull;
      if (of != null) return err(of);
      return ok(off.successOrNull!);
    }

    if (!goal.canDeposit) {
      return err<SavingsGoal>(
          const ValidationFailure('goal.account_required', 'no source account'));
    }
    final perMonth = goal.monthlyRequiredCentsAt(now);
    if (perMonth <= 0) {
      return err<SavingsGoal>(
          const ValidationFailure('goal.nothing_to_transfer', 'already funded'));
    }

    // 划拨要转入虚拟账户，先确保它存在
    final accRes = await ensureGoalAccount(
      accounts: _accounts,
      goals: _goals,
      goal: goal,
      now: now,
      deviceId: goal.deviceId,
      idGen: _idGen,
    );
    final af = accRes.failureOrNull;
    if (af != null) return err(af);
    final goalAccountId = accRes.requireValue;

    // 重读一次：ensureGoalAccount 可能已写入 goalAccountId
    goal = (await _goals.getById(goalId)).successOrNull!;

    final firstRun = _firstRunAt(now, monthStartDay);
    final rule = RecurringRule(
      id: _idGen.generate(at: now),
      bookId: goal.bookId,
      name: '划拨「${goal.name}」',
      frequency: RecurringFrequency.monthly,
      anchorDay: monthStartDay,
      autoConfirm: true,
      entryType: EntryType.transfer,
      amount: Money(perMonth),
      accountId: goal.accountId,
      toAccountId: goalAccountId,
      note: '自动划拨「${goal.name}」',
      kind: RecurringKind.savingsTransfer,
      goalId: goalId,
      nextRunAt: firstRun,
      createdAt: now,
      updatedAt: now,
      deviceId: goal.deviceId,
    );
    final created = await _recurring.create(rule);
    final cf = created.failureOrNull;
    if (cf != null) return err(cf);

    final on = await _goals.update(goal.copyWith(
      autoTransfer: true,
      updatedAt: now,
      revision: goal.revision + 1,
      baseRevision: goal.revision,
    ));
    final of = on.failureOrNull;
    if (of != null) return err(of);
    return ok(on.successOrNull!);
  }

  /// 首次划拨落在下一个记账月首日（当月首日已过则顺延到下一月）。
  DateTime _firstRunAt(DateTime now, int monthStartDay) {
    final d = monthStartDay.clamp(1, 28);
    var next = DateTime.utc(now.year, now.month, d);
    if (!next.isAfter(now)) {
      next = DateTime.utc(now.year, now.month + 1, d);
    }
    return next;
  }
}
