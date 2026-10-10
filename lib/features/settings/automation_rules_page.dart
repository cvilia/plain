/// 自动化规则列表（STORY-6.1）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plain/app/bootstrap.dart';
import 'package:plain/app/theme/app_colors.dart';
import 'package:plain/app/theme/design_tokens.dart';
import 'package:plain/core/refresh/data_invalidation.dart';
import 'package:plain/design_system/app_toast.dart';
import 'package:plain/design_system/confirm_dialog.dart';
import 'package:plain/domain/entities/automation_rule.dart';
import 'package:plain/domain/entities/ledger_entry.dart';
import 'package:plain/domain/repositories/repositories.dart';
import 'package:plain/domain/services/rule_applier.dart';
import 'package:plain/domain/services/rule_engine.dart';

class AutomationRulesPage extends ConsumerStatefulWidget {
  const AutomationRulesPage({super.key});

  @override
  ConsumerState<AutomationRulesPage> createState() => _AutomationRulesPageState();
}

class _AutomationRulesPageState extends ConsumerState<AutomationRulesPage> {
  List<AutomationRule> _rules = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final deps = ref.read(appDependenciesProvider);
    final res = await deps.automationRuleRepository.listAll(bookId: deps.bookId);
    if (!mounted) return;
    setState(() {
      _rules = res.successOrNull ?? const [];
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('自动化规则')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_rules_add',
        onPressed: _showCreateSheet,
        icon: const Icon(Icons.add),
        label: const Text('新建规则'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _rules.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(Spacing.xl),
                    child: Text(
                      '还没有自动化规则。\n例如：备注含「星巴克」→ 自动设为餐饮-饮料',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.colors.inkTertiary),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(Spacing.lg),
                  itemCount: _rules.length,
                  separatorBuilder: (_, _) => const SizedBox(height: Spacing.sm),
                  itemBuilder: (context, i) {
                    final r = _rules[i];
                    return Card(
                      child: ListTile(
                        title: Text(r.name ?? '规则 ${i + 1}'),
                        subtitle: Text(
                          _describe(r),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                        onTap: () => _showDryRun(r),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Switch(
                              value: r.isEnabled,
                              onChanged: (v) => _toggle(r, v),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _delete(r),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  String _describe(AutomationRule r) {
    final conds = r.conditions.map((c) {
      final f = switch (c.field) {
        RuleField.amount => '金额',
        RuleField.note => '备注',
        RuleField.merchant => '商户',
        RuleField.accountId => '账户',
        RuleField.categoryId => '分类',
        RuleField.source => '来源',
        RuleField.type => '类型',
        RuleField.unknown => '?',
      };
      return '$f ${c.op.wire} ${c.value}';
    }).join(' AND ');
    final acts = r.actions.map((a) {
      return switch (a.type) {
        RuleActionType.setCategory => '设分类',
        RuleActionType.setAccount => '设账户',
        RuleActionType.setNotePrefix => '备注前缀',
        RuleActionType.setNotInOutflow => '不计入收支',
        RuleActionType.setReimbursable => '待报销',
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
    final ok = await showConfirmDialog(
      context,
      title: '删除规则',
      message: '确定删除该规则？不影响已记账单。',
      confirmLabel: '删除',
      destructive: true,
    );
    if (ok != true || !mounted) return;
    final deps = ref.read(appDependenciesProvider);
    await deps.automationRuleRepository.softDelete(r.id);
    if (!mounted) return;
    showAppToast(context, '已删除');
    _reload();
  }

  /// 试运行：最近账单命中预览，不改数据（AC7）。
  Future<void> _showDryRun(AutomationRule r) async {
    final deps = ref.read(appDependenciesProvider);
    final page = await deps.ledgerRepository.listPage(
      filter: EntryFilter(bookId: deps.bookId),
      limit: 100,
    );
    if (!mounted) return;
    final items = page.successOrNull?.items ?? const <LedgerEntry>[];
    const engine = RuleEngine();
    final hits = engine.dryRun(items, r);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('试运行 · ${r.name ?? '规则'}'),
        content: SizedBox(
          width: double.maxFinite,
          child: hits.isEmpty
              ? const Text('最近 100 笔中没有命中')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: hits.length.clamp(0, 20),
                  itemBuilder: (_, i) {
                    final h = hits[i];
                    final e = h.entry;
                    final t = e.occurredAt.toLocal();
                    return ListTile(
                      dense: true,
                      title: Text(e.note?.isNotEmpty == true ? e.note! : '账单'),
                      subtitle: Text(
                        '${t.month}/${t.day} · ${h.summaries.join('，')}',
                        style: const TextStyle(fontSize: 11),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(hits.isEmpty ? '关闭' : '仅预览，未修改数据'),
          ),
        ],
      ),
    );
  }

  Future<void> _showCreateSheet() async {
    final nameCtrl = TextEditingController(text: '新规则');
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
            left: Spacing.lg,
            right: Spacing.lg,
            top: Spacing.lg,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + Spacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('新建规则（备注 → 分类）', style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: Spacing.md),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: '名称', border: OutlineInputBorder()),
              ),
              const SizedBox(height: Spacing.md),
              TextField(
                controller: noteCtrl,
                decoration: InputDecoration(
                  labelText: '备注关键词',
                  suffixIcon: DropdownButton<String>(
                    value: op,
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(value: 'contains', child: Text('包含')),
                      DropdownMenuItem(value: 'eq', child: Text('等于')),
                    ],
                    onChanged: (v) => setSheet(() => op = v ?? 'contains'),
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: Spacing.md),
              TextField(
                controller: catCtrl,
                decoration: const InputDecoration(
                  labelText: '目标分类 ID（或名称，暂填 ID）',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: Spacing.md),
              OutlinedButton.icon(
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
                icon: const Icon(Icons.visibility_outlined, size: 18),
                label: Text(previewCount == null ? '预览命中数（最近 500 笔）' : '将命中 $previewCount 笔'),
              ),
              const SizedBox(height: Spacing.md),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('回溯历史账单'),
                subtitle: Text(
                  previewCount == null
                      ? '保存后套用到最近 500 笔（默认不回溯）'
                      : '将更新约 $previewCount 笔历史账单',
                  style: const TextStyle(fontSize: 12),
                ),
                value: retroApply,
                onChanged: (v) => setSheet(() => retroApply = v),
              ),
              const SizedBox(height: Spacing.md),
              FilledButton(
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
                    name: nameCtrl.text.trim().isEmpty ? '新规则' : nameCtrl.text.trim(),
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
                  var retroCount = 0;
                  if (retroApply) {
                    final r = await ApplyRuleRetroactively(
                      repository: deps.ledgerRepository,
                    )(bookId: deps.bookId, rule: rule);
                    retroCount = r.successOrNull ?? 0;
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (!mounted) return;
                  showAppToast(
                    context,
                    retroApply ? '规则已创建，已回溯 $retroCount 笔' : '规则已创建',
                  );
                  _reload();
                },
                child: const Text('保存规则'),
              ),
            ],
          ),
        ),
      ),
    );
    if (mounted) ref.invalidateData.bumpEntryMutated();
  }
}
