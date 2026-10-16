/// STORY-10.3 资产折旧与增值。
///
/// **纯估算**：按「原值 × (1 + 年率)^(持有年数)」复利推算当前估值，
/// 只用于资产总览的展示，**不改动任何账单记录**（AC3）。
///
/// 年率用**基点整数**表达（1bp = 0.01%）：−8%/年 = −800bp，+3%/年 = 300bp。
library;

import 'dart:math' as math;

import 'package:plain/domain/entities/category.dart';
import 'package:plain/domain/entities/enums.dart';

/// 一个账户的估值参数。
class ValuationTerms {
  const ValuationTerms({
    required this.mode,
    required this.baseCents,
    required this.rateBp,
    required this.manualCents,
    required this.startedAt,
  });

  final AssetValuationMode mode;

  /// 原值 / 成本（AC1 的 200,000 与 AC2 的 3,000,000）。
  final int baseCents;

  /// 年率，基点（−800 = −8%/年）。
  final int rateBp;

  /// 手动调整模式下的当前估值。
  final int manualCents;

  /// 持有起始日（用于算持有月数）。
  final DateTime? startedAt;

  /// 从账户读取；未启用估值模式时返回 null。
  static ValuationTerms? ofAccount(Account account) {
    if (!account.valuationMode.isActive) return null;
    return ValuationTerms(
      mode: account.valuationMode,
      baseCents: account.valuationBaseCents,
      rateBp: account.valuationRateBp,
      manualCents: account.valuationManualCents,
      startedAt: account.valuationStartedAt,
    );
  }
}

/// 资产总览里一项的展示口径：原始成本与当前估值**并列**（AC1）。
class ValuationResult {
  const ValuationResult({
    required this.costCents,
    required this.valueCents,
    required this.months,
  });

  /// 原始成本（恒定不变）。
  final int costCents;

  /// 当前估值（估算结果）。
  final int valueCents;

  /// 已持有月数。
  final int months;

  int get deltaCents => valueCents - costCents;
}

class AssetValuationService {
  const AssetValuationService();

  /// 持有月数：按自然月差计算，不足一月按 0 计。
  int monthsHeld({required DateTime? startedAt, required DateTime now}) {
    final s = startedAt;
    if (s == null) return 0;
    final a = s.toLocal();
    final b = now.toLocal();
    var months = (b.year - a.year) * 12 + (b.month - a.month);
    if (b.day < a.day) months -= 1;
    return months < 0 ? 0 : months;
  }

  /// 按估值模式算当前估值。
  ///
  /// - `fixed` / `manual`：直接取用户设定值（AC4 切回固定值即等于设定值）
  /// - `depreciate` / `appreciate`：`原值 × (1 + 年率)^(持有月数/12)`（AC1/AC2）
  ValuationResult evaluate(
    ValuationTerms terms, {
    required DateTime now,
  }) {
    final months = monthsHeld(startedAt: terms.startedAt, now: now);
    switch (terms.mode) {
      case AssetValuationMode.fixed:
        return ValuationResult(
          costCents: terms.baseCents,
          valueCents: terms.manualCents,
          months: months,
        );
      case AssetValuationMode.manual:
        return ValuationResult(
          costCents: terms.baseCents,
          valueCents: terms.manualCents,
          months: months,
        );
      case AssetValuationMode.depreciate:
      case AssetValuationMode.appreciate:
        return ValuationResult(
          costCents: terms.baseCents,
          valueCents: compoundAt(
            baseCents: terms.baseCents,
            rateBp: terms.rateBp,
            months: months,
          ),
          months: months,
        );
      case AssetValuationMode.none:
        return ValuationResult(
          costCents: terms.baseCents,
          valueCents: terms.baseCents,
          months: months,
        );
    }
  }

  /// `原值 × (1 + 年率)^(月数/12)`，四舍五入到分。
  int compoundAt({
    required int baseCents,
    required int rateBp,
    required int months,
  }) {
    if (baseCents <= 0) return 0;
    if (rateBp == 0 || months == 0) return baseCents;
    final years = months / 12.0;
    final factor = math.pow(1 + rateBp / 10000.0, years).toDouble();
    final v = (baseCents * factor).round();
    // 折旧不会折成负数
    return v < 0 ? 0 : v;
  }
}
