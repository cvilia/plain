/// STORY-3.2 高级筛选：多维组合筛选 + CSV 导出（免费）。
/// 筛选维度：分类 × 账户 × 类型 × 金额区间 × 关键词 × 时间。
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:plain/app/bootstrap.dart';
import 'package:plain/app/theme/app_colors.dart';
import 'package:plain/app/theme/design_tokens.dart';
import 'package:plain/app/theme/typography.dart';
import 'package:plain/core/format/amount_formatter.dart';
import 'package:plain/design_system/app_empty_state.dart';
import 'package:plain/design_system/app_toast.dart';
import 'package:plain/design_system/plain_icons_v3.dart';
import 'package:plain/design_system/picker_sheet.dart';
import 'package:plain/design_system/plain_ui.dart';
import 'package:plain/domain/entities/category.dart' as domain;
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/entities/ledger_entry.dart';
import 'package:plain/domain/repositories/repositories.dart';
import 'package:plain/app/l10n/app_strings.dart';
import 'package:plain/app/l10n/strings_accounts.dart';
import 'package:plain/app/l10n/strings_domain.dart';
import 'package:plain/app/l10n/strings_ledger.dart';
import 'package:plain/app/l10n/strings_settings_b.dart';

class AdvancedFilterPage extends ConsumerStatefulWidget {
  const AdvancedFilterPage({super.key});

  @override
  ConsumerState<AdvancedFilterPage> createState() => _AdvancedFilterPageState();
}

class _AdvancedFilterPageState extends ConsumerState<AdvancedFilterPage> {
  String? _categoryId;
  String? _accountId;
  String? _type;
  final _minCtrl = TextEditingController();
  final _maxCtrl = TextEditingController();
  final _keywordCtrl = TextEditingController();
  DateTime? _fromDate;
  DateTime? _toDate;

  List<LedgerEntry> _results = [];
  final Map<String, domain.Category> _categories = {};
  bool _loading = false;
  bool _applied = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _minCtrl.dispose();
    _maxCtrl.dispose();
    _keywordCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final cats = await ref.read(appDependenciesProvider).categoryRepository.listAll();
    final list = cats.successOrNull ?? const <domain.Category>[];
    if (!mounted) return;
    setState(() {
      for (final c in list) {
        _categories[c.id] = c;
      }
    });
  }

  Future<void> _apply() async {
    setState(() {
      _loading = true;
      _applied = true;
    });
    final deps = ref.read(appDependenciesProvider);
    final filter = EntryFilter(
      categoryId: _categoryId,
      accountId: _accountId,
      type: _type,
      fromMs: _fromDate?.millisecondsSinceEpoch,
      toMs: _toDate != null ? _toDate!.millisecondsSinceEpoch + 86399999 : null,
      keyword: _keywordCtrl.text.trim().isEmpty ? null : _keywordCtrl.text.trim(),
      minAmountCents: double.tryParse(_minCtrl.text.trim()) != null ? (double.parse(_minCtrl.text.trim()) * 100).round() : null,
      maxAmountCents: double.tryParse(_maxCtrl.text.trim()) != null ? (double.parse(_maxCtrl.text.trim()) * 100).round() : null,
    );
    final page = await deps.ledgerRepository.listPage(filter: filter, limit: 500);
    if (!mounted) return;
    setState(() {
      _results = page.successOrNull?.items ?? const <LedgerEntry>[];
      _loading = false;
    });
  }

  void _clear() {
    setState(() {
      _categoryId = null;
      _accountId = null;
      _type = null;
      _minCtrl.clear();
      _maxCtrl.clear();
      _keywordCtrl.clear();
      _fromDate = null;
      _toDate = null;
      _results = [];
      _applied = false;
    });
  }

  /// CSV 字段转义：逗号/引号/换行用引号包裹。
  String _csvField(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  Future<void> _exportCsv() async {
    final s = AppStrings.of(context);
    if (_results.isEmpty) return;
    final buf = StringBuffer(s.csvExportHeader);
    for (final e in _results) {
      final cat = _categories[e.categoryId];
      final t = e.occurredAt.toLocal();
      final date = '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
      final typeLabel = switch (e.type) {
        EntryType.expense => s.expense,
        EntryType.income => s.income,
        EntryType.transfer => s.transfer,
        EntryType.borrowOut => s.entryBorrowOut,
        EntryType.borrowIn => s.entryBorrowIn,
        _ => s.other,
      };
      // 金额用整数分格式化，不用 double
      final abs = e.amount.cents.abs();
      final amt = '${e.amount.cents < 0 ? '-' : ''}${abs ~/ 100}.${(abs % 100).toString().padLeft(2, '0')}';
      buf.writeln([
        date,
        typeLabel,
        _csvField(cat?.name ?? ''),
        amt,
        _csvField(e.note ?? ''),
      ].join(','));
    }
    try {
      final dir = Directory.systemTemp;
      final file = File('${dir.path}/plain_filter_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(buf.toString(), flush: true);
      if (mounted) {
        // 分享文件，用户可保存到任意位置
        await Share.shareXFiles([XFile(file.path)], subject: s.exportSubject(_results.length));
      }
    } catch (_) {
      if (mounted) showAppToast(context, s.exportFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Scaffold(
      appBar: PlainTopBar(
        title: s.advancedFilterTitle,
        showBack: true,
        actions: [
          if (_applied && _results.isNotEmpty)
            PlainTopBarTextAction(label: s.exportCsv, onTap: _exportCsv),
          if (_applied)
            PlainTopBarTextAction(label: s.clearAllAction, onTap: _clear),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(Spacing.lg),
        children: [
          // 分类
          _SectionLabel(s.category),
          _CategoryDropdown(value: _categoryId, categories: _categories.values.toList(), onChanged: (v) => setState(() => _categoryId = v)),
          const SizedBox(height: Spacing.md),
          // 类型
          _SectionLabel(s.typeLabel),
          Wrap(
            spacing: Spacing.sm,
            children: [
              for (final (label, val) in [(s.reportFilterAll, null), (s.expense, 'expense'), (s.income, 'income'), (s.transfer, 'transfer')])
                ChoiceChip(label: Text(label), selected: _type == val, onSelected: (_) => setState(() => _type = val)),
            ],
          ),
          const SizedBox(height: Spacing.md),
          // 金额区间
          _SectionLabel(s.crossAmountRange),
          Row(children: [
            Expanded(child: TextField(controller: _minCtrl, keyboardType: TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: s.minAmountLabel, prefixText: '¥', border: OutlineInputBorder()))),
            const SizedBox(width: Spacing.md),
            Expanded(child: TextField(controller: _maxCtrl, keyboardType: TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: s.maxAmountLabel, prefixText: '¥', border: OutlineInputBorder()))),
          ]),
          const SizedBox(height: Spacing.md),
          // 关键词
          _SectionLabel(s.keywordLabel),
          TextField(controller: _keywordCtrl, decoration: InputDecoration(labelText: s.keywordHint, border: OutlineInputBorder())),
          const SizedBox(height: Spacing.md),
          // 时间
          _SectionLabel(s.timeRangeLabel),
          Row(children: [
            Expanded(child: _DateField(label: s.startDateLabel, date: _fromDate, onTap: () async {
              final d = await showDatePicker(context: context, initialDate: _fromDate ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2100));
              if (d != null) setState(() => _fromDate = d);
            })),
            const SizedBox(width: Spacing.md),
            Expanded(child: _DateField(label: s.endDateLabel, date: _toDate, onTap: () async {
              final d = await showDatePicker(context: context, initialDate: _toDate ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2100));
              if (d != null) setState(() => _toDate = d);
            })),
          ]),
          const SizedBox(height: Spacing.xl),
          FilledButton(onPressed: _loading ? null : _apply, child: _loading ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(s.applyFilter)),
          const SizedBox(height: Spacing.lg),
          // 结果
          if (_applied) ...[
            Row(children: [
              Text(s.resultCount(_results.length), style: TextStyle(fontSize: 14, color: context.colors.inkSecondary, fontWeight: FontWeight.w500)),
              const Spacer(),
              if (_results.isNotEmpty)
                TextButton.icon(onPressed: _exportCsv, icon: PlainIcon(PlainIconData.export, size: 18), label: Text(s.exportCsv)),
            ]),
            const SizedBox(height: Spacing.sm),
            if (_results.isEmpty)
              AppEmptyState(icon: PlainIconData.empty, title: s.noMatchingEntries, subtitle: s.tryAdjustingFilter)
            else
              ..._results.map((e) => _ResultTile(entry: e, category: _categories[e.categoryId])),
          ],
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: Text(text, style: AppTextStyles.eyebrow.copyWith(color: context.colors.inkTertiary)),
    );
  }
}

class _CategoryDropdown extends StatelessWidget {
  const _CategoryDropdown({required this.value, required this.categories, required this.onChanged});
  final String? value;
  final List<domain.Category> categories;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final roots = categories.where((c) => c.isRoot).toList();
    // 「全部分类」用空串占位：`showOptionPicker` 的取消也返回 null，
    // 若直接用 null 当值就无法与取消区分。
    String currentName = s.allCategoriesOption;
    for (final c in roots) {
      if (c.id == value) currentName = c.name;
    }
    return PickerField(
      label: null,
      value: currentName,
      onTap: () async {
        final picked = await showOptionPicker<String>(
          context: context,
          title: s.pickCategory,
          current: value ?? '',
          options: [
            PickerOption(value: '', label: s.allCategoriesOption),
            for (final c in roots) PickerOption(value: c.id, label: c.name),
          ],
        );
        if (picked == null) return;
        onChanged(picked.isEmpty ? null : picked);
      },
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.label, required this.date, required this.onTap});
  final String label;
  final DateTime? date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final t = date?.toLocal();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        child: Text(
          t != null ? '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}' : s.selectDateHint,
          style: TextStyle(fontSize: 14, color: t != null ? null : context.colors.inkTertiary),
        ),
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.entry, this.category});
  final LedgerEntry entry;
  final domain.Category? category;

  @override
  Widget build(BuildContext context) {
    final isExpense = entry.type == EntryType.expense;
    final isIncome = entry.type == EntryType.income;
    final amountColor = isExpense ? context.colors.expense : isIncome ? context.colors.income : context.colors.transfer;
    final prefix = isExpense ? '-' : isIncome ? '+' : '';
    final t = entry.occurredAt.toLocal();
    return Container(
      margin: const EdgeInsets.only(bottom: Spacing.xs),
      decoration: BoxDecoration(
        color: context.colors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 60),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${category?.name ?? '未分类'}${entry.note != null && entry.note!.isNotEmpty ? ' · ${entry.note}' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                    ),
                    Text(
                      '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}',
                      style: TextStyle(fontSize: 12, color: context.colors.inkTertiary),
                    ),
                  ],
                ),
              ),
              Text(
                '$prefix${formatAmount(entry.amount.cents)}',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: amountColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
