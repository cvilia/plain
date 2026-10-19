/// 底部选择弹层（通用）。
///
/// 全站「从一列选项里挑一个」的场景都走这里：币种、还款方式、还款账户、
/// 利息分类、资产估值方式…… 它们共用同一套外壳 —— 整屏宽、高度随内容自适应
/// （最多屏高 2/3，超出内部滚动）、圆角 24、顶部拖拽条 + 标题；只有行内布局不同。
///
/// 各页面不要再各写一套 `DropdownButtonFormField`：系统下拉又窄又要滚动，
/// 多选项时尤其难用。
library;

import 'package:flutter/material.dart';
import 'package:plain/app/l10n/app_strings.dart';
import 'package:plain/app/theme/app_colors.dart';
import 'package:plain/app/theme/design_tokens.dart';
import 'package:plain/core/constants/app_constants.dart';
import 'package:plain/design_system/plain_icons_v3.dart';

/// 一个可选项。[description] 渲染为第二行小字（可空）。
@immutable
class PickerOption<T> {
  const PickerOption({
    required this.value,
    required this.label,
    this.description,
  });

  final T value;
  final String label;
  final String? description;
}

/// 通用选项弹层：返回选中值；取消返回 null。
Future<T?> showOptionPicker<T>({
  required BuildContext context,
  required List<PickerOption<T>> options,
  required T? current,
  String? title,
}) {
  final s = AppStrings.of(context);
  return _showPickerSheet<T>(
    context: context,
    title: title ?? s.pleaseSelect,
    buildRows: (ctx) => options.isEmpty
        ? [
            Padding(
              padding: const EdgeInsets.all(Spacing.xl),
              child: Text(
                s.noOptionsAvailable,
                style: TextStyle(fontSize: 14, color: ctx.colors.inkTertiary),
              ),
            ),
          ]
        : [
            for (final o in options)
              _OptionRow(
                label: o.label,
                description: o.description,
                selected: o.value == current,
                onTap: () => Navigator.pop(ctx, o.value),
              ),
          ],
  );
}

/// 币种弹层：行内为「符号 · 代码 · 中文名」三列。
///
/// 币种清单与中文名一律取自 `CurrencyRules`，本文件不持有币种数据。
Future<String?> showCurrencyPicker({
  required BuildContext context,
  required List<String> currencies,
  required String current,
  String? title,
}) {
  final s = AppStrings.of(context);
  return _showPickerSheet<String>(
    context: context,
    title: title ?? s.selectCurrency,
    buildRows: (ctx) => [
      for (final c in currencies)
        _CurrencyRow(
          code: c,
          selected: c == current,
          onTap: () => Navigator.pop(ctx, c),
        ),
    ],
  );
}

/// 外壳：整屏宽；高度随内容自适应，超过屏高 2/3 则停在 2/3 并内部滚动。
/// 不设 minHeight —— 选项少时（如报销两态）弹层贴内容收拢，不留空板。
Future<T?> _showPickerSheet<T>({
  required BuildContext context,
  required String title,
  required List<Widget> Function(BuildContext ctx) buildRows,
}) {
  final h = MediaQuery.sizeOf(context).height;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    // 与 showDialog 同层（root navigator），否则可能被 shell 的底部导航遮挡。
    useRootNavigator: true,
    useSafeArea: true,
    backgroundColor: context.colors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.r4)),
    ),
    constraints: BoxConstraints(maxHeight: h * 2 / 3),
    builder: (ctx) => SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              margin:
                  const EdgeInsets.only(top: Spacing.sm, bottom: Spacing.md),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: ctx.colors.divider,
                borderRadius: BorderRadius.circular(Radii.pill),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                Spacing.lg, 0, Spacing.lg, Spacing.sm),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: ctx.colors.ink,
              ),
            ),
          ),
          ...buildRows(ctx),
          SizedBox(height: MediaQuery.paddingOf(ctx).bottom + Spacing.sm),
        ],
      ),
    ),
  );
}

/// 表单里的「选择项」字段：外观与 `TextField` 完全一致（描边 + 浮动标签 +
/// 右侧 chevron），但点击唤起底部弹层，不用系统下拉。
///
/// 与 [showOptionPicker] / [showCurrencyPicker] 配套使用：
/// ```dart
/// PickerField(
///   label: '还款方式',
///   value: _loanMethod.label,
///   onTap: () async {
///     final picked = await showOptionPicker<LoanRepayMethod>(...);
///     if (picked != null) setState(() => _loanMethod = picked);
///   },
/// )
/// ```
class PickerField extends StatelessWidget {
  const PickerField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.enabled = true,
    this.border,
  });

  /// 浮动标签。传 null 表示不显示标签（标签由外部标题行承担）。
  final String? label;
  final String value;

  /// 点击回调（内部唤起 `showOptionPicker` / `showCurrencyPicker`）。
  final VoidCallback onTap;

  /// 为 false 时字段置灰且不可点（用于编辑态锁定字段）。
  final bool enabled;

  /// 边框样式。默认 null → 继承全局 `inputDecorationTheme`
  /// （全库为圆角 12 的描边），与同表单的 `TextFormField` 像素一致。
  /// 个别表单若要下划线风格，可显式传 `const UnderlineInputBorder()`。
  final InputBorder? border;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(Radii.r2),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: border,
          enabled: enabled,
        ),
        child: Row(children: [
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                color: enabled ? null : context.colors.inkTertiary,
              ),
            ),
          ),
          PlainIcon(
            PlainIconData.chevronDown,
            size: 18,
            color: context.colors.inkTertiary,
          ),
        ]),
      ),
    );
  }
}

/// 通用行：主标签 + 可选副标签，选中打勾。
class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.label,
    required this.selected,
    required this.onTap,
    this.description,
  });

  final String label;
  final String? description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final desc = description;
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(
            horizontal: Spacing.lg, vertical: Spacing.sm),
        color: selected ? colors.primary.withValues(alpha: 0.08) : null,
        child: Row(children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: colors.ink,
                  ),
                ),
                if (desc != null && desc.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    desc,
                    style: TextStyle(fontSize: 12, color: colors.inkTertiary),
                  ),
                ],
              ],
            ),
          ),
          if (selected)
            PlainIcon(PlainIconData.check, size: 18, color: colors.primary),
        ]),
      ),
    );
  }
}

/// 币种行：符号（定宽）+ 代码 + 中文名，选中打勾。
class _CurrencyRow extends StatelessWidget {
  const _CurrencyRow({
    required this.code,
    required this.selected,
    required this.onTap,
  });

  final String code;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sym = CurrencyRules.symbolOf(code);
    // 没有独立符号的币种（如 CHF）其符号即代码，留空占位，
    // 避免出现「CHF  CHF  瑞士法郎」这种重复。
    final showSymbol = sym != code;
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(
            horizontal: Spacing.lg, vertical: Spacing.sm),
        color: selected ? colors.primary.withValues(alpha: 0.08) : null,
        child: Row(children: [
          SizedBox(
            width: 44,
            child: Text(
              showSymbol ? sym : '',
              style: TextStyle(fontSize: 15, color: colors.inkTertiary),
            ),
          ),
          Text(
            code,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: colors.ink,
            ),
          ),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Text(
              CurrencyRules.nameOf(code),
              style: TextStyle(fontSize: 15, color: colors.inkSecondary),
            ),
          ),
          if (selected)
            PlainIcon(PlainIconData.check, size: 18, color: colors.primary),
        ]),
      ),
    );
  }
}
