/// STORY-9.2 票据文本解析（离线结构化抽取）。
library;
import 'package:flutter_test/flutter_test.dart';
import 'package:plain/domain/services/receipt_parser.dart';

void main() {
  test('AC1 抽取金额、日期与商户', () {
    const text = '星巴克\n2026-09-29\n合计 ¥128.50';
    final d = ReceiptParser.parseText(text);
    expect(d.amountCents, 12850);
    expect(d.merchant, '星巴克');
    expect(d.occurredAt, DateTime(2026, 9, 29));
    // 没有学习记录时不给分类建议（不再有写死的「星巴克 → 餐饮」）
    expect(d.categoryHint, isNull);
  });

  test('分类建议来自**已学到的**商户映射', () {
    const text = '星巴克\n2026-09-29\n合计 ¥128.50';
    final d = ReceiptParser.parseText(
      text,
      merchantToCategory: const {'星巴克': 'preset_food_drink'},
    );
    expect(d.merchant, '星巴克');
    expect(d.categoryHint, 'preset_food_drink');
  });

  test('多个已学商户命中时取最长（更具体）', () {
    const text = '瑞幸咖啡（国贸店）合计 30';
    final d = ReceiptParser.parseText(
      text,
      merchantToCategory: const {
        '瑞幸': 'drink',
        '瑞幸咖啡': 'drink_premium',
      },
    );
    expect(d.merchant, '瑞幸咖啡');
    expect(d.categoryHint, 'drink_premium');
  });

  test('空文本得到空草稿', () {
    expect(ReceiptParser.parseText('').isEmpty, true);
    expect(ReceiptParser.parseText('   ').isEmpty, true);
  });

  test('只有金额时不会把金额行当成商户', () {
    final d = ReceiptParser.parseText('实付 98元');
    expect(d.amountCents, 9800);
    expect(d.merchant, isNull);
  });

  test('金额/单据类行不当作商户名', () {
    for (final text in [
      '合计 56.00',
      '收银台 3',
      '订单号 12345',
      '地址 北京市朝阳区',
      '¥88.00',
    ]) {
      expect(ReceiptParser.parseText(text).merchant, isNull, reason: text);
    }
  });

  test('优先取「合计」附近的金额', () {
    final d = ReceiptParser.parseText('订单号 12345\n合计 56.00\n谢谢');
    expect(d.amountCents, 5600);
  });

  test('首行像店名时取为首行（结构启发，不依赖写死清单）', () {
    final d = ReceiptParser.parseText('楼下小超市\n合计 12.30');
    expect(d.merchant, '楼下小超市');
  });

  test('去掉「商户：」之类的字段前缀', () {
    final d = ReceiptParser.parseText('商户：老王便利店\n合计 9.90');
    expect(d.merchant, '老王便利店');
  });

  test('日期支持多种写法；非法月日不接受', () {
    expect(ReceiptParser.parseText('2026/9/29 合计 10').occurredAt, DateTime(2026, 9, 29));
    expect(ReceiptParser.parseText('2026年9月29日 合计 10').occurredAt, DateTime(2026, 9, 29));
    expect(ReceiptParser.parseText('2026-13-45 合计 10').occurredAt, isNull);
  });

  test('日期与单号不会被当成金额（回归：曾把 2026-01-15 取成 2026）', () {
    final d = ReceiptParser.parseText('2026-01-15 逛街');
    expect(d.amountCents, isNull);
    expect(d.isUsable, isFalse);
    final d2 = ReceiptParser.parseText('订单号 12345\n时间 10:32');
    expect(d2.amountCents, isNull);
    expect(d2.isUsable, isFalse);
  });

  test('summary 只说抽到了什么', () {
    final d = ReceiptParser.parseText('星巴克\n2026-09-29\n合计 ¥128.50');
    expect(d.summary, contains('128.50'));
    expect(d.summary, contains('星巴克'));
    expect(ReceiptParser.parseText('').summary, '没有识别到可用信息');
  });
}
