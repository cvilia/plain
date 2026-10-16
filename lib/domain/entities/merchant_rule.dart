/// STORY-1.6 商户学习记录。
///
/// 用户在记账时给一笔带备注的账单选了分类，这条「备注 → 分类」就被记住；
/// 下次输入同样的备注会优先推荐学到的分类（规则式，不是 AI 推断）。
library;

class MerchantRule {
  const MerchantRule({
    required this.id,
    required this.bookId,
    required this.merchant,
    this.categoryId,
    this.hitCount = 1,
    this.lastCorrectedAt,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.revision = 1,
    required this.deviceId,
    this.baseRevision = 0,
  });

  final String id;
  final String bookId;

  /// 备注文本（商户口径见 `rule_engine.dart`：暂用备注承载）。
  final String merchant;
  final String? categoryId;

  /// 被确认的次数；越高越可信。
  final int hitCount;
  final DateTime? lastCorrectedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int revision;
  final String deviceId;
  final int baseRevision;

  bool get isDeleted => deletedAt != null;

  MerchantRule copyWith({
    String? categoryId,
    int? hitCount,
    DateTime? lastCorrectedAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    int? revision,
    int? baseRevision,
  }) =>
      MerchantRule(
        id: id,
        bookId: bookId,
        merchant: merchant,
        categoryId: categoryId ?? this.categoryId,
        hitCount: hitCount ?? this.hitCount,
        lastCorrectedAt: lastCorrectedAt ?? this.lastCorrectedAt,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deletedAt: deletedAt ?? this.deletedAt,
        revision: revision ?? this.revision,
        deviceId: deviceId,
        baseRevision: baseRevision ?? this.baseRevision,
      );

  @override
  bool operator ==(Object other) =>
      other is MerchantRule && other.id == id && other.revision == revision;
  @override
  int get hashCode => Object.hash(id, revision);
}
