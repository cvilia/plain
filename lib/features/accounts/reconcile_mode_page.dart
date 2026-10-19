/// 账户对账模式（STORY-2.3）：逐笔勾选，不改余额。
/// AC1 全部可勾选 + 待对账角标 / AC2 勾选后退出角标更新 / AC3 全部勾完显示已对账 / AC4 编辑保留勾选
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:plain/app/bootstrap.dart';
import 'package:plain/app/theme/app_colors.dart';
import 'package:plain/app/theme/design_tokens.dart';
import 'package:plain/app/theme/typography.dart';
import 'package:plain/core/format/amount_formatter.dart';
import 'package:plain/core/refresh/data_invalidation.dart';
import 'package:plain/design_system/app_empty_state.dart';
import 'package:plain/design_system/app_toast.dart';
import 'package:plain/design_system/plain_icons_v3.dart';
import 'package:plain/design_system/plain_ui.dart';
import 'package:plain/domain/entities/category.dart' as domain;
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/entities/ledger_entry.dart';
import 'package:plain/domain/repositories/repositories.dart';
import 'package:plain/domain/services/reconcile_mode_service.dart';
import 'package:plain/app/l10n/app_strings.dart';
import 'package:plain/app/l10n/strings_accounts.dart';

class ReconcileModePage extends ConsumerStatefulWidget {
  const ReconcileModePage({super.key, required this.accountId, required this.accountName});
  final String accountId;
  final String accountName;

  @override
  ConsumerState<ReconcileModePage> createState() => _ReconcileModePageState();
}

class _ReconcileModePageState extends ConsumerState<ReconcileModePage> {
  List<LedgerEntry> _entries = [];
  final Map<String, domain.Category> _categories = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final deps = ref.read(appDependenciesProvider);
    final page = await deps.ledgerRepository.listPage(
      filter: EntryFilter(accountId: widget.accountId),
      limit: 500,
    );
    final items = page.successOrNull?.items ?? const <LedgerEntry>[];
    final cats = await deps.categoryRepository.listAll();
    final catMap = {for (final c in cats.successOrNull ?? const <domain.Category>[]) c.id: c};
    if (!mounted) return;
    setState(() {
      _entries = items;
      _categories.addAll(catMap);
      _loading = false;
    });
  }

  int get _pendingCount => _entries.where((e) => !e.isReconciled).length;

  Future<void> _toggle(LedgerEntry entry) async {
    final s = AppStrings.of(context);
    final deps = ref.read(appDependenciesProvider);
    final service = ReconcileModeService(repository: deps.ledgerRepository, clock: deps.clock);
    final result = entry.isReconciled
        ? await service.uncheck(entry)
        : await service.check(entry);
    if (!mounted) return;
    final updated = result.successOrNull;
    if (updated == null) {
      showAppToast(context, s.operationFailed);
      return;
    }
    setState(() {
      final i = _entries.indexWhere((e) => e.id == entry.id);
      if (i != -1) _entries[i] = updated;
    });
    ref.invalidateData.bumpEntryMutated();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final pending = _pendingCount;
    final done = _entries.length - pending;
    return Scaffold(
      appBar: PlainTopBar(
        title: s.reconcileWithName(widget.accountName),
        showBack: true,
        actions: [
          if (_entries.isNotEmpty)
            // 顶栏**状态文本**（不可点，故不走 [PlainTopBarTextAction]）。
            // ⚠️ 别用 `ConstrainedBox(minHeight: 44)` 直接包 `Text`：minHeight 会把文字
            // 节点撑成 44 高，而段落按**顶部**绘制 → 文字偏上。用「固定高盒子 + Center」
            // 给子级松约束，Center 在 Row 的无界宽度下会自行 shrinkWrap。
            SizedBox(
              height: 44,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(right: Spacing.lg),
                  child: Text(
                    pending == 0 ? s.reconciledUpTo(_lastReconciledLabel()) : s.pendingReconcileCount(pending),
                    style: TextStyle(
                      fontSize: 14,
                      height: designLineHeight(14),
                      color: pending == 0 ? context.colors.income : context.colors.accent,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? AppEmptyState(
                  icon: PlainIconData.listCheck,
                  title: s.noBills,
                  subtitle: s.reconcileEmptyHint,
                  action: FilledButton.icon(
                    onPressed: () => context.push('/entry'),
                    icon: const PlainIcon(PlainIconData.plus),
                    label: Text(s.recordEntry),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
                  itemCount: _entries.length,
                  itemBuilder: (_, i) {
                    final entry = _entries[i];
                    final cat = _categories[entry.categoryId];
                    final isExpense = entry.type == EntryType.expense;
                    final isIncome = entry.type == EntryType.income;
                    final amountColor = isExpense
                        ? context.colors.expense
                        : isIncome
                            ? context.colors.income
                            : context.colors.transfer;
                    final prefix = isExpense ? '-' : isIncome ? '+' : '';
                    return CheckboxListTile(
                      value: entry.isReconciled,
                      onChanged: (_) => _toggle(entry),
                      activeColor: context.colors.primary,
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
                      title: Text(
                        '${cat?.name ?? '未分类'}${entry.note != null && entry.note!.isNotEmpty ? ' · ${entry.note}' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          decoration: entry.isReconciled ? TextDecoration.lineThrough : null,
                          color: entry.isReconciled ? context.colors.inkTertiary : null,
                        ),
                      ),
                      subtitle: Text(
                        _dateLabel(entry.occurredAt),
                        style: TextStyle(fontSize: 12, color: context.colors.inkTertiary),
                      ),
                      secondary: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '$prefix${formatAmount(entry.amount.cents)}',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: amountColor),
                          ),
                        ],
                      ),
                    );
                  },
                ),
      bottomNavigationBar: _entries.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(Spacing.lg),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        s.checkedCount(done, _entries.length),
                        style: TextStyle(fontSize: 14, color: context.colors.inkSecondary),
                      ),
                    ),
                    if (pending > 0)
                      FilledButton(
                        onPressed: () async {
                          // 全部勾选
                          final deps = ref.read(appDependenciesProvider);
                          final service = ReconcileModeService(repository: deps.ledgerRepository, clock: deps.clock);
                          for (final e in _entries.where((e) => !e.isReconciled)) {
                            await service.check(e);
                          }
                          if (!mounted) return;
                          await _reload();
                          if (!mounted) return;
                          ref.invalidateData.bumpEntryMutated();
                          showAppToast(this.context, s.allChecked);
                        },
                        child: Text(s.checkAll),
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  String _dateLabel(DateTime dt) {
    final t = dt.toLocal();
    return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} '
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  String _lastReconciledLabel() {
    DateTime? last;
    for (final e in _entries) {
      final t = e.reconciledAt;
      if (t != null && (last == null || t.isAfter(last))) last = t;
    }
    if (last == null) return '';
    final t = last.toLocal();
    return '${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
  }
}
