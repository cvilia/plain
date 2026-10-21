/// Home flow list — Quiet Ledger SP-0-02.
/// 顶栏：左侧 44 占位（无跳转）| 2026年9月 | 搜索 · 更多 —— 图标 20 / 44×44 / r12
/// Hero：结余四段式 ink（行盒 45 = 34 × CSS normal）/ 支出 ink / 收入 income 红
/// 日分组：eyebrow（32 上距 + 8 下距，只有日期、无当日合计）+ 圆角 panel
/// 行：6px 色点 · 名称/备注 · 金额（右对齐 + tnum）
/// 见 redesign-v3/单独确认.html、08-SCREENS-SPEC/02-ledger.md
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:plain/app/breakpoints.dart';
import 'package:plain/app/settings/home_layout_prefs.dart';
import 'package:plain/app/bootstrap.dart';
import 'package:plain/app/settings/ledger_settings.dart';
import 'package:plain/app/theme/app_colors.dart';
import 'package:plain/app/theme/theme_registry.dart';
import 'package:plain/app/theme/typography.dart';
import 'package:plain/core/format/amount_formatter.dart';
import 'package:plain/core/refresh/data_invalidation.dart';
import 'package:plain/core/time/date_format.dart';
import 'package:plain/design_system/amount_display.dart';
import 'package:plain/design_system/app_empty_state.dart';
import 'package:plain/design_system/app_toast.dart';
import 'package:plain/design_system/category_avatar.dart';
import 'package:plain/design_system/plain_icons_v3.dart';
import 'package:plain/design_system/plain_ui.dart';
import 'package:plain/domain/entities/category.dart' as domain;
import 'package:plain/domain/entities/ledger_entry.dart';
import 'package:plain/domain/repositories/repositories.dart';
import 'package:plain/features/ledger/controllers/flow_list_controller.dart';
import 'package:plain/features/ledger/presentation/advanced_filter_page.dart';
import 'package:plain/features/ledger/presentation/safe_to_spend_card.dart';
import 'package:plain/app/l10n/app_strings.dart';
import 'package:plain/app/l10n/strings_ledger.dart';

final _homeLayoutProvider =
    FutureProvider<(List<String>, Set<String>)>((ref) async {
  ref.watch(homeLayoutVersionProvider);
  final order = await loadHomeCardOrder();
  final hidden = await loadHomeCardHidden();
  return (order, hidden);
});

class FlowListPage extends ConsumerWidget {
  const FlowListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final state = ref.watch(flowListControllerProvider);
    final controller = ref.read(flowListControllerProvider.notifier);
    final filterCatId = ref.watch(flowCategoryFilterProvider);
    final colors = context.colors;
    final monthStartDay = ref.watch(monthStartDayProvider);

    ref.listen(ledgerVersionProvider, (prev, next) {
      if (prev == next) return;
      controller.refresh();
    });

    // ⚠️ 顶栏月份**恒为当前月**，刻意不做月份切换（产品口径 2026-10-19）：
    // 本页是「这个月的流水」，不是日历浏览器。原左上角日历按钮（跳报表）已移除，
    // 不要再补月份选择器——要跨月看的是报表页（按月份/区间汇总），不是这里。
    final now = DateTime.now();
    final monthTitle = s.yearMonth(now);

    return Scaffold(
      backgroundColor: colors.pageBg,
      // 顶栏统一走 PlainTopBar（`.topbar`）：内容盒 56，状态栏高度由它自己的
      // SafeArea 承担。照设计稿：动作图标 20（`ic("ic_search", 20)`），
      // 不是 `.iconbtn` 的默认 22。
      //
      // 左上角**没有按钮**：原日历（跳 `/reports`）已移除 —— 本页是 shell 分支，
      // 报表是同级 tab，从流水顶部跳过去会污染返回栈。不传 `leadingIcon` / `onBack`
      // 时 `PlainTopBar` 自己补一个 44 宽的占位，标题仍居中，不再需要额外对齐处理。
      appBar: PlainTopBar(
        title: monthTitle,
        actions: [
          PlainTopBarAction(
            icon: PlainIconData.search,
            iconSize: 20,
            tooltip: s.searchOrFilter,
            onTap: () => Navigator.of(context, rootNavigator: true).push<void>(
              MaterialPageRoute(builder: (_) => const AdvancedFilterPage()),
            ),
          ),
          // 原「更多」按钮（空 onTap）已移除（2026-10-19 爸爸拍板）：设计稿从未
          // 定义它， SPEC 里只是空的 iconbtn。顶栏只留搜索。
        ],
      ),
      // ⚠️ `top: false` 是必须的，别顺手改成 `SafeArea(...)`：
      // Scaffold 在 `appBar != null` 时已把这个槽位的 `padding.top` 归零
      //（`_addIfNonNull` 的 `removeTopPadding: widget.appBar != null`），
      // 再叠一层只会白算一次；留着是为了横屏刘海那 44pt 的 left/right。
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            if (filterCatId != null)
              _FilterStrip(
                label: s.filteredBy(
                    state.categoryMap[filterCatId]?.name ?? s.thisCategory),
                onClear: () {
                  ref.read(flowCategoryFilterProvider.notifier).clear();
                  controller.refresh();
                },
              ),
            Expanded(
              child: state.groups.isEmpty && !state.isLoading
                  ? ContentWidthConstraint(
                      child: _EmptyState(
                        onEntryTap: () => context.push('/entry'),
                        errorCode: state.errorMessage,
                        onRetry: controller.refresh,
                      ),
                    )
                  : ContentWidthConstraint(
                      child: _FlowList(
                        state: state,
                        controller: controller,
                        monthStartDay: monthStartDay,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 分类筛选条 —— 设计稿里没有这一条（它是「报表下钻」带过来的态）。
/// 保持设计系统口径：`surfaceMuted` 底 + 15/500 文本 + 右侧「显示全部」。
class _FilterStrip extends StatelessWidget {
  const _FilterStrip({required this.label, required this.onClear});

  final String label;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final colors = context.colors;
    return ColoredBox(
      color: colors.surfaceMuted,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  // 不写 height 会继承 body 的 1.5714（+3.57px），条带被撑高。
                  height: designLineHeight(15),
                  fontWeight: FontWeight.w500,
                  color: colors.ink,
                ),
              ),
            ),
            TextButton(
              onPressed: onClear,
              child: Text(s.showAll),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onEntryTap, this.errorCode, this.onRetry});
  final VoidCallback onEntryTap;

  /// 非空 = 这次是**加载失败**，不是「没记过账」。
  ///
  /// 原先只判 `groups.isEmpty` → 失败与空账本看到的是同一屏「还没有记录」，
  /// 用户以为数据没了（audit 2026-10-15 走查确认）。
  final String? errorCode;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    if (errorCode != null) {
      return AppEmptyState(
        icon: PlainIconData.cloudDownload,
        title: s.flowLoadFailed,
        subtitle: s.flowLoadFailedSubtitle(errorCode!),
        action: FilledButton.icon(
          onPressed: onRetry,
          icon: const PlainIcon(PlainIconData.cloudDownload),
          label: Text(s.retry),
        ),
      );
    }
    return AppEmptyState(
      icon: PlainIconData.receipt,
      title: s.noEntries,
      subtitle: s.tapToRecord,
      action: FilledButton.icon(
        onPressed: onEntryTap,
        icon: const PlainIcon(PlainIconData.plus),
        label: Text(s.recordEntry),
      ),
    );
  }
}

class _FlowList extends ConsumerWidget {
  const _FlowList({
    required this.state,
    required this.controller,
    required this.monthStartDay,
  });

  final FlowListState state;
  final FlowListController controller;
  final int monthStartDay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = state.groups;

    final layout = ref.watch(_homeLayoutProvider).maybeWhen(
          data: (v) => v,
          orElse: () => (const <String>[], const <String>{}),
        );
    final (cardOrder, hiddenCards) = layout;
    final showBalance = !hiddenCards.contains('monthly_balance');
    final showSafe = !hiddenCards.contains('safe_to_spend');

    // 拍平：hero / safe / 日头 / 行（Dismissible 需要顶层）
    // ⚠️ 分组之间**没有** footer 行 —— 32 的间距由 `_DayHeader` 的上内边距出，
    // 与设计稿 `.grp{margin-top:32px}` 一一对应。曾经用「footer 24 + header 8」
    // 凑 32，读起来像两处魔法数，改任一处就会悄悄错位。
    final rows = <_FlowRow>[
      if (showBalance) const _FlowRow.balance(),
      if (showSafe) const _FlowRow.safeToSpend(),
      for (final g in groups) ...[
        _FlowRow.dayHeader(g),
        _FlowRow.dayPanel(g),
      ],
      if (state.hasMore) _FlowRow.more(failed: state.loadMoreFailed),
    ];

    return ListView.builder(
      // `.scroll{padding:0 16px}` —— 垂直方向一律由各块自己的内边距负责，
      // 所以这里上边距是 0（hero 自己带 14）；底部 24 = `.scroll-pad{height:24px}`。
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        switch (row.kind) {
          case _FlowRowKind.balance:
            return _Hero(
              state: state,
              monthStartDay: monthStartDay,
            );
          case _FlowRowKind.safeToSpend:
            // 设计稿屏 2 没有这张卡（它来自「首页卡片自定义」）。
            // 给它 32 的上距，免得贴死在 hero 的第二条发丝线上。
            return const SafeToSpendCard();
          case _FlowRowKind.dayHeader:
            return _DayHeader(group: row.group!);
          case _FlowRowKind.dayPanel:
            return _DayPanel(
              group: row.group!,
              controller: controller,
              categoryMap: state.categoryMap,
            );
          case _FlowRowKind.more:
            // 加载失败时**不能**再自动重试：这一段是 postFrame 触发的，
            // 一旦 DB 持续失败就会变成每帧一次查询（列表有数据时用户只看到永久转圈）。
            if (row.failed) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: TextButton(
                    onPressed: controller.retryLoadMore,
                    child: Text(AppStrings.of(context).retry),
                  ),
                ),
              );
            }
            WidgetsBinding.instance.addPostFrameCallback((_) {
              controller.loadMore();
            });
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
        }
      },
    );
  }
}

enum _FlowRowKind { balance, safeToSpend, dayHeader, dayPanel, more }

class _FlowRow {
  const _FlowRow.balance()
      : kind = _FlowRowKind.balance,
        group = null,
        entry = null,
        failed = false;
  const _FlowRow.safeToSpend()
      : kind = _FlowRowKind.safeToSpend,
        group = null,
        entry = null,
        failed = false;
  const _FlowRow.dayHeader(DayGroup this.group)
      : kind = _FlowRowKind.dayHeader,
        entry = null,
        failed = false;
  const _FlowRow.dayPanel(DayGroup this.group)
      : kind = _FlowRowKind.dayPanel,
        entry = null,
        failed = false;
  const _FlowRow.more({this.failed = false})
      : kind = _FlowRowKind.more,
        group = null,
        entry = null;

  final _FlowRowKind kind;
  final DayGroup? group;
  final LedgerEntry? entry;

  /// 只对 [ _FlowRowKind.more ] 有意义：上一页加载失败 → 显示「重试」而不是转圈。
  final bool failed;
}

/// Hero：品牌渐变卡（本月支出 + 比上月 ±%）+ 卡内收入/结余 + 卡下记账月起始。
/// 2026-10-20 重做：旧版是「发丝线夹住的结余四段式」，用户要求对齐配色预览里的
/// 渐变方框。渐变端点 `heroStart/heroEnd`（暗色 `heroDark*`）按白字 4.6:1 生成，
/// 卡上文字一律白系，不取 `context.colors.ink*`。
/// 记账月收支合计：走 `daily_stats`（monthSummary），与列表分页无关。
///
/// 之前 `_Hero` 累加 `state.groups`（**已加载**的条目），翻页翻到上个月后
/// 会把上个月的钱算进「本月结余」。这里按 `monthStartDay` 的记账月边界查库。
/// 2026-10-20：同时取**上一个记账月**，hero 渐变卡要显示「比上月 ±%」。
final _monthTotalsProvider =
    FutureProvider<({MonthSummary cur, MonthSummary prev})>((ref) async {
  ref.watch(ledgerVersionProvider);
  final deps = ref.watch(appDependenciesProvider);
  final cal = ref.watch(calendarProvider);
  final cur = cal.currentPeriod();
  final prev = cal.previousPeriod(cur);
  const zero = MonthSummary(
    expenseCents: 0,
    incomeCents: 0,
    txCount: 0,
    byCategory: {},
  );
  final curRes = await deps.ledgerRepository.monthSummary(
    bookId: deps.bookId,
    dayFrom: cur.dayFrom,
    dayTo: cur.dayTo,
  );
  final prevRes = await deps.ledgerRepository.monthSummary(
    bookId: deps.bookId,
    dayFrom: prev.dayFrom,
    dayTo: prev.dayTo,
  );
  return (
    cur: curRes.successOrNull ?? zero,
    prev: prevRes.successOrNull ?? zero,
  );
});

class _Hero extends ConsumerWidget {
  const _Hero({required this.state, required this.monthStartDay});
  final FlowListState state;
  final int monthStartDay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final totals = ref.watch(_monthTotalsProvider);
    final summary = totals.value?.cur;
    var income = 0;
    var expense = 0;
    if (summary != null) {
      income = summary.incomeCents;
      expense = summary.expenseCents;
    } else {
      // 首次加载还没回来：先按已加载条目占位，避免闪一下 0。
      for (final g in state.groups) {
        income += g.dayIncome;
        expense += g.dayExpense;
      }
    }
    final balance = income - expense;
    final prevExpense = totals.value?.prev.expenseCents;
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 「比上月」：本月和上月都有数才算百分比；上月为 0 就直说，不除零。
    String? vsText;
    if (expense > 0 && prevExpense != null) {
      if (prevExpense == 0) {
        vsText = s.noExpenseLastMonth;
      } else if (prevExpense == expense) {
        vsText = s.expenseFlatVsLastMonth;
      } else {
        final pct = (expense - prevExpense).abs() / prevExpense * 100;
        final pctStr = pct >= 99.95
            ? '100'
            : (pct % 1 == 0 ? pct.toStringAsFixed(0) : pct.toStringAsFixed(1));
        vsText = expense < prevExpense
            ? s.expenseDownVsLastMonth('$pctStr%')
            : s.expenseUpVsLastMonth('$pctStr%');
      }
    }

    final hero0 = isDark ? colors.heroDarkStart : colors.heroStart;
    final hero1 = isDark ? colors.heroDarkEnd : colors.heroEnd;
    // 渐变端点由 theme_registry 门禁保证白字 ≥ 4.6:1，文字全用白系。
    const onHero = Colors.white;
    final onHeroSub = Colors.white.withValues(alpha: 0.82);
    final onHeroLabel = Colors.white.withValues(alpha: 0.74);
    final heroHairline = Colors.white.withValues(alpha: 0.24);

    return Padding(
      // 横向内距归 `ListView.padding`（左右各 16）统一负责 —— 这里**不能再加**，
      // 否则渐变卡比下面的日卡片窄 32（用户口径：方框要和列表项一样宽）。
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [hero0, hero1],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  s.thisMonthExpense,
                  style: TextStyle(
                    fontSize: 12,
                    height: designLineHeight(12),
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.04 * 12,
                    color: onHeroSub,
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 28 * designLineHeight(28),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: AmountDisplay(
                      cents: expense,
                      fontSize: 28,
                      color: onHero,
                      decorationColor: onHeroSub,
                    ),
                  ),
                ),
                if (vsText != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    vsText,
                    style: TextStyle(
                      fontSize: 12,
                      height: designLineHeight(12),
                      fontWeight: FontWeight.w500,
                      color: onHeroSub,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Container(height: 1, color: heroHairline),
                const SizedBox(height: 10),
                Row(
                  // 大金额（¥+12,800.00）在窄屏/宽字体下会顶破 Row
                  // （实测溢出 17px），各占一半 + FittedBox 缩放兜底。
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: _HeroStat(
                          label: s.income,
                          cents: income,
                          labelColor: onHeroLabel,
                          valueColor: onHero,
                          valueDecoration: onHeroSub,
                          isIncome: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: _HeroStat(
                          label: s.thisMonthBalance,
                          cents: balance,
                          labelColor: onHeroLabel,
                          valueColor: onHero,
                          valueDecoration: onHeroSub,
                          showValueSign: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 12, left: 2),
            child: Row(
              spacing: 6,
              children: [
                PlainIcon(
                  PlainIconData.calendar,
                  size: 13,
                  color: colors.inkFaint,
                ),
                Text(
                  s.monthStartNote(monthStartDay),
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
        ],
      ),
    );
  }
}

/// 渐变卡内的小统计（收入 / 结余）：标签 + 15 号金额，白系。
class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.label,
    required this.cents,
    required this.labelColor,
    required this.valueColor,
    required this.valueDecoration,
    this.showValueSign = false,
    this.isIncome = false,
  });

  final String label;
  final int cents;
  final Color labelColor;
  final Color valueColor;
  final Color valueDecoration;
  final bool showValueSign;
  final bool isIncome;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 3,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            height: designLineHeight(12),
            fontWeight: FontWeight.w600,
            letterSpacing: 0.04 * 12,
            color: labelColor,
          ),
        ),
        AmountDisplay(
          cents: cents,
          fontSize: 15,
          color: valueColor,
          decorationColor: valueDecoration,
          showValueSign: showValueSign,
          isIncome: isIncome,
        ),
      ],
    );
  }
}

/// 日头 eyebrow：`9月28日 周日`（12/600 / ls .08em / muted）。
///
/// 32 的上距就是设计稿的 `.grp{margin-top:32px}`：分组靠留白分，不靠盒子。
/// ⚠️ 设计稿的 eyebrow **只有日期**，右侧没有「当日合计」那一列 —— 别再加回去。
class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.group});
  final DayGroup group;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 32, 2, 8),
      child: Text(
        dayLabel(AppStrings.of(context), group.dayKey),
        style: TextStyle(
          fontSize: 12,
          height: designLineHeight(12),
          fontWeight: FontWeight.w600,
          letterSpacing: 0.08 * 12,
          color: context.colors.inkTertiary,
        ),
      ),
    );
  }
}

/// 流水行（panel 内）：6px 色点 · 名称/备注 · 金额（ink，无符号）
class _EntryRow extends ConsumerStatefulWidget {
  const _EntryRow({
    super.key,
    required this.entry,
    required this.category,
    required this.parent,
    required this.controller,
    this.isFirst = false,
  });

  final LedgerEntry entry;

  /// 记账落的是**二级分类**（《08-数据模型设计》§5.1「category_id — 二级分类优先；
  /// 允许仅一级」），色点取它的 `iconRef`。
  final domain.Category? category;

  /// 二级分类的一级父类；仅一级分类记账时为 null。
  ///
  /// ⚠️ 数据侧**不需要新增任何表**：`categories` 本来就是**自引用两层级树**
  /// （`preset_categories.dart` 用 `insertOne(child, id)` 把二级的 `parent_id`
  /// 指向一级；支出 12 一级 + 41 二级），`categoryMap` 里一级二级都在，
  /// 回查一次即可拿到一级名。
  final domain.Category? parent;

  final FlowListController controller;
  final bool isFirst;

  @override
  ConsumerState<_EntryRow> createState() => _EntryRowState();
}

class _EntryRowState extends ConsumerState<_EntryRow> {
  bool _dismissing = false;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final entry = widget.entry;
    final category = widget.category;
    final controller = widget.controller;
    final colors = context.colors;
    final hide = ref.watch(hideAmountsProvider);

    // 设计：行内金额 ink、无符号；分类点用分类色
    final amountText = formatAmount(entry.amount.cents, hide: hide);
    // 《08-SCREENS-SPEC/02-ledger》§4：`.rt` = **一级**（餐饮）；
    // `.sub` = 「二级 · 备注」（午餐 · 公司楼下）。
    final title = widget.parent?.name ?? category?.name ?? s.uncategorized;
    final sub = _subtitleOf(entry, category, widget.parent);
    // 分类图标：二级有自己的 iconRef 就用它，留空则继承一级（与预置数据口径一致）；
    // 颜色跟着最终那个 ref 走，保证「图标和点同色」。
    final catRef = category != null && category.iconRef.isNotEmpty
        ? category.iconRef
        : (widget.parent?.iconRef.isNotEmpty ?? false)
            ? widget.parent!.iconRef
            : 'other';
    final dotColor = _catColor(catRef);

    return Dismissible(
      key: Key(entry.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: colors.expense.withValues(alpha: 0.12),
        child: PlainIcon(PlainIconData.delete, color: colors.expense),
      ),
      confirmDismiss: (_) async {
        if (_dismissing) return false;
        _dismissing = true;
        return true;
      },
      onDismissed: (_) {
        controller.removeLocal(entry.id);
        controller.deleteEntry(entry.id).then((ok) {
          if (!context.mounted) return;
          if (ok) {
            showAppToastWithAction(
              context,
              s.deleted,
              actionLabel: s.undo,
              onAction: () => controller.undoDelete(),
            );
          } else {
            showAppToast(context, s.deleteFailed);
          }
        });
      },
      child: Material(
        // ⚠️ 必须与 `_DayPanel` 同色（都是 `surfaceCard`）。透明也行，但实心
        // 更稳：滑动删除过程中行底不会漏出面板色。颜色本身已由令牌统一。
        color: colors.surfaceCard,
        child: InkWell(
          onTap: () => context.push('/entry/${entry.id}'),
          child: Container(
            constraints: const BoxConstraints(minHeight: 60),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: widget.isFirst ? const Color(0x00000000) : colors.divider,
                  width: 1,
                ),
              ),
            ),
            // `.row{gap:10px}` —— 色点到文字是 10，不是 12。
            child: Row(
              spacing: 10,
              children: [
                // 分类图标（v3 描边风，未知 ref 兜底「其他」）。之前这里是
                // 一个 6×6 色点，是设计稿早期的简化，真机上辨识度太低。
                CategoryAvatar(iconRef: catRef, color: dotColor, size: 20),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    // `.rcol{gap:2px}`
                    spacing: 2,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          // `.rcol .rt{font-size:15;font-weight:500}` + `lh:normal`
                          // → 行盒 20。不写 height 会继承 body 的 1.5714 → 23.57。
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
                    // `.rw-amt{font-size:15;font-weight:600;letter-spacing:-.01em}`，行盒 20。
                    height: designLineHeight(15),
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.01 * 15,
                    color: colors.ink,
                    fontFeatures: kTabularFigures,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _catColor(String iconRef) {
    final argb = categoryColorFor(iconRef);
    return argb != null ? Color(argb) : context.colors.inkTertiary;
  }

  /// 设计 §4 的 `.sub` = 「二级分类 · 备注」（`r1s="午餐 · 公司楼下"`）。
  ///
  /// 备注选填 → 有二级无备注时就是「午餐」；两者都空（仅一级记账且没写备注）
  /// 才退回时间，避免整行只剩标题。
  ///
  /// ⚠️ 退回的是**录入时刻**（`createdAt`），不是 `occurredAt`：天内顺序本身就是
  /// 「按录入先后」（见 `compareByRecordedOrder`）。显示发生时刻会出现
  /// 「09:00 排在 20:00 上面」这种看着像 bug 的画面 —— 补记时 occurredAt 的
  /// 时分是程序补的，用户从没设过。发生时刻在详情页看。
  String _subtitleOf(
    LedgerEntry entry,
    domain.Category? category,
    domain.Category? parent,
  ) {
    final note = entry.note;
    final parts = <String>[
      if (parent != null && category != null) category.name,
      if (note != null && note.isNotEmpty) note,
    ];
    if (parts.isNotEmpty) return parts.join(' · ');
    final t = entry.createdAt.toLocal();
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }
}

/// 日分组圆角面板：panel r16 / surface / 1px line，行间 line-soft。
///
/// ⚠️ 这里必须是 `Container` 而不是 `DecoratedBox`：CSS 的 `border` 占布局
/// （实测 `.row` 从 panel 的 x+1 起），Flutter 里只有 `Container` 会把
/// `decoration.padding` 算进子项内边距，`DecoratedBox` 不会 —— 用后者
/// 那 1px 边框会压在行的左缘上，色点从 33 掉到 32。
class _DayPanel extends StatelessWidget {
  const _DayPanel({
    required this.group,
    required this.controller,
    required this.categoryMap,
  });

  final DayGroup group;
  final FlowListController controller;
  final Map<String, domain.Category> categoryMap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // 先解析好「二级 → 一级」，再铺行（避免在 children 里塞 Builder）。
    final rows = <Widget>[];
    for (var i = 0; i < group.entries.length; i++) {
      final entry = group.entries[i];
      final cat = categoryMap[entry.categoryId];
      final parentId = cat?.parentId;
      rows.add(
        _EntryRow(
          key: ValueKey('e-${entry.id}'),
          entry: entry,
          category: cat,
          // 一级名由二级的 parentId 回查**同一张** categories 得到。
          parent: parentId == null ? null : categoryMap[parentId],
          controller: controller,
          isFirst: i == 0,
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        // ⚠️ 卡片底必须是 `colors.surfaceCard`（= `t.surface`）；页面底色是
        // `colors.pageBg`（= `t.appBg`，中性纸 × 品牌色 wash）。两者绝不能混：
        // 用后者卡片会和页面融为一体，只剩 1px 的边框，看上去「根本没有卡片」。
        //
        // 2026-10-20：`t.surface` 本身已是「40% 卡白 × 60% 纸色」的预混色
        // （theme_resolver 的「卡片底预混」段，全 app 卡片统一），这里不要再
        // 叠 withValues —— 再叠就成了透明色，且行内 Material 会造成叠乘。
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      clipBehavior: Clip.antiAlias,
      // ⚠️ 这层 `ClipRRect` 不能省。`Container` 的组装顺序是
      //   `DecoratedBox(边框+填充)` → `Padding(border 的 1px 内缩)` → `ClipPath` → 子级，
      // 而 `ClipPath` 按**整个** rect 取半径 16。子级只被内缩了 1px、四角还是直角，
      // 于是行里的白色 `Material`（`_EntryRow` 那层）在弧上盖住那 1px 边框：
      // 直边和弧的两端完好，中段（约 20°–70°）消失（实测墨量 0.94 → 0.16）。
      // 半径 15 = 16 − 1px，与外面那条弧**同心**，正好切在边框内沿，子级再也够不到边框。
      // 与 `plain_ui.dart` 的 `PlainPanel` 是同一个修法。
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: rows,
        ),
      ),
    );
  }
}
