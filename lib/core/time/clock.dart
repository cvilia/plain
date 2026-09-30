/// Clock abstraction. See 05-B2, 06-D6.
library;

abstract class Clock {
  DateTime now();
  int nowMs() => now().millisecondsSinceEpoch;
  String todayKey() => localDayKey(now());
  String localDayKey(DateTime utc) => dayKeyOf(utc.toLocal());

  static String dayKeyOf(DateTime local) {
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '${local.year}-$m-$d';
  }
}

class SystemClock extends Clock {
  SystemClock();
  @override
  DateTime now() => DateTime.now().toUtc();
}

class FixedClock extends Clock {
  FixedClock(this._now);
  DateTime _now;
  @override
  DateTime now() => _now;
  void advance(Duration d) => _now = _now.add(d);
  void set(DateTime t) => _now = t;
}
