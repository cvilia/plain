/// Entry detail page (SP-1-02). See PRD STORY-1.2.
library;

import 'package:plain/app/theme/app_colors.dart';
import 'package:plain/core/time/date_format.dart';
import 'package:flutter/material.dart';
import 'package:plain/design_system/app_toast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:plain/app/bootstrap.dart';
import 'package:plain/app/theme/design_tokens.dart';
import 'package:plain/core/constants/app_constants.dart';
import 'package:plain/core/format/amount_formatter.dart';
import 'package:plain/core/refresh/data_invalidation.dart';
import 'package:plain/domain/entities/category.dart' as domain;
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/entities/ledger_entry.dart';
import 'package:plain/domain/usecases/split_usecases.dart';


class _DetailData {
  const _DetailData({required this.entry, required this.category, this.accountName});
  final LedgerEntry entry;
  final domain.Category? category;
  final String? accountName;
}

final _detailProvider = FutureProvider.family<_DetailData, String>((ref, entryId) async {
  ref.watch(ledgerVersionProvider);
  ref.watch(categoriesVersionProvider);
  ref.watch(accountsVersionProvider);
  final deps = ref.watch(appDependenciesProvider);
  final entryResult = await deps.ledgerRepository.getById(entryId);
  final entry = entryResult.successOrNull;
  if (entry == null) {
    throw StateError('entry.not_found');
  }
  domain.Category? cat;
  if (entry.categoryId != null) {
    final catResult = await deps.categoryRepository.getById(entry.categoryId!);
    cat = catResult.successOrNull;
  }
  // 归属账户
  String? accountName;
  if (entry.accountId != null) {
    final accResult = await deps.accountRepository.getById(entry.accountId!);
    accountName = accResult.successOrNull?.name;
  }
  return _DetailData(entry: entry, category: cat, accountName: accountName);
});

class EntryDetailPage extends ConsumerStatefulWidget {
  const EntryDetailPage({super.key, required this.entryId});
  final String entryId;

  @override
  ConsumerState<EntryDetailPage> createState() => _EntryDetailPageState();
}

class _EntryDetailPageState extends ConsumerState<EntryDetailPage> {
  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_detailProvider(widget.entryId));
    final loading = async.isLoading;
    final entry = async.value?.entry;
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (entry == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('详情')),
        body: const Center(child: Text('账单不存在')),
      );
    }

    final isExpense = entry.type == EntryType.expense;
    final isIncome = entry.type == EntryType.income;
    final amountColor = isExpense ? context.colors.expense : isIncome ? context.colors.income : context.colors.transfer;
    final prefix = isExpense ? '-' : isIncome ? '+' : '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('详情'),
        actions: [
          if (entry.splitRole == SplitRole.normal &&
              (isExpense || isIncome))
            TextButton(
              onPressed: () => _showSplitSheet(context, entry),
              child: const Text('拆分'),
            ),
          if (entry.isSplitParent)
            TextButton(
              onPressed: () => _mergeSplit(context, entry),
              child: const Text('合并'),
            ),
          TextButton(onPressed: () => _edit(context), child: const Text('编辑')),
          IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _confirmDelete(context)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(Spacing.lg),
        children: [
          Center(
            child: Column(
              children: [
                Text(
                  '$prefix${formatAmount(entry.amount.cents, hide: ref.watch(hideAmountsProvider))}',
                  style: TextStyle(fontSize: 40, fontWeight: FontWeight.w600, color: amountColor),
                ),
                const SizedBox(height: Spacing.sm),
                Text(_typeLabel(entry.type), style: TextStyle(fontSize: 14, color: amountColor)),
              ],
            ),
          ),
          const SizedBox(height: Spacing.xl),
          _DetailRow(icon: Icons.category_outlined, label: '分类', value: async.value?.category?.name ?? '未分类'),
          _DetailRow(icon: Icons.account_balance_wallet_outlined, label: '归属账户', value: async.value?.accountName ?? '未指定账户'),
          // 报销状态：可点击切换（none ↔ pending）
          _ReimburseToggleRow(entry: entry),
          _DetailRow(icon: Icons.calendar_today_outlined, label: '日期', value: formatDate(entry.occurredAt)),
          if (entry.note != null && entry.note!.isNotEmpty)
            _DetailRow(icon: Icons.edit_note_outlined, label: '备注', value: entry.note!),
          _DetailRow(icon: Icons.source_outlined, label: '来源', value: _sourceLabel(entry.source)),
          if (entry.splitRole != SplitRole.normal)
            _DetailRow(
              icon: Icons.call_split,
              label: '分割',
              value: entry.isSplitParent ? '父笔（不进分类统计）' : '子笔',
            ),
          _DetailRow(icon: Icons.access_time_outlined, label: '创建时间', value: formatDateTime(entry.createdAt)),
          _DetailRow(icon: Icons.update_outlined, label: '更新时间', value: formatDateTime(entry.updatedAt)),
        ],
      ),
    );
  }

  void _edit(BuildContext context) {
    context.push('/entry/edit/${widget.entryId}');
  }

  Future<void> _showSplitSheet(BuildContext context, LedgerEntry entry) async {
    final rows = List.generate(SplitRules.minChildren, (_) {
      return (amountCtrl: TextEditingController(), catCtrl: TextEditingController());
    });

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
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
              Text(
                '拆分 ${formatAmount(entry.amount.cents)}（合计需对平）',
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
              const SizedBox(height: Spacing.md),
              for (var i = 0; i < rows.length; i++) ...[
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: rows[i].amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: '子笔 ${i + 1} 金额',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: Spacing.sm),
                  Expanded(
                    child: TextField(
                      controller: rows[i].catCtrl,
                      decoration: const InputDecoration(
                        labelText: '分类 ID',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: Spacing.sm),
              ],
              Row(children: [
                TextButton.icon(
                  onPressed: rows.length >= SplitRules.maxChildren
                      ? null
                      : () => setSheet(() => rows.add((
                            amountCtrl: TextEditingController(),
                            catCtrl: TextEditingController(),
                          ))),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('加子笔'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () async {
                    final items = <SplitItem>[];
                    for (final r in rows) {
                      final a = r.amountCtrl.text.trim();
                      if (a.isEmpty) continue;
                      final cents = (double.tryParse(a) ?? 0) * 100;
                      items.add(SplitItem(
                        amountCents: cents.round(),
                        categoryId: r.catCtrl.text.trim().isEmpty
                            ? null
                            : r.catCtrl.text.trim(),
                      ));
                    }
                    if (items.length < SplitRules.minChildren) return;
                    final deps = ref.read(appDependenciesProvider);
                    final result = await SplitEntryUseCase(
                      repository: deps.ledgerRepository,
                      clock: deps.clock,
                      idGen: deps.idGen,
                    )(parent: entry, items: items);
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (!mounted) return;
                    result.when(
                      success: (_) {
                        ref.invalidateData.bumpEntryMutated();
                        showAppToast(context, '已拆分');
                        setState(() {});
                      },
                      failure: (f) => showAppToast(context, '拆分失败: ${f.code}'),
                    );
                  },
                  child: const Text('保存拆分'),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _mergeSplit(BuildContext context, LedgerEntry parent) async {
    final deps = ref.read(appDependenciesProvider);
    final result = await MergeSplitUseCase(
      repository: deps.ledgerRepository,
      clock: deps.clock,
    )(parent: parent);
    if (!mounted) return;
    result.when(
      success: (_) {
        ref.invalidateData.bumpEntryMutated();
        showAppToast(context, '已合并回父笔，请补充分类');
        setState(() {});
      },
      failure: (f) => showAppToast(context, '合并失败: ${f.code}'),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除账单'),
        content: const Text('删除后不可恢复，确定删除？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final deps = ref.read(appDependenciesProvider);
              final result = await deps.deleteEntry(widget.entryId);
              if (result.isSuccess && context.mounted) {
                ref.invalidateData.bumpEntryMutated();
                Navigator.pop(context);
                showAppToast(context, '已删除');
              }
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  String _typeLabel(EntryType type) => switch (type) {
        EntryType.expense => '支出',
        EntryType.income => '收入',
        EntryType.transfer => '转账',
        _ => type.wire,
      };

  String _sourceLabel(EntrySource source) => switch (source) {
        EntrySource.manual => '手动',
        EntrySource.reconcile => '对账',
        EntrySource.import => '导入',
        EntrySource.recurring => '周期',
        _ => source.wire,
      };


}

class _ReimburseToggleRow extends ConsumerWidget {
  const _ReimburseToggleRow({required this.entry});
  final LedgerEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label = switch (entry.reimburseStatus) {
      ReimburseStatus.none => '不报销',
      ReimburseStatus.pending => '待报销',
      ReimburseStatus.submitted => '已提交',
      ReimburseStatus.partial => '部分回款',
      ReimburseStatus.reimbursed => '已回款',
      ReimburseStatus.abandoned => '已放弃',
    };
    final isOn = entry.reimburseStatus == ReimburseStatus.pending;
    return InkWell(
      onTap: () async {
        final deps = ref.read(appDependenciesProvider);
        final next = isOn ? ReimburseStatus.none : ReimburseStatus.pending;
        final updated = entry.copyWith(
          reimburseStatus: next,
          updatedAt: deps.clock.now(),
          revision: entry.revision + 1,
          baseRevision: entry.revision,
        );
        await deps.ledgerRepository.update(updated);
        ref.invalidateData.bumpEntryMutated();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Spacing.md),
        child: Row(
          children: [
            Icon(Icons.receipt_long_outlined, size: 20, color: context.colors.inkTertiary),
            const SizedBox(width: Spacing.md),
            SizedBox(width: 64, child: Text('报销', style: TextStyle(fontSize: 14, color: context.colors.inkSecondary))),
            const SizedBox(width: Spacing.md),
            Expanded(child: Text(label, style: TextStyle(fontSize: 14, color: isOn ? context.colors.accent : context.colors.ink))),
            Switch(
              value: isOn,
              onChanged: (_) {
                final deps = ref.read(appDependenciesProvider);
                final next = isOn ? ReimburseStatus.none : ReimburseStatus.pending;
                final updated = entry.copyWith(
                  reimburseStatus: next,
                  updatedAt: deps.clock.now(),
                  revision: entry.revision + 1,
                  baseRevision: entry.revision,
                );
                deps.ledgerRepository.update(updated);
                ref.invalidateData.bumpEntryMutated();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: context.colors.inkTertiary),
          const SizedBox(width: Spacing.md),
          SizedBox(
            width: 64,
            child: Text(label, style: TextStyle(fontSize: 14, color: context.colors.inkSecondary)),
          ),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.left,
              style: TextStyle(fontSize: 14, color: context.colors.ink),
            ),
          ),
        ],
      ),
    );
  }
}
