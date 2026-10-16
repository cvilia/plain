/// Recurring rules page. See PRD F6.1.
library;

import 'package:plain/app/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:plain/design_system/app_toast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plain/app/bootstrap.dart';
import 'package:plain/app/breakpoints.dart';
import 'package:plain/app/theme/design_tokens.dart';
import 'package:plain/core/format/amount_formatter.dart';
import 'package:plain/core/money/money.dart';
import 'package:plain/core/refresh/data_invalidation.dart';
import 'package:plain/design_system/app_empty_state.dart';
import 'package:plain/design_system/app_error_state.dart';
import 'package:plain/design_system/picker_sheet.dart';
import 'package:plain/design_system/plain_icons_v3.dart';
import 'package:plain/design_system/plain_ui.dart';
import 'package:plain/data/platform/notification_bridge.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/entities/recurring_rule.dart';
import 'package:plain/domain/usecases/recurring_usecases.dart';


final _rulesProvider = FutureProvider<List<RecurringRule>>((ref) async {
  ref.watch(recurringVersionProvider);
  final deps = ref.watch(appDependenciesProvider);
  final res = await deps.recurringRepository.listByBook(deps.bookId);
  return res.successOrNull ?? const [];
});

// 表单选项文案的唯一来源：底部弹层的候选行与字段回显都取自这里，
// 避免出现「选的时候叫每月、显示成 Monthly」这类漂移。
const Map<EntryType, String> _kEntryTypeLabels = {
  EntryType.expense: '支出',
  EntryType.income: '收入',
};

const Map<RecurringFrequency, String> _kFrequencyLabels = {
  RecurringFrequency.daily: '每天',
  RecurringFrequency.weekly: '每周',
  RecurringFrequency.monthly: '每月',
  RecurringFrequency.yearly: '每年',
};

const Map<RecurringEndType, String> _kEndLabels = {
  RecurringEndType.never: '不结束',
  RecurringEndType.count: '生成 N 次后结束',
};

class RecurringPage extends ConsumerStatefulWidget {
  const RecurringPage({super.key});

  @override
  ConsumerState<RecurringPage> createState() => _RecurringPageState();
}

class _RecurringPageState extends ConsumerState<RecurringPage> {

  Future<void> _runDueNow() async {
    await NotificationBridge.requestPermission();
    final deps = ref.read(appDependenciesProvider);
    final res = await deps.generateDueRecurring();
    if (!mounted) return;
    final data = res.successOrNull;
    final count = data?.created.length ?? 0;
    final pending = data?.needConfirm.length ?? 0;
    if (count == 0 && pending == 0) {
      if (!mounted) return;
      showAppToast(context, '当前没有到期的周期记账');
    } else {
      if (count > 0) {
        await NotificationBridge.show(
          id: 9001,
          title: '周期记账已入账',
          body: '已自动生成 $count 笔账单',
        );
      }
      if (pending > 0) {
        await NotificationBridge.show(
          id: 9002,
          title: '周期记账待确认',
          body: '有 $pending 笔到期账单需要你确认入账',
        );
      }
      if (!mounted) return;
      showAppToast(
        context,
        [
          if (count > 0) '已生成 $count 笔',
          if (pending > 0) '$pending 笔待确认',
        ].join('，'),
      );
    }
    ref.invalidateData.bumpEntryMutated();
    ref.invalidateData.bumpRecurringMutated();
    ref.invalidate(_rulesProvider);
  }

  Future<void> _confirmRule(RecurringRule rule, {bool skip = false}) async {
    final deps = ref.read(appDependenciesProvider);
    final res = await deps.confirmRecurringRule(rule, skip: skip);
    if (!mounted) return;
    if (res.isSuccess) {
      ref.invalidateData.bumpEntryMutated();
      ref.invalidateData.bumpRecurringMutated();
      ref.invalidate(_rulesProvider);
      showAppToast(context, skip ? '已跳过本期' : '已确认入账');
    } else {
      showAppToast(context, '操作失败: ${res.failureOrNull?.code ?? 'unknown'}');
    }
  }

  Future<void> _undoLastBatch(RecurringRule rule) async {
    final batchId = rule.lastBatchId;
    if (batchId == null) return;
    final deps = ref.read(appDependenciesProvider);
    final res = await deps.undoRecurringBatch(batchId);
    if (!mounted) return;
    final n = res.successOrNull ?? 0;
    showAppToast(context, n == 0 ? '没有可撤销的账单' : '已撤销 $n 笔账单');
    ref.invalidateData.bumpEntryMutated();
    ref.invalidateData.bumpRecurringMutated();
  }

  Future<void> _create() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const RecurringEditPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hide = ref.watch(hideAmountsProvider);
    final async = ref.watch(_rulesProvider);
    return Scaffold(
      appBar: PlainTopBar(
        title: '周期记账',
        showBack: true,
        actions: [
          PlainTopBarAction(
            icon: PlainIconData.plus,
            tooltip: '新建规则',
            onTap: _create,
          ),
          PlainTopBarAction(
            icon: PlainIconData.play,
            tooltip: '立即执行到期规则',
            onTap: _runDueNow,
          ),
        ],
      ),
      body: ContentWidthConstraint(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => AppErrorState.of(e, onRetry: () => ref.invalidateData.bumpEverything()),
          data: (rules) {
            if (rules.isEmpty) {
              return Center(
                child: AppEmptyState(
                  icon: PlainIconData.recurring,
                  title: '还没有周期记账',
                  subtitle: '房租、订阅、工资都可以自动入账',
                  action: FilledButton.icon(
                    onPressed: _create,
                    icon: const PlainIcon(PlainIconData.plus),
                    label: const Text('新建周期记账'),
                  ),
                ),
              );
            }
            final pending = rules
                .where((r) => !r.autoConfirm && !r.isFinished && !r.nextRunAt.isAfter(ref.read(appDependenciesProvider).clock.now()))
                .toList();
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.md, Spacing.lg, 100),
              itemCount: pending.length + rules.length,
              itemBuilder: (context, i) {
                if (i < pending.length) {
                  return _PendingConfirmTile(
                    rule: pending[i],
                    hide: hide,
                    onConfirm: () => _confirmRule(pending[i]),
                    onSkip: () => _confirmRule(pending[i], skip: true),
                  );
                }
                final rule = rules[i - pending.length];
                return _RuleTile(
                  rule: rule,
                  hide: hide,
                  onUndo: rule.lastBatchId == null ? null : () => _undoLastBatch(rule),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _PendingConfirmTile extends StatelessWidget {
  const _PendingConfirmTile({
    required this.rule,
    required this.hide,
    required this.onConfirm,
    required this.onSkip,
  });

  final RecurringRule rule;
  final bool hide;
  final VoidCallback onConfirm;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final title = rule.name?.isNotEmpty == true ? rule.name! : '周期记账';
    return Card(
      margin: const EdgeInsets.only(bottom: Spacing.sm),
      color: context.colors.primary.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              '${formatAmountYuan(rule.amount.cents, hide: hide)} · 待确认入账',
              style: TextStyle(fontSize: 14, color: context.colors.inkSecondary),
            ),
            const SizedBox(height: Spacing.sm),
            Row(
              children: [
                FilledButton(onPressed: onConfirm, child: const Text('确认入账')),
                const SizedBox(width: Spacing.sm),
                TextButton(onPressed: onSkip, child: const Text('跳过本期')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RuleTile extends StatelessWidget {
  const _RuleTile({required this.rule, required this.hide, this.onUndo});
  final RecurringRule rule;
  final bool hide;
  final VoidCallback? onUndo;

  @override
  Widget build(BuildContext context) {
    final freqLabel = switch (rule.frequency) {
      RecurringFrequency.daily => rule.intervalN == 1 ? '每天' : '每 ${rule.intervalN} 天',
      RecurringFrequency.weekly => rule.intervalN == 1 ? '每周' : '每 ${rule.intervalN} 周',
      RecurringFrequency.monthly =>
        rule.anchorDay == null ? '每月' : '每月 ${rule.anchorDay} 日',
      RecurringFrequency.yearly => '每年',
      RecurringFrequency.interval => '每 ${rule.intervalN} 天',
      RecurringFrequency.unknown => '未知',
    };
    return Card(
      margin: const EdgeInsets.only(bottom: Spacing.sm),
      child: ListTile(
        title: Text(
          rule.name?.isNotEmpty == true ? rule.name! : freqLabel,
          maxLines: 1, overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '$freqLabel · ${formatAmountYuan(rule.amount.cents, hide: hide)}'
          '${rule.isFinished ? ' · 已结束' : (rule.isEnabled ? '' : ' · 已停用')}',
          maxLines: 1, overflow: TextOverflow.ellipsis,
        ),
        trailing: onUndo == null
            ? null
            : IconButton(
                tooltip: '撤销上次生成',
                onPressed: onUndo,
                icon: const PlainIcon(PlainIconData.undo),
              ),
      ),
    );
  }
}

class RecurringEditPage extends ConsumerStatefulWidget {
  const RecurringEditPage({super.key});

  @override
  ConsumerState<RecurringEditPage> createState() => _RecurringEditPageState();
}

class _RecurringEditPageState extends ConsumerState<RecurringEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _anchorCtrl = TextEditingController(text: '1');
  final _intervalCtrl = TextEditingController(text: '1');
  RecurringFrequency _frequency = RecurringFrequency.monthly;
  EntryType _entryType = EntryType.expense;
  bool _autoConfirm = true;
  RecurringEndType _endType = RecurringEndType.never;
  int? _endCount;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _anchorCtrl.dispose();
    _intervalCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final deps = ref.read(appDependenciesProvider);
    final amountCents = Money.parseYuan(_amountCtrl.text.trim()).cents;
    final anchor = int.tryParse(_anchorCtrl.text.trim());
    final interval = int.tryParse(_intervalCtrl.text.trim()) ?? 1;
    final res = await deps.createRecurringRule(CreateRecurringRuleInput(
      bookId: deps.bookId, deviceId: deps.deviceId,
      name: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
      frequency: _frequency, intervalN: interval,
      anchorDay: _frequency == RecurringFrequency.monthly ||
              _frequency == RecurringFrequency.yearly
          ? anchor
          : null,
      autoConfirm: _autoConfirm,
      endType: _endType, endCount: _endCount,
      entryType: _entryType, amountCents: amountCents,
    ));
    if (!mounted) return;
    setState(() => _saving = false);
    if (res.isFailure) {
      showAppToast(context, '保存失败，请检查金额与规则');
      return;
    }
    ref.invalidateData.bumpRecurringMutated();
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PlainTopBar(title: '新建周期记账', showBack: true),
      body: ContentWidthConstraint(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(Spacing.lg),
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: '名称（可选）', hintText: '如：房租'),
                maxLength: 20,
              ),
              TextFormField(
                controller: _amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: '金额', prefixText: '¥ '),
                validator: (v) {
                  final text = (v ?? '').trim();
                  if (text.isEmpty) return '请输入有效金额';
                  try {
                    if (Money.parseYuan(text).cents <= 0) return '请输入有效金额';
                  } on FormatException {
                    return '请输入有效金额';
                  }
                  return null;
                },
              ),
              const SizedBox(height: Spacing.md),
              PickerField(
                label: '类型',
                value: _kEntryTypeLabels[_entryType] ?? '支出',
                onTap: () async {
                  final picked = await showOptionPicker<EntryType>(
                    context: context,
                    title: '类型',
                    current: _entryType,
                    options: [
                      for (final e in _kEntryTypeLabels.entries)
                        PickerOption(value: e.key, label: e.value),
                    ],
                  );
                  if (picked != null) setState(() => _entryType = picked);
                },
              ),
              const SizedBox(height: Spacing.md),
              PickerField(
                label: '频率',
                value: _kFrequencyLabels[_frequency] ?? '每月',
                onTap: () async {
                  final picked = await showOptionPicker<RecurringFrequency>(
                    context: context,
                    title: '频率',
                    current: _frequency,
                    options: [
                      for (final e in _kFrequencyLabels.entries)
                        PickerOption(value: e.key, label: e.value),
                    ],
                  );
                  if (picked != null) setState(() => _frequency = picked);
                },
              ),
              if (_frequency == RecurringFrequency.monthly ||
                  _frequency == RecurringFrequency.yearly)
                TextFormField(
                  controller: _anchorCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '锚定日（1–31）',
                    helperText: '短月自动顺延到月末，如 31 日 → 2 月 28 日',
                  ),
                  validator: (v) {
                    final n = int.tryParse((v ?? '').trim());
                    if (n == null || n < 1 || n > 31) return '请输入 1–31';
                    return null;
                  },
                ),
              if (_frequency == RecurringFrequency.daily)
                TextFormField(
                  controller: _intervalCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '间隔天数'),
                ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('免确认直接入账'),
                subtitle: const Text('关闭后生成的账单可在列表中手动确认'),
                value: _autoConfirm,
                onChanged: (v) => setState(() => _autoConfirm = v),
              ),
              PickerField(
                label: '结束条件',
                value: _kEndLabels[_endType] ?? '不结束',
                onTap: () async {
                  final picked = await showOptionPicker<RecurringEndType>(
                    context: context,
                    title: '结束条件',
                    current: _endType,
                    options: [
                      for (final e in _kEndLabels.entries)
                        PickerOption(value: e.key, label: e.value),
                    ],
                  );
                  if (picked != null) setState(() => _endType = picked);
                },
              ),
              if (_endType == RecurringEndType.count)
                TextFormField(
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '次数'),
                  onChanged: (v) => _endCount = int.tryParse(v.trim()),
                  validator: (v) {
                    if (_endType != RecurringEndType.count) return null;
                    final n = int.tryParse((v ?? '').trim());
                    if (n == null || n <= 0) return '请输入正整数';
                    return null;
                  },
                ),
              const SizedBox(height: Spacing.xl),
              FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: context.colors.primary,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: Text(_saving ? '保存中…' : '保存'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
