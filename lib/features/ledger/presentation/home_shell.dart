/// Home shell — Quiet Ledger nav.
/// CSS: .nav 60px / border-top line / .navitem column gap 3 / .navfab 44×44 r14 accent
/// See redesign-v3/单独确认.html
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:plain/app/breakpoints.dart';
import 'package:plain/app/theme/app_colors.dart';
import 'package:plain/app/theme/typography.dart';
import 'package:plain/design_system/app_toast.dart';
import 'package:plain/design_system/plain_icons_v3.dart';
import 'package:plain/domain/services/member_service.dart';
import 'package:plain/app/l10n/app_strings.dart';
import 'package:plain/app/l10n/strings_ledger.dart';

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final sizeClass = Breakpoints.sizeClassFromConstraints(constraints);
        final isWide = sizeClass != SizeClass.compact;

        if (isWide) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: _railIndex(navigationShell.currentIndex),
                  onDestinationSelected: (i) => _onTap(_branchFromRail(i)),
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    NavigationRailDestination(
                      icon: PlainIcon(PlainIconData.navLedger, size: 22),
                      label: Text(s.flow),
                    ),
                    NavigationRailDestination(
                      icon: PlainIcon(PlainIconData.navReport, size: 22),
                      label: Text(s.reports),
                    ),
                    NavigationRailDestination(
                      icon: PlainIcon(PlainIconData.navAssets, size: 22),
                      label: Text(s.accounts),
                    ),
                    NavigationRailDestination(
                      icon: PlainIcon(PlainIconData.navProfile, size: 22),
                      label: Text(s.navMine),
                    ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: navigationShell),
              ],
            ),
          );
        }

        // ⚠️ `resizeToAvoidBottomInset: false` 不能省。
        // 外壳自身没有任何需要系统键盘的输入 —— 子页面（流水/报表/资产/我的）
        // 都只读列表，输入都在各自的独立路由或 bottom sheet 里。
        // 默认 true 时，只要任何一个 bottom sheet / 弹窗唤起系统键盘，
        // 这个 60 高的自绘导航条 `_QuietNav` 就会被顶到键盘上方，
        // 出现「导航条浮在键盘上」的错位（Flutter 的 Scaffold 在
        // resizeToAvoidBottomInset 为 true 时会把 bottomNavigationBar
        // 一起抬到 viewInsets 之上）。关掉后导航条留在原位、被键盘正常覆盖。
        return Scaffold(
          resizeToAvoidBottomInset: false,
          body: navigationShell,
          bottomNavigationBar: _QuietNav(
            branchIndex: navigationShell.currentIndex,
            onTap: _onTap,
            // STORY-8.2 AC2：只读成员没有记账权限 —— 入口当场说明，
            // 不要等他输完金额再在保存时拦（保存拦截仍在，双保险）。
            onAdd: () {
              if (!ref.read(canWriteLedgerProvider)) {
                showAppToast(context, s.readOnlyNoPermission);
                return;
              }
              context.push('/entry');
            },
          ),
        );
      },
    );
  }

  // shell branches: 0=流水 1=报表 2=资产 3=我的（记一笔是独立路由，不是 branch）
  int _railIndex(int branch) => branch;
  int _branchFromRail(int rail) => rail;

  void _onTap(int branch) {
    navigationShell.goBranch(
      branch,
      initialLocation: branch == navigationShell.currentIndex,
    );
  }
}

/// .nav 60px · border-top · appBg · 5 slots with center FAB.
class _QuietNav extends StatelessWidget {
  const _QuietNav({
    required this.branchIndex,
    required this.onTap,
    required this.onAdd,
  });

  final int branchIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final colors = context.colors;

    // 导航条一体：上边框 + 60 内容高 + 安全区，避免 bottom overflow
    return Container(
      decoration: BoxDecoration(
        // 导航条不是卡片：与页面同底（pageBg），只靠 1px 上边框分层。
        color: colors.pageBg,
        border: Border(top: BorderSide(color: colors.border, width: 1)),
      ),
      // ⚠️ `maintainBottomViewPadding: true` 不能省。
      //
      // SafeArea 默认读 `MediaQuery.padding`，其 `bottom` 是
      // `max(0, viewPadding − viewInsets)` —— 系统键盘一弹就变成 0。
      // 外壳用了 `resizeToAvoidBottomInset: false`（见上），Scaffold 不会把
      // 底栏抬走，但 SafeArea 仍然会把自己的底部内边距从 34 掉到 0：
      // 底栏总高 94 → 60，Scaffold 把多出的 34pt 让给 body，
      // 于是四个子页面里「贴底对齐」的内容整体下滑 34pt（静默重排）。
      //
      // 该参数只把 **bottom** 换成 `viewPadding.bottom`（与键盘无关的原始安全区），
      // left / top / right 仍取 `padding` —— 横屏刘海那 44pt 左右安全区不受影响。
      child: SafeArea(
        top: false,
        maintainBottomViewPadding: true,
        // ⚠️ 59 不是 60。设计 `.nav{height:60px;border-top:1px}` 走的是
        // `box-sizing:border-box` —— 那 1px 边框**算在 60 里面**（实测
        // navitem h=59，图标落在 802 = 793 + 9）。Flutter 的 `Container`
        // 反过来把 `decoration.padding`（= 边框宽度）加在内容**之外**，
        // 写 60 会得到 61，图标整体下移 0.5px。
        child: SizedBox(
          height: 59,
          child: Row(
            children: [
              _NavItem(
                icon: PlainIconData.navLedger,
                label: s.flow,
                selected: branchIndex == 0,
                onTap: () => onTap(0),
              ),
              _NavItem(
                icon: PlainIconData.navReport,
                label: s.reports,
                selected: branchIndex == 1,
                onTap: () => onTap(1),
              ),
              // 记一笔：嵌在导航条中间，不是悬浮球
              Expanded(
                child: Center(child: _NavFab(onPressed: onAdd)),
              ),
              _NavItem(
                icon: PlainIconData.navAssets,
                label: s.accounts,
                selected: branchIndex == 2,
                onTap: () => onTap(2),
              ),
              _NavItem(
                icon: PlainIconData.navProfile,
                label: s.navMine,
                selected: branchIndex == 3,
                onTap: () => onTap(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final PlainIconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // `.navitem{color:var(--muted)}` / `.navitem.on{color:var(--primary-ink)}`。
    // ⚠️ 选中色是 `primary-ink`（在主色底上可读的那一档），不是 `primary` 本体 ——
    // 用 `primary` 在浅主题下对比度不够，深主题下又会糊在底上。
    //
    // ⚠️ 但素白这类「炭黑主色」主题里，primaryInk(#27272A) 与 inkTertiary(灰)
    // 色差太小，光靠文字颜色看不出选中了谁 —— 补一枚 4px 圆点指示器（所有主题
    // 通用，仍用 primaryInk，不加新色）。
    final fg = selected ? colors.primaryInk : colors.inkTertiary;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          // `.navitem{gap:3px}`
          spacing: 3,
          children: [
            // 设计稿实测 svg 22×22（不是 24）。
            PlainIcon(icon, size: 22, color: fg),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                // `.navlab{font-size:12;font-weight:500}` + `lh:normal` → 行盒 16。
                height: designLineHeight(12),
                fontWeight: FontWeight.w500,
                color: fg,
              ),
            ),
            // 选中指示点：未选中时用同尺寸占位，避免选中/切换时整列跳动。
            SizedBox(
              width: 4,
              height: 4,
              child: selected
                  ? DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.primaryInk,
                        shape: BoxShape.circle,
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _NavFab extends StatelessWidget {
  const _NavFab({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final colors = context.colors;
    // `.navfab{width:44px;height:44px;border-radius:14px;background:var(--accent);
    //          color:var(--fab-ic);box-shadow:0 2px 8px var(--shadow-accent)}`
    //
    // 底色 `fabBg` 恒等于**导航选中色** `primaryInk`（右侧 `_NavItem` 选中时用它），
    // 所以「记一笔」和「当前页签」永远是同一个色 —— 这是产品口径，不是巧合。
    // 图标 `fabIc` 是 `primaryInk` 对 4.5:1 的取反：亮主题深底白图标、暗主题浅底深图标。
    //
    // ⚠️ 别再写 `inkFor(accent, fabBg, 3.0)` 这类运行时兜底：`inkFor` 在
    // `contrast(fg,bg) ≥ 阈值` 时**第一步就 return 前景本身**，历史上素白主题
    // `contrast(#FB923C, #3F3F46) = 4.614 ≥ 3.0` → 橘底画橘 `+`，图标整个消失。
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: colors.fabBg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: colors.shadowAccent,
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Material(
        color: const Color(0x00000000),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Center(
            child: PlainIcon(
              PlainIconData.navAdd,
              size: 22,
              color: colors.fabIc,
              semanticLabel: s.recordEntry,
            ),
          ),
        ),
      ),
    );
  }
}
