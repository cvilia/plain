/// Category management page. See PRD STORY-1.3.
library;

import 'package:plain/app/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:plain/design_system/app_error_state.dart';
import 'package:plain/design_system/app_toast.dart';
import 'package:plain/design_system/bubble_overlay.dart';
import 'package:plain/design_system/confirm_dialog.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plain/app/bootstrap.dart';
import 'package:plain/app/theme/design_tokens.dart';
import 'package:plain/core/refresh/data_invalidation.dart';
import 'package:plain/design_system/category_create_sheet.dart';
import 'package:plain/design_system/category_icon_picker.dart';
import 'package:plain/design_system/category_icon_v3.dart';
import 'package:plain/design_system/plain_icons_v3.dart';
import 'package:plain/design_system/picker_sheet.dart';
import 'package:plain/design_system/plain_ui.dart';
import 'package:plain/domain/entities/category.dart' as domain;
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/services/category_naming.dart';
import 'package:plain/app/l10n/app_strings.dart';
import 'package:plain/app/l10n/strings_accounts.dart';
import 'package:plain/app/l10n/strings_domain.dart';
import 'package:plain/app/l10n/strings_ledger.dart';
import 'package:plain/app/l10n/strings_settings_a.dart';

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
    final s = AppStrings.of(context);
    final categoriesAsync = ref.watch(_categoriesProvider);

    return Scaffold(
      appBar: PlainTopBar(
        title: s.categories,
        showBack: true,
        actions: [
          // 顶栏动作一律走 [PlainTopBarAction]（44×44 / r12 水波纹 / 图标 22）。
          // 别用 Material `IconButton`：默认命中盒 48×48、没有 r12 水波纹，
          // 会让「分类管理」与「选择分类」两页的同一个「新增」按钮长成两个样子。
          PlainTopBarAction(
            icon: PlainIconData.plus,
            tooltip: s.categoryNewTooltip,
            onTap: () => _showAddSheet(context, ref),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.sm, Spacing.lg, Spacing.xs),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v.trim()),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: s.categorySearchHint,
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 12, right: 8),
                  child: PlainIcon(
                    PlainIconData.search,
                    size: 18,
                    color: context.colors.inkTertiary,
                  ),
                ),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const PlainIcon(PlainIconData.close, size: 18),
                        tooltip: s.categoryClearSearch,
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
              // 依赖版本变化（reload）时保留上一帧列表，避免整块被 loading 圈顶掉。
              // 只有首次加载（无旧值）才显示加载态。
              skipLoadingOnReload: true,
              data: (categories) {
                final visible = categories
                    .where((c) => !c.isDeleted && _matches(c, categories, _query))
                    .toList();

                if (_query.isNotEmpty && visible.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(Spacing.xl),
                      child: Text(
                        s.categoryNoMatch(_query),
                        style: TextStyle(color: context.colors.inkTertiary),
                      ),
                    ),
                  );
                }

                return ListView(
                  padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.sm, Spacing.lg, Spacing.xl),
                  children: [
                    ..._buildTree(context, ref, categories, visible, CategoryKind.expense, s.expense),
                    ..._buildTree(context, ref, categories, visible, CategoryKind.income, s.income),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => AppErrorState.of(context, e, onRetry: () => ref.invalidateData.bumpEverything()),
            ),
          ),
        ],
      ),
    );
  }

  String? _parentNameOf(List<domain.Category> all, domain.Category c) {
    if (c.parentId == null) return null;
    return all.where((p) => p.id == c.parentId).firstOrNull?.name;
  }

  Future<void> _toggleHide(WidgetRef ref, domain.Category cat) async {
    final deps = ref.read(appDependenciesProvider);
    final updated = cat.copyWith(isHidden: !cat.isHidden, updatedAt: DateTime.now().toUtc());
    // 先落库再 bump：避免「UI 已刷新但库里还没写完」导致读到旧值再刷一次。
    await deps.categoryRepository.update(updated);
    if (!mounted) return;
    ref.invalidateData.bumpCategoriesMutated();
  }

  void _showRenameSheet(BuildContext context, WidgetRef ref, domain.Category cat) {
    final s = AppStrings.of(context);
    // Default (preset) taxonomy is read-only.
    if (cat.isPreset) {
      showAppToast(context, s.categoryPresetReadonly);
      return;
    }
    final nameCtrl = TextEditingController(text: cat.name);
    final noteCtrl = TextEditingController(text: cat.note ?? '');
    var iconRef = cat.iconRef;
    var isRigid = cat.isRigid;
    var isDeductible = cat.isDeductible;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: StatefulBuilder(
          builder: (ctx, setSheetState) => Padding(
            padding: EdgeInsets.only(
              left: Spacing.lg,
              right: Spacing.lg,
              top: Spacing.lg,
              bottom: MediaQuery.viewInsetsOf(ctx).bottom + Spacing.lg,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(s.editCategoryInfo, style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: Spacing.lg),
              TextField(
                controller: nameCtrl,
                maxLength: 6,
                decoration: InputDecoration(labelText: s.nameLabel, border: OutlineInputBorder()),
              ),
              const SizedBox(height: Spacing.md),
              CategoryIconPicker(
                value: iconRef,
                onChanged: (v) => setSheetState(() => iconRef = v),
              ),
              const SizedBox(height: Spacing.md),
              TextField(
                controller: noteCtrl,
                maxLength: 30,
                maxLines: 2,
                inputFormatters: const [], // maxLength truncates silently
                decoration: InputDecoration(
                  labelText: s.note,
                  hintText: s.categoryNoteHint,
                  border: OutlineInputBorder(),
                ),
              ),
              if (cat.isRoot) ...[
                const SizedBox(height: Spacing.sm),
                SwitchListTile(
                  title: Text(s.categoryRigidTitle, style: TextStyle(fontSize: 14)),
                  subtitle: Text(s.categoryRigidSubtitle, style: TextStyle(fontSize: 12, color: Theme.of(ctx).textTheme.bodySmall?.color?.withValues(alpha: 0.6))),
                  value: isRigid,
                  onChanged: (v) => setSheetState(() => isRigid = v),
                  contentPadding: EdgeInsets.zero,
                ),
                // STORY-11.5：可抵扣标记（税务报表按它汇总，二级继承）
                SwitchListTile(
                  title: Text(s.categoryDeductibleTitle, style: TextStyle(fontSize: 14)),
                  subtitle: Text(s.categoryDeductibleSubtitle,
                      style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(ctx)
                              .textTheme
                              .bodySmall
                              ?.color
                              ?.withValues(alpha: 0.6))),
                  value: isDeductible,
                  onChanged: (v) => setSheetState(() => isDeductible = v),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
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
                        isRigid: isRigid,
                        isDeductible: isDeductible,
                        updatedAt: DateTime.now().toUtc(),
                        revision: cat.revision + 1,
                        baseRevision: cat.revision,
                      );
                  deps.categoryRepository.update(updated);
                  ref.invalidateData.bumpCategoriesMutated();
                  Navigator.pop(ctx);
                },
                child: Text(s.save),
              ),
            ],
            ),
          ),
        ),
        ),
      ),
    );
  }

  void _showAddSheet(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(Spacing.lg),
              child: Text(s.addCategory, style: Theme.of(ctx).textTheme.titleMedium),
            ),
            PlainRow(
              leading: const PlainIcon(PlainIconData.chevronRight),
              title: s.addUnderCategory,
              subtitle: s.addUnderCategoryDesc,
              onTap: () {
                Navigator.pop(ctx);
                _showAddLeafSheet(context, ref);
              },
            ),
            PlainRow(
              leading: const PlainIcon(PlainIconData.folderPlus),
              title: s.newRootCategory,
              subtitle: s.rootNeedLeafDesc,
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
    final s = AppStrings.of(context);
    final categories = ref.read(_categoriesProvider).value ?? const <domain.Category>[];
    final roots = categories
        .where((c) => !c.isDeleted && c.isRoot)
        .toList()
      ..sort((a, b) => a.kind.index.compareTo(b.kind.index) != 0
          ? a.kind.index.compareTo(b.kind.index)
          : a.sortOrder.compareTo(b.sortOrder));
    if (roots.isEmpty) {
      showAppToast(context, s.categoryCreateRootFirst);
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
            bottom: MediaQuery.viewInsetsOf(ctx).bottom + Spacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(s.categoryAddSubTitle, style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: Spacing.lg),
              PickerField(
                label: s.parentCategoryLabel,
                value: parent == null ? s.notSelected : _rootLabel(parent!),
                onTap: () async {
                  final picked = await showOptionPicker<domain.Category>(
                    context: ctx,
                    title: s.parentCategoryLabel,
                    current: parent,
                    options: [
                      for (final r in roots)
                        PickerOption(value: r, label: _rootLabel(r)),
                    ],
                  );
                  if (picked != null) setSheetState(() => parent = picked);
                },
              ),
              const SizedBox(height: Spacing.md),
              TextField(
                controller: nameCtrl,
                maxLength: 6,
                decoration: InputDecoration(
                  labelText: s.nameLabel,
                  hintText: s.nameFieldHint,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: Spacing.md),
              TextField(
                controller: noteCtrl,
                maxLength: 30,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: s.note,
                  hintText: s.categoryNoteHint,
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
                    s: AppStrings.of(context),
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
                child: Text(s.addAction),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Create a new first-level group plus its first second-level leaf.
  ///
  /// 弹层与重名校验走共用的 `showCreateRootCategorySheet`（与「选择分类」页
  /// 同一个实现，避免两页各判一套）；管理页不限定 kind，所以表单里保留
  /// 「支出 / 收入」单选。
  Future<void> _showAddRootSheet(BuildContext context, WidgetRef ref) async {
    final existing =
        ref.read(_categoriesProvider).value ?? const <domain.Category>[];
    final draft = await showCreateRootCategorySheet(
      context: context,
      existing: existing,
    );
    if (draft == null || !context.mounted) return;
    final now = DateTime.now().toUtc();
    final rootId = 'cat_${now.microsecondsSinceEpoch}';
    _createCategory(
      context,
      ref,
      name: draft.rootName,
      note: draft.rootNote,
      kind: draft.kind,
      parentId: null,
      iconRef: draft.iconRef,
      id: rootId,
      now: now,
    );
    // 首个二级用默认图标（所选图标留给一级）—— 与选择分类页唯一的差别，
    // 那里二级一律继承父级图标，沿用该页自己的惯例。
    _createCategory(
      context,
      ref,
      name: draft.leafName,
      note: draft.leafNote,
      kind: draft.kind,
      parentId: rootId,
      now: now.add(const Duration(milliseconds: 1)),
    );
  }

  /// Delete a custom category. Live bills are reassigned to the default 其他.
  Future<void> _showDeleteSheet(
    BuildContext context,
    WidgetRef ref,
    domain.Category cat,
  ) async {
    final s = AppStrings.of(context);
    if (cat.isPreset) {
      showAppToast(context, s.categoryPresetReadonly);
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
    final fallbackName = s.other;

    final title = isGroup ? s.categoryDeleteGroupTitle : s.categoryDeleteTitle;
    final String message;
    if (count > 0) {
      final scope = isGroup && childIds.isNotEmpty
          ? s.categoryDeleteScope(childIds.length)
          : '';
      message = s.categoryDeleteEntries(cat.name, scope, count, fallbackName);
    } else {
      message = isGroup && childIds.isNotEmpty
          ? s.categoryDeleteGroupConfirm(cat.name, childIds.length)
          : s.categoryDeleteConfirm(cat.name);
    }

    final okDel = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: count > 0
                ? FilledButton.styleFrom(backgroundColor: context.colors.expense)
                : null,
            child: Text(s.delete),
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
              ? s.categoryDeletedMoved(moved, fallbackName)
              : s.categoryDeletedNamed(cat.name),
        );
      },
      failure: (f) => showAppToast(context, s.categoryDeleteFailed(f.code)),
    );
  }

  String _rootLabel(domain.Category r) {
    final s = AppStrings.of(context);
    final kindLabel = r.kind == CategoryKind.expense ? s.expense : s.income;
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
    showAppToast(context, AppStrings.of(context).categoryAdded(name));
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
          onMerge: () => _showMergeSheet(context, ref, root),
          onDelete: () => _showDeleteSheet(context, ref, root),
          onChildToggleHide: (c) => _toggleHide(ref, c),
          onChildRename: (c) => _showRenameSheet(context, ref, c),
          onChildMove: (c) => _showMoveSheet(context, ref, c),
          onChildMerge: (c) => _showMergeSheet(context, ref, c),
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
              onMerge: () => _showMergeSheet(context, ref, c),
              onDelete: () => _showDeleteSheet(context, ref, c),
            ),
          )),
      const SizedBox(height: Spacing.lg),
    ];
  }

  /// Move a second-level category under a different first-level group.
  void _showMoveSheet(BuildContext context, WidgetRef ref, domain.Category source) {
    final s = AppStrings.of(context);
    // Default (preset) taxonomy is read-only.
    if (source.isPreset) {
      showAppToast(context, s.categoryPresetReadonly);
      return;
    }
    // Only second-level items can change parent.
    if (source.isRoot) {
      showAppToast(context, s.categoryRootNotMovable);
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
      showAppToast(context, s.categoryNoMoveTarget);
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
                  s.categoryMoveToTitle(source.name),
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: targets.length,
                  itemBuilder: (_, i) {
                    final target = targets[i];
                    return PlainRow(
                      leading: const PlainIcon(PlainIconData.folderMove),
                      title: target.name,
                      subtitle: target.kind == CategoryKind.expense ? s.expense : s.income,
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

  /// STORY-1.3 AC11：合并到同层级其他分类。
  void _showMergeSheet(BuildContext context, WidgetRef ref, domain.Category source) {
    final s = AppStrings.of(context);
    if (source.isPreset) {
      showAppToast(context, s.categoryPresetReadonly);
      return;
    }
    final categoriesAsync = ref.read(_categoriesProvider);
    final categories = categoriesAsync.value ?? const <domain.Category>[];
    // 仅同层级、同 kind
    final targets = categories
        .where((c) =>
            !c.isDeleted &&
            c.id != source.id &&
            c.kind == source.kind &&
            (source.isRoot ? c.isRoot : (!c.isRoot && c.parentId == source.parentId)))
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    if (targets.isEmpty) {
      showAppToast(context, s.categoryNoMergeTarget);
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
                  s.categoryMergeToTitle(source.name),
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: targets.length,
                  itemBuilder: (_, i) {
                    final target = targets[i];
                    return PlainRow(
                      leading: const PlainIcon(PlainIconData.merge),
                      title: target.name,
                      onTap: () => _confirmMerge(context, ref, source, target),
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

  Future<void> _confirmMerge(
    BuildContext context,
    WidgetRef ref,
    domain.Category source,
    domain.Category target,
  ) async {
    final s = AppStrings.of(context);
    final deps = ref.read(appDependenciesProvider);
    final count = await deps.categoryRepository.countLiveEntries(
      categoryId: source.id,
      includeDescendants: source.isRoot,
    );
    final n = count.successOrNull ?? 0;
    if (!context.mounted) return;

    final ok = await showConfirmDialog(
      context,
      title: s.categoryMergeTitle,
      message: s.categoryMergeMessage(source.name, target.name, n,
          source.isRoot ? s.categoryMergeRootClause : ''),
      confirmLabel: s.categoryMergeAction,
      destructive: true,
    );
    if (ok != true || !context.mounted) return;

    final result = await deps.categoryRepository.mergeCategories(
      sourceId: source.id,
      targetId: target.id,
    );
    result.when(
      success: (r) {
        ref.invalidateData.bumpCategoriesMutated();
        ref.invalidateData.bumpEntryMutated();
        showAppToast(
            context, s.categoryMerged(r.movedEntries, target.name));
      },
      failure: (f) => showAppToast(context, s.categoryMergeFailed(f.code)),
    );
  }

  void _confirmMove(
    BuildContext context,
    WidgetRef ref,
    domain.Category source,
    domain.Category target,
  ) {
    final s = AppStrings.of(context);
    Navigator.pop(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.categoryMoveTitle),
        content: Text(s.categoryMoveConfirm(source.name, target.name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.cancel)),
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
                  showAppToast(context, s.categoryMoved(target.name));
                },
                failure: (f) {
                  showAppToast(context, s.categoryMoveFailed(f.code));
                },
              );
            },
            child: Text(s.categoryMoveAction),
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
      child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.colors.inkSecondary)),
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
    this.onMerge,
    this.onChildMerge,
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
  final VoidCallback? onMerge;
  final void Function(domain.Category)? onChildMerge;

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
          onMerge: widget.onMerge,
          onDelete: widget.onDelete,
          trailingExpand: hasChildren
              ? GestureDetector(
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: AnimatedRotation(
                    turns: expanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: PlainIcon(
                      PlainIconData.chevronRight,
                      size: 18,
                      color: context.colors.inkTertiary,
                    ),
                  ),
                )
              : null,
          onTap: hasChildren ? () => setState(() => _expanded = !_expanded) : null,
        ),
        if (hasChildren && expanded)
          Padding(
            padding: const EdgeInsets.only(left: Spacing.xl5),
            child: Column(
              children: [
                for (final c in widget.children)
                  _CategoryTile(
                    category: c,
                    parentName: widget.root.name,
                    onToggleHide: () => widget.onChildToggleHide(c),
                    onRename: () => widget.onChildRename(c),
                    onMove: () => widget.onChildMove(c),
                    onMerge: widget.onChildMerge == null ? null : () => widget.onChildMerge!(c),
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
    this.onMerge,
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

  /// Merge into another same-level category (STORY-1.3 AC11).
  final VoidCallback? onMerge;

  /// Parent title for second-level categories (shown in search context).
  final String? parentName;

  /// First-level group styling (bolder title).
  final bool isGroup;

  /// Expand/collapse affordance rendered before the overflow menu.
  final Widget? trailingExpand;

  /// Optional row tap (expand/collapse for groups).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = categoryIconColor(category.iconRef, isDark: isDark);
    final note = category.note;
    final sub = (note != null && note.isNotEmpty) ? note : '';

    return BubbleOnLongPress(
      bubbleText: note,
      child: Material(
        color: colors.surface,
        child: InkWell(
          onTap: onTap,
            child: Container(
            constraints: BoxConstraints(minHeight: isGroup ? 72 : 56),
            padding: EdgeInsets.symmetric(
              horizontal: 8,
              vertical: isGroup ? 12 : 8,
            ),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: isGroup ? colors.border : colors.divider,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                // cicon 24
                CategoryIcon(
                  iconRef: category.iconRef,
                  size: isGroup ? 24 : 20,
                  color: iconColor,
                ),
                const SizedBox(width: 8),
                // rcol
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: isGroup ? 15 : 13,
                          fontWeight: isGroup ? FontWeight.w600 : FontWeight.w500,
                          color: category.isHidden
                              ? colors.inkTertiary
                              : colors.ink,
                          decoration: category.isHidden
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      if (sub.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          sub,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: colors.inkTertiary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailingExpand != null) ...[
                  const SizedBox(width: 2),
                  trailingExpand!,
                ],
                // cnt（设计稿为笔数；无数据时显示预置标记）
                Padding(
                  padding: const EdgeInsets.only(left: 4, right: 2),
                  child: Text(
                    category.isPreset ? s.preset : '',
                    style: TextStyle(fontSize: 12, color: colors.inkTertiary),
                  ),
                ),
                GestureDetector(
                  onTap: onToggleHide,
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    width: 28,
                    height: 44,
                    child: Center(
                      child: PlainIcon(
                        category.isHidden
                            ? PlainIconData.eyeOff
                            : PlainIconData.eye,
                        size: 18,
                        color: colors.inkTertiary,
                      ),
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  child: SizedBox(
                    width: 28,
                    height: 44,
                    child: Center(
                      child: PlainIcon(
                        PlainIconData.dragHandle,
                        size: 16,
                        color: colors.inkTertiary,
                      ),
                    ),
                  ),
                  onSelected: (v) {
                    if (category.isPreset) {
                      showAppToast(context, s.categoryPresetReadonly);
                      return;
                    }
                    switch (v) {
                      case 'rename':
                        onRename();
                      case 'move':
                        onMove?.call();
                      case 'merge':
                        onMerge?.call();
                      case 'delete':
                        onDelete?.call();
                    }
                  },
                  itemBuilder: (ctx) {
                    final locked = category.isPreset;
                    final labelStyle =
                        locked ? TextStyle(color: colors.inkTertiary) : null;
                    return [
                      PopupMenuItem(
                        value: 'rename',
                        child: Text(s.editCategoryInfo, style: labelStyle),
                      ),
                      if (onMove != null)
                        PopupMenuItem(
                          value: 'move',
                          child: Text(s.categoryMoveMenu, style: labelStyle),
                        ),
                      if (onMerge != null)
                        PopupMenuItem(
                          value: 'merge',
                          child: Text(s.categoryMergeMenu, style: labelStyle),
                        ),
                      if (onDelete != null)
                        PopupMenuItem(
                          value: 'delete',
                          child: Text(s.delete, style: labelStyle),
                        ),
                    ];
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

