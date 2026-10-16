/// STORY-10.1 投资持仓：加权平均成本、已实现盈亏、净值贡献（AC1–AC5）。
library;
import 'package:flutter_test/flutter_test.dart';
import 'package:plain/data/db/database.dart';
import 'package:plain/data/repositories/holding_repository.dart';
import 'package:plain/data/sync/change_log_writer.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/entities/holding.dart';
import 'package:plain/domain/services/holding_service.dart';

void main() {
  const svc = HoldingService();
  final now = DateTime.utc(2026, 10, 15, 12);

  Holding make({
    int shares = 0,
    int costPrice = 0,
    int lastPrice = 0,
    int realized = 0,
  }) =>
      Holding(
        id: 'h1', bookId: 'book-1', accountId: 'acc-inv',
        name: '沪深300', assetType: AssetType.fund,
        sharesX10000: Quantity.fromUnits(shares.toDouble()),
        costPriceCents: costPrice,
        lastPriceCents: lastPrice,
        realizedPnlCents: realized,
        createdAt: now, updatedAt: now, deviceId: 'dev-1',
      );

  group('AC2 加权平均成本', () {
    test('10 元买 100 份、12 元再买 100 份 → 均价 11 元', () {
      var h = make();
      h = svc.buy(h, sharesX10000: Quantity.fromUnits(100), unitPriceCents: 1000, at: now);
      expect(h.costPriceCents, 1000);
      h = svc.buy(h, sharesX10000: Quantity.fromUnits(100), unitPriceCents: 1200, at: now);
      // (100×10 + 100×12) / 200 = 11 元
      expect(h.costPriceCents, 1100);
      expect(Quantity.label(h.sharesX10000), '200');
      // 成本基础 = 200 份 × 11 元
      expect(h.costBasisCents, 220000);
    });

    test('买入同时会补上首次现价（未录入时）', () {
      var h = make();
      h = svc.buy(h, sharesX10000: Quantity.fromUnits(10), unitPriceCents: 1000, at: now);
      expect(h.hasPrice, true);
      expect(h.lastPriceCents, 1000);
      expect(h.priceUpdatedAt, now);
    });

    test('已有现价时买入不覆盖现价', () {
      var h = make(lastPrice: 1500);
      h = svc.buy(h, sharesX10000: Quantity.fromUnits(10), unitPriceCents: 1000, at: now);
      expect(h.lastPriceCents, 1500);
    });
  });

  group('AC3 卖出与已实现盈亏', () {
    test('成本 11 元、卖价 15 元、卖 50 份 → 已实现盈亏 200 元', () {
      var h = make(shares: 200, costPrice: 1100);
      final r = svc.sell(h, sharesX10000: Quantity.fromUnits(50), unitPriceCents: 1500, at: now);
      expect(r.realizedCents, 20000); // 200 元
      expect(Quantity.label(r.holding.sharesX10000), '150');
      // 卖出不改变加权均价
      expect(r.holding.costPriceCents, 1100);
      expect(r.holding.realizedPnlCents, 20000);
    });

    test('多次卖出的已实现盈亏累加', () {
      var h = make(shares: 100, costPrice: 1000);
      final a = svc.sell(h, sharesX10000: Quantity.fromUnits(30), unitPriceCents: 1200, at: now);
      final b = svc.sell(a.holding, sharesX10000: Quantity.fromUnits(20), unitPriceCents: 1300, at: now);
      // (12−10)×30 = 60 元；(13−10)×20 = 60 元
      expect(a.realizedCents, 6000);
      expect(b.realizedCents, 6000);
      expect(b.holding.realizedPnlCents, 12000);
    });

    test('亏损卖出得到负数已实现盈亏', () {
      var h = make(shares: 100, costPrice: 1000);
      final r = svc.sell(h, sharesX10000: Quantity.fromUnits(50), unitPriceCents: 800, at: now);
      expect(r.realizedCents, -10000);
    });

    test('卖出份额超过持有量被拒绝且不改变持仓', () {
      final h = make(shares: 10, costPrice: 1000);
      expect(svc.validateSell(h, Quantity.fromUnits(20)).isFailure, true);
      final r = svc.sell(h, sharesX10000: Quantity.fromUnits(20), unitPriceCents: 1200, at: now);
      expect(r.realizedCents, 0);
      expect(r.holding.sharesX10000, h.sharesX10000);
    });
  });

  group('AC4/AC5 行情与净值', () {
    test('未录入现价时不算市值，并可标注更新时间', () {
      final h = make(shares: 100, costPrice: 1000);
      expect(h.hasPrice, false);
      expect(h.marketValueCents, 0);

      final priced = svc.updatePrice(h, priceCents: 1300, at: now);
      expect(priced.hasPrice, true);
      expect(priced.priceUpdatedAt, now);
      // 100 份 × 13 元
      expect(priced.marketValueCents, 130000);
      expect(priced.unrealizedPnlCents, 30000);
    });

    test('AC1 投资账户净值 = 持仓市值 + 现金余额', () {
      final summary = HoldingsSummary.of(
        holdings: [
          make(shares: 100, costPrice: 1000, lastPrice: 1300),
          Holding(
            id: 'h2', bookId: 'book-1', accountId: 'acc-inv', name: '某股票',
            assetType: AssetType.stock,
            sharesX10000: Quantity.fromUnits(200), costPriceCents: 400,
            lastPriceCents: 500, createdAt: now, updatedAt: now, deviceId: 'dev-1',
          ),
        ],
        cashCents: 50000,
      );
      // 1300 + 1000 = 2300 元 市值；+ 500 元现金 = 2800
      expect(summary.marketValueCents, 230000);
      expect(summary.cashCents, 50000);
      expect(summary.netValueCents, 280000);
      expect(summary.holdingCount, 2);
      expect(summary.needsPrice, false);
    });

    test('有持仓但无任何价格时标记 needsPrice', () {
      final summary = HoldingsSummary.of(
        holdings: [make(shares: 100, costPrice: 1000)],
        cashCents: 0,
      );
      expect(summary.needsPrice, true);
    });
  });

  group('仓储往返', () {
    late AppDatabase db;
    late HoldingRepositoryImpl repo;

    setUp(() {
      db = AppDatabase.inMemory();
      repo = HoldingRepositoryImpl(
        db: db,
        changeLogWriter: ChangeLogWriter(db),
      );
    });
    tearDown(() => db.close());

    test('份额与价格按整数往返，不丢精度', () async {
      final h = Holding(
        id: 'h1', bookId: 'book-1', accountId: 'acc-inv',
        name: '沪深300', code: '510300', assetType: AssetType.fund,
        // 1234.5678 份
        sharesX10000: 12345678,
        costPriceCents: 1107,
        lastPriceCents: 1301,
        priceUpdatedAt: now,
        createdAt: now, updatedAt: now, deviceId: 'dev-1',
      );
      expect((await repo.create(h)).isSuccess, true);

      final back = (await repo.getById('h1')).successOrNull!;
      expect(back.sharesX10000, 12345678);
      expect(Quantity.label(back.sharesX10000), '1234.5678');
      expect(back.costPriceCents, 1107);
      expect(back.lastPriceCents, 1301);
      expect(back.priceUpdatedAt, now);
      expect(back.assetType, AssetType.fund);
    });

    test('按账户过滤且软删后不再出现', () async {
      for (final id in ['h1', 'h2']) {
        await repo.create(Holding(
          id: id, bookId: 'book-1', accountId: 'acc-inv', name: 'X',
          sharesX10000: 10000, costPriceCents: 100,
          createdAt: now, updatedAt: now, deviceId: 'dev-1',
        ));
      }
      expect((await repo.listByAccount('acc-inv')).successOrNull, hasLength(2));
      await repo.softDelete('h1');
      expect((await repo.listByAccount('acc-inv')).successOrNull, hasLength(1));
    });
  });
}
