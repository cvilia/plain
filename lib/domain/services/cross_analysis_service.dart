/// STORY-11.3 多维度交叉分析（数据侧）。
///
/// 输出「行维度 × 列维度」的矩阵：单元格金额 + 笔数，另附行列合计与最大值
/// （供页面做热力着色）。纯派生，不涉及渲染。
///
/// 只支持**当前真有数据**的维度：分类 / 账户 / 月份 / 商户 / 金额区间。
library;

import 'package:plain/app/l10n/app_strings.dart';
import 'package:plain/core/constants/app_constants.dart';
import 'package:plain/core/time/clock.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/services/accounting_calendar.dart';
import 'package:plain/app/l10n/strings_domain.dart';
import 'package:plain/app/l10n/strings_core.dart';

/// 参与聚合的一笔账单。
class CrossEntry {
  const CrossEntry({
    required this.cents,
    required this.at,
    required this.isIncome,
    this.categoryId,
    this.accountId,
    this.note,
  });

  final int cents;
  final DateTime at;
  final bool isIncome;
  final String? categoryId;
  final String? accountId;

  /// 备注；「商户」维度沿用备注承载（见 rule_engine 的商户口径）。
  final String? note;
}

/// 一个单元格。
class CrossCell {
  const CrossCell({required this.cents, required this.count});
  final int cents;
  final int count;
}

/// 矩阵表。
class CrossTable {
  const CrossTable({
    required this.rowDim,
    required this.colDim,
    required this.rowKeys,
    required this.rowLabels,
    required this.colKeys,
    required this.colLabels,
    required this.cells,
    required this.rowTotals,
    required this.colTotals,
    required this.grandTotalCents,
    required this.maxCellCents,
  });

  final CrossDimension rowDim;
  final CrossDimension colDim;
  final List<String> rowKeys;
  final List<String> rowLabels;
  final List<String> colKeys;
  final List<String> colLabels;

  /// `rowKey → colKey → cell`。
  final Map<String, Map<String, CrossCell>> cells;
  final Map<String, int> rowTotals;
  final Map<String, int> colTotals;
  final int grandTotalCents;

  /// 最大单元格金额，热力着色用它归一。
  final int maxCellCents;

  bool get isEmpty => rowKeys.isEmpty || colKeys.isEmpty;

  CrossCell? cellAt(String rowKey, String colKey) => cells[rowKey]?[colKey];

  /// AC2：热力强度 0–1（相对最大单元格）。
  double heatOf(String rowKey, String colKey) {
    if (maxCellCents <= 0) return 0;
    final c = cellAt(rowKey, colKey);
    if (c == null) return 0;
    return (c.cents / maxCellCents).clamp(0.0, 1.0);
  }

  static const CrossTable empty = CrossTable(
    rowDim: CrossDimension.category,
    colDim: CrossDimension.month,
    rowKeys: [],
    rowLabels: [],
    colKeys: [],
    colLabels: [],
    cells: {},
    rowTotals: {},
    colTotals: {},
    grandTotalCents: 0,
    maxCellCents: 0,
  );
}

class CrossAnalysisService {
  const CrossAnalysisService();

  CrossTable build({
    required AppStrings s,
    required List<CrossEntry> entries,
    required CrossDimension rowDim,
    required CrossDimension colDim,
    Map<String, String> categoryNames = const {},
    Map<String, String> accountNames = const {},
    required int monthStartDay,
  }) {
    final cells = <String, Map<String, CrossCell>>{};
    final rowLabels = <String, String>{};
    final colLabels = <String, String>{};
    final rowTotals = <String, int>{};
    final colTotals = <String, int>{};
    var grand = 0;
    var maxCell = 0;

    for (final e in entries) {
      if (e.cents <= 0) continue;
      final row = _keyOf(
        e, rowDim, s,
        categoryNames: categoryNames,
        accountNames: accountNames,
        monthStartDay: monthStartDay,
      );
      final col = _keyOf(
        e, colDim, s,
        categoryNames: categoryNames,
        accountNames: accountNames,
        monthStartDay: monthStartDay,
      );
      rowLabels[row.key] = row.label;
      colLabels[col.key] = col.label;

      final byCol =
          cells.putIfAbsent(row.key, () => <String, CrossCell>{});
      final prev = byCol[col.key];
      final next = CrossCell(
        cents: (prev?.cents ?? 0) + e.cents,
        count: (prev?.count ?? 0) + 1,
      );
      byCol[col.key] = next;
      if (next.cents > maxCell) maxCell = next.cents;

      rowTotals[row.key] = (rowTotals[row.key] ?? 0) + e.cents;
      colTotals[col.key] = (colTotals[col.key] ?? 0) + e.cents;
      grand += e.cents;
    }

    // 行按合计降序；列的顺序按维度定（见 _orderCols）
    final rowKeys = rowTotals.keys.toList()
      ..sort((a, b) => rowTotals[b]!.compareTo(rowTotals[a]!));
    final colKeys = _orderCols(colDim, colTotals);

    return CrossTable(
      rowDim: rowDim,
      colDim: colDim,
      rowKeys: rowKeys,
      rowLabels: [for (final k in rowKeys) rowLabels[k] ?? k],
      colKeys: colKeys,
      colLabels: [for (final k in colKeys) colLabels[k] ?? k],
      cells: cells,
      rowTotals: rowTotals,
      colTotals: colTotals,
      grandTotalCents: grand,
      maxCellCents: maxCell,
    );
  }

  /// 列的顺序按维度决定，不能一律按字符串排（中文标签与金额档按字母序没有意义）：
  /// - 月份、金额档：键本身有序（`YYYY-MM` / 档位序号），升序
  /// - 其余维度：按列合计降序，最大的排前面
  List<String> _orderCols(CrossDimension dim, Map<String, int> totals) {
    final keys = totals.keys.toList();
    switch (dim) {
      case CrossDimension.month:
      case CrossDimension.amountRange:
        keys.sort();
      case CrossDimension.category:
      case CrossDimension.account:
      case CrossDimension.merchant:
        keys.sort((a, b) => totals[b]!.compareTo(totals[a]!));
    }
    return keys;
  }

  ({String key, String label}) _keyOf(
    CrossEntry e,
    CrossDimension dim,
    AppStrings s, {
    required Map<String, String> categoryNames,
    required Map<String, String> accountNames,
    required int monthStartDay,
  }) {
    switch (dim) {
      case CrossDimension.category:
        final id = e.categoryId;
        if (id == null) return (key: '__none__', label: s.uncategorized);
        return (key: id, label: categoryNames[id] ?? s.unknownCategory);
      case CrossDimension.account:
        final id = e.accountId;
        if (id == null) return (key: '__none__', label: s.noAccount);
        return (key: id, label: accountNames[id] ?? s.unknownAccount);
      case CrossDimension.month:
        // G-1：月份维度一律走记账月唯一入口
        final key = AccountingCalendar.labelFor(e.at, monthStartDay);
        return (key: key, label: key);
      case CrossDimension.merchant:
        final note = (e.note ?? '').trim();
        if (note.isEmpty) return (key: '__none__', label: s.noMerchant);
        return (key: note, label: note);
      case CrossDimension.amountRange:
        final idx = _rangeIndexOf(e.cents);
        // 键用档位序号，保证列序与档位一致
        return (key: '$idx', label: _rangeLabel(idx, s));
    }
  }

  /// 金额档位序号。
  int _rangeIndexOf(int cents) {
    final b = CrossAnalysisRules.boundsCents;
    for (var i = 0; i < b.length; i++) {
      if (cents < b[i]) return i;
    }
    return b.length;
  }

  String _rangeLabel(int index, AppStrings s) {
    final b = CrossAnalysisRules.boundsCents;
    if (index == 0) return s.crossAmountUnderLabel;
    if (index >= b.length) return s.crossAmountOverLabel;
    return s.crossRangeLabel(b[index - 1] ~/ 100, b[index] ~/ 100);
  }

  /// 便捷：月份标签（G-1 唯一入口）。
  static String monthLabelOf(DateTime utc, int monthStartDay) =>
      AccountingCalendar.labelFor(utc, monthStartDay);

  /// 账单所属的记账月日键前缀（供页面按单元格下钻筛选）。
  static String dayKeyOf(DateTime utc) => Clock.dayKeyOf(utc.toLocal());
}
