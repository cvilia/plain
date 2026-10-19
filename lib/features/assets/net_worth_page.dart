/// SP-2-06 净值追踪 —— 净值构成 + 逐月走势 + 可下钻。
///
/// STORY-10.4：净值 = Σ资产 − Σ负债，**每一项都能下钻到明细**。
/// 构成与序列都从账户余额、持仓市值与交易日历实时算出，页面无写死值。
///
/// 走势口径：账户余额按交易日历回算；持仓无价格史，按**当前市值**计入每个历史点
/// （页面下方注明），不伪造历史价格。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:plain/app/bootstrap.dart';
import 'package:plain/app/breakpoints.dart';
import 'package:plain/app/settings/ledger_settings.dart';
import 'package:plain/app/theme/app_colors.dart';
import 'package:plain/app/theme/design_tokens.dart';
import 'package:plain/core/constants/app_constants.dart';
import 'package:plain/core/format/amount_formatter.dart';
import 'package:plain/design_system/amount_display.dart';
import 'package:plain/design_system/app_empty_state.dart';
import 'package:plain/design_system/app_error_state.dart';
import 'package:plain/design_system/plain_icons_v3.dart';
import 'package:plain/design_system/plain_ui.dart';
import 'package:plain/domain/entities/category.dart';
import 'package:plain/domain/entities/currency_rate.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/entities/holding.dart';
import 'package:plain/domain/entities/ledger_entry.dart';
import 'package:plain/domain/repositories/repositories.dart';
import 'package:plain/domain/services/net_worth_service.dart';
import 'package:plain/features/accounts/credit_reconcile_page.dart';
import 'package:plain/features/assets/debt_optimize_page.dart';
import 'package:plain/features/assets/investment_page.dart';
import 'package:plain/features/assets/loan_page.dart';
import 'package:plain/app/l10n/app_strings.dart';
import 'package:plain/app/l10n/strings_accounts.dart';

const _svc = NetWorthService();

class NetWorthPage extends ConsumerStatefulWidget {
  const NetWorthPage({super.key});
  final int months = 12;

  @override
  ConsumerState<NetWorthPage> createState() => _NetWorthPageState();
}

class _NetWorthPageState extends ConsumerState<NetWorthPage> {
  bool _loading = true;
  Object? _loadError;
  NetWorthSnapshot? _snapshot;
  List<NetWorthPoint> _points = const [];
  List<Account> _accounts = const [];
  List<LedgerEntry> _entries = const [];

  /// 拿不到锁定汇率、因而未计入净值的外币账户名（页面要注明，不能静默少算）。
  List<String> _unconvertedRates = const [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    final deps = ref.read(appDependenciesProvider);

    final accountsRes = await deps.accountRepository.listWithBalances();
    final holdingsRes = await deps.holdingRepository.listByBook(deps.bookId);
    // 序列需要全量流水（扣掉已删的）
    final ledgerRes = await deps.ledgerRepository.listPage(limit: 3000);
    // 外币账户折算要用用户手填的锁定汇率（STORY-9.3）
    final ratesRes = await deps.currencyRateRepository.listByBook(deps.bookId);
    if (!mounted) return;

    final loadFailure = accountsRes.failureOrNull ??
        holdingsRes.failureOrNull ??
        ledgerRes.failureOrNull ??
        ratesRes.failureOrNull;
    if (loadFailure != null) {
      setState(() {
        _loadError = loadFailure;
        _loading = false;
      });
      return;
    }

    final all = accountsRes.successOrNull ?? const <AccountWithBalance>[];
    final holdings = holdingsRes.successOrNull ?? const <Holding>[];

    // ── 外币账户口径（V3.0 拍板 2026-10-15）──
    // 账户余额只走本位币口径（流水恒为本位币，期初在原币下填写，不混加）；
    // 净值里外币账户按锁定汇率折算参与，拿不到汇率则**整个账户不参与**。
    final rateToBase = <String, double>{
      for (final r in ratesRes.successOrNull ?? const <CurrencyRate>[])
        if (r.toCurrency == MoneyRules.defaultCurrency) r.fromCurrency: r.rate,
    };
    final valued = <Account>[];
    final openingInBase = <String, int>{};
    final unconvertedRates = <String>[];
    for (final ab in all) {
      final opening = NetWorthService.convertedOpeningCents(
        account: ab.account,
        rateToBase: rateToBase,
      );
      if (opening == null) {
        unconvertedRates.add(ab.account.name);
        continue;
      }
      valued.add(ab.account);
      if (ab.account.currency != MoneyRules.defaultCurrency) {
        openingInBase[ab.account.id] = opening;
      }
    }

    final balances = {
      for (final ab in all) ab.account.id: ab.balanceCents,
    };
    // 本位币口径余额 + 折算后的期初 = 该账户计入净值的外币折算值
    for (final e in openingInBase.entries) {
      balances[e.key] = (balances[e.key] ?? 0) + e.value;
    }

    final marketByAccount = <String, int>{};
    final countByAccount = <String, int>{};
    for (final h in holdings) {
      marketByAccount[h.accountId] =
          (marketByAccount[h.accountId] ?? 0) + h.marketValueCents;
      countByAccount[h.accountId] = (countByAccount[h.accountId] ?? 0) + 1;
    }

    final now = deps.clock.now();
    final snapshot = _svc.snapshot(
      s: AppStrings.of(context),
      accounts: valued,
      balances: balances,
      holdingsMarketByAccount: marketByAccount,
      holdingsCountByAccount: countByAccount,
      now: now,
    );
    final entries = ledgerRes.successOrNull?.items ?? const <LedgerEntry>[];
    final totalMarket = marketByAccount.values.fold<int>(0, (a, b) => a + b);
    final points = _svc.monthlySeries(
      accounts: valued,
      entries: entries,
      periods: NetWorthService.recentPeriods(
        now: now.toLocal(),
        monthStartDay: ref.read(monthStartDayProvider),
        months: widget.months,
      ),
      holdingsMarketCents: totalMarket,
      now: now,
      openingByAccount: openingInBase,
    );

    setState(() {
      _accounts = valued;
      _entries = entries;
      _snapshot = snapshot;
      _points = points;
      _unconvertedRates = unconvertedRates;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final colors = context.colors;
    return Scaffold(
      appBar: PlainTopBar(
        title: s.netWorthTracking,
        showBack: true,
        actions: [
          // STORY-10.5：债务优化入口
          Material(
            color: const Color(0x00000000),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () => Navigator.of(context, rootNavigator: true).push<void>(
                MaterialPageRoute(builder: (_) => const DebtOptimizePage()),
              ),
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 64,
                height: 44,
                child: Center(
                  child: Text(s.debtOptimize,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: colors.primary)),
                ),
              ),
            ),
          ),
        ],
      ),
      body: _loadError != null
          ? AppErrorState.of(context, _loadError!, onRetry: _reload)
          : _loading
          ? const Center(child: CircularProgressIndicator())
          : ContentWidthConstraint(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    Spacing.lg, 0, Spacing.lg, Spacing.xl),
                children: [
                  if (_snapshot != null) ...[
                    _Hero(snapshot: _snapshot!),
                    PlainEyebrow(s.accounts),
                    if (_snapshot!.assets.isEmpty)
                      _EmptyRow(
                        text: s.noAssetAccounts,
                        actionLabel: s.addAccount,
                        onAction: () => context.push('/accounts'),
                      )
                    else
                      PlainPanel(
                        children: [
                          for (var i = 0; i < _snapshot!.assets.length; i++) ...[
                            if (i > 0)
                              Divider(
                                  height: 1,
                                  thickness: 1,
                                  indent: 16,
                                  color: colors.divider),
                            _EntryRow(
                              entry: _snapshot!.assets[i],
                              colors: colors,
                              onTap: () => _drillDown(_snapshot!.assets[i]),
                            ),
                          ],
                        ],
                      ),
                    PlainEyebrow(s.liabilities),
                    if (_snapshot!.liabilities.isEmpty)
                      _EmptyRow(text: s.noLiabilityAccounts)
                    else
                      PlainPanel(
                        children: [
                          for (var i = 0;
                              i < _snapshot!.liabilities.length;
                              i++) ...[
                            if (i > 0)
                              Divider(
                                  height: 1,
                                  thickness: 1,
                                  indent: 16,
                                  color: colors.divider),
                            _EntryRow(
                              entry: _snapshot!.liabilities[i],
                              colors: colors,
                              onTap: () => _drillDown(_snapshot!.liabilities[i]),
                            ),
                          ],
                        ],
                      ),
                    PlainEyebrow(s.netWorthTrend),
                    PlainPanel(
                      children: [
                        if (_points.isEmpty)
                          _EmptyRow(text: s.noData)
                        else
                          _TrendPanel(points: _points),
                      ],
                    ),
                    const SizedBox(height: Spacing.md),
                    _NotePanel(
                      unpricedHoldings: _snapshot!.unpricedHoldings,
                      hasValuation: _accounts.any(
                          (a) => a.valuationMode.isActive),
                      unconvertedRates: _unconvertedRates,
                      skippedForeignDebts: _snapshot!.skippedForeignDebts,
                    ),
                  ] else
                    AppEmptyState(
                      icon: PlainIconData.chartLine,
                      title: s.noDataYet,
                      subtitle: s.netWorthEmptyHint,
                    ),
                ],
              ),
            ),
    );
  }

  /// AC1/AC2/AC3 的下钻：能进专页的进专页，否则列出该账户流水。
  Future<void> _drillDown(NetWorthEntry entry) async {
    final accountId = entry.accountId;
    if (accountId == null) return;
    final account = _accounts.where((a) => a.id == accountId).firstOrNull;
    if (account == null) return;

    switch (account.type) {
      case AccountType.investment:
        await Navigator.of(context, rootNavigator: true).push<void>(
          MaterialPageRoute(builder: (_) => InvestmentPage(accountId: accountId)),
        );
      case AccountType.loanIn:
        await Navigator.of(context, rootNavigator: true).push<void>(
          MaterialPageRoute(builder: (_) => LoanPage(accountId: accountId)),
        );
      case AccountType.credit:
        await Navigator.of(context, rootNavigator: true).push<void>(
          MaterialPageRoute(
              builder: (_) => CreditReconcilePage(accountId: accountId)),
        );
      default:
        if (!mounted) return;
        await _showEntriesSheet(account);
    }
    if (mounted) _reload();
  }

  /// 普通账户的下钻明细：列出该账户真实流水。
  Future<void> _showEntriesSheet(Account account) async {
    final s = AppStrings.of(context);
    final mine = _entries
        .where((e) => e.accountId == account.id || e.toAccountId == account.id)
        .toList();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(ctx).height * 0.6,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(Spacing.lg),
                child: Row(children: [
                  Expanded(
                    child: Text(s.accountEntriesCount(account.name, mine.length),
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(s.close)),
                ]),
              ),
              const Divider(height: 1),
              Expanded(
                child: mine.isEmpty
                    ? _EmptyRow(text: s.noAccountEntries)
                    : ListView.builder(
                        itemCount: mine.length,
                        itemBuilder: (ctx, i) {
                          final e = mine[i];
                          final local = e.occurredAt.toLocal();
                          return ListTile(
                            dense: true,
                            title: Text(
                              '${local.month.toString().padLeft(2, '0')}-'
                              '${local.day.toString().padLeft(2, '0')}'
                              '${e.note == null || e.note!.isEmpty ? '' : ' · ${e.note}'}',
                              style: const TextStyle(fontSize: 14),
                            ),
                            trailing: AmountDisplay(
                                cents: e.amount.cents, fontSize: 14),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.snapshot});
  final NetWorthSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: Spacing.sm, bottom: Spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(height: 1, thickness: 1, color: colors.divider),
          Padding(
            padding: const EdgeInsets.fromLTRB(2, Spacing.lg, 2, Spacing.sm),
            child: Text(
              s.currentNetWorth,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.08 * 12,
                color: colors.inkTertiary,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: Spacing.lg),
            child: AmountDisplay(
              cents: snapshot.netCents,
              fontSize: 34,
              integerWeight: FontWeight.w700,
              // 净值为负时必须是 `¥-1,786.00`：以前这里会把负号吃掉
              showValueSign: true,
            ),
          ),
          Row(children: [
            Expanded(
              child: _Split(
                  label: s.totalAssets, cents: snapshot.totalAssetsCents),
            ),
            const SizedBox(width: Spacing.lg),
            Expanded(
              child: _Split(
                  label: s.totalLiabilities, cents: snapshot.totalLiabilitiesCents),
            ),
          ]),
          Padding(
            padding: const EdgeInsets.only(top: Spacing.lg),
            child: Divider(height: 1, thickness: 1, color: colors.divider),
          ),
        ],
      ),
    );
  }
}

class _Split extends StatelessWidget {
  const _Split({required this.label, required this.cents});
  final String label;
  final int cents;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: colors.inkTertiary)),
        const SizedBox(height: 4),
        Text(formatAmountYuan(cents),
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: colors.ink)),
      ],
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.entry,
    required this.colors,
    required this.onTap,
  });
  final NetWorthEntry entry;
  final AppColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final e = entry;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(
                  e.label,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              AmountDisplay(cents: e.cents, fontSize: 15),
            ]),
            const SizedBox(height: 2),
            Text(
              [
                e.bucket.label(s),
                if (e.detail != null) e.detail!,
                // 固定资产并列展示原始成本（AC1）
                if (e.costCents != null)
                  s.originalValue(formatAmountYuan(e.costCents!)),
              ].join(' · '),
              style: TextStyle(fontSize: 12, color: colors.inkTertiary),
            ),
          ],
        ),
      ),
    );
  }
}

/// 走势：按月一根条形 + 数值，避免引入额外图表依赖。
class _TrendPanel extends StatelessWidget {
  const _TrendPanel({required this.points});
  final List<NetWorthPoint> points;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // 时间倒序：最近一个月在最上面。数据源是升序（旧→新），这里翻一次，
    // 不要改 `monthlySeries` —— 别处（如趋势计算）依赖升序。
    final rows = points.reversed.toList();
    final maxAbs = rows
        .map((p) => p.netCents.abs())
        .fold<int>(1, (a, b) => a > b ? a : b);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, Spacing.md, 16, Spacing.md),
      child: Column(
        children: [
          for (final p in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                SizedBox(
                  width: 58,
                  child: Text(p.label,
                      style: TextStyle(fontSize: 12, color: colors.inkTertiary)),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: Stack(children: [
                      Container(height: 8, color: colors.surfaceMuted),
                      FractionallySizedBox(
                        widthFactor: (p.netCents.abs() / maxAbs).clamp(0.0, 1.0),
                        child: Container(
                          height: 8,
                          color: p.netCents >= 0
                              ? colors.income
                              : colors.expense,
                        ),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 92,
                  child: Text(
                    formatAmountYuan(p.netCents),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colors.ink),
                  ),
                ),
              ]),
            ),
        ],
      ),
    );
  }
}

class _EmptyRow extends StatelessWidget {
  const _EmptyRow({required this.text, this.actionLabel, this.onAction});
  final String text;

  /// 空态不能是死胡同：能给出下一步时传 label + 回调。
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Row(
          children: [
            Expanded(
              child: Text(text,
                  style: TextStyle(
                      fontSize: 14, color: context.colors.inkTertiary)),
            ),
            if (actionLabel != null && onAction != null)
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ),
      );
}

class _NotePanel extends StatelessWidget {
  const _NotePanel({
    required this.unpricedHoldings,
    required this.hasValuation,
    required this.unconvertedRates,
    this.skippedForeignDebts = 0,
  });
  final int unpricedHoldings;

  /// 未纳入净值的外币负债账户数（口径：外币贷款不参与债务测算）。
  final int skippedForeignDebts;
  final bool hasValuation;

  /// 没有锁定汇率、因此未计入净值的外币账户名。
  final List<String> unconvertedRates;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final colors = context.colors;
    final lines = <String>[
      s.netWorthTrendNote,
    ];
    if (unpricedHoldings > 0) {
      lines.add(s.unpricedHoldingsNote(unpricedHoldings));
    }
    if (unconvertedRates.isNotEmpty) {
      // 口径：外币账户按锁定汇率折算参与净值；没汇率就不参与（不混加原币）
      lines.add(s.unconvertedRatesNote(unconvertedRates.join('、')));
    }
    if (skippedForeignDebts > 0) {
      // 外币负债不参与净值：本金原币、流水本位币，硬算会得出 0 或混加出来的假数字
      lines.add(s.skippedForeignDebtsNote(skippedForeignDebts));
    }
    if (hasValuation) {
      lines.add(s.valuationNote);
    }
    lines.add(s.holdingHistoryNote);
    return PlainPanel(
      padding: const EdgeInsets.all(Spacing.lg),
      children: [
        for (final l in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(l,
                style: TextStyle(
                    fontSize: 14, height: 1.65, color: colors.inkSecondary)),
          ),
      ],
    );
  }
}
