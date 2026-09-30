/// Screen adaptation: L1 breakpoint layer. See 07-屏幕适配方案 §3, §4.
///
/// Breakpoint constants live ONLY here. Any literal 600/840/1200 elsewhere
/// is a defect. Use [responsiveValue] for discrete tiers, never for scaling.
library;

import 'package:flutter/widgets.dart';

/// Material 3 window size classes + height class.
enum SizeClass {
  /// Width < 600dp: phone portrait (320–430).
  compact,

  /// Width 600–839dp: phone landscape, small tablet portrait, split-screen narrow.
  medium,

  /// Width 840–1199dp: iPad portrait, mainstream tablet landscape.
  expanded,

  /// Width ≥ 1200dp: large tablet landscape.
  large,
}

/// Breakpoint constants (single source of truth).
class Breakpoints {
  Breakpoints._();

  /// compact | medium boundary.
  static const double compactMax = 600;

  /// medium | expanded boundary.
  static const double mediumMax = 840;

  /// expanded | large boundary.
  static const double expandedMax = 1200;

  /// Compact height threshold: < 480dp is landscape phone (vertical space scarce).
  static const double compactHeight = 480;

  /// Content max width for reading comfort (centered on wide screens).
  static const double contentMaxWidth = 840;

  /// FormB (landscape/tablet) width threshold for entry input page.
  static const double formBWidth = 600;

  /// FormB height threshold.
  static const double formBHeight = 480;

  /// Get size class from width.
  static SizeClass sizeClassFromWidth(double width) {
    if (width < compactMax) return SizeClass.compact;
    if (width < mediumMax) return SizeClass.medium;
    if (width < expandedMax) return SizeClass.expanded;
    return SizeClass.large;
  }

  /// Get size class from container constraints (for LayoutBuilder).
  static SizeClass sizeClassFromConstraints(BoxConstraints constraints) {
    return sizeClassFromWidth(constraints.maxWidth);
  }

  /// Check if height is compact (landscape phone).
  static bool isCompactHeight(double height) => height < compactHeight;

  /// Entry input FormB trigger: height < 480 OR width >= 600. See §6.1.
  static bool isFormB(double width, double height) {
    return height < compactHeight || width >= formBWidth;
  }
}

/// Get size class from build context (uses local constraints via LayoutBuilder).
/// NOTE: Do NOT use MediaQuery.size in feature code — use this instead.
SizeClass sizeClassOf(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  return Breakpoints.sizeClassFromWidth(width);
}

/// Responsive discrete value selection (window-level).
///
/// ONLY for discrete values (column counts, padding tiers, visibility flags).
/// NEVER for continuous derivation — that would be scaling in disguise.
T responsiveValue<T>(
  BuildContext context, {
  required T compact,
  T? medium,
  T? expanded,
  T? large,
}) {
  return switch (sizeClassOf(context)) {
    SizeClass.compact => compact,
    SizeClass.medium => medium ?? compact,
    SizeClass.expanded => expanded ?? medium ?? compact,
    SizeClass.large => large ?? expanded ?? medium ?? compact,
  };
}

/// Responsive discrete value selection (container-level).
/// Use inside LayoutBuilder. See §3.3.
T responsiveValueOf<T>(
  BoxConstraints constraints, {
  required T compact,
  T? medium,
  T? expanded,
  T? large,
}) {
  return switch (Breakpoints.sizeClassFromConstraints(constraints)) {
    SizeClass.compact => compact,
    SizeClass.medium => medium ?? compact,
    SizeClass.expanded => expanded ?? medium ?? compact,
    SizeClass.large => large ?? expanded ?? medium ?? compact,
  };
}

/// Content max width constraint widget: centers content on wide screens,
/// prevents reading lines from stretching to 1300dp on tablets.
/// See 07 §4 L3 rule 3.
class ContentWidthConstraint extends StatelessWidget {
  const ContentWidthConstraint({super.key, required this.child, this.maxWidth});

  final Widget child;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth ?? Breakpoints.contentMaxWidth),
        child: child,
      ),
    );
  }
}

/// Discrete font size tiers (no continuous scaling).
/// See 07 §4 L4.
class AdaptiveFontSizes {
  AdaptiveFontSizes._();

  /// Display (entry input amount): compact 48 / medium 56 / expanded 64.
  static double display(BuildContext context) =>
      responsiveValue(context, compact: 48, medium: 56, expanded: 64);

  /// Body: fixed 15, never changes across breakpoints.
  static const double body = 15;

  /// Title: fixed 17.
  static const double title = 17;

  /// Caption: fixed 12.
  static const double caption = 12;
}

/// Discrete padding tiers from Design Token.
/// See 07 §4 L4.
class AdaptivePaddings {
  AdaptivePaddings._();

  /// Page horizontal padding: 16 / 24 / 32.
  static double pageHorizontal(BuildContext context) =>
      responsiveValue(context, compact: 16, medium: 24, expanded: 32);

  /// Card internal padding: 12 / 16 / 20.
  static double card(BuildContext context) =>
      responsiveValue(context, compact: 12, medium: 16, expanded: 20);
}
