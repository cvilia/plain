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
import 'package:plain/core/format/amount_formatter.dart';
import 'package:plain/core/refresh/data_invalidation.dart';
import 'package:plain/domain/entities/category.dart' as domain;
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/entities/ledger_entry.dart';


class _DetailData {
  const _DetailData({required this.entry, required this.category});
  final LedgerEntry entry;
  final domain.Category? category;
}

final _detailProvider = FutureProvider.family<_DetailData, String>((ref, entryId) async {
  ref.watch(ledgerVersionProvider);
  ref.watch(categoriesVersionProvider);
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
  return _DetailData(entry: entry, category: cat);
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
          _DetailRow(icon: Icons.calendar_today_outlined, label: '日期', value: formatDateTime(entry.occurredAt)),
          if (entry.note != null && entry.note!.isNotEmpty)
            _DetailRow(icon: Icons.edit_note_outlined, label: '备注', value: entry.note!),
          _DetailRow(icon: Icons.source_outlined, label: '来源', value: _sourceLabel(entry.source)),
          _DetailRow(icon: Icons.access_time_outlined, label: '创建时间', value: formatDateTime(entry.createdAt)),
          _DetailRow(icon: Icons.update_outlined, label: '更新时间', value: formatDateTime(entry.updatedAt)),
        ],
      ),
    );
  }

  void _edit(BuildContext context) {
    context.push('/entry/edit/${widget.entryId}');
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
        children: [
          Icon(icon, size: 20, color: context.colors.inkTertiary),
          const SizedBox(width: Spacing.md),
          Text(label, style: TextStyle(fontSize: 14, color: context.colors.inkSecondary)),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 14, color: context.colors.ink),
            ),
          ),
        ],
      ),
    );
  }
}
