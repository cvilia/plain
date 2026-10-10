/// STORY-1.6 商户学习测试。
library;
import 'package:flutter_test/flutter_test.dart';
import 'package:plain/domain/services/merchant_learner.dart';

void main() {
  test('learn increments hit count and updates category', () {
    final now = DateTime.utc(2026, 9, 29);
    final r1 = MerchantLearner.learn(
      id: 'm1', bookId: 'b', merchant: '星巴克', categoryId: 'c1', now: now,
    );
    expect(r1.hitCount, 1);
    final r2 = MerchantLearner.learn(
      id: 'm1', bookId: 'b', merchant: '星巴克', categoryId: 'c2', now: now, existing: r1,
    );
    expect(r2.hitCount, 2);
    expect(r2.categoryId, 'c2');
  });

  test('suggest returns learned category', () {
    final rule = MerchantRule(
      id: 'm1', bookId: 'b', merchant: '瑞幸', categoryId: 'drink', hitCount: 3,
    );
    final map = {'瑞幸': rule};
    expect(MerchantLearner.suggest(merchant: '瑞幸', rulesByMerchant: map), 'drink');
    expect(MerchantLearner.suggest(merchant: '肯德基', rulesByMerchant: map), isNull);
  });

  test('topByHits sorts by hit count', () {
    final rules = [
      const MerchantRule(id: 'a', bookId: 'b', merchant: 'A', categoryId: 'x', hitCount: 1),
      const MerchantRule(id: 'c', bookId: 'b', merchant: 'C', categoryId: 'y', hitCount: 9),
      const MerchantRule(id: 'd', bookId: 'b', merchant: 'D', categoryId: 'z', hitCount: 5),
    ];
    final top = MerchantLearner.topByHits(rules, n: 2);
    expect(top.first.merchant, 'C');
    expect(top.length, 2);
  });
}
