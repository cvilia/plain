/// Full category picker page. See PRD STORY-1.1 (More grid).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plain/app/bootstrap.dart';
import 'package:plain/app/theme/design_tokens.dart';
import 'package:plain/core/refresh/data_invalidation.dart';
import 'package:plain/design_system/category_icons.dart';
import 'package:plain/domain/entities/category.dart' as domain;
import 'package:plain/domain/entities/enums.dart';

final _allCategoriesProvider = FutureProvider<List<domain.Category>>((ref) async {
  ref.watch(categoriesVersionProvider);
  final repo = ref.watch(categoryRepositoryProvider);
  final result = await repo.listVisible();
  return result.successOrNull ?? const [];
});

class CategoryPickerPage extends ConsumerStatefulWidget {
  const CategoryPickerPage({super.key, this.kind = CategoryKind.expense});
  final CategoryKind kind;

  @override
  ConsumerState<CategoryPickerPage> createState() => _CategoryPickerPageState();
}

class _CategoryPickerPageState extends ConsumerState<CategoryPickerPage> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(_allCategoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('选择分类'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Spacing.lg, 0, Spacing.lg, Spacing.sm),
            child: TextField(
              decoration: InputDecoration(
                hintText: '搜索分类...',
                prefixIcon: const Icon(Icons.search, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Radii.pill),
                  borderSide: BorderSide(color: BrandColors.border),
                ),
                filled: true,
                fillColor: BrandColors.surfaceMuted,
                contentPadding: const EdgeInsets.symmetric(horizontal: Spacing.md),
              ),
              onChanged: (v) => setState(() => _searchQuery = v.trim()),
            ),
          ),
        ),
      ),
      body: categoriesAsync.when(
        data: (categories) {
          var filtered = categories.where((c) => c.kind == widget.kind).toList();
          if (_searchQuery.isNotEmpty) {
            filtered = filtered.where((c) => c.name.contains(_searchQuery)).toList();
          }

          if (filtered.isEmpty) {
            return Center(
              child: Text(
                _searchQuery.isEmpty ? '暂无分类' : '未找到匹配分类',
                style: TextStyle(color: BrandColors.inkTertiary),
              ),
            );
          }

          final roots = filtered.where((c) => c.isRoot).toList();
          final children = filtered.where((c) => !c.isRoot).toList();

          return ListView(
            padding: const EdgeInsets.all(Spacing.md),
            children: [
              ...roots.map((root) {
                final rootChildren = children.where((c) => c.parentId == root.id).toList();
                return _ExpandableCategoryGroup(
                  root: root,
                  children: rootChildren,
                  onSelected: (cat) => Navigator.pop(context, cat.id),
                );
              }),
              ...children
                  .where((c) => !roots.any((r) => r.id == c.parentId))
                  .map((c) => _CategoryTile(
                        category: c,
                        onTap: () => Navigator.pop(context, c.id),
                      )),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
      ),
    );
  }
}

class _ExpandableCategoryGroup extends StatefulWidget {
  const _ExpandableCategoryGroup({
    required this.root,
    required this.children,
    required this.onSelected,
  });

  final domain.Category root;
  final List<domain.Category> children;
  final void Function(domain.Category) onSelected;

  @override
  State<_ExpandableCategoryGroup> createState() => _ExpandableCategoryGroupState();
}

class _ExpandableCategoryGroupState extends State<_ExpandableCategoryGroup> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final hasChildren = widget.children.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CategoryTile(
          category: widget.root,
          trailing: hasChildren
              ? GestureDetector(
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: AnimatedRotation(
                    turns: _expanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.chevron_right, size: 20, color: BrandColors.inkTertiary),
                  ),
                )
              : null,
          onTap: () {
            if (hasChildren && !_expanded) {
              setState(() => _expanded = true);
            } else {
              widget.onSelected(widget.root);
            }
          },
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(left: Spacing.xl),
            child: Column(
              children: widget.children
                  .map((c) => _CategoryTile(category: c, onTap: () => widget.onSelected(c)))
                  .toList(),
            ),
          ),
          crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
        const SizedBox(height: Spacing.xs),
      ],
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category, required this.onTap, this.trailing});
  final domain.Category category;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final isExpense = category.kind == CategoryKind.expense;
    final color = isExpense ? BrandColors.expense : BrandColors.income;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: color.withValues(alpha: 0.1),
        child: Icon(iconForCategory(category.iconRef), size: 18, color: color),
      ),
      title: Text(
        category.name,
        style: TextStyle(
          fontSize: 15,
          fontWeight: category.isRoot ? FontWeight.w500 : FontWeight.w400,
        ),
      ),
      trailing: trailing,
      onTap: onTap,
    );
  }
}
