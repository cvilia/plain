/// Entry input page (SP-1-01). See PRD STORY-1.1.
library;

import 'package:plain/app/theme/app_colors.dart';
import 'package:plain/core/time/date_format.dart';
import 'package:flutter/material.dart';
import 'package:plain/design_system/app_toast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plain/app/bootstrap.dart';
import 'package:plain/app/breakpoints.dart';
import 'package:plain/app/theme/design_tokens.dart';
import 'package:plain/core/constants/app_constants.dart';
import 'package:plain/core/refresh/data_invalidation.dart';
import 'package:plain/design_system/app_date_picker.dart';
import 'package:plain/design_system/category_icons.dart';
import 'package:plain/domain/entities/category.dart' as domain;
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/features/ledger/controllers/entry_input_controller.dart';
import 'package:plain/features/ledger/controllers/recent_categories.dart';
import 'package:plain/features/ledger/presentation/category_picker_page.dart';

final _categoriesProvider = FutureProvider<List<domain.Category>>((ref) async {
  ref.watch(categoriesVersionProvider);
  final repo = ref.watch(categoryRepositoryProvider);
  final result = await repo.listVisible(kind: CategoryKind.expense);
  return result.successOrNull ?? const [];
});



class EntryInputPage extends ConsumerStatefulWidget {
  const EntryInputPage({super.key, this.editEntryId});
  final String? editEntryId;

  @override
  ConsumerState<EntryInputPage> createState() => _EntryInputPageState();
}

class _EntryInputPageState extends ConsumerState<EntryInputPage> {
  @override
  void initState() {
    super.initState();
    if (widget.editEntryId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadForEdit());
    }
  }

  Future<void> _loadForEdit() async {
    final deps = ref.read(appDependenciesProvider);
    final result = await deps.ledgerRepository.getById(widget.editEntryId!);
    final entry = result.successOrNull;
    if (entry != null) {
      ref.read(entryInputControllerProvider.notifier).loadForEdit(entry: entry);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(entryInputControllerProvider);
    final controller = ref.read(entryInputControllerProvider.notifier);
    final categoriesAsync = ref.watch(_categoriesProvider);
    final isEdit = widget.editEntryId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? '编辑账单' : '记一笔'),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        actions: [
          if (isEdit)
            TextButton(
              onPressed: () async {
                final ok = await controller.saveExplicit();
                if (!ok || !context.mounted) return;
                final msg = controller.currentToast;
                if (msg != null) {
                  showAppToast(context, msg);
                  controller.clearToast();
                }
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('保存'),
            ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // FormB trigger: height < 480 OR width >= 600 (§6.1 disjunction)
            final isFormB = Breakpoints.isFormB(
              constraints.maxWidth,
              constraints.maxHeight,
            );
            return isFormB
                ? _buildFormB(controller, state, categoriesAsync)
                : _buildFormA(controller, state, categoriesAsync);
          },
        ),
      ),
    );
  }

  Widget _buildFormA(
    EntryInputController controller,
    EntryInputState state,
    AsyncValue<List<domain.Category>> categoriesAsync,
  ) {
    // Constraint-driven: use LayoutBuilder local constraints, not MediaQuery.size.
    // See 07 §4 L3 rule 1.
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalHeight = constraints.maxHeight;

        // Discrete tiers for keypad: compact height gets taller keypad ratio.
        final isCompactHeight = Breakpoints.isCompactHeight(totalHeight);
        final keypadRatio = isCompactHeight ? 0.45 : 0.38;

        // Amount display: fixed height, scales with font tier.
        final fontSize = AdaptiveFontSizes.display(context);
        final amountHeight = fontSize + 100;

        // Reserve room for category area + action chips so short screens never overflow.
        const minBottom = 168; // ~2 category rows + attr bar
        final maxKeypad = (totalHeight - amountHeight - minBottom).clamp(160.0, 320.0);
        final keypadHeight = (totalHeight * keypadRatio).clamp(160.0, maxKeypad);

        return Column(
          children: [
            SizedBox(
              height: amountHeight,
              child: _AmountDisplay(controller: controller, state: state),
            ),
            SizedBox(
              height: keypadHeight,
              child: _Keypad(controller: controller),
            ),
            Expanded(
              child: _CategoryAndAttrs(
                controller: controller,
                state: state,
                categoriesAsync: categoriesAsync,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFormB(
    EntryInputController controller,
    EntryInputState state,
    AsyncValue<List<domain.Category>> categoriesAsync,
  ) {
    return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(
        flex: 5,
        child: Column(children: [
          _AmountDisplay(controller: controller, state: state),
          Expanded(child: _Keypad(controller: controller)),
        ]),
      ),
      const VerticalDivider(width: 1),
      Expanded(
        flex: 5,
        child: _CategoryAndAttrs(controller: controller, state: state, categoriesAsync: categoriesAsync),
      ),
    ]);
  }
}

class _AmountDisplay extends StatelessWidget {
  const _AmountDisplay({required this.controller, required this.state});
  final EntryInputController controller;
  final EntryInputState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.md, Spacing.lg, Spacing.sm),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Row(children: [
          _TypeChip(label: '支出', selected: state.type == EntryType.expense, color: context.colors.expense, onTap: () => controller.onTypeChanged(EntryType.expense)),
          const SizedBox(width: Spacing.sm),
          _TypeChip(label: '收入', selected: state.type == EntryType.income, color: context.colors.income, onTap: () => controller.onTypeChanged(EntryType.income)),
          const SizedBox(width: Spacing.sm),
          _TypeChip(label: '转账', selected: state.type == EntryType.transfer, color: context.colors.transfer, onTap: () => controller.onTypeChanged(EntryType.transfer)),
          const Spacer(),
        ]),
        const SizedBox(height: Spacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text('\u00a5', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: context.colors.inkTertiary)),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                state.displayAmount.isEmpty ? '0' : state.displayAmount,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: TextStyle(
                  // Discrete tiers: shrink for long amounts (see 07 §4 L4)
                  fontSize: state.displayAmount.length > 12
                      ? AdaptiveFontSizes.display(context) * 0.55
                      : state.displayAmount.length > 8
                          ? AdaptiveFontSizes.display(context) * 0.75
                          : AdaptiveFontSizes.display(context),
                  fontWeight: FontWeight.w600,
                  color: context.colors.ink,
                  height: 1.1,
                ),
              ),
            ),
          ],
        ),
        SizedBox(
          height: 20,
          child: state.errorMessage != null
              ? Text(_errorText(state.errorMessage!), style: theme.textTheme.bodySmall?.copyWith(color: context.colors.expense))
              : state.wasIncompleteExpression
                  ? Text('表达式未闭合', style: theme.textTheme.bodySmall?.copyWith(color: context.colors.inkTertiary))
                  : const SizedBox.shrink(),
        ),
      ]),
    );
  }

  String _errorText(String code) => switch (code) {
        'amount_over_limit' => '金额超出上限',
        'amount_zero' => '请输入金额',
        'category_required' => '请选择分类',
        _ => '输入有误',
      };
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.label, required this.selected, required this.color, required this.onTap});
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: UiDurations.shortAnim,
        padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.xs + 2),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(Radii.pill),
          border: Border.all(color: selected ? color : context.colors.border),
        ),
        child: Text(label, style: TextStyle(fontSize: 13, fontWeight: selected ? FontWeight.w600 : FontWeight.w400, color: selected ? color : context.colors.inkSecondary)),
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({required this.controller});
  final EntryInputController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _keyRow(context, ['7', '8', '9', '\u00f7']),
          _keyRow(context, ['4', '5', '6', '\u00d7']),
          _keyRow(context, ['1', '2', '3', '-']),
          _keyRow(context, ['.', '0', '=', '+']),
          _keyRow(context, ['\u232b', 'C', 'OK']),
        ],
      ),
    );
  }

  Widget _keyRow(BuildContext context, List<String> labels) {
    return SizedBox(
      height: 56,
      child: Row(children: [
        for (final label in labels)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: _KeyButton(label: label, onTap: () => _onKey(context, label), isConfirm: label == 'OK', isEquals: label == '='),
            ),
          ),
        if (labels.length == 3) const Spacer(),
      ]),
    );
  }

  void _onKey(BuildContext context, String label) {
    switch (label) {
      case '\u232b':
        controller.onBackspace();
      case 'C':
        controller.onClearAll();
      case '=':
        controller.onEquals();
      case 'OK':
        _saveAndToast(context);
      case '+' || '-' || '\u00d7' || '\u00f7':
        controller.onOperator(label);
      case '.':
        controller.onDot();
      default:
        controller.onDigit(label);
    }
  }

  Future<void> _saveAndToast(BuildContext context) async {
    final ok = await controller.saveExplicit();
    if (!ok || !context.mounted) return;
    final msg = controller.currentToast;
    if (msg != null) {
      showAppToast(context, msg, bottom: 120);
      controller.clearToast();
    }
  }
}

class _KeyButton extends StatelessWidget {
  const _KeyButton({required this.label, required this.onTap, this.isConfirm = false, this.isEquals = false});
  final String label;
  final VoidCallback onTap;
  final bool isConfirm;
  final bool isEquals;

  @override
  Widget build(BuildContext context) {
    final bg = isConfirm ? context.colors.primary : isEquals ? context.colors.primary.withValues(alpha: 0.12) : context.colors.surfaceCard;
    final fg = isConfirm ? context.colors.onPrimary : isEquals ? context.colors.primary : context.colors.ink;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(Radii.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.sm),
        child: Center(
          child: Text(label, style: TextStyle(fontSize: label.length > 1 ? 16 : 22, fontWeight: FontWeight.w500, color: fg)),
        ),
      ),
    );
  }
}

class _CategoryAndAttrs extends StatelessWidget {
  const _CategoryAndAttrs({required this.controller, required this.state, required this.categoriesAsync});
  final EntryInputController controller;
  final EntryInputState state;
  final AsyncValue<List<domain.Category>> categoriesAsync;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Expanded(
        child: categoriesAsync.when(
          data: (categories) => _CategoryGrid(controller: controller, state: state, categories: categories),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => const Center(child: Text('分类加载失败')),
        ),
      ),
      _AttrBar(controller: controller, state: state),
    ]);
  }
}

class _CategoryGrid extends ConsumerWidget {
  const _CategoryGrid({required this.controller, required this.state, required this.categories});
  final EntryInputController controller;
  final EntryInputState state;
  final List<domain.Category> categories;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Recent-first; first launch falls back to default leaves (by sort order).
    final kind = state.type.wire;
    final recents = ref.watch(recentCategoriesProvider)[kind] ?? const <String>[];
    final leaves = categories.leaves;

    final byId = {for (final c in leaves) c.id: c};
    final visible = <domain.Category>[];
    for (final id in recents) {
      final c = byId[id]; // leaves only — parents never enter the grid
      if (c != null && !visible.contains(c)) visible.add(c);
      if (visible.length >= 7) break;
    }
    if (visible.isEmpty) {
      visible.addAll(leaves.take(7));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Spacing.sm, Spacing.xs, Spacing.sm, 0),
          child: Row(
            children: [
              Text(
                recents.isEmpty ? '默认分类' : '最近使用',
                style: TextStyle(fontSize: 11, color: context.colors.inkTertiary),
              ),
              const Spacer(),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(Spacing.sm),
            physics: const AlwaysScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: Spacing.xs,
              crossAxisSpacing: Spacing.xs,
              childAspectRatio: 1.05,
            ),
            itemCount: visible.length + 1,
            itemBuilder: (context, index) {
              if (index >= visible.length) {
                return _CategoryCell(
                  icon: Icons.more_horiz,
                  label: '更多',
                  selected: false,
                  color: context.colors.inkTertiary,
                  onTap: () async {
                    final result = await Navigator.push<String>(
                      context,
                      MaterialPageRoute(builder: (_) => const CategoryPickerPage()),
                    );
                    if (result != null) {
                      controller.selectCategory(result);
                    }
                  },
                );
              }
              final cat = visible[index];
              final selected = state.selectedCategoryId == cat.id;
              return _CategoryCell(
                icon: iconForCategory(cat.iconRef),
                label: cat.name,
                selected: selected,
                color: context.colors.primary,
                onTap: () {
                  controller.submitOnCategoryTap(cat.id);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CategoryCell extends StatelessWidget {
  const _CategoryCell({required this.icon, required this.label, required this.selected, required this.color, required this.onTap});
  final IconData icon;
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: UiDurations.shortAnim,
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 26, color: selected ? color : context.colors.inkSecondary),
          const SizedBox(height: 4),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, fontWeight: selected ? FontWeight.w600 : FontWeight.w400, color: selected ? color : context.colors.inkSecondary)),
        ]),
      ),
    );
  }
}

class _AttrBar extends ConsumerWidget {
  const _AttrBar({required this.controller, required this.state});
  final EntryInputController controller;
  final EntryInputState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTransfer = state.type == EntryType.transfer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: context.colors.divider))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isTransfer) ...[
            Row(children: [
              Expanded(child: _AttrChip(
                icon: Icons.arrow_upward_outlined,
                label: state.selectedAccountId != null ? '转出账户' : '选择转出',
                onTap: () => _showAccountPicker(context, ref, isSource: true),
              )),
              const SizedBox(width: Spacing.sm),
              Icon(Icons.arrow_forward, size: 16, color: context.colors.inkTertiary),
              const SizedBox(width: Spacing.sm),
              Expanded(child: _AttrChip(
                icon: Icons.arrow_downward_outlined,
                label: state.toAccountId != null ? '转入账户' : '选择转入',
                onTap: () => _showAccountPicker(context, ref, isSource: false),
              )),
            ]),
            const SizedBox(height: Spacing.sm),
          ] else
            Row(children: [
              _AttrChip(
                icon: Icons.account_balance_wallet_outlined,
                label: state.selectedAccountId != null ? '账户' : '默认账户',
                onTap: () => _showAccountPicker(context, ref, isSource: true),
              ),
              const SizedBox(width: Spacing.sm),
            ]),
          Row(children: [
            _AttrChip(icon: Icons.calendar_today_outlined, label: _dateChipLabel(state.occurredAt), onTap: () => _pickDate(context)),
            const SizedBox(width: Spacing.sm),
            Expanded(child: _AttrChip(icon: Icons.edit_note_outlined, label: state.note ?? '备注', expanded: true, onTap: () => _showNoteSheet(context))),
          ]),
        ],
      ),
    );
  }



  String _dateChipLabel(DateTime? at) {
    if (at == null) return '今天';
    if (isSameLocalDay(at, DateTime.now())) return '今天';
    return shortDateLabel(at);
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showAppDatePicker(
      context: context,
      initialDate: state.occurredAt?.toLocal() ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) controller.onDateSelected(picked.toUtc());
  }

  void _showAccountPicker(BuildContext context, WidgetRef ref, {required bool isSource}) {
    final db = ref.read(appDependenciesProvider).db;
    final rows = db.raw.select(
      'SELECT id, name, type FROM accounts WHERE deleted_at IS NULL ORDER BY sort_order ASC',
    );

    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(Spacing.lg),
              child: Text(isSource ? '选择账户' : '选择转入账户', style: Theme.of(ctx).textTheme.titleMedium),
            ),
            ListTile(
              leading: const Icon(Icons.remove_circle_outline),
              title: const Text('不指定账户'),
              onTap: () {
                if (isSource) {
                  controller.onAccountSelected(null);
                } else {
                  controller.onToAccountSelected(null);
                }
                Navigator.pop(ctx);
              },
            ),
            ...rows.map((row) {
              final id = row['id']! as String;
              final name = row['name']! as String;
              final type = row['type']! as String;
              return ListTile(
                leading: Icon(type == 'cash' ? Icons.payments_outlined : Icons.credit_card_outlined),
                title: Text(name),
                onTap: () {
                  if (isSource) {
                    controller.onAccountSelected(id);
                  } else {
                    controller.onToAccountSelected(id);
                  }
                  Navigator.pop(ctx);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showNoteSheet(BuildContext context) {
    final textCtrl = TextEditingController(text: state.note ?? '');
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: const Text('备注'),
        content: TextField(
          controller: textCtrl,
          autofocus: true,
          maxLines: 3,
          maxLength: 100,
          decoration: const InputDecoration(hintText: '写点什么...', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              controller.onNoteChanged(textCtrl.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}

class _AttrChip extends StatelessWidget {
  const _AttrChip({required this.icon, required this.label, required this.onTap, this.expanded = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final child = Material(
      color: context.colors.surfaceMuted,
      borderRadius: BorderRadius.circular(Radii.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.pill),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 16, color: context.colors.inkSecondary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: context.colors.inkSecondary)),
            ),
          ]),
        ),
      ),
    );
    return child;
  }
}

