/// Quiet Ledger shared UI primitives.
/// See redesign-v3/05-COMPONENT-SPECS.md — panel / row / eyebrow / type-tab / switch.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:plain/app/theme/app_colors.dart';
import 'package:plain/app/theme/typography.dart';
import 'package:plain/design_system/plain_icons_v3.dart';

/// Section label above a panel. 12/600, muted, slight tracking.
class PlainEyebrow extends StatelessWidget {
  const PlainEyebrow(this.text, {super.key, this.padding});

  final String text;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(2, 16, 2, 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.08 * 12,
          color: context.colors.inkTertiary,
        ),
      ),
    );
  }
}

/// Surface panel: r16 / surface / 1px line. Children stacked with lineSoft dividers.
class PlainPanel extends StatelessWidget {
  const PlainPanel({
    super.key,
    required this.children,
    this.padding = EdgeInsets.zero,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(
          Divider(height: 1, thickness: 1, indent: 16, color: colors.divider),
        );
      }
      rows.add(children[i]);
    }
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      padding: padding,
      // ⚠️ 这层 `ClipRRect` 不是可有可无的。`Container` 的组装顺序是
      //   `DecoratedBox(边框+填充)` → `Padding(border 的 1px 内缩)` → `ClipPath` → 子级，
      // 而 `ClipPath` 按**整个** rect 取半径 16：子级只被推了 1px，四角仍是直角，
      // 于是行的白底在弧上盖住那 1px 边框 —— 直边和弧两端完好，中段消失
      // （实测边框墨量 0.94 → 0.16），看上去就像「卡片没有圆角边框」。
      // 半径 15 = 16 − 1px，与外面那条弧**同心**，正好切在边框内沿上：
      // 子级够不到边框，也不会和边框之间留缝（CSS `overflow:hidden` 就是这个行为）。
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        // ⚠️ `crossAxisAlignment` 必须显式写 `stretch`。
        // `Column` 默认是 `center` —— 调用方传进来的行若宽度是收缩的，
        // 就会被居中、与同层由本组件插入的满宽 `Divider` 对不齐（缩放时尤其明显）。
        // 面板是列表容器，语义上每一行都该满宽。
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: rows,
        ),
      ),
    );
  }
}

/// List row: min 60, label left, optional value/chevron/switch right.
class PlainRow extends StatelessWidget {
  const PlainRow({
    super.key,
    required this.title,
    this.subtitle,
    this.value,
    this.leading,
    this.trailing,
    this.showChevron = false,
    this.onTap,
    this.minHeight = 60,
  });

  final String title;
  final String? subtitle;
  final String? value;
  final Widget? leading;
  final Widget? trailing;
  final bool showChevron;
  final VoidCallback? onTap;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 12)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.inkTertiary,
                        ),
                      ),
                  ],
                ),
              ),
              if (value != null)
                Text(
                  value!,
                  style: TextStyle(fontSize: 15, color: colors.inkTertiary),
                ),
              if (showChevron) ...[
                const SizedBox(width: 4),
                PlainIcon(
                  PlainIconData.chevronRight,
                  size: 20,
                  color: colors.inkFaint,
                ),
              ],
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}

/// Type tab: 支出/收入/转账/借出/借入. Selected = primaryTint + 1px primaryInk border.
class PlainTypeTab extends StatelessWidget {
  const PlainTypeTab({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: selected ? colors.primaryTint : const Color(0x00000000),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? colors.primaryInk : const Color(0x00000000),
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? colors.ink : colors.inkTertiary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Quiet Ledger switch: 48×28 track / 22 thumb.
/// Off = line border; on = primary; disabled = disabledBg/disabledFg (NOT opacity).
class PlainSwitch extends StatelessWidget {
  const PlainSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // Disabled state must be visually distinct from "off" — use dedicated tokens.
    final Color trackColor;
    final Color trackBorder;
    final Color thumbColor;
    if (!enabled) {
      trackColor = colors.disabledBg;
      trackBorder = colors.disabledFg;
      thumbColor = colors.disabledFg;
    } else if (value) {
      trackColor = colors.primary;
      trackBorder = colors.primary;
      thumbColor = colors.surfaceCard;
    } else {
      trackColor = colors.border;
      trackBorder = colors.border;
      thumbColor = colors.surfaceCard;
    }

    return Semantics(
      toggled: value,
      enabled: enabled,
      child: GestureDetector(
        onTap: enabled ? () => onChanged?.call(!value) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 48,
          height: 28,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: trackColor,
            border: Border.all(color: trackBorder, width: 1),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 150),
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: thumbColor,
                shape: BoxShape.circle,
                boxShadow: enabled
                    ? [
                        BoxShadow(
                          color: colors.shadow1,
                          offset: const Offset(0, 1),
                          blurRadius: 2,
                        ),
                      ]
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Danger outline button (detail delete etc).
/// Whole button reads as danger — border + text + icon all use income-ink.
class PlainDangerButton extends StatelessWidget {
  const PlainDangerButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback onPressed;
  final PlainIconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // 提到局部变量：public 字段不参与类型提升，直接内联 `if (icon != null)` 收窄不了类型。
    final iconData = icon;
    return Material(
      color: const Color(0x00000000),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 44,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.incomeLine, width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (iconData != null) ...[
                PlainIcon(iconData, size: 18, color: colors.incomeInk),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: colors.incomeInk,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Primary button: 52 high / r12 / no elevation. Saturated accent.
class PlainPrimaryButton extends StatelessWidget {
  const PlainPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback onPressed;
  final PlainIconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // 同 PlainDangerButton：public 字段不做类型提升，先落到局部变量。
    final iconData = icon;
    return Material(
      color: colors.primary,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 52,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: colors.shadow1,
                offset: const Offset(0, 1),
                blurRadius: 2,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (iconData != null) ...[
                PlainIcon(iconData, size: 18, color: colors.onPrimary),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colors.onPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Category color dot (8×8 default, 6×6 for row inline).
class CategoryDot extends StatelessWidget {
  const CategoryDot({super.key, required this.color, this.size = 8});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
// B0 additions — PlainTopBar / PlainSeg / PlainTag
// ══════════════════════════════════════════════════════════════════════

/// Top bar: 56 high, title 20/600 centered, optional back (44×44 r12) + right actions.
/// Replaces Material AppBar entirely.
class PlainTopBar extends StatelessWidget implements PreferredSizeWidget {
  const PlainTopBar({
    super.key,
    required this.title,
    this.showBack = false,
    this.onBack,
    this.leadingIcon,
    this.actions = const [],
    this.primary = true,
    this.centerTitle = true,
  });

  final String title;
  final bool showBack;
  final VoidCallback? onBack;

  /// 覆盖左上角按钮造型。设计稿里「记一笔」用 ✕（关闭）而非返回箭头；
  /// 为空时退回 [showBack] 的默认箭头行为。
  final PlainIconData? leadingIcon;

  final List<Widget> actions;

  /// 与 Material `AppBar.primary` 同义：是否把系统状态栏高度算进自身高度。
  ///
  /// 作为 `Scaffold.appBar` 时**必须**保持 `true`。`Scaffold` 给 `appBar` 的是
  /// **loose 约束**（`_ScaffoldLayout` 里 `appBarHeight = layoutChild(...).height`），
  /// 高度完全由 appBar 自己决定 —— 标准 `AppBar` 正是自己把
  /// `MediaQuery.paddingOf(context).top` 加进高度的。本组件若不自算，
  /// 这 56pt 的前约 47pt 会压在系统状态栏下面（iPhone 上顶栏文字/按钮被遮）。
  ///
  /// 只有页面**自管**顶部内边距时才传 `false`：如「记一笔」把顶栏放进
  /// `body` 并显式 `Padding(top: viewPaddingOf(context).top)`，
  /// 此时再叠一层 SafeArea 会让顶栏双倍下移。
  final bool primary;

  /// 标题是否在**整条顶栏**里居中（而不是只在剩余空间里居中）。
  ///
  /// **默认开**（统一口径，别逐页各写一遍）：默认布局把标题放进 `Expanded`，
  /// 它的「中心」是中点右移后的位置 —— 右侧动作比左侧 44 宽多少，标题就左偏多少
  /// （如资产页的「净值 + ＋」偏了半个动作宽）。
  ///
  /// 居中的代价是可能与动作区重叠，因此这里**不是无脑居中**：
  /// 只有当两侧留得出标题空间时才绝对居中（`Stack`），否则退回「占满剩余空间」
  /// 的老布局 —— 那说明这条顶栏塞不下居中标题，硬居中会把标题压成一条缝或压在
  /// 图标上。极个别页面若要强制走老布局，传 `centerTitle: false`。
  final bool centerTitle;

  /// 居中标题两侧各留多少——左/右动作各按一个 44 图标按钮估算（8 外层 + 44 + 4 间距）。
  static const double _centerTitleSideInset = 8 + 44 + 4;

  /// 标题至少要有这么宽才值得居中；再窄就不如退回老布局（否则标题被压成一条缝）。
  static const double _minCenteredTitleWidth = 48;

  /// 右侧动作区宽度估算：[PlainTopBarAction] 是 44，其余（页面自绘文字按钮）按 64 估。
  double get _estimatedActionsWidth {
    if (actions.isEmpty) return 44;
    var w = 0.0;
    for (final a in actions) {
      w += a is PlainTopBarAction ? 44 : 64;
    }
    return w + 2 * (actions.length - 1); // 动作之间的 spacing
  }

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // 同上：`leadingIcon` 是 public 字段，不能靠 `!= null` 收窄，先取局部变量。
    final leading = leadingIcon;
    // 内容盒固定 56 高；状态栏内边距由外层 SafeArea 承担（见 `primary`）。
    //
    // 三处间距全部来自设计稿 `.topbar`，不要凭手感调：
    //   `.topbar{gap:4px;padding:0 8px}`      → 外层 Row spacing 4、左右 padding 8
    //   `.topbar h1{flex:1;padding:0 4px}`    → 标题左右各 4（对称，不移动视觉中心）
    //   `.tb-right{gap:2px}`                  → 右侧动作之间 2
    // 实测对账（屏 2）：leading 8–52 · gap 4 · h1 56–291(w235) · gap 4 · tb-right 295–385 · 右padding 8 = 393 ✓
    final content = SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: LayoutBuilder(
          builder: (context, c) {
            // 统一策略（别再逐页各开一次 centerTitle）：
            // 两侧留得出标题空间就绝对居中，留不出就退回「占满剩余空间」的老布局。
            // 判据用动作区宽度的估算值 —— 目的是「绝不重叠、绝不把标题压成一条缝」。
            final sideReserve = _estimatedActionsWidth > 44
                ? _estimatedActionsWidth
                : 44.0;
            final centered = centerTitle &&
                c.maxWidth - 2 * sideReserve >= _minCenteredTitleWidth;
            if (!centered) {
              return Row(
                spacing: 4,
                children: [
                  _leadingSlot(context, leading),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: _title(context),
                    ),
                  ),
                  _actionsSlot(),
                ],
              );
            }
            return Stack(
              alignment: Alignment.center,
              children: [
                Row(
                  spacing: 4,
                  children: [
                    _leadingSlot(context, leading),
                    const Spacer(),
                    _actionsSlot(),
                  ],
                ),
                // 绝对居中；标题框按估算的侧边宽度收窄，长标题先省略号截断
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: _centerTitleSideInset),
                  child: _title(context),
                ),
              ],
            );
          },
        ),
      ),
    );
    // `color` 必须落在 SafeArea **外层**：否则状态栏那一条会漏出 Scaffold 底色。
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: plainStatusBarStyle(context),
      child: Container(
        color: colors.surface,
        child: primary ? SafeArea(bottom: false, child: content) : content,
      ),
    );
  }

  /// 左侧槽位：自定义图标 > 返回箭头 > 44 占位（占位是为了让标题不贴边）。
  Widget _leadingSlot(BuildContext context, PlainIconData? leading) {
    if (leading != null) {
      return PlainTopBarAction(
        icon: leading,
        onTap: onBack ?? () => Navigator.of(context).maybePop(),
      );
    }
    if (showBack) {
      return PlainTopBarAction(
        icon: PlainIconData.back,
        onTap: onBack ?? () => Navigator.of(context).maybePop(),
      );
    }
    return const SizedBox(width: 44);
  }

  /// 右侧槽位：动作按钮；没有动作时同样留 44，两侧对称。
  Widget _actionsSlot() {
    if (actions.isEmpty) return const SizedBox(width: 44);
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 2,
      children: actions,
    );
  }

  Widget _title(BuildContext context) => Text(
        title,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 20,
          // spec.json 全 29 屏实测：size=20 / lh=normal / wt=600 / 行盒 27px。
          // 不写 height 会静默继承 DefaultTextStyle 的 1.5714 → 行盒 31.4（+4.4px）。
          height: designLineHeight(20),
          fontWeight: FontWeight.w600,
          color: context.colors.ink,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
}

/// 状态栏图标明暗 —— **全 App 唯一来源**。
///
/// Material `AppBar` 会自己往 widget 树上挂一层
/// `AnnotatedRegion<SystemUiOverlayStyle>`（`_AppBarState.build` 里按
/// `AppBarTheme.systemOverlayStyle` → `ThemeData.brightness` 推算）。
/// `PlainTopBar` 取代它之后如果不补这一层，状态栏的文字/电池图标就**完全没人管**：
/// 暗色主题下系统仍按浅色背景推出深色图标，贴在深色顶栏上看不见。
///
/// 两端读的字段不是同一个（`flutter/services.dart` 的 `SystemUiOverlayStyle`）：
/// - iOS：`statusBarBrightness` 描述的是**背景**亮度 —— 深背景要填 [Brightness.dark]，
///   系统才知道该用白字。
/// - Android：`statusBarIconBrightness` 描述的是**图标**亮度 —— 深背景填 [Brightness.light]。
///
/// `statusBarColor` 一律透明：顶栏的底色由 [PlainTopBar] 的 `Container` 铺到状态栏
/// 下面（它吃了 `primary: true` 的 `SafeArea`），再刷一层系统色会盖掉主题底色。
SystemUiOverlayStyle plainStatusBarStyle(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
  );
}

/// 顶栏里的图标按钮：44×44 / r12 / 图标 22 —— 与 [PlainTopBar] 左侧返回键同一造型。
///
/// 用于 [PlainTopBar.actions]（右侧动作区是 `Row(mainAxisSize: min)`，宽度即 44）。
///
/// ⚠️ 别用 Material `IconButton`：它默认命中盒 48×48、内边距 8、图标 24、
/// 前景色走 `colorScheme` —— 与设计稿的 44 / 22 / `inkSecondary` 三处都不一致，
/// 混用会让「同一根顶栏在不同页面高矮胖瘦都不一样」。
class PlainTopBarAction extends StatelessWidget {
  const PlainTopBarAction({
    super.key,
    required this.icon,
    this.onTap,
    this.iconSize = 22,
    this.color,
    this.tooltip,
  });

  final PlainIconData icon;
  final VoidCallback? onTap;
  final double iconSize;

  /// 默认 `inkSecondary`；「清空」这类破坏性动作传 `expense`。
  final Color? color;

  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final btn = Material(
      color: const Color(0x00000000),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 44,
          height: 44,
          // Center 给 child 松约束，避免 SvgPicture 被 tight 约束拉到 44。
          child: Center(
            child: PlainIcon(
              icon,
              size: iconSize,
              color: color ?? colors.inkSecondary,
            ),
          ),
        ),
      ),
    );
    final tip = tooltip;
    return tip == null ? btn : Tooltip(message: tip, child: btn);
  }
}

/// 底部单选弹层 —— 全 App 唯一实现。
///
/// 为什么不用 `showModalBottomSheet` + `ListTile`：
/// `ListTile` 是 Material 组件（行高 56 / 左右内边距 16 / 选中态走
/// `colorScheme.primary` 的淡染底 / 文本行高继承自己的 `textTheme`），
/// 与设计系统的 `.row`（`min-height:60` · `padding:9px 16px` · 选中靠一个
/// `ic_check`）三处都不一致 —— 同一个「选一个值」的动作在设置页里
/// 会长成两个样子。
///
/// 弹层自身也照设计系统收口：`surface` 底 + 顶部 r24 + 行间 1px `line-soft`
/// 满宽分隔（对应 `.row + .row{border-top:1px solid var(--line-soft)}`，
/// 注意**不缩进**，与 [PlainPanel] 内那种缩进 16 的分隔线不是一回事）。
///
/// 返回被点中的值；点遮罩关闭返回 `null`。
Future<T?> showPlainPickerSheet<T>({
  required BuildContext context,
  required String title,
  required List<(T, String)> options,
  T? selected,
}) {
  final colors = context.colors;
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: colors.surface,
    // 别让它顶到全屏：28 个月起始日会铺满整块屏幕，失去「弹层」的语义。
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.6,
    ),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 12),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 15,
                height: designLineHeight(15),
                fontWeight: FontWeight.w600,
                color: colors.ink,
              ),
            ),
          ),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: options.length,
              separatorBuilder: (_, _) =>
                  Divider(height: 1, thickness: 1, color: colors.divider),
              itemBuilder: (_, i) {
                final (value, label) = options[i];
                return PlainRow(
                  title: label,
                  trailing: value == selected
                      ? PlainIcon(
                          PlainIconData.check,
                          size: 20,
                          color: colors.primaryInk,
                        )
                      : null,
                  onTap: () => Navigator.pop(ctx, value),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

/// Segmented control: 36 high / surfaceInset track / selected item r8 surface.
/// Hit target extended to 44 via transparent padding.
class PlainSeg extends StatelessWidget {
  const PlainSeg({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<String> items;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colors.surfaceInset,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: _SegItem(
                label: items[i],
                selected: i == selectedIndex,
                onTap: () => onChanged(i),
              ),
            ),
        ],
      ),
    );
  }
}

class _SegItem extends StatelessWidget {
  const _SegItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: selected ? colors.surfaceCard : const Color(0x00000000),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: colors.shadow1,
                      offset: const Offset(0, 1),
                      blurRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? colors.ink : colors.inkTertiary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Small pill tag: 22 high / r999 / 12·600. Used for 已支持 / 规划中 / V3.0 etc.
class PlainTag extends StatelessWidget {
  const PlainTag({
    super.key,
    required this.label,
    this.tone = PlainTagTone.neutral,
  });

  final String label;
  final PlainTagTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (Color bg, Color fg) = switch (tone) {
      PlainTagTone.neutral => (colors.surfaceMuted, colors.inkTertiary),
      PlainTagTone.ring => (colors.warnSoft, colors.warnInk),
      PlainTagTone.done => (colors.okSoft, colors.okInk),
      PlainTagTone.danger => (colors.incomeSoft, colors.incomeInk),
    };
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}

enum PlainTagTone { neutral, ring, done, danger }
