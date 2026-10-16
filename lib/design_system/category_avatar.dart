/// Category / account avatar: Quiet Ledger category icon or local image.
/// New v3 SVG icons get no backing plate (design); legacy refs keep tinted circle.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:plain/design_system/category_icon_v3.dart';

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
            errorBuilder: (_, _, _) => _fallback(),
          ),
        ),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    // v3: stroke icon, no pastel plate.
    return CategoryIcon(iconRef: iconRef, size: size * 1.15, color: color);
  }
}
