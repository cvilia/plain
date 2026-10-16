/// 报销中心（STORY-1.8 / SP-1-06）：按状态分组聚合垫付账单。
/// AC1 待报销分组+合计 / AC5 放弃保留账单 / AC6 统计三项
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plain/app/bootstrap.dart';
import 'package:plain/app/theme/app_colors.dart';
import 'package:plain/app/theme/design_tokens.dart';
import 'package:plain/core/refresh/data_invalidation.dart';
import 'package:plain/design_system/amount_display.dart';
import 'package:plain/design_system/app_empty_state.dart';
import 'package:plain/design_system/app_toast.dart';
import 'package:plain/design_system/plain_icons_v3.dart';
import 'package:plain/design_system/plain_ui.dart';
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
    ref.listen(ledgerVersionProvider, (prev, next) {
      if (prev != next) _reload();
    });

    final pending = _byStatus(ReimburseStatus.pending);
    final submitted = _byStatus(ReimburseStatus.submitted) + _byStatus(ReimburseStatus.partial);
    final arrived = _byStatus(ReimburseStatus.reimbursed);
    final totalPending = _sumOf(pending) + _sumOf(submitted);

    return Scaffold(
      appBar: const PlainTopBar(title: '报销中心', showBack: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(Spacing.lg),
              children: [
                _Hero(pendingCount: pending.length, submittedCount: submitted.length, totalPending: totalPending),
                if (_entries.isEmpty)
                  AppEmptyState(
                    icon: PlainIconData.receipt,
                    title: '还没有报销账单',
                    subtitle: '在账单详情里把一笔支出标为「待报销」',
                  )
                else ...[
                  if (pending.isNotEmpty) ...[
                    PlainEyebrow('待报销 · ${pending.length} 笔'),
                    PlainPanel(children: [for (final e in pending) _EntryRow(entry: e, categories: _categories)]),
                    const SizedBox(height: Spacing.md),
                  ],
                  if (submitted.isNotEmpty) ...[
                    PlainEyebrow('已提交 · ${submitted.length} 笔'),
                    PlainPanel(children: [for (final e in submitted) _EntryRow(entry: e, categories: _categories)]),
                    const SizedBox(height: Spacing.md),
                  ],
                  if (arrived.isNotEmpty) ...[
                    PlainEyebrow('已到账 · ${arrived.length} 笔'),
                    PlainPanel(children: [for (final e in arrived) _EntryRow(entry: e, categories: _categories)]),
                    const SizedBox(height: Spacing.md),
                  ],
                ],
                _NotePanel(),
              ],
            ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.pendingCount, required this.submittedCount, required this.totalPending});
  final int pendingCount;
  final int submittedCount;
  final int totalPending;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(height: 1, thickness: 1, color: colors.border),
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8, left: 2),
            child: Text(
              '待收回金额',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.08 * 12, color: colors.inkTertiary),
            ),
          ),
          // 设计稿 `.amt.xl`：cur 21.08 muted + int/pnt 34 w700 ink + dec 21.08 w600 muted，
          // 四段共用 `-0.68px` tracking、行盒 39.44。原来这里手写三段式，
          // 字重/字距/行高/派生段字号全都不符，且与 AmountDisplay 重复实现。
          AmountDisplay(cents: totalPending, fontSize: 34),
          const SizedBox(height: 16),
          Row(
            children: [
              _Split(label: '待报销', text: '$pendingCount 笔'),
              const SizedBox(width: 28),
              _Split(label: '已提交', text: '$submittedCount 笔'),
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

class _EntryRow extends ConsumerWidget {
  const _EntryRow({required this.entry, required this.categories});
  final LedgerEntry entry;
  final Map<String, domain.Category> categories;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final t = entry.occurredAt.toLocal();
    final cat = categories[entry.categoryId]?.name ?? '';
    final dateStr = '${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
    final note = entry.note?.isNotEmpty == true ? entry.note! : '';
    final label = cat.isNotEmpty && note.isNotEmpty
        ? '$dateStr $cat · $note'
        : cat.isNotEmpty
            ? '$dateStr $cat'
            : note.isNotEmpty
                ? '$dateStr $note'
                : dateStr;
    return InkWell(
      onTap: () => Navigator.push<void>(
        context,
        MaterialPageRoute(builder: (_) => EntryDetailPage(entryId: entry.id)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: SizedBox(
          height: 38,
          child: Row(
            children: [
              Expanded(child: Text(label, style: TextStyle(fontSize: 14, color: colors.inkTertiary), maxLines: 1, overflow: TextOverflow.ellipsis)),
              AmountDisplay(cents: entry.amount.cents, fontSize: 15),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                icon: const PlainIcon(PlainIconData.moreVertical, size: 18),
                onSelected: (v) => _action(context, ref, v),
                itemBuilder: (_) => [
                  if (entry.reimburseStatus == ReimburseStatus.pending)
                    const PopupMenuItem(value: 'submit', child: Text('标记已提交')),
                  if (entry.reimburseStatus == ReimburseStatus.submitted || entry.reimburseStatus == ReimburseStatus.partial)
                    const PopupMenuItem(value: 'reimbursed', child: Text('标记已到账')),
                  const PopupMenuItem(value: 'abandon', child: Text('放弃报销')),
                ],
              ),
            ],
          ),
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
            plain: '报销到账时系统自动生成一笔等额收入并 —— 净效果为 0， 不会把报销算成额外收入。',
            parts: const [
              (false, '报销到账时系统自动生成一笔等额收入并'),
              (true, '冲销原支出'),
              (false, ' —— 净效果为 0， 不会把报销算成额外收入。'),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          _RichPara(
            plain: '支出统计中该笔（体现真实消费）， 到账收入标记为「报销回款」，不计入收入口径。',
            parts: const [
              (false, '支出统计中该笔'),
              (true, '始终保留'),
              (false, '（体现真实消费）， 到账收入标记为「报销回款」，不计入收入口径。'),
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
