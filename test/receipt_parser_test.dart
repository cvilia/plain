/// STORY-9.2 票据文本解析骨架。
library;
import 'package:flutter_test/flutter_test.dart';
import 'package:plain/domain/services/receipt_parser.dart';

void main() {
  test('AC1 parse amount merchant and category hint', () {
    const text = '星巴克\n2026-09-29\n合计 ¥128.50';
    final d = ReceiptParser.parseText(text);
    expect(d.amountCents, 12850);
    expect(d.merchant, '星巴克');
    expect(d.occurredAt, DateTime(2026, 9, 29));
    expect(d.categoryHint, '餐饮');
  });

  test('empty text yields empty draft', () {
    expect(ReceiptParser.parseText('').isEmpty, true);
    expect(ReceiptParser.parseText('   ').isEmpty, true);
  });

  test('amount without merchant still parsed', () {
    final d = ReceiptParser.parseText('实付 98元');
    expect(d.amountCents, 9800);
    expect(d.merchant, isNull);
  });

  test('prefers 合计 amount over stray numbers', () {
    final d = ReceiptParser.parseText('订单号 12345\n合计 56.00\n谢谢');
    expect(d.amountCents, 5600);
  });
}
