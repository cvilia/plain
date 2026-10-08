/// Category / account avatar: tinted circle + icon.
library;

import 'package:flutter/material.dart';
import 'package:plain/design_system/category_icons.dart';

/// Tinted circle with a category/account icon.
///
/// [size] is the icon size; the circle radius matches the established
/// call-site convention (radius == icon size).
class CategoryAvatar extends StatelessWidget {
  const CategoryAvatar({
    super.key,
    required this.iconRef,
    required this.color,
    this.size = 20,
  });

  final String iconRef;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: size,
      backgroundColor: color.withValues(alpha: 0.1),
      child: Icon(iconForCategory(iconRef), size: size, color: color),
    );
  }
}
