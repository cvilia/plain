/// CSV import wizard: paste → map columns → preview → import. PRD F7.5.
library;

import 'package:plain/app/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:plain/design_system/app_toast.dart';
import 'package:plain/features/ledger/presentation/member_write_guard.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plain/app/bootstrap.dart';
import 'package:plain/app/breakpoints.dart';
import 'package:plain/app/theme/design_tokens.dart';
import 'package:plain/core/format/amount_formatter.dart';
import 'package:plain/design_system/plain_icons_v3.dart';
import 'package:plain/design_system/picker_sheet.dart';
import 'package:plain/design_system/plain_ui.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/services/csv_importer.dart';

class ImportPage extends ConsumerStatefulWidget {
  const ImportPage({super.key});

  @override
  ConsumerState<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends ConsumerState<ImportPage> {
  final _csvController = TextEditingController();
  int _step = 0; // 0=paste, 1=map, 2=preview, 3=done
  List<List<String>> _rows = const [];
  CsvColumnMapping _mapping = const CsvColumnMapping(dateCol: 0, amountCol: 1);
  List<ParsedEntry> _previewEntries = const [];
  List<String> _previewErrors = const [];
  ImportReport? _report;
  bool _importing = false;

  @override
  void dispose() {
    _csvController.dispose();
    super.dispose();
  }

  void _parseCsv() {
    final text = _csvController.text;
    if (text.trim().isEmpty) return;
    final rows = parseCsv(text);
    if (rows.length < 2) {
      showAppToast(context, 'CSV 内容不足，至少需要表头和一行数据');
      return;
    }
    setState(() {
      _rows = rows;
      _step = 1;
      // Auto-detect: date-like col 0, amount-like col 1
      _mapping = CsvColumnMapping(
        dateCol: _detectDateCol(rows),
        amountCol: _detectAmountCol(rows),
      );
    });
  }

  int _detectDateCol(List<List<String>> rows) {
    final header = rows.first;
    for (var i = 0; i < header.length; i++) {
      final h = header[i].toLowerCase();
      if (h.contains('日期') || h.contains('时间') || h.contains('date')) return i;
    }
    return 0;
  }

  int _detectAmountCol(List<List<String>> rows) {
    final header = rows.first;
    for (var i = 0; i < header.length; i++) {
      final h = header[i].toLowerCase();
      if (h.contains('金额') || h.contains('amount') || h.contains('money')) return i;
    }
    return rows.first.length > 1 ? 1 : 0;
  }

  void _buildPreview() {
    final parsed = parseRows(_rows, _mapping);
    setState(() {
      _previewEntries = parsed.entries;
      _previewErrors = parsed.errors;
      _step = 2;
    });
  }

  Future<void> _doImport() async {
    // STORY-8.2 AC2：导入就是批量新增账单 —— 只读成员不得用导入绕开记账权限
    if (!await guardCanWriteLedger(context, ref)) return;
    setState(() => _importing = true);
    final deps = ref.read(appDependenciesProvider);

    // Build category name → id map
    final catRes = await deps.categoryRepository.listAll();
    final cats = catRes.successOrNull ?? const [];
    final catMap = {for (final c in cats) c.name: c.id};

    final result = await deps.importCsv(
      csvText: _csvController.text,
      mapping: _mapping,
      bookId: deps.bookId,
      deviceId: deps.deviceId,
      resolveCategoryId: (name) => catMap[name],
    );

    if (!mounted) return;
    setState(() {
      _importing = false;
      _report = result.successOrNull;
      _step = 3;
    });
    if (result.isFailure && _report == null) {
      showAppToast(context, '导入失败: ${result.failureOrNull?.message ?? ''}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PlainTopBar(title: '数据导入', showBack: true),
      body: ContentWidthConstraint(
        child: ListView(
          padding: const EdgeInsets.all(Spacing.lg),
          children: [
            _StepIndicator(current: _step),
            const SizedBox(height: Spacing.lg),
            switch (_step) {
              0 => _buildPasteStep(),
              1 => _buildMapStep(),
              2 => _buildPreviewStep(),
              _ => _buildDoneStep(),
            },
          ],
        ),
      ),
    );
  }

  Widget _buildPasteStep() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('粘贴 CSV 内容', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: Spacing.sm),
            Text(
              '从竞品 App 导出 CSV 后，将内容粘贴到下方。支持钱迹、随手记、挖财等主流格式。',
              style: TextStyle(fontSize: 14, color: context.colors.inkSecondary),
            ),
            const SizedBox(height: Spacing.lg),
            TextField(
              controller: _csvController,
              maxLines: 10,
              decoration: InputDecoration(
                hintText: '日期,金额,分类,备注\n2024-01-15,25.00,餐饮,午餐\n...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.md)),
                filled: true,
                fillColor: context.colors.surfaceMuted,
              ),
            ),
            const SizedBox(height: Spacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _parseCsv,
                child: const Text('下一步：映射列'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapStep() {
    final headers = _rows.first;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('映射列', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: Spacing.sm),
            Text('共 ${_rows.length - 1} 行数据，请指定各列含义',
                style: TextStyle(fontSize: 14, color: context.colors.inkSecondary)),
            const SizedBox(height: Spacing.lg),
            _buildColDropdown('日期列 *', _mapping.dateCol, headers, (v) {
              if (v == null) return;
              setState(() => _mapping = CsvColumnMapping(
                dateCol: v, amountCol: _mapping.amountCol,
                typeCol: _mapping.typeCol, categoryCol: _mapping.categoryCol,
                noteCol: _mapping.noteCol, merchantCol: _mapping.merchantCol,
              ));
            }),
            _buildColDropdown('金额列 *', _mapping.amountCol, headers, (v) {
              if (v == null) return;
              setState(() => _mapping = CsvColumnMapping(
                dateCol: _mapping.dateCol, amountCol: v,
                typeCol: _mapping.typeCol, categoryCol: _mapping.categoryCol,
                noteCol: _mapping.noteCol, merchantCol: _mapping.merchantCol,
              ));
            }),
            _buildColDropdown('分类列', _mapping.categoryCol, headers, (v) {
              setState(() => _mapping = CsvColumnMapping(
                dateCol: _mapping.dateCol, amountCol: _mapping.amountCol,
                typeCol: _mapping.typeCol, categoryCol: v,
                noteCol: _mapping.noteCol, merchantCol: _mapping.merchantCol,
              ));
            }, optional: true),
            _buildColDropdown('备注列', _mapping.noteCol, headers, (v) {
              setState(() => _mapping = CsvColumnMapping(
                dateCol: _mapping.dateCol, amountCol: _mapping.amountCol,
                typeCol: _mapping.typeCol, categoryCol: _mapping.categoryCol,
                noteCol: v, merchantCol: _mapping.merchantCol,
              ));
            }, optional: true),
            _buildColDropdown('商家列', _mapping.merchantCol, headers, (v) {
              setState(() => _mapping = CsvColumnMapping(
                dateCol: _mapping.dateCol, amountCol: _mapping.amountCol,
                typeCol: _mapping.typeCol, categoryCol: _mapping.categoryCol,
                noteCol: _mapping.noteCol, merchantCol: v,
              ));
            }, optional: true),
            const SizedBox(height: Spacing.lg),
            Row(children: [
              Expanded(
                child: Material(
                  color: const Color(0x00000000),
                  child: InkWell(
                    onTap: () => setState(() => _step = 0),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.colors.lineStrong),
                      ),
                      child: Center(
                        child: Text('返回', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: context.colors.ink)),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: FilledButton(onPressed: _buildPreview, child: const Text('预览')),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildColDropdown(String label, int? value, List<String> headers, ValueChanged<int?> onChanged, {bool optional = false}) {
    // 下标用 -1 作「（无）」哨兵：`showOptionPicker` 的取消也返回 null，
    // 与「明确选择无」无法区分，故不用 null 当值。
    final v = value;
    final valid = v != null && v >= 0 && v < headers.length;
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.md),
      child: PickerField(
        label: label,
        value: valid ? '$v: ${headers[v]}' : (optional ? '（无）' : '请选择'),
        onTap: () async {
          final picked = await showOptionPicker<int>(
            context: context,
            title: label,
            current: valid ? v : -1,
            options: [
              if (optional) const PickerOption(value: -1, label: '（无）'),
              for (var i = 0; i < headers.length; i++)
                PickerOption(value: i, label: '$i: ${headers[i]}'),
            ],
          );
          if (picked == null) return;
          onChanged(picked < 0 ? null : picked);
        },
      ),
    );
  }

  Widget _buildPreviewStep() {
    final deduped = dedupEntries(_previewEntries, const {});
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('预览', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: Spacing.sm),
            Text('可导入 ${deduped.unique.length} 条，跳过 ${_previewErrors.length} 条异常',
                style: TextStyle(fontSize: 14, color: context.colors.inkSecondary)),
            const SizedBox(height: Spacing.md),
            if (_previewErrors.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(Spacing.md),
                decoration: BoxDecoration(
                  color: context.colors.expense.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(Radii.sm),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('异常行', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.colors.expense)),
                    const SizedBox(height: Spacing.xs),
                    ..._previewErrors.take(5).map((e) => Text(e, style: TextStyle(fontSize: 12, color: context.colors.expense))),
                    if (_previewErrors.length > 5)
                      Text('... 共 ${_previewErrors.length} 条', style: TextStyle(fontSize: 12, color: context.colors.expense)),
                  ],
                ),
              ),
              const SizedBox(height: Spacing.md),
            ],
            ...deduped.unique.take(10).map((e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
              child: Row(children: [
                Expanded(
                  flex: 2,
                  child: Text('${e.occurredAt.year}-${e.occurredAt.month.toString().padLeft(2, '0')}-${e.occurredAt.day.toString().padLeft(2, '0')}',
                      style: TextStyle(fontSize: 12, color: context.colors.inkSecondary)),
                ),
                Expanded(
                  flex: 2,
                  child: Text(e.categoryName ?? '未分类', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
                ),
                Expanded(
                  flex: 3,
                  child: Text(e.note ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: context.colors.inkTertiary)),
                ),
                Text(
                  '${e.type == EntryType.expense ? '-' : '+'}${formatAmount(e.amountCents)}',
                  style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600,
                    color: e.type == EntryType.expense ? context.colors.expense : context.colors.income,
                  ),
                ),
              ]),
            )),
            if (deduped.unique.length > 10)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
                child: Text('... 共 ${deduped.unique.length} 条', style: TextStyle(fontSize: 12, color: context.colors.inkTertiary)),
              ),
            const SizedBox(height: Spacing.lg),
            Row(children: [
              Expanded(
                child: Material(
                  color: const Color(0x00000000),
                  child: InkWell(
                    onTap: _importing ? null : () => setState(() => _step = 1),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.colors.lineStrong),
                      ),
                      child: Center(
                        child: Text('返回', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: context.colors.ink)),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: FilledButton(
                  onPressed: _importing ? null : _doImport,
                  child: _importing
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text('导入 ${deduped.unique.length} 条'),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildDoneStep() {
    final r = _report;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('导入完成', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: Spacing.lg),
            if (r != null) ...[
              _ResultRow('成功导入', '${r.successCount} 条', context.colors.income),
              _ResultRow('去重跳过', '${r.dedupedCount} 条', context.colors.inkSecondary),
              _ResultRow('失败/异常', '${r.failedCount} 条', context.colors.expense),
              if (r.errors.isNotEmpty) ...[
                const SizedBox(height: Spacing.md),
                Text('异常详情', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.colors.expense)),
                ...r.errors.take(5).map((e) => Text(e, style: TextStyle(fontSize: 12, color: context.colors.expense))),
              ],
            ],
            const SizedBox(height: Spacing.xl),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('完成'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.current});
  final int current;

  @override
  Widget build(BuildContext context) {
    const labels = ['粘贴', '映射', '预览', '完成'];
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0) Expanded(child: Container(height: 1, color: i <= current ? context.colors.primary : context.colors.border)),
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i <= current ? context.colors.primary : context.colors.surfaceMuted,
            ),
            child: Center(
              child: i < current
                  ? PlainIcon(
                      PlainIconData.check,
                      size: 16,
                      color: context.colors.onPrimary,
                    )
                  : Text('${i + 1}', style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600,
                      color: i <= current ? context.colors.onPrimary : context.colors.inkTertiary,
                    )),
            ),
          ),
        ],
      ],
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow(this.label, this.value, this.color);
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14, color: context.colors.inkSecondary)),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}
