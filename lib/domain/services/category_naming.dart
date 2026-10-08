/// Category title uniqueness helpers for add / rename flows.
library;

import 'package:plain/domain/entities/category.dart';
import 'package:plain/domain/entities/enums.dart';

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
      if (c.isRoot && c.name == n) return '已有同名一级分类';
    }
    return null;
  }

  for (final c in all) {
    if (c.isDeleted || c.id == ignoreId) continue;
    if (c.kind != kind) continue;
    if (!c.isRoot && c.name == n) {
      final parentName = findParent(c.parentId)?.name ?? '未分组';
      return '「$parentName」下已有同名分类';
    }
  }
  for (final c in all) {
    if (c.isDeleted || c.id == ignoreId) continue;
    if (c.kind != kind) continue;
    if (c.isRoot && c.name == n) return '与一级分类「$n」同名';
  }
  return null;
}

/// Default catch-all first-level categories (记录兜底).
///
/// These roots are the only first-level entries that may be selected for
/// accounting — everything else must be a second-level leaf.
bool isDefaultOtherCategory(Category c) {
  return c.isRoot && (c.id == 'preset_other' || c.id == 'preset_income_other');
}
