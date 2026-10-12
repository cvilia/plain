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
import 'package:plain/domain/services/ai_recognition_service.dart';
import 'package:plain/design_system/emotion_feedback_card.dart';
import 'package:plain/design_system/sound_service.dart';
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

    // STORY-5.4：监听情绪反馈并展示卡片
    ref.listen(entryInputControllerProvider.select((s) => s.emotionFeedback), (prev, next) {
      if (next == null || next == prev) return;
      showEmotionFeedback(context, next, () {
        ref.read(entryInputControllerProvider.notifier).clearEmotion();
      });
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? '编辑账单' : '记一笔'),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        actions: [
          if (!isEdit)
            IconButton(
              icon: const Icon(Icons.document_scanner_outlined),
              tooltip: '识别小票',
              onPressed: () => _showOcrSheet(context, controller),
            ),
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

  /// STORY-9.4：AI 识别记账 — 文本识别 + 额度管理。
  void _showOcrSheet(BuildContext context, EntryInputController controller) {
    final ctrl = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: Spacing.lg, right: Spacing.lg, top: Spacing.lg,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + Spacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('AI 识别记账', style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: Spacing.sm),
            // 额度显示
            FutureBuilder<QuotaStatus>(
              future: AiRecognitionService.getQuota(
                now: DateTime.now(),
                monthStartDay: ref.read(appDependenciesProvider).calendar.monthStartDay,
              ),
              builder: (ctx2, snap) {
                final q = snap.data;
                if (q == null) return const SizedBox.shrink();
                return Text(
                  '本月额度 ${q.displayLabel}',
                  style: TextStyle(fontSize: 11, color: q.isExhausted ? context.colors.expense : context.colors.inkTertiary),
                );
              },
            ),
            const SizedBox(height: Spacing.sm),
            Text('粘贴文字、截图或语音识别结果，自动预填金额和商户。', style: TextStyle(fontSize: 12, color: context.colors.inkTertiary)),
            const SizedBox(height: Spacing.lg),
            TextField(
              controller: ctrl,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: '例如：星巴克 ¥128.50 2026-01-15',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: Spacing.lg),
            FilledButton(
              onPressed: () async {
                final text = ctrl.text.trim();
                if (text.isEmpty) return;
                // 检查额度
                final deps = ref.read(appDependenciesProvider);
                final now = DateTime.now();
                final quota = await AiRecognitionService.getQuota(
                  now: now,
                  monthStartDay: deps.calendar.monthStartDay,
                );
                if (quota.isExhausted) {
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) showAppToast(this.context, '本月额度已用完，下月 ${deps.calendar.monthStartDay} 日恢复');
                  return;
                }
                final draft = AiRecognitionService.parseInput(AiInputType.text, text);
                // 成功识别才消耗额度（AC2）
                if (!draft.isEmpty) {
                  await AiRecognitionService.consumeQuota(
                    now: now,
                    monthStartDay: deps.calendar.monthStartDay,
                  );
                }
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                if (draft.isEmpty) {
                  showAppToast(context, '未能识别，请手动录入');
                  return;
                }
                controller.applyOcrPrefill(
                  amountCents: draft.amountCents,
                  merchant: draft.merchant,
                  occurredAt: draft.occurredAt,
                  categoryHint: draft.categoryHint,
                );
                showAppToast(context, '已预填，请确认或修正');
              },
              child: const Text('识别并预填'),
            ),
          ],
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
        // 错误提示（如「请选择分类」）贴住键盘，减少与键盘的空隙。
        final fontSize = AdaptiveFontSizes.display(context);
        final amountHeight = fontSize + 90;

        // Reserve room for category area + action chips so short screens never overflow.
        const minBottom = 168; // ~2 category rows + attr bar
        // 5 rows × ~40px + gaps is the practical minimum for a usable keypad.
        const minKeypad = 200.0;
        final maxKeypad = (totalHeight - amountHeight - minBottom).clamp(minKeypad, 320.0);
        final keypadHeight = (totalHeight * keypadRatio).clamp(minKeypad, maxKeypad);

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

class _AmountDisplay extends StatefulWidget {
  const _AmountDisplay({required this.controller, required this.state});
  final EntryInputController controller;
  final EntryInputState state;

  @override
  State<_AmountDisplay> createState() => _AmountDisplayState();
}

class _AmountDisplayState extends State<_AmountDisplay> with SingleTickerProviderStateMixin {
  late final AnimationController _shakeCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );
  String? _lastError;

  @override
  void didUpdateWidget(covariant _AmountDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    final err = widget.state.errorMessage;
    if (err == 'amount_over_limit' && _lastError != 'amount_over_limit') {
      _shakeCtrl.forward(from: 0);
    }
    _lastError = err;
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = widget.state;
    final controller = widget.controller;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.md, Spacing.lg, Spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
        // Wrap avoids RenderFlex overflow when the window is narrow
        // (3 chips + gaps exceeded the row width by ~10px).
        Wrap(
          spacing: Spacing.sm,
          runSpacing: Spacing.xs,
          children: [
            _TypeChip(label: '支出', selected: state.type == EntryType.expense, color: context.colors.expense, onTap: () => controller.onTypeChanged(EntryType.expense)),
            _TypeChip(label: '收入', selected: state.type == EntryType.income, color: context.colors.income, onTap: () => controller.onTypeChanged(EntryType.income)),
            _TypeChip(label: '转账', selected: state.type == EntryType.transfer, color: context.colors.transfer, onTap: () => controller.onTypeChanged(EntryType.transfer)),
            _TypeChip(label: '借出', selected: state.type == EntryType.borrowOut, color: context.colors.inkSecondary, onTap: () => controller.onTypeChanged(EntryType.borrowOut)),
            _TypeChip(label: '借入', selected: state.type == EntryType.borrowIn, color: context.colors.inkSecondary, onTap: () => controller.onTypeChanged(EntryType.borrowIn)),
          ],
        ),
        const SizedBox(height: Spacing.sm),
        AnimatedBuilder(
          animation: _shakeCtrl,
          builder: (context, child) {
            final dx = Curves.elasticIn.transform(_shakeCtrl.value) * 12;
            return Transform.translate(offset: Offset(dx, 0), child: child);
          },
          child: Row(
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
        'expression_invalid' => '无法计算',
        'transfer_accounts_required' => '请选择转出与转入账户',
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
    // 产品口径：键盘只保留数字、小数点、退格/清空与 OK（无四则运算）。
    // Rows stretch to the parent keypad region. Fixed 56px rows overflowed
    // when Form A allocated a shorter height (e.g. desktop window).
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
      child: Column(
        children: [
          Expanded(child: _keyRow(context, ['7', '8', '9', '\u232b'])),
          Expanded(child: _keyRow(context, ['4', '5', '6', 'C'])),
          Expanded(child: _keyRow(context, ['1', '2', '3', '.'])),
          Expanded(child: _keyRow(context, ['0', 'OK'])),
        ],
      ),
    );
  }

  Widget _keyRow(BuildContext context, List<String> labels) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        for (final label in labels)
          Expanded(
            flex: label == 'OK' ? 2 : 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: _KeyButton(label: label, onTap: () => _onKey(context, label), isConfirm: label == 'OK'),
            ),
          ),
      ]),
    );
  }

  void _onKey(BuildContext context, String label) {
    switch (label) {
      case '\u232b':
        controller.onBackspace();
      case 'C':
        controller.onClearAll();
      case 'OK':
        // 产品口径：只有 OK 保存；点分类不落库。
        _saveAndToast(context);
      case '.':
        controller.onDot();
      default:
        controller.onDigit(label);
    }
  }

  Future<void> _saveAndToast(BuildContext context) async {
    final ok = await controller.saveExplicit();
    if (!ok || !context.mounted) return;
    // 音效开关打开时播放 coin 声
    playEntrySavedSound(context);
    final msg = controller.currentToast;
    if (msg != null) {
      // STORY-1.1：保存 toast 带「撤销」，5 秒窗口
      final savedId = controller.lastSavedEntryId;
      if (savedId != null) {
        showAppToastWithAction(
          context,
          msg,
          actionLabel: '撤销',
          onAction: () async {
            final undone = await controller.undoLastSaved();
            if (undone && context.mounted) {
              showAppToast(context, '已撤销');
            }
          },
        );
        controller.clearToast();
      } else {
        showAppToast(context, msg);
        controller.clearToast();
      }
    }
    // STORY-5.1：设置项「保存后停留」（默认开）
    if (!controller.stayAfterSave && context.mounted) {
      Navigator.pop(context);
    }
  }
}

class _KeyButton extends StatelessWidget {
  const _KeyButton({required this.label, required this.onTap, this.isConfirm = false});
  final String label;
  final VoidCallback onTap;
  final bool isConfirm;

  @override
  Widget build(BuildContext context) {
    final bg = isConfirm ? context.colors.primary : context.colors.surfaceCard;
    final fg = isConfirm ? context.colors.onPrimary : context.colors.ink;
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
    // G-6 / AC12：转账不走分类宫格，换专属双账户表单（必须 OK 确认）。
    if (state.type == EntryType.transfer) {
      return Column(children: [
        Expanded(child: _TransferForm(controller: controller, state: state)),
        _AttrBar(controller: controller, state: state),
      ]);
    }
    // STORY-1.7：借出/借入走往来对象表单
    if (state.type == EntryType.borrowOut || state.type == EntryType.borrowIn) {
      return Column(children: [
        Expanded(child: _BorrowForm(controller: controller, state: state)),
        _AttrBar(controller: controller, state: state),
      ]);
    }
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

/// 借出/借入：往来对象（备注）+ 约定还款日。
class _BorrowForm extends StatelessWidget {
  const _BorrowForm({required this.controller, required this.state});
  final EntryInputController controller;
  final EntryInputState state;

  @override
  Widget build(BuildContext context) {
    final isOut = state.type == EntryType.borrowOut;
    return Padding(
      padding: const EdgeInsets.all(Spacing.md),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(
          isOut ? '借出往来对象' : '借入往来对象',
          style: TextStyle(fontSize: 12, color: context.colors.inkTertiary),
        ),
        const SizedBox(height: Spacing.sm),
        TextField(
          decoration: const InputDecoration(
            labelText: '往来对象（必填）',
            hintText: '如：张三',
            border: OutlineInputBorder(),
          ),
          onChanged: controller.onNoteChanged,
        ),
        const Spacer(),
        Text(
          '可继续填写备注与日期；保存需点 OK',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: context.colors.inkTertiary),
        ),
      ]),
    );
  }
}

/// 转账专属表单：只选转出/转入账户与备注，不选分类。
class _TransferForm extends ConsumerWidget {
  const _TransferForm({required this.controller, required this.state});
  final EntryInputController controller;
  final EntryInputState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(Spacing.md),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('转账账户', style: TextStyle(fontSize: 12, color: context.colors.inkTertiary)),
        const SizedBox(height: Spacing.sm),
        _AccountRow(
          icon: Icons.arrow_upward_outlined,
          title: '转出账户',
          value: state.selectedAccountId,
          onTap: () => _pickAccount(context, ref, isSource: true),
        ),
        const SizedBox(height: Spacing.sm),
        Center(child: Icon(Icons.arrow_downward, size: 20, color: context.colors.inkTertiary)),
        const SizedBox(height: Spacing.sm),
        _AccountRow(
          icon: Icons.arrow_downward_outlined,
          title: '转入账户',
          value: state.toAccountId,
          onTap: () => _pickAccount(context, ref, isSource: false),
        ),
        const Spacer(),
        Text(
          '转账不计入收支统计，无需选择分类（G-2）',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: context.colors.inkTertiary),
        ),
      ]),
    );
  }

  void _pickAccount(BuildContext context, WidgetRef ref, {required bool isSource}) {
    final db = ref.read(appDependenciesProvider).db;
    final rows = db.raw.select(
      'SELECT id, name, type FROM accounts WHERE deleted_at IS NULL ORDER BY sort_order ASC',
    );
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final r in rows)
              ListTile(
                title: Text((r['name'] as String?) ?? ''),
                subtitle: Text((r['type'] as String?) ?? ''),
                onTap: () {
                  final id = r['id'] as String?;
                  if (isSource) {
                    controller.onAccountSelected(id);
                  } else {
                    controller.onToAccountSelected(id);
                  }
                  Navigator.pop(ctx);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.icon, required this.title, required this.value, required this.onTap});
  final IconData icon;
  final String title;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.surfaceCard,
      borderRadius: BorderRadius.circular(Radii.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.md),
          child: Row(children: [
            Icon(icon, size: 18, color: context.colors.primary),
            const SizedBox(width: Spacing.sm),
            Text(title, style: TextStyle(fontSize: 14, color: context.colors.inkSecondary)),
            const Spacer(),
            Text(value == null ? '请选择' : '已选择', style: TextStyle(fontSize: 14, color: context.colors.ink)),
            Icon(Icons.chevron_right, size: 18, color: context.colors.inkTertiary),
          ]),
        ),
      ),
    );
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
      if (visible.length >= 10) break;
    }
    if (visible.isEmpty) {
      visible.addAll(leaves.take(10));
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
              crossAxisCount: 5,
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
                  // 产品口径（v1.x 修订）：点分类只预选，**必须点 OK 才保存**。
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
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Icon(icon, size: 26, color: selected ? color : context.colors.inkSecondary),
              ),
            ),
            const SizedBox(height: 2),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? color : context.colors.inkSecondary,
                ),
              ),
            ),
          ],
        ),
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
          ] else ...[
            Row(children: [
              _AttrChip(
                icon: Icons.account_balance_wallet_outlined,
                label: state.selectedAccountId != null ? '账户' : '默认账户',
                onTap: () => _showAccountPicker(context, ref, isSource: true),
              ),
              const SizedBox(width: Spacing.sm),
              // STORY-1.8：需报销标记
              _AttrChip(
                icon: Icons.receipt_long_outlined,
                label: '需报销',
                active: state.reimburseStatus == ReimburseStatus.pending,
                onTap: controller.toggleReimburse,
              ),
            ]),
            const SizedBox(height: Spacing.sm),
          ],
          Row(children: [
            _AttrChip(icon: Icons.calendar_today_outlined, label: _dateChipLabel(state.occurredAt, ref.read(appDependenciesProvider).clock.now()), onTap: () => _pickDate(context, ref)),
            const SizedBox(width: Spacing.sm),
            Expanded(child: _AttrChip(icon: Icons.edit_note_outlined, label: state.note ?? '备注', expanded: true, onTap: () => _showNoteSheet(context))),
          ]),
        ],
      ),
    );
  }



  String _dateChipLabel(DateTime? at, DateTime now) {
    if (at == null) return '今天';
    if (isSameLocalDay(at, now)) return '今天';
    return shortDateLabel(at);
  }

  Future<void> _pickDate(BuildContext context, WidgetRef ref) async {
    final now = ref.read(appDependenciesProvider).clock.now().toLocal();
    final picked = await showAppDatePicker(
      context: context,
      initialDate: state.occurredAt?.toLocal() ?? now,
      firstDate: DateTime(2020),
      lastDate: now.add(const Duration(days: 1)),
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
  const _AttrChip({required this.icon, required this.label, required this.onTap, this.expanded = false, this.active = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool expanded;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final bg = active ? context.colors.accent.withValues(alpha: 0.15) : context.colors.surfaceMuted;
    final fg = active ? context.colors.accent : context.colors.inkSecondary;
    final child = Material(
      color: bg,
      borderRadius: BorderRadius.circular(Radii.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.pill),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 6),
            Flexible(
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: fg)),
            ),
          ]),
        ),
      ),
    );
    return child;
  }
}

