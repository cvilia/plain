/// STORY-10.1 投资持仓。
library;

import 'package:plain/domain/entities/enums.dart';

/// 份额的量纲：以「万分之一份」为单位的整数存储（`sharesX10000`）。
///
/// 用整数而不是 double —— 份额 × 单价要精确到「分」，double 在累乘/累加时会漂。
/// 4 位小数足够覆盖基金申购赎回的份额精度（常见 2 位）。
class Quantity {
  Quantity._();

  static const int scale = 10000;

  /// 1234.56 份 → 12345600
  static int fromUnits(double units) => (units * scale).round();

  static double toUnits(int sharesX10000) => sharesX10000 / scale;

  /// 金额（分）= 份额 × 单价（分）。
  static int valueCents({
    required int sharesX10000,
    required int priceCents,
  }) =>
      (sharesX10000 * priceCents / scale).round();

  /// 展示用：去掉无意义的尾随零（1.5000 → 1.5，100.0000 → 100）
  static String label(int sharesX10000) {
    final s = toUnits(sharesX10000).toStringAsFixed(4);
    if (!s.contains('.')) return s;
    var out = s;
    while (out.endsWith('0')) {
      out = out.substring(0, out.length - 1);
    }
    if (out.endsWith('.')) out = out.substring(0, out.length - 1);
    return out;
  }
}

class Holding {
  const Holding({
    required this.id,
    required this.bookId,
    required this.accountId,
    required this.name,
    this.code,
    this.assetType = AssetType.other,
    required this.sharesX10000,
    required this.costPriceCents,
    this.lastPriceCents = 0,
    this.priceUpdatedAt,
    this.realizedPnlCents = 0,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.revision = 1,
    required this.deviceId,
    this.baseRevision = 0,
  });

  final String id;
  final String bookId;
  final String accountId;
  final String name;
  final String? code;
  final AssetType assetType;

  /// 当前持有份额（万分之一份）。
  final int sharesX10000;

  /// **加权平均成本单价**（分/份）。买入时按加权平均更新。
  final int costPriceCents;

  /// 最近一次录入的现价（分/份）。0 = 尚未录入。
  final int lastPriceCents;

  /// 现价录入时间（AC4：行情不可用时显示「价格更新于 <时间>」）。
  final DateTime? priceUpdatedAt;

  /// 累计已实现盈亏（分），加权平均法卖出时累加。
  final int realizedPnlCents;

  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int revision;
  final String deviceId;
  final int baseRevision;

  bool get isDeleted => deletedAt != null;

  /// 成本基础（分）= 持有份额 × 加权平均成本单价。
  int get costBasisCents =>
      Quantity.valueCents(sharesX10000: sharesX10000, priceCents: costPriceCents);

  /// 市值（分）= 持有份额 × 现价。
  int get marketValueCents => Quantity.valueCents(
      sharesX10000: sharesX10000, priceCents: lastPriceCents);

  /// 浮动盈亏（分）。
  int get unrealizedPnlCents => marketValueCents - costBasisCents;

  /// 是否已录入现价（AC4/AC5）。
  bool get hasPrice => lastPriceCents > 0;

  Holding copyWith({
    String? name,
    String? code,
    AssetType? assetType,
    int? sharesX10000,
    int? costPriceCents,
    int? lastPriceCents,
    DateTime? priceUpdatedAt,
    int? realizedPnlCents,
    DateTime? updatedAt,
    DateTime? deletedAt,
    int? revision,
    int? baseRevision,
  }) =>
      Holding(
        id: id,
        bookId: bookId,
        accountId: accountId,
        name: name ?? this.name,
        code: code ?? this.code,
        assetType: assetType ?? this.assetType,
        sharesX10000: sharesX10000 ?? this.sharesX10000,
        costPriceCents: costPriceCents ?? this.costPriceCents,
        lastPriceCents: lastPriceCents ?? this.lastPriceCents,
        priceUpdatedAt: priceUpdatedAt ?? this.priceUpdatedAt,
        realizedPnlCents: realizedPnlCents ?? this.realizedPnlCents,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deletedAt: deletedAt ?? this.deletedAt,
        revision: revision ?? this.revision,
        deviceId: deviceId,
        baseRevision: baseRevision ?? this.baseRevision,
      );

  @override
  bool operator ==(Object other) =>
      other is Holding && other.id == id && other.revision == revision;
  @override
  int get hashCode => Object.hash(id, revision);
}
