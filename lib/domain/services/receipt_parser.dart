/// 票据 OCR 结果解析骨架（STORY-9.2）。
/// 识别结果只用于预填，不直接入库（AC1/AC2）。
library;

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

  /// 分类建议（如「餐饮-饮料」的 id 或名称）。
  final String? categoryHint;

  bool get isEmpty =>
      amountCents == null && merchant == null && occurredAt == null;
}

/// 从 OCR 文本中抽取关键字段（正则骨架，后续可换识别服务）。
class ReceiptParser {
  /// 金额：¥128.50 / 128.50元 / 合计 98
  static final _amountRe = RegExp(
    r'(?:¥|￥|\$|USD|CNY)?\s*(\d{1,9}(?:\.\d{1,2})?)\s*(?:元|¥)?',
    caseSensitive: false,
  );

  /// 日期：2026-09-29 / 2026/09/29 / 2026年9月29日
  static final _dateRe = RegExp(
    r'(\d{4})[-/年.](\d{1,2})[-/月.](\d{1,2})日?',
  );

  /// 常见商户关键词（骨架，可接学习表）。
  static const List<String> knownMerchants = [
    '星巴克', '瑞幸', '麦当劳', '肯德基', '滴滴', '淘宝', '京东', '美团', '饿了么',
  ];

  static OcrDraft parseText(String text) {
    final t = text.trim();
    if (t.isEmpty) return const OcrDraft();

    int? cents;
    // 优先取「合计/总额/实付」附近金额
    final totalM = RegExp(r'(合计|总额|实付|应付)[^\d]{0,6}(\d{1,9}(?:\.\d{1,2})?)')
        .firstMatch(t);
    final amtM = totalM ?? _amountRe.firstMatch(t);
    if (amtM != null) {
      final raw = totalM?.group(2) ?? amtM.group(1)!;
      final v = double.tryParse(raw);
      if (v != null) cents = (v * 100).round();
    }

    String? merchant;
    for (final m in knownMerchants) {
      if (t.contains(m)) {
        merchant = m;
        break;
      }
    }

    DateTime? date;
    final dM = _dateRe.firstMatch(t);
    if (dM != null) {
      final y = int.tryParse(dM.group(1)!);
      final mo = int.tryParse(dM.group(2)!);
      final d = int.tryParse(dM.group(3)!);
      if (y != null && mo != null && d != null) {
        date = DateTime(y, mo, d);
      }
    }

    String? hint;
    if (merchant != null) {
      // 简单启发：餐饮类商户 → 餐饮
      if (const ['星巴克', '瑞幸', '麦当劳', '肯德基'].contains(merchant)) {
        hint = '餐饮';
      }
    }

    return OcrDraft(
      amountCents: cents,
      merchant: merchant,
      occurredAt: date,
      categoryHint: hint,
    );
  }
}
