/// Account management page (SP-2-01). See PRD STORY-2.1.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plain/app/bootstrap.dart';
import 'package:plain/app/breakpoints.dart';
import 'package:plain/app/theme/design_tokens.dart';
import 'package:plain/core/refresh/data_invalidation.dart';
import 'package:plain/domain/entities/enums.dart';

final _accountsProvider = FutureProvider<List<_AccountWithBalance>>((ref) async {
  // Refetch when accounts or ledger entries change (balances derive from both).
  ref.watch(accountsVersionProvider);
  ref.watch(ledgerVersionProvider);
  final deps = ref.watch(appDependenciesProvider);
  final db = deps.db;
  final rows = db.raw.select(
    'SELECT * FROM accounts WHERE deleted_at IS NULL ORDER BY sort_order ASC',
  );
  final result = <_AccountWithBalance>[];
  for (final row in rows) {
    final id = row['id']! as String;
    final opening = (row['opening_balance_cents'] as int?) ?? 0;

    final expRow = db.raw.select(
      'SELECT COALESCE(SUM(amount_cents), 0) AS s FROM transactions '
      'WHERE account_id = ? AND type = ? AND deleted_at IS NULL',
      [id, 'expense'],
    );
    final incRow = db.raw.select(
      'SELECT COALESCE(SUM(amount_cents), 0) AS s FROM transactions '
      'WHERE account_id = ? AND type = ? AND deleted_at IS NULL',
      [id, 'income'],
    );
    final exp = expRow.first['s']! as int;
    final inc = incRow.first['s']! as int;

    result.add(_AccountWithBalance(
      id: id,
      name: row['name']! as String,
      type: AccountType.fromWire(row['type'] as String?),
      openingBalance: opening,
      balance: opening - exp + inc,
      isHidden: (row['is_hidden'] as int?) == 1,
    ));
  }
  return result;
});

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
}

class AccountsPage extends ConsumerWidget {
  const AccountsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    watchBrandTheme(ref);
    final accountsAsync = ref.watch(_accountsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('资产')),
      body: accountsAsync.when(
        data: (accounts) {
          if (accounts.isEmpty) {
            return ContentWidthConstraint(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.account_balance_wallet_outlined, size: 80, color: BrandColors.inkTertiary),
                    const SizedBox(height: Spacing.lg),
                    Text('还没有账户', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: BrandColors.inkSecondary)),
                    const SizedBox(height: Spacing.sm),
                    Text('添加现金或银行卡', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: BrandColors.inkTertiary)),
                  ],
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
                        Text('净资产', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: BrandColors.inkSecondary)),
                        const SizedBox(height: Spacing.sm),
                        Text(
                          '\u00a5${(netAssets / 100).toStringAsFixed(2)}',
                          style: TextStyle(fontSize: 32, fontWeight: FontWeight.w600, color: BrandColors.ink),
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
        backgroundColor: BrandColors.primary,
        foregroundColor: BrandColors.onPrimary,
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
    final ctrl = TextEditingController(text: (account.balance / 100).toStringAsFixed(2));
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('对账'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('当前余额: ${(account.balance / 100).toStringAsFixed(2)}'),
            const SizedBox(height: Spacing.md),
            TextField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: '瀹為檯浣欓', border: OutlineInputBorder(), prefixText: '\u00a5'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              final text = ctrl.text.trim();
              if (text.isEmpty) return;
              final parts = text.split('.');
              final yuan = int.tryParse(parts[0]) ?? 0;
              var cent = 0;
              if (parts.length > 1) {
                final centStr = parts[1].padRight(2, '0').substring(0, 2);
                cent = int.tryParse(centStr) ?? 0;
              }
              final actualCents = yuan * 100 + cent;
              final diff = actualCents - account.balance;

              if (diff != 0) {
                final deps = ref.read(appDependenciesProvider);
                final db = deps.db;
                final now = DateTime.now().toUtc().millisecondsSinceEpoch;
                final isExpense = diff < 0;
                final adjId = 'recon_$now';
                final catRows = db.raw.select(
                  "SELECT id FROM categories WHERE name = 'Other' AND deleted_at IS NULL LIMIT 1",
                );
                final catId = catRows.isEmpty ? null : catRows.first['id']! as String;

                db.raw.execute(
                  'INSERT INTO transactions '
                  '(id,book_id,type,amount_cents,currency,category_id,account_id,'
                  'occurred_at,note,source,created_at,updated_at,revision,device_id,base_revision) '
                  'VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
                  [adjId, deps.bookId, isExpense ? 'expense' : 'income', diff.abs(), 'CNY', catId, account.id, now, '对账调整', 'reconcile', now, now, 1, deps.deviceId, 0],
                );
              }

              if (ctx.mounted) Navigator.pop(ctx);
              ref.invalidateData.bumpAccountsMutated();
            },
            child: const Text('对账'),
          ),
        ],
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({required this.account, required this.onRefresh, required this.onReconcile});
  final _AccountWithBalance account;
  final VoidCallback onRefresh;
  final VoidCallback onReconcile;

  @override
  Widget build(BuildContext context) {
    final isCash = account.type == AccountType.cash;
    return Card(
      margin: const EdgeInsets.only(bottom: Spacing.sm),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.sm),
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: BrandColors.primary.withValues(alpha: 0.1),
          child: Icon(isCash ? Icons.payments_outlined : Icons.credit_card_outlined, size: 20, color: BrandColors.primary),
        ),
        title: Text(account.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
        subtitle: Text(isCash ? '现金' : '储蓄卡', style: TextStyle(fontSize: 12, color: BrandColors.inkTertiary)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('\u00a5${(account.balance / 100).toStringAsFixed(2)}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: BrandColors.ink)),
                if (account.openingBalance != 0)
                  Text('期初: ${(account.openingBalance / 100).toStringAsFixed(2)}', style: TextStyle(fontSize: 11, color: BrandColors.inkTertiary)),
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

    var openingCents = 0;
    final openingText = _openingCtrl.text.trim();
    if (openingText.isNotEmpty) {
      final parts = openingText.split('.');
      final yuan = int.tryParse(parts[0]) ?? 0;
      var cent = 0;
      if (parts.length > 1) {
        final centStr = parts[1].padRight(2, '0').substring(0, 2);
        cent = int.tryParse(centStr) ?? 0;
      }
      openingCents = yuan * 100 + cent;
    }

    final db = ref.read(appDependenciesProvider).db;
    final deviceId = ref.read(appDependenciesProvider).deviceId;
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final id = 'acct_${DateTime.now().millisecondsSinceEpoch}';

    db.raw.execute(
      'INSERT INTO accounts (id,name,type,currency,opening_balance_cents,note,sort_order,is_hidden,created_at,updated_at,revision,device_id,base_revision) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)',
      [id, name, _type.wire, 'CNY', openingCents, _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(), 0, 0, now, now, 1, deviceId, 0],
    );

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
          color: !enabled ? BrandColors.surfaceMuted.withValues(alpha: 0.5) : selected ? BrandColors.primary.withValues(alpha: 0.1) : BrandColors.surfaceMuted,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: !enabled ? BrandColors.border.withValues(alpha: 0.5) : selected ? BrandColors.primary : BrandColors.border),
        ),
        child: Column(children: [
          Icon(icon, size: 28, color: !enabled ? BrandColors.inkTertiary.withValues(alpha: 0.4) : selected ? BrandColors.primary : BrandColors.inkSecondary),
          const SizedBox(height: Spacing.xs),
          Text(label, style: TextStyle(fontSize: 13, fontWeight: selected ? FontWeight.w600 : FontWeight.w400, color: !enabled ? BrandColors.inkTertiary.withValues(alpha: 0.4) : selected ? BrandColors.primary : BrandColors.inkSecondary)),
          if (badge != null) ...[
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(color: BrandColors.accent.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(Radii.sm)),
              child: Text(badge!, style: TextStyle(fontSize: 9, color: BrandColors.inkSecondary)),
            ),
          ],
        ]),
      ),
    );
  }
}


