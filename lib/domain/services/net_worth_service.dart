/// STORY-10.4 净值追踪。
///
/// 净值 = Σ资产 − Σ负债，**每一项都可下钻**（AC1–AC3）。
///
/// 口径说明（重要）：
/// - 固定资产（设了估值模式的账户）计入**估算估值**，并同时带出原始成本（AC1/AC2）；
/// - 投资账户计入「账户现金 + 持仓当前市值」；
/// - 信用卡/贷款按**欠款为正数**计入负债。
///
/// **历史曲线的已知限制**：账户余额可以按交易日历回算，但持仓的历史市值需要
/// 历史价格，而本项目无行情源、也不存价格史。因此历史曲线只回算「账户余额型」
/// 部分，持仓按**当前市值**计入，并在页面注明——不编造历史价格。
library;

import 'package:plain/core/constants/app_constants.dart';
import 'package:plain/domain/entities/category.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/entities/ledger_entry.dart';
import 'package:plain/domain/services/asset_valuation_service.dart';

/// 净值的分类（STORY-10.4 的资产/负债分类）。
enum NetWorthBucket {
  cash('现金'),
  debit('储蓄'),
  investment('投资'),
  fixed('固定资产'),
  receivable('借出'),
  credit('信用卡'),
  loan('贷款'),
  payable('借入'),
  goal('目标预留');

  const NetWorthBucket(this.label);
  final String label;

  bool get isLiability =>
      this == NetWorthBucket.credit ||
      this == NetWorthBucket.loan ||
      this == NetWorthBucket.payable;

  static NetWorthBucket of(Account account, {required bool hasValuation}) {
    // 设了估值方式的资产账户归入「固定资产」，用估算值参与净值
    if (hasValuation && !account.isLoan && !account.isCredit) {
      return NetWorthBucket.fixed;
    }
    return switch (account.type) {
      AccountType.cash => NetWorthBucket.cash,
      AccountType.debit => NetWorthBucket.debit,
      AccountType.investment => NetWorthBucket.investment,
      AccountType.goal => NetWorthBucket.goal,
      AccountType.loanOut => NetWorthBucket.receivable,
      AccountType.credit => NetWorthBucket.credit,
      AccountType.loanIn => NetWorthBucket.loan,
      _ => NetWorthBucket.cash,
    };
  }
}

/// 净值中的一项（可下钻到账户）。
class NetWorthEntry {
  const NetWorthEntry({
    required this.label,
    required this.cents,
    required this.bucket,
    this.accountId,
    this.detail,
    this.costCents,
  });

  final String label;

  /// 计入净值的金额（资产为正；负债为**正数欠款**）。
  final int cents;
  final NetWorthBucket bucket;
  final String? accountId;

  /// 下钻说明，例如「含 2 个持仓」。
  final String? detail;

  /// 固定资产的原始成本（与估值并列展示，AC1）。
  final int? costCents;
}

class NetWorthSnapshot {
  const NetWorthSnapshot({
    required this.assets,
    required this.liabilities,
    required this.unpricedHoldings,
    this.skippedForeignDebts = 0,
  });

  final List<NetWorthEntry> assets;
  final List<NetWorthEntry> liabilities;

  /// 有持仓但未录价的账户数（市值不可信，页面要提示）。
  final int unpricedHoldings;

  /// 未纳入净值的外币负债账户数（口径见 `Account.supportsDebtTracking`）。
  final int skippedForeignDebts;

  int get totalAssetsCents => assets.fold(0, (s, e) => s + e.cents);
  int get totalLiabilitiesCents => liabilities.fold(0, (s, e) => s + e.cents);
  int get netCents => totalAssetsCents - totalLiabilitiesCents;

  /// 按分类汇总（资产）。
  Map<NetWorthBucket, int> get assetsByBucket => _group(assets);

  /// 按分类汇总（负债）。
  Map<NetWorthBucket, int> get liabilitiesByBucket => _group(liabilities);

  static Map<NetWorthBucket, int> _group(List<NetWorthEntry> items) {
    final out = <NetWorthBucket, int>{};
    for (final e in items) {
      out[e.bucket] = (out[e.bucket] ?? 0) + e.cents;
    }
    return out;
  }
}

/// 净值序列上的一个点。
class NetWorthPoint {
  const NetWorthPoint({
    required this.label,
    required this.periodEnd,
    required this.assetsCents,
    required this.liabilitiesCents,
  });

  final String label;
  final DateTime periodEnd;
  final int assetsCents;
  final int liabilitiesCents;
  int get netCents => assetsCents - liabilitiesCents;
}

class NetWorthService {
  const NetWorthService({
    AssetValuationService valuation = const AssetValuationService(),
  }) : _valuation = valuation;

  final AssetValuationService _valuation;

  /// 当前净值构成。
  ///
  /// [balances] 是账户派生余额；[holdingsMarketByAccount] 是各投资账户的持仓市值；
  /// [holdingsCountByAccount] 用于下钻说明。
  NetWorthSnapshot snapshot({
    required List<Account> accounts,
    required Map<String, int> balances,
    required Map<String, int> holdingsMarketByAccount,
    required Map<String, int> holdingsCountByAccount,
    required DateTime now,
  }) {
    final assets = <NetWorthEntry>[];
    final liabilities = <NetWorthEntry>[];
    var unpriced = 0;
    var skippedForeignDebts = 0;

    for (final a in accounts) {
      final terms = ValuationTerms.ofAccount(a);
      final bucket = NetWorthBucket.of(a, hasValuation: terms != null);
      final balance = balances[a.id] ?? 0;

      if (terms != null) {
        // 固定资产：计入估算估值，同时带出原始成本
        final v = _valuation.evaluate(terms, now: now);
        assets.add(NetWorthEntry(
          label: a.name,
          cents: v.valueCents,
          bucket: bucket,
          accountId: a.id,
          detail: '${v.months} 个月',
          costCents: v.costCents,
        ));
        continue;
      }

      if (bucket == NetWorthBucket.investment) {
        final market = holdingsMarketByAccount[a.id] ?? 0;
        final count = holdingsCountByAccount[a.id] ?? 0;
        if (count > 0 && market == 0) unpriced++;
        assets.add(NetWorthEntry(
          label: a.name,
          cents: balance + market,
          bucket: bucket,
          accountId: a.id,
          detail: count > 0 ? '含 $count 个持仓' : null,
        ));
        continue;
      }

      if (bucket.isLiability) {
        // 外币贷款不参与净值：本金是原币、流水是本位币，拼不出可信的剩余本金
        // （2026-10-15 口径）。这类账户由用户手动维护，页面另有说明。
        if (a.needsManualDebtNote) {
          skippedForeignDebts++;
          continue;
        }
        // 负债以正数欠款计入（信用卡余额为 −欠款，贷款余额为 −剩余本金）
        liabilities.add(NetWorthEntry(
          label: a.name,
          cents: balance < 0 ? -balance : 0,
          bucket: bucket,
          accountId: a.id,
        ));
        continue;
      }

      assets.add(NetWorthEntry(
        label: a.name,
        cents: balance,
        bucket: bucket,
        accountId: a.id,
      ));
    }

    return NetWorthSnapshot(
      assets: assets,
      liabilities: liabilities,
      unpricedHoldings: unpriced,
      skippedForeignDebts: skippedForeignDebts,
    );
  }

  /// 外币账户期初的折算（V3.0 拍板 2026-10-15）。
  ///
  /// 口径：账户余额只走**本位币口径**（流水恒为本位币，见
  /// `AccountRepositoryImpl._openingForBalance`），而期初余额是用户在原币下填的数，
  /// 因此它必须**先按用户手填的锁定汇率折成本位币**才允许参与净值——
  /// 折算前不参与，绝不把原币数字当本位币混加。
  ///
  /// 返回值：
  /// - 本位币账户 → 原期初值（无需折算）；
  /// - 外币账户 + 有 `<原币>/<本位币>` 锁定汇率 → 折算后的期初（分）；
  /// - 外币账户 + **拿不到汇率** → null，表示该账户**不参与净值**（页面要注明）。
  ///
  /// [rateToBase] 的键是原币代码，值 = 1 单位原币折多少本位币。
  static int? convertedOpeningCents({
    required Account account,
    required Map<String, double> rateToBase,
  }) {
    if (account.currency == MoneyRules.defaultCurrency) return account.openingBalance;
    final rate = rateToBase[account.currency];
    if (rate == null || rate <= 0) return null;
    return (account.openingBalance * rate).round();
  }

  /// 账户在 [asOf] 的派生余额（与 `AccountRepositoryImpl` 同口径的五段式）。
  ///
  /// 信用卡的**存储欠款**没有历史，历史点一律走派生口径。
  ///
  /// [openingCents] 用于外币账户：传入按锁定汇率折算后的期初（分）；
  /// 缺省时用账户自身存储的期初（本位币账户）。
  static int balanceAt({
    required Account account,
    required List<LedgerEntry> entries,
    required DateTime asOf,
    int? openingCents,
  }) {
    var balance = openingCents ?? account.openingBalance;
    for (final e in entries) {
      if (e.isDeleted) continue;
      if (e.occurredAt.isAfter(asOf)) continue;
      if (!e.affectsBalance) continue; // 拆分子笔不计
      final amount = e.amount.cents;
      final isFrom = e.accountId == account.id;
      final isTo = e.toAccountId == account.id;
      switch (e.type) {
        case EntryType.expense:
          if (isFrom) balance -= amount;
        case EntryType.income:
          if (isFrom) balance += amount;
        case EntryType.transfer:
          if (isFrom) balance -= amount;
          if (isTo) balance += amount;
        // STORY-1.7：借出/借入与转出/转入同向（G-2「计入账户余额 = 是」）
        case EntryType.borrowOut:
          if (isFrom) balance -= amount;
        case EntryType.borrowIn:
          if (isFrom) balance += amount;
        case EntryType.repayCredit:
        case EntryType.unknown:
          break;
      }
    }
    return balance;
  }

  /// 逐月净值序列。
  ///
  /// 每个历史点 = Σ账户在期末的派生余额（估值型账户用其估算值）
  /// **+ 持仓当前市值**——投资账户的现金已随交易回算，只有持仓市值没有价格史，
  /// 因此固定按当前市值计入，并在页面注明（见文件头说明）。
  List<NetWorthPoint> monthlySeries({
    required List<Account> accounts,
    required List<LedgerEntry> entries,
    required List<({String label, DateTime periodEnd})> periods,
    required int holdingsMarketCents,
    required DateTime now,
    Map<String, int> openingByAccount = const <String, int>{},
  }) {
    // 估值型账户的估值无法回溯（没有历史持有年数），按当前估算值计入
    final valuationByAccount = <String, int>{};
    for (final a in accounts) {
      final terms = ValuationTerms.ofAccount(a);
      if (terms != null) {
        valuationByAccount[a.id] =
            _valuation.evaluate(terms, now: now).valueCents;
      }
    }

    return [
      for (final p in periods)
        _pointAt(
          accounts: accounts,
          entries: entries,
          label: p.label,
          periodEnd: p.periodEnd,
          valuationByAccount: valuationByAccount,
          holdingsMarketCents: holdingsMarketCents,
          openingByAccount: openingByAccount,
        ),
    ];
  }

  NetWorthPoint _pointAt({
    required List<Account> accounts,
    required List<LedgerEntry> entries,
    required String label,
    required DateTime periodEnd,
    required Map<String, int> valuationByAccount,
    required int holdingsMarketCents,
    required Map<String, int> openingByAccount,
  }) {
    var assets = holdingsMarketCents;
    var liabilities = 0;
    for (final a in accounts) {
      final evaluated = valuationByAccount[a.id];
      if (evaluated != null) {
        assets += evaluated;
        continue;
      }
      final balance = balanceAt(
        account: a,
        entries: _entriesOf(entries, a.id),
        asOf: periodEnd,
        // 外币账户的期初要用折算后的值（拿不到汇率的账户已被调用方剔除）
        openingCents: openingByAccount[a.id],
      );
      if (a.isCredit || a.type == AccountType.loanIn) {
        liabilities += balance < 0 ? -balance : 0;
      } else {
        assets += balance;
      }
    }
    return NetWorthPoint(
      label: label,
      periodEnd: periodEnd,
      assetsCents: assets,
      liabilitiesCents: liabilities,
    );
  }

  static List<LedgerEntry> _entriesOf(List<LedgerEntry> entries, String accountId) => [
        for (final e in entries)
          if (e.accountId == accountId || e.toAccountId == accountId) e,
      ];

  /// 生成最近 [months] 个月的期间（含当月），结束日为该记账月的最后一天。
  static List<({String label, DateTime periodEnd})> recentPeriods({
    required DateTime now,
    required int monthStartDay,
    required int months,
  }) {
    final out = <({String label, DateTime periodEnd})>[];
    for (var i = months - 1; i >= 0; i--) {
      final start = DateTime(now.year, now.month - i, monthStartDay);
      final nextStart = DateTime(start.year, start.month + 1, monthStartDay);
      final end = nextStart.subtract(const Duration(days: 1));
      out.add((
        label: '${start.year}-${start.month.toString().padLeft(2, '0')}',
        periodEnd: DateTime.utc(end.year, end.month, end.day, 23, 59, 59),
      ));
    }
    return out;
  }
}
