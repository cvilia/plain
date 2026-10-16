/// LedgerEntry entity. See 08-5.1.
library;

import 'package:plain/core/money/money.dart';
import 'package:plain/domain/entities/enums.dart';

class LedgerEntry {
  const LedgerEntry({
    required this.id, required this.bookId, required this.type,
    required this.amount, required this.currency,
    this.originalAmountCents, this.exchangeRate,
    this.categoryId, this.accountId, this.toAccountId,
    required this.occurredAt, this.note, required this.source,
    this.batchId,
    this.splitRole = SplitRole.normal,
    this.parentId,
    this.reimburseStatus = ReimburseStatus.none,
    this.excludeFromStats = false,
    this.reconciledAt,
    this.memberId,
    required this.createdAt, required this.updatedAt,
    this.deletedAt, this.revision = 1,
    required this.deviceId, this.baseRevision = 0,
  });

  final String id;
  final String bookId;
  final EntryType type;
  final Money amount;
  final String currency;

  /// STORY-9.3：原币金额（cents）。null = 与 amount 相同（本位币记账）。
  final int? originalAmountCents;

  /// STORY-9.3：锁定汇率。null = 不适用（本位币记账）。
  final double? exchangeRate;
  final String? categoryId;
  final String? accountId;
  final String? toAccountId;
  final DateTime occurredAt;
  final String? note;
  final EntrySource source;
  final String? batchId;

  /// STORY-6.2：普通 / 拆分父笔 / 拆分子笔。
  final SplitRole splitRole;
  final String? parentId;

  /// STORY-1.8：报销状态。
  final ReimburseStatus reimburseStatus;

  /// G-2：手动标记「不计入收支」。**只影响统计口径，不影响账户余额**——
  /// 该笔仍是真实账单，仍从账户里划走了钱，只是不计入收支合计、
  /// 分类统计与预算（见 G-2 派生口径表）。
  final bool excludeFromStats;

  /// STORY-2.3：对账模式勾选时间；null = 待对账。
  final DateTime? reconciledAt;

  /// STORY-8.2：归属成员（家庭账本「各记各的」）。null = 未指定归属。
  final String? memberId;

  bool get isReconciled => reconciledAt != null;

  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int revision;
  final String deviceId;
  final int baseRevision;

  bool get isDeleted => deletedAt != null;
  bool get isTransfer => type == EntryType.transfer;
  bool get isSplitParent => splitRole == SplitRole.parent;
  bool get isSplitChild => splitRole == SplitRole.child;

  /// G-2：计入收支统计 = 收入/支出类型，且非对账调整，且未被手动标记排除。
  /// 对账调整只修余额，不进消费/分类统计（《08》C11）。
  /// STORY-6.2：子笔不计收支（已在父笔计过），父笔计一次。
  /// G-2 + STORY-6.2：
  /// - 收支合计（含分割）：父笔/普通计一次，子笔不计（Σ子笔=父笔）
  /// - 分类统计/预算：子笔/普通计，父笔不计
  /// - 对账调整不进统计
  /// - 手动标「不计入收支」不进统计，但仍计入账户余额
  bool get countsInOutflow =>
      type.countsInOutflow &&
      source != EntrySource.reconcile &&
      splitRole != SplitRole.child &&
      !excludeFromStats;

  /// 影响账户余额：普通账单与拆分父笔；子笔不计（避免双算）。
  /// 注意 [excludeFromStats] 不在此处——手动排除只改统计口径，余额照常变。
  bool get affectsBalance => splitRole != SplitRole.child;

  /// 进分类统计 / 预算：子笔与普通账单；父笔不计（避免双算）。
  bool get countsInCategoryStats =>
      type.countsInOutflow &&
      source != EntrySource.reconcile &&
      splitRole != SplitRole.parent &&
      !excludeFromStats;

  /// 是否允许手动标记「不计入收支」。
  ///
  /// 只有「手动录入的普通收入/支出」需要这个开关：对账调整、转账、借贷、
  /// 拆分子笔等类型的「计不计入收支」是 G-2 定死的派生结果，不该让用户改。
  bool get canMarkExcluded =>
      source == EntrySource.manual &&
      splitRole == SplitRole.normal &&
      (type == EntryType.expense || type == EntryType.income);

  int get signedCentsForFlow => switch (type) {
        EntryType.expense => -amount.cents,
        EntryType.income => amount.cents,
        _ => 0,
      };

  LedgerEntry copyWith({
    Money? amount, String? categoryId, String? accountId, String? toAccountId,
    DateTime? occurredAt, String? note, EntryType? type,
    SplitRole? splitRole, String? parentId,
    ReimburseStatus? reimburseStatus,
    bool? excludeFromStats,
    DateTime? reconciledAt,
    String? memberId,
    int? originalAmountCents, double? exchangeRate,
    DateTime? updatedAt, DateTime? deletedAt, int? revision, int? baseRevision,
    bool clearNote = false, bool clearCategoryId = false, bool clearDeletedAt = false,
    bool clearParentId = false, bool clearAccount = false, bool clearMemberId = false,
    /// STORY-2.3：取消对账勾选。
    /// 没有这个开关时 `copyWith(reconciledAt: null)` 会被 `?? this.x` 吃掉，
    /// 表现为「取消勾选点了没反应」（audit 2026-10-15 发现）。
    bool clearReconciledAt = false,
  }) {
    return LedgerEntry(
      id: id, bookId: bookId, type: type ?? this.type,
      amount: amount ?? this.amount, currency: currency,
      originalAmountCents: originalAmountCents ?? this.originalAmountCents,
      exchangeRate: exchangeRate ?? this.exchangeRate,
      categoryId: clearCategoryId ? null : (categoryId ?? this.categoryId),
      accountId: clearAccount ? null : (accountId ?? this.accountId),
      toAccountId: toAccountId ?? this.toAccountId,
      occurredAt: occurredAt ?? this.occurredAt,
      note: clearNote ? null : (note ?? this.note),
      source: source, batchId: batchId,
      splitRole: splitRole ?? this.splitRole,
      parentId: clearParentId ? null : (parentId ?? this.parentId),
      reimburseStatus: reimburseStatus ?? this.reimburseStatus,
      excludeFromStats: excludeFromStats ?? this.excludeFromStats,
      reconciledAt: clearReconciledAt ? null : (reconciledAt ?? this.reconciledAt),
      memberId: clearMemberId ? null : (memberId ?? this.memberId),
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      revision: revision ?? this.revision, deviceId: deviceId,
      baseRevision: baseRevision ?? this.baseRevision,
    );
  }

  @override
  bool operator ==(Object other) => other is LedgerEntry && other.id == id && other.revision == revision;
  @override
  int get hashCode => Object.hash(id, revision);
}
