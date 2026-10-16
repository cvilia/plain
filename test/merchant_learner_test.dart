/// STORY-1.6 商户学习：规则式推荐 + 命中累计 + 持久化。
library;
import 'package:flutter_test/flutter_test.dart';
import 'package:plain/core/id/uuid_v7.dart';
import 'package:plain/core/time/clock.dart';
import 'package:plain/data/db/database.dart';
import 'package:plain/data/repositories/merchant_rule_repository.dart';
import 'package:plain/data/sync/change_log_writer.dart';
import 'package:plain/domain/services/merchant_learner.dart';

void main() {
  final now = DateTime.utc(2026, 10, 15, 12);

  MerchantRule rule({
    required String merchant,
    String? categoryId,
    int hitCount = 1,
  }) =>
      MerchantRule(
        id: merchant, bookId: 'book-1', merchant: merchant,
        categoryId: categoryId, hitCount: hitCount,
        createdAt: now, updatedAt: now, deviceId: 'dev-1',
      );

  group('学习', () {
    test('首次学习新建规则，命中次数为 1', () {
      final r = MerchantLearner.learn(
        id: 'm1', bookId: 'book-1', merchant: '瑞幸',
        categoryId: 'preset_food_drink', now: now, deviceId: 'dev-1',
      );
      expect(r.id, 'm1');
      expect(r.categoryId, 'preset_food_drink');
      expect(r.hitCount, 1);
      expect(r.lastCorrectedAt, now);
    });

    test('再次学习同一商户：命中 +1，分类被更新，id 不变', () {
      final first = MerchantLearner.learn(
        id: 'm1', bookId: 'book-1', merchant: '瑞幸',
        categoryId: 'preset_food_drink', now: now, deviceId: 'dev-1',
      );
      final second = MerchantLearner.learn(
        id: 'm2', bookId: 'book-1', merchant: '瑞幸',
        categoryId: 'preset_food_other', now: now, deviceId: 'dev-1',
        existing: first,
      );
      expect(second.id, 'm1'); // 沿用既有 id
      expect(second.hitCount, 2);
      expect(second.categoryId, 'preset_food_other');
      expect(second.revision, first.revision + 1);
    });
  });

  group('推荐', () {
    test('精确命中给 1.0 置信度', () {
      final s = MerchantLearner.suggest(
        merchant: '瑞幸',
        rulesByMerchant: {
          '瑞幸': rule(merchant: '瑞幸', categoryId: 'drink'),
        },
      );
      expect(s, isNotNull);
      expect(s!.categoryId, 'drink');
      expect(s.confidence, 1.0);
    });

    test('包含命中按商户名占备注比例给置信度', () {
      // 「瑞幸」(2) 占「瑞幸咖啡」(4) 的一半 → 0.5，高于 0.3 的下限
      final s = MerchantLearner.suggest(
        merchant: '瑞幸咖啡',
        rulesByMerchant: {
          '瑞幸': rule(merchant: '瑞幸', categoryId: 'drink'),
        },
      );
      expect(s!.categoryId, 'drink');
      expect(s.confidence, closeTo(0.5, 1e-9));
    });

    test('占比过小时置信度有 0.3 下限', () {
      final s = MerchantLearner.suggest(
        merchant: '今天去了很久没去的瑞幸喝了一杯',
        rulesByMerchant: {
          '瑞幸': rule(merchant: '瑞幸', categoryId: 'drink'),
        },
      );
      expect(s!.confidence, 0.3);
    });

    test('大小写不敏感', () {
      final s = MerchantLearner.suggest(
        merchant: 'STARBUCKS',
        rulesByMerchant: {
          'starbucks': rule(merchant: 'starbucks', categoryId: 'drink'),
        },
      );
      expect(s!.categoryId, 'drink');
    });

    test('没有学过的商户返回 null（不再有写死的关键词表兜底）', () {
      expect(
        MerchantLearner.suggest(
          merchant: '肯德基',
          rulesByMerchant: {'瑞幸': rule(merchant: '瑞幸', categoryId: 'drink')},
        ),
        isNull,
      );
      expect(MerchantLearner.suggest(merchant: ' ', rulesByMerchant: const {}), isNull);
    });

    test('包含命中时命中次数高者优先', () {
      final s = MerchantLearner.suggest(
        merchant: '星巴克 咖啡',
        rulesByMerchant: {
          '星巴克': rule(merchant: '星巴克', categoryId: 'low', hitCount: 1),
          '咖啡': rule(merchant: '咖啡', categoryId: 'high', hitCount: 9),
        },
      );
      expect(s!.categoryId, 'high');
    });

    test('Top N 按命中次数排序', () {
      final top = MerchantLearner.topByHits([
        rule(merchant: 'a', hitCount: 1),
        rule(merchant: 'c', hitCount: 9),
        rule(merchant: 'd', hitCount: 5),
      ], n: 2);
      expect(top.map((r) => r.merchant).toList(), ['c', 'd']);
    });

    test('关键词映射只含真正学到的分类', () {
      final map = MerchantLearner.keywordMapOf([
        rule(merchant: '瑞幸', categoryId: 'drink'),
        rule(merchant: '待定'), // 无分类 → 不参与
        rule(merchant: '  ', categoryId: 'x'), // 空商户 → 不参与
      ]);
      expect(map, {'瑞幸': 'drink'});
    });
  });

  group('持久化', () {
    late AppDatabase db;
    late MerchantRuleRepositoryImpl repo;

    setUp(() {
      db = AppDatabase.inMemory();
      repo = MerchantRuleRepositoryImpl(
        db: db, changeLogWriter: ChangeLogWriter(db),
        idGen: UuidV7(), clock: FixedClock(now),
      );
    });
    tearDown(() => db.close());

    test('同一商户重复学习是累加，不产生第二行', () async {
      await repo.learn(bookId: 'book-1', merchant: '瑞幸',
          categoryId: 'drink', deviceId: 'dev-1');
      await repo.learn(bookId: 'book-1', merchant: '瑞幸',
          categoryId: 'drink', deviceId: 'dev-1');
      await repo.learn(bookId: 'book-1', merchant: '瑞幸',
          categoryId: 'food', deviceId: 'dev-1');

      final list = (await repo.listByBook('book-1')).successOrNull!;
      expect(list, hasLength(1));
      expect(list.single.hitCount, 3);
      // 最近一次的分类生效
      expect(list.single.categoryId, 'food');
    });

    test('学到的映射能直接喂给推荐（端到端）', () async {
      await repo.learn(bookId: 'book-1', merchant: '瑞幸',
          categoryId: 'drink', deviceId: 'dev-1');
      final list = (await repo.listByBook('book-1')).successOrNull!;
      final s = MerchantLearner.suggest(
        merchant: '瑞幸咖啡',
        rulesByMerchant: {for (final r in list) r.merchant: r},
      );
      expect(s!.categoryId, 'drink');
    });

    test('空商户或空分类被拒', () async {
      expect(
        (await repo.learn(bookId: 'book-1', merchant: '  ',
                categoryId: 'drink', deviceId: 'dev-1'))
            .isFailure,
        true,
      );
      expect(
        (await repo.learn(bookId: 'book-1', merchant: '瑞幸',
                categoryId: '', deviceId: 'dev-1'))
            .isFailure,
        true,
      );
    });

    test('忘掉后不再参与推荐', () async {
      final r = await repo.learn(bookId: 'book-1', merchant: '瑞幸',
          categoryId: 'drink', deviceId: 'dev-1');
      await repo.forget(r.successOrNull!.id);
      expect((await repo.listByBook('book-1')).successOrNull, isEmpty);
    });

    test('学习写入 change_log', () async {
      await repo.learn(bookId: 'book-1', merchant: '瑞幸',
          categoryId: 'drink', deviceId: 'dev-1');
      await repo.learn(bookId: 'book-1', merchant: '瑞幸',
          categoryId: 'drink', deviceId: 'dev-1');
      final rows = db.raw.select(
          "SELECT COUNT(*) AS c FROM change_log WHERE entity_type = 'merchant_rule'");
      expect(rows.first['c'], 2);
    });
  });
}
