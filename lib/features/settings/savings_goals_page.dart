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

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final deps = ref.read(appDependenciesProvider);
    final res = await deps.savingsGoalRepository.listByBook(deps.bookId);
    // 目标进度读**目标虚拟账户的派生余额**（V3.0 口径），
    // 因此这里要一次性拿全账户余额（`listWithBalances` 一条聚合查询）。
    final accRes = await deps.accountRepository.listWithBalances();
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
    final deps = ref.read(appDependenciesProvider);
    final catRes = await deps.categoryRepository.listAll(kind: CategoryKind.expense);
    final categories = (catRes.successOrNull ?? const <Category>[])
        .where((c) => c.parentId != null) // 限额落在叶子分类上（与预算页一致）
        .toList();
    if (categories.isEmpty) {
      if (mounted) showAppToast(context, '还没有可用的支出分类');
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
    final amount = await _askLimitAmount(context, title: '「${cat.name}」每月上限');
    if (amount == null || !mounted) return;
    final res = await _goalSystem.setCategoryLimit(
      bookId: deps.bookId,
      categoryId: cat.id,
      amountCents: amount,
      deviceId: deps.deviceId,
    );
    if (!mounted) return;
    if (res.isFailure) {
      showAppToast(context, '设置失败：${res.failureOrNull!.code}');
      return;
    }
    ref.invalidateData.bumpBudgetMutated();
    await _reload();
  }

  /// 调整/删除已有限额目标（改的还是那条预算行）。
  Future<void> _editLimit(LimitGoalView view) async {
    final deps = ref.read(appDependenciesProvider);
    final amount = await _askLimitAmount(
      context,
      title: '「${view.categoryName}」每月上限',
      initial: view.limitCents,
      allowDelete: true,
    );
    if (amount == null || !mounted) return;
    if (amount < 0) {
      await _goalSystem.removeLimit(view.budget.id);
      ref.invalidateData.bumpBudgetMutated();
      await _reload();
      if (mounted) showAppToast(context, '已删除限额目标');
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
      showAppToast(context, '修改失败：${res.failureOrNull!.code}');
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
              const InputDecoration(labelText: '金额', border: OutlineInputBorder()),
        ),
        actions: [
          if (allowDelete)
            TextButton(
              onPressed: () => Navigator.pop(ctx, -1),
              child: const Text('删除'),
            ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              final v = double.tryParse(ctrl.text.trim());
              if (v == null || v <= 0) {
                Navigator.pop(ctx);
                return;
              }
              Navigator.pop(ctx, (v * 100).round());
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = ref.read(appDependenciesProvider).clock.now();
    return Scaffold(
      appBar: PlainTopBar(
        title: '目标体系',
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
                  child: Text('新建', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: context.colors.primary)),
                ),
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(Spacing.lg),
              children: [
                _Hero(views: _progress, now: now),
                if (_goals.isEmpty)
                  AppEmptyState(
                    icon: PlainIconData.chartLine,
                    title: '还没有目标',
                    subtitle: '建一个储蓄目标攒钱、关联贷款做还债目标，或用限额目标控制某类开销',
                    action: FilledButton.icon(
                      onPressed: _showCreateSheet,
                      icon: const PlainIcon(PlainIconData.plus),
                      label: const Text('新建目标'),
                    ),
                  )
                else ...[
                  PlainEyebrow('目标 · ${_goals.length} 个'),
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
                      '${_foreignDebtGoals.join('、')} 关联的是外币贷款，'
                      '未参与进度测算（本金外币、流水本位币对不上），请手动维护还款进度。',
                      style: TextStyle(
                        fontSize: 12,
                        height: designLineHeight(12) * 1.4,
                        color: context.colors.inkTertiary,
                      ),
                    ),
                  ),
                // ── STORY-7.2：限额目标（= 分类预算，同一份数据）──
                PlainEyebrow('限额目标 · ${_limits.length} 个'),
                if (_limits.isEmpty)
                  PlainPanel(children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '想控制某类开销（例如「本月餐饮 ≤ 2000」）就建一个限额目标。'
                            '它的底层就是分类预算，和预算页看到的是同一份数据。',
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
                            label: const Text('添加限额目标'),
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
                              '限额目标复用分类预算，不产生第二套数据；'
                              '切换预算方法论时它照常生效。',
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
                            label: const Text('添加'),
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
    // 存入是「可用账户 → 目标虚拟账户」的内部转账，必须先有转出端
    if (!g.canDeposit) {
      showAppToast(context, '请先给该目标关联一个账户');
      return;
    }
    // 还债目标的进度靠还款推进，不提供「存入」
    if (g.isDebt) {
      showAppToast(context, '还债目标通过还款推进，不能存入');
      return;
    }
    final ctrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('存入「${g.name}」'),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: '金额', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
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
                showAppToast(context, '已存入');
                ref.invalidateData.bumpEntryMutated();
                ref.invalidateData.bumpAccountsMutated();
                _reload();
              } else {
                showAppToast(context, '存入失败');
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  /// STORY-7.1 AC6：开启「自动按月划拨」——走统一周期引擎，锚定记账月首日。
  Future<void> _toggleAuto(SavingsGoal g) async {
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
        'goal.account_required' => '请先给该目标关联一个账户',
        'goal.nothing_to_transfer' => '该目标已存满，无需划拨',
        _ => '操作失败',
      });
      return;
    }
    showAppToast(context, g.autoTransfer ? '已关闭自动划拨' : '已开启自动划拨');
    ref.invalidateData.bumpRecurringMutated();
    _reload();
  }

  /// STORY-7.2 AC3：还债目标的提前还款测算。
  ///
  /// 「提前 N 个月还清、少付利息 ¥Z」由 `LoanAmortizationService` 派生，
  /// 依据的是关联贷款的真实参数与剩余本金，不写死任何数字。
  Future<void> _showPrepay(SavingsGoal g) async {
    final ctx = _debt[g.id];
    if (ctx == null) {
      showAppToast(context, '关联的贷款账户缺少参数，无法测算');
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
            title: Text('提前还款测算「${g.name}」'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (v) => setDlg(() => extraText = v),
                  decoration: const InputDecoration(
                      labelText: '每月额外还',
                      border: OutlineInputBorder(),
                      prefixText: '¥'),
                ),
                const SizedBox(height: Spacing.md),
                TextFormField(
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (v) => setDlg(() => lumpText = v),
                  decoration: const InputDecoration(
                      labelText: '一次性还本',
                      border: OutlineInputBorder(),
                      prefixText: '¥'),
                ),
                const SizedBox(height: Spacing.lg),
                Text(
                  hasInput
                      ? '可提前 ${r.monthsSaved} 个月还清，少付利息 ${formatAmountYuan(r.interestSavedCents)}'
                      : '基准剩余 ${r.baseline.months} 期、利息 ${formatAmountYuan(r.baseline.interestCents)}',
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
                child: const Text('关闭'),
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
            Text('新建储蓄目标', style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: Spacing.md),
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '名称', border: OutlineInputBorder())),
            const SizedBox(height: Spacing.md),
            TextField(
              controller: targetCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: '目标金额', border: OutlineInputBorder()),
            ),
            const SizedBox(height: Spacing.md),
            // 类型决定「关联账户」的候选集：储蓄选可用账户，还债选贷款账户
            PickerField(
              label: '目标类型',
              value: isDebt ? '还债目标' : '储蓄目标',
              onTap: () async {
                final picked = await showOptionPicker<String>(
                  context: ctx,
                  title: '目标类型',
                  current: isDebt ? 'debt' : 'savings',
                  options: const [
                    PickerOption(value: 'savings', label: '储蓄目标'),
                    PickerOption(value: 'debt', label: '还债目标'),
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
              label: isDebt ? '关联贷款' : '关联账户',
              value: () {
                final list = isDebt ? _loanAccounts : _accounts;
                for (final a in list) {
                  if (a.id == accountId) return a.name;
                }
                return '未选择';
              }(),
              onTap: () async {
                final list = isDebt ? _loanAccounts : _accounts;
                final picked = await showOptionPicker<String>(
                  context: ctx,
                  title: isDebt ? '关联贷款' : '关联账户',
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
              title: '截止日期',
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
                  showAppToast(context, '目标已创建');
                  _reload();
                }
              },
              child: const Text('保存'),
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
                  ? '已超支 ¥${formatAmount(-view.remainingCents, hide: false)}'
                  : '剩余 ¥${formatAmount(view.remainingCents, hide: false)} · 已用 $pct%',
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
              '目标已存 / 目标总额',
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
              _Split(label: '总进度', text: '$pct%'),
              const SizedBox(width: 28),
              _Split(label: '月需存入', text: formatAmountYuan(monthly)),
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
    final colors = context.colors;
    final g = view.goal;
    final monthly = view.monthlyRequiredCentsAt(now);
    final progress = view.progress.clamp(0.0, 1.0).toDouble();
    final remaining = (view.targetCents - view.savedCents).clamp(0, view.targetCents).toInt();
    final pct = (view.progress * 100).toStringAsFixed(0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.md),
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
                  '$pct% · 还差 ${formatAmountYuan(remaining)}',
                  style: TextStyle(fontSize: 12, color: colors.inkTertiary),
                ),
              ),
              Text('月存 ${formatAmountYuan(monthly)}', style: TextStyle(fontSize: 12, color: colors.inkSecondary)),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          Row(
            children: [
              // STORY-7.1：手动存入（还债目标不适用）
              if (!g.isDebt) ...[
                TextButton(onPressed: onDeposit, child: const Text('存入')),
                const SizedBox(width: Spacing.sm),
              ],
              // STORY-7.1 AC6：自动按月划拨（走统一周期引擎）
              if (!g.isDebt) ...[
                Text(
                  '自动按月划拨',
                  style: TextStyle(fontSize: 14, color: colors.inkSecondary),
                ),
                const Spacer(),
                Switch(value: g.autoTransfer, onChanged: (_) => onToggleAuto()),
              ],
              // STORY-7.2 AC3：还债目标可做提前还款测算
              if (g.isDebt && debt != null) ...[
                const Spacer(),
                TextButton(onPressed: onPrepay, child: const Text('提前还款测算')),
              ],
            ],
          ),
          // STORY-7.2 AC2：剩余期数 / 剩余利息 / 预计还清日
          if (g.isDebt && debt != null) ...[
            const SizedBox(height: Spacing.sm),
            Text(
              '剩余 ${debt!.progress.remainingMonths} 期 · '
              '剩余利息 ${formatAmountYuan(debt!.progress.remainingInterestCents)} · '
              '预计还清 ${debt!.progress.payoffDate == null ? '已结清' : '${debt!.progress.payoffDate!.year}-${debt!.progress.payoffDate!.month.toString().padLeft(2, '0')}'}',
              style: TextStyle(fontSize: 12, color: colors.inkTertiary),
            ),
          ],
          if (g.isDebt && debt == null)
            Padding(
              padding: const EdgeInsets.only(top: Spacing.sm),
              child: Text(
                '关联的贷款账户缺少本金/利率/期数，无法测算',
                style: TextStyle(fontSize: 12, color: colors.inkTertiary),
              ),
            ),
          // AC4：截止日已过而未达成时标记「未达成」，数据保留
          if (view.isOverdueAt(now))
            Padding(
              padding: const EdgeInsets.only(top: Spacing.xs),
              child: Text(
                '未达成（截止日已过）',
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
            plain: '把「一年一次的大额支出」拆成月存（保险费、旅行、年检）， 避免某个月突然被击穿。',
            parts: const [
              (true, '沉淀基金'),
              (false, '把「一年一次的大额支出」拆成月存（保险费、旅行、年检）， 避免某个月突然被击穿。'),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          _RichPara(
            plain: '目标里的钱 —— 否则你会以为自己很有钱。',
            parts: const [
              (false, '目标里的钱'),
              (true, '从「安全可花」基数中扣除'),
              (false, ' —— 否则你会以为自己很有钱。'),
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
