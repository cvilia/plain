/// STORY-1.6 商户学习（纯逻辑：推荐 + 学习）。
///
/// 持久化在 `merchant_rules` 表（见仓储）；本文件只做规则式推荐与合并，
/// 便于单测，也不依赖存储。
library;

import 'package:plain/domain/entities/merchant_rule.dart';

export 'package:plain/domain/entities/merchant_rule.dart';

/// 一次推荐结果。
class MerchantSuggestion {
  const MerchantSuggestion({
    required this.categoryId,
    required this.confidence,
    required this.merchant,
  });

  final String categoryId;

  /// 精确命中 1.0；包含命中按商户名占备注的比例（最低 0.3）。
  final double confidence;

  /// 命中的已学备注。
  final String merchant;
}

/// 学习与推荐。
class MerchantLearner {
  /// 从已学记录推荐分类：优先精确匹配，其次包含匹配（命中次数高者优先）。
  ///
  /// [rulesByMerchant] 的键为备注原文（大小写不敏感匹配）。
  static MerchantSuggestion? suggest({
    required String merchant,
    required Map<String, MerchantRule> rulesByMerchant,
  }) {
    final key = merchant.trim();
    if (key.isEmpty) return null;
    final lower = key.toLowerCase();

    // ① 精确匹配：学到的就是这一条备注
    for (final r in rulesByMerchant.values) {
      if (r.categoryId == null) continue;
      if (r.merchant.trim().toLowerCase() == lower) {
        return MerchantSuggestion(
            categoryId: r.categoryId!, confidence: 1.0, merchant: r.merchant);
      }
    }

    // ② 包含匹配：备注里含已学商户名（如「瑞幸咖啡（国贸店）」含「瑞幸」）
    final contained = rulesByMerchant.values
        .where((r) =>
            r.categoryId != null &&
            r.merchant.trim().isNotEmpty &&
            lower.contains(r.merchant.trim().toLowerCase()))
        .toList()
      ..sort((a, b) => b.hitCount.compareTo(a.hitCount));
    if (contained.isEmpty) return null;

    final best = contained.first;
    final ratio = best.merchant.trim().length / key.length;
    return MerchantSuggestion(
      categoryId: best.categoryId!,
      // 占比过小时不可信，但既然备注里确实出现了已学商户名，给一个下限
      confidence: ratio < 0.3 ? 0.3 : ratio,
      merchant: best.merchant,
    );
  }

  /// 用户确认分类时学习：已有则命中 +1 并更新分类，否则新建。
  ///
  /// 返回**要写回仓储的实体**（id 沿用既有记录的 id）。
  static MerchantRule learn({
    required String id,
    required String bookId,
    required String merchant,
    required String categoryId,
    required DateTime now,
    required String deviceId,
    MerchantRule? existing,
  }) {
    if (existing != null) {
      return existing.copyWith(
        categoryId: categoryId,
        hitCount: existing.hitCount + 1,
        lastCorrectedAt: now,
        updatedAt: now,
        revision: existing.revision + 1,
        baseRevision: existing.revision,
      );
    }
    return MerchantRule(
      id: id,
      bookId: bookId,
      merchant: merchant,
      categoryId: categoryId,
      hitCount: 1,
      lastCorrectedAt: now,
      createdAt: now,
      updatedAt: now,
      deviceId: deviceId,
    );
  }

  /// 按命中次数排序取 Top N（供预览/调试）。
  static List<MerchantRule> topByHits(Iterable<MerchantRule> rules, {int n = 10}) {
    final list = rules.toList()
      ..sort((a, b) => b.hitCount.compareTo(a.hitCount));
    return list.take(n).toList();
  }

  /// 供 `CategorySuggester` 使用的「关键词 → 分类」映射（只含已学到的）。
  static Map<String, String> keywordMapOf(Iterable<MerchantRule> rules) {
    final out = <String, String>{};
    for (final r in rules) {
      final id = r.categoryId;
      if (id == null || id.isEmpty) continue;
      final key = r.merchant.trim();
      if (key.isEmpty) continue;
      out[key] = id;
    }
    return out;
  }
}
