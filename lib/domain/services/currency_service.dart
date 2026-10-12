/// STORY-9.3 多币种：汇率锁定、原币/本位币双显示、跨币种转账。
library;

import 'package:plain/core/constants/app_constants.dart';

/// 币种转换结果。
class CurrencyConversion {
  const CurrencyConversion({
    required this.originalCents,
    required this.convertedCents,
    required this.rate,
    required this.fromCurrency,
    required this.toCurrency,
  });

  final int originalCents;
  final int convertedCents;
  final double rate;
  final String fromCurrency;
  final String toCurrency;

  /// 原币显示字符串。
  String get originalDisplay => '${CurrencyRules.symbolOf(fromCurrency)}${(originalCents / 100).toStringAsFixed(2)}';

  /// 折算显示字符串。
  String get convertedDisplay => '${CurrencyRules.symbolOf(toCurrency)}${(convertedCents / 100).toStringAsFixed(2)}';
}

/// 币种服务：汇率换算与锁定。
class CurrencyService {
  /// 手动设置的锁定汇率（原币→本位币）。
  /// 锁定后后续记录使用同一汇率，不受市场变动影响。
  static final Map<String, double> _lockedRates = {};

  /// 锁定汇率（key = 'USD/CNY' 等）。
  static void lockRate(String from, String to, double rate) {
    _lockedRates['$from/$to'] = rate;
  }

  /// 获取锁定汇率。
  static double? lockedRate(String from, String to) => _lockedRates['$from/$to'];

  /// 解锁汇率。
  static void unlockRate(String from, String to) {
    _lockedRates.remove('$from/$to');
  }

  /// 是否已锁定。
  static bool isLocked(String from, String to) => _lockedRates.containsKey('$from/$to');

  /// 换算金额。使用锁定汇率（如有），否则使用默认汇率。
  /// 默认汇率：同币种 = 1.0，不同币种需要外部提供（无自动汇率 API）。
  static CurrencyConversion convert({
    required int originalCents,
    required String fromCurrency,
    required String toCurrency,
    double? overrideRate,
  }) {
    if (fromCurrency == toCurrency) {
      return CurrencyConversion(
        originalCents: originalCents,
        convertedCents: originalCents,
        rate: 1.0,
        fromCurrency: fromCurrency,
        toCurrency: toCurrency,
      );
    }
    // 优先使用锁定汇率
    double rate = overrideRate ?? lockedRate(fromCurrency, toCurrency) ?? 0.0;
    final converted = (originalCents * rate).round();
    return CurrencyConversion(
      originalCents: originalCents,
      convertedCents: converted,
      rate: rate,
      fromCurrency: fromCurrency,
      toCurrency: toCurrency,
    );
  }

  /// 跨币种转账校验（STORY-9.3 AC3）。
  /// 返回 null = 校验通过；返回错误信息 = 拦截。
  static String? validateTransfer({
    required String fromCurrency,
    required String toCurrency,
    required double? rate,
    required int? fromAmountCents,
    required int? toAmountCents,
  }) {
    if (fromCurrency == toCurrency) return null;
    if (rate == null || rate <= 0) return '需填写两边金额与汇率';
    if (fromAmountCents == null || toAmountCents == null) return '需填写两边金额与汇率';
    return null;
  }
}
