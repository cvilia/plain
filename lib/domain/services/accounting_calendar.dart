/// Accounting calendar. See 06-D6, 08-7.3.
library;

import 'package:plain/core/time/clock.dart';

class AccountingPeriod {
  const AccountingPeriod({required this.dayFrom, required this.dayTo, required this.year, required this.month, required this.label});
  final String dayFrom;
  final String dayTo;
  final int year;
  final int month;
  final String label;
}

class AccountingCalendar {
  AccountingCalendar({required Clock clock, this.monthStartDay = 1}) : _clock = clock;
  final Clock _clock;
  final int monthStartDay;

  /// G-1：某笔账（UTC 时刻）所属的**记账月标签** `YYYY-MM`。
  ///
  /// **全产品唯一的「这笔属于哪个月」入口**——报表分组、交叉分析的月份维度、
  /// 额度重置、月度汇总一律调它，禁止各处自行按自然月算或各自偏移月起始日。
  /// （此前 `TaxService` / `CrossAnalysisService` / `AiRecognitionService`
  /// 各写了一份同样的偏移逻辑，属重复实现。）
  static String labelFor(DateTime utc, int monthStartDay) {
    final local = utc.toLocal();
    var year = local.year;
    var month = local.month;
    if (local.day < monthStartDay) {
      month -= 1;
      if (month == 0) {
        month = 12;
        year -= 1;
      }
    }
    return '$year-${month.toString().padLeft(2, '0')}';
  }

  /// 当前记账月标签。
  String currentLabel() => labelFor(_clock.now(), monthStartDay);

  /// 本笔账（[utc]）是否落在当前记账月内。
  bool isInCurrentPeriod(DateTime utc) =>
      labelFor(utc, monthStartDay) == currentLabel();

  AccountingPeriod currentPeriod() {
    final now = _clock.now().toLocal();
    return periodFor(now.year, now.month);
  }

  AccountingPeriod periodFor(int year, int month, {int? day}) {
    final d = day ?? 1;
    final inThis = d >= monthStartDay;
    final pYear = inThis ? year : (month == 1 ? year - 1 : year);
    final pMonth = inThis ? month : (month == 1 ? 12 : month - 1);
    final start = DateTime(pYear, pMonth, monthStartDay);
    final nextStart = pMonth == 12 ? DateTime(pYear + 1, 1, monthStartDay) : DateTime(pYear, pMonth + 1, monthStartDay);
    final end = nextStart.subtract(const Duration(days: 1));
    return AccountingPeriod(dayFrom: Clock.dayKeyOf(start), dayTo: Clock.dayKeyOf(end), year: pYear, month: pMonth, label: '$pYear-${pMonth.toString().padLeft(2, '0')}');
  }

  AccountingPeriod previousPeriod([AccountingPeriod? from]) {
    final base = from ?? currentPeriod();
    return periodFor(base.month == 1 ? base.year - 1 : base.year, base.month == 1 ? 12 : base.month - 1, day: monthStartDay);
  }

  AccountingPeriod nextPeriod([AccountingPeriod? from]) {
    final base = from ?? currentPeriod();
    return periodFor(base.month == 12 ? base.year + 1 : base.year, base.month == 12 ? 1 : base.month + 1, day: monthStartDay);
  }

  String dayKeyOf(DateTime utc) => _clock.localDayKey(utc);
  String today() => _clock.todayKey();
}
