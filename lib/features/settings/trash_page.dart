/// Recycle bin: soft-deleted entries within 30-day retention. PRD F7.7.
library;

import 'package:plain/app/theme/app_colors.dart';
import 'package:plain/design_system/category_avatar.dart';
import 'package:plain/design_system/confirm_dialog.dart';
import 'package:flutter/material.dart';
import 'package:plain/design_system/app_toast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plain/app/bootstrap.dart';
import 'package:plain/app/breakpoints.dart';
import 'package:plain/app/theme/design_tokens.dart';
import 'package:plain/core/constants/app_constants.dart';
import 'package:plain/core/format/amount_formatter.dart';
import 'package:plain/core/refresh/data_invalidation.dart';
import 'package:plain/domain/entities/category.dart' as domain;
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/entities/ledger_entry.dart';


class _TrashData {
  const _TrashData({required this.entries, required this.categoryMap});
  final List<LedgerEntry> entries;
  final Map<String, domain.Category> categoryMap;
}

final _trashProvider = FutureProvider<_TrashData>((ref) async {
  ref.watch(ledgerVersionProvider);
  ref.watch(categoriesVersionProvider);
  final deps = ref.watch(appDependenciesProvider);
  final catRes = await deps.categoryRepository.listAll();
  final cats = catRes.successOrNull ?? const <domain.Category>[];
  final res = await deps.listDeletedEntries(bookId: deps.bookId);
  return _TrashData(
    entries: res.successOrNull ?? const [],
    categoryMap: {for (final c in cats) c.id: c},
  );
});

class TrashPage extends ConsumerStatefulWidget {
  const TrashPage({super.key});

  @override
  ConsumerState<TrashPage> createState() => _TrashPageState();
}

class _TrashPageState extends ConsumerState<TrashPage> {

  Future<void> _restore(LedgerEntry entry) async {
    final deps = ref.read(appDependenciesProvider);
    final res = await deps.restoreEntry(entry.id);
    if (!mounted) return;
    if (res.isSuccess) {
      ref.invalidateData.bumpEntryMutated();
      showAppToast(context, '已恢复');
      } else {
      showAppToast(context, '恢复失败');
    }
  }

  Future<void> _purgeOne(LedgerEntry entry) async {
    final confirmed = await showConfirmDialog(
      context,
      title: '彻底删除',
      message: '彻底删除后无法恢复，确定继续？',
      confirmLabel: '彻底删除',
      destructive: true,
    );
    if (confirmed != true || !mounted) return;

    final deps = ref.read(appDependenciesProvider);
    final res = await deps.ledgerRepository.hardDelete(entry.id);
    if (!mounted) return;
    if (res.isSuccess) {
      showAppToast(context, '已彻底删除');
      }
  }

  Future<void> _purgeAll() async {
    final entries = ref.read(_trashProvider).value?.entries ?? const <LedgerEntry>[];
    if (entries.isEmpty) return;
    final confirmed = await showConfirmDialog(
      context,
      title: '清空回收站',
      message: '将彻底删除 ${entries.length} 笔账单，删除后无法恢复。确定继续？',
      confirmLabel: '清空',
      destructive: true,
    );
    if (confirmed != true || !mounted) return;

    final deps = ref.read(appDependenciesProvider);
    // Purge everything currently in trash (deleted_at is always in the past).
    final res = await deps.ledgerRepository.purgeExpired(before: DateTime.now().toUtc().add(const Duration(days: 1)));
    if (!mounted) return;
    if (res.isSuccess) {
      showAppToast(context, '回收站已清空');
      }
  }

  @override
  Widget build(BuildContext context) {
    final hide = ref.watch(hideAmountsProvider);
    final async = ref.watch(_trashProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('回收站'),
        actions: [
          if (async.value?.entries.isNotEmpty ?? false)
            TextButton(onPressed: _purgeAll, child: const Text('清空')),
        ],
      ),
      body: ContentWidthConstraint(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('加载失败: $e')),
          data: (data) {
            final entries = data.entries;
            final categoryMap = data.categoryMap;
            if (entries.isEmpty) return const _EmptyTrash();
            return ListView.builder(
              padding: const EdgeInsets.only(bottom: Spacing.xxl),
              itemCount: entries.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: EdgeInsets.fromLTRB(Spacing.lg, Spacing.md, Spacing.lg, Spacing.sm),
                    child: Text(
                      '删除的账单保留 30 天，到期自动清除',
                      style: TextStyle(fontSize: 12, color: context.colors.inkTertiary),
                    ),
                  );
                }
                final entry = entries[index - 1];
                return _TrashTile(
                  entry: entry,
                  category: categoryMap[entry.categoryId],
                  hideAmount: hide,
                  onRestore: () => _restore(entry),
                  onPurge: () => _purgeOne(entry),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _EmptyTrash extends StatelessWidget {
  const _EmptyTrash();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.delete_outline, size: 64, color: context.colors.inkTertiary.withValues(alpha: 0.5)),
          const SizedBox(height: Spacing.lg),
          Text('回收站是空的', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: context.colors.inkSecondary)),
          const SizedBox(height: Spacing.sm),
          Text('删除的账单会暂时存放在这里', style: TextStyle(fontSize: 13, color: context.colors.inkTertiary)),
        ],
      ),
    );
  }
}

class _TrashTile extends StatelessWidget {
  const _TrashTile({
    required this.entry, required this.category,
    required this.hideAmount, required this.onRestore, required this.onPurge,
  });

  final LedgerEntry entry;
  final domain.Category? category;
  final bool hideAmount;
  final VoidCallback onRestore;
  final VoidCallback onPurge;

  @override
  Widget build(BuildContext context) {
    final isExpense = entry.type == EntryType.expense;
    final isIncome = entry.type == EntryType.income;
    final amountColor = isExpense ? context.colors.expense : isIncome ? context.colors.income : context.colors.transfer;
    final prefix = isExpense ? '-' : isIncome ? '+' : '';
    final amountText = '$prefix${formatAmount(entry.amount.cents, hide: hideAmount)}';

    final deletedAt = entry.deletedAt;
    final daysLeft = deletedAt == null
        ? 0
        : TrashRules.trashTtl.inDays - DateTime.now().toUtc().difference(deletedAt).inDays;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.xs),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.xs),
        leading: CategoryAvatar(iconRef: category?.iconRef ?? 'other', color: amountColor),
        title: Text(
          category?.name ?? '未分类',
          maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          '剩余 ${daysLeft.clamp(0, 30)} 天${entry.note != null && entry.note!.isNotEmpty ? ' · ${entry.note}' : ''}',
          maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, color: context.colors.inkTertiary),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(amountText, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: amountColor)),
            const SizedBox(width: Spacing.sm),
            IconButton(
              icon: const Icon(Icons.restore, size: 20),
              tooltip: '恢复',
              visualDensity: VisualDensity.compact,
              onPressed: onRestore,
            ),
            IconButton(
              icon: Icon(Icons.delete_forever_outlined, size: 20, color: context.colors.inkTertiary),
              tooltip: '彻底删除',
              visualDensity: VisualDensity.compact,
              onPressed: onPurge,
            ),
          ],
        ),
      ),
    );
  }
}
