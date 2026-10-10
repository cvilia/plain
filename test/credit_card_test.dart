/// STORY-2.2 信用卡账单周期。
library;
import 'package:flutter_test/flutter_test.dart';
import 'package:plain/domain/entities/category.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/services/credit_card_service.dart';

void main() {
  test('AC3 bill date rolls to next month bill day', () {
    final bill = CreditCardService.billDateForPurchase(
      purchaseAt: DateTime(2026, 6, 8),
      billDay: 5,
    );
    expect(bill, DateTime(2026, 7, 5));
  });

  test('purchase on bill day goes to next bill', () {
    final bill = CreditCardService.billDateForPurchase(
      purchaseAt: DateTime(2026, 6, 5),
      billDay: 5,
    );
    expect(bill, DateTime(2026, 7, 5));
  });

  test('AC4 amount due = previous unpaid + new - paid', () {
    expect(
      CreditCardService.amountDue(
        previousUnpaidCents: 200000,
        currentNewCents: 300000,
        currentPaidCents: 100000,
      ),
      400000,
    );
  });

  test('AC1/AC2 available limit is derived from debt', () {
    final a = Account(
      id: 'c1', name: '招行', type: AccountType.credit,
      currency: 'CNY', openingBalance: 0, sortOrder: 0,
      creditLimitCents: 2000000, creditDebtCents: 350000,
      createdAt: DateTime.utc(2026), updatedAt: DateTime.utc(2026), deviceId: 'd',
    );
    expect(a.creditAvailableCents, 1650000);
    expect(CreditCardService.availableLimit(a), 1650000);
    expect(a.isOverLimit, false);
  });

  test('AC6 over limit flag', () {
    final a = Account(
      id: 'c1', name: '招行', type: AccountType.credit,
      currency: 'CNY', openingBalance: 0, sortOrder: 0,
      creditLimitCents: 1000, creditDebtCents: 1500,
      createdAt: DateTime.utc(2026), updatedAt: DateTime.utc(2026), deviceId: 'd',
    );
    expect(a.isOverLimit, true);
    expect(a.creditAvailableCents, 0);
  });

  test('interest free days from purchase to due date', () {
    final d = CreditCardService.interestFreeDays(
      purchaseAt: DateTime(2026, 6, 8),
      dueDate: DateTime(2026, 7, 25),
    );
    expect(d, DateTime(2026, 7, 25).difference(DateTime(2026, 6, 8)).inDays);
  });
}
