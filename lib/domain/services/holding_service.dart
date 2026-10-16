/// STORY-10.1 投资持仓的买入 / 卖出 / 行情录入。
///
/// **加权平均成本法**（PRD STORY-10.1）：
/// - 买入：`新均价 = (原份额×原均价 + 买入份额×买价) ÷ 新份额`（AC2）
/// - 卖出：`已实现盈亏 = (卖价 − 加权均价) × 卖出份额`，均价不变（AC3）
///
/// 全部为纯函数，不碰存储；落地由调用方写回仓储。
library;

import 'package:plain/core/result/result.dart';
import 'package:plain/domain/entities/holding.dart';

class HoldingService {
  const HoldingService();

  /// 买入：更新份额与加权平均成本单价（AC2）。
  Holding buy(
    Holding holding, {
    required int sharesX10000,
    required int unitPriceCents,
    required DateTime at,
  }) {
    if (sharesX10000 <= 0) return holding;
    final newShares = holding.sharesX10000 + sharesX10000;
    // 原成本总额 + 本次买入金额，除以新份额
    final oldCost = holding.sharesX10000 * holding.costPriceCents;
    final addCost = sharesX10000 * unitPriceCents;
    final newAvg = newShares == 0 ? 0 : ((oldCost + addCost) / newShares).round();
    return holding.copyWith(
      sharesX10000: newShares,
      costPriceCents: newAvg,
      lastPriceCents: holding.hasPrice ? holding.lastPriceCents : unitPriceCents,
      priceUpdatedAt: holding.hasPrice ? holding.priceUpdatedAt : at,
      updatedAt: at,
      revision: holding.revision + 1,
      baseRevision: holding.revision,
    );
  }

  /// 卖出：按加权平均法结算已实现盈亏（AC3）。
  ///
  /// 份额不足时返回失败，不做部分成交。
  ({Holding holding, int realizedCents}) sell(
    Holding holding, {
    required int sharesX10000,
    required int unitPriceCents,
    required DateTime at,
  }) {
    if (sharesX10000 <= 0 || sharesX10000 > holding.sharesX10000) {
      return (holding: holding, realizedCents: 0);
    }
    final realized = Quantity.valueCents(
      sharesX10000: sharesX10000,
      priceCents: unitPriceCents - holding.costPriceCents,
    );
    final next = holding.copyWith(
      sharesX10000: holding.sharesX10000 - sharesX10000,
      realizedPnlCents: holding.realizedPnlCents + realized,
      updatedAt: at,
      revision: holding.revision + 1,
      baseRevision: holding.revision,
    );
    return (holding: next, realizedCents: realized);
  }

  /// 录入现价（AC4/AC5）。
  ///
  /// 行情源不可用时**只走手动录入**，并记录录入时间以便页面标注
  /// 「价格更新于 <时间>」；不做任何外部请求。
  Holding updatePrice(
    Holding holding, {
    required int priceCents,
    required DateTime at,
  }) {
    if (priceCents <= 0) return holding;
    return holding.copyWith(
      lastPriceCents: priceCents,
      priceUpdatedAt: at,
      updatedAt: at,
      revision: holding.revision + 1,
      baseRevision: holding.revision,
    );
  }

  /// 校验卖出份额是否可用。
  Result<void> validateSell(Holding holding, int sharesX10000) {
    if (sharesX10000 <= 0) {
      return err(const ValidationFailure('holding.shares_invalid', 'zero'));
    }
    if (sharesX10000 > holding.sharesX10000) {
      return err(const ValidationFailure('holding.shares_exceeded', 'too many'));
    }
    return ok(null);
  }
}

/// 一个投资账户下所有持仓的合计（净值贡献，AC1）。
class HoldingsSummary {
  const HoldingsSummary({
    required this.cashCents,
    required this.marketValueCents,
    required this.costBasisCents,
    required this.realizedPnlCents,
    required this.holdingCount,
  });

  /// 该投资账户的现金余额（账户派生余额）。
  final int cashCents;

  /// 持仓市值合计。
  final int marketValueCents;
  final int costBasisCents;
  final int realizedPnlCents;
  final int holdingCount;

  /// AC1：投资账户净值 = 持仓市值 + 现金余额。
  int get netValueCents => marketValueCents + cashCents;

  int get unrealizedPnlCents => marketValueCents - costBasisCents;

  /// 有持仓但一个价格都没录入时，市值不可信。
  bool get needsPrice => holdingCount > 0 && marketValueCents == 0;

  static HoldingsSummary of({
    required List<Holding> holdings,
    required int cashCents,
  }) {
    var market = 0;
    var cost = 0;
    var realized = 0;
    for (final h in holdings) {
      market += h.marketValueCents;
      cost += h.costBasisCents;
      realized += h.realizedPnlCents;
    }
    return HoldingsSummary(
      cashCents: cashCents,
      marketValueCents: market,
      costBasisCents: cost,
      realizedPnlCents: realized,
      holdingCount: holdings.length,
    );
  }
}
