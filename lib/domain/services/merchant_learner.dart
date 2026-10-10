/// 商户自动学习（STORY-1.6）。
/// 备注/商户关键词 → 分类；用户纠正时累计命中。
library;

class MerchantRule {
  const MerchantRule({
    required this.id,
    required this.bookId,
    required this.merchant,
    this.categoryId,
    this.hitCount = 1,
    this.lastCorrectedAt,
  });

  final String id;
  final String bookId;
  final String merchant;
  final String? categoryId;
  final int hitCount;
  final DateTime? lastCorrectedAt;
}

/// 学习与推荐（纯内存逻辑，便于单测；持久化由仓储层负责）。
class MerchantLearner {
  /// 从历史映射推荐：命中次数高者优先。
  static String? suggest({
    required String merchant,
    required Map<String, MerchantRule> rulesByMerchant,
  }) {
    final key = merchant.trim();
    if (key.isEmpty) return null;
    final hit = rulesByMerchant[key] ?? rulesByMerchant[key.toLowerCase()];
    return hit?.categoryId;
  }

  /// 用户纠正分类时学习：已有则 hit_count+1 并更新分类，否则新建。
  static MerchantRule learn({
    required String id,
    required String bookId,
    required String merchant,
    required String categoryId,
    required DateTime now,
    MerchantRule? existing,
  }) {
    if (existing != null) {
      return MerchantRule(
        id: existing.id,
        bookId: existing.bookId,
        merchant: existing.merchant,
        categoryId: categoryId,
        hitCount: existing.hitCount + 1,
        lastCorrectedAt: now,
      );
    }
    return MerchantRule(
      id: id,
      bookId: bookId,
      merchant: merchant,
      categoryId: categoryId,
      hitCount: 1,
      lastCorrectedAt: now,
    );
  }

  /// 按命中次数排序取 Top N（供预览/调试）。
  static List<MerchantRule> topByHits(Iterable<MerchantRule> rules, {int n = 10}) {
    final list = rules.toList()
      ..sort((a, b) => b.hitCount.compareTo(a.hitCount));
    return list.take(n).toList();
  }
}
