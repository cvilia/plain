/// 储蓄目标与基金（STORY-7.1 / SP-5-06）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plain/app/bootstrap.dart';
import 'package:plain/app/settings/ledger_settings.dart';
import 'package:plain/app/theme/app_colors.dart';
import 'package:plain/app/theme/design_tokens.dart';
import 'package:plain/app/theme/typography.dart';
import 'package:plain/core/format/amount_formatter.dart';
import 'package:plain/core/refresh/data_invalidation.dart';
import 'package:plain/core/time/date_format.dart';
import 'package:plain/design_system/amount_display.dart';
import 'package:plain/design_system/app_date_picker.dart';
import 'package:plain/design_system/app_empty_state.dart';
import 'package:plain/design_system/app_error_state.dart';
import 'package:plain/design_system/app_toast.dart';
import 'package:plain/design_system/picker_sheet.dart';
import 'package:plain/design_system/plain_icons_v3.dart';
import 'package:plain/design_system/plain_ui.dart';
import 'package:plain/domain/entities/category.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/entities/ledger_entry.dart';
import 'package:plain/domain/entities/savings_goal.dart';
import 'package:plain/domain/repositories/repositories.dart';
import 'package:plain/domain/services/goal_progress_service.dart';
import 'package:plain/domain/services/goal_system_service.dart';
import 'package:plain/domain/services/loan_amortization_service.dart';
import 'package:plain/app/l10n/app_strings.dart';
import 'package:plain/app/l10n/strings_accounts.dart';
import 'package:plain/app/l10n/strings_core.dart';
import 'package:plain/app/l10n/strings_settings_a.dart';
import 'package:plain/app/l10n/strings_ledger.dart';

const _amortization = LoanAmortizationService();

class SavingsGoalsPage extends ConsumerStatefulWidget {
  const SavingsGoalsPage({super.key});

  @override
  ConsumerState<SavingsGoalsPage> createState() => _SavingsGoalsPageState();
}

/// 还债目标的实时测算上下文（全部由贷款参数与账本派生）。
class _DebtContext {
  const _DebtContext({
    required this.terms,
    required this.schedule,
    required this.progress,
  });

  final LoanTerms terms;
  final LoanSchedule schedule;
  final LoanProgress progress;
}

class _SavingsGoalsPageState extends ConsumerState<SavingsGoalsPage> {
  List<SavingsGoal> _goals = const [];
  /// 目标进度（已存 = 目标虚拟账户的派生余额），与 `_goals` 一一对应。
  List<GoalProgress> _progress = const [];
  /// 可选作存款转出端的账户（目标虚拟账户不可选）。
  List<Account> _accounts = const [];
  List<Account> _loanAccounts = const [];
  /// 还债目标（goal.id → 对应贷款的实时测算），全部派生自贷款参数与账本。
  final Map<String, _DebtContext> _debt = {};

  /// STORY-7.2：限额目标（派生自分类预算 + 当期支出，不落库）
  List<LimitGoalView> _limits = const [];

  /// 关联了外币贷款的还债目标名（不参与测算，需手动维护）。
  List<String> _foreignDebtGoals = const [];
  bool _loading = true;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final s = AppStrings.of(context);
    setState(() {
      _loading = true;
      _loadError = null;
    });
    final deps = ref.read(appDependenciesProvider);
    final res = await deps.savingsGoalRepository.listByBook(deps.bookId);
    // 目标进度读**目标虚拟账户的派生余额**（V3.0 口径），
    // 因此这里要一次性拿全账户余额（`listWithBalances` 一条聚合查询）。
    final accRes = await deps.accountRepository.listWithBalances();
    final loadFailure = res.failureOrNull ?? accRes.failureOrNull;
    if (loadFailure != null) {
      setState(() {
        _loadError = loadFailure;
        _loading = false;
      });
      return;
    }
    final rows = accRes.successOrNull ?? const <AccountWithBalance>[];
    final all = [for (final r in rows) r.account];
    final goals = res.successOrNull ?? const <SavingsGoal>[];

    // 目标进度（派生，不读存储的 saved_cents）
    final progress = _goalProgress.ofAll(
      goals: goals,
      balanceByAccount: GoalProgressService.balanceIndex(rows),
    );

    // 还债目标：从关联的贷款账户取实测数据（不写死）
    final debt = <String, _DebtContext>{};
    final foreignDebtGoals = <String>[];
    for (final g in goals.where((g) => g.isDebt)) {
      final accountId = g.accountId;
      if (accountId == null) continue;
      final loan = all.where((a) => a.id == accountId && a.isLoan).firstOrNull;
      if (loan == null) continue;
      // 外币负债不参与测算（口径 2026-10-15）：本金原币、流水本位币，算不出可信进度
      if (loan.needsManualDebtNote) {
        foreignDebtGoals.add(g.name);
        continue;
      }
      final terms = LoanTerms.ofAccount(loan);
      if (terms == null) continue;
      final balanceCents =
          rows.where((r) => r.account.id == accountId).firstOrNull?.balanceCents ?? 0;
      final remaining = balanceCents < 0 ? -balanceCents : 0;
      final page = await deps.ledgerRepository.listPage(
        filter: EntryFilter(accountId: accountId),
        limit: 2000,
      );
      final items = page.successOrNull?.items ?? const <LedgerEntry>[];
      final paid = items
          .where((e) =>
              !e.isDeleted &&
              e.type == EntryType.transfer &&
              e.toAccountId == accountId)
          .length;
      final schedule = _amortization.schedule(terms);
      debt[g.id] = _DebtContext(
        terms: terms,
        schedule: schedule,
        progress: _amortization.progress(
          schedule: schedule,
          remainingPrincipalCents: remaining,
          paidPeriods: paid,
        ),
      );
    }

    // STORY-7.2 限额目标：读分类预算 + 本记账月实际支出（口径复用 spentCents）
    final catRes = await deps.categoryRepository.listAll(kind: CategoryKind.expense);
    final categories = catRes.successOrNull ?? const <Category>[];
    final names = {for (final c in categories) c.id: c.name};
    final calendar = ref.read(calendarProvider);
    final period = calendar.currentPeriod();
    final limitRes = await _goalSystem.limitGoals(
      s: s,
      bookId: deps.bookId,
      from: DateTime.parse(period.dayFrom),
      to: DateTime.parse(period.dayTo).add(const Duration(days: 1)),
      categoryNames: names,
    );

    if (!mounted) return;
    setState(() {
      _goals = goals;
      _progress = progress;
      _accounts = all.where((a) => !a.type.isVirtual && !a.isLoan).toList();
      _loanAccounts = all.where((a) => a.isLoan).toList();
      _debt
        ..clear()
        ..addAll(debt);
      _limits = limitRes.successOrNull ?? const [];
      _foreignDebtGoals = foreignDebtGoals;
      _loading = false;
    });
  }

  GoalProgressService get _goalProgress => const GoalProgressService();

  GoalSystemService get _goalSystem => GoalSystemService(
        budgets: ref.read(appDependenciesProvider).budgetRepository,
        idGen: ref.read(appDependenciesProvider).idGen,
        clock: ref.read(appDependenciesProvider).clock,
      );

  /// STORY-7.2 AC4：建限额目标 = 写一条分类预算（同分类已有则改额度）。
  Future<void> _addLimit() async {
    final s = AppStrings.of(context);
    final deps = ref.read(appDependenciesProvider);
    final catRes = await deps.categoryRepository.listAll(kind: CategoryKind.expense);
    final categories = (catRes.successOrNull ?? const <Category>[])
        .where((c) => c.parentId != null) // 限额落在叶子分类上（与预算页一致）
        .toList();
    if (categories.isEmpty) {
      if (mounted) showAppToast(context, s.goalNoExpenseCategory);
      return;
    }
    if (!mounted) return;
    final cat = await showModalBottomSheet<Category>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final c in categories)
              PlainRow(
                title: c.name,
                onTap: () => Navigator.pop(ctx, c),
                showChevron: true,
              ),
          ],
        ),
      ),
    );
    if (cat == null || !mounted) return;
    final amount = await _askLimitAmount(context, title: s.goalMonthlyLimitTitle(cat.name));
    if (amount == null || !mounted) return;
    final res = await _goalSystem.setCategoryLimit(
      bookId: deps.bookId,
      categoryId: cat.id,
      amountCents: amount,
      deviceId: deps.deviceId,
    );
    if (!mounted) return;
    if (res.isFailure) {
      showAppToast(context, s.goalSetFailed(res.failureOrNull!.code));
      return;
    }
    ref.invalidateData.bumpBudgetMutated();
    await _reload();
  }

  /// 调整/删除已有限额目标（改的还是那条预算行）。
  Future<void> _editLimit(LimitGoalView view) async {
    final s = AppStrings.of(context);
    final deps = ref.read(appDependenciesProvider);
    final amount = await _askLimitAmount(
      context,
      title: s.goalMonthlyLimitTitle(view.categoryName),
      initial: view.limitCents,
      allowDelete: true,
    );
    if (amount == null || !mounted) return;
    if (amount < 0) {
      await _goalSystem.removeLimit(view.budget.id);
      ref.invalidateData.bumpBudgetMutated();
      await _reload();
      if (mounted) showAppToast(context, s.goalLimitDeleted);
      return;
    }
    final res = await _goalSystem.setCategoryLimit(
      bookId: deps.bookId,
      categoryId: view.budget.categoryId!,
      amountCents: amount,
      deviceId: deps.deviceId,
    );
    if (!mounted) return;
    if (res.isFailure) {
      showAppToast(context, s.goalUpdateFailed(res.failureOrNull!.code));
      return;
    }
    ref.invalidateData.bumpBudgetMutated();
    await _reload();
  }

  /// 返回 null = 取消，返回 -1 = 删除。
  Future<int?> _askLimitAmount(
    BuildContext context, {
    required String title,
    int? initial,
    bool allowDelete = false,
  }) async {
    final s = AppStrings.of(context);
    final ctrl = TextEditingController(
      text: initial == null ? '' : (initial / 100).toStringAsFixed(2),
    );
    return showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration:
              InputDecoration(
                  labelText: s.amountFieldLabel, border: const OutlineInputBorder()),
        ),
        actions: [
          if (allowDelete)
            TextButton(
              onPressed: () => Navigator.pop(ctx, -1),
              child: Text(s.delete),
            ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.cancel)),
          FilledButton(
            onPressed: () {
              final v = double.tryParse(ctrl.text.trim());
              if (v == null || v <= 0) {
                Navigator.pop(ctx);
                return;
              }
              Navigator.pop(ctx, (v * 100).round());
            },
            child: Text( s.save),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final now = ref.read(appDependenciesProvider).clock.now();
    return Scaffold(
      appBar: PlainTopBar(
        title: s.goalSystemTitle,
        showBack: true,
        actions: [
          Material(
            color: const Color(0x00000000),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: _showCreateSheet,
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 52,
                height: 44,
                child: Center(
                  child: Text(s.newAction, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: context.colors.primary)),
                ),
              ),
            ),
          ),
        ],
      ),
      body: _loadError != null
          ? AppErrorState.of(context, _loadError!, onRetry: _reload)
          : _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(Spacing.lg),
              children: [
                _Hero(views: _progress, now: now),
                if (_goals.isEmpty)
                  AppEmptyState(
                    icon: PlainIconData.chartLine,
                    title: s.goalEmptyTitle,
                    subtitle: s.goalEmptySubtitle,
                    action: FilledButton.icon(
                      onPressed: _showCreateSheet,
                      icon: const PlainIcon(PlainIconData.plus),
                      label: Text(s.goalNew),
                    ),
                  )
                else ...[
                  PlainEyebrow(s.goalCount(_goals.length)),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: context.colors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: context.colors.border),
                    ),
                    child: Column(
                      children: [
                        for (var i = 0; i < _goals.length; i++) ...[
                          if (i > 0) Divider(height: 1, thickness: 1, indent: 16, color: context.colors.divider),
                          _GoalRow(
                            view: _progress[i],
                            now: now,
                            debt: _debt[_goals[i].id],
                            onDeposit: () => _showDeposit(_goals[i]),
                            onToggleAuto: () => _toggleAuto(_goals[i]),
                            onPrepay: () => _showPrepay(_goals[i]),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: Spacing.md),
                ],
                if (_foreignDebtGoals.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Spacing.sm),
                    child: Text(
                      s.goalForeignDebtNote(_foreignDebtGoals.join('、')),
                      style: TextStyle(
                        fontSize: 12,
                        height: designLineHeight(12) * 1.4,
                        color: context.colors.inkTertiary,
                      ),
                    ),
                  ),
                // ── STORY-7.2：限额目标（= 分类预算，同一份数据）──
                PlainEyebrow(s.goalLimitCount(_limits.length)),
                if (_limits.isEmpty)
                  PlainPanel(children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.goalLimitEmptyNote,
                            style: TextStyle(
                              fontSize: 12,
                              height: designLineHeight(12) * 1.4,
                              color: context.colors.inkTertiary,
                            ),
                          ),
                          const SizedBox(height: Spacing.sm),
                          FilledButton.icon(
                            onPressed: _addLimit,
                            icon: const PlainIcon(PlainIconData.plus),
                            label: Text(s.goalAddLimit),
                          ),
                        ],
                      ),
                    ),
                  ])
                else
                  PlainPanel(children: [
                    for (var i = 0; i < _limits.length; i++) ...[
                      if (i > 0)
                        Divider(
                            height: 1,
                            thickness: 1,
                            indent: 16,
                            color: context.colors.divider),
                      _LimitRow(
                        view: _limits[i],
                        onTap: () => _editLimit(_limits[i]),
                      ),
                    ],
                    const Divider(height: 1, thickness: 1, indent: 16),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              s.goalLimitReuseNote,
                              style: TextStyle(
                                fontSize: 12,
                                height: designLineHeight(12),
                                color: context.colors.inkTertiary,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _addLimit,
                            icon: const PlainIcon(PlainIconData.plus, size: 16),
                            label: Text(s.addAction),
                          ),
                        ],
                      ),
                    ),
                  ]),
                _NotePanel(),
              ],
            ),
    );
  }

  Future<void> _showDeposit(SavingsGoal g) async {
    final s = AppStrings.of(context);
    // 存入是「可用账户 → 目标虚拟账户」的内部转账，必须先有转出端
    if (!g.canDeposit) {
      showAppToast(context, s.goalAccountRequired);
      return;
    }
    // 还债目标的进度靠还款推进，不提供「存入」
    if (g.isDebt) {
      showAppToast(context, s.goalDebtNoDeposit);
      return;
    }
    final ctrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.goalDepositTitle(g.name)),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: s.amountFieldLabel, border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.cancel)),
          FilledButton(
            onPressed: () async {
              final v = double.tryParse(ctrl.text.trim()) ?? 0;
              final cents = (v * 100).round();
              if (cents <= 0) return;
              final deps = ref.read(appDependenciesProvider);
              final r = await deps.depositToGoal(
                goalId: g.id,
                amountCents: cents,
                deviceId: deps.deviceId,
              );
              if (ctx.mounted) Navigator.pop(ctx);
              if (!mounted) return;
              if (r.isSuccess) {
                showAppToast(context, s.goalDeposited);
                ref.invalidateData.bumpEntryMutated();
                ref.invalidateData.bumpAccountsMutated();
                _reload();
              } else {
                showAppToast(context, s.goalDepositFailed);
              }
            },
            child: Text(s.ok),
          ),
        ],
      ),
    );
  }

  /// STORY-7.1 AC6：开启「自动按月划拨」——走统一周期引擎，锚定记账月首日。
  Future<void> _toggleAuto(SavingsGoal g) async {
    final s = AppStrings.of(context);
    final deps = ref.read(appDependenciesProvider);
    final r = await deps.setGoalAutoTransfer(
      goalId: g.id,
      enabled: !g.autoTransfer,
      monthStartDay: ref.read(monthStartDayProvider),
    );
    if (!mounted) return;
    if (r.isFailure) {
      final code = r.failureOrNull?.code;
      showAppToast(context, switch (code) {
        'goal.account_required' => s.goalAccountRequired,
        'goal.nothing_to_transfer' => s.goalNothingToTransfer,
        _ => s.operationFailed,
      });
      return;
    }
    showAppToast(context, g.autoTransfer ? s.goalAutoOff : s.goalAutoOn);
    ref.invalidateData.bumpRecurringMutated();
    _reload();
  }

  /// STORY-7.2 AC3：还债目标的提前还款测算。
  ///
  /// 「提前 N 个月还清、少付利息 ¥Z」由 `LoanAmortizationService` 派生，
  /// 依据的是关联贷款的真实参数与剩余本金，不写死任何数字。
  Future<void> _showPrepay(SavingsGoal g) async {
    final s = AppStrings.of(context);
    final ctx = _debt[g.id];
    if (ctx == null) {
      showAppToast(context, s.goalLoanMissingParams);
      return;
    }
    // 不手管 controller：`showDialog` 返回时弹窗淡出动画还没结束、子树仍会重建，
    // 此时 dispose 会抛「A TextEditingController was used after being disposed」。
    // 用局部变量 + `onChanged` 取值，`TextFormField` 自己管内部 controller。
    var extraText = '';
    var lumpText = '';
    await showDialog<void>(
      context: context,
      builder: (dctx) => StatefulBuilder(
        builder: (dctx, setDlg) {
          final extra = _centsOf(extraText);
          final lump = _centsOf(lumpText);
          final r = _amortization.prepay(
            ctx.terms,
            extraMonthlyCents: extra,
            lumpSumCents: lump,
          );
          final hasInput = extra > 0 || lump > 0;
          return AlertDialog(
            title: Text(s.goalPrepayTitle(g.name)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (v) => setDlg(() => extraText = v),
                  decoration: InputDecoration(
                      labelText: s.extraMonthly,
                      border: OutlineInputBorder(),
                      prefixText: '¥'),
                ),
                const SizedBox(height: Spacing.md),
                TextFormField(
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (v) => setDlg(() => lumpText = v),
                  decoration: InputDecoration(
                      labelText: s.lumpSum,
                      border: OutlineInputBorder(),
                      prefixText: '¥'),
                ),
                const SizedBox(height: Spacing.lg),
                Text(
                  hasInput
                      ? s.goalPrepayResult(r.monthsSaved, formatAmountYuan(r.interestSavedCents))
                      : s.goalPrepayBaseline(r.baseline.months, formatAmountYuan(r.baseline.interestCents)),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.colors.ink,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dctx),
                child: Text(s.close),
              ),
            ],
          );
        },
      ),
    );
  }

  int _centsOf(String text) {
    final v = double.tryParse(text.trim());
    if (v == null || v <= 0) return 0;
    return (v * 100).round();
  }

  Future<void> _showCreateSheet() async {
    final s = AppStrings.of(context);
    final nameCtrl = TextEditingController();
    final targetCtrl = TextEditingController();
    // STORY-7.2：储蓄目标 vs 还债目标
    var isDebt = false;
    var accountId = _accounts.isNotEmpty ? _accounts.first.id : null;
    var dueAt = ref.read(appDependenciesProvider).clock.now().add(const Duration(days: 365));
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
        padding: EdgeInsets.only(
          left: Spacing.lg,
          right: Spacing.lg,
          top: Spacing.lg,
          bottom: MediaQuery.viewInsetsOf(ctx).bottom + Spacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(s.goalCreateTitle, style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: Spacing.md),
            TextField(controller: nameCtrl, decoration: InputDecoration(labelText: s.nameLabel, border: OutlineInputBorder())),
            const SizedBox(height: Spacing.md),
            TextField(
              controller: targetCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: s.goalTargetAmount, border: OutlineInputBorder()),
            ),
            const SizedBox(height: Spacing.md),
            // 类型决定「关联账户」的候选集：储蓄选可用账户，还债选贷款账户
            PickerField(
              label: s.goalTypeLabel,
              value: isDebt ? s.goalTypeDebt : s.homeCardSavingsGoals,
              onTap: () async {
                final picked = await showOptionPicker<String>(
                  context: ctx,
                  title: s.goalTypeLabel,
                  current: isDebt ? 'debt' : 'savings',
                  options: [
                    PickerOption(value: 'savings', label: s.homeCardSavingsGoals),
                    PickerOption(value: 'debt', label: s.goalTypeDebt),
                  ],
                );
                if (picked == null) return;
                setSheet(() {
                  isDebt = picked == 'debt';
                  final list = isDebt ? _loanAccounts : _accounts;
                  accountId = list.isEmpty ? null : list.first.id;
                });
              },
            ),
            const SizedBox(height: Spacing.md),
            // 关联账户 = 存款划拨的转出端；还债目标则指向贷款账户
            PickerField(
              label: isDebt ? s.goalLinkLoan : s.goalLinkAccount,
              value: () {
                final list = isDebt ? _loanAccounts : _accounts;
                for (final a in list) {
                  if (a.id == accountId) return a.name;
                }
                return s.notSelected;
              }(),
              onTap: () async {
                final list = isDebt ? _loanAccounts : _accounts;
                final picked = await showOptionPicker<String>(
                  context: ctx,
                  title: isDebt ? s.goalLinkLoan : s.goalLinkAccount,
                  current: accountId,
                  options: [
                    for (final a in list)
                      PickerOption(value: a.id, label: a.name),
                  ],
                );
                if (picked != null) setSheet(() => accountId = picked);
              },
            ),
            const SizedBox(height: Spacing.md),
            PlainRow(
              title: s.goalDueDate,
              value: formatDate(dueAt),
              showChevron: true,
              onTap: () async {
                final picked = await showAppDatePicker(
                  context: ctx,
                  initialDate: dueAt.toLocal(),
                  firstDate: DateTime(2020),
                  // 目标截止日天然在未来，不能用选择器的默认上界
                  lastDate: DateTime.now().add(const Duration(days: 3650)),
                );
                if (picked != null) setSheet(() => dueAt = picked.toUtc());
              },
            ),
            const SizedBox(height: Spacing.lg),
            FilledButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final target = ((double.tryParse(targetCtrl.text.trim()) ?? 0) * 100).round();
                if (name.isEmpty || target <= 0) return;
                final deps = ref.read(appDependenciesProvider);
                final now = deps.clock.now();
                await deps.savingsGoalRepository.create(SavingsGoal(
                  id: deps.idGen.generate(),
                  bookId: deps.bookId,
                  name: name,
                  targetCents: target,
                  savedCents: 0,
                  goalType: isDebt ? GoalType.debt : GoalType.savings,
                  dueAt: dueAt,
                  accountId: accountId,
                  createdAt: now,
                  updatedAt: now,
                  deviceId: deps.deviceId,
                ));
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  showAppToast(context, s.goalCreated);
                  _reload();
                }
              },
              child: Text(s.save),
            ),
          ],
        ),
        ),
      ),
    );
    if (mounted) ref.invalidateData.bumpBudgetMutated();
  }
}

/// STORY-7.2：限额目标一行（数据来自分类预算，只读展示 + 点开调整）。
class _LimitRow extends StatelessWidget {
  const _LimitRow({required this.view, required this.onTap});
  final LimitGoalView view;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final colors = context.colors;
    final pct = (view.progress * 100).round();
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    view.categoryName,
                    style: TextStyle(
                      fontSize: 15,
                      height: designLineHeight(15),
                      fontWeight: FontWeight.w500,
                      color: colors.ink,
                    ),
                  ),
                ),
                Text(
                  '¥${formatAmount(view.spentCents, hide: false)} / '
                  '¥${formatAmount(view.limitCents, hide: false)}',
                  style: TextStyle(
                    fontSize: 14,
                    height: designLineHeight(14),
                    color: colors.inkSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: view.progress,
                minHeight: 4,
                backgroundColor: colors.chartTrack,
                valueColor: AlwaysStoppedAnimation(
                  view.isOver ? colors.expense : colors.primary,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              view.isOver
                  ? s.goalLimitOver(formatAmount(-view.remainingCents, hide: false))
                  : s.goalLimitRemaining(formatAmount(view.remainingCents, hide: false), pct),
              style: TextStyle(
                fontSize: 12,
                height: designLineHeight(12),
                color: view.isOver ? colors.expense : colors.inkTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {  const _Hero({required this.views, required this.now});
  /// 进度视图（已存 = 虚拟账户派生余额）。
  final List<GoalProgress> views;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final colors = context.colors;
    final totalSaved = views.fold(0, (s, v) => s + v.savedCents);
    final totalTarget = views.fold(0, (s, v) => s + v.targetCents);
    final monthly = views.fold(0, (s, v) => s + v.monthlyRequiredCentsAt(now));
    final pct = totalTarget > 0 ? (totalSaved / totalTarget * 100).toStringAsFixed(1) : '0.0';
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(height: 1, thickness: 1, color: colors.border),
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8, left: 2),
            child: Text(
              s.goalHeroSavedOfTarget,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.08 * 12, color: colors.inkTertiary),
            ),
          ),
          // 设计稿 `.amt.xl`（见 reimburse_center_page 同处注释）：
          // cur 21.08 muted + int/pnt 34 w700 ink + dec 21.08 w600 muted，
          // 四段共用 `-0.68px` tracking、行盒 39.44。原来手写三段式全不符。
          AmountDisplay(cents: totalSaved, fontSize: 34),
          const SizedBox(height: 16),
          Row(
            children: [
              _Split(label: s.goalTotalProgress, text: '$pct%'),
              const SizedBox(width: 28),
              _Split(label: s.goalMonthlyNeed, text: formatAmountYuan(monthly)),
            ],
          ),
          const SizedBox(height: 16),
          Divider(height: 1, thickness: 1, color: colors.border),
        ],
      ),
    );
  }
}

class _Split extends StatelessWidget {
  const _Split({required this.label, required this.text});
  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: colors.inkTertiary)),
        const SizedBox(height: 4),
        Text(text, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.ink)),
      ],
    );
  }
}

class _GoalRow extends StatelessWidget {
  const _GoalRow({
    required this.view,
    required this.now,
    required this.onDeposit,
    required this.onToggleAuto,
    required this.onPrepay,
    this.debt,
  });

  /// 进度视图：进度/已存/还差都读**虚拟账户派生余额**。
  final GoalProgress view;
  final DateTime now;
  final VoidCallback onDeposit;
  final VoidCallback onToggleAuto;
  final VoidCallback onPrepay;

  /// 还债目标专属：关联贷款的实时测算（AC2/AC3）。
  final _DebtContext? debt;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final colors = context.colors;
    final g = view.goal;
    final monthly = view.monthlyRequiredCentsAt(now);
    final progress = view.progress.clamp(0.0, 1.0).toDouble();
    final remaining = (view.targetCents - view.savedCents).clamp(0, view.targetCents).toInt();
    final pct = (view.progress * 100).round();
    return Padding(
      // 水平 16：卡片内标题/金额/进度条不能贴卡片边框（对齐 _LimitRow 的口径）
      padding: const EdgeInsets.fromLTRB(16, Spacing.md, 16, Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(g.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500))),
              Text(formatAmountYuan(view.savedCents), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.ink)),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          _ProgressBar(progress: progress),
          const SizedBox(height: Spacing.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  s.goalRemainingPct(pct, formatAmountYuan(remaining)),
                  style: TextStyle(fontSize: 12, color: colors.inkTertiary),
                ),
              ),
              Text(s.goalMonthlySave(formatAmountYuan(monthly)), style: TextStyle(fontSize: 12, color: colors.inkSecondary)),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          Row(
            children: [
              // STORY-7.1：手动存入（还债目标不适用）
              if (!g.isDebt) ...[
                TextButton(onPressed: onDeposit, child: Text(s.goalDepositAction)),
                const SizedBox(width: Spacing.sm),
              ],
              // STORY-7.1 AC6：自动按月划拨（走统一周期引擎）
              if (!g.isDebt) ...[
                Text(
                  s.goalAutoTransfer,
                  style: TextStyle(fontSize: 14, color: colors.inkSecondary),
                ),
                const Spacer(),
                Switch(value: g.autoTransfer, onChanged: (_) => onToggleAuto()),
              ],
              // STORY-7.2 AC3：还债目标可做提前还款测算
              if (g.isDebt && debt != null) ...[
                const Spacer(),
                TextButton(onPressed: onPrepay, child: Text(s.prepayCalc)),
              ],
            ],
          ),
          // STORY-7.2 AC2：剩余期数 / 剩余利息 / 预计还清日
          if (g.isDebt && debt != null) ...[
            const SizedBox(height: Spacing.sm),
            Text(
              s.goalDebtRemaining(
                debt!.progress.remainingMonths,
                formatAmountYuan(debt!.progress.remainingInterestCents),
                debt!.progress.payoffDate == null
                    ? s.goalDebtSettled
                    : '${debt!.progress.payoffDate!.year}-'
                        '${debt!.progress.payoffDate!.month.toString().padLeft(2, '0')}',
              ),
              style: TextStyle(fontSize: 12, color: colors.inkTertiary),
            ),
          ],
          if (g.isDebt && debt == null)
            Padding(
              padding: const EdgeInsets.only(top: Spacing.sm),
              child: Text(
                s.goalLoanIncomplete,
                style: TextStyle(fontSize: 12, color: colors.inkTertiary),
              ),
            ),
          // AC4：截止日已过而未达成时标记「未达成」，数据保留
          if (view.isOverdueAt(now))
            Padding(
              padding: const EdgeInsets.only(top: Spacing.xs),
              child: Text(
                s.goalOverdue,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.accent),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      height: 6,
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: progress.clamp(0.0, 1.0).toDouble(),
          child: Container(
            decoration: BoxDecoration(
              color: colors.primary,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      ),
    );
  }
}

class _NotePanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final colors = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RichPara(
            plain: s.goalFundPlain,
            parts: [
              (true, s.goalFundBold),
              (false, s.goalFundPlain),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          _RichPara(
            plain: s.goalDeductPlain,
            parts: [
              (false, s.goalDeductA),
              (true, s.goalDeductB),
              (false, s.goalDeductC),
            ],
          ),
        ],
      ),
    );
  }
}

class _RichPara extends StatelessWidget {
  const _RichPara({required this.plain, required this.parts});
  final String plain;
  final List<(bool, String)> parts;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      label: plain,
      child: Text.rich(
        TextSpan(
          children: [
            for (final (isBold, text) in parts)
              TextSpan(
                text: text,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
                  color: isBold ? colors.ink : colors.inkSecondary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
