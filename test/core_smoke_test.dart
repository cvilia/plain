/// Core smoke tests.
library;
import 'package:flutter_test/flutter_test.dart';
import 'package:plain/core/id/uuid_v7.dart';
import 'package:plain/core/money/expression_evaluator.dart';
import 'package:plain/core/money/money.dart';
import 'package:plain/core/time/clock.dart';
import 'package:plain/domain/entities/enums.dart';

void main() {
  test('Money parse and format', () {
    expect(const Money(2500).toYuanString(), '25.00');
    expect(Money.parseYuan('25.5').toYuanString(), '25.50');
    expect(Money.parseYuan('12.34').toYuanString(), '12.34');
    expect(const Money(123456789).toYuanGrouped(), '1,234,567.89');
  });

  test('Expression evaluator', () {
    const eval = ExpressionEvaluator();
    expect(eval.eval('25').money.toYuanString(), '25.00');
    expect(eval.eval('12.5+7.5').money.toYuanString(), '20.00');
    expect(eval.eval('100-30').money.toYuanString(), '70.00');
    expect(eval.eval('25+').wasIncomplete, true);
    expect(eval.eval('25+').money.toYuanString(), '25.00');
  });

  test('Clock day key', () {
    final fixed = FixedClock(DateTime.utc(2026, 9, 29, 12));
    expect(fixed.todayKey(), isNotEmpty);
    expect(Clock.dayKeyOf(DateTime(2026, 9, 29)), '2026-09-29');
  });

  test('UUID v7 generates 26-char ids', () {
    final id = UuidV7().generate();
    expect(id.length, 26);
    expect(UuidV7.isValid(id), true);
  });

  test('Enum wire roundtrip', () {
    expect(EntryType.fromWire('expense'), EntryType.expense);
    expect(EntryType.fromWire('unknown_value'), EntryType.unknown);
    expect(EntryType.expense.wire, 'expense');
  });
}
