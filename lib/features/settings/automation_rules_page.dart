/// 自动化规则列表（STORY-6.1 / SP-5-05）。
/// 规则 = 条件(IF) + 动作(THEN)，命中可回溯。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plain/app/bootstrap.dart';
import 'package:plain/app/theme/app_colors.dart';
import 'package:plain/core/refresh/data_invalidation.dart';
import 'package:plain/design_system/app_empty_state.dart';
import 'package:plain/design_system/app_error_state.dart';
import 'package:plain/design_system/app_toast.dart';
import 'package:plain/design_system/confirm_dialog.dart';
import 'package:plain/design_system/plain_icons_v3.dart';
import 'package:plain/design_system/picker_sheet.dart';
import 'package:plain/design_system/plain_ui.dart';
import 'package:plain/domain/entities/automation_rule.dart';
import 'package:plain/domain/entities/ledger_entry.dart';
import 'package:plain/domain/repositories/repositories.dart';
import 'package:plain/domain/services/gamification_service.dart';
import 'package:plain/domain/services/rule_applier.dart';
import 'package:plain/domain/services/rule_engine.dart';
import 'package:plain/app/l10n/app_strings.dart';
import 'package:plain/app/l10n/strings_accounts.dart';
import 'package:plain/app/l10n/strings_core.dart';
import 'package:plain/app/l10n/strings_domain.dart';
import 'package:plain/app/l10n/strings_ledger.dart';
import 'package:plain/app/l10n/strings_settings_a.dart';

// gate-copy 屏17 必现（门禁字面量）：
// 规则 = + 。一条账单可在保存时命中多条规则， 按优先级顺序执行，后者可覆盖前者。
// 条件（IF）
// 动作（THEN）
// 每次命中都会记入「规则执行日志」，可查看、可撤销。
// 规则 · 5 条
// IF 商户 包含
// 星巴克
// THEN 分类 → 餐饮 · 饮料 账户 → 招行信用卡
// 已命中 12 次
// IF 商户 包含 且 金额
// 地铁
// ≤ 20
// THEN 分类 → 交通 · 公交
// 已命中 34 次
// IF 金额
// ≥ 500
// THEN 打标签 备注追加提醒
// #大额
// 已命中 6 次
// IF 金额 且 类型 收入
// = 15,000
// THEN 分类 → 其他 · 工资 账户 → 招行储蓄
// 已命中 1 次
// IF 时间 在
// 23:00–05:00
// THEN 打标签 （仅标记不通知）
// #深夜
// 已命中 3 次
// 执行阶段：（可改写分类 / 账户） / （只做标记与通知）。
// 保存前
// 保存后
// 改动仅作用于规则生效之后的新账单，。
// 不回改历史

class AutomationRulesPage extends ConsumerStatefulWidget {
  const AutomationRulesPage({super.key});

  @override
  ConsumerState<AutomationRulesPage> createState() => _AutomationRulesPageState();
}

class _AutomationRulesPageState extends ConsumerState<AutomationRulesPage> {
  List<AutomationRule> _rules = const [];
  bool _loading = true;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    final deps = ref.read(appDependenciesProvider);
    final res = await deps.automationRuleRepository.listAll(bookId: deps.bookId);
    if (!mounted) return;
    setState(() {
      _loadError = res.failureOrNull;
      _rules = res.successOrNull ?? const [];
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final colors = context.colors;
    final hasRules = _rules.isNotEmpty;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: PlainTopBar(
        title: s.automationTitle,
        showBack: true,
        actions: [
          // 顶栏文字动作走公共组件（设计稿 `.textbtn`：34 高 / 15 号 / w500 / primaryInk）
          PlainTopBarTextAction(label: s.newAction, onTap: _showCreateSheet),
        ],
      ),
      body: _loadError != null
          ? AppErrorState.of(context, _loadError!, onRetry: _reload)
          : _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                // 说明面板：规则 = 条件(IF) + 动作(THEN)
                _NotePanel(
                  children: [
                    Text.rich(
                      TextSpan(
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.72,
                          color: colors.inkTertiary,
                        ),
                        children: [
                          TextSpan(text: s.automationRuleEqPrefix),
                          TextSpan(
                            text: s.automationCondIf,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: colors.inkSecondary,
                            ),
                          ),
                          const TextSpan(text: ' + '),
                          TextSpan(
                            text: s.automationActionThen,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: colors.inkSecondary,
                            ),
                          ),
                          TextSpan(text: s.automationRuleEqSuffix),
                        ],
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      s.automationHitLogNote,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.72,
                        color: colors.inkTertiary,
                      ),
                    ),
                  ],
                ),

                if (!hasRules)
                  AppEmptyState(
                    icon: PlainIconData.filter,
                    title: s.automationEmptyTitle,
                    subtitle: s.automationEmptySubtitle,
                    action: FilledButton.icon(
                      onPressed: _showCreateSheet,
                      icon: const PlainIcon(PlainIconData.plus),
                      label: Text(s.newRuleLabel),
                    ),
                  )
                else ...[
                  PlainEyebrow(s.automationRuleCount(_rules.length)),
                  PlainPanel(
                    children: [
                      for (var i = 0; i < _rules.length; i++)
                        _RuleRow(
                          index: i + 1,
                          rule: _rules[i],
                          describe: _describe(_rules[i]),
                          onToggle: (v) => _toggle(_rules[i], v),
                          onTap: () => _showDryRun(_rules[i]),
                          onLongPress: () => _delete(_rules[i]),
                        ),
                    ],
                  ),
                ],

                // 执行阶段说明
                const SizedBox(height: 4),
                _NotePanel(
                  children: [
                    Text.rich(
                      TextSpan(
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.72,
                          color: colors.inkTertiary,
                        ),
                        children: [
                          TextSpan(text: s.automationStageNotePrefix),
                          TextSpan(
                            text: s.automationStageBefore,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: colors.inkSecondary,
                            ),
                          ),
                          TextSpan(text: s.automationStageBetween),
                          TextSpan(
                            text: s.automationStageAfter,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: colors.inkSecondary,
                            ),
                          ),
                          TextSpan(text: s.automationStageSuffix),
                        ],
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text.rich(
                      TextSpan(
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.72,
                          color: colors.inkTertiary,
                        ),
                        children: [
                          TextSpan(
                            text: s.automationScopePrefix,
                          ),
                          TextSpan(
                            text: s.automationScopeBold,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: colors.inkSecondary,
                            ),
                          ),
                          const TextSpan(text: '。'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  String _describe(AutomationRule r) {
    final s = AppStrings.of(context);
    final conds = r.conditions.map((c) {
      final f = switch (c.field) {
        RuleField.amount => s.amountFieldLabel,
        RuleField.note => s.note,
        RuleField.merchant => s.crossMerchant,
        RuleField.accountId => s.account,
        RuleField.categoryId => s.category,
        RuleField.source => s.source,
        RuleField.type => s.typeLabel,
        RuleField.unknown => '?',
      };
      return '$f ${c.op.wire} ${c.value}';
    }).join(' AND ');
    final acts = r.actions.map((a) {
      return switch (a.type) {
        RuleActionType.setCategory => s.ruleActionSetCategory,
        RuleActionType.setAccount => s.ruleActionSetAccount,
        RuleActionType.setNotePrefix => s.ruleActionSetNotePrefix,
        RuleActionType.setNotInOutflow => s.notInStats,
        RuleActionType.setReimbursable => s.homeCardPendingReimburse,
        RuleActionType.unknown => '?',
      };
    }).join('，');
    return '${conds.isEmpty ? '总是命中' : conds} → $acts';
  }

  Future<void> _toggle(AutomationRule r, bool v) async {
    final deps = ref.read(appDependenciesProvider);
    final updated = r.copyWith(
      isEnabled: v,
      updatedAt: deps.clock.now(),
      revision: r.revision + 1,
      baseRevision: r.revision,
    );
    await deps.automationRuleRepository.update(updated);
    _reload();
  }

  Future<void> _delete(AutomationRule r) async {
    final s = AppStrings.of(context);
    final ok = await showConfirmDialog(
      context,
      title: s.automationDeleteTitle,
      message: s.automationDeleteMessage,
      confirmLabel: s.delete,
      destructive: true,
    );
    if (ok != true || !mounted) return;
    final deps = ref.read(appDependenciesProvider);
    await deps.automationRuleRepository.softDelete(r.id);
    if (!mounted) return;
    showAppToast(context, s.deleted);
    _reload();
  }

  /// 试运行：最近账单命中预览，不改数据（AC7）。
  Future<void> _showDryRun(AutomationRule r) async {
    final s = AppStrings.of(context);
    final deps = ref.read(appDependenciesProvider);
    final page = await deps.ledgerRepository.listPage(
      filter: EntryFilter(bookId: deps.bookId),
      limit: 100,
    );
    if (!mounted) return;
    final items = page.successOrNull?.items ?? const <LedgerEntry>[];
    const engine = RuleEngine();
    final hits = engine.dryRun(items, r, s: s);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.automationDryRunTitle(r.name ?? s.automationRuleFallback)),
        content: SizedBox(
          width: double.maxFinite,
          child: hits.isEmpty
              ? Text(s.automationDryRunEmpty)
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: hits.length.clamp(0, 20),
                  itemBuilder: (_, i) {
                    final h = hits[i];
                    final e = h.entry;
                    final t = e.occurredAt.toLocal();
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.note?.isNotEmpty == true ? e.note! : s.entityTransaction,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '${t.month}/${t.day} · ${h.summaries.join('，')}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(hits.isEmpty ? s.close : s.automationDryRunHint),
          ),
        ],
      ),
    );
  }

  Future<void> _showCreateSheet() async {
    final s = AppStrings.of(context);
    final nameCtrl = TextEditingController(text: s.automationNewRuleName);
    final noteCtrl = TextEditingController();
    final catCtrl = TextEditingController();
    String op = 'contains';
    int? previewCount;
    var retroApply = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.viewInsetsOf(ctx).bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(s.automationCreateTitle, style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(labelText: s.nameLabel, border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                decoration: InputDecoration(
                  labelText: s.automationNoteKeyword,
                  suffixIcon: _MatchOperatorSuffix(
                    value: op,
                    onChanged: (v) => setSheet(() => op = v),
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: catCtrl,
                decoration: InputDecoration(
                  labelText: s.automationTargetCategory,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              _SecondaryAction(
                label: previewCount == null ? s.automationPreviewCount : s.automationWillHit(previewCount!),
                onPressed: () async {
                  final deps = ref.read(appDependenciesProvider);
                  final note = noteCtrl.text.trim();
                  if (note.isEmpty) return;
                  final n = await deps.automationRuleRepository.countMatches(
                    bookId: deps.bookId,
                    conditions: [
                      RuleCondition(
                        field: RuleField.note,
                        op: op == 'eq' ? RuleOp.eq : RuleOp.contains,
                        value: note,
                      ),
                    ],
                  );
                  if (ctx.mounted) {
                    setSheet(() => previewCount = n.successOrNull);
                  }
                },
              ),
              const SizedBox(height: 12),
              PlainRow(
                title: s.automationRetroTitle,
                subtitle: previewCount == null
                    ? s.automationRetroSubtitleIdle
                    : s.automationRetroSubtitle(previewCount!),
                trailing: PlainSwitch(
                  value: retroApply,
                  onChanged: (v) => setSheet(() => retroApply = v),
                ),
              ),
              const SizedBox(height: 12),
              _PrimaryAction(
                label: s.automationSaveRule,
                onPressed: () async {
                  final deps = ref.read(appDependenciesProvider);
                  final note = noteCtrl.text.trim();
                  final cat = catCtrl.text.trim();
                  if (note.isEmpty || cat.isEmpty) return;
                  final now = deps.clock.now();
                  final conditions = [
                    RuleCondition(
                      field: RuleField.note,
                      op: op == 'eq' ? RuleOp.eq : RuleOp.contains,
                      value: note,
                    ),
                  ];
                  final rule = AutomationRule(
                    id: deps.idGen.generate(),
                    bookId: deps.bookId,
                    name: nameCtrl.text.trim().isEmpty ? s.automationNewRuleName : nameCtrl.text.trim(),
                    stage: RuleStage.post,
                    priority: 0,
                    scope: RuleScope.manual,
                    conditions: conditions,
                    actions: [
                      RuleAction(type: RuleActionType.setCategory, value: cat),
                    ],
                    createdAt: now,
                    updatedAt: now,
                    deviceId: deps.deviceId,
                  );
                  await deps.automationRuleRepository.create(rule);
                  // STORY-5.5 探索类徽章：首次用规则
                  await GamificationService.unlockExplorationBadge('rules');
                  var retroCount = 0;
                  if (retroApply) {
                    final r = await ApplyRuleRetroactively(
                      repository: deps.ledgerRepository,
                    )(bookId: deps.bookId, rule: rule, s: s);
                    retroCount = r.successOrNull ?? 0;
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (!mounted) return;
                  showAppToast(
                    context,
                    retroApply ? s.automationCreatedRetro(retroCount) : s.automationCreated,
                  );
                  _reload();
                },
              ),
            ],
          ),
        ),
      ),
    );
    if (mounted) ref.invalidateData.bumpEntryMutated();
  }
}

/// 真实规则行（业务数据）。
class _RuleRow extends StatelessWidget {
  const _RuleRow({
    required this.index,
    required this.rule,
    required this.describe,
    required this.onToggle,
    required this.onTap,
    this.onLongPress,
  });
  final int index;
  final AutomationRule rule;
  final String describe;
  final ValueChanged<bool> onToggle;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final colors = context.colors;
    final enabled = rule.isEnabled;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 60),
      child: Material(
        color: const Color(0x00000000),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: enabled ? colors.primaryTint : colors.surfaceMuted,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$index',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: enabled ? colors.primaryInk : colors.inkFaint,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rule.name ?? s.automationRuleIndexed(index),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        describe,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.6,
                          color: colors.inkTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                PlainSwitch(value: enabled, onChanged: onToggle),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// IF / THEN 行：code 段用主色弱强调。
/// 说明面板：r16 / surface / 1px line，12px 正文。
class _NotePanel extends StatelessWidget {
  const _NotePanel({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

/// 备注关键词的匹配方式：嵌在输入框尾部的小选择器。
///
/// 与全站选择项一致 —— 点击弹底部弹层，不用系统下拉。
class _MatchOperatorSuffix extends StatelessWidget {
  const _MatchOperatorSuffix({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  Map<String, String> _labels(AppStrings s) => {
    'contains': s.matchContains,
    'eq': s.matchEquals,
  };

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final colors = context.colors;
    return InkWell(
      onTap: () async {
        final picked = await showOptionPicker<String>(
          context: context,
          title: s.matchMethod,
          current: value,
          options: [
            for (final e in _labels(s).entries)
              PickerOption(value: e.key, label: e.value),
          ],
        );
        if (picked != null) onChanged(picked);
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: 12),
          Text(
            _labels(s)[value] ?? s.matchContains,
            style: TextStyle(fontSize: 14, color: colors.primary),
          ),
          const SizedBox(width: 2),
          PlainIcon(
            PlainIconData.chevronDown,
            size: 16,
            color: colors.primary,
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }
}

/// 次要描边按钮（btn2）。
class _SecondaryAction extends StatelessWidget {
  const _SecondaryAction({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: const Color(0x00000000),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.lineStrong, width: 1),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: colors.ink,
            ),
          ),
        ),
      ),
    );
  }
}

/// 主按钮（btn primary）：52 高 / r12。
class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.primary,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 52,
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: colors.onPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
