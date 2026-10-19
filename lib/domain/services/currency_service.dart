/// STORY-9.3 多币种：汇率锁定、原币/本位币双显示、跨币种转账。
///
/// **无外部汇率源**：汇率只有两个来源——用户为这笔账单填的值（`overrideRate`），
/// 或用户为该币种对设定的**锁定汇率**（持久化在 `currency_rates`）。
/// 因此本服务是纯函数：锁定汇率由调用方传入，不再持有静态可变状态
/// （原先存在内存 Map 里，重启即丢，也无法测试）。
library;

import 'package:plain/app/l10n/app_strings.dart';
import 'package:plain/core/constants/app_constants.dart';
import 'package:plain/app/l10n/strings_domain.dart';

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

  /// 是否发生了实际换算（同币种时为 false）。
  bool get isConverted => fromCurrency != toCurrency;

  /// 原币显示字符串。
  String get originalDisplay =>
      '${CurrencyRules.symbolOf(fromCurrency)}${(originalCents / 100).toStringAsFixed(2)}';

  /// 折算显示字符串。
  String get convertedDisplay =>
      '${CurrencyRules.symbolOf(toCurrency)}${(convertedCents / 100).toStringAsFixed(2)}';

  /// 双显示，例如 `$100.00 ≈ ¥720.00`；同币种只显示一次。
  String get dualDisplay =>
      isConverted ? '$originalDisplay ≈ $convertedDisplay' : originalDisplay;
}

class CurrencyService {
  const CurrencyService();

  /// 换算金额。优先用 [overrideRate]（这笔账单锁定的值），
  /// 否则用 [lockedRates]（该币种对的锁定值，键为 `USD/CNY`）。
  ///
  /// 两者都没有且币种不同时，rate = 0 且 converted = 0——调用方应据此
  /// 拦截「跨币种未填汇率」（AC3），而不是拿 0 当结果用。
  CurrencyConversion convert({
    required int originalCents,
    required String fromCurrency,
    required String toCurrency,
    double? overrideRate,
    Map<String, double> lockedRates = const {},
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
    final rate = overrideRate ?? lockedRates['$fromCurrency/$toCurrency'] ?? 0.0;
    final converted = rate > 0 ? (originalCents * rate).round() : 0;
    return CurrencyConversion(
      originalCents: originalCents,
      convertedCents: converted,
      rate: rate,
      fromCurrency: fromCurrency,
      toCurrency: toCurrency,
    );
  }

  /// 跨币种转账校验（AC3）。
  /// 返回 null = 校验通过；返回错误信息 = 拦截。
  String? validateTransfer({
    required AppStrings s,
    required String fromCurrency,
    required String toCurrency,
    required double? rate,
    required int? fromAmountCents,
    required int? toAmountCents,
  }) {
    if (fromCurrency == toCurrency) return null;
    if (rate == null || rate <= 0) return s.currencyRateRequired;
    if (fromAmountCents == null || toAmountCents == null) return s.currencyRateRequired;
    return null;
  }
}
