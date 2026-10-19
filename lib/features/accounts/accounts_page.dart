/// Account management page (SP-2-01). See PRD STORY-2.1.
library;

import 'package:plain/app/theme/app_colors.dart';
import 'package:plain/design_system/amount_display.dart';
import 'package:plain/design_system/plain_icons_v3.dart';
import 'package:plain/design_system/plain_ui.dart';
import 'package:plain/design_system/amount_text.dart';
import 'package:plain/design_system/app_empty_state.dart';
import 'package:plain/design_system/app_error_state.dart';
import 'package:plain/design_system/app_toast.dart';
import 'package:plain/features/accounts/credit_reconcile_page.dart';
import 'package:plain/features/accounts/reconcile_mode_page.dart';
import 'package:plain/features/assets/investment_page.dart';
import 'package:plain/features/assets/loan_page.dart';
import 'package:plain/features/assets/net_worth_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plain/app/bootstrap.dart';
import 'package:plain/app/breakpoints.dart';
import 'package:plain/app/l10n/app_strings.dart';
import 'package:plain/app/l10n/strings_settings_b.dart';
import 'package:plain/app/l10n/strings_accounts.dart';
import 'package:plain/app/theme/design_tokens.dart';
import 'package:plain/core/constants/app_constants.dart';
import 'package:plain/core/format/amount_formatter.dart';
import 'package:plain/core/money/money.dart';
import 'package:plain/core/refresh/data_invalidation.dart';
import 'package:plain/core/time/date_format.dart';
import 'package:plain/design_system/app_date_picker.dart';
import 'package:plain/design_system/picker_sheet.dart';
import 'package:plain/domain/entities/category.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/entities/ledger_entry.dart';
import 'package:plain/domain/repositories/repositories.dart';
import 'package:plain/domain/usecases/entry_usecases.dart';
import 'package:plain/app/l10n/strings_domain.dart';

final _accountsProvider = FutureProvider<List<_AccountWithBalance>>((ref) async {
  // Refetch when accounts or ledger entries change (balances derive from both).
  ref.watch(accountsVersionProvider);
  ref.watch(ledgerVersionProvider);
  final deps = ref.watch(appDependenciesProvider);
  final res = await deps.accountRepository.listWithBalances();
  final list = res.successOrNull ?? const <AccountWithBalance>[];
  // STORY-2.3：待对账角标 — 未勾选笔数
  final pendingMap = <String, int>{};
  for (final aw in list) {
    final page = await deps.ledgerRepository.listPage(
      filter: EntryFilter(accountId: aw.account.id),
      limit: 500,
    );
    final items = page.successOrNull?.items ?? const <LedgerEntry>[];
    pendingMap[aw.account.id] = items.where((e) => !e.isReconciled).length;
  }
  return [
    for (final aw in list)
      _AccountWithBalance.from(aw, pendingReconcile: pendingMap[aw.account.id] ?? 0),
  ];
});

/// Flat view-model the list UI already expects.
class _AccountWithBalance {
  const _AccountWithBalance({
    required this.account,
    required this.balance,
    this.pendingReconcile = 0,
  });
  final Account account;
  final int balance;
  final int pendingReconcile;

  String get id => account.id;
  String get name => account.name;
  AccountType get type => account.type;
  int get openingBalance => account.openingBalance;
  bool get isHidden => account.isHidden;
  bool get isCredit => account.isCredit;
  bool get isLoan => account.isLoan;
  bool get isOverLimit => account.isOverLimit;
  int get creditAvailableCents => account.creditAvailableCents;

  factory _AccountWithBalance.from(AccountWithBalance src, {int pendingReconcile = 0}) =>
      _AccountWithBalance(
        account: src.account,
        balance: src.balanceCents,
        pendingReconcile: pendingReconcile,
      );
}

class AccountsPage extends ConsumerWidget {
  const AccountsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final accountsAsync = ref.watch(_accountsProvider);

    return Scaffold(
      appBar: PlainTopBar(
        title: s.accounts,
        // 底部 Tab 页是导航终点，没有「上一页」可回 —— 不放返回箭头
        // （标题居中由 PlainTopBar 的默认行为统一负责）
        actions: [
          // STORY-10.4：净值追踪入口
          Material(
            color: const Color(0x00000000),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () => Navigator.push<void>(
                context,
                MaterialPageRoute(builder: (_) => const NetWorthPage()),
              ),
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 52,
                height: 44,
                child: Center(
                  child: Text(s.netWorth,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: context.colors.primary)),
                ),
              ),
            ),
          ),
          Material(
            color: const Color(0x00000000),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () => _showAddSheet(context, ref),
              borderRadius: BorderRadius.circular(12),
              child: const SizedBox(
                width: 44,
                height: 44,
                child: Center(child: PlainIcon(PlainIconData.plus, size: 22)),
              ),
            ),
          ),
        ],
      ),
      body: accountsAsync.when(
        data: (accounts) {
          if (accounts.isEmpty) {
            return ContentWidthConstraint(
              child: AppEmptyState(
                icon: PlainIconData.wallet,
                title: s.noAccounts,
                subtitle: s.addCashOrCard,
                action: FilledButton.icon(
                  onPressed: () => _showAddSheet(context, ref),
                  icon: const PlainIcon(PlainIconData.plus),
                  label: Text(s.addAccount),
                ),
              ),
            );
          }

          final netAssets = accounts.fold(0, (sum, a) => sum + a.balance);

          return ContentWidthConstraint(
            child: ListView(
              padding: const EdgeInsets.all(Spacing.lg),
              children: [
                // Quiet Ledger: 净资产纯排印，无卡片
                Padding(
                  padding: const EdgeInsets.only(top: 14, bottom: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.netAssets,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.08 * 12,
                          color: context.colors.inkTertiary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      AmountDisplay(
                        cents: netAssets,
                        fontSize: 34,
                        integerWeight: FontWeight.w700,
                      ),
                      const SizedBox(height: 16),
                      Divider(height: 1, thickness: 1, color: context.colors.border),
                    ],
                  ),
                ),
                // 资产
                Padding(
                  padding: const EdgeInsets.fromLTRB(2, 8, 2, 8),
                  child: Text(
                    s.accounts,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.08 * 12,
                      color: context.colors.inkTertiary,
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: context.colors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.colors.border),
                  ),
                  child: Column(
                    children: [
                      for (final a in accounts.where((x) => x.balance >= 0))
                        _AccountTile(
                          account: a,
                          onRefresh: () => ref.invalidateData.bumpAccountsMutated(),
                          onReconcile: () {
                            if (a.type == AccountType.credit) {
                              _openCreditReconcile(context, a.id);
                            } else if (a.isLoan) {
                              // STORY-10.2：贷款账户进摊销页
                              Navigator.push<void>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => LoanPage(accountId: a.id),
                                ),
                              );
                            } else if (a.type == AccountType.investment) {
                              // STORY-10.1：投资账户进持仓页
                              Navigator.push<void>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => InvestmentPage(accountId: a.id),
                                ),
                              );
                            } else {
                              _showReconcileDialog(context, ref, a);
                            }
                          },
                        ),
                    ],
                  ),
                ),
                // 负债
                if (accounts.any((x) => x.balance < 0)) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(2, 24, 2, 8),
                    child: Text(
                      s.liabilities,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.08 * 12,
                        color: context.colors.inkTertiary,
                      ),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: context.colors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: context.colors.border),
                    ),
                    child: Column(
                      children: [
                        for (final a in accounts.where((x) => x.balance < 0))
                          _AccountTile(
                            account: a,
                            onRefresh: () => ref.invalidateData.bumpAccountsMutated(),
                            onReconcile: () {
                              if (a.type == AccountType.credit) {
                                _openCreditReconcile(context, a.id);
                              } else if (a.isLoan) {
                                Navigator.push<void>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => LoanPage(accountId: a.id),
                                  ),
                                );
                              } else {
                                _showReconcileDialog(context, ref, a);
                              }
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AppErrorState.of(context, e,
            onRetry: () => ref.invalidateData.bumpEverything()),
      ),
    );
  }

  void _showAddSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: _AddAccountSheet(onSaved: () {
          ref.invalidateData.bumpAccountsMutated();
        }),
      ),
    );
  }

  void _openCreditReconcile(BuildContext context, String accountId) {
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => CreditReconcilePage(accountId: accountId),
      ),
    );
  }

  void _showReconcileDialog(BuildContext context, WidgetRef ref, _AccountWithBalance account) {
    final s = AppStrings.of(context);
    final ctrl = TextEditingController(text: formatAmount(account.balance));
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.reconcile),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text('${s.currentBalance}: ', style: TextStyle(color: context.colors.inkSecondary)),
              AmountWithCurrency(cents: account.balance),
            ]),
            const SizedBox(height: Spacing.md),
            TextField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: s.actualBalance, border: const OutlineInputBorder(), prefixText: '\u00a5'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.cancel)),
          FilledButton(
            onPressed: () async {
              final text = ctrl.text.trim();
              if (text.isEmpty) return;
              final int actualCents;
              try {
                actualCents = Money.parseYuan(text).cents;
              } on FormatException {
                return;
              }
              final diff = actualCents - account.balance;

              if (diff != 0) {
                // Route through CreateEntryUseCase so change_log / daily_stats /
                // UUID / revision are all written (raw INSERT used to skip them).
                final deps = ref.read(appDependenciesProvider);
                final isExpense = diff < 0;
                final result = await deps.createEntry(CreateEntryInput(
                  amountExpression: formatAmount(diff.abs()),
                  type: isExpense ? EntryType.expense : EntryType.income,
                  categoryId: isExpense ? 'preset_other' : 'preset_income_other',
                  accountId: account.id,
                  // i18n-exempt: 写库系统备注，属数据非界面文案
                  note: '对账调整',
                  source: EntrySource.reconcile,
                  bookId: deps.bookId,
                  deviceId: deps.deviceId,
                ), s: s);
                if (result.isFailure) {
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) showAppToast(context, s.reconcileFailed(result.failureOrNull?.code ?? s.unknownError));
                  return;
                }
              }

              if (ctx.mounted) Navigator.pop(ctx);
              ref.invalidateData.bumpAccountsMutated();
              ref.invalidateData.bumpEntryMutated();
            },
            child: Text(s.reconcile),
          ),
        ],
      ),
    );
  }
}

class _AccountTile extends ConsumerWidget {
  const _AccountTile({
    required this.account,
    required this.onRefresh,
    required this.onReconcile,
  });
  final _AccountWithBalance account;
  final VoidCallback onRefresh;
  final VoidCallback onReconcile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final colors = context.colors;
    final typeLabel = switch (account.type) {
      AccountType.cash => s.cash,
      AccountType.debit => s.debitCard,
      AccountType.credit => s.accountTypeCredit,
      AccountType.investment => s.accountTypeInvestment,
      AccountType.loanIn => s.accountTypeLoan,
      AccountType.loanOut => s.entryBorrowOut,
      AccountType.goal => s.accountTypeGoal,
      _ => s.account,
    };
    final iconRef = switch (account.type) {
      AccountType.cash => 'wallet',
      AccountType.debit => 'card',
      AccountType.credit => 'receipt',
      AccountType.investment => 'chartLine',
      AccountType.loanIn => 'chartLine',
      AccountType.loanOut => 'chartLine',
      _ => 'other',
    };

    return InkWell(
      onTap: () => _showReconcileDialog(context, ref, account),
      child: Container(
        constraints: const BoxConstraints(minHeight: 60),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: colors.divider, width: 1)),
        ),
        child: Row(
          children: [
            PlainIcon(
              iconRef == 'wallet'
                  ? PlainIconData.wallet
                  : iconRef == 'card'
                      ? PlainIconData.card
                      : iconRef == 'receipt'
                          ? PlainIconData.receipt
                          : iconRef == 'chartLine'
                              ? PlainIconData.chartLine
                              : PlainIconData.wallet,
              size: 22,
              color: colors.inkSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    typeLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: colors.inkTertiary,
                    ),
                  ),
                  // STORY-2.3 AC1/AC3：待对账 N 笔角标（全部勾完即消失）。
                  // 点它进逐笔对账模式，与整行的「数字对账」是两条不同路径。
                  if (account.pendingReconcile > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: InkWell(
                        onTap: () => Navigator.push<void>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ReconcileModePage(
                              accountId: account.id,
                              accountName: account.name,
                            ),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            s.pendingReconcileCount(account.pendingReconcile),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: colors.accent,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            AmountDisplay(cents: account.balance, fontSize: 15),
            const SizedBox(width: 4),
            PlainIcon(
              PlainIconData.chevronRight,
              size: 20,
              color: colors.inkFaint,
            ),
          ],
        ),
      ),
    );
  }

  void _showReconcileDialog(BuildContext context, WidgetRef ref, dynamic a) {
    // keep existing dialog via parent callback style — simplified
    onReconcile();
  }
}

class _AddAccountSheet extends ConsumerStatefulWidget {
  // ignore: unused_element_parameter
  const _AddAccountSheet({required this.onSaved, this.editing});
  final VoidCallback onSaved;
  final Account? editing;

  @override
  ConsumerState<_AddAccountSheet> createState() => _AddAccountSheetState();
}

class _AddAccountSheetState extends ConsumerState<_AddAccountSheet> {
  final _nameCtrl = TextEditingController();
  final _openingCtrl = TextEditingController(text: '0');
  final _noteCtrl = TextEditingController();
  final _limitCtrl = TextEditingController(text: '0');
  final _billDayCtrl = TextEditingController();
  final _dueDayCtrl = TextEditingController();
  final _minPayCtrl = TextEditingController();
  final _creditRateCtrl = TextEditingController();
  // STORY-10.2 贷款参数
  final _loanPrincipalCtrl = TextEditingController();
  final _loanRateCtrl = TextEditingController();
  final _loanTermCtrl = TextEditingController();
  LoanRepayMethod _loanMethod = LoanRepayMethod.equalInstallment;
  DateTime? _loanFirstPaymentAt;
  String? _repayAccountId;
  String? _interestCategoryId;
  List<Account> _repayCandidates = const [];
  List<Category> _interestCategories = const [];
  // STORY-10.3 资产估值
  AssetValuationMode _valuationMode = AssetValuationMode.none;
  final _valBaseCtrl = TextEditingController();
  final _valRateCtrl = TextEditingController();
  final _valManualCtrl = TextEditingController();
  DateTime? _valuationStartedAt;
  AccountType _type = AccountType.cash;
  String _currency = 'CNY';
  bool _saving = false;

  bool get _isEditing => widget.editing != null;
  bool get _isLoan => _type == AccountType.loanIn;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    if (e != null) {
      _nameCtrl.text = e.name;
      // 信用卡的权威数字是「欠款余额」（存储值），期初余额对它无意义。
      _openingCtrl.text = e.type == AccountType.credit
          ? (e.creditDebtCents / 100).toStringAsFixed(2)
          : (e.openingBalance / 100).toStringAsFixed(2);
      _noteCtrl.text = e.note ?? '';
      _type = e.type;
      _currency = e.currency;
      _limitCtrl.text = (e.creditLimitCents / 100).toStringAsFixed(2);
      _billDayCtrl.text = e.billDay?.toString() ?? '';
      _dueDayCtrl.text = e.dueDay?.toString() ?? '';
      _minPayCtrl.text = e.minPaymentCents > 0
          ? (e.minPaymentCents / 100).toStringAsFixed(2)
          : '';
      _creditRateCtrl.text =
          e.creditAnnualRateBp > 0 ? _rateTextOf(e.creditAnnualRateBp) : '';
      _loanPrincipalCtrl.text = e.loanPrincipalCents > 0
          ? (e.loanPrincipalCents / 100).toStringAsFixed(2)
          : '';
      _loanRateCtrl.text =
          e.loanAnnualRateBp > 0 ? _rateTextOf(e.loanAnnualRateBp) : '';
      _loanTermCtrl.text = e.loanTermMonths?.toString() ?? '';
      _loanMethod = e.loanRepayMethod ?? LoanRepayMethod.equalInstallment;
      _loanFirstPaymentAt = e.loanFirstPaymentAt;
      _valuationMode = e.valuationMode;
      _valBaseCtrl.text = e.valuationBaseCents > 0
          ? (e.valuationBaseCents / 100).toStringAsFixed(2)
          : '';
      _valRateCtrl.text = e.valuationRateBp != 0
          ? _rateTextOf(e.valuationRateBp.abs())
          : '';
      _valManualCtrl.text = e.valuationManualCents > 0
          ? (e.valuationManualCents / 100).toStringAsFixed(2)
          : '';
      _valuationStartedAt = e.valuationStartedAt;
    }
    _loadPickerOptions();
  }

  /// 贷款要选「还款账户」与「利息分类」，两者都来自库，不写死。
  Future<void> _loadPickerOptions() async {
    final deps = ref.read(appDependenciesProvider);
    final accs = await deps.accountRepository.listAll();
    final cats = await deps.categoryRepository.listAll();
    if (!mounted) return;
    setState(() {
      _repayCandidates = (accs.successOrNull ?? const <Account>[])
          .where((a) => !a.type.isVirtual && !a.isLoan)
          .toList();
      _interestCategories = (cats.successOrNull ?? const <Category>[])
          .where((c) => c.kind == CategoryKind.expense && !c.isHidden)
          .toList();
      _repayAccountId ??=
          _repayCandidates.isEmpty ? null : _repayCandidates.first.id;
      _interestCategoryId ??= _interestCategories.isEmpty
          ? null
          : _interestCategories
              .firstWhere((c) => c.id == 'preset_other',
                  orElse: () => _interestCategories.first)
              .id;
    });
  }

  /// 490 → "4.9"（去掉无意义的尾随零）
  static String _rateTextOf(int bp) {
    final s = (bp / 100).toStringAsFixed(2);
    return s.endsWith('0') ? s.substring(0, s.length - 1) : s;
  }

  /// "4.9" → 490
  static int? _rateBpOf(String text) {
    final v = double.tryParse(text.trim());
    if (v == null || v < 0) return null;
    return (v * 100).round();
  }

  /// 金额文本 → 分（非法输入按 0）。
  static int _centsOf(String text) {
    try {
      return Money.parseYuan(text.trim()).cents;
    } on FormatException {
      return 0;
    }
  }

  /// 还款账户的显示名 —— 字段里存的是 id，展示要回查名称。
  String get _repayAccountName {
    final s = AppStrings.of(context);
    final id = _repayAccountId;
    if (id == null) return s.notSelected;
    for (final a in _repayCandidates) {
      if (a.id == id) return a.name;
    }
    return s.notSelected;
  }

  /// 利息分类的显示名 —— 字段里存的是 id，展示要回查名称。
  String get _interestCategoryName {
    final s = AppStrings.of(context);
    final id = _interestCategoryId;
    if (id == null) return s.notSelected;
    for (final c in _interestCategories) {
      if (c.id == id) return c.name;
    }
    return s.notSelected;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _openingCtrl.dispose();
    _noteCtrl.dispose();
    _limitCtrl.dispose();
    _billDayCtrl.dispose();
    _dueDayCtrl.dispose();
    _minPayCtrl.dispose();
    _creditRateCtrl.dispose();
    _loanPrincipalCtrl.dispose();
    _loanRateCtrl.dispose();
    _loanTermCtrl.dispose();
    _valBaseCtrl.dispose();
    _valRateCtrl.dispose();
    _valManualCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Padding(
      padding: EdgeInsets.only(left: Spacing.lg, right: Spacing.lg, top: Spacing.lg, bottom: MediaQuery.viewInsetsOf(context).bottom + Spacing.lg),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_isEditing ? s.editAccount : s.addAccount, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: Spacing.lg),
            Wrap(
            spacing: Spacing.sm,
            runSpacing: Spacing.sm,
            children: [
              _TypeOption(label: s.cash, icon: PlainIconData.amount, selected: _type == AccountType.cash, onTap: () => setState(() => _type = AccountType.cash)),
              _TypeOption(label: s.debitCard, icon: PlainIconData.card, selected: _type == AccountType.debit, onTap: () => setState(() => _type = AccountType.debit)),
              _TypeOption(label: s.accountTypeCredit, icon: PlainIconData.card, selected: _type == AccountType.credit, onTap: () => setState(() => _type = AccountType.credit)),
              _TypeOption(label: s.accountTypeInvestment, icon: PlainIconData.trendUp, selected: _type == AccountType.investment, onTap: () => setState(() => _type = AccountType.investment)),
              // STORY-10.2：贷款账户（借入 = 负债），带摊销参数
              _TypeOption(label: s.accountTypeLoan, icon: PlainIconData.chartLine, selected: _type == AccountType.loanIn, onTap: () => setState(() => _type = AccountType.loanIn)),
            ],
          ),
          const SizedBox(height: Spacing.lg),
          TextField(controller: _nameCtrl, maxLength: 20, decoration: InputDecoration(labelText: s.nameLabel, hintText: s.nameHintCash, border: OutlineInputBorder())),
          const SizedBox(height: Spacing.md),
          // 本表单的选择项统一走底部弹层（`design_system/picker_sheet.dart`），
          // 不用系统下拉：选项带说明、宽度和高度都可控。
          PickerField(
            label: s.currency,
            value: '${CurrencyRules.symbolOf(_currency)}  $_currency  '
                '${CurrencyRules.nameOf(_currency)}',
            onTap: () async {
              final picked = await showCurrencyPicker(
                context: context,
                currencies: CurrencyRules.symbols.keys.toList(),
                current: _currency,
              );
              if (picked != null) setState(() => _currency = picked);
            },
          ),
          const SizedBox(height: Spacing.md),
          // 信用卡的权威数字是「欠款余额」（G-2.1 存储值），开户时由这一栏写入；
          // 开户之后它由账单入账与对账页维护，因此编辑态不再提供直接改它的入口。
          // 贷款同理：期初余额恒为 −贷款总额，由本金栏推导，不单独问用户。
          if ((_isEditing && _type == AccountType.credit) || _isLoan)
            Text(
              _isLoan
                  ? s.loanOpeningAutoNote
                  : s.creditDebtMaintainedNote,
              style: TextStyle(fontSize: 12, color: context.colors.inkTertiary),
            )
          else ...[
            TextField(controller: _openingCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: _type == AccountType.credit ? s.openingDebt : s.openingBalance, hintText: '0.00', border: const OutlineInputBorder(), prefixText: '¥')),
            // V3.0 口径（外币账户按单币种处理）：账户余额只走本位币口径，
            // 原币期初不并入余额，而是在净值里按锁定汇率折算参与。
            if (_currency != MoneyRules.defaultCurrency)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  s.foreignOpeningNote(_currency),
                  style: TextStyle(fontSize: 12, color: context.colors.inkTertiary),
                ),
              ),
          ],
          if (_type == AccountType.credit) ...[
            const SizedBox(height: Spacing.md),
            TextField(
              controller: _limitCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: s.creditLimit, hintText: '0.00', border: OutlineInputBorder(), prefixText: '¥'),
            ),
            const SizedBox(height: Spacing.md),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _billDayCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: s.billDayLabel, border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: TextField(
                  controller: _dueDayCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: s.dueDayLabel, border: OutlineInputBorder()),
                ),
              ),
            ]),
            const SizedBox(height: Spacing.md),
            // STORY-10.5：债务优化需要的最低还款与循环年利率（账单上的事实）
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _minPayCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                      labelText: s.minPayment,
                      hintText: '0.00',
                      border: OutlineInputBorder(),
                      prefixText: '¥'),
                ),
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: TextField(
                  controller: _creditRateCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                      labelText: s.creditAnnualRateLabel,
                      hintText: '18',
                      border: OutlineInputBorder()),
                ),
              ),
            ]),
          ],
          // ── STORY-10.2 贷款参数：摊销表由这些参数派生，不存表 ──
          if (_isLoan) ...[
            const SizedBox(height: Spacing.md),
            TextField(
              controller: _loanPrincipalCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: s.loanPrincipal, hintText: '0.00', border: OutlineInputBorder(), prefixText: '¥'),
            ),
            const SizedBox(height: Spacing.md),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _loanRateCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: s.annualRateLabel, hintText: '4.9', border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: TextField(
                  controller: _loanTermCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: s.termMonthsLabel, hintText: '360', border: OutlineInputBorder()),
                ),
              ),
            ]),
            const SizedBox(height: Spacing.md),
            PickerField(
              label: s.repayMethod,
              value: _loanMethod.label(AppStrings.of(context)),
              onTap: () async {
                final picked = await showOptionPicker<LoanRepayMethod>(
                  context: context,
                  title: s.repayMethod,
                  current: _loanMethod,
                  options: [
                    PickerOption(
                      value: LoanRepayMethod.equalInstallment,
                      label: LoanRepayMethod.equalInstallment.label(AppStrings.of(context)),
                      description: s.equalInstallmentDesc,
                    ),
                    PickerOption(
                      value: LoanRepayMethod.equalPrincipal,
                      label: LoanRepayMethod.equalPrincipal.label(AppStrings.of(context)),
                      description: s.equalPrincipalDesc,
                    ),
                  ],
                );
                if (picked != null) setState(() => _loanMethod = picked);
              },
            ),
            const SizedBox(height: Spacing.md),
            PlainRow(
              title: s.firstPaymentDate,
              value: _loanFirstPaymentAt == null
                  ? s.repayNotSet
                  : formatDate(_loanFirstPaymentAt!),
              showChevron: true,
              onTap: () async {
                final picked = await showAppDatePicker(
                  context: context,
                  initialDate: _loanFirstPaymentAt?.toLocal() ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now().add(const Duration(days: 3650)),
                );
                if (picked != null) {
                  setState(() => _loanFirstPaymentAt = picked.toUtc());
                }
              },
            ),
            const SizedBox(height: Spacing.md),
            PickerField(
              label: s.repayAccount,
              value: _repayAccountName,
              onTap: () async {
                final picked = await showOptionPicker<String>(
                  context: context,
                  title: s.repayAccount,
                  current: _repayAccountId,
                  options: [
                    for (final a in _repayCandidates)
                      PickerOption(value: a.id, label: a.name),
                  ],
                );
                if (picked != null) setState(() => _repayAccountId = picked);
              },
            ),
            const SizedBox(height: Spacing.md),
            PickerField(
              label: s.interestCategoryLabel,
              value: _interestCategoryName,
              onTap: () async {
                final picked = await showOptionPicker<String>(
                  context: context,
                  title: s.interestCategory,
                  current: _interestCategoryId,
                  options: [
                    for (final c in _interestCategories)
                      PickerOption(value: c.id, label: c.name),
                  ],
                );
                if (picked != null) {
                  setState(() => _interestCategoryId = picked);
                }
              },
            ),
          ],
          // ── STORY-10.3 资产估值：纯估算，只影响资产总览展示 ──
          if (!_isLoan && _type != AccountType.credit) ...[
            const SizedBox(height: Spacing.md),
            PickerField(
              label: s.valuationMode,
              value: _valuationMode.label(AppStrings.of(context)),
              onTap: () async {
                final picked = await showOptionPicker<AssetValuationMode>(
                  context: context,
                  title: s.valuationMode,
                  current: _valuationMode,
                  options: [
                    for (final m in AssetValuationMode.values)
                      PickerOption(
                        value: m,
                        label: m.label(AppStrings.of(context)),
                        description: switch (m) {
                          AssetValuationMode.none => s.valuationNoneDesc,
                          AssetValuationMode.fixed => s.valuationFixedDesc,
                          AssetValuationMode.depreciate => s.valuationDepreciateDesc,
                          AssetValuationMode.appreciate => s.valuationAppreciateDesc,
                          AssetValuationMode.manual => s.valuationManualDesc,
                        },
                      ),
                  ],
                );
                if (picked != null) setState(() => _valuationMode = picked);
              },
            ),
            if (_valuationMode == AssetValuationMode.depreciate ||
                _valuationMode == AssetValuationMode.appreciate) ...[
              const SizedBox(height: Spacing.md),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _valBaseCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                        labelText: s.valuationBase,
                        border: OutlineInputBorder(),
                        prefixText: '¥'),
                  ),
                ),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: TextField(
                    controller: _valRateCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: _valuationMode == AssetValuationMode.depreciate
                          ? s.valuationDepreciateRate
                          : s.valuationAppreciateRate,
                      hintText: _valuationMode == AssetValuationMode.depreciate
                          ? '8'
                          : '3',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: Spacing.md),
              PlainRow(
                title: s.holdingStartDate,
                value: _valuationStartedAt == null
                    ? s.repayNotSet
                    : formatDate(_valuationStartedAt!),
                showChevron: true,
                onTap: () async {
                  final picked = await showAppDatePicker(
                    context: context,
                    initialDate: _valuationStartedAt?.toLocal() ?? DateTime.now(),
                    firstDate: DateTime(1990),
                    lastDate: DateTime.now().add(const Duration(days: 1)),
                  );
                  if (picked != null) {
                    setState(() => _valuationStartedAt = picked.toUtc());
                  }
                },
              ),
            ],
            if (_valuationMode == AssetValuationMode.fixed ||
                _valuationMode == AssetValuationMode.manual) ...[
              const SizedBox(height: Spacing.md),
              TextField(
                controller: _valManualCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                    labelText: _valuationMode == AssetValuationMode.fixed
                        ? s.valuationFixed
                        : s.currentValuation,
                    hintText: '0.00',
                    border: const OutlineInputBorder(),
                    prefixText: '¥'),
              ),
            ],
          ],
          const SizedBox(height: Spacing.md),
          TextField(controller: _noteCtrl, maxLines: 2, maxLength: 100, decoration: InputDecoration(labelText: s.noteOptional, border: OutlineInputBorder())),
          const SizedBox(height: Spacing.lg),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(_isEditing ? s.saveChanges : s.save),
          ),
        ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final s = AppStrings.of(context);
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);

    final openingText = _openingCtrl.text.trim();
    var openingCents = 0;
    if (openingText.isNotEmpty) {
      try {
        openingCents = Money.parseYuan(openingText).cents;
      } on FormatException {
        openingCents = 0;
      }
    }

    final deps = ref.read(appDependenciesProvider);
    final now = deps.clock.now();
    final note = _noteCtrl.text.trim();

    // STORY-2.2 信用卡参数（非信用卡忽略）
    final isCredit = _type == AccountType.credit;
    var creditLimit = 0;
    if (isCredit) {
      try {
        creditLimit = Money.parseYuan(_limitCtrl.text.trim()).cents;
      } on FormatException {
        creditLimit = 0;
      }
    }
    int? billDay = int.tryParse(_billDayCtrl.text.trim());
    int? dueDay = int.tryParse(_dueDayCtrl.text.trim());
    if (billDay != null) billDay = billDay.clamp(1, 28);
    if (dueDay != null) dueDay = dueDay.clamp(1, 28);

    // STORY-10.5：信用卡的最低还款与循环年利率
    final creditMinPay = isCredit ? _centsOf(_minPayCtrl.text) : 0;
    final creditRateBp = isCredit ? (_rateBpOf(_creditRateCtrl.text) ?? 0) : 0;

    // STORY-10.2 贷款参数（非贷款忽略）
    var loanPrincipal = 0;
    var loanRateBp = 0;
    int? loanTerm;
    LoanRepayMethod? loanMethod;
    if (_isLoan) {
      final p = double.tryParse(_loanPrincipalCtrl.text.trim());
      if (p == null || p <= 0) {
        setState(() => _saving = false);
        showAppToast(context, s.fillLoanPrincipal);
        return;
      }
      loanPrincipal = (p * 100).round();
      loanRateBp = _rateBpOf(_loanRateCtrl.text) ?? 0;
      loanTerm = int.tryParse(_loanTermCtrl.text.trim());
      loanMethod = _loanMethod;
      if (loanTerm == null || loanTerm <= 0 || _loanFirstPaymentAt == null) {
        setState(() => _saving = false);
        showAppToast(context, s.fillTermAndFirstPayment);
        return;
      }
      if (_repayAccountId == null) {
        setState(() => _saving = false);
        showAppToast(context, s.selectRepayAccount);
        return;
      }
    }

    // 贷款账户的期初余额由本金推导（负债为负），不单独问用户
    final effectiveOpening = _isLoan
        ? -loanPrincipal
        : (isCredit ? 0 : openingCents);

    // STORY-10.3 资产估值参数（贷款/信用卡忽略）。
    // 折旧模式下的年率取输入值的相反数，用户只需填正数。
    final wantsValuation =
        !_isLoan && _type != AccountType.credit && _valuationMode.isActive;
    var valBase = 0;
    var valRateBp = 0;
    var valManual = 0;
    if (wantsValuation) {
      valBase = _centsOf(_valBaseCtrl.text);
      valManual = _centsOf(_valManualCtrl.text);
      final rate = _rateBpOf(_valRateCtrl.text) ?? 0;
      valRateBp = _valuationMode == AssetValuationMode.depreciate ? -rate : rate;
    }

    final accountId = _isEditing ? widget.editing!.id : deps.idGen.generate();

    if (_isEditing) {
      final e = widget.editing!;
      await deps.accountRepository.update(Account(
        id: accountId,
        name: name,
        type: _type,
        currency: _currency,
        // 贷款改参数时保留既有期初，避免把已发生的还款历史一起改掉
        openingBalance: _isLoan ? e.openingBalance : effectiveOpening,
        note: note.isEmpty ? null : note,
        sortOrder: e.sortOrder,
        isHidden: e.isHidden,
        creditLimitCents: isCredit ? creditLimit : 0,
        creditDebtCents: e.creditDebtCents,
        creditAnnualRateBp: creditRateBp,
        minPaymentCents: creditMinPay,
        billDay: isCredit ? billDay : null,
        dueDay: isCredit ? dueDay : null,
        loanPrincipalCents: _isLoan ? loanPrincipal : 0,
        loanAnnualRateBp: _isLoan ? loanRateBp : 0,
        loanTermMonths: _isLoan ? loanTerm : null,
        loanRepayMethod: _isLoan ? loanMethod : null,
        loanFirstPaymentAt: _isLoan ? _loanFirstPaymentAt : null,
        valuationMode:
            wantsValuation ? _valuationMode : AssetValuationMode.none,
        valuationBaseCents: wantsValuation ? valBase : 0,
        valuationRateBp: wantsValuation ? valRateBp : 0,
        valuationManualCents: wantsValuation ? valManual : 0,
        valuationStartedAt:
            wantsValuation ? _valuationStartedAt : null,
        createdAt: e.createdAt,
        updatedAt: now,
        deletedAt: e.deletedAt,
        revision: e.revision + 1,
        deviceId: e.deviceId,
        baseRevision: e.revision,
      ));
    } else {
      await deps.accountRepository.create(Account(
        id: accountId,
        name: name,
        type: _type,
        currency: _currency,
        openingBalance: effectiveOpening,
        note: note.isEmpty ? null : note,
        sortOrder: 0,
        isHidden: false,
        creditLimitCents: creditLimit,
        creditDebtCents: isCredit ? openingCents : 0,
        creditAnnualRateBp: creditRateBp,
        minPaymentCents: creditMinPay,
        billDay: billDay,
        dueDay: dueDay,
        loanPrincipalCents: loanPrincipal,
        loanAnnualRateBp: loanRateBp,
        loanTermMonths: loanTerm,
        loanRepayMethod: loanMethod,
        loanFirstPaymentAt: _loanFirstPaymentAt,
        valuationMode: wantsValuation ? _valuationMode : AssetValuationMode.none,
        valuationBaseCents: wantsValuation ? valBase : 0,
        valuationRateBp: wantsValuation ? valRateBp : 0,
        valuationManualCents: wantsValuation ? valManual : 0,
        valuationStartedAt: wantsValuation ? _valuationStartedAt : null,
        createdAt: now,
        updatedAt: now,
        revision: 1,
        deviceId: deps.deviceId,
        baseRevision: 0,
      ));
    }

    // 贷款：建立「每期还款」周期规则（利息 + 本金两笔，待确认）
    if (_isLoan) {
      final reloaded = await deps.accountRepository.getById(accountId);
      final loan = reloaded.successOrNull;
      if (loan != null) {
        final r = await deps.setLoanRepaymentSchedule(
          loanAccount: loan,
          bookId: deps.bookId,
          repayAccountId: _repayAccountId!,
          interestCategoryId: _interestCategoryId ?? 'preset_other',
        );
        if (r.isFailure && mounted) {
          showAppToast(context,
              s.repayScheduleFailed(r.failureOrNull?.code ?? s.unknownError));
        }
      }
    }

    if (mounted) {
      ref.invalidateData.bumpRecurringMutated();
      widget.onSaved();
      Navigator.pop(context);
    }
  }
}

class _TypeOption extends StatelessWidget {
  const _TypeOption({required this.label, required this.icon, required this.selected, required this.onTap});

  final String label;
  final PlainIconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: Spacing.md),
        decoration: BoxDecoration(
          color: selected ? context.colors.primary.withValues(alpha: 0.1) : context.colors.surfaceMuted,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: selected ? context.colors.primary : context.colors.border),
        ),
        child: Column(children: [
          PlainIcon(icon, size: 28, color: selected ? context.colors.primary : context.colors.inkSecondary),
          const SizedBox(height: Spacing.xs),
          Text(label, style: TextStyle(fontSize: 14, fontWeight: selected ? FontWeight.w600 : FontWeight.w400, color: selected ? context.colors.primary : context.colors.inkSecondary)),
        ]),
      ),
    );
  }
}

