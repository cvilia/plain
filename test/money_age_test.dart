/// STORY-11.4 资金年龄（FIFO 加权）。
library;
import 'package:flutter_test/flutter_test.dart';
import 'package:plain/app/l10n/strings_core.dart';
import 'package:plain/domain/services/money_age_service.dart';

void main() {
  const svc = MoneyAgeService();
  final d0 = DateTime.utc(2026, 1, 1);

  DateTime day(int n) => d0.add(Duration(days: n));

  group('FIFO 逐笔年龄', () {
    test('支出按时间消耗最早未耗尽的收入', () {
      final ages = svc.agesOf(
        incomes: [
          MoneyLot(at: day(0), cents: 1000),
          MoneyLot(at: day(30), cents: 1000),
        ],
        expenses: [
          MoneyLot(at: day(10), cents: 1000), // 用掉 day0 的那笔 → 10 天
          MoneyLot(at: day(40), cents: 1000), // 用掉 day30 的那笔 → 10 天
        ],
      );
      expect(ages, hasLength(2));
      expect(ages[0], closeTo(10, 1e-9));
      expect(ages[1], closeTo(10, 1e-9));
    });

    test('跨两笔收入时按金额加权', () {
      final ages = svc.agesOf(
        incomes: [
          MoneyLot(at: day(0), cents: 1000),
          MoneyLot(at: day(30), cents: 1000),
        ],
        expenses: [
          MoneyLot(at: day(40), cents: 1500), // 1000 来自 day0（40 天）+ 500 来自 day30（10 天）
        ],
      );
      // (40×1000 + 10×500) / 1500 = 30
      expect(ages.single, closeTo(30, 1e-9));
    });

    test('AC2 先花后收：没有可用收入的部分取 0 天，不取负数', () {
      final ages = svc.agesOf(
        incomes: [MoneyLot(at: day(10), cents: 1000)],
        expenses: [MoneyLot(at: day(0), cents: 1000)],
      );
      expect(ages.single, 0);
      expect(ages.single, greaterThanOrEqualTo(0));
    });

    test('部分超出可用收入时只对覆盖到的部分计龄', () {
      final ages = svc.agesOf(
        incomes: [MoneyLot(at: day(0), cents: 500)],
        expenses: [MoneyLot(at: day(20), cents: 1000)], // 只覆盖 500
      );
      // 500 的年龄 20 天 + 500 未覆盖按 0 天 → (20×500)/1000 = 10
      expect(ages.single, closeTo(10, 1e-9));
    });

    test('收入与支出乱序输入也能正确配对', () {
      final ages = svc.agesOf(
        incomes: [
          MoneyLot(at: day(30), cents: 1000),
          MoneyLot(at: day(0), cents: 1000),
        ],
        expenses: [
          MoneyLot(at: day(40), cents: 1000),
          MoneyLot(at: day(10), cents: 1000),
        ],
      );
      // 排序后：支出 day10 用 day0（10 天）；支出 day40 用 day30（10 天）
      expect(ages, [closeTo(10, 1e-9), closeTo(10, 1e-9)]);
    });
  });

  group('AC3 数据充足判定', () {
    List<MoneyLot> incomesOver(int count, {int spanDays = 120}) {
      final step = count <= 1 ? 0 : spanDays ~/ (count - 1);
      return [
        for (var i = 0; i < count; i++)
          MoneyLot(at: day(i * step), cents: 100000),
      ];
    }

    test('收入笔数不足 5 笔 → 数据积累中', () {
      final r = svc.evaluate(
        incomes: incomesOver(4),
        expenses: [MoneyLot(at: day(60), cents: 10000)],
        months: const [],
      );
      expect(r.hasEnoughData, false);
      expect(r.interpretation(kDefaultAppStrings), '数据积累中');
    });

    test('跨度不足两个月 → 数据积累中', () {
      final r = svc.evaluate(
        incomes: [
          for (var i = 0; i < 6; i++)
            MoneyLot(at: day(i * 5), cents: 100000), // 跨度仅 25 天
        ],
        expenses: [MoneyLot(at: day(30), cents: 10000)],
        months: const [],
      );
      expect(r.hasEnoughData, false);
    });

    test('笔数与跨度都够 → 有数据', () {
      final r = svc.evaluate(
        incomes: incomesOver(6),
        expenses: [MoneyLot(at: day(100), cents: 10000)],
        months: const [],
      );
      expect(r.hasEnoughData, true);
    });
  });

  group('AC1 趋势与当前值', () {
    test('按月给出加权平均，当月无支出时为 null', () {
      final now = DateTime(2026, 3, 15);
      final months =
          MoneyAgeService.recentMonths(now: now, monthStartDay: 1, count: 3);
      expect(months.map((m) => m.label).toList(), ['2026-01', '2026-02', '2026-03']);

      final r = svc.evaluate(
        incomes: [
          for (var i = 0; i < 6; i++)
            MoneyLot(at: DateTime.utc(2025, 12, 1 + i * 10), cents: 100000),
        ],
        expenses: [
          // 1 月 15 日花掉最早那笔（12/1）→ 45 天
          MoneyLot(at: DateTime.utc(2026, 1, 15), cents: 100000),
        ],
        months: months,
      );
      expect(r.trend, hasLength(3));
      expect(r.trend[0].ageDays, closeTo(45, 1e-9));
      expect(r.trend[1].ageDays, isNull); // 2 月没花钱
      expect(r.trend[2].ageDays, isNull); // 3 月没花钱
      // 当前取最近一个有支出的月
      expect(r.currentAgeDays, closeTo(45, 1e-9));
    });

    test('当前与上月都可比时给出两者', () {
      final now = DateTime(2026, 3, 15);
      final months =
          MoneyAgeService.recentMonths(now: now, monthStartDay: 1, count: 3);
      final r = svc.evaluate(
        incomes: [
          for (var i = 0; i < 6; i++)
            MoneyLot(at: DateTime.utc(2025, 12, 1 + i * 5), cents: 100000),
        ],
        expenses: [
          MoneyLot(at: DateTime.utc(2026, 1, 20), cents: 50000),
          MoneyLot(at: DateTime.utc(2026, 2, 20), cents: 50000),
        ],
        months: months,
      );
      expect(r.currentAgeDays, isNotNull);
      expect(r.previousAgeDays, isNotNull);
      expect(r.currentAgeDays, greaterThan(r.previousAgeDays!));
    });
  });

  group('AC4 解读文案方向：年龄越大越从容', () {
    MoneyAgeResult result({double? cur, double? prev, bool enough = true}) =>
        MoneyAgeResult(
          hasEnoughData: enough,
          currentAgeDays: cur,
          previousAgeDays: prev,
          trend: const [],
          incomeCount: 6,
          expenseCount: 6,
        );

    test('43 天 vs 上月 35 天 → 正向表述', () {
      final text = result(cur: 43, prev: 35).interpretation(kDefaultAppStrings);
      expect(text, contains('更从容'));
      expect(text, contains('35'));
      expect(text, contains('43'));
    });

    test('变小则提示吃紧', () {
      final text = result(cur: 28, prev: 40).interpretation(kDefaultAppStrings);
      expect(text, contains('吃紧'));
    });

    test('基本持平给出中性表述', () {
      expect(result(cur: 40, prev: 40).interpretation(kDefaultAppStrings), contains('持平'));
    });

    test('数据不足时统一显示数据积累中', () {
      expect(result(cur: 43, prev: 35, enough: false).interpretation(kDefaultAppStrings), '数据积累中');
    });
  });
}
