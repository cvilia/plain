/// Entry detail page (SP-1-02). See PRD STORY-1.2.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:plain/app/bootstrap.dart';
import 'package:plain/app/theme/design_tokens.dart';
import 'package:plain/core/constants/app_constants.dart';
import 'package:plain/data/data_freshness.dart';
import 'package:plain/domain/entities/category.dart' as domain;
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/entities/ledger_entry.dart';
import 'package:plain/features/ledger/controllers/flow_list_controller.dart';

class EntryDetailPage extends ConsumerStatefulWidget {
  const EntryDetailPage({super.key, required this.entryId});
  final String entryId;

  @override
  ConsumerState<EntryDetailPage> createState() => _EntryDetailPageState();
}

class _EntryDetailPageState extends ConsumerState<EntryDetailPage> {
  LedgerEntry? _entry;
  domain.Category? _category;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final deps = ref.read(appDependenciesProvider);
    final entryResult = await deps.ledgerRepository.getById(widget.entryId);
    final entry = entryResult.successOrNull;
    if (entry == null) {
      setState(() => _loading = false);
      return;
    }
    domain.Category? cat;
    if (entry.categoryId != null) {
      final catResult = await deps.categoryRepository.getById(entry.categoryId!);
      cat = catResult.successOrNull;
    }
    setState(() {
      _entry = entry;
      _category = cat;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final entry = _entry;
    if (entry == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('详情')),
        body: const Center(child: Text('账单不存在')),
      );
    }

    final isExpense = entry.type == EntryType.expense;
    final isIncome = entry.type == EntryType.income;
    final amountColor = isExpense ? BrandColors.expense : isIncome ? BrandColors.income : BrandColors.transfer;
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
                  '$prefix${(entry.amount.cents / 100).toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 40, fontWeight: FontWeight.w600, color: amountColor),
                ),
                const SizedBox(height: Spacing.sm),
                Text(_typeLabel(entry.type), style: TextStyle(fontSize: 14, color: amountColor)),
              ],
            ),
          ),
          const SizedBox(height: Spacing.xl),
          _DetailRow(icon: Icons.category_outlined, label: '分类', value: _category?.name ?? '未分类'),
          _DetailRow(icon: Icons.calendar_today_outlined, label: '日期', value: _formatDate(entry.occurredAt)),
          if (entry.note != null && entry.note!.isNotEmpty)
            _DetailRow(icon: Icons.edit_note_outlined, label: '备注', value: entry.note!),
          _DetailRow(icon: Icons.source_outlined, label: '来源', value: _sourceLabel(entry.source)),
          _DetailRow(icon: Icons.access_time_outlined, label: '创建时间', value: _formatDateTime(entry.createdAt)),
          _DetailRow(icon: Icons.update_outlined, label: '更新时间', value: _formatDateTime(entry.updatedAt)),
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
                ref.read(dataFreshnessProvider.notifier).bump();
                ref.read(flowListControllerProvider.notifier).refresh();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: const Text('已删除'), duration: UiDurations.undoWindow),
                );
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

  String _formatDate(DateTime at) {
    final local = at.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime at) => _formatDate(at);
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
          Icon(icon, size: 20, color: BrandColors.inkTertiary),
          const SizedBox(width: Spacing.md),
          Text(label, style: TextStyle(fontSize: 14, color: BrandColors.inkSecondary)),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 14, color: BrandColors.ink),
            ),
          ),
        ],
      ),
    );
  }
}
