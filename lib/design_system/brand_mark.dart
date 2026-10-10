/// 素记品牌标：与「我的」页底部同一只存钱罐小猪（Icons.savings_outlined）。
/// 非位图；颜色跟主题；背景透明。
library;

import 'package:flutter/material.dart';
import 'package:plain/app/theme/app_colors.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({
    super.key,
    this.size = 120,
    this.showLabel = true,
  });

  /// 圆角块边长。
  final double size;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(size * 0.22),
          ),
          child: Icon(
            Icons.savings_outlined,
            size: size * 0.56,
            color: colors.primary,
          ),
        ),
        if (showLabel) ...[
          const SizedBox(height: 12),
          Text(
            '素记',
            style: TextStyle(
              fontSize: size * 0.18,
              fontWeight: FontWeight.w600,
              letterSpacing: 4,
              color: colors.ink,
            ),
          ),
        ],
      ],
    );
  }
}
