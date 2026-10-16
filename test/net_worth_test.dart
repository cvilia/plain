/// STORY-10.4 净值追踪：构成可下钻、历史序列按账本回算。
library;
import 'package:flutter_test/flutter_test.dart';
import 'package:plain/core/money/money.dart';
import 'package:plain/domain/entities/category.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/entities/ledger_entry.dart';
import 'package:plain/domain/services/net_worth_service.dart';

void main() {
  const svc = NetWorthService();
  final now = DateTime.utc(2026, 10, 15, 12);

  Account acc(
    String id,
    AccountType type, {
    int opening = 0,
    AssetValuationMode valuation = AssetValuationMode.none,
    int base = 0,
    int rateBp = 0,
    int manual = 0,
    DateTime? startedAt,
  }) =>
      Account(
        id: id, name: id, type: type, currency: 'CNY',
        openingBalance: opening, sortOrder: 0,
        valuationMode: valuation, valuationBaseCents: base,
        valuationRateBp: rateBp, valuationManualCents: manual,
        valuationStartedAt: startedAt,
        createdAt: now, updatedAt: now, deviceId: 'dev-1',
      );

  LedgerEntry entry({
    String id = 'e',
    EntryType type = EntryType.expense,
    int cents = 100,
    String? accountId,
    String? toAccountId,
    DateTime? at,
    bool deleted = false,
  }) =>
      LedgerEntry(
        id: id, bookId: 'book-1', type: type, amount: Money(cents),
        currency: 'CNY', accountId: accountId, toAccountId: toAccountId,
        occurredAt: at ?? now, source: EntrySource.manual,
        createdAt: now, updatedAt: now, deviceId: 'dev-1',
        deletedAt: deleted ? now : null,
      );

  group('AC1 净值 = Σ资产 − Σ负债，每项可下钻', () {
    test('3 资产 + 2 负债', () {
      final snapshot = svc.snapshot(
        accounts: [
          acc('现金', AccountType.cash),
          acc('储蓄', AccountType.debit),
          acc('投资', AccountType.investment),
          acc('信用卡', AccountType.credit),
          acc('房贷', AccountType.loanIn),
        ],
        balances: {
          '现金': 100000,
          '储蓄': 200000,
          '投资': 50000, // 投资账户现金
          '信用卡': -20000, // 欠款 200
          '房贷': -100000, // 剩余本金 1000
        },
        holdingsMarketByAccount: {'投资': 30000},
        holdingsCountByAccount: {'投资': 2},
        now: now,
      );

      // 投资账户计入「现金 + 持仓市值」
      expect(snapshot.totalAssetsCents, 100000 + 200000 + 80000);
      // 负债按正数欠款计入
      expect(snapshot.totalLiabilitiesCents, 20000 + 100000);
      expect(snapshot.netCents, 380000 - 120000);

      // 每项都可下钻（带 accountId）
      expect(snapshot.assets.every((e) => e.accountId != null), true);
      expect(snapshot.liabilities.every((e) => e.accountId != null), true);
      // AC2：投资项说明含持仓数
      final inv = snapshot.assets.firstWhere((e) => e.bucket == NetWorthBucket.investment);
      expect(inv.cents, 80000);
      expect(inv.detail, '含 2 个持仓');
      // AC3：贷款项 = 剩余本金
      final loan = snapshot.liabilities.firstWhere((e) => e.bucket == NetWorthBucket.loan);
      expect(loan.cents, 100000);
    });

    test('分类汇总与未录价提示', () {
      final snapshot = svc.snapshot(
        accounts: [acc('投资', AccountType.investment)],
        balances: {'投资': 0},
        holdingsMarketByAccount: {'投资': 0},
        holdingsCountByAccount: {'投资': 3},
        now: now,
      );
      expect(snapshot.unpricedHoldings, 1);
    });
  });

  group('固定资产用估算值参与净值（AC1/AC2 联动）', () {
    test('车辆账户按 −8%/年 估算，并带出原始成本', () {
      final snapshot = svc.snapshot(
        accounts: [
          acc('车', AccountType.cash,
              valuation: AssetValuationMode.depreciate,
              base: 20000000, rateBp: -800,
              startedAt: DateTime.utc(2025, 10, 15)),
        ],
        balances: {'车': 20000000},
        holdingsMarketByAccount: const {},
        holdingsCountByAccount: const {},
        now: now,
      );
      final car = snapshot.assets.single;
      expect(car.bucket, NetWorthBucket.fixed);
      expect(car.costCents, 20000000); // 原始成本不变
      expect(car.cents, 18400000); // 12 个月后估值
      expect(snapshot.totalAssetsCents, 18400000);
    });
  });

  group('历史序列（AC4）', () {
    test('余额按交易日历回算，剔除子笔与已删', () {
      final a = acc('现金', AccountType.cash, opening: 100000);
      final entries = [
        entry(id: 'e1', cents: 10000, accountId: '现金',
            at: DateTime.utc(2026, 9, 10)),
        entry(id: 'e2', type: EntryType.transfer, cents: 5000, accountId: '现金',
            at: DateTime.utc(2026, 9, 20)),
        entry(id: 'e3', type: EntryType.transfer, cents: 3000,
            toAccountId: '现金', at: DateTime.utc(2026, 10, 2)),
        entry(id: 'e4', cents: 99999, accountId: '现金',
            at: DateTime.utc(2026, 10, 3), deleted: true),
      ];
      // 9 月末：只算 9 月的两笔
      expect(
        NetWorthService.balanceAt(
          account: a, entries: entries, asOf: DateTime.utc(2026, 9, 30, 23, 59)),
        100000 - 10000 - 5000,
      );
      // 10 月中：加上转入
      expect(
        NetWorthService.balanceAt(
          account: a, entries: entries, asOf: DateTime.utc(2026, 10, 15)),
        100000 - 10000 - 5000 + 3000,
      );
    });

    test('近 N 个月序列的标签与点数正确', () {
      final periods = NetWorthService.recentPeriods(
        now: DateTime(2026, 10, 15), monthStartDay: 1, months: 12);
      expect(periods, hasLength(12));
      expect(periods.first.label, '2025-11');
      expect(periods.last.label, '2026-10');

      final points = svc.monthlySeries(
        accounts: [acc('现金', AccountType.cash, opening: 100000)],
        entries: [
          entry(id: 'e1', cents: 40000, accountId: '现金',
              at: DateTime.utc(2026, 9, 10)),
        ],
        periods: periods,
        holdingsMarketCents: 0,
        now: now,
      );
      expect(points, hasLength(12));
      // 9 月之前是期初，9 月之后减少
      expect(points.first.netCents, 100000);
      expect(points.last.netCents, 60000);
    });

    test('持仓当前市值计入每个历史点（无价格史）', () {
      final points = svc.monthlySeries(
        accounts: [acc('投资', AccountType.investment, opening: 0)],
        entries: const [],
        periods: NetWorthService.recentPeriods(
            now: DateTime(2026, 10, 15), monthStartDay: 1, months: 3),
        holdingsMarketCents: 70000,
        now: now,
      );
      // 持仓市值固定 700，现金 0
      expect(points.every((p) => p.netCents == 70000), true);
    });
  });
}
