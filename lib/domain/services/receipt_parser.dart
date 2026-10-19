/// STORY-9.2 票据识别结果解析。
///
/// **离线**：不调用任何外部 OCR/AI 服务。文本来自用户粘贴（小票文字、截图识别
/// 结果、一句话描述），本服务只做**结构化抽取**：
/// - 金额：优先「合计/总额/实付」附近的数字，否则取第一个像金额的数字
/// - 日期：`2026-09-29` / `2026/09/29` / `2026年9月29日`
/// - 商户：优先匹配**已学到的**商户名（`merchant_rules`，由用户记账累积而来），
///   否则取首行作为候选（小票首行通常是商户名）
///
/// ⚠️ 这里**不再有写死的商户清单**——商户与分类的对应关系来自学习表，
/// 用户没学过就不猜。
///
/// 识别结果只用于预填，**不直接入库**（AC1/AC2）。
library;

import 'package:plain/app/l10n/app_strings.dart';
import 'package:plain/app/l10n/strings_domain.dart';

class OcrDraft {
  const OcrDraft({
    this.amountCents,
    this.merchant,
    this.occurredAt,
    this.categoryHint,
  });

  final int? amountCents;
  final String? merchant;
  final DateTime? occurredAt;

  /// 分类建议（来自已学到的商户映射；没学过则为 null）。
  final String? categoryHint;

  bool get isEmpty =>
      amountCents == null && merchant == null && occurredAt == null;

  /// 识别**成功**的判据（AC1/AC2）：金额是记账的必需字段。
  ///
  /// 只抽到商户名或日期不算成功 —— 小票首行的启发式很容易把一句普通话
  /// （如「今天天气不错」）当成店名，那种结果既不能预填也不能计额度。
  bool get isUsable => amountCents != null;

  /// 抽取到了什么（用于给用户一句「识别到 X」的反馈）。
  String summary(AppStrings s) {
    final parts = <String>[];
    if (amountCents != null) {
      parts.add(s.ocrAmount((amountCents! / 100).toStringAsFixed(2)));
    }
    if (merchant != null) parts.add(s.ocrMerchant(merchant!));
    if (occurredAt != null) {
      final d = occurredAt!;
      parts.add(s.ocrDate('${d.year}-${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}'));
    }
    return parts.isEmpty ? s.ocrEmpty : s.ocrRecognized(parts.join(' · '));
  }
}

class ReceiptParser {
  /// 日期：2026-09-29 / 2026/09/29 / 2026年9月29日
  static final _dateRe = RegExp(
    r'(\d{4})[-/年.](\d{1,2})[-/月.](\d{1,2})日?',
  );

  /// 小票首行通常只有店名，超过这个长度就不像店名了。
  static const int _maxMerchantLen = 20;

  /// 从文本抽取字段。
  ///
  /// [merchantToCategory] 来自学习表（`MerchantLearner.keywordMapOf`）——
  /// 命中的商户同时给出分类建议；没命中就只用结构启发取商户名，不给分类建议。
  static OcrDraft parseText(
    String text, {
    Map<String, String> merchantToCategory = const {},
  }) {
    final t = text.trim();
    if (t.isEmpty) return const OcrDraft();

    final cents = _parseAmount(t);
    final date = _parseDate(t);
    final (merchant, hint) = _parseMerchant(t, merchantToCategory);

    return OcrDraft(
      amountCents: cents,
      merchant: merchant,
      occurredAt: date,
      categoryHint: hint,
    );
  }

  /// 兜底用的「像金额」片段：带币种符号、带「元」、或带两位小数。
  ///
  /// ⚠️ 兜底**不能**直接用 [_amountRe]（任意数字）：小票上的日期、单号、电话
  /// 都是数字，`2026-01-15` 会被取成「金额 2026」。所以先剔除日期片段，
  /// 再只接受上面三种形态。
  static final _moneyRe = RegExp(
    r'(?:[¥￥$]\s*(\d{1,9}(?:\.\d{1,2})?))'
    r'|(?:(\d{1,9}(?:\.\d{1,2})?)\s*元)'
    r'|(?:(\d{1,9}\.\d{2}))',
  );

  static int? _parseAmount(String t) {
    // 优先取「合计/总额/实付/应付」附近的金额
    final totalM = RegExp(r'(合计|总额|实付|应付|小计)[^\d]{0,6}(\d{1,9}(?:\.\d{1,2})?)')
        .firstMatch(t);
    if (totalM != null) {
      final v = double.tryParse(totalM.group(2)!);
      if (v != null) return (v * 100).round();
    }
    final amtM = _moneyRe.firstMatch(t.replaceAll(_dateRe, ' '));
    if (amtM == null) return null;
    final raw = amtM.group(1) ?? amtM.group(2) ?? amtM.group(3);
    if (raw == null) return null;
    final v = double.tryParse(raw);
    return v == null ? null : (v * 100).round();
  }

  static DateTime? _parseDate(String t) {
    final dM = _dateRe.firstMatch(t);
    if (dM == null) return null;
    final y = int.tryParse(dM.group(1)!);
    final mo = int.tryParse(dM.group(2)!);
    final d = int.tryParse(dM.group(3)!);
    if (y == null || mo == null || d == null) return null;
    if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
    return DateTime(y, mo, d);
  }

  /// 不像店名的关键词（金额/单据类字段），命中就不作为商户候选。
  static final _notMerchantRe = RegExp(
      r'(元|¥|￥|\$|合计|总额|实付|应付|小计|收银|单号|时间|日期|电话|地址|数量|单价)');

  /// 商户名至少要有一段连续的汉字或字母。
  static final _nameLikeRe = RegExp(r'[\u4e00-\u9fa5A-Za-z]{2,}');

  /// 返回 (商户, 分类建议)。
  static (String?, String?) _parseMerchant(
    String t,
    Map<String, String> merchantToCategory,
  ) {
    // ① 已学到的商户名出现在文本里：取**最长**的那个（更具体）
    String? best;
    for (final known in merchantToCategory.keys) {
      final key = known.trim();
      if (key.isEmpty) continue;
      if (!t.contains(key)) continue;
      if (best == null || key.length > best.length) best = key;
    }
    if (best != null) return (best, merchantToCategory[best]);

    // ② 结构启发：小票首行通常是店名；但金额/单据类行要排除掉
    for (final line in t.split('\n')) {
      final s = line.trim();
      if (s.isEmpty) continue;
      if (s.length > _maxMerchantLen) break;
      if (_notMerchantRe.hasMatch(s)) continue;
      // 去掉常见前缀标记
      final cleaned = s.replaceFirst(RegExp(r'^(商户|商家|店铺)[:：]?\s*'), '');
      if (cleaned.isEmpty) continue;
      if (!_nameLikeRe.hasMatch(cleaned)) continue;
      return (cleaned, null);
    }
    return (null, null);
  }
}
