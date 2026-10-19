/// SP-5-12 汇率锁定。
///
/// STORY-9.3：汇率**只有用户手动设定这一个来源**（本项目不接外部行情）。
/// 锁定后，用该币种账户记账时按锁定值折成本位币；每笔账单也可以带自己的汇率。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plain/app/bootstrap.dart';
import 'package:plain/app/breakpoints.dart';
import 'package:plain/app/theme/app_colors.dart';
import 'package:plain/app/theme/design_tokens.dart';
import 'package:plain/app/theme/typography.dart';
import 'package:plain/core/constants/app_constants.dart';
import 'package:plain/design_system/app_empty_state.dart';
import 'package:plain/design_system/app_toast.dart';
import 'package:plain/design_system/confirm_dialog.dart';
import 'package:plain/design_system/picker_sheet.dart';
import 'package:plain/design_system/plain_icons_v3.dart';
import 'package:plain/design_system/plain_ui.dart';
import 'package:plain/domain/entities/currency_rate.dart';
import 'package:plain/app/l10n/app_strings.dart';
import 'package:plain/app/l10n/strings_settings_a.dart';
import 'package:plain/app/l10n/strings_settings_b.dart';

class CurrencyRatePage extends ConsumerStatefulWidget {
  const CurrencyRatePage({super.key});

  @override
  ConsumerState<CurrencyRatePage> createState() => _CurrencyRatePageState();
}

class _CurrencyRatePageState extends ConsumerState<CurrencyRatePage> {
  bool _loading = true;
  List<CurrencyRate> _rates = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final deps = ref.read(appDependenciesProvider);
    final res = await deps.currencyRateRepository.listByBook(deps.bookId);
    if (!mounted) return;
    setState(() {
      _rates = res.successOrNull ?? const [];
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final colors = context.colors;
    final base = MoneyRules.defaultCurrency;
    return Scaffold(
      appBar: PlainTopBar(
        title: s.currencyRateTitle,
        showBack: true,
        actions: [
          PlainTopBarAction(
            icon: PlainIconData.plus,
            tooltip: s.addRate,
            onTap: () => _edit(null),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ContentWidthConstraint(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    Spacing.lg, Spacing.sm, Spacing.lg, Spacing.xl),
                children: [
                  if (_rates.isEmpty)
                    AppEmptyState(
                      icon: PlainIconData.cloud,
                      title: s.noLockedRate,
                      subtitle: s.noLockedRateHint(base),
                      action: FilledButton.icon(
                        onPressed: () => _edit(null),
                        icon: const PlainIcon(PlainIconData.plus),
                        label: Text(s.addRate),
                      ),
                    )
                  else
                    PlainPanel(children: [
                      for (var i = 0; i < _rates.length; i++) ...[
                        if (i > 0)
                          Divider(
                              height: 1,
                              thickness: 1,
                              indent: 16,
                              color: colors.divider),
                        _RateRow(
                          rate: _rates[i],
                          onTap: () => _edit(_rates[i]),
                          onDelete: () => _remove(_rates[i]),
                        ),
                      ],
                    ]),
                  const SizedBox(height: Spacing.md),
                  _NotePanel(base: base),
                ],
              ),
            ),
    );
  }

  Future<void> _edit(CurrencyRate? existing) async {
    final s = AppStrings.of(context);
    final currencies = CurrencyRules.symbols.keys
        .where((c) => c != MoneyRules.defaultCurrency)
        .toList();
    final initialFrom = existing?.fromCurrency ??
        (currencies.contains('USD') ? 'USD' : currencies.first);

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _RateEditDialog(
        existing: existing,
        currencies: currencies,
        initialFrom: initialFrom,
      ),
    );
    if (!mounted) return;
    if (saved == true) {
      showAppToast(context, s.rateLocked);
      await _load();
    }
  }

  Future<void> _remove(CurrencyRate r) async {
    final s = AppStrings.of(context);
    final ok = await showConfirmDialog(
      context,
      title: s.unlockRate,
      message: s.unlockRateConfirm(r.pairKey),
      confirmLabel: s.unlockRelation,
      destructive: true,
    );
    if (ok != true || !mounted) return;
    final deps = ref.read(appDependenciesProvider);
    await deps.currencyRateRepository.removeRate(
      bookId: deps.bookId,
      fromCurrency: r.fromCurrency,
      toCurrency: r.toCurrency,
    );
    await _load();
  }
}

/// 新增 / 修改锁定汇率的弹窗。
///
/// ★ 单独做成 `StatefulWidget`（而不是页面里用 `StatefulBuilder` + 局部
/// `TextEditingController`）是为了让 controller 的生命周期与弹窗子树一致。
/// 若在 `showDialog` 的 future 返回后立刻 `dispose()`，弹窗**淡出动画期间**
/// 子树仍会重建，会抛「A TextEditingController was used after being
/// disposed」——并连带把那一帧的布局打乱（表现为 `Column` 报出天文数字级
/// 的 RenderFlex 溢出）。交给 `State.dispose()` 就不会早于最后一个构建帧。
class _RateEditDialog extends ConsumerStatefulWidget {
  const _RateEditDialog({
    required this.existing,
    required this.currencies,
    required this.initialFrom,
  });

  /// null 表示新增。
  final CurrencyRate? existing;
  final List<String> currencies;
  final String initialFrom;

  @override
  ConsumerState<_RateEditDialog> createState() => _RateEditDialogState();
}

class _RateEditDialogState extends ConsumerState<_RateEditDialog> {
  late String _from = widget.initialFrom;
  late final TextEditingController _rateCtrl = TextEditingController(
      text: widget.existing == null ? '' : formatRate(widget.existing!.rate));
  bool _saving = false;

  /// 内联错误文案。**不再用 toast 报失败**：弹窗的模态遮罩会把它盖住，
  /// 用户看到的就是「点了保存没反应」（真机反馈 2026-10-15）。
  String? _error;

  @override
  void dispose() {
    _rateCtrl.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final s = AppStrings.of(context);
    final picked = await showCurrencyPicker(
      context: context,
      currencies: widget.currencies,
      current: _from,
      title: s.selectForeignCurrency,
    );
    if (picked != null && mounted) setState(() => _from = picked);
  }

  Future<void> _save() async {
    final s = AppStrings.of(context);
    final rate = double.tryParse(_rateCtrl.text.trim());
    if (rate == null || rate <= 0) {
      setState(() => _error = s.rateMustBePositive);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final deps = ref.read(appDependenciesProvider);
      final r = await deps.currencyRateRepository.setRate(
        bookId: deps.bookId,
        fromCurrency: _from,
        toCurrency: MoneyRules.defaultCurrency,
        rate: rate,
        deviceId: deps.deviceId,
      );
      if (!mounted) return;
      if (r.isFailure) {
        // 失败时不关弹窗，用户可直接改数重试。
        setState(() {
          _saving = false;
          _error = s.saveFailedDetail(r.failureOrNull?.code ?? 'unknown');
        });
        return;
      }
      Navigator.pop(context, true);
    } catch (e) {
      // ⚠️ 这里必须捕 `Object` 而不是 `Exception`：仓储只 catch Exception，
      // `TypeError` / `StateError` 这类 Error 会一路逃出来 —— 原先的后果是
      // 「保存中…」永久卡住（按钮被 `_saving ? null` 置灰，之后怎么点都没反应），
      // 且界面没有任何提示。现在无论如何都复位并把原因显示出来。
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = s.saveFailedDetail(e.toString());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final colors = context.colors;
    final existing = widget.existing;
    return AlertDialog(
      // 键盘弹起时内容可滚动，避免定型高度不够而溢出。
      scrollable: true,
      title: Text(existing == null ? s.addLockedRateTitle : s.editLockedRateTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(Radii.r2),
            // 已存在的汇率不允许改币种（改币种等于换一条记录）。
            onTap: existing != null ? null : _pick,
            child: InputDecorator(
              decoration: InputDecoration(
                  labelText: s.foreignCurrency, border: OutlineInputBorder()),
              child: Row(children: [
                Expanded(
                  child: Text(
                    '${CurrencyRules.symbolOf(_from)}  $_from  '
                    '${CurrencyRules.nameOf(_from)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      color: existing != null ? colors.inkTertiary : colors.ink,
                    ),
                  ),
                ),
                PlainIcon(
                  PlainIconData.chevronDown,
                  size: 18,
                  color: colors.inkTertiary,
                ),
              ]),
            ),
          ),
          const SizedBox(height: Spacing.md),
          TextField(
            controller: _rateCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: '1 $_from = ? ${MoneyRules.defaultCurrency}',
              hintText: '7.20',
              border: const OutlineInputBorder(),
            ),
          ),
          // 失败原因就在输入框下面，用户看得见（toast 会被弹窗遮罩盖住）
          if (_error != null) ...[
            const SizedBox(height: Spacing.sm),
            Text(
              _error!,
              style: TextStyle(
                fontSize: 12,
                height: designLineHeight(12),
                color: colors.expense,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context, false),
            child: Text(s.cancel)),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? s.recurringSaving : s.save),
        ),
      ],
    );
  }
}

/// 汇率展示：去掉无意义的尾随零（7.200000 → 7.2）。
String formatRate(double rate) {
  var s = rate.toStringAsFixed(6);
  while (s.contains('.') && s.endsWith('0')) {
    s = s.substring(0, s.length - 1);
  }
  if (s.endsWith('.')) s = s.substring(0, s.length - 1);
  return s;
}

class _RateRow extends StatelessWidget {
  const _RateRow({
    required this.rate,
    required this.onTap,
    required this.onDelete,
  });
  final CurrencyRate rate;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '1 ${rate.fromCurrency} = ${formatRate(rate.rate)} ${rate.toCurrency}',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(s.rateLockedBadge, style: TextStyle(fontSize: 12, color: colors.income)),
              ],
            ),
          ),
          IconButton(
            onPressed: onDelete,
            icon: const PlainIcon(PlainIconData.delete, size: 20),
            tooltip: s.deleteLockedRate,
          ),
        ]),
      ),
    );
  }
}

class _NotePanel extends StatelessWidget {
  const _NotePanel({required this.base});
  final String base;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final colors = context.colors;
    final lines = <String>[
      s.rateNoteSource,
      s.rateNoteConvert(base),
      s.rateNotePerEntry,
    ];
    return PlainPanel(
      padding: const EdgeInsets.all(Spacing.lg),
      children: [
        for (final l in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(l,
                style: TextStyle(
                    fontSize: 14, height: 1.65, color: colors.inkSecondary)),
          ),
      ],
    );
  }
}
