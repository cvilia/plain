/// Full category picker page. See PRD STORY-1.1 (More grid).
library;

import 'package:plain/app/theme/app_colors.dart';
import 'package:plain/design_system/category_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plain/app/bootstrap.dart';
import 'package:plain/app/theme/design_tokens.dart';
import 'package:plain/core/refresh/data_invalidation.dart';
import 'package:plain/design_system/app_toast.dart';
import 'package:plain/domain/entities/category.dart' as domain;
import 'package:plain/domain/services/category_naming.dart';
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
                  borderSide: BorderSide(color: context.colors.border),
                ),
                filled: true,
                fillColor: context.colors.surfaceMuted,
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
            final q = _searchQuery.toLowerCase();
            // Match first- and second-level titles; when a root hits, keep its
            // children so they can be shown expanded under it.
            filtered = filtered.where((c) {
              if (c.name.toLowerCase().contains(q)) return true;
              if (c.parentId != null) {
                final parent = categories.where((p) => p.id == c.parentId).firstOrNull;
                return parent != null && parent.name.toLowerCase().contains(q);
              }
              return false;
            }).toList();
          }

          if (filtered.isEmpty) {
            return Center(
              child: Text(
                _searchQuery.isEmpty ? '暂无分类' : '未找到匹配分类',
                style: TextStyle(color: context.colors.inkTertiary),
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
                  searching: _searchQuery.isNotEmpty,
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
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_category_picker_add',
        icon: const Icon(Icons.add),
        label: const Text('新增'),
        backgroundColor: context.colors.primary,
        foregroundColor: context.colors.onPrimary,
        onPressed: () => _showAddLeafSheet(context, ref),
      ),
    );
  }

  /// Add a second-level category from the picker, then select it.
  Future<void> _showAddLeafSheet(BuildContext context, WidgetRef ref) async {
    final categories = ref.read(_allCategoriesProvider).value ?? const <domain.Category>[];
    final roots = categories
        .where((c) => !c.isDeleted && c.isRoot && c.kind == widget.kind)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    if (roots.isEmpty) {
      showAppToast(context, '请先在分类管理中新建一级分类');
      return;
    }
    domain.Category? parent = roots.first;
    final nameCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    final created = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: Spacing.lg,
            right: Spacing.lg,
            top: Spacing.lg,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + Spacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('新增分类条目', style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: Spacing.lg),
              DropdownButtonFormField<domain.Category>(
                initialValue: parent,
                decoration: const InputDecoration(
                  labelText: '归属一级分类',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final r in roots)
                    DropdownMenuItem(value: r, child: Text(r.name)),
                ],
                onChanged: (v) => setSheetState(() => parent = v),
              ),
              const SizedBox(height: Spacing.md),
              TextField(
                controller: nameCtrl,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: '名称',
                  hintText: '如：咖啡',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: Spacing.md),
              TextField(
                controller: noteCtrl,
                maxLength: 30,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: '备注（可选）',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: Spacing.lg),
              FilledButton(
                onPressed: () {
                  final p = parent;
                  if (p == null) return;
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) return;
                  final conflict = categoryTitleConflictMessage(
                    all: categories,
                    name: name,
                    parentId: p.id,
                    kind: p.kind,
                  );
                  if (conflict != null) {
                    showAppToast(context, conflict);
                    return;
                  }
                  final deps = ref.read(appDependenciesProvider);
                  final now = DateTime.now().toUtc();
                  final id = 'cat_${now.microsecondsSinceEpoch}';
                  final note = noteCtrl.text.trim();
                  deps.categoryRepository.create(domain.Category(
                    id: id,
                    parentId: p.id,
                    name: name,
                    kind: p.kind,
                    iconRef: p.iconRef,
                    note: note.isEmpty ? null : note,
                    sortOrder: 999,
                    createdAt: now,
                    updatedAt: now,
                    deviceId: deps.deviceId,
                  ));
                  ref.invalidateData.bumpCategoriesMutated();
                  Navigator.pop(ctx, id);
                },
                child: const Text('添加并选用'),
              ),
            ],
          ),
        ),
      ),
    );
    if (created != null && context.mounted) {
      Navigator.pop(context, created);
    }
  }
}

class _ExpandableCategoryGroup extends StatefulWidget {
  const _ExpandableCategoryGroup({
    required this.root,
    required this.children,
    required this.onSelected,
    this.searching = false,
  });

  final domain.Category root;
  final List<domain.Category> children;
  final void Function(domain.Category) onSelected;

  /// When true, children stay open so search hits are visible.
  final bool searching;

  @override
  State<_ExpandableCategoryGroup> createState() => _ExpandableCategoryGroupState();
}

class _ExpandableCategoryGroupState extends State<_ExpandableCategoryGroup> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final hasChildren = widget.children.isNotEmpty;
    final expanded = _expanded || widget.searching;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CategoryTile(
          category: widget.root,
          trailing: hasChildren
              ? GestureDetector(
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: AnimatedRotation(
                    turns: expanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.chevron_right, size: 20, color: context.colors.inkTertiary),
                  ),
                )
              : null,
          onTap: () {
            // Default 其他 is a first-level catch-all and IS selectable for
            // accounting; every other first-level group only expands.
            if (isDefaultOtherCategory(widget.root)) {
              widget.onSelected(widget.root);
              return;
            }
            setState(() => _expanded = !_expanded);
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
          crossFadeState: expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
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
    final color = isExpense ? context.colors.expense : context.colors.income;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
      leading: CategoryAvatar(iconRef: category.iconRef, iconAsset: category.iconAsset, color: color, size: 18),
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
