/// STORY-10.3 资产折旧与增值（纯估算，不改账单）。
library;
import 'package:flutter_test/flutter_test.dart';
import 'package:plain/domain/entities/category.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/services/asset_valuation_service.dart';

void main() {
  const svc = AssetValuationService();

  // AC1 的车辆：原值 20 万、年折旧 −8%、持有 12 个月
  final carStart = DateTime.utc(2025, 1, 10);
  final carNow = DateTime.utc(2026, 1, 10);

  group('AC1 年折旧率', () {
    test('原值 200000、−8%、12 个月 → 估值 184000，原值不变', () {
      final r = svc.evaluate(
        ValuationTerms(
          mode: AssetValuationMode.depreciate,
          baseCents: 20000000, // 200,000 元
          rateBp: -800, // −8%
          manualCents: 0,
          startedAt: carStart,
        ),
        now: carNow,
      );
      expect(r.months, 12);
      expect(r.valueCents, 18400000); // 184,000 元
      expect(r.costCents, 20000000); // 原始成本仍显示 200,000
      expect(r.deltaCents, -1600000);
    });

    test('持有 24 个月按复利递减（不是线性）', () {
      final r = svc.evaluate(
        ValuationTerms(
          mode: AssetValuationMode.depreciate,
          baseCents: 20000000,
          rateBp: -800,
          manualCents: 0,
          startedAt: carStart,
        ),
        now: DateTime.utc(2027, 1, 10),
      );
      // 200000 × 0.92² = 169280
      expect(r.valueCents, 16928000);
    });
  });

  group('AC2 年增值率', () {
    test('原值 3000000、+3%、24 个月 → 约 3182700', () {
      final r = svc.evaluate(
        ValuationTerms(
          mode: AssetValuationMode.appreciate,
          baseCents: 300000000, // 3,000,000 元
          rateBp: 300, // +3%
          manualCents: 0,
          startedAt: DateTime.utc(2025, 6, 1),
        ),
        now: DateTime.utc(2027, 6, 1),
      );
      expect(r.months, 24);
      // 3000000 × 1.03² = 3,182,700
      expect(r.valueCents, 318270000);
    });
  });

  group('AC4 固定值与手动调整', () {
    test('固定值：估值恒等于设定值，不随持有月数变化', () {
      final terms = ValuationTerms(
        mode: AssetValuationMode.fixed,
        baseCents: 20000000,
        rateBp: 0,
        manualCents: 15000000,
        startedAt: carStart,
      );
      expect(svc.evaluate(terms, now: carNow).valueCents, 15000000);
      expect(svc.evaluate(terms, now: DateTime.utc(2030, 1, 10)).valueCents, 15000000);
    });

    test('手动调整：估值等于手填值', () {
      final r = svc.evaluate(
        ValuationTerms(
          mode: AssetValuationMode.manual,
          baseCents: 20000000,
          rateBp: 0,
          manualCents: 1234500,
          startedAt: carStart,
        ),
        now: carNow,
      );
      expect(r.valueCents, 1234500);
    });
  });

  group('边界', () {
    test('未启用估值模式时不参与估算', () {
      expect(
        ValuationTerms.ofAccount(_account(AssetValuationMode.none)),
        isNull,
      );
      expect(
        ValuationTerms.ofAccount(_account(AssetValuationMode.depreciate)),
        isNotNull,
      );
    });

    test('持有月数按自然月计算，不足一月不计', () {
      final start = DateTime.utc(2026, 1, 20);
      expect(svc.monthsHeld(startedAt: start, now: DateTime.utc(2026, 1, 25)), 0);
      expect(svc.monthsHeld(startedAt: start, now: DateTime.utc(2026, 2, 19)), 0);
      expect(svc.monthsHeld(startedAt: start, now: DateTime.utc(2026, 2, 20)), 1);
      expect(svc.monthsHeld(startedAt: null, now: start), 0);
    });

    test('未设起始日时按 0 月处理，估值等于原值', () {
      final r = svc.evaluate(
        ValuationTerms(
          mode: AssetValuationMode.depreciate,
          baseCents: 10000000,
          rateBp: -800,
          manualCents: 0,
          startedAt: null,
        ),
        now: carNow,
      );
      expect(r.months, 0);
      expect(r.valueCents, 10000000);
    });

    test('年率为 0 时估值等于原值；极端折旧不出现负数', () {
      expect(
        svc.compoundAt(baseCents: 10000000, rateBp: 0, months: 24),
        10000000,
      );
      expect(
        svc.compoundAt(baseCents: 10000000, rateBp: -9900, months: 120) >= 0,
        true,
      );
    });
  });
}

/// 仅用于 ofAccount 判定的最小账户。
Account _account(AssetValuationMode mode) => Account(
      id: 'a1', name: '车', type: AccountType.cash,
      currency: 'CNY', openingBalance: 20000000, sortOrder: 0,
      valuationMode: mode,
      valuationBaseCents: 20000000,
      valuationRateBp: -800,
      createdAt: DateTime.utc(2025, 1, 1), updatedAt: DateTime.utc(2025, 1, 1),
      deviceId: 'dev-1',
    );
