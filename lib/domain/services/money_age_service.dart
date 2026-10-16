/// STORY-11.4 资金年龄（Age of Money）。
///
/// 定义：**花掉的每一块钱，其来源收入距花掉那天有多久**，按金额加权平均。
///
/// 算法（FIFO）：把收入按时间排成队列，每笔支出依次消耗**最早尚未耗尽**的收入；
/// 支出日与该收入日的天数差就是这一块钱的「年龄」，再按金额加权。
///
/// 口径要点：
/// - 只消耗“支出当时已经到账”的收入。支出早于任何可用收入（先花后收）时，
///   该部分年龄取 **0** 而非负数（AC2）——这也是 YNAB 式 Age of Money 的做法。
/// - 年龄**越大越从容**：说明钱在手里待得久，不靠当月工资过日子（AC4 的文案方向）。
library;

/// 一笔收入或支出（只取计算所需字段）。
class MoneyLot {
  const MoneyLot({required this.at, required this.cents});
  final DateTime at;
  final int cents;
}

/// 趋势上的一个月。
class MoneyAgePoint {
  const MoneyAgePoint({
    required this.label,
    required this.periodEnd,
    required this.ageDays,
    required this.expenseCents,
  });

  final String label;
  final DateTime periodEnd;

  /// 当月支出的加权平均资金年龄（当月无支出时为 null）。
  final double? ageDays;
  final int expenseCents;
}

/// 资金年龄结果。
class MoneyAgeResult {
  const MoneyAgeResult({
    required this.hasEnoughData,
    required this.currentAgeDays,
    required this.previousAgeDays,
    required this.trend,
    required this.incomeCount,
    required this.expenseCount,
  });

  /// false = 数据积累中（AC3）。
  final bool hasEnoughData;

  /// 当前（最近一个月）的资金年龄（天）。当月无支出时为 null。
  final double? currentAgeDays;

  /// 上个月的资金年龄（天），用于对比。
  final double? previousAgeDays;

  final List<MoneyAgePoint> trend;
  final int incomeCount;
  final int expenseCount;

  /// AC4：年龄变大 = 更从容。
  ///
  /// 返回一句话解读；数据不足或无对比基准时给出相应说明。
  String get interpretation {
    final cur = currentAgeDays;
    final prev = previousAgeDays;
    if (!hasEnoughData || cur == null) return '数据积累中';
    if (prev == null) {
      return '当前约 ${cur.round()} 天：这笔钱从进账到花掉平均等了这么久。';
    }
    final diff = cur - prev;
    if (diff.abs() < 1) {
      return '与上月基本持平（约 ${cur.round()} 天），节奏很稳。';
    }
    if (diff > 0) {
      return '比上月更从容：${prev.round()} 天 → ${cur.round()} 天，'
          '钱在手里多留了约 ${diff.round()} 天。';
    }
    return '比上月吃紧：${prev.round()} 天 → ${cur.round()} 天，'
        '钱花得比上个月快约 ${(-diff).round()} 天。';
  }
}

class MoneyAgeService {
  const MoneyAgeService({
    this.minIncomeCount = 5,
    this.minSpanDays = 60,
  });

  /// 至少这么多笔收入才算“数据够”（不足则显示数据积累中）。
  final int minIncomeCount;

  /// 首末账目跨度至少这么久（约 2 个月）。
  final int minSpanDays;

  /// 逐笔算支出年龄（与输入顺序一一对应，按时间排序后配对）。
  ///
  /// 返回的是「排序后」支出的年龄列表。
  List<double> agesOf({
    required List<MoneyLot> incomes,
    required List<MoneyLot> expenses,
  }) {
    final sortedIn = [...incomes]..sort((a, b) => a.at.compareTo(b.at));
    final sortedEx = [...expenses]..sort((a, b) => a.at.compareTo(b.at));

    var incomeIdx = 0;
    final pending = <_PendingLot>[];
    final ages = <double>[];

    for (final e in sortedEx) {
      // 支出当时已经到账的收入才入队
      while (incomeIdx < sortedIn.length &&
          !sortedIn[incomeIdx].at.isAfter(e.at)) {
        pending.add(_PendingLot(
          at: sortedIn[incomeIdx].at,
          remaining: sortedIn[incomeIdx].cents,
        ));
        incomeIdx++;
      }

      var need = e.cents;
      var weighted = 0.0;
      var consumed = 0;
      for (final lot in pending) {
        if (need <= 0) break;
        if (lot.remaining <= 0) continue;
        final take = lot.remaining < need ? lot.remaining : need;
        final days = e.at.difference(lot.at).inDays;
        weighted += (days < 0 ? 0 : days) * take;
        consumed += take;
        lot.remaining -= take;
        need -= take;
      }
      // 先花后收：没有可用收入覆盖的部分按 0 天计（AC2，不取负数）
      if (need > 0) {
        consumed += need;
      }
      ages.add(consumed == 0 ? 0 : weighted / consumed);
    }
    return ages;
  }

  /// 主计算入口：当前值 + 近几个月趋势 + 解读。
  MoneyAgeResult evaluate({
    required List<MoneyLot> incomes,
    required List<MoneyLot> expenses,
    required List<({String label, DateTime periodEnd, DateTime periodStart})>
        months,
  }) {
    final hasEnough = _hasEnoughData(incomes);
    final sortedEx = [...expenses]..sort((a, b) => a.at.compareTo(b.at));
    final ages = agesOf(incomes: incomes, expenses: sortedEx);

    final trend = <MoneyAgePoint>[];
    for (final m in months) {
      // 该月区间内的支出（含起、不含止）
      var weighted = 0.0;
      var cents = 0;
      for (var i = 0; i < sortedEx.length; i++) {
        final at = sortedEx[i].at;
        if (at.isBefore(m.periodStart)) continue;
        if (!at.isBefore(m.periodEnd)) continue;
        weighted += ages[i] * sortedEx[i].cents;
        cents += sortedEx[i].cents;
      }
      trend.add(MoneyAgePoint(
        label: m.label,
        periodEnd: m.periodEnd,
        ageDays: cents == 0 ? null : weighted / cents,
        expenseCents: cents,
      ));
    }

    // 当前 = 最近一个有支出的月份；上月 = 它前一个
    double? current;
    double? previous;
    for (var i = trend.length - 1; i >= 0; i--) {
      if (trend[i].ageDays != null) {
        current ??= trend[i].ageDays;
        if (current != null && i > 0 && trend[i - 1].ageDays != null) {
          previous = trend[i - 1].ageDays;
        }
        if (current != null && previous != null) break;
      }
    }

    return MoneyAgeResult(
      hasEnoughData: hasEnough,
      currentAgeDays: current,
      previousAgeDays: previous,
      trend: trend,
      incomeCount: incomes.length,
      expenseCount: expenses.length,
    );
  }

  /// AC3：收入笔数不足，或账目跨度不足约两个月 → 数据积累中。
  bool _hasEnoughData(List<MoneyLot> incomes) {
    if (incomes.length < minIncomeCount) return false;
    if (incomes.isEmpty) return false;
    final sorted = [...incomes]..sort((a, b) => a.at.compareTo(b.at));
    final span = sorted.last.at.difference(sorted.first.at).inDays;
    return span >= minSpanDays;
  }

  /// 生成近 [count] 个记账月的区间（[monthStartDay] 来自 G-1）。
  static List<({String label, DateTime periodEnd, DateTime periodStart})>
      recentMonths({
    required DateTime now,
    required int monthStartDay,
    int count = 6,
  }) {
    final out = <({String label, DateTime periodEnd, DateTime periodStart})>[];
    for (var i = count - 1; i >= 0; i--) {
      final start = DateTime(now.year, now.month - i, monthStartDay);
      final end = DateTime(start.year, start.month + 1, monthStartDay);
      out.add((
        label: '${start.year}-${start.month.toString().padLeft(2, '0')}',
        periodStart: DateTime.utc(start.year, start.month, start.day),
        periodEnd: DateTime.utc(end.year, end.month, end.day),
      ));
    }
    return out;
  }
}

class _PendingLot {
  _PendingLot({required this.at, required this.remaining});
  final DateTime at;
  int remaining;
}
