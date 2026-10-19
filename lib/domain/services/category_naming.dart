/// Category title uniqueness helpers for add / rename flows.
library;

import 'package:plain/app/l10n/app_strings.dart';
import 'package:plain/domain/entities/category.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/app/l10n/strings_domain.dart';

/// Human-readable conflict message for [name], or `null` when unique.
///
/// Scope is [kind] (expense vs income are independent namespaces).
///
/// * First-level (`parentId == null`): collides with another root →
///   「已有同名一级分类」.
/// * Second-level: collides with a leaf under some other parent →
///   「「父名」下已有同名分类」; or collides with a root title →
///   「与一级分类「X」同名」.
String? categoryTitleConflictMessage({
  required AppStrings s,
  required List<Category> all,
  required String name,
  required String? parentId,
  required CategoryKind kind,
  String? ignoreId,
}) {
  final n = name.trim();
  if (n.isEmpty) return null;

  Category? findParent(String? pid) {
    if (pid == null) return null;
    for (final c in all) {
      if (c.id == pid) return c;
    }
    return null;
  }

  if (parentId == null) {
    for (final c in all) {
      if (c.isDeleted || c.id == ignoreId) continue;
      if (c.kind != kind) continue;
      if (c.isRoot && c.name == n) return s.catRootDuplicate;
    }
    return null;
  }

  for (final c in all) {
    if (c.isDeleted || c.id == ignoreId) continue;
    if (c.kind != kind) continue;
    if (!c.isRoot && c.name == n) {
      final parentName = findParent(c.parentId)?.name ?? s.ungrouped;
      return s.catSubDuplicate(parentName);
    }
  }
  for (final c in all) {
    if (c.isDeleted || c.id == ignoreId) continue;
    if (c.kind != kind) continue;
    if (c.isRoot && c.name == n) return s.catRootNameDuplicate(n);
  }
  return null;
}

/// Default catch-all first-level categories (记录兜底).
///
/// ⚠️ 这两个兜底一级**永远可以直接记账**（即使被加了子分类）。
///
/// 一级分类能否直接选中的完整口径（2026-10-16）：
/// · 有子分类的一级 → 只作分组，记账时选二级；
/// · **没有子分类的一级 → 自己就是最小可选单位，可以直接选**
///   （否则它在界面上是死胡同：点不动、底下也没得选）；
/// · 兜底「其他」→ 恒可选。
///
/// 判据与 `CategoryListX.leaves`（宫格/预算选择器的口径）一致：
/// 「没有子项的分类 = 叶子 = 可选」。
bool isDefaultOtherCategory(Category c) {
  return c.isRoot && (c.id == 'preset_other' || c.id == 'preset_income_other');
}
