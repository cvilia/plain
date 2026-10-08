/// Account management page (SP-2-01). See PRD STORY-2.1.
library;

import 'package:plain/app/theme/app_colors.dart';
import 'package:plain/design_system/category_avatar.dart';
import 'package:plain/design_system/app_empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plain/app/bootstrap.dart';
import 'package:plain/app/breakpoints.dart';
import 'package:plain/app/theme/design_tokens.dart';
import 'package:plain/core/format/amount_formatter.dart';
import 'package:plain/core/money/money.dart';
import 'package:plain/core/refresh/data_invalidation.dart';
import 'package:plain/domain/entities/category.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/repositories/repositories.dart';
import 'package:plain/domain/usecases/entry_usecases.dart';

final _accountsProvider = FutureProvider<List<_AccountWithBalance>>((ref) async {
  // Refetch when accounts or ledger entries change (balances derive from both).
  ref.watch(accountsVersionProvider);
  ref.watch(ledgerVersionProvider);
  final deps = ref.watch(appDependenciesProvider);
  final res = await deps.accountRepository.listWithBalances();
  final list = res.successOrNull ?? const <AccountWithBalance>[];
  return list.map(_AccountWithBalance.from).toList();
});

/// Flat view-model the list UI already expects.
class _AccountWithBalance {
  const _AccountWithBalance({
    required this.id,
    required this.name,
    required this.type,
    required this.openingBalance,
    required this.balance,
    required this.isHidden,
  });
  final String id;
  final String name;
  final AccountType type;
  final int openingBalance;
  final int balance;
  final bool isHidden;

  factory _AccountWithBalance.from(AccountWithBalance src) => _AccountWithBalance(
        id: src.account.id,
        name: src.account.name,
        type: src.account.type,
        openingBalance: src.account.openingBalance,
        balance: src.balanceCents,
        isHidden: src.account.isHidden,
      );
}

class AccountsPage extends ConsumerWidget {
  const AccountsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(_accountsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('资产')),
      body: accountsAsync.when(
        data: (accounts) {
          if (accounts.isEmpty) {
            return const ContentWidthConstraint(
              child: AppEmptyState(
                icon: Icons.account_balance_wallet_outlined,
                title: '还没有账户',
                subtitle: '添加现金或银行卡',
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
                        Text(
                          formatAmountYuan(netAssets, hide: ref.watch(hideAmountsProvider)),
                          style: TextStyle(fontSize: 32, fontWeight: FontWeight.w600, color: context.colors.ink),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: Spacing.lg),
                ...accounts.map((a) => _AccountTile(
                      account: a,
                      onRefresh: () => ref.invalidateData.bumpAccountsMutated(),
                      onReconcile: () => _showReconcileDialog(context, ref, a),
                    )),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_accounts_add',
        onPressed: () => _showAddSheet(context, ref),
        backgroundColor: context.colors.primary,
        foregroundColor: context.colors.onPrimary,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _AddAccountSheet(onSaved: () {
        ref.invalidateData.bumpAccountsMutated();
      }),
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
            Text('当前余额: ${formatAmountYuan(account.balance, hide: ref.watch(hideAmountsProvider))}'),
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
                await deps.createEntry(CreateEntryInput(
                  amountExpression: formatAmount(diff.abs()),
                  type: isExpense ? EntryType.expense : EntryType.income,
                  categoryId: isExpense ? 'preset_other' : 'preset_income_other',
                  accountId: account.id,
                  note: '对账调整',
                  source: EntrySource.reconcile,
                  bookId: deps.bookId,
                  deviceId: deps.deviceId,
                ));
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
    final isCash = account.type == AccountType.cash;
    return Card(
      margin: const EdgeInsets.only(bottom: Spacing.sm),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.sm),
        leading: CategoryAvatar(
          iconRef: isCash ? 'payments' : 'card',
          color: context.colors.primary,
        ),
        title: Text(account.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
        subtitle: Text(isCash ? '现金' : '储蓄卡', style: TextStyle(fontSize: 12, color: context.colors.inkTertiary)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(formatAmountYuan(account.balance, hide: ref.watch(hideAmountsProvider)), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: context.colors.ink)),
                if (account.openingBalance != 0)
                  Text('期初: ${formatAmount(account.openingBalance)}', style: TextStyle(fontSize: 11, color: context.colors.inkTertiary)),
              ],
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 20),
              onSelected: (v) {
                if (v == 'reconcile') onReconcile();
              },
              itemBuilder: (_) => [const PopupMenuItem(value: 'reconcile', child: Text('对账'))],
            ),
          ],
        ),
      ),
    );
  }
}

class _AddAccountSheet extends ConsumerStatefulWidget {
  const _AddAccountSheet({required this.onSaved});
  final VoidCallback onSaved;

  @override
  ConsumerState<_AddAccountSheet> createState() => _AddAccountSheetState();
}

class _AddAccountSheetState extends ConsumerState<_AddAccountSheet> {
  final _nameCtrl = TextEditingController();
  final _openingCtrl = TextEditingController(text: '0');
  final _noteCtrl = TextEditingController();
  AccountType _type = AccountType.cash;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _openingCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: Spacing.lg, right: Spacing.lg, top: Spacing.lg, bottom: MediaQuery.of(context).viewInsets.bottom + Spacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('添加账户', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: Spacing.lg),
          Wrap(
            spacing: Spacing.sm,
            runSpacing: Spacing.sm,
            children: [
              _TypeOption(label: '现金', icon: Icons.payments_outlined, selected: _type == AccountType.cash, onTap: () => setState(() => _type = AccountType.cash)),
              _TypeOption(label: '储蓄卡', icon: Icons.credit_card_outlined, selected: _type == AccountType.debit, onTap: () => setState(() => _type = AccountType.debit)),
              _TypeOption(label: '信用卡', icon: Icons.credit_card, selected: false, enabled: false, badge: 'V1.2', onTap: () {}),
              _TypeOption(label: '投资', icon: Icons.trending_up_outlined, selected: false, enabled: false, badge: 'V1.2', onTap: () {}),
            ],
          ),
          const SizedBox(height: Spacing.lg),
          TextField(controller: _nameCtrl, maxLength: 20, decoration: const InputDecoration(labelText: '名称', hintText: '如：现金', border: OutlineInputBorder())),
          const SizedBox(height: Spacing.md),
          TextField(controller: _openingCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: '期初余额', hintText: '0.00', border: OutlineInputBorder(), prefixText: '\u00a5')),
          const SizedBox(height: Spacing.md),
          TextField(controller: _noteCtrl, maxLines: 2, maxLength: 100, decoration: const InputDecoration(labelText: '备注（可选）', border: OutlineInputBorder())),
          const SizedBox(height: Spacing.lg),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('保存'),
          ),
        ],
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
    await deps.accountRepository.create(Account(
      id: deps.idGen.generate(),
      name: name,
      type: _type,
      currency: 'CNY',
      openingBalance: openingCents,
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      sortOrder: 0,
      isHidden: false,
      createdAt: now,
      updatedAt: now,
      revision: 1,
      deviceId: deps.deviceId,
      baseRevision: 0,
    ));

    if (mounted) {
      widget.onSaved();
      Navigator.pop(context);
    }
  }
}

class _TypeOption extends StatelessWidget {
  const _TypeOption({required this.label, required this.icon, required this.selected, required this.onTap, this.enabled = true, this.badge});

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final bool enabled;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: Spacing.md),
        decoration: BoxDecoration(
          color: !enabled ? context.colors.surfaceMuted.withValues(alpha: 0.5) : selected ? context.colors.primary.withValues(alpha: 0.1) : context.colors.surfaceMuted,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: !enabled ? context.colors.border.withValues(alpha: 0.5) : selected ? context.colors.primary : context.colors.border),
        ),
        child: Column(children: [
          Icon(icon, size: 28, color: !enabled ? context.colors.inkTertiary.withValues(alpha: 0.4) : selected ? context.colors.primary : context.colors.inkSecondary),
          const SizedBox(height: Spacing.xs),
          Text(label, style: TextStyle(fontSize: 13, fontWeight: selected ? FontWeight.w600 : FontWeight.w400, color: !enabled ? context.colors.inkTertiary.withValues(alpha: 0.4) : selected ? context.colors.primary : context.colors.inkSecondary)),
          if (badge != null) ...[
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(color: context.colors.accent.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(Radii.sm)),
              child: Text(badge!, style: TextStyle(fontSize: 9, color: context.colors.inkSecondary)),
            ),
          ],
        ]),
      ),
    );
  }
}


