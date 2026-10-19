/// 分类图标选择器 —— 全 App 唯一实现。
///
/// 分类管理页（新建一级分类 / 编辑分类信息）与选择分类页（新建一级分类）
/// 共用同一套。图标清单、按图标去重的选中判定两件事只留一处真值。
///
/// 2026-10-19：**移除了「上传自定义图标」**（原 F1.2）。内置 `ic_cat_*`
/// 已扩到 100 枚，覆盖餐饮/购物/日用/交通/居住/通讯/娱乐/医疗/学习/人情/财务
/// 全部场景，用户不再需要自己传图 —— 传图带来的代价（本地文件体积、备份包
/// 膨胀、还原时的孤儿文件）远大于它解决的问题。
library;

import 'package:flutter/material.dart';
import 'package:plain/app/theme/app_colors.dart';
import 'package:plain/app/theme/design_tokens.dart';
import 'package:plain/design_system/category_icon_v3.dart';
import 'package:plain/design_system/category_icons.dart';
import 'package:plain/design_system/plain_icons_v3.dart';

/// 选择器展示的 ref 清单。
///
/// `kAllCategoryIconRefs` 是近 300 个**语义 ref**，而 v3 图标是 31 枚
/// （30 个支出一级 + 收入「红包」），ref → 图标是**多对一**映射。若直接遍历
/// ref 列表，同一枚图标会在网格里重复出现几十次（曾出现一整排相同的碗）。
/// 这里按解析后的图标去重，每枚图标取第一个出现的 ref 作为代表。
final List<String> kPickerCategoryIconRefs = () {
  final seen = <String>{};
  final out = <String>[];
  for (final r in kAllCategoryIconRefs) {
    final icon = plainIconForRef(r);
    if (icon == null) continue;
    if (seen.add(icon.name)) out.add(r);
  }
  return List<String>.unmodifiable(out);
}();

/// 分类图标选择器：内置图标网格。
///
/// **受控组件**：图标 ref 由父级（表单）持有 —— 提交时要读。
class CategoryIconPicker extends StatelessWidget {
  const CategoryIconPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  /// 当前内置图标 ref。
  final String value;

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    const crossAxisCount = 8;
    const spacing = 8.0;

    // 限高 5 行（2026-10-19 爸爸反馈）：100 枚图标全展开会把表单拉得极长，
    // 改成固定 5 行高、网格内部自行滚动。行高按实际宽度算（393pt 下约 38pt），
    // 平板等宽屏自动变大，不写死像素。
    return LayoutBuilder(
      builder: (context, constraints) {
        final cell =
            (constraints.maxWidth - spacing * (crossAxisCount - 1)) /
                crossAxisCount;
        final height = cell * 5 + spacing * 4 + Spacing.sm * 2;
        return SizedBox(
          height: height,
          child: GridView.builder(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              // 8 列在 393pt 宽下每格约 41pt，图标 20 仍有足够留白。
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: spacing,
              crossAxisSpacing: spacing,
              childAspectRatio: 1,
            ),
            itemCount: kPickerCategoryIconRefs.length,
            itemBuilder: (context, i) {
              final r = kPickerCategoryIconRefs[i];
              final icon = plainIconForRef(r)!;
              // 按「图标」而非 ref 判选中：多个 ref 解析到同一枚图标时仍能高亮。
              final selected = plainIconForRef(value)?.name == icon.name;
              return InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => onChanged(r),
                child: Container(
                  // 必须居中：否则子级收到 tight 约束被拉伸到整格，
                  // 图标放大约 2 倍、描边等比变粗。
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected
                        ? context.colors.primary.withValues(alpha: 0.15)
                        : context.colors.surfaceMuted,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color:
                          selected ? context.colors.primary : context.colors.divider,
                    ),
                  ),
                  child: PlainIcon(
                    icon,
                    size: 20,
                    color: context.colors.primary,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
