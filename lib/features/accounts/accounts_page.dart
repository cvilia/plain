/// Account management page (SP-2-01). See PRD STORY-2.1.
library;

import 'package:plain/app/theme/app_colors.dart';
import 'package:plain/design_system/category_avatar.dart';
import 'package:plain/design_system/amount_text.dart';
import 'package:plain/design_system/app_empty_state.dart';
import 'package:plain/design_system/app_toast.dart';
import 'package:plain/features/accounts/credit_reconcile_page.dart';
import 'package:plain/features/accounts/reconcile_mode_page.dart';
import 'package:plain/features/ledger/presentation/home_shell.dart';
import 'package:plain/design_system/confirm_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plain/app/bootstrap.dart';
import 'package:plain/app/breakpoints.dart';
import 'package:plain/app/theme/design_tokens.dart';
import 'package:plain/core/constants/app_constants.dart';
import 'package:plain/core/format/amount_formatter.dart';
import 'package:plain/core/money/money.dart';
import 'package:plain/core/refresh/data_invalidation.dart';
import 'package:plain/domain/entities/category.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/entities/ledger_entry.dart';
import 'package:plain/domain/repositories/repositories.dart';
import 'package:plain/domain/usecases/entry_usecases.dart';

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
    final accountsAsync = ref.watch(_accountsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('资产'),
        actions: [
          AddAppBarAction(tooltip: '添加账户', onPressed: () => _showAddSheet(context, ref)),
        ],
      ),
      body: accountsAsync.when(
        data: (accounts) {
          if (accounts.isEmpty) {
            return ContentWidthConstraint(
              child: AppEmptyState(
                icon: Icons.account_balance_wallet_outlined,
                title: '还没有账户',
                subtitle: '添加现金或银行卡',
                action: FilledButton.icon(
                  onPressed: () => _showAddSheet(context, ref),
                  icon: const Icon(Icons.add),
                  label: const Text('添加账户'),
                ),
              ),
            );
          }

          final netAssets = accounts.fold(0, (sum, a) => sum + a.balance);

          return ContentWidthConstraint(
            child: ListView(
              padding: const EdgeInsets.all(Spacing.lg),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(Spacing.xl),
                    child: Column(
                      children: [
                        Text('净资产', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.colors.inkSecondary)),
                        const SizedBox(height: Spacing.sm),
                        AmountWithCurrency(
                          cents: netAssets,
                          fontSize: 32,
                          fontWeight: FontWeight.w600,
                          color: context.colors.ink,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: Spacing.lg),
                ...accounts.map((a) => _AccountTile(
                      account: a,
                      onRefresh: () => ref.invalidateData.bumpAccountsMutated(),
                      onReconcile: () {
                    // 信用卡走欠款对账页（STORY-2.2 AC7/AC8）
                    if (a.type == AccountType.credit) {
                      _openCreditReconcile(context, a.id);
                    } else {
                      _showReconcileDialog(context, ref, a);
                    }
                  },
                    )),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
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
    final ctrl = TextEditingController(text: formatAmount(account.balance));
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('对账'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text('当前余额: ', style: TextStyle(color: context.colors.inkSecondary)),
              AmountWithCurrency(cents: account.balance),
            ]),
            const SizedBox(height: Spacing.md),
            TextField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: '实际余额', border: OutlineInputBorder(), prefixText: '\u00a5'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
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
                  note: '对账调整',
                  source: EntrySource.reconcile,
                  bookId: deps.bookId,
                  deviceId: deps.deviceId,
                ));
                if (result.isFailure) {
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) showAppToast(context, '对账失败：${result.failureOrNull?.code ?? '未知错误'}');
                  return;
                }
              }

              if (ctx.mounted) Navigator.pop(ctx);
              ref.invalidateData.bumpAccountsMutated();
              ref.invalidateData.bumpEntryMutated();
            },
            child: const Text('对账'),
          ),
        ],
      ),
    );
  }
}

class _AccountTile extends ConsumerWidget {
  const _AccountTile({required this.account, required this.onRefresh, required this.onReconcile});
  final _AccountWithBalance account;
  final VoidCallback onRefresh;
  final VoidCallback onReconcile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typeLabel = switch (account.type) {
      AccountType.cash => '现金',
      AccountType.debit => '储蓄卡',
      AccountType.credit => '信用卡',
      AccountType.investment => '投资',
      _ => '账户',
    };
    final iconRef = switch (account.type) {
      AccountType.cash => 'payments',
      AccountType.debit => 'card',
      AccountType.credit => 'credit',
      AccountType.investment => 'invest',
      _ => 'other',
    };
    return Card(
      margin: const EdgeInsets.only(bottom: Spacing.sm),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.sm),
        leading: CategoryAvatar(
          iconRef: iconRef,
          color: context.colors.primary,
        ),
        title: Row(
          children: [
            Expanded(child: Text(account.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500))),
            if (account.pendingReconcile > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: context.colors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '待对账 ${account.pendingReconcile} 笔',
                  style: TextStyle(fontSize: 10, color: context.colors.accent, fontWeight: FontWeight.w500),
                ),
              ),
          ],
        ),
        subtitle: Text(typeLabel, style: TextStyle(fontSize: 12, color: context.colors.inkTertiary)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AmountWithCurrency(
                  cents: account.balance,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: context.colors.ink,
                ),
                if (account.isCredit) ...[
                  Text(
                    account.isOverLimit ? '超额' : '可用 ${formatAmount(account.creditAvailableCents)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: account.isOverLimit
                          ? context.colors.expense
                          : context.colors.inkTertiary,
                    ),
                  ),
                ] else if (account.openingBalance != 0)
                  Text('期初: ${formatAmount(account.openingBalance)}', style: TextStyle(fontSize: 11, color: context.colors.inkTertiary)),
              ],
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 20),
              onSelected: (v) {
                switch (v) {
                  case 'reconcile':
                    onReconcile();
                  case 'reconcile_mode':
                    _openReconcileMode(context);
                  case 'edit':
                    _editAccount(context, ref);
                  case 'hide':
                    _toggleHide(context, ref);
                  case 'delete':
                    _deleteAccount(context, ref);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'reconcile', child: Text('对账')),
                const PopupMenuItem(value: 'reconcile_mode', child: Text('逐笔对账')),
                const PopupMenuItem(value: 'edit', child: Text('编辑')),
                PopupMenuItem(value: 'hide', child: Text(account.isHidden ? '取消隐藏' : '隐藏')),
                const PopupMenuItem(value: 'delete', child: Text('删除')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editAccount(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: _AddAccountSheet(
          editing: account.account,
          onSaved: onRefresh,
        ),
      ),
    );
    if (context.mounted) onRefresh();
  }

  void _openReconcileMode(BuildContext context) {
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => ReconcileModePage(accountId: account.id, accountName: account.name),
      ),
    ).then((_) => onRefresh());
  }

  Future<void> _toggleHide(BuildContext context, WidgetRef ref) async {
    final deps = ref.read(appDependenciesProvider);
    final now = deps.clock.now();
    await deps.accountRepository.update(account.account.copyWith(
      isHidden: !account.isHidden,
      updatedAt: now,
      revision: account.account.revision + 1,
      baseRevision: account.account.revision,
    ));
    ref.invalidateData.bumpAccountsMutated();
    ref.invalidateData.bumpEntryMutated();
    onRefresh();
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final deps = ref.read(appDependenciesProvider);
    final refs = await deps.accountRepository.countReferences(account.id);
    final counts = refs.successOrNull;
    if (counts == null || !context.mounted) return;

    if (!counts.isEmpty) {
      // 有引用：迁移 / 改为不指定账户 / 隐藏（STORY-2.1 AC6）
      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('账户仍有引用'),
          content: Text(
            '账单 ${counts.transactions + counts.transferIn} 笔 · 周期规则 ${counts.recurringRules} 条\n\n'
            '可选择迁移、改为不指定账户，或隐藏保留数据。',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, 'hide'), child: const Text('改为隐藏')),
            TextButton(onPressed: () => Navigator.pop(ctx, 'cancel'), child: const Text('取消')),
            TextButton(onPressed: () => Navigator.pop(ctx, 'detach'), child: const Text('改为不指定账户')),
            FilledButton(onPressed: () => Navigator.pop(ctx, 'migrate'), child: const Text('迁移后删除')),
          ],
        ),
      );
      if (choice == 'hide') {
        if (!context.mounted) return;
        await _toggleHide(context, ref);
        return;
      }
      if (choice == 'detach') {
        if (!context.mounted) return;
        await _detachAndDelete(context, ref);
        return;
      }
      if (choice != 'migrate' || !context.mounted) return;
      final toId = await _pickTargetAccount(context, ref);
      if (toId == null || !context.mounted) return;
      final moved = await deps.accountRepository.migrateTransactions(fromId: account.id, toId: toId);
      if (!moved.isSuccess) {
        if (context.mounted) showAppToast(context, '迁移失败：${moved.failureOrNull?.code ?? '未知错误'}');
        return;
      }
      if (!context.mounted) return;
      ref.invalidateData.bumpEntryMutated();
      ref.invalidateData.bumpRecurringMutated();
      final del = await deps.accountRepository.softDelete(account.id);
      if (del.isSuccess && context.mounted) {
        showAppToast(context, '已迁移并删除账户');
      } else if (context.mounted) {
        showAppToast(context, '删除失败：${del.failureOrNull?.code ?? '未知错误'}');
      }
      ref.invalidateData.bumpAccountsMutated();
      onRefresh();
      return;
    }

    final confirmed = await showConfirmDialog(
      context,
      title: '删除账户',
      message: '确定删除「${account.name}」？此操作不可恢复。',
      confirmLabel: '删除',
      destructive: true,
    );
    if (confirmed != true || !context.mounted) return;
    final del = await deps.accountRepository.softDelete(account.id);
    if (del.isSuccess) {
      ref.invalidateData.bumpAccountsMutated();
      ref.invalidateData.bumpEntryMutated();
      if (context.mounted) showAppToast(context, '已删除');
    } else if (context.mounted) {
      showAppToast(context, '删除失败，请先迁移或隐藏');
    }
    onRefresh();
  }

  /// STORY-2.1：把引用账单改为不指定账户，然后删除账户。
  Future<void> _detachAndDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: '改为不指定账户',
      message: '该账户的 ${'账单与规则'}将改为「不指定账户」，然后删除「${account.name}」。此操作不可恢复。',
      confirmLabel: '确认',
      destructive: true,
    );
    if (confirmed != true || !context.mounted) return;

    final deps = ref.read(appDependenciesProvider);
    final detached = await deps.accountRepository.detachFromAccount(account.id);
    if (!detached.isSuccess) {
      if (context.mounted) showAppToast(context, '处理失败：${detached.failureOrNull?.code ?? '未知错误'}');
      return;
    }
    if (!context.mounted) return;
    ref.invalidateData.bumpEntryMutated();
    ref.invalidateData.bumpRecurringMutated();
    final del = await deps.accountRepository.softDelete(account.id);
    if (del.isSuccess && context.mounted) {
      showAppToast(context, '已改为不指定账户并删除');
    } else if (context.mounted) {
      showAppToast(context, '删除失败：${del.failureOrNull?.code ?? '未知错误'}');
    }
    ref.invalidateData.bumpAccountsMutated();
    onRefresh();
  }

  Future<String?> _pickTargetAccount(BuildContext context, WidgetRef ref) async {
    final deps = ref.read(appDependenciesProvider);
    final list = await deps.accountRepository.listAll();
    final accounts = (list.successOrNull ?? const <Account>[])
        .where((a) => a.id != account.id && !a.isDeleted)
        .toList();
    if (!context.mounted || accounts.isEmpty) return null;
    return showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('迁移到哪个账户？'),
        children: [
          for (final a in accounts)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, a.id),
              child: Text(a.name),
            ),
        ],
      ),
    );
  }
}

class _AddAccountSheet extends ConsumerStatefulWidget {
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
  AccountType _type = AccountType.cash;
  String _currency = 'CNY';
  bool _saving = false;

  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    if (e != null) {
      _nameCtrl.text = e.name;
      _openingCtrl.text = (e.openingBalance / 100).toStringAsFixed(2);
      _noteCtrl.text = e.note ?? '';
      _type = e.type;
      _currency = e.currency;
      _limitCtrl.text = (e.creditLimitCents / 100).toStringAsFixed(2);
      _billDayCtrl.text = e.billDay?.toString() ?? '';
      _dueDayCtrl.text = e.dueDay?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _openingCtrl.dispose();
    _noteCtrl.dispose();
    _limitCtrl.dispose();
    _billDayCtrl.dispose();
    _dueDayCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: Spacing.lg, right: Spacing.lg, top: Spacing.lg, bottom: MediaQuery.of(context).viewInsets.bottom + Spacing.lg),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_isEditing ? '编辑账户' : '添加账户', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: Spacing.lg),
            Wrap(
            spacing: Spacing.sm,
            runSpacing: Spacing.sm,
            children: [
              _TypeOption(label: '现金', icon: Icons.payments_outlined, selected: _type == AccountType.cash, onTap: () => setState(() => _type = AccountType.cash)),
              _TypeOption(label: '储蓄卡', icon: Icons.credit_card_outlined, selected: _type == AccountType.debit, onTap: () => setState(() => _type = AccountType.debit)),
              _TypeOption(label: '信用卡', icon: Icons.credit_card, selected: _type == AccountType.credit, onTap: () => setState(() => _type = AccountType.credit)),
              _TypeOption(label: '投资', icon: Icons.trending_up_outlined, selected: _type == AccountType.investment, onTap: () => setState(() => _type = AccountType.investment)),
            ],
          ),
          const SizedBox(height: Spacing.lg),
          TextField(controller: _nameCtrl, maxLength: 20, decoration: const InputDecoration(labelText: '名称', hintText: '如：现金', border: OutlineInputBorder())),
          const SizedBox(height: Spacing.md),
          DropdownButtonFormField<String>(
            initialValue: _currency,
            decoration: const InputDecoration(labelText: '币种', border: OutlineInputBorder()),
            items: [
              for (final code in CurrencyRules.symbols.keys)
                DropdownMenuItem(value: code, child: Text('${CurrencyRules.symbolOf(code)}  $code')),
            ],
            onChanged: (v) => setState(() => _currency = v ?? 'CNY'),
          ),
          const SizedBox(height: Spacing.md),
          TextField(controller: _openingCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: '期初余额', hintText: '0.00', border: OutlineInputBorder(), prefixText: '¥')),
          if (_type == AccountType.credit) ...[
            const SizedBox(height: Spacing.md),
            TextField(
              controller: _limitCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: '总额度', hintText: '0.00', border: OutlineInputBorder(), prefixText: '¥'),
            ),
            const SizedBox(height: Spacing.md),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _billDayCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '账单日 (1–28)', border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: TextField(
                  controller: _dueDayCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '还款日 (1–28)', border: OutlineInputBorder()),
                ),
              ),
            ]),
          ],
          const SizedBox(height: Spacing.md),
          TextField(controller: _noteCtrl, maxLines: 2, maxLength: 100, decoration: const InputDecoration(labelText: '备注（可选）', border: OutlineInputBorder())),
          const SizedBox(height: Spacing.lg),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(_isEditing ? '保存修改' : '保存'),
          ),
        ],
        ),
      ),
    );
  }

  Future<void> _save() async {
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
    var creditLimit = 0;
    if (_type == AccountType.credit) {
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

    if (_isEditing) {
      final e = widget.editing!;
      await deps.accountRepository.update(Account(
        id: e.id,
        name: name,
        type: _type,
        currency: _currency,
        openingBalance: openingCents,
        note: note.isEmpty ? null : note,
        sortOrder: e.sortOrder,
        isHidden: e.isHidden,
        creditLimitCents: _type == AccountType.credit ? creditLimit : 0,
        creditDebtCents: e.creditDebtCents,
        billDay: _type == AccountType.credit ? billDay : null,
        dueDay: _type == AccountType.credit ? dueDay : null,
        createdAt: e.createdAt,
        updatedAt: now,
        deletedAt: e.deletedAt,
        revision: e.revision + 1,
        deviceId: e.deviceId,
        baseRevision: e.revision,
      ));
    } else {
      await deps.accountRepository.create(Account(
        id: deps.idGen.generate(),
        name: name,
        type: _type,
        currency: _currency,
        openingBalance: openingCents,
        note: note.isEmpty ? null : note,
        sortOrder: 0,
        isHidden: false,
        creditLimitCents: creditLimit,
        billDay: billDay,
        dueDay: dueDay,
        createdAt: now,
        updatedAt: now,
        revision: 1,
        deviceId: deps.deviceId,
        baseRevision: 0,
      ));
    }

    if (mounted) {
      widget.onSaved();
      Navigator.pop(context);
    }
  }
}

class _TypeOption extends StatelessWidget {
  const _TypeOption({required this.label, required this.icon, required this.selected, required this.onTap});

  final String label;
  final IconData icon;
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
          Icon(icon, size: 28, color: selected ? context.colors.primary : context.colors.inkSecondary),
          const SizedBox(height: Spacing.xs),
          Text(label, style: TextStyle(fontSize: 13, fontWeight: selected ? FontWeight.w600 : FontWeight.w400, color: selected ? context.colors.primary : context.colors.inkSecondary)),
        ]),
      ),
    );
  }
}

