/// STORY-9.3 锁定汇率。
library;

/// 一条「原币 → 本位币」的锁汇率。
class CurrencyRate {
  const CurrencyRate({
    required this.id,
    required this.bookId,
    required this.fromCurrency,
    required this.toCurrency,
    required this.rate,
    required this.updatedAt,
    this.revision = 1,
    required this.deviceId,
    this.baseRevision = 0,
  });

  final String id;
  final String bookId;
  final String fromCurrency;
  final String toCurrency;

  /// 1 单位原币折多少本位币。
  final double rate;
  final DateTime updatedAt;
  final int revision;
  final String deviceId;
  final int baseRevision;

  /// 查询键，形如 `USD/CNY`。
  String get pairKey => '$fromCurrency/$toCurrency';

  CurrencyRate copyWith({
    double? rate,
    DateTime? updatedAt,
    int? revision,
    int? baseRevision,
  }) =>
      CurrencyRate(
        id: id,
        bookId: bookId,
        fromCurrency: fromCurrency,
        toCurrency: toCurrency,
        rate: rate ?? this.rate,
        updatedAt: updatedAt ?? this.updatedAt,
        revision: revision ?? this.revision,
        deviceId: deviceId,
        baseRevision: baseRevision ?? this.baseRevision,
      );
}
