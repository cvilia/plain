/// Recycle bin: soft-deleted entries within 30-day retention. PRD F7.7.
library;

import 'package:plain/app/theme/app_colors.dart';
import 'package:plain/design_system/category_avatar.dart';
import 'package:plain/design_system/confirm_dialog.dart';
import 'package:plain/design_system/plain_icons_v3.dart';
import 'package:plain/design_system/plain_ui.dart';
import 'package:flutter/material.dart';
import 'package:plain/design_system/app_error_state.dart';
import 'package:plain/design_system/app_toast.dart';
import 'package:plain/features/ledger/presentation/member_write_guard.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plain/app/bootstrap.dart';
import 'package:plain/app/breakpoints.dart';
import 'package:plain/app/theme/design_tokens.dart';
import 'package:plain/core/constants/app_constants.dart';
import 'package:plain/core/format/amount_formatter.dart';
import 'package:plain/core/time/date_format.dart';
import 'package:plain/core/refresh/data_invalidation.dart';
import 'package:plain/domain/entities/category.dart' as domain;
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/entities/ledger_entry.dart';
import 'package:plain/app/l10n/app_strings.dart';
import 'package:plain/app/l10n/strings_ledger.dart';
import 'package:plain/app/l10n/strings_settings_a.dart';
import 'package:plain/app/l10n/strings_settings_b.dart';


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
  // Window only — anything older is purged at startup and hidden here.
  final res = await deps.listDeletedEntries(bookId: deps.bookId, limit: 500);
  final cutoff = deps.clock.now().subtract(TrashRules.trashTtl);
  final live = (res.successOrNull ?? const <LedgerEntry>[])
      .where((e) => e.deletedAt == null || e.deletedAt!.isAfter(cutoff))
      .toList();
  return _TrashData(
    entries: live,
    categoryMap: {for (final c in cats) c.id: c},
  );
});

class TrashPage extends ConsumerStatefulWidget {
  const TrashPage({super.key});

  @override
  ConsumerState<TrashPage> createState() => _TrashPageState();
}

class _TrashPageState extends ConsumerState<TrashPage> {
  Future<void> _reload() async {
    ref.invalidateData.bumpEntryMutated();
    ref.invalidate(_trashProvider);
  }

  Future<void> _restore(LedgerEntry entry) async {
    final s = AppStrings.of(context);
    // STORY-8.2 AC2：恢复 = 让账单重新入账，只读成员不得做
    if (!await guardCanWriteLedger(context, ref)) return;
    try {
      final deps = ref.read(appDependenciesProvider);
      final res = await deps.restoreEntry(entry.id);
      if (!mounted) return;
      if (res.isSuccess) {
        await _reload();
        if (!mounted) return;
        showAppToast(context, s.restored);
      } else {
        showAppToast(context, '恢复失败: ${res.failureOrNull?.code ?? 'unknown'}');
      }
    } on Object catch (e) {
      if (!mounted) return;
      showAppToast(context, s.restoreFailed(e.toString()));
    }
  }

  Future<void> _restoreAll(List<LedgerEntry> entries) async {
    final s = AppStrings.of(context);
    if (entries.isEmpty) return;
    final confirmed = await showConfirmDialog(
      context,
      title: s.restoreAll,
      message: s.restoreAllConfirm(entries.length),
      confirmLabel: s.restoreAll,
    );
    if (confirmed != true || !mounted) return;

    // STORY-8.2 AC2：恢复 = 让账单重新入账，只读成员不得做
    if (!await guardCanWriteLedger(context, ref)) return;
    final deps = ref.read(appDependenciesProvider);
    var okCount = 0;
    String? lastError;
    for (final e in entries) {
      try {
        final res = await deps.restoreEntry(e.id);
        if (res.isSuccess) {
          okCount++;
        } else {
          lastError = res.failureOrNull?.code ?? 'unknown';
        }
      } on Object catch (ex) {
        lastError = '$ex';
      }
    }
    if (!mounted) return;
    await _reload();
    if (!mounted) return;
    showAppToast(
      context,
      okCount > 0 ? s.restoredCount(okCount) : '恢复失败${lastError == null ? '' : ': $lastError'}',
    );
  }

  Future<void> _purgeOne(LedgerEntry entry) async {
    final s = AppStrings.of(context);
    final confirmed = await showConfirmDialog(
      context,
      title: s.purgeForever,
      message: s.purgeForeverConfirm,
      confirmLabel: s.purgeForever,
      destructive: true,
    );
    if (confirmed != true || !mounted) return;

    try {
      final deps = ref.read(appDependenciesProvider);
      final res = await deps.ledgerRepository.hardDelete(entry.id);
      if (!mounted) return;
      if (res.isSuccess) {
        await _reload();
        if (!mounted) return;
        showAppToast(context, s.purgedForever);
      } else {
        showAppToast(context, '删除失败: ${res.failureOrNull?.code ?? 'unknown'}');
      }
    } on Object catch (e) {
      if (!mounted) return;
      showAppToast(context, s.categoryDeleteFailed(e.toString()));
    }
  }

  Future<void> _purgeAll() async {
    final s = AppStrings.of(context);
    final entries = ref.read(_trashProvider).value?.entries ?? const <LedgerEntry>[];
    if (entries.isEmpty) return;
    final confirmed = await showConfirmDialog(
      context,
      title: s.emptyTrashTitle,
      message: '将彻底删除 ${entries.length} 笔账单，删除后无法恢复。确定继续？',
      confirmLabel: s.clearAllAction,
      destructive: true,
    );
    if (confirmed != true || !mounted) return;

    try {
      final deps = ref.read(appDependenciesProvider);
      // Purge everything currently in trash (deleted_at is always in the past).
      final res = await deps.ledgerRepository.purgeExpired(
        before: deps.clock.now().add(const Duration(days: 1)),
      );
      if (!mounted) return;
      if (res.isSuccess) {
        await _reload();
        if (!mounted) return;
        showAppToast(context, s.trashEmptied);
      } else {
        showAppToast(context, '清空失败: ${res.failureOrNull?.code ?? 'unknown'}');
      }
    } on Object catch (e) {
      if (!mounted) return;
      showAppToast(context, s.emptyFailed(e.toString()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final hide = ref.watch(hideAmountsProvider);
    final async = ref.watch(_trashProvider);
    return Scaffold(
      appBar: PlainTopBar(
        title: s.trashTitle,
        showBack: true,
        actions: [
          if (async.value?.entries.isNotEmpty ?? false) ...[
            TextButton(
              onPressed: () => _restoreAll(async.value!.entries),
              child: Text(s.restoreAll),
            ),
            TextButton(
              onPressed: _purgeAll,
              child: Text(s.clearAllAction, style: TextStyle(color: context.colors.expense)),
            ),
          ],
        ],
      ),
      body: ContentWidthConstraint(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => AppErrorState.of(context, e, onRetry: () => ref.invalidateData.bumpEverything()),
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
                      s.trashRetentionHint,
                      style: TextStyle(fontSize: 12, color: context.colors.inkTertiary),
                    ),
                  );
                }
                final entry = entries[index - 1];
                return _TrashTile(
                  entry: entry,
                  category: categoryMap[entry.categoryId],
                  hideAmount: hide,
                  now: ref.read(appDependenciesProvider).clock.now(),
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
    final s = AppStrings.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          PlainIcon(
            PlainIconData.delete,
            size: 64,
            color: context.colors.inkTertiary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: Spacing.lg),
          Text(s.trashEmptyTitle, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: context.colors.inkSecondary)),
          const SizedBox(height: Spacing.sm),
          Text(s.trashEmptySubtitle, style: TextStyle(fontSize: 14, color: context.colors.inkTertiary)),
        ],
      ),
    );
  }
}

class _TrashTile extends StatelessWidget {
  const _TrashTile({
    required this.entry, required this.category,
    required this.hideAmount, required this.now, required this.onRestore, required this.onPurge,
  });

  final LedgerEntry entry;
  final domain.Category? category;
  final bool hideAmount;
  final DateTime now;
  final VoidCallback onRestore;
  final VoidCallback onPurge;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final isExpense = entry.type == EntryType.expense;
    final isIncome = entry.type == EntryType.income;
    final amountColor = isExpense ? context.colors.expense : isIncome ? context.colors.income : context.colors.transfer;
    final prefix = isExpense ? '-' : isIncome ? '+' : '';
    final amountText = '$prefix${formatAmount(entry.amount.cents, hide: hideAmount)}';

    final deletedAt = entry.deletedAt;
    final daysLeft = deletedAt == null
        ? 0
        : TrashRules.trashTtl.inDays - now.difference(deletedAt).inDays;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.xs),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.xs),
        leading: CategoryAvatar(iconRef: category?.iconRef ?? 'other', color: amountColor),
        title: Text(
          category?.name ?? s.uncategorized,
          maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          [
            s.daysRemaining(daysLeft.clamp(0, TrashRules.trashTtl.inDays)),
            if (entry.note != null && entry.note!.isNotEmpty) entry.note!,
            s.recordedSuffix(formatDateTime(entry.occurredAt)),
          ].join(' · '),
          maxLines: 2, overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, color: context.colors.inkTertiary),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                amountText,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: amountColor),
              ),
            ),
            const SizedBox(width: Spacing.xs),
            IconButton(
              icon: const PlainIcon(PlainIconData.undo, size: 20),
              tooltip: s.restore,
              visualDensity: VisualDensity.compact,
              onPressed: onRestore,
            ),
            IconButton(
              icon: PlainIcon(
                PlainIconData.delete,
                size: 20,
                color: context.colors.inkTertiary,
              ),
              tooltip: s.purgeForever,
              visualDensity: VisualDensity.compact,
              onPressed: onPurge,
            ),
          ],
        ),
      ),
    );
  }
}
