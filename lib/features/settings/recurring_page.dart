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
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/entities/recurring_rule.dart';
import 'package:plain/domain/usecases/recurring_usecases.dart';


final _rulesProvider = FutureProvider<List<RecurringRule>>((ref) async {
  ref.watch(recurringVersionProvider);
  final deps = ref.watch(appDependenciesProvider);
  final res = await deps.recurringRepository.listByBook(deps.bookId);
  return res.successOrNull ?? const [];
});

class RecurringPage extends ConsumerStatefulWidget {
  const RecurringPage({super.key});

  @override
  ConsumerState<RecurringPage> createState() => _RecurringPageState();
}

class _RecurringPageState extends ConsumerState<RecurringPage> {

  Future<void> _runDueNow() async {
    final deps = ref.read(appDependenciesProvider);
    final res = await deps.generateDueRecurring();
    if (!mounted) return;
    final count = res.successOrNull?.created.length ?? 0;
    showAppToast(context, count == 0 ? '当前没有到期的周期记账' : '已生成 $count 笔账单');
    ref.invalidateData.bumpEntryMutated();
    ref.invalidateData.bumpRecurringMutated();
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
      appBar: AppBar(
        title: const Text('周期记账'),
        actions: [
          IconButton(
            tooltip: '立即执行到期规则',
            onPressed: _runDueNow,
            icon: const Icon(Icons.play_arrow),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_recurring_add',
        onPressed: _create,
        backgroundColor: context.colors.primary,
        foregroundColor: context.colors.onPrimary,
        icon: const Icon(Icons.add),
        label: const Text('新建规则'),
      ),
      body: ContentWidthConstraint(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('加载失败: $e')),
          data: (rules) => rules.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(Spacing.xl),
                      child: Text(
                        '还没有周期记账。\n房租、订阅、工资都可以自动入账。',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: context.colors.inkTertiary, fontSize: AdaptiveFontSizes.body),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.md, Spacing.lg, 100),
                    itemCount: rules.length,
                    itemBuilder: (context, i) => _RuleTile(
                      rule: rules[i], hide: hide,
                      onUndo: rules[i].lastBatchId == null
                          ? null
                          : () => _undoLastBatch(rules[i]),
                    ),
                  ),
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
                icon: const Icon(Icons.undo),
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
      appBar: AppBar(title: const Text('新建周期记账')),
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
              DropdownButtonFormField<EntryType>(
                initialValue: _entryType,
                decoration: const InputDecoration(labelText: '类型'),
                items: const [
                  DropdownMenuItem(value: EntryType.expense, child: Text('支出')),
                  DropdownMenuItem(value: EntryType.income, child: Text('收入')),
                ],
                onChanged: (v) => setState(() => _entryType = v ?? EntryType.expense),
              ),
              const SizedBox(height: Spacing.md),
              DropdownButtonFormField<RecurringFrequency>(
                initialValue: _frequency,
                decoration: const InputDecoration(labelText: '频率'),
                items: const [
                  DropdownMenuItem(value: RecurringFrequency.daily, child: Text('每天')),
                  DropdownMenuItem(value: RecurringFrequency.weekly, child: Text('每周')),
                  DropdownMenuItem(value: RecurringFrequency.monthly, child: Text('每月')),
                  DropdownMenuItem(value: RecurringFrequency.yearly, child: Text('每年')),
                ],
                onChanged: (v) => setState(() => _frequency = v ?? RecurringFrequency.monthly),
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
              DropdownButtonFormField<RecurringEndType>(
                initialValue: _endType,
                decoration: const InputDecoration(labelText: '结束条件'),
                items: const [
                  DropdownMenuItem(value: RecurringEndType.never, child: Text('不结束')),
                  DropdownMenuItem(value: RecurringEndType.count, child: Text('生成 N 次后结束')),
                ],
                onChanged: (v) => setState(() => _endType = v ?? RecurringEndType.never),
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
