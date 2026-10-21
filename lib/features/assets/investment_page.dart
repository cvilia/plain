/// SP-2-04 投资持仓 —— 份额 / 加权平均成本 / 市值 / 已实现盈亏。
///
/// STORY-10.1：页面**只读真实持仓与账户余额**，所有数字由
/// `HoldingService` 与账户派生余额算出，无写死值。
///
/// 行情说明（AC4/AC5）：本项目不接外部行情源，价格一律**手动录入**并记录
/// 录入时间；未录入价格的持仓不计入市值，页面提示补录。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plain/app/bootstrap.dart';
import 'package:plain/app/breakpoints.dart';
import 'package:plain/app/theme/app_colors.dart';
import 'package:plain/app/theme/design_tokens.dart';
import 'package:plain/core/format/amount_formatter.dart';
import 'package:plain/core/refresh/data_invalidation.dart';
import 'package:plain/design_system/amount_display.dart';
import 'package:plain/design_system/app_empty_state.dart';
import 'package:plain/design_system/app_error_state.dart';
import 'package:plain/design_system/app_toast.dart';
import 'package:plain/design_system/confirm_dialog.dart';
import 'package:plain/design_system/plain_icons_v3.dart';
import 'package:plain/design_system/picker_sheet.dart';
import 'package:plain/design_system/plain_ui.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/entities/holding.dart';
import 'package:plain/domain/services/holding_service.dart';
import 'package:plain/app/l10n/app_strings.dart';
import 'package:plain/app/l10n/strings_accounts.dart';
import 'package:plain/app/l10n/strings_domain.dart';

const _svc = HoldingService();

class InvestmentPage extends ConsumerStatefulWidget {
  const InvestmentPage({super.key, required this.accountId});
  final String accountId;

  @override
  ConsumerState<InvestmentPage> createState() => _InvestmentPageState();
}

class _InvestmentPageState extends ConsumerState<InvestmentPage> {
  bool _loading = true;
  Object? _loadError;
  String _accountName = '';
  List<Holding> _holdings = const [];
  HoldingsSummary _summary =
      HoldingsSummary.of(holdings: const [], cashCents: 0);

  @override
  void initState() {
    super.initState();
    // ⚠️ `_reload()` 开头就取 `AppStrings.of(context)`，`initState` 阶段
    // `Localizations` 还没挂载 → 必须等首帧后再跑（2026-10-20 全页面巡检发现）。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reload();
    });
  }

  Future<void> _reload() async {
    final s = AppStrings.of(context);
    setState(() {
      _loading = true;
      _loadError = null;
    });
    final deps = ref.read(appDependenciesProvider);
    final acct = await deps.accountRepository.getById(widget.accountId);
    final bal = await deps.accountRepository.balanceOf(widget.accountId);
    final list = await deps.holdingRepository.listByAccount(widget.accountId);
    if (!mounted) return;
    final loadFailure = acct.failureOrNull ??
        bal.failureOrNull ??
        list.failureOrNull;
    if (loadFailure != null) {
      setState(() {
        _loadError = loadFailure;
        _loading = false;
      });
      return;
    }
    final account = acct.successOrNull;
    final holdings = list.successOrNull ?? const <Holding>[];
    // 现金余额取自账户派生余额（持仓市值是另一块，不重复计）
    final cash = bal.successOrNull?.balanceCents ?? 0;
    setState(() {
      _accountName = account?.name ?? s.accountTypeInvestment;
      _holdings = holdings;
      _summary = HoldingsSummary.of(holdings: holdings, cashCents: cash);
      _loading = false;
    });
  }

  int _centsOf(String text) {
    final v = double.tryParse(text.trim());
    if (v == null || v <= 0) return 0;
    return (v * 100).round();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final colors = context.colors;
    return Scaffold(
      appBar: PlainTopBar(
        title: _accountName,
        showBack: true,
        actions: [
          Material(
            color: const Color(0x00000000),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: _showAddHolding,
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 52,
                height: 44,
                child: Center(
                  child: Text(s.addLabel,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: colors.primary)),
                ),
              ),
            ),
          ),
        ],
      ),
      body: _loadError != null
          ? AppErrorState.of(context, _loadError!, onRetry: _reload)
          : _loading
          ? const Center(child: CircularProgressIndicator())
          : ContentWidthConstraint(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    Spacing.lg, 0, Spacing.lg, Spacing.xl),
                children: [
                  _Hero(summary: _summary),
                  if (_holdings.isEmpty)
                    AppEmptyState(
                      icon: PlainIconData.trendUp,
                      title: s.noHoldings,
                      subtitle: s.holdingsHint,
                      action: FilledButton.icon(
                        onPressed: _showAddHolding,
                        icon: const PlainIcon(PlainIconData.plus),
                        label: Text(s.addHolding),
                      ),
                    )
                  else ...[
                    PlainEyebrow(s.holdingsCount(_holdings.length)),
                    PlainPanel(
                      children: [
                        for (var i = 0; i < _holdings.length; i++) ...[
                          if (i > 0)
                            Divider(
                                height: 1,
                                thickness: 1,
                                indent: 16,
                                color: colors.divider),
                          _HoldingRow(
                            holding: _holdings[i],
                            onTap: () => _showActions(_holdings[i]),
                          ),
                        ],
                      ],
                    ),
                  ],
                  const SizedBox(height: Spacing.md),
                  _NotePanel(hasUnpriced: _summary.needsPrice),
                ],
              ),
            ),
    );
  }

  Future<void> _showAddHolding() async {
    final s = AppStrings.of(context);
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final sharesCtrl = TextEditingController();
    final costCtrl = TextEditingController();
    var type = AssetType.fund;

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
              Text(s.addHolding, style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: Spacing.md),
              TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                      labelText: s.nameLabel, border: OutlineInputBorder())),
              const SizedBox(height: Spacing.md),
              TextField(
                  controller: codeCtrl,
                  decoration: InputDecoration(
                      labelText: s.codeOptionalLabel, border: OutlineInputBorder())),
              const SizedBox(height: Spacing.md),
              PickerField(
                label: s.typeLabel,
                value: type.label(AppStrings.of(context)),
                onTap: () async {
                  final picked = await showOptionPicker<AssetType>(
                    context: ctx,
                    title: s.typeLabel,
                    current: type,
                    options: [
                      for (final t in AssetType.values)
                        PickerOption(value: t, label: t.label(AppStrings.of(context))),
                    ],
                  );
                  if (picked != null) setSheet(() => type = picked);
                },
              ),
              const SizedBox(height: Spacing.md),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: sharesCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                        labelText: s.shares, border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: TextField(
                    controller: costCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                        labelText: s.costPrice,
                        border: OutlineInputBorder(),
                        prefixText: '¥'),
                  ),
                ),
              ]),
              const SizedBox(height: Spacing.lg),
              FilledButton(
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  final shares = double.tryParse(sharesCtrl.text.trim()) ?? 0;
                  final cost = _centsOf(costCtrl.text);
                  if (name.isEmpty || shares <= 0 || cost <= 0) return;
                  final deps = ref.read(appDependenciesProvider);
                  final now = deps.clock.now();
                  final code = codeCtrl.text.trim();
                  final r = await deps.holdingRepository.create(Holding(
                    id: deps.idGen.generate(),
                    bookId: deps.bookId,
                    accountId: widget.accountId,
                    name: name,
                    code: code.isEmpty ? null : code,
                    assetType: type,
                    sharesX10000: Quantity.fromUnits(shares),
                    costPriceCents: cost,
                    // 首次录入时把成本价同时作为现价，市值立刻可算
                    lastPriceCents: cost,
                    priceUpdatedAt: now,
                    createdAt: now,
                    updatedAt: now,
                    deviceId: deps.deviceId,
                  ));
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (!mounted) return;
                  if (r.isSuccess) {
                    ref.invalidateData.bumpAccountsMutated();
                    _reload();
                  } else {
                    showAppToast(context, s.saveFailed);
                  }
                },
                child: Text(s.save),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 对一笔持仓的操作：买入 / 卖出 / 更新价格 / 删除。
  Future<void> _showActions(Holding h) async {
    final s = AppStrings.of(context);
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(h.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                s.holdingSubtitle(Quantity.label(h.sharesX10000),
                    formatAmountYuan(h.costPriceCents)),
              ),
            ),
            const Divider(height: 1),
            ListTile(
                leading: const PlainIcon(PlainIconData.plus),
                title: Text(s.buy),
                onTap: () => Navigator.pop(ctx, 'buy')),
            ListTile(
                leading: const PlainIcon(PlainIconData.minus),
                title: Text(s.sell),
                onTap: () => Navigator.pop(ctx, 'sell')),
            ListTile(
                leading: const PlainIcon(PlainIconData.edit),
                title: Text(s.updatePrice),
                onTap: () => Navigator.pop(ctx, 'price')),
            ListTile(
                leading: const PlainIcon(PlainIconData.delete),
                title: Text(s.deleteHolding),
                onTap: () => Navigator.pop(ctx, 'delete')),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;

    switch (action) {
      case 'buy':
        await _showTrade(h, isSell: false);
      case 'sell':
        await _showTrade(h, isSell: true);
      case 'price':
        await _showUpdatePrice(h);
      case 'delete':
        final ok = await showConfirmDialog(
          context,
          title: s.deleteHolding,
          message: s.deleteHoldingMessage,
          confirmLabel: s.delete,
          destructive: true,
        );
        if (ok != true) return;
        await ref.read(appDependenciesProvider).holdingRepository.softDelete(h.id);
        if (mounted) _reload();
    }
  }

  Future<void> _showTrade(Holding h, {required bool isSell}) async {
    final s = AppStrings.of(context);
    // ★ 用局部变量 + `onChanged` 取值，不在页面里创建 `TextEditingController`。
    // `showDialog` 的 future 在 pop 那一刻就返回，但弹窗**淡出动画期间**子树仍会
    // 重建（`TextField` 的装饰动画会重新订阅 controller），此时 dispose 会抛
    // 「A TextEditingController was used after being disposed」。
    // `TextFormField` 自带内部 controller，生命周期由它的 State 管理，无需手动释放。
    var sharesText = '';
    var priceText = '';
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${isSell ? '卖出' : '买入'}「${h.name}」'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isSell
                  ? s.currentHolding(Quantity.label(h.sharesX10000))
                  : s.currentHoldingWithAvg(Quantity.label(h.sharesX10000),
                      formatAmountYuan(h.costPriceCents)),
              style: TextStyle(fontSize: 12, color: context.colors.inkTertiary),
            ),
            const SizedBox(height: Spacing.md),
            TextFormField(
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (v) => sharesText = v,
              decoration: InputDecoration(
                  labelText: s.shares, border: const OutlineInputBorder()),
            ),
            const SizedBox(height: Spacing.md),
            TextFormField(
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (v) => priceText = v,
              decoration: InputDecoration(
                  labelText: isSell ? s.sellPrice : s.buyPrice,
                  border: const OutlineInputBorder(),
                  prefixText: '¥'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text( s.cancel)),
          FilledButton(
            onPressed: () async {
              final shares = double.tryParse(sharesText.trim()) ?? 0;
              final price = _centsOf(priceText);
              if (shares <= 0 || price <= 0) return;
              final sharesX = Quantity.fromUnits(shares);
              final deps = ref.read(appDependenciesProvider);
              final now = deps.clock.now();

              if (isSell && _svc.validateSell(h, sharesX).isFailure) {
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) showAppToast(context, s.sellExceedsHolding);
                return;
              }
              final next = isSell
                  ? _svc
                      .sell(h, sharesX10000: sharesX, unitPriceCents: price, at: now)
                      .holding
                  : _svc.buy(h,
                      sharesX10000: sharesX, unitPriceCents: price, at: now);
              final r = await deps.holdingRepository.update(next);
              if (ctx.mounted) Navigator.pop(ctx);
              if (!mounted) return;
              if (r.isSuccess) {
                _reload();
              } else {
                showAppToast(context, s.operationFailed);
              }
            },
            child: Text( s.ok),
          ),
        ],
      ),
    );
  }

  Future<void> _showUpdatePrice(Holding h) async {
    final s = AppStrings.of(context);
    // 同 `_showBuySell`：不手管 controller，交给 `TextFormField` 内部 State。
    var priceText = '';
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.updatePriceTitle(h.name)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (h.priceUpdatedAt != null)
              Text(
                // AC4：行情不可用时显示上次价格并标注更新时间
                s.lastPriceUpdatedAt(_formatStamp(h.priceUpdatedAt!)),
                style: TextStyle(fontSize: 12, color: context.colors.inkTertiary),
              ),
            const SizedBox(height: Spacing.md),
            TextFormField(
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (v) => priceText = v,
              decoration: InputDecoration(
                  labelText: s.latestPrice,
                  border: OutlineInputBorder(),
                  prefixText: '¥'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.cancel)),
          FilledButton(
            onPressed: () async {
              final price = _centsOf(priceText);
              if (price <= 0) return;
              final deps = ref.read(appDependenciesProvider);
              final next = _svc.updatePrice(h,
                  priceCents: price, at: deps.clock.now());
              final r = await deps.holdingRepository.update(next);
              if (ctx.mounted) Navigator.pop(ctx);
              if (!mounted) return;
              _reload();
              if (r.isFailure) showAppToast(context, s.updateFailed);
            },
            child: Text(s.save),
          ),
        ],
      ),
    );
  }

  static String _formatStamp(DateTime at) {
    final local = at.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.summary});
  final HoldingsSummary summary;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: Spacing.sm, bottom: Spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(height: 1, thickness: 1, color: colors.divider),
          Padding(
            padding: const EdgeInsets.fromLTRB(2, Spacing.lg, 2, Spacing.sm),
            child: Text(
              s.investmentNetValueLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.08 * 12,
                color: colors.inkTertiary,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: Spacing.lg),
            child: AmountDisplay(
              cents: summary.netValueCents,
              fontSize: 34,
              integerWeight: FontWeight.w700,
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _Split(
                  label: s.marketValue,
                  amountCents: summary.marketValueCents,
                ),
              ),
              const SizedBox(width: Spacing.lg),
              Expanded(
                child: _Split(
                  label: s.cashBalance,
                  amountCents: summary.cashCents,
                ),
              ),
              const SizedBox(width: Spacing.lg),
              Expanded(
                child: _Split(
                  label: s.unrealizedPnl,
                  amountCents: summary.unrealizedPnlCents,
                  showSign: true,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: Spacing.lg),
            child: Divider(height: 1, thickness: 1, color: colors.divider),
          ),
        ],
      ),
    );
  }
}

class _Split extends StatelessWidget {
  const _Split({required this.label, required this.amountCents, this.showSign = false});
  final String label;
  final int amountCents;
  final bool showSign;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tone = showSign
        ? (amountCents >= 0 ? colors.income : colors.expense)
        : colors.ink;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: colors.inkTertiary)),
        const SizedBox(height: 4),
        Text(
          // 正号也在货币符号之后：`¥+2,000.00`，不是 `+¥2,000.00`
          showSign && amountCents > 0
              ? '¥+${formatAmount(amountCents)}'
              : formatAmountYuan(amountCents),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: tone,
          ),
        ),
      ],
    );
  }
}

class _HoldingRow extends StatelessWidget {
  const _HoldingRow({required this.holding, required this.onTap});
  final Holding holding;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final colors = context.colors;
    final h = holding;
    final pnl = h.unrealizedPnlCents;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(
                  h.code == null || h.code!.isEmpty
                      ? h.name
                      : '${h.name} · ${h.code}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              AmountDisplay(cents: h.marketValueCents, fontSize: 15),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              Expanded(
                child: Text(
                  s.holdingSummary(h.assetType.label(s),
                      Quantity.label(h.sharesX10000),
                      formatAmountYuan(h.costPriceCents)),
                  style: TextStyle(fontSize: 12, color: colors.inkTertiary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                h.hasPrice
                    // 正号在货币符号之后：`¥+120.00` / `¥-80.00`
                    ? '¥${pnl >= 0 ? '+' : '-'}${formatAmount(pnl.abs())}'
                    : s.noPrice,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: !h.hasPrice
                      ? colors.inkTertiary
                      : (pnl >= 0 ? colors.income : colors.expense),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _NotePanel extends StatelessWidget {
  const _NotePanel({required this.hasUnpriced});
  final bool hasUnpriced;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final colors = context.colors;
    return PlainPanel(
      padding: const EdgeInsets.all(Spacing.lg),
      children: [
        Text(
          hasUnpriced
              ? s.unpricedNote
              : s.priceNote,
          style: TextStyle(fontSize: 14, height: 1.65, color: colors.inkSecondary),
        ),
      ],
    );
  }
}
