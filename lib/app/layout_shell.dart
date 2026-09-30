/// L2 layout shell. See 07-屏幕适配方案 §4 L2.
///
/// "Write once, place anywhere": pages declare content, shell decides layout.
/// compact: bottom NavigationBar + single column
/// medium: collapsed NavigationRail + single column
/// expanded/large: expanded NavigationRail + two columns
library;

import 'package:flutter/material.dart';
import 'package:plain/app/breakpoints.dart';
import 'package:plain/app/theme/design_tokens.dart';

/// Adaptive app shell with responsive navigation + content layout.
class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.currentIndex,
    required this.onNavigationChanged,
    required this.body,
    this.secondaryBody,
    this.floatingActionButton,
    this.appBar,
  });

  /// Current tab index (0–4).
  final int currentIndex;
  final ValueChanged<int> onNavigationChanged;

  /// Main content slot.
  final Widget body;

  /// Optional secondary content (detail pane on expanded+).
  final Widget? secondaryBody;

  final Widget? floatingActionButton;
  final PreferredSizeWidget? appBar;

  static const _destinations = [
    (Icons.receipt_long_outlined, Icons.receipt_long, '流水'),
    (Icons.pie_chart_outline, Icons.pie_chart, '报表'),
    (Icons.account_balance_wallet_outlined, Icons.account_balance_wallet, '资产'),
    (Icons.settings_outlined, Icons.settings, '我的'),
  ];

  @override
  Widget build(BuildContext context) {
    final sizeClass = sizeClassOf(context);

    return switch (sizeClass) {
      SizeClass.compact => _buildCompact(context),
      SizeClass.medium || SizeClass.expanded || SizeClass.large =>
        _buildMediumPlus(context, sizeClass),
    };
  }

  /// compact: bottom NavigationBar, single column.
  Widget _buildCompact(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: onNavigationChanged,
        destinations: [
          for (final d in _destinations)
            NavigationDestination(icon: Icon(d.$1), selectedIcon: Icon(d.$2), label: d.$3),
        ],
      ),
      floatingActionButton: floatingActionButton,
    );
  }

  /// medium+: NavigationRail, optional two-column.
  Widget _buildMediumPlus(BuildContext context, SizeClass sizeClass) {
    final isExpanded = sizeClass == SizeClass.expanded || sizeClass == SizeClass.large;
    final showLabels = sizeClass == SizeClass.large;

    final content = secondaryBody != null
        ? Row(children: [
            Expanded(child: body),
            const VerticalDivider(width: 1),
            Expanded(child: secondaryBody!),
          ])
        : body;

    return Scaffold(
      appBar: appBar,
      body: Row(children: [
        NavigationRail(
          selectedIndex: currentIndex,
          onDestinationSelected: onNavigationChanged,
          extended: isExpanded && showLabels,
          labelType: isExpanded && !showLabels
              ? NavigationRailLabelType.all
              : showLabels
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.none,
          destinations: [
            for (final d in _destinations)
              NavigationRailDestination(icon: Icon(d.$1), selectedIcon: Icon(d.$2), label: Text(d.$3)),
          ],
        ),
        const VerticalDivider(width: 1),
        Expanded(child: content),
      ]),
      floatingActionButton: floatingActionButton,
    );
  }
}

/// Responsive page scaffold: handles content width constraint + safe area.
/// Pages should use this instead of bare Scaffold.
class ResponsiveScaffold extends StatelessWidget {
  const ResponsiveScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.floatingActionButton,
    this.constrainWidth = true,
    this.padding,
  });

  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;

  /// Whether to constrain content width on wide screens.
  final bool constrainWidth;

  /// Page-level padding (discrete tier applied if null).
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final pagePadding = padding ??
        EdgeInsets.symmetric(
          horizontal: AdaptivePaddings.pageHorizontal(context),
          vertical: Spacing.md,
        );

    final content = Padding(padding: pagePadding, child: body);

    return Scaffold(
      appBar: appBar,
      body: constrainWidth ? ContentWidthConstraint(child: content) : content,
      floatingActionButton: floatingActionButton,
    );
  }
}
