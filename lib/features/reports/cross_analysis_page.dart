/// SP-3-05 多维度交叉分析。
///
/// STORY-11.3：行维度 × 列维度的透视矩阵 + 热力着色 + 单元格下钻 +
/// 「我的报表」（保存维度组合与筛选，一键复现）。
///
/// 维度只提供**当前真有数据**的五项：分类 / 账户 / 月份 / 商户 / 金额区间
/// （本项目无标签与成员实体，故不列出空壳维度）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plain/app/bootstrap.dart';
import 'package:plain/app/breakpoints.dart';
import 'package:plain/app/l10n/app_strings.dart';
import 'package:plain/app/l10n/strings_reports.dart';
import 'package:plain/app/settings/ledger_settings.dart';
import 'package:plain/app/theme/app_colors.dart';
import 'package:plain/app/theme/design_tokens.dart';
import 'package:plain/app/theme/typography.dart';
import 'package:plain/core/format/amount_formatter.dart';
import 'package:plain/design_system/amount_display.dart';
import 'package:plain/design_system/app_empty_state.dart';
import 'package:plain/design_system/app_toast.dart';
import 'package:plain/design_system/confirm_dialog.dart';
import 'package:plain/design_system/plain_icons_v3.dart';
import 'package:plain/design_system/picker_sheet.dart';
import 'package:plain/design_system/plain_ui.dart';
import 'package:plain/domain/entities/category.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/entities/ledger_entry.dart';
import 'package:plain/domain/entities/saved_report.dart';
import 'package:plain/domain/services/cross_analysis_service.dart';

const _svc = CrossAnalysisService();
const _dims = CrossDimension.values;

class CrossAnalysisPage extends ConsumerStatefulWidget {
  const CrossAnalysisPage({super.key});

  @override
  ConsumerState<CrossAnalysisPage> createState() => _CrossAnalysisPageState();
}

class _CrossAnalysisPageState extends ConsumerState<CrossAnalysisPage> {
  bool _loading = true;
  CrossDimension _rowDim = CrossDimension.category;
  CrossDimension _colDim = CrossDimension.month;
  ReportEntryFilter _filter = ReportEntryFilter.expense;
  bool _heatmap = true;

  CrossTable _table = CrossTable.empty;
  List<LedgerEntry> _entries = const [];
  Map<String, Category> _categories = const {};
  List<SavedReport> _saved = const [];

  /// 范围：最近 [monthsBack] 个记账月（含当月）。
  static const int _monthsBack = 6;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final deps = ref.read(appDependenciesProvider);
    final page = await deps.ledgerRepository.listPage(limit: 5000);
    final cats = await deps.categoryRepository.listAll();
    final accounts = await deps.accountRepository.listAll();
    final saved = await deps.savedReportRepository.listByBook(deps.bookId);
    if (!mounted) return;

    final now = deps.clock.now();
    final startDay = ref.read(monthStartDayProvider);
    final local = now.toLocal();
    final from = DateTime.utc(local.year, local.month - (_monthsBack - 1), startDay);
    final to = DateTime.utc(local.year, local.month + 1, startDay);

    final all = page.successOrNull?.items ?? const <LedgerEntry>[];
    // G-2：过滤口径随维度走 ——
    // - 有「分类」维时用 countsInCategoryStats（子笔计、父笔不计），
    //   否则分割父笔（分类已清空）会把整额落到「未分类」而真子笔被排除；
    // - 纯账户/月份/商户维度用 countsInOutflow（父笔计、子笔不计），
    //   否则父子两笔都会进账户维度、金额翻倍。
    final usesCategory =
        _rowDim == CrossDimension.category || _colDim == CrossDimension.category;
    final inWindow = [
      for (final e in all)
        if (!e.isDeleted &&
            (usesCategory ? e.countsInCategoryStats : e.countsInOutflow) &&
            !e.occurredAt.isBefore(from) &&
            e.occurredAt.isBefore(to) &&
            _passesFilter(e))
          e,
    ];

    final catList = cats.successOrNull ?? const <Category>[];
    setState(() {
      _entries = inWindow;
      _categories = {for (final c in catList) c.id: c};
      _saved = saved.successOrNull ?? const [];
      _table = _buildTable(
        inWindow,
        categoryNames: {for (final c in catList) c.id: c.name},
        accountNames: {
          for (final a in accounts.successOrNull ?? const <Account>[]) a.id: a.name,
        },
        monthStartDay: startDay,
      );
      _loading = false;
    });
  }

  bool _passesFilter(LedgerEntry e) => switch (_filter) {
        ReportEntryFilter.all => true,
        ReportEntryFilter.expense => e.type == EntryType.expense,
        ReportEntryFilter.income => e.type == EntryType.income,
      };

  CrossTable _buildTable(
    List<LedgerEntry> entries, {
    required Map<String, String> categoryNames,
    required Map<String, String> accountNames,
    required int monthStartDay,
  }) =>
      _svc.build(
        s: AppStrings.of(context),
        rowDim: _rowDim,
        colDim: _colDim,
        categoryNames: categoryNames,
        accountNames: accountNames,
        monthStartDay: monthStartDay,
        entries: [
          for (final e in entries)
            CrossEntry(
              cents: e.amount.cents,
              at: e.occurredAt,
              isIncome: e.type == EntryType.income,
              categoryId: e.categoryId,
              accountId: e.accountId,
              note: e.note,
            ),
        ],
      );

  Future<void> _rebuild() async {
    final deps = ref.read(appDependenciesProvider);
    final cats = await deps.categoryRepository.listAll();
    final accounts = await deps.accountRepository.listAll();
    if (!mounted) return;
    setState(() {
      _table = _buildTable(
        _entries,
        categoryNames: {
          for (final c in cats.successOrNull ?? const <Category>[]) c.id: c.name,
        },
        accountNames: {
          for (final a in accounts.successOrNull ?? const <Account>[]) a.id: a.name,
        },
        monthStartDay: ref.read(monthStartDayProvider),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final colors = context.colors;
    return Scaffold(
      appBar: PlainTopBar(
        title: s.reportCrossTitle,
        showBack: true,
        actions: [
          PlainTopBarAction(
            icon: PlainIconData.listCheck,
            tooltip: s.reportMineTitle,
            onTap: _showSaved,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ContentWidthConstraint(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    Spacing.lg, Spacing.sm, Spacing.lg, Spacing.xl),
                children: [
                  _DimPicker(
                    label: s.reportRowLabel,
                    selected: _rowDim,
                    onChanged: (d) {
                      setState(() => _rowDim = d);
                      _rebuild();
                    },
                  ),
                  const SizedBox(height: Spacing.sm),
                  _DimPicker(
                    label: s.reportColLabel,
                    selected: _colDim,
                    onChanged: (d) {
                      setState(() => _colDim = d);
                      _rebuild();
                    },
                  ),
                  const SizedBox(height: Spacing.sm),
                  PlainSeg(
                    items: [for (final f in ReportEntryFilter.values) f.label(s)],
                    selectedIndex: ReportEntryFilter.values.indexOf(_filter),
                    onChanged: (i) async {
                      setState(() => _filter = ReportEntryFilter.values[i]);
                      await _load();
                    },
                  ),
                  const SizedBox(height: Spacing.md),
                  Row(children: [
                    Text(s.reportHeatmap,
                        style: TextStyle(
                            fontSize: 14, color: colors.inkSecondary)),
                    const Spacer(),
                    PlainSwitch(
                      value: _heatmap,
                      onChanged: (v) => setState(() => _heatmap = v),
                    ),
                  ]),
                  const SizedBox(height: Spacing.sm),
                  if (_table.isEmpty)
                    AppEmptyState(
                      icon: PlainIconData.filter,
                      title: s.reportNoDataComboTitle,
                      subtitle: s.reportNoDataComboSubtitle,
                    )
                  else ...[
                    PlainEyebrow(
                        s.reportMatrixEyebrow(_rowDim.label(s), _colDim.label(s), _entries.length)),
                    PlainPanel(children: [
                      _Matrix(
                        table: _table,
                        heatmap: _heatmap,
                        onCellTap: _showCell,
                      ),
                    ]),
                    const SizedBox(height: Spacing.sm),
                    Text(
                      s.reportGrandTotalHint(formatAmountYuan(_table.grandTotalCents)),
                      style:
                          TextStyle(fontSize: 12, color: colors.inkTertiary),
                    ),
                  ],
                  const SizedBox(height: Spacing.md),
                  _SavePanel(
                    onSave: _saveCurrent,
                    savedCount: _saved.length,
                  ),
                ],
              ),
            ),
    );
  }

  /// AC4：保存当前组合。
  Future<void> _saveCurrent() async {
    // 不手管 controller：`showDialog` 返回时弹窗淡出动画还没结束、子树仍会重建，
    // 此时 dispose 会抛「A TextEditingController was used after being disposed」。
    final s = AppStrings.of(context);
    var name = s.reportComboName(_rowDim.label(s), _colDim.label(s));
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.reportSaveAsTitle),
        content: TextFormField(
          initialValue: name,
          onChanged: (v) => name = v,
          decoration: InputDecoration(
              labelText: s.reportNameField, border: const OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(s.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, name.trim()),
            child: Text(s.save),
          ),
        ],
      ),
    );
    if (result == null || result.isEmpty || !mounted) return;

    final deps = ref.read(appDependenciesProvider);
    final now = deps.clock.now();
    final local = now.toLocal();
    final startDay = ref.read(monthStartDayProvider);
    final r = await deps.savedReportRepository.create(SavedReport(
      id: deps.idGen.generate(),
      bookId: deps.bookId,
      name: result,
      rowDim: _rowDim,
      colDim: _colDim,
      fromMs: DateTime.utc(local.year, local.month - (_monthsBack - 1), startDay)
          .millisecondsSinceEpoch,
      toMs: DateTime.utc(local.year, local.month + 1, startDay)
          .millisecondsSinceEpoch,
      entryFilter: _filter,
      heatmap: _heatmap,
      createdAt: now,
      updatedAt: now,
      deviceId: deps.deviceId,
    ));
    if (!mounted) return;
    if (r.isSuccess) {
      showAppToast(context, s.reportSavedToast(result));
      await _load();
    } else {
      showAppToast(context, s.reportSaveFailed);
    }
  }

  /// AC4：一键复现 / 删除。
  Future<void> _showSaved() async {
    final s = AppStrings.of(context);
    if (_saved.isEmpty) {
      showAppToast(context, s.reportNoSaved);
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(Spacing.lg),
              child: Row(children: [
                Expanded(
                  child: Text(s.reportMineTitle,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                ),
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(s.close)),
              ]),
            ),
            const Divider(height: 1),
            for (final r in _saved)
              ListTile(
                title: Text(r.name, style: const TextStyle(fontSize: 15)),
                subtitle: Text(r.describe(s),
                    style: const TextStyle(fontSize: 12)),
                trailing: IconButton(
                  icon: const PlainIcon(PlainIconData.delete, size: 20),
                  tooltip: s.reportDeleteTooltip,
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _deleteSaved(r);
                  },
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _applySaved(r);
                },
              ),
            const SizedBox(height: Spacing.md),
          ],
        ),
      ),
    );
  }

  void _applySaved(SavedReport r) {
    final s = AppStrings.of(context);
    setState(() {
      _rowDim = r.rowDim;
      _colDim = r.colDim;
      _filter = r.entryFilter;
      _heatmap = r.heatmap;
    });
    _rebuild();
    showAppToast(context, s.reportAppliedToast(r.name));
  }

  Future<void> _deleteSaved(SavedReport r) async {
    final s = AppStrings.of(context);
    final ok = await showConfirmDialog(
      context,
      title: s.reportDeleteTitle,
      message: s.reportDeleteConfirm(r.name),
      confirmLabel: s.delete,
      destructive: true,
    );
    if (ok != true || !mounted) return;
    await ref.read(appDependenciesProvider).savedReportRepository.softDelete(r.id);
    await _load();
  }

  /// AC3：点单元格下钻到对应账单。
  Future<void> _showCell(String rowKey, String colKey) async {
    final s = AppStrings.of(context);
    final cell = _table.cellAt(rowKey, colKey);
    if (cell == null) return;
    final mine = [
      for (final e in _entries)
        if (_matchesKey(e, _rowDim, rowKey) && _matchesKey(e, _colDim, colKey)) e,
    ];
    final rowLabel = _table.rowLabels[_table.rowKeys.indexOf(rowKey)];
    final colLabel = _table.colLabels[_table.colKeys.indexOf(colKey)];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(ctx).height * 0.6,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.all(Spacing.lg),
              child: Row(children: [
                Expanded(
                  child: Text(s.reportCellSheetTitle(rowLabel, colLabel, mine.length),
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                ),
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(s.close)),
              ]),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: mine.length,
                itemBuilder: (ctx, i) {
                  final e = mine[i];
                  final local = e.occurredAt.toLocal();
                  final cat = e.categoryId == null
                      ? s.uncategorized
                      : (_categories[e.categoryId]?.name ?? s.uncategorized);
                  return ListTile(
                    dense: true,
                    title: Text(
                      '${local.month.toString().padLeft(2, '0')}-'
                      '${local.day.toString().padLeft(2, '0')} $cat'
                      '${e.note == null || e.note!.isEmpty ? '' : ' · ${e.note}'}',
                      style: const TextStyle(fontSize: 14),
                    ),
                    trailing: AmountDisplay(cents: e.amount.cents, fontSize: 14),
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }

  bool _matchesKey(LedgerEntry e, CrossDimension dim, String key) {
    switch (dim) {
      case CrossDimension.category:
        return key == (e.categoryId ?? '__none__');
      case CrossDimension.account:
        return key == (e.accountId ?? '__none__');
      case CrossDimension.merchant:
        final note = (e.note ?? '').trim();
        return key == (note.isEmpty ? '__none__' : note);
      case CrossDimension.month:
        return key ==
            CrossAnalysisService.monthLabelOf(
                e.occurredAt, ref.read(monthStartDayProvider));
      case CrossDimension.amountRange:
        // 金额档位键是序号，用与服务一致的边界判定
        return key == _rangeKeyOf(e.amount.cents);
    }
  }

  static String _rangeKeyOf(int cents) {
    const bounds = [10000, 50000, 100000, 500000];
    for (var i = 0; i < bounds.length; i++) {
      if (cents < bounds[i]) return '$i';
    }
    return '${bounds.length}';
  }
}

class _DimPicker extends StatelessWidget {
  const _DimPicker({
    required this.label,
    required this.selected,
    required this.onChanged,
  });
  final String label;
  final CrossDimension selected;
  final ValueChanged<CrossDimension> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final colors = context.colors;
    return Row(children: [
      SizedBox(
        width: 32,
        child: Text(label,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colors.inkSecondary)),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: PickerField(
          label: null,
          value: selected.label(AppStrings.of(context)),
          onTap: () async {
            final picked = await showOptionPicker<CrossDimension>(
              context: context,
              title: s.reportDimSheetTitle(label),
              current: selected,
              options: [
                for (final d in _dims)
                  PickerOption(value: d, label: d.label(AppStrings.of(context))),
              ],
            );
            if (picked != null) onChanged(picked);
          },
        ),
      ),
    ]);
  }
}

/// 矩阵表：首列固定行标签，其余列可横向滚动。
class _Matrix extends StatelessWidget {
  const _Matrix({
    required this.table,
    required this.heatmap,
    required this.onCellTap,
  });
  final CrossTable table;
  final bool heatmap;
  final void Function(String rowKey, String colKey) onCellTap;

  static const double _colWidth = 92;
  static const double _rowLabelWidth = 108;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final colors = context.colors;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 表头
          Row(children: [
            SizedBox(
              width: _rowLabelWidth,
              // ⚠️ `label` 是 `(AppStrings) => String` 方法，必须传 `s` 调用；
              // 直接插值得到的是闭包，界面会打出 "Closure: (AppStrings) => String"。
              child: Text('${table.rowDim.label(s)} \\ ${table.colDim.label(s)}',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colors.inkTertiary)),
            ),
            for (var c = 0; c < table.colKeys.length; c++)
              SizedBox(
                width: _colWidth,
                child: Text(
                  table.colLabels[c],
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: colors.inkTertiary),
                ),
              ),
            SizedBox(
              width: _colWidth,
              child: Text(s.reportTotal,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: colors.inkSecondary)),
            ),
          ]),
          const SizedBox(height: 6),
          for (var r = 0; r < table.rowKeys.length; r++) ...[
            Divider(height: 1, thickness: 1, color: colors.divider),
            Row(children: [
              SizedBox(
                width: _rowLabelWidth,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    table.rowLabels[r],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
              for (var c = 0; c < table.colKeys.length; c++)
                _cell(context, table.rowKeys[r], table.colKeys[c]),
              SizedBox(
                width: _colWidth,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    formatAmountYuan(table.rowTotals[table.rowKeys[r]] ?? 0),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: colors.ink),
                  ),
                ),
              ),
            ]),
          ],
          Divider(height: 1, thickness: 1, color: colors.divider),
          // 列合计
          Row(children: [
            SizedBox(
              width: _rowLabelWidth,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(s.reportTotal,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: colors.inkSecondary)),
              ),
            ),
            for (final k in table.colKeys)
              SizedBox(
                width: _colWidth,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    formatAmountYuan(table.colTotals[k] ?? 0),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: colors.inkSecondary),
                  ),
                ),
              ),
            SizedBox(
              width: _colWidth,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  formatAmountYuan(table.grandTotalCents),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: colors.ink),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _cell(BuildContext context, String rowKey, String colKey) {
    final cell = table.cellAt(rowKey, colKey);
    final heat = heatmap ? table.heatOf(rowKey, colKey) : 0.0;
    final colors = context.colors;
    return InkWell(
      onTap: cell == null ? null : () => onCellTap(rowKey, colKey),
      // 固定行高 + Center：金额与行标签垂直居中；热力色块不再铺满整格，
      // 改成一块内缩的圆角「色片」，上下左右都留空隙。
      child: SizedBox(
        width: _colWidth,
        height: 40,
        child: Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: heat <= 0
                  ? null
                  : colors.primary.withValues(alpha: 0.06 + 0.34 * heat),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Text(
                cell == null ? '—' : formatAmountYuan(cell.cents),
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 12,
                  height: designLineHeight(12),
                  fontWeight:
                      cell == null ? FontWeight.w400 : FontWeight.w600,
                  color: cell == null ? colors.inkFaint : colors.ink,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SavePanel extends StatelessWidget {
  const _SavePanel({required this.onSave, required this.savedCount});
  final VoidCallback onSave;
  final int savedCount;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final colors = context.colors;
    return PlainPanel(
      padding: const EdgeInsets.all(Spacing.lg),
      children: [
        Text(
          s.reportSavePanelHint(savedCount),
          style: TextStyle(fontSize: 14, height: 1.65, color: colors.inkSecondary),
        ),
        const SizedBox(height: Spacing.md),
        FilledButton.icon(
          onPressed: onSave,
          icon: const PlainIcon(PlainIconData.listCheck),
          label: Text(s.reportSaveAsTitle),
        ),
      ],
    );
  }
}
