/// STORY-11.5 税务 / 可抵扣支出报表（数据侧）。
///
/// 「可抵扣」是**分类上的标记**（`categories.is_deductible`）；与刚性支出同规则：
/// 一级分类可标，二级**继承其根分类**的标记。
///
/// 年度口径按**自然年**（税务年度即自然年），记账月口径按 G-1 的月起始日。
library;

import 'package:plain/core/time/clock.dart';
import 'package:plain/domain/services/accounting_calendar.dart';

/// 一笔参与汇总的支出。
class TaxEntry {
  const TaxEntry({
    required this.cents,
    required this.at,
    this.categoryId,
  });

  final int cents;
  final DateTime at;
  final String? categoryId;
}

/// 分类的可抵扣标记与层级（用于二级继承根分类）。
class TaxCategoryInfo {
  const TaxCategoryInfo({
    required this.name,
    required this.isDeductible,
    this.parentId,
  });

  final String name;
  final bool isDeductible;
  final String? parentId;
}

/// 报表里的一行（一个分类）。
class TaxLine {
  const TaxLine({
    required this.categoryId,
    required this.name,
    required this.cents,
    required this.count,
  });

  final String? categoryId;
  final String name;
  final int cents;
  final int count;
}

/// 一个申报周期的汇总。
class TaxSummary {
  const TaxSummary({
    required this.periodKey,
    required this.lines,
    required this.isFiled,
    required this.filedAt,
  });

  final String periodKey;
  final List<TaxLine> lines;

  /// AC3：该周期是否已标记申报。
  final bool isFiled;
  final DateTime? filedAt;

  /// AC2：可抵扣支出合计。
  int get totalCents => lines.fold(0, (s, l) => s + l.cents);
  int get totalCount => lines.fold(0, (s, l) => s + l.count);

  bool get isEmpty => lines.isEmpty;

  static const TaxSummary empty = TaxSummary(
    periodKey: '', lines: [], isFiled: false, filedAt: null);
}

class TaxService {
  const TaxService();

  /// 汇总某个周期的可抵扣支出（AC1/AC2）。
  ///
  /// [periodKey] 为记账月 `YYYY-MM` 或年度 `YYYY`。
  TaxSummary summarize({
    required List<TaxEntry> entries,
    required Map<String, TaxCategoryInfo> categories,
    required String periodKey,
    required int monthStartDay,
    required bool isFiled,
    DateTime? filedAt,
  }) {
    final byLine = <String, TaxLine>{};
    final isYear = periodKey.length == 4;

    for (final e in entries) {
      if (e.cents <= 0) continue;
      if (!_inPeriod(e.at, periodKey, isYear: isYear, monthStartDay: monthStartDay)) {
        continue;
      }
      final id = e.categoryId;
      if (id == null) continue;
      if (!isDeductible(id, categories)) continue;

      final name = categories[id]?.name ?? '未知分类';
      final prev = byLine[id];
      byLine[id] = TaxLine(
        categoryId: id,
        name: name,
        cents: (prev?.cents ?? 0) + e.cents,
        count: (prev?.count ?? 0) + 1,
      );
    }

    final lines = byLine.values.toList()
      ..sort((a, b) => b.cents.compareTo(a.cents));
    return TaxSummary(
      periodKey: periodKey,
      lines: lines,
      isFiled: isFiled,
      filedAt: filedAt,
    );
  }

  /// 分类是否可抵扣：自身标记为真，或它的根分类标记为真（二级继承）。
  bool isDeductible(String categoryId, Map<String, TaxCategoryInfo> categories) {
    final info = categories[categoryId];
    if (info == null) return false;
    if (info.isDeductible) return true;
    if (info.parentId == null) return false;
    // 沿 parentId 上溯找根
    var cur = categories[info.parentId];
    var guard = 0;
    while (cur != null && guard < 10) {
      if (cur.isDeductible) return true;
      if (cur.parentId == null) break;
      cur = categories[cur.parentId];
      guard++;
    }
    return false;
  }

  /// 账单是否落在 [periodKey] 周期内。
  bool _inPeriod(
    DateTime utc,
    String periodKey, {
    required bool isYear,
    required int monthStartDay,
  }) {
    final local = utc.toLocal();
    if (isYear) {
      // 年度按自然年
      return local.year == int.tryParse(periodKey);
    }
    return accountingMonthOf(utc, monthStartDay) == periodKey;
  }

  /// 支出所属的记账月标签（G-1 唯一入口）。
  static String accountingMonthOf(DateTime utc, int monthStartDay) =>
      AccountingCalendar.labelFor(utc, monthStartDay);

  static String dayKeyOf(DateTime utc) => Clock.dayKeyOf(utc.toLocal());

  /// 可选的申报周期列表（最近 [months] 个记账月 + 涉及到的年度）。
  static List<({String key, String label, bool isYear})> periodOptions({
    required DateTime now,
    required int monthStartDay,
    int months = 12,
  }) {
    final out = <({String key, String label, bool isYear})>[];
    final local = now.toLocal();
    final years = <int>{local.year};
    for (var i = 0; i < months; i++) {
      final key = accountingMonthOf(
        DateTime.utc(local.year, local.month - i, local.day),
        monthStartDay,
      );
      years.add(int.parse(key.substring(0, 4)));
      out.add((key: key, label: key, isYear: false));
    }
    for (final y in years.toList()..sort((a, b) => b.compareTo(a))) {
      out.add((key: '$y', label: '$y 年度', isYear: true));
    }
    return out;
  }
}
