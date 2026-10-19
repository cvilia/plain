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
import 'package:plain/app/l10n/app_strings.dart';
import 'package:plain/app/l10n/strings_accounts.dart';
import 'package:plain/app/l10n/strings_core.dart';
import 'package:plain/app/l10n/strings_domain.dart';
import 'package:plain/app/l10n/strings_settings_b.dart';

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
    final s = AppStrings.of(context);
    ref.listen(ledgerVersionProvider, (prev, next) {
      if (prev != next) _reload();
    });

    final pending = _byStatus(ReimburseStatus.pending);
    final submitted = _byStatus(ReimburseStatus.submitted) + _byStatus(ReimburseStatus.partial);
    final arrived = _byStatus(ReimburseStatus.reimbursed);
    final totalPending = _sumOf(pending) + _sumOf(submitted);

    return Scaffold(
      appBar: PlainTopBar(title: s.reimburseCenter, showBack: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(Spacing.lg),
              children: [
                _Hero(pendingCount: pending.length, submittedCount: submitted.length, totalPending: totalPending),
                if (_entries.isEmpty)
                  AppEmptyState(
                    icon: PlainIconData.receipt,
                    title: s.noReimburseEntries,
                    subtitle: s.noReimburseEntriesHint,
                  )
                else ...[
                  if (pending.isNotEmpty) ...[
                    PlainEyebrow(s.reimburseGroupPending(pending.length)),
                    PlainPanel(children: [for (final e in pending) _EntryRow(entry: e, categories: _categories)]),
                    const SizedBox(height: Spacing.md),
                  ],
                  if (submitted.isNotEmpty) ...[
                    PlainEyebrow(s.reimburseGroupSubmitted(submitted.length)),
                    PlainPanel(children: [for (final e in submitted) _EntryRow(entry: e, categories: _categories)]),
                    const SizedBox(height: Spacing.md),
                  ],
                  if (arrived.isNotEmpty) ...[
                    PlainEyebrow(s.reimburseGroupArrived(arrived.length)),
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
    final s = AppStrings.of(context);
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
              s.pendingRecoverAmount,
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
              _Split(label: s.homeCardPendingReimburse, text: s.entriesCount(pendingCount)),
              const SizedBox(width: 28),
              _Split(label: s.reimburseSubmitted, text: s.entriesCount(submittedCount)),
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
    final s = AppStrings.of(context);
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
      onTap: () => Navigator.of(context, rootNavigator: true).push<void>(
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
                    PopupMenuItem(value: 'submit', child: Text(s.markSubmitted)),
                  if (entry.reimburseStatus == ReimburseStatus.submitted || entry.reimburseStatus == ReimburseStatus.partial)
                    PopupMenuItem(value: 'reimbursed', child: Text(s.markArrived)),
                  PopupMenuItem(value: 'abandon', child: Text(s.abandonReimburse)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _action(BuildContext context, WidgetRef ref, String action) async {
    final s = AppStrings.of(context);
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
        showAppToast(context, action == 'abandon' ? s.reimburseAbandonedToast : s.updatedToast);
      }
    } else if (context.mounted) {
      showAppToast(context, s.operationFailed);
    }
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
            plain: s.reimburseNote1Plain,
            parts: [
              (false, s.reimburseNote1A),
              (true, s.reimburseNote1B),
              (false, s.reimburseNote1C),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          _RichPara(
            plain: s.reimburseNote2Plain,
            parts: [
              (false, s.reimburseNote2A),
              (true, s.reimburseNote2B),
              (false, s.reimburseNote2C),
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
