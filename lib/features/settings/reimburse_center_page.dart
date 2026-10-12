/// 报销中心（STORY-1.8）：按状态分组聚合垫付账单。
/// AC1 待报销分组+合计 / AC5 放弃保留账单 / AC6 统计三项
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plain/app/bootstrap.dart';
import 'package:plain/app/theme/app_colors.dart';
import 'package:plain/app/theme/design_tokens.dart';
import 'package:plain/core/format/amount_formatter.dart';
import 'package:plain/core/refresh/data_invalidation.dart';
import 'package:plain/design_system/app_empty_state.dart';
import 'package:plain/design_system/app_toast.dart';
import 'package:plain/domain/entities/category.dart' as domain;
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/entities/ledger_entry.dart';
import 'package:plain/domain/services/reimburse_workflow.dart';
import 'package:plain/features/ledger/presentation/entry_detail_page.dart';

class ReimburseCenterPage extends ConsumerStatefulWidget {
  const ReimburseCenterPage({super.key});

  @override
  ConsumerState<ReimburseCenterPage> createState() => _ReimburseCenterPageState();
}

class _ReimburseCenterPageState extends ConsumerState<ReimburseCenterPage> {
  List<LedgerEntry> _entries = [];
  final Map<String, domain.Category> _categories = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final deps = ref.read(appDependenciesProvider);
    final page = await deps.ledgerRepository.listPage(limit: 500);
    final items = page.successOrNull?.items ?? const <LedgerEntry>[];
    final cats = await deps.categoryRepository.listAll();
    final catMap = {for (final c in cats.successOrNull ?? const <domain.Category>[]) c.id: c};
    if (!mounted) return;
    setState(() {
      _entries = items.where((e) => e.reimburseStatus.inFlow).toList();
      _categories.addAll(catMap);
      _loading = false;
    });
  }

  List<LedgerEntry> _byStatus(ReimburseStatus s) =>
      _entries.where((e) => e.reimburseStatus == s).toList();

  int _sumOf(List<LedgerEntry> list) =>
      list.fold(0, (sum, e) => sum + e.amount.cents);

  @override
  Widget build(BuildContext context) {
    // 写→bump→读：账单变更后自动刷新报销列表
    ref.listen(ledgerVersionProvider, (prev, next) {
      if (prev != next) _reload();
    });

    final pending = _byStatus(ReimburseStatus.pending);
    final submitted = _byStatus(ReimburseStatus.submitted);
    final partial = _byStatus(ReimburseStatus.partial);
    final reimbursed = _byStatus(ReimburseStatus.reimbursed);
    final totalPending = _sumOf(pending) + _sumOf(submitted) + _sumOf(partial);

    return Scaffold(
      appBar: AppBar(title: const Text('报销中心')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? const AppEmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: '还没有报销中的账单',
                  subtitle: '记账时勾选「需报销」即可归集到这里',
                )
              : ListView(
                  padding: const EdgeInsets.all(Spacing.lg),
                  children: [
                    // 统计卡
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(Spacing.xl),
                        child: Row(
                          children: [
                            _Stat(label: '累计垫付', value: _sumOf(pending) + _sumOf(submitted) + _sumOf(partial) + _sumOf(reimbursed)),
                            const SizedBox(width: Spacing.lg),
                            _Stat(label: '未回款', value: totalPending, highlight: true),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: Spacing.lg),
                    if (pending.isNotEmpty) ...[
                      _SectionHeader(title: '待报销', count: pending.length, amount: _sumOf(pending)),
                      ...pending.map(_EntryRow.new),
                      const SizedBox(height: Spacing.md),
                    ],
                    if (submitted.isNotEmpty) ...[
                      _SectionHeader(title: '已提交', count: submitted.length, amount: _sumOf(submitted)),
                      ...submitted.map(_EntryRow.new),
                      const SizedBox(height: Spacing.md),
                    ],
                    if (partial.isNotEmpty) ...[
                      _SectionHeader(title: '部分回款', count: partial.length, amount: _sumOf(partial)),
                      ...partial.map(_EntryRow.new),
                      const SizedBox(height: Spacing.md),
                    ],
                    if (reimbursed.isNotEmpty) ...[
                      _SectionHeader(title: '已回款', count: reimbursed.length, amount: _sumOf(reimbursed)),
                      ...reimbursed.map(_EntryRow.new),
                    ],
                  ],
                ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.highlight = false});
  final String label;
  final int value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: context.colors.inkTertiary)),
          const SizedBox(height: Spacing.xs),
          Text(
            formatAmount(value),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: highlight ? context.colors.accent : context.colors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.count, required this.amount});
  final String title;
  final int count;
  final int amount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: Row(
        children: [
          Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.colors.inkSecondary)),
          const SizedBox(width: Spacing.sm),
          Text('$count 笔', style: TextStyle(fontSize: 12, color: context.colors.inkTertiary)),
          const Spacer(),
          Text(formatAmount(amount), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: context.colors.accent)),
        ],
      ),
    );
  }
}

class _EntryRow extends ConsumerWidget {
  const _EntryRow(this.entry);
  final LedgerEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusLabel = switch (entry.reimburseStatus) {
      ReimburseStatus.pending => '待报销',
      ReimburseStatus.submitted => '已提交',
      ReimburseStatus.partial => '部分回款',
      ReimburseStatus.reimbursed => '已回款',
      _ => '',
    };
    final t = entry.occurredAt.toLocal();
    return Card(
      margin: const EdgeInsets.only(bottom: Spacing.xs),
      child: ListTile(
        dense: true,
        onTap: () => Navigator.push<void>(
          context,
          MaterialPageRoute(builder: (_) => EntryDetailPage(entryId: entry.id)),
        ),
        title: Text(
          entry.note?.isNotEmpty == true ? entry.note! : '账单',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14),
        ),
        subtitle: Text(
          '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} · $statusLabel',
          style: TextStyle(fontSize: 11, color: context.colors.inkTertiary),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(formatAmount(entry.amount.cents), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: context.colors.expense)),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 18),
              onSelected: (v) => _action(context, ref, v),
              itemBuilder: (_) => [
                if (entry.reimburseStatus == ReimburseStatus.pending)
                  const PopupMenuItem(value: 'submit', child: Text('标记已提交')),
                if (entry.reimburseStatus == ReimburseStatus.submitted)
                  const PopupMenuItem(value: 'reimbursed', child: Text('标记已回款')),
                if (entry.reimburseStatus == ReimburseStatus.partial)
                  const PopupMenuItem(value: 'reimbursed', child: Text('标记已回款')),
                const PopupMenuItem(value: 'abandon', child: Text('放弃报销')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _action(BuildContext context, WidgetRef ref, String action) async {
    final deps = ref.read(appDependenciesProvider);
    final workflow = ReimburseWorkflow(repository: deps.ledgerRepository, now: () => deps.clock.now());
    final result = switch (action) {
      'submit' => await workflow.submit(entry),
      'reimbursed' => await workflow.markReimbursed(entry),
      'abandon' => await workflow.abandon(entry),
      _ => null,
    };
    if (result == null) return;
    if (result.isSuccess) {
      ref.invalidateData.bumpEntryMutated();
      if (context.mounted) {
        showAppToast(context, action == 'abandon' ? '已放弃报销' : '已更新');
      }
    } else if (context.mounted) {
      showAppToast(context, '操作失败');
    }
  }
}
