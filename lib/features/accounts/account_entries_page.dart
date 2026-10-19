/// 单个账户的账单列表（资产页 → 账户行 → 查看账单）。
///
/// 为什么不复用流水页：流水页带月份/筛选/预算条等一整套状态，从账户进来
/// 只想要「这个账户发生过什么」。这里保持极简：一个标题 + 一串账单。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:plain/app/bootstrap.dart';
import 'package:plain/app/breakpoints.dart';
import 'package:plain/app/l10n/app_strings.dart';
import 'package:plain/app/l10n/strings_accounts.dart';
import 'package:plain/app/theme/app_colors.dart';
import 'package:plain/app/theme/design_tokens.dart';
import 'package:plain/app/theme/typography.dart';
import 'package:plain/core/format/amount_formatter.dart';
import 'package:plain/core/refresh/data_invalidation.dart';
import 'package:plain/design_system/app_empty_state.dart';
import 'package:plain/design_system/app_error_state.dart';
import 'package:plain/design_system/plain_icons_v3.dart';
import 'package:plain/design_system/plain_ui.dart';
import 'package:plain/domain/entities/category.dart' as domain;
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/entities/ledger_entry.dart';
import 'package:plain/domain/repositories/repositories.dart';

class AccountEntriesPage extends ConsumerStatefulWidget {
  const AccountEntriesPage({
    super.key,
    required this.accountId,
    required this.accountName,
  });

  final String accountId;
  final String accountName;

  @override
  ConsumerState<AccountEntriesPage> createState() => _AccountEntriesPageState();
}

class _AccountEntriesPageState extends ConsumerState<AccountEntriesPage> {
  List<LedgerEntry> _entries = const [];
  final Map<String, domain.Category> _categories = {};
  bool _loading = true;
  Object? _loadError;

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
    final page = await deps.ledgerRepository.listPage(
      filter: EntryFilter(accountId: widget.accountId),
      limit: 300,
    );
    final cats = await deps.categoryRepository.listAll();
    if (!mounted) return;
    final failure = page.failureOrNull ?? cats.failureOrNull;
    if (failure != null) {
      setState(() {
        _loadError = failure;
        _loading = false;
      });
      return;
    }
    setState(() {
      _entries = page.successOrNull?.items ?? const <LedgerEntry>[];
      _categories
        ..clear()
        ..addEntries(
          (cats.successOrNull ?? const <domain.Category>[])
              .map((c) => MapEntry(c.id, c)),
        );
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Scaffold(
      appBar: PlainTopBar(title: widget.accountName, showBack: true),
      body: _loadError != null
          ? AppErrorState.of(context, _loadError!, onRetry: _reload)
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidateData.bumpAccountsMutated();
                    await _reload();
                  },
                  child: _entries.isEmpty
                      ? ListView(
                          children: [
                            SizedBox(
                                height:
                                    MediaQuery.sizeOf(context).height * 0.2),
                            AppEmptyState(
                              icon: PlainIconData.receipt,
                              title: s.noAccountEntries,
                              subtitle: s.entryListEmptyHint,
                            ),
                          ],
                        )
                      : ContentWidthConstraint(
                          child: ListView.builder(
                            padding: const EdgeInsets.only(bottom: Spacing.xl),
                            itemCount: _entries.length,
                            itemBuilder: (context, i) => _EntryRow(
                              entry: _entries[i],
                              category: _categories[_entries[i].categoryId],
                              isFirst: i == 0,
                            ),
                          ),
                        ),
                ),
    );
  }
}

class _EntryRow extends ConsumerWidget {
  const _EntryRow({
    required this.entry,
    required this.category,
    required this.isFirst,
  });

  final LedgerEntry entry;
  final domain.Category? category;
  final bool isFirst;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final colors = context.colors;
    final hide = ref.watch(hideAmountsProvider);
    final local = entry.occurredAt.toLocal();
    final date =
        '${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
    final title = category?.name ?? s.uncategorized;
    final sub = (entry.note ?? '').trim();
    // 收入绿、支出墨色：与流水页同一套口径（金额不带符号，靠颜色分正负）。
    final signed = entry.type == EntryType.income ||
        entry.type == EntryType.borrowIn;
    final amountText = formatAmount(entry.amount.cents, hide: hide);

    return Material(
      color: colors.surface,
      child: InkWell(
        onTap: () => context.push('/entry/${entry.id}'),
        child: Container(
          constraints: const BoxConstraints(minHeight: 60),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: isFirst ? const Color(0x00000000) : colors.divider,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 44,
                child: Text(
                  date,
                  style: TextStyle(
                    fontSize: 12,
                    height: designLineHeight(12),
                    fontWeight: FontWeight.w500,
                    color: colors.inkTertiary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        height: designLineHeight(15),
                        fontWeight: FontWeight.w500,
                        color: colors.ink,
                      ),
                    ),
                    if (sub.isNotEmpty)
                      Text(
                        sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          height: designLineHeight(12),
                          fontWeight: FontWeight.w500,
                          color: colors.inkTertiary,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                amountText,
                style: TextStyle(
                  fontSize: 15,
                  height: designLineHeight(15),
                  fontWeight: FontWeight.w600,
                  color: signed ? colors.income : colors.ink,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
