/// 储蓄目标列表（STORY-7.1）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plain/app/bootstrap.dart';
import 'package:plain/app/theme/app_colors.dart';
import 'package:plain/features/ledger/presentation/home_shell.dart';
import 'package:plain/app/theme/design_tokens.dart';
import 'package:plain/core/format/amount_formatter.dart';
import 'package:plain/core/refresh/data_invalidation.dart';
import 'package:plain/design_system/app_toast.dart';
import 'package:plain/domain/entities/savings_goal.dart';

class SavingsGoalsPage extends ConsumerStatefulWidget {
  const SavingsGoalsPage({super.key});

  @override
  ConsumerState<SavingsGoalsPage> createState() => _SavingsGoalsPageState();
}

class _SavingsGoalsPageState extends ConsumerState<SavingsGoalsPage> {
  List<SavingsGoal> _goals = const [];
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
    if (!mounted) return;
    setState(() {
      _goals = res.successOrNull ?? const [];
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final now = ref.read(appDependenciesProvider).clock.now();
    return Scaffold(
      appBar: AppBar(
        title: const Text('储蓄目标'),
        actions: [AddAppBarAction(tooltip: '新建目标', onPressed: _showCreateSheet)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _goals.isEmpty
              ? Center(
                  child: Text('还没有储蓄目标', style: TextStyle(color: context.colors.inkTertiary)),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(Spacing.lg),
                  itemCount: _goals.length,
                  separatorBuilder: (_, _) => const SizedBox(height: Spacing.sm),
                  itemBuilder: (context, i) {
                    final g = _goals[i];
                    final monthly = g.monthlyRequiredCentsAt(now);
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(Spacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    g.goalType == GoalType.debt
                                        ? '${g.name}（还债）'
                                        : g.name,
                                    style: const TextStyle(
                                        fontSize: 16, fontWeight: FontWeight.w600),
                                  ),
                                ),
                                if (g.isOverdueAt(now))
                                  Text('未达成',
                                      style: TextStyle(
                                          fontSize: 12, color: context.colors.expense)),
                                if (g.isAchieved)
                                  Text(g.goalType == GoalType.debt ? '已还清' : '已达成',
                                      style: TextStyle(
                                          fontSize: 12, color: context.colors.income)),
                              ],
                            ),
                            const SizedBox(height: Spacing.sm),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: g.progress,
                                minHeight: 8,
                                backgroundColor: context.colors.surfaceMuted,
                              ),
                            ),
                            const SizedBox(height: Spacing.sm),
                            Text(
                              g.goalType == GoalType.debt
                                  ? '${formatAmountYuan(g.savedCents)} / ${formatAmountYuan(g.targetCents)} 已还'
                                      '${g.remainingTerms == null ? '' : ' · 剩余 ${g.remainingTerms} 期'}'
                                  : '${formatAmountYuan(g.savedCents)} / ${formatAmountYuan(g.targetCents)}'
                                      ' · 每月需存 ${formatAmountYuan(monthly)}',
                              style: TextStyle(
                                  fontSize: 12, color: context.colors.inkSecondary),
                            ),
                            Row(
                              children: [
                                TextButton(
                                  onPressed: () => _showDeposit(g),
                                  child: const Text('存入'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Future<void> _showDeposit(SavingsGoal g) async {
    final ctrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('存入「${g.name}」'),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: '金额',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              final v = double.tryParse(ctrl.text.trim()) ?? 0;
              final cents = (v * 100).round();
              if (cents <= 0) return;
              final deps = ref.read(appDependenciesProvider);
              final r = await deps.savingsGoalRepository.deposit(
                goalId: g.id,
                amountCents: cents,
              );
              if (ctx.mounted) Navigator.pop(ctx);
              if (!mounted) return;
              if (r.isSuccess) {
                showAppToast(context, '已存入');
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

  Future<void> _showCreateSheet() async {
    final nameCtrl = TextEditingController();
    final targetCtrl = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: Spacing.lg,
          right: Spacing.lg,
          top: Spacing.lg,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + Spacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('新建储蓄目标', style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: Spacing.md),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: '名称', border: OutlineInputBorder()),
            ),
            const SizedBox(height: Spacing.md),
            TextField(
              controller: targetCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: '目标金额', border: OutlineInputBorder()),
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
                  dueAt: now.add(const Duration(days: 365)),
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
    );
    if (mounted) ref.invalidateData.bumpBudgetMutated();
  }
}

