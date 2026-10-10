/// Category / account avatar: tinted circle + icon or local image.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:plain/design_system/category_icons.dart';

/// Tinted circle with a category/account icon (or uploaded image).
///
/// [size] is the icon size; the circle radius matches the established
/// call-site convention (radius == icon size).
class CategoryAvatar extends StatelessWidget {
  const CategoryAvatar({
    super.key,
    required this.iconRef,
    required this.color,
    this.iconAsset,
    this.size = 20,
  });

  final String iconRef;
  final Color color;

  /// 本地上传图标的文件路径（F1.2）；优先于 [iconRef]。
  final String? iconAsset;
  final double size;

  @override
  Widget build(BuildContext context) {
    final img = iconAsset;
    if (img != null && img.isNotEmpty && File(img).existsSync()) {
      return CircleAvatar(
        radius: size,
        backgroundColor: color.withValues(alpha: 0.1),
        child: ClipOval(
          child: Image.file(
            File(img),
            width: size * 1.6,
            height: size * 1.6,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) =>
                Icon(iconForCategory(iconRef), size: size, color: color),
          ),
        ),
      );
    }
    return CircleAvatar(
      radius: size,
      backgroundColor: color.withValues(alpha: 0.1),
      child: Icon(iconForCategory(iconRef), size: size, color: color),
    );
  }
}
