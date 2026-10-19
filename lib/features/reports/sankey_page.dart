/// SP-3-04 桑基现金流图。
///
/// STORY-11.2：双层流向「收入来源 → 汇总 → 各支出去向」。
/// 图数据全部由 `SankeyService` 从真实账单派生；页面自绘（不引第三方图表库），
/// 节点可点击下钻到对应账单（AC3）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plain/app/bootstrap.dart';
import 'package:plain/app/breakpoints.dart';
import 'package:plain/app/settings/ledger_settings.dart';
import 'package:plain/app/theme/app_colors.dart';
import 'package:plain/app/theme/design_tokens.dart';
import 'package:plain/core/format/amount_formatter.dart';
import 'package:plain/design_system/app_date_picker.dart';
import 'package:plain/design_system/amount_display.dart';
import 'package:plain/design_system/app_empty_state.dart';
import 'package:plain/design_system/plain_icons_v3.dart';
import 'package:plain/design_system/plain_ui.dart';
import 'package:plain/domain/entities/category.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/entities/ledger_entry.dart';
import 'package:plain/domain/services/sankey_service.dart';
import 'package:plain/app/l10n/app_strings.dart';
import 'package:plain/app/l10n/strings_reports.dart';
import 'package:plain/app/l10n/strings_accounts.dart';

const _svc = SankeyService();

/// 时间范围。
enum _Range { thisMonth, last3Months, custom }

class SankeyPage extends ConsumerStatefulWidget {
  const SankeyPage({super.key});

  @override
  ConsumerState<SankeyPage> createState() => _SankeyPageState();
}

class _SankeyPageState extends ConsumerState<SankeyPage> {
  bool _loading = true;
  SankeyDimension _dimension = SankeyDimension.topCategory;
  _Range _range = _Range.thisMonth;
  DateTime? _customFrom;
  DateTime? _customTo;

  SankeyGraph _graph = SankeyGraph.empty;
  List<LedgerEntry> _entries = const [];
  Map<String, Category> _categories = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// 当前时间窗（UTC）。
  ({DateTime from, DateTime to}) _window() {
    final now = ref.read(appDependenciesProvider).clock.now();
    final startDay = ref.read(monthStartDayProvider);
    // 月初/月末按 G-1 的记账月边界
    DateTime monthStart(int offset) {
      final local = now.toLocal();
      return DateTime.utc(local.year, local.month + offset, startDay);
    }

    switch (_range) {
      case _Range.thisMonth:
        return (from: monthStart(0), to: monthStart(1));
      case _Range.last3Months:
        return (from: monthStart(-2), to: monthStart(1));
      case _Range.custom:
        final from = _customFrom ?? monthStart(0);
        final to = _customTo ?? monthStart(1);
        return (from: from, to: to);
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final deps = ref.read(appDependenciesProvider);
    final page = await deps.ledgerRepository.listPage(limit: 5000);
    final cats = await deps.categoryRepository.listAll();
    final accounts = await deps.accountRepository.listAll();
    if (!mounted) return;

    final w = _window();
    final all = page.successOrNull?.items ?? const <LedgerEntry>[];
    // G-2：这是**按分类**的聚合，必须用 countsInCategoryStats（子笔计、父笔不计）。
    // 用 countsInOutflow 会让分割父笔（分类已被清空）把整额落到「未分类」，
    // 而真正带分类的子笔反被排除 —— 整棵分类树都是错的（audit 2026-10-15 发现）。
    final inWindow = [
      for (final e in all)
        if (!e.isDeleted &&
            e.countsInCategoryStats &&
            !e.occurredAt.isBefore(w.from) &&
            e.occurredAt.isBefore(w.to))
          e,
    ];

    final catList = cats.successOrNull ?? const <Category>[];
    final byId = {for (final c in catList) c.id: c};
    // 一级分类信息：二级往上归到根
    final info = <String, SankeyCategoryInfo>{};
    for (final c in catList) {
      final root = _rootOf(c, byId);
      info[c.id] = SankeyCategoryInfo(
        name: c.name,
        rootId: root.id,
        rootName: root.name,
      );
    }

    final graph = _svc.build(
      s: AppStrings.of(context),
      dimension: _dimension,
      categories: info,
      accountNames: {
        for (final a in accounts.successOrNull ?? const <Account>[]) a.id: a.name,
      },
      entries: [
        for (final e in inWindow)
          SankeyEntry(
            isIncome: e.type == EntryType.income,
            cents: e.amount.cents,
            categoryId: e.categoryId,
            accountId: e.accountId,
          ),
      ],
    );

    setState(() {
      _graph = graph;
      _entries = inWindow;
      _categories = byId;
      _loading = false;
    });
  }

  static Category _rootOf(Category c, Map<String, Category> byId) {
    var cur = c;
    var guard = 0;
    while (cur.parentId != null && guard < 10) {
      final parent = byId[cur.parentId];
      if (parent == null) break;
      cur = parent;
      guard++;
    }
    return cur;
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Scaffold(
      appBar: PlainTopBar(title: s.reportSankeyTitle, showBack: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ContentWidthConstraint(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    Spacing.lg, 0, Spacing.lg, Spacing.xl),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: Spacing.sm),
                    child: PlainSeg(
                      items: [for (final d in SankeyDimension.values) d.label(AppStrings.of(context))],
                      selectedIndex: SankeyDimension.values.indexOf(_dimension),
                      onChanged: (i) {
                        setState(() => _dimension = SankeyDimension.values[i]);
                        _load();
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: Spacing.sm),
                    child: PlainSeg(
                      items: [s.sankeyRangeThisMonth, s.sankeyRangeLast3, s.sankeyRangeCustom],
                      selectedIndex: _Range.values.indexOf(_range),
                      onChanged: (i) async {
                        final r = _Range.values[i];
                        if (r == _Range.custom) {
                          await _pickCustomRange();
                          return;
                        }
                        setState(() => _range = r);
                        _load();
                      },
                    ),
                  ),
                  const SizedBox(height: Spacing.sm),
                  // AC4：无收入/无支出给提示而不是空图
                  if (_graph.hasNoIncome)
                    _Hint(
                      icon: PlainIconData.chartLine,
                      text: s.sankeyNoIncomeHint,
                    ),
                  if (_graph.hasNoExpense)
                    _Hint(
                      icon: PlainIconData.chartLine,
                      text: s.sankeyNoExpenseHint,
                    ),
                  if (!_graph.isEmpty) ...[
                    PlainEyebrow(s.sankeyFlowEyebrow),
                    PlainPanel(children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: Spacing.md),
                        child: SizedBox(
                          height: 260,
                          child: _SankeyChart(
                            graph: _graph,
                            onTapNode: _showNodeEntries,
                          ),
                        ),
                      ),
                    ]),
                    PlainEyebrow(s.sankeyDetailEyebrow),
                    PlainPanel(children: [
                      _TotalRow(
                          label: s.sankeyIncomeTotal,
                          cents: _graph.totalIncomeCents,
                          color: context.colors.income),
                      _TotalRow(
                          label: s.sankeyExpenseTotal,
                          cents: _graph.totalExpenseCents,
                          color: context.colors.expense),
                      _TotalRow(
                        label: _graph.netCents >= 0 ? s.balance : s.sankeyOver,
                        cents: _graph.netCents.abs(),
                        color: _graph.netCents >= 0
                            ? context.colors.income
                            : context.colors.expense,
                        bold: true,
                      ),
                    ]),
                  ] else
                    AppEmptyState(
                      icon: PlainIconData.chartLine,
                      title: s.sankeyEmptyTitle,
                      subtitle: s.sankeyEmptySubtitle,
                    ),
                  const SizedBox(height: Spacing.md),
                  _NotePanel(graph: _graph, dimension: _dimension),
                ],
              ),
            ),
    );
  }

  Future<void> _pickCustomRange() async {
    final from = await showAppDatePicker(
      context: context,
      initialDate: _customFrom?.toLocal() ?? DateTime.now(),
      firstDate: DateTime(2015),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (from == null || !mounted) return;
    final to = await showAppDatePicker(
      context: context,
      initialDate: _customTo?.toLocal() ?? from,
      firstDate: from,
      lastDate: DateTime.now().add(const Duration(days: 366)),
    );
    if (to == null || !mounted) return;
    setState(() {
      _range = _Range.custom;
      _customFrom = DateTime.utc(from.year, from.month, from.day);
      // 含当天，故右界取次日
      final end = to.add(const Duration(days: 1));
      _customTo = DateTime.utc(end.year, end.month, end.day);
    });
    _load();
  }

  /// AC3：点节点下钻到该节点的账单明细。
  Future<void> _showNodeEntries(SankeyNode node) async {
    final s = AppStrings.of(context);
    final isIncome = _graph.sources.contains(node);
    final mine = [
      for (final e in _entries)
        if ((e.type == EntryType.income) == isIncome && _matches(node, e)) e,
    ];
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
                  child: Text(s.accountEntriesCount(node.label, mine.length),
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
              child: mine.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(Spacing.lg),
                      child: Text(
                        node.isOther
                            ? s.sankeyOtherHint
                            : s.sankeyNoEntries,
                        style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(ctx).extension<AppColors>()!.inkTertiary),
                      ),
                    )
                  : ListView.builder(
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
                          trailing:
                              AmountDisplay(cents: e.amount.cents, fontSize: 14),
                        );
                      },
                    ),
            ),
          ]),
        ),
      ),
    );
  }

  /// 该账单是否属于某节点（按当前维度判定）。
  bool _matches(SankeyNode node, LedgerEntry e) {
    switch (_dimension) {
      case SankeyDimension.account:
        final id = e.accountId ?? '__none__';
        return node.key == id;
      case SankeyDimension.topCategory:
        final c = e.categoryId == null ? null : _categories[e.categoryId];
        final rootId = c == null ? '__none__' : _rootOf(c, _categories).id;
        return node.key == rootId;
      case SankeyDimension.leafCategory:
        return node.key == (e.categoryId ?? '__none__');
    }
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.icon, required this.text});
  final PlainIconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            PlainIcon(icon, size: 20, color: colors.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text,
                  style: TextStyle(fontSize: 14, color: colors.accent)),
            ),
          ]),
        ),
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.cents,
    required this.color,
    this.bold = false,
  });
  final String label;
  final int cents;
  final Color color;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return PlainRow(
      title: label,
      trailing: Text(
        formatAmountYuan(cents),
        style: TextStyle(
          fontSize: 15,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

/// 自绘双层流向：左右两栏节点 + 中间汇总，用贝塞尔带连接。
class _SankeyChart extends StatelessWidget {
  const _SankeyChart({required this.graph, required this.onTapNode});
  final SankeyGraph graph;
  final ValueChanged<SankeyNode> onTapNode;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return LayoutBuilder(builder: (context, c) {
      final layout = _SankeyLayout.of(
        graph: graph,
        size: Size(c.maxWidth, c.maxHeight),
      );
      return GestureDetector(
        onTapUp: (d) {
          final node = layout.hitTest(d.localPosition);
          if (node != null) onTapNode(node);
        },
        child: CustomPaint(
          size: Size(c.maxWidth, c.maxHeight),
          painter: _SankeyPainter(layout: layout, colors: colors),
        ),
      );
    });
  }
}

/// 布局模型：节点的矩形（同时用于绘制与命中测试）。
class _SankeyLayout {
  const _SankeyLayout({
    required this.sources,
    required this.targets,
    required this.hub,
    required this.totalIncome,
    required this.totalExpense,
  });

  final List<(SankeyNode, Rect)> sources;
  final List<(SankeyNode, Rect)> targets;
  final Rect hub;
  final int totalIncome;
  final int totalExpense;

  static const double _nodeWidth = 14;
  static const double _gap = 6;

  static _SankeyLayout of({required SankeyGraph graph, required Size size}) {
    // 左栏 = 收入来源，右栏 = 支出去向
    final leftNodes = _stack(graph.sources, graph.totalIncomeCents, size);
    final rightNodes =
        _stack(graph.targets, graph.totalExpenseCents, size, right: true);
    // 汇总条：取左右可用高度的较小者居中
    final hubHeight = size.height;
    final hub = Rect.fromLTWH(
      size.width / 2 - _nodeWidth / 2,
      (size.height - hubHeight) / 2,
      _nodeWidth,
      hubHeight,
    );
    return _SankeyLayout(
      sources: leftNodes,
      targets: rightNodes,
      hub: hub,
      totalIncome: graph.totalIncomeCents,
      totalExpense: graph.totalExpenseCents,
    );
  }

  /// 左/右栏节点：按金额占比分配高度（留出间距）。
  static List<(SankeyNode, Rect)> _stack(
    List<SankeyNode> nodes,
    int total,
    Size size, {
    bool right = false,
  }) {
    if (nodes.isEmpty || total <= 0) return const [];
    final gaps = _gap * (nodes.length - 1);
    final usable = (size.height - gaps).clamp(1.0, double.infinity);
    final x = right ? size.width - _nodeWidth : 0.0;
    final out = <(SankeyNode, Rect)>[];
    var y = 0.0;
    for (final n in nodes) {
      final h = (usable * (n.cents / total)).clamp(3.0, usable);
      out.add((n, Rect.fromLTWH(x, y, _nodeWidth, h)));
      y += h + _gap;
    }
    return out;
  }

  SankeyNode? hitTest(Offset p) {
    for (final (n, r) in sources) {
      if (r.inflate(8).contains(p)) return n;
    }
    for (final (n, r) in targets) {
      if (r.inflate(8).contains(p)) return n;
    }
    return null;
  }
}

class _SankeyPainter extends CustomPainter {
  _SankeyPainter({required this.layout, required this.colors});
  final _SankeyLayout layout;
  final AppColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    final incomePaint = Paint()..color = colors.income;
    final expensePaint = Paint()..color = colors.expense;
    final ribbonIn = Paint()..color = colors.income.withValues(alpha: 0.28);
    final ribbonOut = Paint()..color = colors.expense.withValues(alpha: 0.28);

    // 收入 → 汇总
    for (final (_, r) in layout.sources) {
      _ribbon(canvas, r, layout.hub, ribbonIn);
    }
    // 汇总 → 支出
    for (final (_, r) in layout.targets) {
      _ribbon(canvas, layout.hub, r, ribbonOut);
    }

    for (final (_, r) in layout.sources) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(r, const Radius.circular(4)), incomePaint);
    }
    canvas.drawRRect(
        RRect.fromRectAndRadius(layout.hub, const Radius.circular(4)),
        Paint()..color = colors.lineStrong);
    for (final (_, r) in layout.targets) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(r, const Radius.circular(4)), expensePaint);
    }
  }

  /// 从 [a] 到 [b] 的等宽带（三次贝塞尔）。
  void _ribbon(Canvas canvas, Rect a, Rect b, Paint paint) {
    final from = Offset(a.right, a.center.dy);
    final to = Offset(b.left, b.center.dy);
    final thickness =
        ((a.height / (layout.totalIncome <= 0 ? 1 : layout.totalIncome)) *
                (b.height / (layout.totalExpense <= 0 ? 1 : layout.totalExpense))
                    .clamp(0.0, 1.0) *
                40)
            .clamp(2.0, 26.0);
    final dx = (to.dx - from.dx) * 0.45;
    final path = Path()
      ..moveTo(from.dx, from.dy - thickness / 2)
      ..cubicTo(from.dx + dx, from.dy - thickness / 2, to.dx - dx,
          to.dy - thickness / 2, to.dx, to.dy - thickness / 2)
      ..lineTo(to.dx, to.dy + thickness / 2)
      ..cubicTo(to.dx - dx, to.dy + thickness / 2, from.dx + dx,
          from.dy + thickness / 2, from.dx, from.dy + thickness / 2)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SankeyPainter old) =>
      old.layout != layout || old.colors != colors;
}

class _NotePanel extends StatelessWidget {
  const _NotePanel({required this.graph, required this.dimension});
  final SankeyGraph graph;
  final SankeyDimension dimension;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final colors = context.colors;
    final lines = <String>[
      s.sankeyNoteDimension(dimension.label(s)),
      s.sankeyNoteThreshold,
      if (graph.sources.any((n) => n.isOther) ||
          graph.targets.any((n) => n.isOther))
        s.sankeyNoteOtherNode,
      if (graph.netCents != 0)
        graph.netCents > 0
            ? s.sankeyNoteSurplus
            : s.sankeyNoteDeficit,
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
