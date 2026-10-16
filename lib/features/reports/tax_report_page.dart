/// SP-3-06 税务 / 可抵扣支出报表。
///
/// STORY-11.5：按记账月或年度汇总「可抵扣」分类的支出，分类别列出，可导出明细，
/// 每个周期可标记「已申报」。
///
/// 「可抵扣」是**分类上的标记**（分类管理页可编辑，二级继承根分类），
/// 因此报表口径与用户维护的分类数据一致，没有第二套配置。
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:plain/app/bootstrap.dart';
import 'package:plain/app/breakpoints.dart';
import 'package:plain/app/settings/ledger_settings.dart';
import 'package:plain/app/theme/app_colors.dart';
import 'package:plain/app/theme/design_tokens.dart';
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
import 'package:plain/domain/entities/tax_filing.dart';
import 'package:plain/domain/services/tax_service.dart';
import 'package:share_plus/share_plus.dart';

const _svc = TaxService();

class TaxReportPage extends ConsumerStatefulWidget {
  const TaxReportPage({super.key});

  @override
  ConsumerState<TaxReportPage> createState() => _TaxReportPageState();
}

class _TaxReportPageState extends ConsumerState<TaxReportPage> {
  bool _loading = true;
  TaxPeriodKind _kind = TaxPeriodKind.month;
  String? _periodKey;

  TaxSummary _summary = TaxSummary.empty;
  List<LedgerEntry> _deductibleEntries = const [];
  Map<String, Category> _categories = const {};
  List<TaxFiling> _filings = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  List<({String key, String label, bool isYear})> _options() =>
      TaxService.periodOptions(
        now: ref.read(appDependenciesProvider).clock.now(),
        monthStartDay: ref.read(monthStartDayProvider),
      );

  Future<void> _load() async {
    setState(() => _loading = true);
    final deps = ref.read(appDependenciesProvider);
    final page = await deps.ledgerRepository.listPage(limit: 5000);
    final cats = await deps.categoryRepository.listAll();
    final filings = await deps.taxFilingRepository.listByBook(deps.bookId);
    if (!mounted) return;

    final catList = cats.successOrNull ?? const <Category>[];
    final byId = {for (final c in catList) c.id: c};
    final info = <String, TaxCategoryInfo>{
      for (final c in catList)
        c.id: TaxCategoryInfo(
          name: c.name,
          isDeductible: c.isDeductible,
          parentId: c.parentId,
        ),
    };

    final options = _options();
    final selected = _periodKey ??
        options
            .firstWhere((o) => o.isYear == (_kind == TaxPeriodKind.year),
                orElse: () => options.first)
            .key;
    final isYear = selected.length == 4;

    // 只有计入分类统计的支出才可能可抵扣（G-2 口径）
    final mine = [
      for (final e in page.successOrNull?.items ?? const <LedgerEntry>[])
        if (!e.isDeleted &&
            e.countsInCategoryStats &&
            e.type == EntryType.expense &&
            e.categoryId != null &&
            _svc.isDeductible(e.categoryId!, info))
          e,
    ];

    final filingList = filings.successOrNull ?? const <TaxFiling>[];
    final filing = filingList.isEmpty
        ? null
        : filingList.where((f) => f.periodKey == selected).firstOrNull;

    setState(() {
      _categories = byId;
      _deductibleEntries = mine;
      _filings = filingList;
      _summary = _svc.summarize(
        entries: [
          for (final e in mine)
            TaxEntry(cents: e.amount.cents, at: e.occurredAt, categoryId: e.categoryId),
        ],
        categories: info,
        periodKey: selected,
        monthStartDay: ref.read(monthStartDayProvider),
        isFiled: filing != null,
        filedAt: filing?.filedAt,
      );
      _periodKey = selected;
      _kind = isYear ? TaxPeriodKind.year : TaxPeriodKind.month;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final options = _options();
    // 申报周期候选随「记账月 / 年度」切换。
    final periodOptions = options
        .where((o) => o.isYear == (_kind == TaxPeriodKind.year))
        .toList();
    return Scaffold(
      appBar: PlainTopBar(
        title: '税务报表',
        showBack: true,
        actions: [
          PlainTopBarAction(
            icon: PlainIconData.export,
            tooltip: '导出明细',
            onTap: _exportCsv,
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
                  PlainSeg(
                    items: const ['记账月', '年度'],
                    selectedIndex: _kind == TaxPeriodKind.month ? 0 : 1,
                    onChanged: (i) {
                      setState(() {
                        _kind = i == 0
                            ? TaxPeriodKind.month
                            : TaxPeriodKind.year;
                        _periodKey = null;
                      });
                      _load();
                    },
                  ),
                  const SizedBox(height: Spacing.sm),
                  PickerField(
                    label: '申报周期',
                    value: () {
                      for (final o in periodOptions) {
                        if (o.key == _periodKey) return o.label;
                      }
                      return '请选择';
                    }(),
                    onTap: () async {
                      final picked = await showOptionPicker<String>(
                        context: context,
                        title: '申报周期',
                        current: _periodKey,
                        options: [
                          for (final o in periodOptions)
                            PickerOption(value: o.key, label: o.label),
                        ],
                      );
                      if (picked == null) return;
                      setState(() => _periodKey = picked);
                      _load();
                    },
                  ),
                  const SizedBox(height: Spacing.md),
                  // AC3：已申报状态可切换
                  Row(children: [
                    Text(
                      _summary.isFiled
                          ? '已申报（${_summary.filedAt == null ? '' : _fmtDay(_summary.filedAt!)}）'
                          : '未申报',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _summary.isFiled
                            ? colors.income
                            : colors.inkSecondary,
                      ),
                    ),
                    const Spacer(),
                    PlainSwitch(
                      value: _summary.isFiled,
                      onChanged: (_) => _toggleFiled(),
                    ),
                  ]),
                  const SizedBox(height: Spacing.sm),
                  if (_summary.isEmpty)
                    AppEmptyState(
                      icon: PlainIconData.receipt,
                      title: '该周期没有可抵扣支出',
                      subtitle: '在分类管理里把相关分类标为「可抵扣」后，'
                          '它们的支出会自动汇总到这里',
                    )
                  else ...[
                    PlainEyebrow('可抵扣明细 · ${_summary.lines.length} 类'),
                    PlainPanel(children: [
                      for (var i = 0; i < _summary.lines.length; i++) ...[
                        if (i > 0)
                          Divider(
                              height: 1,
                              thickness: 1,
                              indent: 16,
                              color: colors.divider),
                        _LineRow(line: _summary.lines[i]),
                      ],
                    ]),
                    const SizedBox(height: Spacing.sm),
                    PlainPanel(children: [
                      PlainRow(
                        title: '合计（${_summary.totalCount} 笔）',
                        trailing: Text(
                          formatAmountYuan(_summary.totalCents),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: colors.ink,
                          ),
                        ),
                      ),
                    ]),
                  ],
                  const SizedBox(height: Spacing.md),
                  _NotePanel(isFiled: _summary.isFiled),
                ],
              ),
            ),
    );
  }

  static String _fmtDay(DateTime at) {
    final l = at.toLocal();
    return '${l.year}-${l.month.toString().padLeft(2, '0')}-'
        '${l.day.toString().padLeft(2, '0')}';
  }

  Future<void> _toggleFiled() async {
    final deps = ref.read(appDependenciesProvider);
    final key = _periodKey;
    if (key == null) return;

    if (_summary.isFiled) {
      final filing = _filings.where((f) => f.periodKey == key).firstOrNull;
      if (filing == null) return;
      final ok = await showConfirmDialog(
        context,
        title: '取消申报',
        message: '取消「$key」的已申报标记？',
        confirmLabel: '取消申报',
        destructive: true,
      );
      if (ok != true || !mounted) return;
      await deps.taxFilingRepository.unmarkFiled(filing.id);
      if (mounted) showAppToast(context, '已取消申报');
    } else {
      final r = await deps.taxFilingRepository.markFiled(
        id: deps.idGen.generate(),
        bookId: deps.bookId,
        periodKey: key,
        periodKind: key.length == 4 ? TaxPeriodKind.year : TaxPeriodKind.month,
        deviceId: deps.deviceId,
      );
      if (!mounted) return;
      showAppToast(context, r.isSuccess ? '已标记申报' : '标记失败');
    }
    await _load();
  }

  /// 导出该周期的可抵扣明细（CSV，走系统分享，与「高级筛选」同一套做法）。
  Future<void> _exportCsv() async {
    if (_summary.isEmpty) {
      showAppToast(context, '该周期没有可导出的明细');
      return;
    }
    final key = _periodKey ?? '';
    final mine = [
      for (final e in _deductibleEntries)
        if (_inPeriod(e.occurredAt, key)) e,
    ];
    final buf = StringBuffer('日期,分类,金额,备注\n');
    for (final e in mine) {
      final t = e.occurredAt.toLocal();
      final date = '${t.year}-${t.month.toString().padLeft(2, '0')}-'
          '${t.day.toString().padLeft(2, '0')}';
      final abs = e.amount.cents.abs();
      final amt =
          '${abs ~/ 100}.${(abs % 100).toString().padLeft(2, '0')}';
      buf.writeln([
        date,
        _csv(_categories[e.categoryId]?.name ?? ''),
        amt,
        _csv(e.note ?? ''),
      ].join(','));
    }
    try {
      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/plain_tax_${key.replaceAll('-', '')}_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(buf.toString(), flush: true);
      if (!mounted) return;
      await Share.shareXFiles([XFile(file.path)],
          subject: '可抵扣支出明细 $key（${mine.length} 笔）');
    } catch (_) {
      if (mounted) showAppToast(context, '导出失败');
    }
  }

  bool _inPeriod(DateTime utc, String key) {
    if (key.length == 4) return utc.toLocal().year == int.tryParse(key);
    return TaxService.accountingMonthOf(utc, ref.read(monthStartDayProvider)) ==
        key;
  }

  /// CSV 字段转义：含逗号/引号/换行时加引号并转义内部引号。
  static String _csv(String v) {
    if (v.contains(',') || v.contains('"') || v.contains('\n')) {
      return '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({required this.line});
  final TaxLine line;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(line.name,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text('${line.count} 笔',
                  style: TextStyle(fontSize: 12, color: colors.inkTertiary)),
            ],
          ),
        ),
        AmountDisplay(cents: line.cents, fontSize: 15),
      ]),
    );
  }
}

class _NotePanel extends StatelessWidget {
  const _NotePanel({required this.isFiled});
  final bool isFiled;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final lines = <String>[
      '「可抵扣」是分类上的标记：在分类管理里标记后，该分类的支出会自动汇总到这里。',
      '二级分类继承其根分类的标记，不用逐个设置。',
      '年度汇总按自然年；记账月汇总按你在设置里定的月起始日。',
      isFiled
          ? '该周期已标记申报，取消后可以重新汇总。'
          : '汇总无误后可以标记「已申报」，标记只记录状态，不影响账单。',
    ];
    return PlainPanel(
      padding: const EdgeInsets.all(Spacing.lg),
      children: [
        for (final l in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(l,
                style: TextStyle(
                    fontSize: 14, height: 1.65, color: colors.inkSecondary)),
          ),
      ],
    );
  }
}
