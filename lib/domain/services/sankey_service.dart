/// STORY-11.2 Sankey 桑基现金流图（数据侧）。
///
/// 结构是双层流向：**收入来源 → 汇总 → 各支出去向**。
/// 只做图数据的派生，不涉及渲染；节点占比不足阈值时并入「其他」（AC5）。
library;

import 'package:plain/app/l10n/app_strings.dart';
import 'package:plain/app/l10n/strings_domain.dart';

/// 维度（AC1/AC2）。
enum SankeyDimension {
  topCategory('top_category'),
  leafCategory('leaf_category'),
  account('account');

  const SankeyDimension(this.wire);
  final String wire;

  String label(AppStrings s) => switch (this) {
        SankeyDimension.topCategory => s.sankeyTopCategory,
        SankeyDimension.leafCategory => s.sankeyLeafCategory,
        SankeyDimension.account => s.account,
      };
}

/// 参与聚合的一笔账单（只需这几个字段）。
class SankeyEntry {
  const SankeyEntry({
    required this.isIncome,
    required this.cents,
    this.categoryId,
    this.accountId,
  });

  final bool isIncome;
  final int cents;
  final String? categoryId;
  final String? accountId;
}

/// 分类的层级信息（一级名用于按一级分类聚合）。
class SankeyCategoryInfo {
  const SankeyCategoryInfo({
    required this.name,
    required this.rootId,
    required this.rootName,
  });

  final String name;
  final String rootId;
  final String rootName;
}

/// 一个节点（收入来源或支出去向）。
class SankeyNode {
  const SankeyNode({
    required this.key,
    required this.label,
    required this.cents,
    required this.isOther,
  });

  /// 下钻用：分类 id 或账户 id；合并产生的「其他」节点为 null。
  final String? key;
  final String label;
  final int cents;

  /// 是否由 < 阈值的节点合并而来。
  final bool isOther;
}

/// 图数据。
class SankeyGraph {
  const SankeyGraph({
    required this.sources,
    required this.targets,
    required this.totalIncomeCents,
    required this.totalExpenseCents,
  });

  final List<SankeyNode> sources;
  final List<SankeyNode> targets;
  final int totalIncomeCents;
  final int totalExpenseCents;

  /// AC4：无收入 / 无支出要给出提示而不是空图。
  bool get hasNoIncome => totalIncomeCents <= 0;
  bool get hasNoExpense => totalExpenseCents <= 0;

  /// 结余（正）或超支（负）。
  int get netCents => totalIncomeCents - totalExpenseCents;

  int get nodeCount => sources.length + targets.length;

  bool get isEmpty => sources.isEmpty && targets.isEmpty;

  static const SankeyGraph empty = SankeyGraph(
    sources: [], targets: [], totalIncomeCents: 0, totalExpenseCents: 0);
}

class SankeyService {
  const SankeyService({this.minShare = 0.01});

  /// 占比低于此值的节点并入「其他」（AC5，默认 1%）。
  final double minShare;

  SankeyGraph build({
    required AppStrings s,
    required List<SankeyEntry> entries,
    required SankeyDimension dimension,
    Map<String, SankeyCategoryInfo> categories = const {},
    Map<String, String> accountNames = const {},
  }) {
    final incomeRaw = <String, _Agg>{};
    final expenseRaw = <String, _Agg>{};

    for (final e in entries) {
      if (e.cents <= 0) continue;
      final bucket = e.isIncome ? incomeRaw : expenseRaw;
      final (groupKey, groupLabel) =
          _groupOf(e, dimension, categories, accountNames, s);
      final agg = bucket.putIfAbsent(
          groupKey, () => _Agg(key: groupKey, label: groupLabel));
      agg.cents += e.cents;
    }

    final sources = _finalize(incomeRaw, s);
    final targets = _finalize(expenseRaw, s);
    return SankeyGraph(
      sources: sources,
      targets: targets,
      totalIncomeCents: sources.fold(0, (s, n) => s + n.cents),
      totalExpenseCents: targets.fold(0, (s, n) => s + n.cents),
    );
  }

  /// 按占比重排 + 小项合并为「其他」，金额降序。
  List<SankeyNode> _finalize(Map<String, _Agg> raw, AppStrings s) {
    if (raw.isEmpty) return const [];
    final all = raw.values.toList()
      ..sort((a, b) => b.cents.compareTo(a.cents));
    final total = all.fold<int>(0, (s, a) => s + a.cents);
    if (total <= 0) return const [];

    final kept = <SankeyNode>[];
    var otherCents = 0;
    for (final a in all) {
      if (a.cents / total < minShare) {
        otherCents += a.cents;
      } else {
        kept.add(SankeyNode(
            key: a.key, label: a.label, cents: a.cents, isOther: false));
      }
    }
    if (otherCents > 0) {
      kept.add(SankeyNode(
          key: null, label: s.other, cents: otherCents, isOther: true));
    }
    return kept;
  }

  /// 返回 (分组键, 展示标签)；分组键为 null 时归入「未归类」。
  (String, String) _groupOf(
    SankeyEntry e,
    SankeyDimension dimension,
    Map<String, SankeyCategoryInfo> categories,
    Map<String, String> accountNames,
    AppStrings s,
  ) {
    switch (dimension) {
      case SankeyDimension.account:
        final id = e.accountId;
        if (id == null) return ('__none__', s.noAccount);
        return (id, accountNames[id] ?? s.unknownAccount);
      case SankeyDimension.topCategory:
        final id = e.categoryId;
        if (id == null) return ('__none__', s.uncategorized);
        final info = categories[id];
        if (info == null) return ('__none__', s.uncategorized);
        return (info.rootId, info.rootName);
      case SankeyDimension.leafCategory:
        final id = e.categoryId;
        if (id == null) return ('__none__', s.uncategorized);
        return (id, categories[id]?.name ?? s.unknownCategory);
    }
  }
}

class _Agg {
  _Agg({required this.key, required this.label});
  final String? key;
  final String label;
  int cents = 0;
}
