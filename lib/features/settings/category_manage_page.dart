/// Category management page. See PRD STORY-1.3.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plain/app/bootstrap.dart';
import 'package:plain/app/theme/design_tokens.dart';
import 'package:plain/design_system/category_icons.dart';
import 'package:plain/domain/entities/category.dart' as domain;
import 'package:plain/domain/entities/enums.dart';

final _categoriesProvider = FutureProvider<List<domain.Category>>((ref) async {
  final repo = ref.watch(categoryRepositoryProvider);
  final result = await repo.listAll();
  return result.successOrNull ?? const [];
});

class CategoryManagePage extends ConsumerWidget {
  const CategoryManagePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(_categoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('分类管理')),
      body: categoriesAsync.when(
        data: (categories) {
          final expense = categories.where((c) => c.kind == CategoryKind.expense).toList();
          final income = categories.where((c) => c.kind == CategoryKind.income).toList();

          return ListView(
            padding: const EdgeInsets.all(Spacing.lg),
            children: [
              if (expense.isNotEmpty) ...[
                _SectionLabel(label: '支出'),
                ...expense.map((c) => _CategoryTile(
                      category: c,
                      onToggleHide: () => _toggleHide(ref, c),
                      onRename: () => _showRenameSheet(context, ref, c),
                      onMerge: () => _showMergeSheet(context, ref, c),
                    )),
                const SizedBox(height: Spacing.lg),
              ],
              if (income.isNotEmpty) ...[
                _SectionLabel(label: '收入'),
                ...income.map((c) => _CategoryTile(
                      category: c,
                      onToggleHide: () => _toggleHide(ref, c),
                      onRename: () => _showRenameSheet(context, ref, c),
                      onMerge: () => _showMergeSheet(context, ref, c),
                    )),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_category_add',
        onPressed: () => _showAddSheet(context, ref),
        backgroundColor: BrandColors.primary,
        foregroundColor: BrandColors.onPrimary,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _toggleHide(WidgetRef ref, domain.Category cat) {
    final deps = ref.read(appDependenciesProvider);
    final updated = cat.copyWith(isHidden: !cat.isHidden, updatedAt: DateTime.now().toUtc());
    deps.categoryRepository.update(updated);
    ref.invalidate(_categoriesProvider);
  }

  void _showRenameSheet(BuildContext context, WidgetRef ref, domain.Category cat) {
    final ctrl = TextEditingController(text: cat.name);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
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
            Text('重命名分类', style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: Spacing.lg),
            TextField(
              controller: ctrl,
              maxLength: 6,
              decoration: const InputDecoration(labelText: '名称', border: OutlineInputBorder()),
            ),
            const SizedBox(height: Spacing.lg),
            FilledButton(
              onPressed: () {
                final name = ctrl.text.trim();
                if (name.isEmpty) return;
                final deps = ref.read(appDependenciesProvider);
                final updated = cat.copyWith(
                  name: name,
                  updatedAt: DateTime.now().toUtc(),
                  revision: cat.revision + 1,
                  baseRevision: cat.revision,
                );
                deps.categoryRepository.update(updated);
                ref.invalidate(_categoriesProvider);
                Navigator.pop(ctx);
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddSheet(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    var kind = CategoryKind.expense;

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
              Text('添加分类', style: Theme.of(ctx).textTheme.titleMedium),
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
                controller: nameCtrl,
                maxLength: 6,
                decoration: const InputDecoration(labelText: '名称', hintText: '如：咖啡', border: OutlineInputBorder()),
              ),
              const SizedBox(height: Spacing.lg),
              FilledButton(
                onPressed: () {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) return;
                  final deps = ref.read(appDependenciesProvider);
                  final now = DateTime.now().toUtc();
                  final id = 'cat_${DateTime.now().millisecondsSinceEpoch}';
                  deps.categoryRepository.create(domain.Category(
                    id: id,
                    name: name,
                    kind: kind,
                    iconRef: 'other',
                    sortOrder: 999,
                    createdAt: now,
                    updatedAt: now,
                    deviceId: deps.deviceId,
                  ));
                  ref.invalidate(_categoriesProvider);
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

  void _showMergeSheet(BuildContext context, WidgetRef ref, domain.Category source) {
    final categoriesAsync = ref.read(_categoriesProvider);
    final categories = categoriesAsync.value ?? const <domain.Category>[];
    final targets = categories
        .where((c) => c.id != source.id && c.kind == source.kind && !c.isDeleted)
        .toList();

    if (targets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有可合并的目标分类')),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(Spacing.lg),
              child: Text('将「${source.name}」合并到：', style: Theme.of(ctx).textTheme.titleMedium),
            ),
            ...targets.map((t) => ListTile(
                  leading: const Icon(Icons.merge_type_outlined),
                  title: Text(t.name),
                  onTap: () => _confirmMerge(context, ref, source, t),
                )),
          ],
        ),
      ),
    );
  }

  void _confirmMerge(BuildContext context, WidgetRef ref, domain.Category source, domain.Category target) {
    Navigator.pop(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('合并分类'),
        content: Text('将「${source.name}」的所有账单迁移到「${target.name}」？此操作不可恢复。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final deps = ref.read(appDependenciesProvider);
              final result = await deps.categoryRepository.merge(sourceId: source.id, targetId: target.id);
              result.when(
                success: (count) {
                  ref.invalidate(_categoriesProvider);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('已合并 $count 笔账单')),
                  );
                },
                failure: (f) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('合并失败: ${f.code}')),
                  );
                },
              );
            },
            child: const Text('合并'),
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
      child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: BrandColors.inkSecondary)),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.onToggleHide,
    required this.onRename,
    required this.onMerge,
  });

  final domain.Category category;
  final VoidCallback onToggleHide;
  final VoidCallback onRename;
  final VoidCallback onMerge;

  @override
  Widget build(BuildContext context) {
    final isExpense = category.kind == CategoryKind.expense;
    final color = isExpense ? BrandColors.expense : BrandColors.income;

    return Card(
      margin: const EdgeInsets.only(bottom: Spacing.sm),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.xs),
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(iconForCategory(category.iconRef), size: 18, color: color),
        ),
        title: Text(
          category.name,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: category.isHidden ? BrandColors.inkTertiary : BrandColors.ink,
            decoration: category.isHidden ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: category.isPreset
            ? Text('预置', style: TextStyle(fontSize: 11, color: BrandColors.inkTertiary))
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
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
                switch (v) {
                  case 'rename':
                    onRename();
                  case 'merge':
                    onMerge();
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'rename', child: Text('重命名')),
                const PopupMenuItem(value: 'merge', child: Text('合并')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
