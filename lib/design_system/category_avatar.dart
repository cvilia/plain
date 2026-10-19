/// Category / account avatar: Quiet Ledger category icon.
/// New v3 SVG icons get no backing plate (design); legacy refs keep tinted circle.
///
/// 2026-10-19：本地上传自定义图标（原 F1.2）已下线 —— 内置图标库已扩到
/// 100 枚，不再需要用户自己传图。这里只保留描边图标一条路。
library;

import 'package:flutter/material.dart';
import 'package:plain/design_system/category_icon_v3.dart';

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
    // v3: stroke icon, no pastel plate.
    return CategoryIcon(iconRef: iconRef, size: size * 1.15, color: color);
  }
}
