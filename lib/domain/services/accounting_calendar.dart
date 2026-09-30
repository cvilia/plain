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
