/// STORY-3.3 安全可花计算测试。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:plain/domain/services/safe_to_spend_service.dart';

void main() {
  test('AC1: safe = available - futureBills - goalAllocation - rigidReserve', () {
    final r = SafeToSpendResult(
      availableCents: 500000,
      futureBillsCents: 120000,
      goalAllocationCents: 80000,
      rigidReserveCents: 100000,
      remainingDays: 20,
      hasAnyBudget: true,
    );
    expect(r.safeToSpendCents, 200000); // 2000 元
    expect(r.dailyAverageCents, 10000); // 100 元
    expect(r.isNegative, isFalse);
  });

  test('AC2: negative result flagged', () {
    final r = SafeToSpendResult(
      availableCents: 100000,
      futureBillsCents: 50000,
      goalAllocationCents: 30000,
      rigidReserveCents: 50000,
      remainingDays: 15,
      hasAnyBudget: true,
    );
    expect(r.safeToSpendCents, -30000);
    expect(r.isNegative, isTrue);
    expect(r.dailyAverageCents, -2000);
  });

  test('remainingDays=0 → dailyAverage returns 0 (div-by-zero guard)', () {
    final r = SafeToSpendResult(
      availableCents: 100000,
      futureBillsCents: 0,
      goalAllocationCents: 0,
      rigidReserveCents: 0,
      remainingDays: 0,
      hasAnyBudget: true,
    );
    expect(r.safeToSpendCents, 100000);
    expect(r.dailyAverageCents, 0);
  });

  test('AC3: hasAnyBudget false hides card', () {
    final r = SafeToSpendResult(
      availableCents: 500000,
      futureBillsCents: 0,
      goalAllocationCents: 0,
      rigidReserveCents: 0,
      remainingDays: 20,
      hasAnyBudget: false,
    );
    expect(r.hasAnyBudget, isFalse);
  });
}
