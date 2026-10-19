/// Category and Account entities. See 08-5.2, 5.3.
library;

import 'package:plain/core/constants/app_constants.dart';
import 'package:plain/domain/entities/enums.dart';

class Category {
  const Category({
    required this.id, this.parentId, required this.name,
    required this.kind, required this.iconRef,
    this.note,
    required this.sortOrder, this.isHidden = false, this.isPreset = false,
    this.isRigid = false,
    this.isDeductible = false,
    required this.createdAt, required this.updatedAt,
    this.deletedAt, this.revision = 1,
    required this.deviceId, this.baseRevision = 0,
  });

  final String id;
  final String? parentId;
  final String name;
  final CategoryKind kind;
  final String iconRef;

  /// Category boundary note (≤30 chars). Distinct from transactions.note.
  final String? note;
  final int sortOrder;
  final bool isHidden;
  final bool isPreset;

  /// STORY-3.3：刚性支出标记。仅一级分类可标，二级继承。
  /// 仅用于安全可花的「刚性支出预留」计算。
  /// STORY-11.1：同时作为 50/30/20 里「需要」的判据。
  final bool isRigid;

  /// STORY-11.5：可抵扣支出标记（税务报表按它汇总）。
  final bool isDeductible;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int revision;
  final String deviceId;
  final int baseRevision;

  bool get isDeleted => deletedAt != null;
  bool get isRoot => parentId == null;

  /// Note cannot be cleared via [copyWith] (`??` treats null as "unset").
  /// Use this when the user empties the note field.
  Category withNote(String? note) => Category(
        id: id, parentId: parentId, name: name, kind: kind,
        iconRef: iconRef, note: note,
        sortOrder: sortOrder, isHidden: isHidden, isPreset: isPreset, isRigid: isRigid,
        isDeductible: isDeductible,
        createdAt: createdAt, updatedAt: updatedAt, deletedAt: deletedAt,
        revision: revision, deviceId: deviceId, baseRevision: baseRevision,
      );

  /// Reparent this category (used by 移动二级分类).
  Category withParent(String? parentId) => Category(
        id: id, parentId: parentId, name: name, kind: kind,
        iconRef: iconRef, note: note,
        sortOrder: sortOrder, isHidden: isHidden, isPreset: isPreset, isRigid: isRigid,
        isDeductible: isDeductible,
        createdAt: createdAt, updatedAt: updatedAt, deletedAt: deletedAt,
        revision: revision, deviceId: deviceId, baseRevision: baseRevision,
      );

  Category copyWith({
    String? name, String? iconRef, int? sortOrder,
    bool? isHidden, bool? isRigid, bool? isDeductible,
    DateTime? updatedAt, DateTime? deletedAt,
    int? revision, int? baseRevision,
  }) {
    return Category(
      id: id, parentId: parentId, name: name ?? this.name, kind: kind,
      iconRef: iconRef ?? this.iconRef,
      note: note,
      sortOrder: sortOrder ?? this.sortOrder, isHidden: isHidden ?? this.isHidden,
      isPreset: isPreset, isRigid: isRigid ?? this.isRigid,
      isDeductible: isDeductible ?? this.isDeductible,
      createdAt: createdAt, updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt, revision: revision ?? this.revision,
      deviceId: deviceId, baseRevision: baseRevision ?? this.baseRevision,
    );
  }

  @override
  bool operator ==(Object other) => other is Category && other.id == id && other.revision == revision;
  @override
  int get hashCode => Object.hash(id, revision);
}

class Account {
  const Account({
    required this.id, required this.name, required this.type,
    required this.currency, required this.openingBalance, this.note,
    required this.sortOrder, this.isHidden = false,
    this.creditLimitCents = 0,
    this.creditDebtCents = 0,
    this.creditAnnualRateBp = 0,
    this.minPaymentCents = 0,
    this.billDay,
    this.dueDay,
    this.loanPrincipalCents = 0,
    this.loanAnnualRateBp = 0,
    this.loanTermMonths,
    this.loanRepayMethod,
    this.loanFirstPaymentAt,
    this.valuationMode = AssetValuationMode.none,
    this.valuationBaseCents = 0,
    this.valuationRateBp = 0,
    this.valuationManualCents = 0,
    this.valuationStartedAt,
    required this.createdAt, required this.updatedAt,
    this.deletedAt, this.revision = 1,
    required this.deviceId, this.baseRevision = 0,
  });

  final String id;
  final String name;
  final AccountType type;
  final String currency;
  final int openingBalance;
  final String? note;
  final int sortOrder;
  final bool isHidden;

  /// STORY-2.2 信用卡：总额度 / 欠款余额（存储值）/ 账单日 / 还款日。
  final int creditLimitCents;
  final int creditDebtCents;
  final int? billDay;
  final int? dueDay;

  /// STORY-2.2：信用卡循环年利率（基点）。
  final int creditAnnualRateBp;

  /// STORY-10.5：账单上的最低还款额（债务优化要用，无法派生）。
  final int minPaymentCents;

  /// STORY-10.2 贷款参数：本金 / 年利率(基点) / 期数 / 还款方式 / 首次还款日。
  /// 摊销表本身**不落库**（纯派生，见 `LoanAmortizationService`）。
  final int loanPrincipalCents;
  final int loanAnnualRateBp;
  final int? loanTermMonths;
  final LoanRepayMethod? loanRepayMethod;
  final DateTime? loanFirstPaymentAt;

  /// STORY-10.3 资产估值：模式 / 原值 / 年率(基点) / 手动估值 / 持有起始。
  /// 估值是**纯估算**，只影响资产总览展示，不改动账单。
  final AssetValuationMode valuationMode;
  final int valuationBaseCents;
  final int valuationRateBp;
  final int valuationManualCents;
  final DateTime? valuationStartedAt;

  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int revision;
  final String deviceId;
  final int baseRevision;

  bool get isDeleted => deletedAt != null;
  bool get isCredit => type == AccountType.credit;

  /// 可用额度 = 总额度 − 欠款（派生，只读）。
  int get creditAvailableCents {
    final a = creditLimitCents - creditDebtCents;
    return a > 0 ? a : 0;
  }

  /// 是否刷爆（AC6 橙标）。
  bool get isOverLimit => isCredit && creditDebtCents > creditLimitCents;

  /// 是否贷款账户（借入 = 负债 / 借出 = 资产）。
  bool get isLoan => type == AccountType.loanIn || type == AccountType.loanOut;

  /// 是否外币账户。
  bool get isForeignCurrency => currency != MoneyRules.defaultCurrency;

  /// 是否**参与债务测算**（净值负债、债务优化、还债目标）。
  ///
  /// 口径（2026-10-15 定）：外币贷款**不参与** —— 贷款本金是原币给的，
  /// 流水却是本位币记的，两者拼不出一个可信的剩余本金；硬算会得出 0 或
  /// 混加出来的假数字。这类账户由用户手动维护，界面需明确标注。
  bool get supportsDebtTracking => isLoan && !isForeignCurrency;

  /// 是否需要向用户说明「该外币负债未纳入测算」。
  bool get needsManualDebtNote => isLoan && isForeignCurrency;

  /// 贷款参数是否齐备，可生成摊销表。
  bool get hasLoanTerms =>
      isLoan &&
      loanPrincipalCents > 0 &&
      loanTermMonths != null &&
      loanTermMonths! > 0 &&
      loanFirstPaymentAt != null &&
      loanRepayMethod != null &&
      loanRepayMethod != LoanRepayMethod.unknown;

  Account copyWith({
    String? name, int? openingBalance, String? note, int? sortOrder,
    bool? isHidden, int? creditLimitCents, int? creditDebtCents,
    int? billDay, int? dueDay,
    int? creditAnnualRateBp, int? minPaymentCents,
    int? loanPrincipalCents, int? loanAnnualRateBp, int? loanTermMonths,
    LoanRepayMethod? loanRepayMethod, DateTime? loanFirstPaymentAt,
    AssetValuationMode? valuationMode, int? valuationBaseCents,
    int? valuationRateBp, int? valuationManualCents, DateTime? valuationStartedAt,
    DateTime? updatedAt, DateTime? deletedAt,
    int? revision, int? baseRevision,
  }) {
    return Account(
      id: id, name: name ?? this.name, type: type, currency: currency,
      openingBalance: openingBalance ?? this.openingBalance, note: note ?? this.note,
      sortOrder: sortOrder ?? this.sortOrder, isHidden: isHidden ?? this.isHidden,
      creditLimitCents: creditLimitCents ?? this.creditLimitCents,
      creditDebtCents: creditDebtCents ?? this.creditDebtCents,
      billDay: billDay ?? this.billDay,
      dueDay: dueDay ?? this.dueDay,
      creditAnnualRateBp: creditAnnualRateBp ?? this.creditAnnualRateBp,
      minPaymentCents: minPaymentCents ?? this.minPaymentCents,
      loanPrincipalCents: loanPrincipalCents ?? this.loanPrincipalCents,
      loanAnnualRateBp: loanAnnualRateBp ?? this.loanAnnualRateBp,
      loanTermMonths: loanTermMonths ?? this.loanTermMonths,
      loanRepayMethod: loanRepayMethod ?? this.loanRepayMethod,
      loanFirstPaymentAt: loanFirstPaymentAt ?? this.loanFirstPaymentAt,
      valuationMode: valuationMode ?? this.valuationMode,
      valuationBaseCents: valuationBaseCents ?? this.valuationBaseCents,
      valuationRateBp: valuationRateBp ?? this.valuationRateBp,
      valuationManualCents: valuationManualCents ?? this.valuationManualCents,
      valuationStartedAt: valuationStartedAt ?? this.valuationStartedAt,
      createdAt: createdAt, updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt, revision: revision ?? this.revision,
      deviceId: deviceId, baseRevision: baseRevision ?? this.baseRevision,
    );
  }

  @override
  bool operator ==(Object other) => other is Account && other.id == id && other.revision == revision;
  @override
  int get hashCode => Object.hash(id, revision);
}

class AccountBalance {
  const AccountBalance({required this.accountId, required this.balanceCents, required this.openingCents, required this.txCount});
  final String accountId;
  final int balanceCents;
  final int openingCents;
  final int txCount;
}

/// Helpers for selectable category lists (entry grid, budget, pickers).
extension CategoryListX on List<Category> {
  /// Ids that have at least one live child in this list.
  Set<String> get _parentIds {
    final s = <String>{};
    for (final c in this) {
      final pid = c.parentId;
      if (pid != null) s.add(pid);
    }
    return s;
  }

  /// Only second-level / ungrouped items — never first-level groups.
  List<Category> get leaves {
    final parents = _parentIds;
    return where((c) => !c.isDeleted && !parents.contains(c.id)).toList();
  }
}
