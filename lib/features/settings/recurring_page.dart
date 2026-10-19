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
import 'package:plain/app/l10n/app_strings.dart';
import 'package:plain/app/l10n/strings_accounts.dart';
import 'package:plain/app/l10n/strings_domain.dart';
import 'package:plain/app/l10n/strings_settings_a.dart';
import 'package:plain/app/l10n/strings_ledger.dart';


final _rulesProvider = FutureProvider<List<RecurringRule>>((ref) async {
  ref.watch(recurringVersionProvider);
  final deps = ref.watch(appDependenciesProvider);
  final res = await deps.recurringRepository.listByBook(deps.bookId);
  return res.successOrNull ?? const [];
});

// 表单选项文案的唯一来源：底部弹层的候选行与字段回显都取自这里，
// 避免出现「选的时候叫每月、显示成 Monthly」这类漂移。
Map<EntryType, String> _entryTypeLabels(AppStrings s) => {
  EntryType.expense: s.expense,
  EntryType.income: s.income,
};

Map<RecurringFrequency, String> _frequencyLabels(AppStrings s) => {
  RecurringFrequency.daily: s.recurringFreqDaily,
  RecurringFrequency.weekly: s.recurringFreqWeekly,
  RecurringFrequency.monthly: s.recurringFreqMonthly,
  RecurringFrequency.yearly: s.recurringFreqYearly,
};

Map<RecurringEndType, String> _endLabels(AppStrings s) => {
  RecurringEndType.never: s.recurringEndNever,
  RecurringEndType.count: s.recurringEndCount,
};

class RecurringPage extends ConsumerStatefulWidget {
  const RecurringPage({super.key});

  @override
  ConsumerState<RecurringPage> createState() => _RecurringPageState();
}

class _RecurringPageState extends ConsumerState<RecurringPage> {

  Future<void> _runDueNow() async {
    final s = AppStrings.of(context);
    await NotificationBridge.requestPermission();
    final deps = ref.read(appDependenciesProvider);
    final res = await deps.generateDueRecurring(s: s);
    if (!mounted) return;
    final data = res.successOrNull;
    final count = data?.created.length ?? 0;
    final pending = data?.needConfirm.length ?? 0;
    if (count == 0 && pending == 0) {
      if (!mounted) return;
      showAppToast(context, s.recurringNoDue);
    } else {
      if (count > 0) {
        await NotificationBridge.show(
          id: 9001,
          title: s.recurringPostedTitle,
          body: s.recurringPostedBody(count),
        );
      }
      if (pending > 0) {
        await NotificationBridge.show(
          id: 9002,
          title: s.recurringPendingTitle,
          body: s.recurringPendingBody(pending),
        );
      }
      if (!mounted) return;
      showAppToast(
        context,
        [
          if (count > 0) s.recurringToastGenerated(count),
          if (pending > 0) s.recurringToastPending(pending),
        ].join('，'),
      );
    }
    ref.invalidateData.bumpEntryMutated();
    ref.invalidateData.bumpRecurringMutated();
    ref.invalidate(_rulesProvider);
  }

  Future<void> _confirmRule(RecurringRule rule, {bool skip = false}) async {
    final s = AppStrings.of(context);
    final deps = ref.read(appDependenciesProvider);
    final res = await deps.confirmRecurringRule(rule,
        skip: skip, s: AppStrings.of(context));
    if (!mounted) return;
    if (res.isSuccess) {
      ref.invalidateData.bumpEntryMutated();
      ref.invalidateData.bumpRecurringMutated();
      ref.invalidate(_rulesProvider);
      showAppToast(context, skip ? s.recurringSkipped : s.recurringConfirmed);
    } else {
      showAppToast(context,
          s.recurringOpFailed(res.failureOrNull?.code ?? 'unknown'));
    }
  }

  Future<void> _undoLastBatch(RecurringRule rule) async {
    final s = AppStrings.of(context);
    final batchId = rule.lastBatchId;
    if (batchId == null) return;
    final deps = ref.read(appDependenciesProvider);
    final res = await deps.undoRecurringBatch(batchId);
    if (!mounted) return;
    final n = res.successOrNull ?? 0;
    showAppToast(context, n == 0 ? s.recurringNothingToUndo : s.recurringUndone(n));
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
    final s = AppStrings.of(context);
    final hide = ref.watch(hideAmountsProvider);
    final async = ref.watch(_rulesProvider);
    return Scaffold(
      appBar: PlainTopBar(
        title: s.actionLogEntityRecurring,
        showBack: true,
        actions: [
          PlainTopBarAction(
            icon: PlainIconData.plus,
            tooltip: s.newRuleLabel,
            onTap: _create,
          ),
          PlainTopBarAction(
            icon: PlainIconData.play,
            tooltip: s.recurringRunDueTooltip,
            onTap: _runDueNow,
          ),
        ],
      ),
      body: ContentWidthConstraint(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => AppErrorState.of(context, e, onRetry: () => ref.invalidateData.bumpEverything()),
          data: (rules) {
            if (rules.isEmpty) {
              return Center(
                child: AppEmptyState(
                  icon: PlainIconData.recurring,
                  title: s.recurringEmptyTitle,
                  subtitle: s.recurringEmptySubtitle,
                  action: FilledButton.icon(
                    onPressed: _create,
                    icon: const PlainIcon(PlainIconData.plus),
                    label: Text(s.recurringNewTitle),
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
    final s = AppStrings.of(context);
    final title = rule.name?.isNotEmpty == true ? rule.name! : s.actionLogEntityRecurring;
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
              s.recurringPendingSuffix(formatAmountYuan(rule.amount.cents, hide: hide)),
              style: TextStyle(fontSize: 14, color: context.colors.inkSecondary),
            ),
            const SizedBox(height: Spacing.sm),
            Row(
              children: [
                FilledButton(onPressed: onConfirm, child: Text(s.recurringConfirmAction)),
                const SizedBox(width: Spacing.sm),
                TextButton(onPressed: onSkip, child: Text(s.recurringSkipAction)),
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
    final s = AppStrings.of(context);
    final freqLabel = switch (rule.frequency) {
      RecurringFrequency.daily => rule.intervalN == 1 ? s.recurringFreqDaily : s.recurringEveryDays(rule.intervalN),
      RecurringFrequency.weekly => rule.intervalN == 1 ? s.recurringFreqWeekly : s.recurringEveryWeeks(rule.intervalN),
      RecurringFrequency.monthly =>
        rule.anchorDay == null ? s.recurringFreqMonthly : s.recurringMonthlyOnDay(rule.anchorDay!),
      RecurringFrequency.yearly => s.recurringFreqYearly,
      RecurringFrequency.interval => s.recurringEveryDays(rule.intervalN),
      RecurringFrequency.unknown => s.entryUnknown,
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
                tooltip: s.recurringUndoTooltip,
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
    final s = AppStrings.of(context);
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
      showAppToast(context, s.recurringSaveFailed);
      return;
    }
    ref.invalidateData.bumpRecurringMutated();
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Scaffold(
      appBar: PlainTopBar(title: s.recurringNewTitle, showBack: true),
      body: ContentWidthConstraint(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(Spacing.lg),
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: InputDecoration(labelText: s.recurringNameLabel, hintText: s.recurringNameHint),
                maxLength: 20,
              ),
              TextFormField(
                controller: _amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: s.amountFieldLabel, prefixText: '¥ '),
                validator: (v) {
                  final text = (v ?? '').trim();
                  if (text.isEmpty) return s.recurringInvalidAmount;
                  try {
                    if (Money.parseYuan(text).cents <= 0) return s.recurringInvalidAmount;
                  } on FormatException {
                    return s.recurringInvalidAmount;
                  }
                  return null;
                },
              ),
              const SizedBox(height: Spacing.md),
              PickerField(
                label: s.typeLabel,
                value: _entryTypeLabels(s)[_entryType] ?? s.expense,
                onTap: () async {
                  final picked = await showOptionPicker<EntryType>(
                    context: context,
                    title: s.typeLabel,
                    current: _entryType,
                    options: [
                      for (final e in _entryTypeLabels(s).entries)
                        PickerOption(value: e.key, label: e.value),
                    ],
                  );
                  if (picked != null) setState(() => _entryType = picked);
                },
              ),
              const SizedBox(height: Spacing.md),
              PickerField(
                label: s.recurringFrequencyLabel,
                value: _frequencyLabels(s)[_frequency] ?? s.recurringFreqMonthly,
                onTap: () async {
                  final picked = await showOptionPicker<RecurringFrequency>(
                    context: context,
                    title: s.recurringFrequencyLabel,
                    current: _frequency,
                    options: [
                      for (final e in _frequencyLabels(s).entries)
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
                  decoration: InputDecoration(
                    labelText: s.recurringAnchorLabel,
                    helperText: s.recurringAnchorHelper,
                  ),
                  validator: (v) {
                    final n = int.tryParse((v ?? '').trim());
                    if (n == null || n < 1 || n > 31) return s.recurringAnchorInvalid;
                    return null;
                  },
                ),
              if (_frequency == RecurringFrequency.daily)
                TextFormField(
                  controller: _intervalCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: s.recurringIntervalLabel),
                ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(s.recurringAutoConfirmTitle),
                subtitle: Text(s.recurringAutoConfirmSubtitle),
                value: _autoConfirm,
                onChanged: (v) => setState(() => _autoConfirm = v),
              ),
              PickerField(
                label: s.recurringEndLabel,
                value: _endLabels(s)[_endType] ?? s.recurringEndNever,
                onTap: () async {
                  final picked = await showOptionPicker<RecurringEndType>(
                    context: context,
                    title: s.recurringEndLabel,
                    current: _endType,
                    options: [
                      for (final e in _endLabels(s).entries)
                        PickerOption(value: e.key, label: e.value),
                    ],
                  );
                  if (picked != null) setState(() => _endType = picked);
                },
              ),
              if (_endType == RecurringEndType.count)
                TextFormField(
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: s.recurringCountLabel),
                  onChanged: (v) => _endCount = int.tryParse(v.trim()),
                  validator: (v) {
                    if (_endType != RecurringEndType.count) return null;
                    final n = int.tryParse((v ?? '').trim());
                    if (n == null || n <= 0) return s.recurringCountInvalid;
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
                child: Text(_saving ? s.recurringSaving : s.save),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
