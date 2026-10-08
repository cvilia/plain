/// Category management page. See PRD STORY-1.3.
library;

import 'package:plain/app/theme/app_colors.dart';
import 'package:plain/design_system/category_avatar.dart';
import 'package:flutter/material.dart';
import 'package:plain/design_system/app_toast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plain/app/bootstrap.dart';
import 'package:plain/app/theme/design_tokens.dart';
import 'package:plain/core/refresh/data_invalidation.dart';
import 'package:plain/design_system/category_icons.dart';
import 'package:plain/domain/entities/category.dart' as domain;
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/services/category_naming.dart';

final _categoriesProvider = FutureProvider<List<domain.Category>>((ref) async {
  ref.watch(categoriesVersionProvider);
  final repo = ref.watch(categoryRepositoryProvider);
  final result = await repo.listAll();
  return result.successOrNull ?? const [];
});

class CategoryManagePage extends ConsumerStatefulWidget {
  const CategoryManagePage({super.key});

  @override
  ConsumerState<CategoryManagePage> createState() => _CategoryManagePageState();
}

class _CategoryManagePageState extends ConsumerState<CategoryManagePage> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Fuzzy title match across first-level and second-level (incl. custom) names.
  ///
  /// Substring, case-insensitive. A child is also kept when its parent name
  /// matches so users can jump in from either level.
  bool _matches(domain.Category c, List<domain.Category> all, String q) {
    if (q.isEmpty) return true;
    final needle = q.toLowerCase();
    if (c.name.toLowerCase().contains(needle)) return true;
    // Second-level: allow hit via parent title.
    if (c.parentId != null) {
      final parent = all.where((p) => p.id == c.parentId).firstOrNull;
      if (parent != null && parent.name.toLowerCase().contains(needle)) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(_categoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('分类管理')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.sm, Spacing.lg, Spacing.xs),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v.trim()),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: '搜索分类名称',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.colors.border),
                ),
              ),
            ),
          ),
          Expanded(
            child: categoriesAsync.when(
              data: (categories) {
                final visible = categories
                    .where((c) => !c.isDeleted && _matches(c, categories, _query))
                    .toList();

                if (_query.isNotEmpty && visible.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(Spacing.xl),
                      child: Text(
                        '没有匹配「$_query」的分类',
                        style: TextStyle(color: context.colors.inkTertiary),
                      ),
                    ),
                  );
                }

                return ListView(
                  padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.sm, Spacing.lg, Spacing.xl),
                  children: [
                    ..._buildTree(context, ref, categories, visible, CategoryKind.expense, '支出'),
                    ..._buildTree(context, ref, categories, visible, CategoryKind.income, '收入'),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('加载失败: $e')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_category_add',
        onPressed: () => _showAddSheet(context, ref),
        backgroundColor: context.colors.primary,
        foregroundColor: context.colors.onPrimary,
        child: const Icon(Icons.add),
      ),
    );
  }

  String? _parentNameOf(List<domain.Category> all, domain.Category c) {
    if (c.parentId == null) return null;
    return all.where((p) => p.id == c.parentId).firstOrNull?.name;
  }

  void _toggleHide(WidgetRef ref, domain.Category cat) {
    final deps = ref.read(appDependenciesProvider);
    final updated = cat.copyWith(isHidden: !cat.isHidden, updatedAt: DateTime.now().toUtc());
    deps.categoryRepository.update(updated);
    ref.invalidateData.bumpCategoriesMutated();
  }

  void _showRenameSheet(BuildContext context, WidgetRef ref, domain.Category cat) {
    // Default (preset) taxonomy is read-only.
    if (cat.isPreset) {
      showAppToast(context, '默认分类不可修改');
      return;
    }
    final nameCtrl = TextEditingController(text: cat.name);
    final noteCtrl = TextEditingController(text: cat.note ?? '');
    var iconRef = cat.iconRef;
    showModalBottomSheet<void>(
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
              Text('编辑分类信息', style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: Spacing.lg),
              TextField(
                controller: nameCtrl,
                maxLength: 6,
                decoration: const InputDecoration(labelText: '名称', border: OutlineInputBorder()),
              ),
              const SizedBox(height: Spacing.md),
              _IconPicker(
                value: iconRef,
                onChanged: (v) => setSheetState(() => iconRef = v),
              ),
              const SizedBox(height: Spacing.md),
              TextField(
                controller: noteCtrl,
                maxLength: 30,
                maxLines: 2,
                inputFormatters: const [], // maxLength truncates silently
                decoration: const InputDecoration(
                  labelText: '备注',
                  hintText: '界定分类边界，最多 30 字',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: Spacing.lg),
              FilledButton(
                onPressed: () {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) return;
                  final noteText = noteCtrl.text.trim();
                  final deps = ref.read(appDependenciesProvider);
                  final updated = cat
                      .withNote(noteText.isEmpty ? null : noteText)
                      .copyWith(
                        name: name,
                        iconRef: iconRef,
                        updatedAt: DateTime.now().toUtc(),
                        revision: cat.revision + 1,
                        baseRevision: cat.revision,
                      );
                  deps.categoryRepository.update(updated);
                  ref.invalidateData.bumpCategoriesMutated();
                  Navigator.pop(ctx);
                },
                child: const Text('保存'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(Spacing.lg),
              child: Text('添加分类', style: Theme.of(ctx).textTheme.titleMedium),
            ),
            ListTile(
              leading: const Icon(Icons.subdirectory_arrow_right),
              title: const Text('添加到分类下'),
              subtitle: const Text('在已有的一级分类下新增二级条目'),
              onTap: () {
                Navigator.pop(ctx);
                _showAddLeafSheet(context, ref);
              },
            ),
            ListTile(
              leading: const Icon(Icons.create_new_folder_outlined),
              title: const Text('新建一级分类'),
              subtitle: const Text('需同时录入至少一个二级条目'),
              onTap: () {
                Navigator.pop(ctx);
                _showAddRootSheet(context, ref);
              },
            ),
            const SizedBox(height: Spacing.sm),
          ],
        ),
      ),
    );
  }

  /// Create a second-level (leaf) under a chosen first-level parent.
  void _showAddLeafSheet(BuildContext context, WidgetRef ref) {
    final categories = ref.read(_categoriesProvider).value ?? const <domain.Category>[];
    final roots = categories
        .where((c) => !c.isDeleted && c.isRoot)
        .toList()
      ..sort((a, b) => a.kind.index.compareTo(b.kind.index) != 0
          ? a.kind.index.compareTo(b.kind.index)
          : a.sortOrder.compareTo(b.sortOrder));
    if (roots.isEmpty) {
      showAppToast(context, '请先新建一级分类');
      return;
    }
    domain.Category? parent = roots.first;
    final nameCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    showModalBottomSheet<void>(
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
              Text('添加二级分类', style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: Spacing.lg),
              DropdownButtonFormField<domain.Category>(
                initialValue: parent,
                decoration: const InputDecoration(
                  labelText: '归属一级分类',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final r in roots)
                    DropdownMenuItem(value: r, child: Text(_rootLabel(r))),
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
                  labelText: '备注',
                  hintText: '界定分类边界，最多 30 字',
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
                  _createCategory(
                    context,
                    ref,
                    name: name,
                    note: noteCtrl.text.trim(),
                    kind: p.kind,
                    parentId: p.id,
                  );
                  Navigator.pop(ctx);
                },
                child: const Text('添加'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Create a new first-level group plus its first second-level leaf.
  void _showAddRootSheet(BuildContext context, WidgetRef ref) {
    var kind = CategoryKind.expense;
    final rootNameCtrl = TextEditingController();
    final rootNoteCtrl = TextEditingController();
    final leafNameCtrl = TextEditingController();
    final leafNoteCtrl = TextEditingController();
    var iconRef = 'other';

    showModalBottomSheet<void>(
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
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('新建一级分类', style: Theme.of(ctx).textTheme.titleMedium),
                const SizedBox(height: Spacing.sm),
                Text(
                  '一级分类仅作分组，记账时请选择二级条目',
                  style: TextStyle(fontSize: 12, color: context.colors.inkTertiary),
                ),
                const SizedBox(height: Spacing.lg),
                RadioGroup<CategoryKind>(
                  groupValue: kind,
                  onChanged: (v) => setSheetState(() => kind = v!),
                  child: Row(
                    children: [
                      Expanded(child: RadioListTile<CategoryKind>(title: const Text('支出'), value: CategoryKind.expense)),
                      Expanded(child: RadioListTile<CategoryKind>(title: const Text('收入'), value: CategoryKind.income)),
                    ],
                  ),
                ),
                const SizedBox(height: Spacing.md),
                TextField(
                  controller: rootNameCtrl,
                  maxLength: 6,
                  decoration: const InputDecoration(
                    labelText: '一级分类名称',
                    hintText: '如：宠物',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: Spacing.md),
                TextField(
                  controller: rootNoteCtrl,
                  maxLength: 30,
                  decoration: const InputDecoration(
                    labelText: '一级备注（可选）',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: Spacing.md),
                _IconPicker(
                  value: iconRef,
                  onChanged: (v) => setSheetState(() => iconRef = v),
                ),
                const SizedBox(height: Spacing.lg),
                Text('首个二级条目', style: Theme.of(ctx).textTheme.titleSmall),
                const SizedBox(height: Spacing.sm),
                TextField(
                  controller: leafNameCtrl,
                  maxLength: 6,
                  decoration: const InputDecoration(
                    labelText: '二级名称（必填）',
                    hintText: '如：猫粮',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: Spacing.md),
                TextField(
                  controller: leafNoteCtrl,
                  maxLength: 30,
                  decoration: const InputDecoration(
                    labelText: '二级备注（可选）',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: Spacing.lg),
                FilledButton(
                  onPressed: () {
                    final rootName = rootNameCtrl.text.trim();
                    final leafName = leafNameCtrl.text.trim();
                    if (rootName.isEmpty || leafName.isEmpty) {
                      showAppToast(context, '请填写一级名称和首个二级条目');
                      return;
                    }
                    final all = ref.read(_categoriesProvider).value ?? const <domain.Category>[];
                    final rootConflict = categoryTitleConflictMessage(
                      all: all,
                      name: rootName,
                      parentId: null,
                      kind: kind,
                    );
                    if (rootConflict != null) {
                      showAppToast(context, rootConflict);
                      return;
                    }
                    // Leaf title must also be unique across the same kind.
                    final leafConflict = categoryTitleConflictMessage(
                      all: all,
                      name: leafName,
                      parentId: 'temp',
                      kind: kind,
                    );
                    if (leafConflict != null) {
                      showAppToast(context, leafConflict);
                      return;
                    }
                    final now = DateTime.now().toUtc();
                    final rootId = 'cat_${now.microsecondsSinceEpoch}';
                    _createCategory(
                      context,
                      ref,
                      name: rootName,
                      note: rootNoteCtrl.text.trim(),
                      kind: kind,
                      parentId: null,
                      iconRef: iconRef,
                      id: rootId,
                      now: now,
                    );
                    _createCategory(
                      context,
                      ref,
                      name: leafName,
                      note: leafNoteCtrl.text.trim(),
                      kind: kind,
                      parentId: rootId,
                      now: now.add(const Duration(milliseconds: 1)),
                    );
                    Navigator.pop(ctx);
                  },
                  child: const Text('创建'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Delete a custom category. Live bills are reassigned to the default 其他.
  Future<void> _showDeleteSheet(
    BuildContext context,
    WidgetRef ref,
    domain.Category cat,
  ) async {
    if (cat.isPreset) {
      showAppToast(context, '默认分类不可修改');
      return;
    }
    final deps = ref.read(appDependenciesProvider);
    final categories = ref.read(_categoriesProvider).value ?? const <domain.Category>[];
    final isGroup = cat.isRoot;
    final childIds = isGroup
        ? categories
            .where((c) => !c.isDeleted && c.parentId == cat.id)
            .map((c) => c.id)
            .toList()
        : const <String>[];
    final countRes = await deps.categoryRepository.countLiveEntries(
      categoryId: cat.id,
      includeDescendants: isGroup,
    );
    final count = countRes.successOrNull ?? 0;
    if (!context.mounted) return;

    final fallbackId = cat.kind == CategoryKind.expense
        ? 'preset_other'
        : 'preset_income_other';
    const fallbackName = '其他';

    final title = isGroup ? '删除分类组' : '删除分类';
    final String message;
    if (count > 0) {
      final scope = isGroup && childIds.isNotEmpty
          ? '及其 ${childIds.length} 个下级分类'
          : '';
      message =
          '「${cat.name}」$scope下有 $count 笔账单。\n删除后账单将归入「$fallbackName」分类。';
    } else {
      message = isGroup && childIds.isNotEmpty
          ? '将删除「${cat.name}」及其 ${childIds.length} 个下级分类。'
          : '确定删除「${cat.name}」？';
    }

    final okDel = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: count > 0
                ? FilledButton.styleFrom(backgroundColor: context.colors.expense)
                : null,
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (okDel != true || !context.mounted) return;

    final result = await deps.categoryRepository.deleteAndReassign(
      categoryId: cat.id,
      fallbackCategoryId: fallbackId,
      includeDescendants: isGroup,
    );
    if (!context.mounted) return;
    result.when(
      success: (moved) {
        ref.invalidateData.bumpCategoriesMutated();
        ref.invalidateData.bumpEntryMutated();
        showAppToast(
          context,
          moved > 0
              ? '已删除，$moved 笔账单归入「$fallbackName」'
              : '已删除「${cat.name}」',
        );
      },
      failure: (f) => showAppToast(context, '删除失败: ${f.code}'),
    );
  }

  String _rootLabel(domain.Category r) {
    final kindLabel = r.kind == CategoryKind.expense ? '支出' : '收入';
    return '${r.name} · $kindLabel';
  }

  void _createCategory(
    BuildContext context,
    WidgetRef ref, {
    required String name,
    required String? note,
    required CategoryKind kind,
    required String? parentId,
    String iconRef = 'other',
    String? id,
    DateTime? now,
  }) {
    final deps = ref.read(appDependenciesProvider);
    final ts = now ?? DateTime.now().toUtc();
    deps.categoryRepository.create(domain.Category(
      id: id ?? 'cat_${ts.microsecondsSinceEpoch}',
      parentId: parentId,
      name: name,
      kind: kind,
      iconRef: iconRef,
      note: (note == null || note.isEmpty) ? null : note,
      sortOrder: 999,
      createdAt: ts,
      updatedAt: ts,
      deviceId: deps.deviceId,
    ));
    ref.invalidateData.bumpCategoriesMutated();
    showAppToast(context, '已添加「$name」');
  }

  /// Build one kind section as first-level groups + nested second-level tiles.
  List<Widget> _buildTree(
    BuildContext context,
    WidgetRef ref,
    List<domain.Category> all,
    List<domain.Category> visible,
    CategoryKind kind,
    String sectionLabel,
  ) {
    final kindAll = visible.where((c) => c.kind == kind).toList();
    if (kindAll.isEmpty) return const [];

    final roots = kindAll.where((c) => c.isRoot).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final childrenOf = <String, List<domain.Category>>{};
    for (final c in kindAll.where((c) => !c.isRoot)) {
      final pid = c.parentId;
      if (pid == null) continue;
      (childrenOf[pid] ??= []).add(c);
    }
    for (final list in childrenOf.values) {
      list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }

    // Orphans / children whose parent is filtered out of `visible` still show.
    final visibleRootIds = roots.map((r) => r.id).toSet();
    final orphans = kindAll
        .where((c) => !c.isRoot && !visibleRootIds.contains(c.parentId))
        .toList();

    return [
      _SectionLabel(label: sectionLabel),
      for (final root in roots)
        _CategoryGroup(
          root: root,
          children: childrenOf[root.id] ?? const [],
          searching: _query.isNotEmpty,
          onToggleHide: () => _toggleHide(ref, root),
          onRename: () => _showRenameSheet(context, ref, root),
          onMove: null, // first-level groups are not movable
          onDelete: () => _showDeleteSheet(context, ref, root),
          onChildToggleHide: (c) => _toggleHide(ref, c),
          onChildRename: (c) => _showRenameSheet(context, ref, c),
          onChildMove: (c) => _showMoveSheet(context, ref, c),
          onChildDelete: (c) => _showDeleteSheet(context, ref, c),
        ),
      ...orphans.map((c) => Padding(
            padding: const EdgeInsets.only(left: Spacing.md),
            child: _CategoryTile(
              category: c,
              parentName: _parentNameOf(all, c),
              onToggleHide: () => _toggleHide(ref, c),
              onRename: () => _showRenameSheet(context, ref, c),
              onMove: () => _showMoveSheet(context, ref, c),
              onDelete: () => _showDeleteSheet(context, ref, c),
            ),
          )),
      const SizedBox(height: Spacing.lg),
    ];
  }

  /// Move a second-level category under a different first-level group.
  void _showMoveSheet(BuildContext context, WidgetRef ref, domain.Category source) {
    // Default (preset) taxonomy is read-only.
    if (source.isPreset) {
      showAppToast(context, '默认分类不可修改');
      return;
    }
    // Only second-level items can change parent.
    if (source.isRoot) {
      showAppToast(context, '一级分类不能移动');
      return;
    }
    final categoriesAsync = ref.read(_categoriesProvider);
    final categories = categoriesAsync.value ?? const <domain.Category>[];
    final targets = categories
        .where((c) =>
            !c.isDeleted &&
            c.isRoot &&
            c.id != source.parentId &&
            c.kind == source.kind)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    if (targets.isEmpty) {
      showAppToast(context, '没有可移动到的一级分类');
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(ctx).height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(Spacing.lg),
                child: Text(
                  '将「${source.name}」移动到：',
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: targets.length,
                  itemBuilder: (_, i) {
                    final target = targets[i];
                    return ListTile(
                      leading: const Icon(Icons.drive_file_move_outline),
                      title: Text(target.name),
                      subtitle: Text(target.kind == CategoryKind.expense ? '支出' : '收入'),
                      onTap: () => _confirmMove(context, ref, source, target),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmMove(
    BuildContext context,
    WidgetRef ref,
    domain.Category source,
    domain.Category target,
  ) {
    Navigator.pop(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('移动分类'),
        content: Text('将「${source.name}」移动到「${target.name}」下？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final deps = ref.read(appDependenciesProvider);
              final result = await deps.categoryRepository.moveToParent(
                categoryId: source.id,
                newParentId: target.id,
              );
              result.when(
                success: (_) {
                  ref.invalidateData.bumpCategoriesMutated();
                  showAppToast(context, '已移动到「${target.name}」');
                },
                failure: (f) {
                  showAppToast(context, '移动失败: ${f.code}');
                },
              );
            },
            child: const Text('移动'),
          ),
        ],
      ),
    );
  }

}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.colors.inkSecondary)),
    );
  }
}

class _CategoryGroup extends StatefulWidget {
  const _CategoryGroup({
    required this.root,
    required this.children,
    required this.searching,
    required this.onToggleHide,
    required this.onRename,
    required this.onChildToggleHide,
    required this.onChildRename,
    required this.onChildMove,
    required this.onChildDelete,
    required this.onDelete,
    this.onMove,
  });

  final domain.Category root;
  final List<domain.Category> children;
  final bool searching;
  final VoidCallback onToggleHide;
  final VoidCallback onRename;
  final void Function(domain.Category) onChildToggleHide;
  final void Function(domain.Category) onChildRename;
  final void Function(domain.Category) onChildMove;
  final void Function(domain.Category) onChildDelete;
  final VoidCallback onDelete;
  final VoidCallback? onMove;

  @override
  State<_CategoryGroup> createState() => _CategoryGroupState();
}

class _CategoryGroupState extends State<_CategoryGroup> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    // While searching, open all groups so hits are visible.
    final expanded = _expanded || widget.searching;
    final hasChildren = widget.children.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CategoryTile(
          category: widget.root,
          isGroup: true,
          onToggleHide: widget.onToggleHide,
          onRename: widget.onRename,
          onMove: widget.onMove,
          onDelete: widget.onDelete,
          trailingExpand: hasChildren
              ? GestureDetector(
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: AnimatedRotation(
                    turns: expanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: context.colors.inkTertiary,
                    ),
                  ),
                )
              : null,
          onTap: hasChildren ? () => setState(() => _expanded = !_expanded) : null,
        ),
        if (hasChildren && expanded)
          Padding(
            padding: const EdgeInsets.only(left: Spacing.md),
            child: Column(
              children: [
                for (final c in widget.children)
                  _CategoryTile(
                    category: c,
                    parentName: widget.root.name,
                    onToggleHide: () => widget.onChildToggleHide(c),
                    onRename: () => widget.onChildRename(c),
                    onMove: () => widget.onChildMove(c),
                    onDelete: () => widget.onChildDelete(c),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.onToggleHide,
    required this.onRename,
    this.onMove,
    this.onDelete,
    this.parentName,
    this.isGroup = false,
    this.trailingExpand,
    this.onTap,
  });

  final domain.Category category;
  final VoidCallback onToggleHide;
  final VoidCallback onRename;
  /// Move to another first-level group — second-level only.
  final VoidCallback? onMove;

  /// Delete custom category (bills go to default 其他).
  final VoidCallback? onDelete;

  /// Parent title for second-level categories (shown in search context).
  final String? parentName;

  /// First-level group styling (bolder title).
  final bool isGroup;

  /// Expand/collapse affordance rendered before the overflow menu.
  final Widget? trailingExpand;

  /// Optional row tap (expand/collapse for groups).
  final VoidCallback? onTap;

  Widget? _subtitle(BuildContext context) {
    final note = category.note;
    final children = <Widget>[];
    if (parentName != null && parentName!.isNotEmpty) {
      children.add(Text(
        '在「$parentName」下',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, color: context.colors.inkTertiary),
      ));
    }
    if (note != null && note.isNotEmpty) {
      children.add(Text(
        note,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, color: context.colors.inkTertiary),
      ));
    }
    if (category.isPreset) {
      children.add(Text('预置', style: TextStyle(fontSize: 11, color: context.colors.inkTertiary)));
    }
    if (children.isEmpty) return null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: 2),
          children[i],
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isExpense = category.kind == CategoryKind.expense;
    final color = isExpense ? context.colors.expense : context.colors.income;

    return Card(
      margin: const EdgeInsets.only(bottom: Spacing.sm),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.xs),
        leading: CategoryAvatar(iconRef: category.iconRef, color: color, size: 18),
        title: Text(
          category.name,
          style: TextStyle(
            fontSize: 15,
            fontWeight: isGroup ? FontWeight.w600 : FontWeight.w500,
            color: category.isHidden ? context.colors.inkTertiary : context.colors.ink,
            decoration: category.isHidden ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: _subtitle(context),
        onTap: onTap,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ?trailingExpand,
            IconButton(
              icon: Icon(
                category.isHidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 20,
              ),
              onPressed: onToggleHide,
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 20),
              onSelected: (v) {
                // Default (preset) taxonomy is read-only — always answer with a toast.
                if (category.isPreset) {
                  showAppToast(context, '默认分类不可修改');
                  return;
                }
                switch (v) {
                  case 'rename':
                    onRename();
                  case 'move':
                    onMove?.call();
                  case 'delete':
                    onDelete?.call();
                }
              },
              itemBuilder: (ctx) {
                final locked = category.isPreset;
                final labelStyle = locked ? TextStyle(color: context.colors.inkTertiary) : null;
                return [
                  PopupMenuItem(
                    value: 'rename',
                    child: Text('编辑分类信息', style: labelStyle),
                  ),
                  // 一级分组不可移动；仅二级条目可换归属。
                  if (onMove != null)
                    PopupMenuItem(
                      value: 'move',
                      child: Text('移动到…', style: labelStyle),
                    ),
                  if (onDelete != null)
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('删除', style: labelStyle),
                    ),
                ];
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _IconPicker extends StatelessWidget {
  const _IconPicker({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  static const _refs = [
    'food', 'shopping', 'daily', 'transport', 'fruit',
    'entertainment', 'telecom', 'housing', 'medical', 'study',
    'social', 'salary', 'bonus', 'other',
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final r in _refs)
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => onChanged(r),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: r == value
                    ? context.colors.primary.withValues(alpha: 0.15)
                    : context.colors.surfaceMuted,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: r == value ? context.colors.primary : context.colors.divider,
                ),
              ),
              child: Icon(iconForCategory(r), size: 20, color: context.colors.primary),
            ),
          ),
      ],
    );
  }
}
