/// Entry detail page (SP-1-02). See PRD STORY-1.2.
library;

import 'package:plain/app/theme/app_colors.dart';
import 'package:plain/core/time/date_format.dart';
import 'package:flutter/material.dart';
import 'package:plain/design_system/amount_display.dart';
import 'package:plain/design_system/app_toast.dart';
import 'package:plain/design_system/plain_icons_v3.dart';
import 'package:plain/design_system/plain_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:plain/app/bootstrap.dart';
import 'package:plain/app/theme/design_tokens.dart';
import 'package:plain/app/theme/typography.dart';
import 'package:plain/core/constants/app_constants.dart';
import 'package:plain/core/format/amount_formatter.dart';
import 'package:plain/core/refresh/data_invalidation.dart';
import 'package:plain/domain/entities/category.dart' as domain;
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/entities/ledger_entry.dart';
import 'package:plain/domain/usecases/split_usecases.dart';
import 'package:plain/features/ledger/presentation/member_write_guard.dart';
import 'package:plain/features/ledger/presentation/entry_participants_row.dart';
import 'package:plain/app/l10n/app_strings.dart';
import 'package:plain/app/l10n/strings_accounts.dart';
import 'package:plain/app/l10n/strings_domain.dart';
import 'package:plain/app/l10n/strings_ledger.dart';


class _DetailData {
  const _DetailData({
    required this.entry,
    required this.category,
    this.accountName,
    this.accountCurrency,
  });
  final LedgerEntry entry;
  final domain.Category? category;
  final String? accountName;

  /// STORY-9.3：账户币种，用于「原币 / 本位币」双显示。
  final String? accountCurrency;
}

final _detailProvider = FutureProvider.family<_DetailData, String>((ref, entryId) async {
  ref.watch(ledgerVersionProvider);
  ref.watch(categoriesVersionProvider);
  ref.watch(accountsVersionProvider);
  final deps = ref.watch(appDependenciesProvider);
  final entryResult = await deps.ledgerRepository.getById(entryId);
  final entry = entryResult.successOrNull;
  if (entry == null) {
    throw StateError('entry.not_found');
  }
  domain.Category? cat;
  if (entry.categoryId != null) {
    final catResult = await deps.categoryRepository.getById(entry.categoryId!);
    cat = catResult.successOrNull;
  }
  // 归属账户
  String? accountName;
  String? accountCurrency;
  if (entry.accountId != null) {
    final accResult = await deps.accountRepository.getById(entry.accountId!);
    accountName = accResult.successOrNull?.name;
    accountCurrency = accResult.successOrNull?.currency;
  }
  return _DetailData(
    entry: entry,
    category: cat,
    accountName: accountName,
    accountCurrency: accountCurrency,
  );
});

class EntryDetailPage extends ConsumerStatefulWidget {
  const EntryDetailPage({super.key, required this.entryId});
  final String entryId;

  @override
  ConsumerState<EntryDetailPage> createState() => _EntryDetailPageState();
}

class _EntryDetailPageState extends ConsumerState<EntryDetailPage> {
  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final async = ref.watch(_detailProvider(widget.entryId));
    final loading = async.isLoading;
    final entry = async.value?.entry;
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (entry == null) {
      return Scaffold(
        appBar: PlainTopBar(title: s.detail, showBack: true),
        body: Center(child: Text(s.entryNotFound)),
      );
    }

    final isExpense = entry.type == EntryType.expense;
    final isIncome = entry.type == EntryType.income;
    final amountColor = isExpense ? context.colors.expense : isIncome ? context.colors.income : context.colors.transfer;

    // 顶栏右侧只放「删除」一枚 44×44 图标按钮。
    //
    // 原来这里是「拆分 / 编辑 / 删除」三枚自绘控件：估算宽度 64+64+44+4 = 176pt，
    // 超过 `PlainTopBar` 居中判据允许的侧边预留，于是标题静默退回「占满剩余空间」
    // 的老布局 —— 表现为「账单详情」左偏。三个动作也偏离了设计稿
    //（`08-SCREENS-SPEC/04-detail.md` §2：右侧仅「编辑」文字按钮）。
    //
    // 另外那枚自绘删除按钮把 `PlainIcon` 直接塞进 `SizedBox(44,44)`：SvgPicture 的
    // `width/height` 只在松约束下生效，紧约束把它拉到 44×44 —— 所以图标看着比别处大。
    // [PlainTopBarAction] 内部那句「Center 给 child 松约束」正是为此而写。
    return Scaffold(
      appBar: PlainTopBar(
        title: s.entryDetailTitle,
        showBack: true,
        actions: [
          PlainTopBarAction(
            icon: PlainIconData.delete,
            // 破坏性动作压到最轻的一档：它不该比标题更响，误触还有二次确认兜底。
            color: context.colors.inkTertiary,
            tooltip: s.delete,
            onTap: () => _confirmDelete(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // Quiet Ledger: 金额是唯一主角，无卡片
          Center(
            child: Column(
              children: [
                Text(
                  s.amountFieldLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.colors.inkTertiary,
                  ),
                ),
                const SizedBox(height: 12),
                AmountDisplay(
                  cents: isExpense ? -entry.amount.cents : entry.amount.cents,
                  fontSize: 34,
                  showSign: true,
                  isExpense: isExpense,
                  isIncome: isIncome,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CategoryDot(color: amountColor),
                    const SizedBox(width: 8),
                    Text(
                      '${async.value?.category?.name ?? s.uncategorized} · ${async.value?.accountName ?? s.noAccount}',
                      style: TextStyle(fontSize: 14, color: context.colors.inkSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          _DetailRow(label: s.category, value: async.value?.category?.name ?? s.uncategorized),
          _DetailRow(label: s.account, value: async.value?.accountName ?? s.noAccount),
          // STORY-9.3：原币 / 本位币双显示（同币种时这里不出现）
          if (entry.originalAmountCents != null)
            _DetailRow(
              label: s.originalAmountFieldLabel,
              value: _dualCurrencyLabel(entry, async.value?.accountCurrency),
            ),
          if (entry.exchangeRate != null)
            _DetailRow(label: s.entityCurrencyRate, value: _rateLabel(entry.exchangeRate!)),
          // 报销 / 收支：本页只做**只读展示**——这两项原来各带一个就地切换的
          // Switch（点一下立刻写库），现按页面职责划分，改值统一去编辑页
          //（见 `entry_input_page.dart::_AttrBar` 的两个 chip）。
          _DetailRow(label: s.reimburseFieldTitle, value: _reimburseLabel(entry.reimburseStatus)),
          // G-2：「不计入收支」只对手动录入的普通收支开放
          if (entry.canMarkExcluded)
            _DetailRow(
              label: s.statsRowLabel,
              value: entry.excludeFromStats ? s.notInStats : s.countedInStats,
            ),
          // STORY-8.2 AC5：AA 分摊（标记参与人自动平均分摊）
          if (isExpense || isIncome)
            EntryParticipantsRow(entryId: widget.entryId, amountCents: entry.amount.cents),
          _DetailRow(label: s.date, value: formatDate(entry.occurredAt)),
          if (entry.note != null && entry.note!.isNotEmpty)
            _DetailRow(label: s.note, value: entry.note!),
          _DetailRow(label: s.source, value: _sourceLabel(entry.source)),
          if (entry.splitRole != SplitRole.normal)
            _DetailRow(
              label: s.splitRowLabel,
              value: entry.isSplitParent ? s.splitParentValue : s.splitChildValue,
            ),
          _DetailRow(label: s.created, value: formatDateTime(entry.createdAt)),
          _DetailRow(label: s.updated, value: formatDateTime(entry.updatedAt)),
          const SizedBox(height: Spacing.lg),
          // ── 动作区 ──
          // 「编辑」是本页的主操作，「拆分 / 合并」是罕见的进阶操作（会改写数据结构、
          // 产生子笔），所以主按钮在前、次级描边按钮在后，两者都不再占顶栏。
          PlainPrimaryButton(
            label: s.edit,
            icon: PlainIconData.edit,
            onPressed: () => _edit(context),
          ),
          if (entry.splitRole == SplitRole.normal && (isExpense || isIncome)) ...[
            const SizedBox(height: Spacing.sm),
            // 图标集里没有「拆分」，就不给它编一个（`ic_merge` 是合并的方向，反着用会误导）。
            PlainSecondaryButton(
              label: s.splitActionLabel,
              onPressed: () => _showSplitSheet(context, entry),
            ),
          ],
          if (entry.isSplitParent) ...[
            const SizedBox(height: Spacing.sm),
            PlainSecondaryButton(
              label: s.mergeBackParent,
              icon: PlainIconData.merge,
              onPressed: () => _mergeSplit(context, entry),
            ),
          ],
          // ⚠️ 这里原本还有一枚 `PlainDangerButton`「删除这笔账单」+「删除后不可恢复」脚注
          //（`04-detail.md` §5 的危险区）。按产品口径撤掉了：同一动作不在同屏出现两次，
          // 删除只保留顶栏那一枚；确认弹窗里写明的是**真实语义**（软删 → 回收站可恢复）。
        ],
      ),
    );
  }

  String _sourceLabel(EntrySource source) => switch (source) {
        EntrySource.manual => '手动录入',
        EntrySource.reconcile => '对账',
        EntrySource.import => '导入',
        EntrySource.recurring => '周期',
        _ => source.wire,
      };

  static String _reimburseLabel(ReimburseStatus s) => switch (s) {
        ReimburseStatus.none => '不报销',
        ReimburseStatus.pending => '待报销',
        ReimburseStatus.submitted => '已提交',
        ReimburseStatus.partial => '部分回款',
        ReimburseStatus.reimbursed => '已回款',
        ReimburseStatus.abandoned => '已放弃',
      };

  /// STORY-9.3 AC1：`$100.00 ≈ ¥720.00`（本位币金额是库里的 amount）。
  ///
  /// 统一走 `formatDualCurrency`：自己拼字符串会丢掉千分位，还多一份重复实现。
  static String _dualCurrencyLabel(LedgerEntry entry, String? accountCurrency) =>
      formatDualCurrency(
        originalCents: entry.originalAmountCents!,
        convertedCents: entry.amount.cents,
        fromCurrency: accountCurrency ?? MoneyRules.defaultCurrency,
        toCurrency: entry.currency,
      );

  /// 汇率展示：去掉无意义的尾随零（7.200000 → 7.2）
  static String _rateLabel(double rate) {
    var s = rate.toStringAsFixed(6);
    while (s.contains('.') && s.endsWith('0')) {
      s = s.substring(0, s.length - 1);
    }
    if (s.endsWith('.')) s = s.substring(0, s.length - 1);
    return s;
  }

  void _edit(BuildContext context) {
    context.push('/entry/edit/${widget.entryId}');
  }

  Future<void> _showSplitSheet(BuildContext context, LedgerEntry entry) async {
    final s = AppStrings.of(context);
    // STORY-8.2 AC2：拆分会产生子笔（= 写账单），只读成员不得做
    if (!await guardCanWriteLedger(context, ref)) return;
    if (!context.mounted) return;
    final rows = List.generate(SplitRules.minChildren, (_) {
      return (amountCtrl: TextEditingController(), catCtrl: TextEditingController());
    });

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: Spacing.lg,
            right: Spacing.lg,
            top: Spacing.lg,
            bottom: MediaQuery.viewInsetsOf(ctx).bottom + Spacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                s.splitSheetTitle(formatAmount(entry.amount.cents)),
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
              const SizedBox(height: Spacing.md),
              for (var i = 0; i < rows.length; i++) ...[
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: rows[i].amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: s.childAmountFieldLabel(i + 1),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: Spacing.sm),
                  Expanded(
                    child: TextField(
                      controller: rows[i].catCtrl,
                      decoration: InputDecoration(
                        labelText: s.categoryIdFieldLabel,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: Spacing.sm),
              ],
              Row(children: [
                TextButton.icon(
                  onPressed: rows.length >= SplitRules.maxChildren
                      ? null
                      : () => setSheet(() => rows.add((
                            amountCtrl: TextEditingController(),
                            catCtrl: TextEditingController(),
                          ))),
                  icon: const PlainIcon(PlainIconData.plus, size: 18),
                  label: Text(s.addChildAction),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () async {
                    final items = <SplitItem>[];
                    for (final r in rows) {
                      final a = r.amountCtrl.text.trim();
                      if (a.isEmpty) continue;
                      final cents = (double.tryParse(a) ?? 0) * 100;
                      items.add(SplitItem(
                        amountCents: cents.round(),
                        categoryId: r.catCtrl.text.trim().isEmpty
                            ? null
                            : r.catCtrl.text.trim(),
                      ));
                    }
                    if (items.length < SplitRules.minChildren) return;
                    final deps = ref.read(appDependenciesProvider);
                    final result = await SplitEntryUseCase(
                      repository: deps.ledgerRepository,
                      clock: deps.clock,
                      idGen: deps.idGen,
                    )(parent: entry, items: items);
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (!mounted) return;
                    result.when(
                      success: (_) {
                        ref.invalidateData.bumpEntryMutated();
                        showAppToast(context, s.splitDone);
                        setState(() {});
                      },
                      failure: (f) => showAppToast(context, '拆分失败: ${f.code}'),
                    );
                  },
                  child: Text(s.saveSplitAction),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _mergeSplit(BuildContext context, LedgerEntry parent) async {
    final s = AppStrings.of(context);
    // STORY-8.2 AC2：合并会改写账单，只读成员不得做
    if (!await guardCanWriteLedger(context, ref)) return;
    final deps = ref.read(appDependenciesProvider);
    final result = await MergeSplitUseCase(
      repository: deps.ledgerRepository,
      clock: deps.clock,
    )(parent: parent);
    if (!mounted) return;
    result.when(
      success: (_) {
        ref.invalidateData.bumpEntryMutated();
        showAppToast(context, s.mergeDone);
        setState(() {});
      },
      failure: (f) => showAppToast(context, '合并失败: ${f.code}'),
    );
  }

  void _confirmDelete(BuildContext context) {
    final s = AppStrings.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.deleteThisEntry),
        // ⚠️ 别写「不可恢复」：账单是**软删除**（`deleted_at`），
        // 「设置 › 回收站」里有恢复入口，30 天内（`TrashRules.trashTtl`）
        // 都能捞回来。文案必须和落库语义一致 —— 这一条设计稿 §5 自己
        // 也点了出来（`04-detail.md` 的「文案与实现需一致」）。
        content: Text(s.deleteTrashContent),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.cancel)),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final deps = ref.read(appDependenciesProvider);
              final result = await deps.deleteEntry(widget.entryId);
              if (result.isSuccess && context.mounted) {
                ref.invalidateData.bumpEntryMutated();
                Navigator.pop(context);
                showAppToast(context, s.deleted);
              }
            },
            child: Text(s.delete),
          ),
        ],
      ),
    );
  }

  
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // ⚠️ 高度：设计稿 `.drow{min-height:56px;padding:10px 16px}`，但详情页是**连续十来行**
    // 的「标签—值」事实表，56 在这个密度下整页太松。按全库通用列表行高收口到 **44**
    //（= `.crow` / `.attrrow`，也是触控底线）；`Text` 必须显式写 `height`，否则继承
    // `bodyMedium` 的 1.5714（14 → 22pt），比设计行高 19 多 3pt 且不再受字号控制。
    // 内容 1(border) + 12 + 19 + 12 = 44，与 `minHeight` 恰好齐平。
    //
    // ⚠️ **不要加水平内边距**。设计稿 `.drow{padding:10px 16px}` 的 16 是相对
    // `.panel`（白卡）算的；本页是 Quiet Ledger **无卡片**，`.scroll` 的 16 就是
    // 全页唯一的左右基准 —— 再缩 16 会让标签列/值列比满宽分隔线、「附件 0/5」、
    // 「＋ 添加」多缩一格，两条竖线全断。去掉后标签左边缘、值右边缘都落在 16。
    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: colors.divider, width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              height: designLineHeight(14),
              fontWeight: FontWeight.w500,
              color: colors.inkTertiary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                height: designLineHeight(14),
                fontWeight: FontWeight.w500,
                color: colors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

