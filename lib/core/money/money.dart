/// Money value object: int64 cents, never double.
/// See 04-5.1, 08-4.1, 05-B1.
library;

import 'dart:math' as math;

class Money implements Comparable<Money> {
  const Money(this.cents);

  factory Money.parseYuan(String yuanStr) {
    final s = yuanStr.trim();
    if (s.isEmpty) return Money.zero;
    final neg = s.startsWith('-');
    final body = neg ? s.substring(1) : s;
    final parts = body.split('.');
    if (parts.length > 2) throw FormatException('Invalid yuan: $yuanStr');
    final yuanPart = parts[0].isEmpty ? '0' : parts[0];
    var centPart = parts.length == 2 ? parts[1] : '';
    if (centPart.length > 2) centPart = centPart.substring(0, 2);
    while (centPart.length < 2) {
      centPart = '${centPart}0';
    }
    final total = int.parse(yuanPart) * 100 + int.parse(centPart);
    return Money(neg ? -total : total);
  }

  static const Money zero = Money(0);
  static const int maxCents = 9999999999;

  final int cents;

  bool get isZero => cents == 0;
  bool get isNegative => cents < 0;
  bool get isPositive => cents > 0;

  Money operator +(Money other) => Money(cents + other.cents);
  Money operator -(Money other) => Money(cents - other.cents);
  Money operator -() => Money(-cents);
  Money operator *(int factor) => Money(cents * factor);

  @override
  int compareTo(Money other) => cents.compareTo(other.cents);

  bool operator <(Money other) => cents < other.cents;
  bool operator <=(Money other) => cents <= other.cents;
  bool operator >(Money other) => cents > other.cents;
  bool operator >=(Money other) => cents >= other.cents;

  @override
  bool operator ==(Object other) => other is Money && other.cents == cents;

  @override
  int get hashCode => cents.hashCode;

  String toYuanString({bool forceSign = false}) {
    final neg = cents < 0;
    final abs = cents.abs();
    final s = '${abs ~/ 100}.${(abs % 100).toString().padLeft(2, '0')}';
    if (neg) return '-$s';
    if (forceSign && cents > 0) return '+$s';
    return s;
  }

  String toYuanGrouped({bool forceSign = false}) {
    final raw = toYuanString();
    final neg = raw.startsWith('-');
    final body = neg ? raw.substring(1) : raw;
    final dot = body.indexOf('.');
    final intPart = dot < 0 ? body : body.substring(0, dot);
    final decPart = dot < 0 ? '' : body.substring(dot);
    final buf = StringBuffer();
    for (var i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) buf.write(',');
      buf.write(intPart[i]);
    }
    final core = '$buf$decPart';
    if (neg) return '-$core';
    if (forceSign && cents > 0) return '+$core';
    return core;
  }

  String toYuanAbbrev() {
    final abs = cents.abs();
    final sign = cents < 0 ? '-' : '';
    if (abs >= 10000000000) return '$sign${_trim(abs / 10000000000)}yi';
    if (abs >= 1000000) return '$sign${_trim(abs / 1000000)}wan';
    return toYuanString();
  }

  static String _trim(double v) {
    final s = v.toStringAsFixed(1);
    return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
  }

  @override
  String toString() => 'Money(${toYuanString()})';

  Money abs() => Money(cents.abs());
  Money clampToLimit() => Money(math.min(math.max(cents, -maxCents), maxCents));
  bool get withinProductLimit => cents.abs() <= maxCents;
}
