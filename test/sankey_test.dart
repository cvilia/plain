/// STORY-11.2 Sankey 图数据派生。
library;
import 'package:flutter_test/flutter_test.dart';
import 'package:plain/app/l10n/strings_core.dart';
import 'package:plain/domain/services/sankey_service.dart';

void main() {
  const svc = SankeyService();

  // 一级分类：food(餐饮) / life(生活)；food 下有两个二级
  const cats = <String, SankeyCategoryInfo>{
    'food': SankeyCategoryInfo(name: '餐饮', rootId: 'food', rootName: '餐饮'),
    'food_lunch': SankeyCategoryInfo(name: '午餐', rootId: 'food', rootName: '餐饮'),
    'food_dinner': SankeyCategoryInfo(name: '晚餐', rootId: 'food', rootName: '餐饮'),
    'life': SankeyCategoryInfo(name: '生活', rootId: 'life', rootName: '生活'),
  };
  const accounts = <String, String>{'acc-a': '工资卡', 'acc-b': '招行信用卡'};

  group('AC1 收入来源与支出去向', () {
    test('按一级分类聚合，收入与支出各自成组且合计正确', () {
      final g = svc.build(
        dimension: SankeyDimension.topCategory,
        categories: cats,
        accountNames: accounts,
        entries: const [
          // 收入两笔
          SankeyEntry(isIncome: true, cents: 1000000, accountId: 'acc-a'),
          SankeyEntry(isIncome: true, cents: 200000, accountId: 'acc-a'),
          // 支出：餐饮（含两个二级）+ 生活
          SankeyEntry(isIncome: false, cents: 30000, categoryId: 'food_lunch'),
          SankeyEntry(isIncome: false, cents: 20000, categoryId: 'food_dinner'),
          SankeyEntry(isIncome: false, cents: 50000, categoryId: 'life'),
        ],
        s: kDefaultAppStrings,
      );
      // 收入未指定分类 → 归「未分类」
      expect(g.sources, hasLength(1));
      expect(g.sources.first.label, '未分类');
      expect(g.sources.first.cents, 1200000);
      expect(g.totalIncomeCents, 1200000);

      // 二级归并到一级：餐饮 50000 + 生活 50000
      expect(g.targets, hasLength(2));
      expect(g.targets.first.label, '餐饮');
      expect(g.targets.first.cents, 50000);
      expect(g.targets.first.key, 'food');
      expect(g.targets.last.label, '生活');
      expect(g.totalExpenseCents, 100000);
      expect(g.netCents, 1100000);
    });

    test('二级分类维度下不归并', () {
      final g = svc.build(
        dimension: SankeyDimension.leafCategory,
        categories: cats,
        entries: const [
          SankeyEntry(isIncome: false, cents: 30000, categoryId: 'food_lunch'),
          SankeyEntry(isIncome: false, cents: 20000, categoryId: 'food_dinner'),
        ],
        s: kDefaultAppStrings,
      );
      expect(g.targets.map((n) => n.label).toList(), ['午餐', '晚餐']);
    });
  });

  group('AC2 切维度到账户', () {
    test('按账户聚合，含未指定账户', () {
      final g = svc.build(
        dimension: SankeyDimension.account,
        accountNames: accounts,
        entries: const [
          SankeyEntry(isIncome: false, cents: 30000, accountId: 'acc-b'),
          SankeyEntry(isIncome: false, cents: 10000, accountId: 'acc-b'),
          SankeyEntry(isIncome: false, cents: 5000),
        ],
        s: kDefaultAppStrings,
      );
      expect(g.targets, hasLength(2));
      expect(g.targets.first.label, '招行信用卡');
      expect(g.targets.first.cents, 40000);
      expect(g.targets.last.label, '未指定账户');
    });
  });

  group('AC4 空态', () {
    test('无收入时标记 hasNoIncome', () {
      final g = svc.build(
        dimension: SankeyDimension.topCategory,
        categories: cats,
        entries: const [
          SankeyEntry(isIncome: false, cents: 10000, categoryId: 'life'),
        ],
        s: kDefaultAppStrings,
      );
      expect(g.hasNoIncome, true);
      expect(g.hasNoExpense, false);
    });

    test('无支出时标记 hasNoExpense', () {
      final g = svc.build(
        dimension: SankeyDimension.topCategory,
        entries: const [SankeyEntry(isIncome: true, cents: 10000)],
        s: kDefaultAppStrings,
      );
      expect(g.hasNoExpense, true);
      expect(g.hasNoIncome, false);
    });

    test('完全没有账目时图为空', () {
      final g = svc.build(
          entries: const [], dimension: SankeyDimension.topCategory, s: kDefaultAppStrings);
      expect(g.isEmpty, true);
      expect(g.hasNoIncome, true);
      expect(g.hasNoExpense, true);
    });
  });

  group('AC5 占比不足 1% 并入「其他」', () {
    test('0.5% 的分类被并入其他，且键为 null', () {
      // 支出合计 20000 + 100 = 20100；100 占 0.498% < 1%
      final g = svc.build(
        dimension: SankeyDimension.leafCategory,
        categories: cats,
        entries: const [
          SankeyEntry(isIncome: false, cents: 20000, categoryId: 'life'),
          SankeyEntry(isIncome: false, cents: 99, categoryId: 'food_lunch'),
        ],
        s: kDefaultAppStrings,
      );
      expect(g.targets.map((n) => n.label).toList(), ['生活', '其他']);
      final other = g.targets.last;
      expect(other.isOther, true);
      expect(other.key, isNull);
      expect(other.cents, 99);
      // 合并后总额不变
      expect(g.totalExpenseCents, 20099);
    });

    test('恰好达到阈值的分类保留', () {
      // 1000 / 100000 = 1.0% 不小于阈值 → 保留
      final g = svc.build(
        dimension: SankeyDimension.leafCategory,
        categories: cats,
        entries: const [
          SankeyEntry(isIncome: false, cents: 99000, categoryId: 'life'),
          SankeyEntry(isIncome: false, cents: 1000, categoryId: 'food_lunch'),
        ],
        s: kDefaultAppStrings,
      );
      expect(g.targets.map((n) => n.label).toList(), ['生活', '午餐']);
      expect(g.targets.any((n) => n.isOther), false);
    });
  });

  group('AC6 规模性能', () {
    test('500 个节点规模下构建远快于 800ms', () {
      final entries = [
        for (var i = 0; i < 500; i++)
          SankeyEntry(
            isIncome: false,
            cents: 1000 + i,
            categoryId: i % 2 == 0 ? 'life' : 'food',
          ),
      ];
      final sw = Stopwatch()..start();
      final g = svc.build(
        dimension: SankeyDimension.topCategory,
        entries: entries,
        categories: cats,
        s: kDefaultAppStrings,
      );
      sw.stop();
      expect(g.targets, hasLength(2));
      expect(sw.elapsedMilliseconds, lessThan(800));
    });
  });
}
