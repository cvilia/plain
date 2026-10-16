/// Entry detail page (SP-1-02). See PRD STORY-1.2.
library;

import 'package:plain/app/theme/app_colors.dart';
import 'package:plain/core/time/date_format.dart';
import 'package:flutter/material.dart';
import 'package:plain/design_system/amount_display.dart';
import 'package:plain/design_system/app_toast.dart';
import 'package:plain/design_system/plain_icons_v3.dart';
import 'package:plain/design_system/plain_ui.dart';
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
import 'package:plain/features/ledger/presentation/entry_attachments_section.dart';
import 'package:plain/features/ledger/presentation/member_write_guard.dart';
import 'package:plain/features/ledger/presentation/entry_participants_row.dart';


class _DetailData {
  const _DetailData({
    required this.entry,
    required this.category,
    this.accountName,
    this.accountCurrency,
  });
  final LedgerEntry entry;
  final domain.Category? category;
  final String? accountName;

  /// STORY-9.3：账户币种，用于「原币 / 本位币」双显示。
  final String? accountCurrency;
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
  String? accountCurrency;
  if (entry.accountId != null) {
    final accResult = await deps.accountRepository.getById(entry.accountId!);
    accountName = accResult.successOrNull?.name;
    accountCurrency = accResult.successOrNull?.currency;
  }
  return _DetailData(
    entry: entry,
    category: cat,
    accountName: accountName,
    accountCurrency: accountCurrency,
  );
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
        appBar: PlainTopBar(title: '详情', showBack: true),
        body: const Center(child: Text('账单不存在')),
      );
    }

    final isExpense = entry.type == EntryType.expense;
    final isIncome = entry.type == EntryType.income;
    final amountColor = isExpense ? context.colors.expense : isIncome ? context.colors.income : context.colors.transfer;

    return Scaffold(
      appBar: PlainTopBar(
        title: '账单详情',
        showBack: true,
        actions: [
          if (entry.splitRole == SplitRole.normal &&
              (isExpense || isIncome))
            Material(
              color: const Color(0x00000000),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () => _showSplitSheet(context, entry),
                borderRadius: BorderRadius.circular(12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text('拆分', style: TextStyle(fontSize: 14, color: context.colors.primary)),
                  ),
                ),
              ),
            ),
          if (entry.isSplitParent)
            Material(
              color: const Color(0x00000000),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () => _mergeSplit(context, entry),
                borderRadius: BorderRadius.circular(12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text('合并', style: TextStyle(fontSize: 14, color: context.colors.primary)),
                  ),
                ),
              ),
            ),
          Material(
            color: const Color(0x00000000),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () => _edit(context),
              borderRadius: BorderRadius.circular(12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text('编辑', style: TextStyle(fontSize: 14, color: context.colors.primary)),
                ),
              ),
            ),
          ),
          Material(
            color: const Color(0x00000000),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () => _confirmDelete(context),
              borderRadius: BorderRadius.circular(12),
              child: const SizedBox(
                width: 44,
                height: 44,
                child: PlainIcon(PlainIconData.delete, size: 20),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // Quiet Ledger: 金额是唯一主角，无卡片
          Center(
            child: Column(
              children: [
                Text(
                  '金额',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.colors.inkTertiary,
                  ),
                ),
                const SizedBox(height: 12),
                AmountDisplay(
                  cents: isExpense ? -entry.amount.cents : entry.amount.cents,
                  fontSize: 34,
                  showSign: true,
                  isExpense: isExpense,
                  isIncome: isIncome,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CategoryDot(color: amountColor),
                    const SizedBox(width: 8),
                    Text(
                      '${async.value?.category?.name ?? '未分类'} · ${async.value?.accountName ?? '招行储蓄卡'}',
                      style: TextStyle(fontSize: 14, color: context.colors.inkSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          _DetailRow(label: '分类', value: async.value?.category?.name ?? '未分类'),
          _DetailRow(label: '账户', value: async.value?.accountName ?? '招行储蓄卡'),
          // STORY-9.3：原币 / 本位币双显示（同币种时这里不出现）
          if (entry.originalAmountCents != null)
            _DetailRow(
              label: '原币金额',
              value: _dualCurrencyLabel(entry, async.value?.accountCurrency),
            ),
          if (entry.exchangeRate != null)
            _DetailRow(label: '锁定汇率', value: _rateLabel(entry.exchangeRate!)),
          // 报销状态：可点击切换（none ↔ pending）
          _ReimburseToggleRow(entry: entry),
          // G-2：「不计入收支」只对手动录入的普通收支开放
          if (entry.canMarkExcluded) _ExcludeFromStatsToggleRow(entry: entry),
          // STORY-8.2 AC5：AA 分摊（标记参与人自动平均分摊）
          if (isExpense || isIncome)
            EntryParticipantsRow(entryId: widget.entryId, amountCents: entry.amount.cents),
          _DetailRow(label: '日期', value: formatDate(entry.occurredAt)),
          if (entry.note != null && entry.note!.isNotEmpty)
            _DetailRow(label: '备注', value: entry.note!),
          _DetailRow(label: '来源', value: _sourceLabel(entry.source)),
          if (entry.splitRole != SplitRole.normal)
            _DetailRow(
              label: '分割',
              value: entry.isSplitParent ? '父笔（不进分类统计）' : '子笔',
            ),
          _DetailRow(label: '创建时间', value: formatDateTime(entry.createdAt)),
          _DetailRow(label: '更新时间', value: formatDateTime(entry.updatedAt)),
          const SizedBox(height: Spacing.md),
          // STORY-1.5：附件（详情页与编辑态都可增删）
          EntryAttachmentsSection(entryId: widget.entryId),
          const SizedBox(height: 16),
          // ── 危险区 ──
          PlainDangerButton(
            label: '删除这笔账单',
            onPressed: () => _confirmDelete(context),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              '删除后不可恢复',
              style: TextStyle(fontSize: 12, color: context.colors.inkFaint),
            ),
          ),
        ],
      ),
    );
  }

  String _sourceLabel(EntrySource source) => switch (source) {
        EntrySource.manual => '手动录入',
        EntrySource.reconcile => '对账',
        EntrySource.import => '导入',
        EntrySource.recurring => '周期',
        _ => source.wire,
      };

  /// STORY-9.3 AC1：`$100.00 ≈ ¥720.00`（本位币金额是库里的 amount）。
  ///
  /// 统一走 `formatDualCurrency`：自己拼字符串会丢掉千分位，还多一份重复实现。
  static String _dualCurrencyLabel(LedgerEntry entry, String? accountCurrency) =>
      formatDualCurrency(
        originalCents: entry.originalAmountCents!,
        convertedCents: entry.amount.cents,
        fromCurrency: accountCurrency ?? MoneyRules.defaultCurrency,
        toCurrency: entry.currency,
      );

  /// 汇率展示：去掉无意义的尾随零（7.200000 → 7.2）
  static String _rateLabel(double rate) {
    var s = rate.toStringAsFixed(6);
    while (s.contains('.') && s.endsWith('0')) {
      s = s.substring(0, s.length - 1);
    }
    if (s.endsWith('.')) s = s.substring(0, s.length - 1);
    return s;
  }

  void _edit(BuildContext context) {
    context.push('/entry/edit/${widget.entryId}');
  }

  Future<void> _showSplitSheet(BuildContext context, LedgerEntry entry) async {
    // STORY-8.2 AC2：拆分会产生子笔（= 写账单），只读成员不得做
    if (!await guardCanWriteLedger(context, ref)) return;
    if (!context.mounted) return;
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
            bottom: MediaQuery.viewInsetsOf(ctx).bottom + Spacing.lg,
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
                  icon: const PlainIcon(PlainIconData.plus, size: 18),
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
    // STORY-8.2 AC2：合并会改写账单，只读成员不得做
    if (!await guardCanWriteLedger(context, ref)) return;
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
        title: const Text('删除这笔账单'),
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

  
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: colors.divider, width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: colors.inkTertiary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: colors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// G-2：手动标记「不计入收支」。
///
/// 开启后该笔不进收支合计、分类统计与预算，**但仍计入账户余额**——它是一笔
/// 真实发生的账单。只有手动录入的普通收支可改（[LedgerEntry.canMarkExcluded]），
/// 对账调整/转账/借贷/拆分子笔的计入口径由 G-2 定死。
class _ExcludeFromStatsToggleRow extends ConsumerWidget {
  const _ExcludeFromStatsToggleRow({required this.entry});
  final LedgerEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOn = entry.excludeFromStats;
    Future<void> toggle() async {
      final deps = ref.read(appDependenciesProvider);
      final updated = entry.copyWith(
        excludeFromStats: !isOn,
        updatedAt: deps.clock.now(),
        revision: entry.revision + 1,
        baseRevision: entry.revision,
      );
      await deps.ledgerRepository.update(updated);
      ref.invalidateData.bumpEntryMutated();
    }

    return InkWell(
      onTap: toggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Spacing.md),
        child: Row(
          children: [
            PlainIcon(
              PlainIconData.eyeOff,
              size: 20,
              color: context.colors.inkTertiary,
            ),
            const SizedBox(width: Spacing.md),
            SizedBox(
              width: 64,
              child: Text('收支',
                  style: TextStyle(fontSize: 14, color: context.colors.inkSecondary)),
            ),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Text(
                isOn ? '不计入收支' : '计入收支',
                style: TextStyle(
                  fontSize: 14,
                  color: isOn ? context.colors.accent : context.colors.ink,
                ),
              ),
            ),
            Switch(value: isOn, onChanged: (_) => toggle()),
          ],
        ),
      ),
    );
  }
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
            PlainIcon(
              PlainIconData.receipt,
              size: 20,
              color: context.colors.inkTertiary,
            ),
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
