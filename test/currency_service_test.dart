/// STORY-9.3 多币种服务测试。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:plain/core/constants/app_constants.dart';
import 'package:plain/domain/services/currency_service.dart';

void main() {
  test('CurrencyRules symbols cover common currencies', () {
    expect(CurrencyRules.symbols.containsKey('CNY'), isTrue);
    expect(CurrencyRules.symbols.containsKey('USD'), isTrue);
    expect(CurrencyRules.symbolOf('CNY'), '¥');
    expect(CurrencyRules.symbolOf('USD'), r'$');
    expect(CurrencyRules.symbolOf('XYZ'), 'XYZ'); // unknown → code
  });

  test('same currency conversion returns identical values', () {
    final r = CurrencyService.convert(
      originalCents: 12345,
      fromCurrency: 'CNY',
      toCurrency: 'CNY',
    );
    expect(r.convertedCents, 12345);
    expect(r.rate, 1.0);
  });

  test('lockRate and convert uses locked rate', () {
    CurrencyService.lockRate('USD', 'CNY', 7.20);
    expect(CurrencyService.isLocked('USD', 'CNY'), isTrue);
    final r = CurrencyService.convert(
      originalCents: 10000, // $100
      fromCurrency: 'USD',
      toCurrency: 'CNY',
    );
    expect(r.convertedCents, 72000); // ¥720
    expect(r.rate, 7.20);
    CurrencyService.unlockRate('USD', 'CNY');
    expect(CurrencyService.isLocked('USD', 'CNY'), isFalse);
  });

  test('cross-currency transfer requires rate and both amounts', () {
    // 缺汇率
    expect(
      CurrencyService.validateTransfer(
        fromCurrency: 'USD', toCurrency: 'CNY',
        rate: null, fromAmountCents: 10000, toAmountCents: 72000,
      ),
      isNotNull,
    );
    // 有汇率和两边金额
    expect(
      CurrencyService.validateTransfer(
        fromCurrency: 'USD', toCurrency: 'CNY',
        rate: 7.20, fromAmountCents: 10000, toAmountCents: 72000,
      ),
      isNull,
    );
    // 同币种无需校验
    expect(
      CurrencyService.validateTransfer(
        fromCurrency: 'CNY', toCurrency: 'CNY',
        rate: null, fromAmountCents: null, toAmountCents: null,
      ),
      isNull,
    );
  });

  test('dual currency display', () {
    final r = CurrencyService.convert(
      originalCents: 1250,
      fromCurrency: 'USD',
      toCurrency: 'CNY',
      overrideRate: 7.12,
    );
    expect(r.originalDisplay, r'$12.50');
    expect(r.convertedDisplay, '¥89.00');
  });
}
