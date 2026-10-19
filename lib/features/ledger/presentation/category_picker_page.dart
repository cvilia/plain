/// Full category picker page. See PRD STORY-1.1 (More grid).
library;

import 'package:plain/app/theme/app_colors.dart';
import 'package:plain/design_system/category_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plain/app/bootstrap.dart';
import 'package:plain/app/theme/design_tokens.dart';
import 'package:plain/core/refresh/data_invalidation.dart';
import 'package:plain/design_system/app_error_state.dart';
import 'package:plain/design_system/app_toast.dart';
import 'package:plain/design_system/category_create_sheet.dart';
import 'package:plain/design_system/plain_icons_v3.dart';
import 'package:plain/design_system/picker_sheet.dart';
import 'package:plain/design_system/plain_ui.dart';
import 'package:plain/domain/entities/category.dart' as domain;
import 'package:plain/domain/services/category_naming.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/app/l10n/app_strings.dart';
import 'package:plain/app/l10n/strings_accounts.dart';
import 'package:plain/app/l10n/strings_ledger.dart';
import 'package:plain/app/l10n/strings_settings_b.dart';

/// 当前 kind 的全部分类（含已隐藏项）。
///
/// ⚠️ 用 `listAll()` 而不是 `listVisible()`：本页「新建」弹层要拿这份清单做
/// **重名校验**，而写库的唯一索引 `uq_category_name(COALESCE(parent_id,''),name)`
/// 并不区分隐藏 —— 拿可见列表校验会漏判，一路走到写库才失败，而 `create` 的
/// 返回值这里并不检查，界面看着"建成"了、库里其实没有。
/// 展示处单独滤掉隐藏项（见 build 的 data 分支）。
final _allCategoriesProvider = FutureProvider<List<domain.Category>>((ref) async {
  ref.watch(categoriesVersionProvider);
  final repo = ref.watch(categoryRepositoryProvider);
  final result = await repo.listAll();
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
    final s = AppStrings.of(context);
    final categoriesAsync = ref.watch(_allCategoriesProvider);

    return Scaffold(
      appBar: PlainTopBar(
        title: s.pickCategory,
        showBack: true,
        // 新增入口在**顶栏右上角**（原来挂在右下角是 `FloatingActionButton.extended`）。
        // 本页是二级页：右下角悬浮按钮既压住列表末行，又和「左上角返回」的层级动线
        // 对不上；与「分类管理」页统一到同一处。
        actions: [
          PlainTopBarAction(
            icon: PlainIconData.plus,
            tooltip: s.addCategory,
            onTap: () => _showAddSheet(context, ref),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.sm, Spacing.lg, Spacing.sm),
            child: TextField(
              decoration: InputDecoration(
                hintText: s.searchCategoryHint,
                // 与「分类管理」页同一口径：图标 18 + 显式 `inkTertiary` + 收紧
                // prefix 内边距。默认 `prefixIcon` 会被 `prefixIconConstraints`
                // 撑进 48×48 的盒子并在其中居中 → 图标看着偏大、离左边框又远。
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 12, right: 8),
                  child: PlainIcon(
                    PlainIconData.search,
                    size: 18,
                    color: context.colors.inkTertiary,
                  ),
                ),
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
          Expanded(
            child: categoriesAsync.when(
              data: (categories) {
                // 隐藏项不进选择列表（与管理页不同：那边显示并划掉），
                // 但仍留在 `categories` 里参与新建时的重名校验。
                var filtered = categories
                    .where((c) => c.kind == widget.kind && !c.isHidden)
                    .toList();
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
                      _searchQuery.isEmpty ? s.noCategories : s.noMatchingCategory,
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
              error: (e, _) => AppErrorState.of(context, e, onRetry: () => ref.invalidateData.bumpEverything()),
            ),
          ),
        ],
      ),
    );
  }

  /// 新增入口：二级条目 / 一级分类，两选一。
  ///
  /// 与「分类管理」页同一套选项与文案。原来这里直接进二级弹层，一级分类只能
  /// 回分类管理页去建 —— 同一个「新增分类」入口，两页能力不一致。
  Future<void> _showAddSheet(BuildContext context, WidgetRef ref) async {
    final s = AppStrings.of(context);
    await showModalBottomSheet<void>(
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

  /// Add a second-level category from the picker, then select it.
  Future<void> _showAddLeafSheet(BuildContext context, WidgetRef ref) async {
    final s = AppStrings.of(context);
    final categories = ref.read(_allCategoriesProvider).value ?? const <domain.Category>[];
    final roots = categories
        .where((c) => c.isRoot && !c.isHidden && c.kind == widget.kind)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    if (roots.isEmpty) {
      showAppToast(context, s.noRootCategoryHint);
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
            bottom: MediaQuery.viewInsetsOf(ctx).bottom + Spacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(s.newCategoryEntryTitle, style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: Spacing.lg),
              PickerField(
                label: s.parentCategoryLabel,
                value: parent == null ? s.notSelected : parent!.name,
                onTap: () async {
                  final picked = await showOptionPicker<domain.Category>(
                    context: ctx,
                    title: s.parentCategoryLabel,
                    current: parent,
                    options: [
                      for (final r in roots)
                        PickerOption(value: r, label: r.name),
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
                  labelText: s.noteOptional,
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
                  final now = DateTime.now().toUtc();
                  final id = 'cat_${now.microsecondsSinceEpoch}';
                  final note = noteCtrl.text.trim();
                  _createCategory(
                    ref,
                    id: id,
                    parentId: p.id,
                    name: name,
                    note: note.isEmpty ? null : note,
                    kind: p.kind,
                    iconRef: p.iconRef,
                    now: now,
                  );
                  ref.invalidateData.bumpCategoriesMutated();
                  Navigator.pop(ctx, id);
                },
                child: Text(s.addAndSelect),
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

  /// 新建一级分类 + 首个二级条目，并把新二级条目直接选中返回。
  ///
  /// 弹层与重名校验走共用的 [showCreateRootCategorySheet]（与「分类管理」页
  /// 同一个实现）。本页两处不同，都只为贴合「选分类」这个场景：
  /// · kind 锁定为 [CategoryPickerPage.kind]：本页只可能在某个 kind 下选分类，
  ///   放行另一个 kind 会把分类 id 回传给调用方挂到错误的账单类型上；
  /// · 建成即选用：回传首个二级条目的 id，调用方直接选中。
  Future<void> _showAddRootSheet(BuildContext context, WidgetRef ref) async {
    final s = AppStrings.of(context);
    final existing =
        ref.read(_allCategoriesProvider).value ?? const <domain.Category>[];
    final draft = await showCreateRootCategorySheet(
      context: context,
      existing: existing,
      lockedKind: widget.kind,
      submitLabel: s.createAndSelect,
    );
    if (draft == null || !context.mounted) return;

    final now = DateTime.now().toUtc();
    final rootId = 'cat_${now.microsecondsSinceEpoch}';
    final leafAt = now.add(const Duration(milliseconds: 1));
    final leafId = 'cat_${leafAt.microsecondsSinceEpoch}';
    _createCategory(
      ref,
      id: rootId,
      parentId: null,
      name: draft.rootName,
      note: draft.rootNote,
      kind: draft.kind,
      iconRef: draft.iconRef,
      now: now,
    );
    // 二级继承刚选的图标，与同页「添加到分类下」的惯例一致（那边也是继承
    // 父级图标）—— 与分类管理页的唯一差别就在这一处。
    _createCategory(
      ref,
      id: leafId,
      parentId: rootId,
      name: draft.leafName,
      note: draft.leafNote,
      kind: draft.kind,
      iconRef: draft.iconRef,
      now: leafAt,
    );
    ref.invalidateData.bumpCategoriesMutated();
    if (context.mounted) Navigator.pop(context, leafId);
  }

  /// 建一行分类。字段与「分类管理」页的 `_createCategory` 逐项对齐，
  /// 差异只有本页不给"已添加"toast（建完立刻返回选中，toast 已由调用方承担）。
  void _createCategory(
    WidgetRef ref, {
    required String id,
    required String? parentId,
    required String name,
    required String? note,
    required CategoryKind kind,
    required String iconRef,
    required DateTime now,
  }) {
    final deps = ref.read(appDependenciesProvider);
    deps.categoryRepository.create(domain.Category(
      id: id,
      parentId: parentId,
      name: name,
      kind: kind,
      iconRef: iconRef,
      note: note,
      sortOrder: 999,
      createdAt: now,
      updatedAt: now,
      deviceId: deps.deviceId,
    ));
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
                    child: PlainIcon(
                      PlainIconData.chevronRight,
                      size: 20,
                      color: context.colors.inkTertiary,
                    ),
                  ),
                )
              : null,
          onTap: () {
            // 一级分类的分工：
            // · **有**子分类 → 只作分组，点一下展开（记账要落到二级）；
            // · **没有**子分类 → 它自己就是最小可选单位，直接选中 —— 否则点它
            //   没反应、底下又没得选，是个死胡同。宫格（`CategoryListX.leaves`
            //   把这类当叶子）与预算选择器给的也是它，三处口径一致。
            // · 兜底「其他」即使将来有了子分类也仍然可直接选。
            if (!hasChildren || isDefaultOtherCategory(widget.root)) {
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
        // 组间不再留 4pt 间隙：有了上边线之后，任何额外间距都会让线的节奏
        // 忽宽忽窄（组内 0、组间 4）。「分类管理」页同样是组间无间隙。
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
    final colors = context.colors;
    final isExpense = category.kind == CategoryKind.expense;
    final color = isExpense ? colors.expense : colors.income;

    return Material(
      color: const Color(0x00000000),
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 60),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          // 每行画**上**边线，而不是下边线：
          // · 最后一行下面不会多出一条悬空的线（列表末尾＝线也结束）；
          // · 首行上面有一条起始线，与「分类管理」页 `_CategoryTile` 完全同构。
          // 一级用 `border`、二级用更浅的 `divider`，层级一眼可分。
          // 注意：`decoration` 的 border 会**折进 padding**（Container 把
          // `decoration.padding` 加到内边距上），所以这里实得内容高是
          // `1 + 11 + 内容 + 10`，总高仍是 `max(60, …)` = 60，不会被撑高。
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: category.isRoot ? colors.border : colors.divider,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              CategoryAvatar(iconRef: category.iconRef, color: color, size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  category.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: category.isRoot ? FontWeight.w500 : FontWeight.w400,
                  ),
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}
