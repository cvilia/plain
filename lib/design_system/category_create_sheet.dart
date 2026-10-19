/// 「新建一级分类」底部弹层 —— 全 App 唯一实现。
///
/// 一级分类只作分组，记账时必须落到二级条目；所以只建一级会立刻产出一个
/// **选不了**的分类，这个流程天然是「一级 + 首个二级」的合并表单。
///
/// 分类管理页与选择分类页共用本实现，差异只用两个参数表达：
/// · [lockedKind] 为 null → 显示支出/收入单选（分类管理页自己决定建哪类）；
///   非 null → 固定为该 kind（选择分类页：kind 由页面决定，跨 kind 的分类
///   回传给调用方会挂到错误的账单类型上）。
/// · [submitLabel] 前者「创建」，后者「创建并选用」（建完即选中返回）。
///
/// 校验也收在这里，避免两页各判一套：
/// 一级重名 → 「已有同名一级分类」；首个二级重名 → 「「父名」下已有同名分类」。
///
/// ⚠️ [existing] 必须传**含隐藏项的全集**（`listAll`）：写库的唯一索引
/// `uq_category_name(COALESCE(parent_id,''),name)` 并不区分隐藏，用可见列表
/// 校验会漏判 —— 走到写库才失败，而各页对 `create` 的返回值并不检查，
/// 界面看起来"成功"了但库里没有。
library;

import 'package:flutter/material.dart';
import 'package:plain/app/l10n/app_strings.dart';
import 'package:plain/app/theme/app_colors.dart';
import 'package:plain/app/theme/design_tokens.dart';
import 'package:plain/design_system/app_toast.dart';
import 'package:plain/design_system/category_icon_picker.dart';
import 'package:plain/domain/entities/category.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/services/category_naming.dart';

/// 用户在弹层里填好、尚未落库的一级分类草稿。
///
/// 空备注统一收敛成 `null`（库里的 `note` 本来就是可空列，别写空串）。
@immutable
class NewRootCategoryDraft {
  const NewRootCategoryDraft({
    required this.kind,
    required this.rootName,
    required this.leafName,
    required this.iconRef,
    this.rootNote,
    this.leafNote,
  });

  final CategoryKind kind;
  final String rootName;
  final String? rootNote;
  final String leafName;
  final String? leafNote;
  final String iconRef;
}

/// 打开「新建一级分类」弹层。确认返回草稿；取消返回 null。
Future<NewRootCategoryDraft?> showCreateRootCategorySheet({
  required BuildContext context,
  required List<Category> existing,
  CategoryKind? lockedKind,
  String submitLabel = '创建',
}) {
  return showModalBottomSheet<NewRootCategoryDraft>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: _CreateRootCategorySheet(
        existing: existing,
        lockedKind: lockedKind,
        submitLabel: submitLabel,
      ),
    ),
  );
}

class _CreateRootCategorySheet extends StatefulWidget {
  const _CreateRootCategorySheet({
    required this.existing,
    required this.submitLabel,
    this.lockedKind,
  });

  final List<Category> existing;
  final CategoryKind? lockedKind;
  final String submitLabel;

  @override
  State<_CreateRootCategorySheet> createState() =>
      _CreateRootCategorySheetState();
}

class _CreateRootCategorySheetState extends State<_CreateRootCategorySheet> {
  CategoryKind _kind = CategoryKind.expense;
  final _rootNameCtrl = TextEditingController();
  final _rootNoteCtrl = TextEditingController();
  final _leafNameCtrl = TextEditingController();
  final _leafNoteCtrl = TextEditingController();
  String _iconRef = 'other';

  @override
  void initState() {
    super.initState();
    _kind = widget.lockedKind ?? CategoryKind.expense;
  }

  // 在 State 里持有 controller 并正常释放：弹层路由要等退场动画走完才销毁
  // 子树，这里的 dispose 一定晚于动画结束，不会撞上「pop 后立刻 dispose」
  // 导致 TextField 重订阅已释放 controller 的坑。
  @override
  void dispose() {
    _rootNameCtrl.dispose();
    _rootNoteCtrl.dispose();
    _leafNameCtrl.dispose();
    _leafNoteCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final rootName = _rootNameCtrl.text.trim();
    final leafName = _leafNameCtrl.text.trim();
    if (rootName.isEmpty || leafName.isEmpty) {
      showAppToast(context, AppStrings.of(context).fillRootAndFirstSubError);
      return;
    }
    final draft = NewRootCategoryDraft(
      kind: _kind,
      rootName: rootName,
      rootNote: _trimmedOrNull(_rootNoteCtrl.text),
      leafName: leafName,
      leafNote: _trimmedOrNull(_leafNoteCtrl.text),
      iconRef: _iconRef,
    );
    final conflict = _conflictOf(draft);
    // 有冲突就停在弹层里让用户改，别先关再报错（输入会丢）。
    if (conflict != null) {
      showAppToast(context, conflict);
      return;
    }
    Navigator.pop(context, draft);
  }

  /// 一级、首个二级各按自己层级查重。
  String? _conflictOf(NewRootCategoryDraft d) {
    final rootConflict = categoryTitleConflictMessage(
      s: AppStrings.of(context),
      all: widget.existing,
      name: d.rootName,
      parentId: null,
      kind: d.kind,
    );
    if (rootConflict != null) return rootConflict;
    // 二级名字在同 kind 内全局唯一（与挂在哪一级无关）→ parentId 传占位值，
    // 命中「「某父」下已有同名分类」而不是「与一级分类同名」。
    return categoryTitleConflictMessage(
      s: AppStrings.of(context),
      all: widget.existing,
      name: d.leafName,
      parentId: 'temp',
      kind: d.kind,
    );
  }

  static String? _trimmedOrNull(String raw) {
    final t = raw.trim();
    return t.isEmpty ? null : t;
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final locked = widget.lockedKind;
    return Padding(
      padding: EdgeInsets.only(
        left: Spacing.lg,
        right: Spacing.lg,
        top: Spacing.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + Spacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(s.newRootCategory, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: Spacing.sm),
            Text(
              s.rootCategoryHint,
              style: TextStyle(fontSize: 12, color: context.colors.inkTertiary),
            ),
            const SizedBox(height: Spacing.lg),
            if (locked == null)
              RadioGroup<CategoryKind>(
                groupValue: _kind,
                onChanged: (v) => setState(() => _kind = v ?? _kind),
                child: Row(
                  children: [
                    Expanded(
                      child: RadioListTile<CategoryKind>(
                        title: Text(s.expense),
                        value: CategoryKind.expense,
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<CategoryKind>(
                        title: Text(s.income),
                        value: CategoryKind.income,
                      ),
                    ),
                  ],
                ),
              )
            else
              Text(
                s.categoryKindLabel(locked == CategoryKind.expense ? s.expense : s.income),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: context.colors.inkSecondary,
                ),
              ),
            const SizedBox(height: Spacing.md),
            TextField(
              controller: _rootNameCtrl,
              maxLength: 6,
              decoration: InputDecoration(
                labelText: s.rootCategoryNameLabel,
                hintText: s.rootCategoryNameHint,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: Spacing.md),
            TextField(
              controller: _rootNoteCtrl,
              maxLength: 30,
              decoration: InputDecoration(
                labelText: s.rootNoteLabel,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: Spacing.md),
            CategoryIconPicker(
              value: _iconRef,
              onChanged: (v) => setState(() => _iconRef = v),
            ),
            const SizedBox(height: Spacing.lg),
            Text(s.firstSubEntryTitle, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: Spacing.sm),
            TextField(
              controller: _leafNameCtrl,
              maxLength: 6,
              decoration: InputDecoration(
                labelText: s.subCategoryNameLabel,
                hintText: s.subCategoryNameHint,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: Spacing.md),
            TextField(
              controller: _leafNoteCtrl,
              maxLength: 30,
              decoration: InputDecoration(
                labelText: s.subNoteLabel,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: Spacing.lg),
            FilledButton(
              onPressed: _submit,
              child: Text(widget.submitLabel),
            ),
          ],
        ),
      ),
    );
  }
}
