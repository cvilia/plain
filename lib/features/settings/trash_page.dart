/// Recycle bin: soft-deleted entries within 30-day retention. PRD F7.7.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plain/app/bootstrap.dart';
import 'package:plain/app/breakpoints.dart';
import 'package:plain/app/theme/design_tokens.dart';
import 'package:plain/core/constants/app_constants.dart';
import 'package:plain/core/format/amount_formatter.dart';
import 'package:plain/data/data_freshness.dart';
import 'package:plain/design_system/category_icons.dart';
import 'package:plain/domain/entities/category.dart' as domain;
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/entities/ledger_entry.dart';

class TrashPage extends ConsumerStatefulWidget {
  const TrashPage({super.key});

  @override
  ConsumerState<TrashPage> createState() => _TrashPageState();
}

class _TrashPageState extends ConsumerState<TrashPage> {
  List<LedgerEntry> _entries = const [];
  Map<String, domain.Category> _categoryMap = const {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final deps = ref.read(appDependenciesProvider);
    final catRes = await deps.categoryRepository.listAll();
    final cats = catRes.successOrNull ?? const <domain.Category>[];
    final res = await deps.listDeletedEntries(bookId: deps.bookId);
    if (!mounted) return;
    setState(() {
      _categoryMap = {for (final c in cats) c.id: c};
      _entries = res.successOrNull ?? const [];
      _loading = false;
    });
  }

  Future<void> _restore(LedgerEntry entry) async {
    final deps = ref.read(appDependenciesProvider);
    final res = await deps.restoreEntry(entry.id);
    if (!mounted) return;
    if (res.isSuccess) {
      ref.read(dataFreshnessProvider.notifier).bump();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已恢复')));
      await _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('恢复失败')));
    }
  }

  Future<void> _purgeOne(LedgerEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('彻底删除'),
        content: const Text('彻底删除后无法恢复，确定继续？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: BrandColors.expense),
            child: const Text('彻底删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final deps = ref.read(appDependenciesProvider);
    final res = await deps.ledgerRepository.hardDelete(entry.id);
    if (!mounted) return;
    if (res.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已彻底删除')));
      await _load();
    }
  }

  Future<void> _purgeAll() async {
    if (_entries.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空回收站'),
        content: Text('将彻底删除 ${_entries.length} 笔账单，删除后无法恢复。确定继续？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: BrandColors.expense),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final deps = ref.read(appDependenciesProvider);
    // Purge everything currently in trash (deleted_at is always in the past).
    final res = await deps.ledgerRepository.purgeExpired(before: DateTime.now().toUtc().add(const Duration(days: 1)));
    if (!mounted) return;
    if (res.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('回收站已清空')));
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final hide = ref.watch(hideAmountsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('回收站'),
        actions: [
          if (_entries.isNotEmpty)
            TextButton(onPressed: _purgeAll, child: const Text('清空')),
        ],
      ),
      body: ContentWidthConstraint(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _entries.isEmpty
                ? const _EmptyTrash()
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: Spacing.xxl),
                    itemCount: _entries.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Padding(
                          padding: EdgeInsets.fromLTRB(Spacing.lg, Spacing.md, Spacing.lg, Spacing.sm),
                          child: Text(
                            '删除的账单保留 30 天，到期自动清除',
                            style: TextStyle(fontSize: 12, color: BrandColors.inkTertiary),
                          ),
                        );
                      }
                      final entry = _entries[index - 1];
                      return _TrashTile(
                        entry: entry,
                        category: _categoryMap[entry.categoryId],
                        hideAmount: hide,
                        onRestore: () => _restore(entry),
                        onPurge: () => _purgeOne(entry),
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
          Icon(Icons.delete_outline, size: 64, color: BrandColors.inkTertiary.withValues(alpha: 0.5)),
          const SizedBox(height: Spacing.lg),
          Text('回收站是空的', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: BrandColors.inkSecondary)),
          const SizedBox(height: Spacing.sm),
          Text('删除的账单会暂时存放在这里', style: TextStyle(fontSize: 13, color: BrandColors.inkTertiary)),
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
    final amountColor = isExpense ? BrandColors.expense : isIncome ? BrandColors.income : BrandColors.transfer;
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
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: amountColor.withValues(alpha: 0.1),
          child: Icon(iconForCategory(category?.iconRef ?? 'other'), size: 20, color: amountColor),
        ),
        title: Text(
          category?.name ?? '未分类',
          maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          '剩余 ${daysLeft.clamp(0, 30)} 天${entry.note != null && entry.note!.isNotEmpty ? ' · ${entry.note}' : ''}',
          maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, color: BrandColors.inkTertiary),
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
              icon: Icon(Icons.delete_forever_outlined, size: 20, color: BrandColors.inkTertiary),
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
