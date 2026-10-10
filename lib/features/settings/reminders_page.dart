/// 提醒中心（STORY-6.3）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plain/app/bootstrap.dart';
import 'package:plain/app/theme/app_colors.dart';
import 'package:plain/app/theme/design_tokens.dart';
import 'package:plain/domain/entities/reminder.dart';
import 'package:plain/domain/services/reminder_service.dart';

class ReminderPrefsNotifier extends Notifier<ReminderPrefs> {
  @override
  ReminderPrefs build() => const ReminderPrefs();

  void toggleAllMuted() => state = state.copyWith(allMuted: !state.allMuted);
  void toggleKind(ReminderKind kind) => state = state.toggle(kind);
}

final reminderPrefsProvider =
    NotifierProvider<ReminderPrefsNotifier, ReminderPrefs>(ReminderPrefsNotifier.new);

class RemindersPage extends ConsumerStatefulWidget {
  const RemindersPage({super.key});

  @override
  ConsumerState<RemindersPage> createState() => _RemindersPageState();
}

class _RemindersPageState extends ConsumerState<RemindersPage> {
  List<AppReminder> _items = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final deps = ref.read(appDependenciesProvider);
    final prefs = ref.read(reminderPrefsProvider);
    final service = ReminderService(
      budgetRepository: deps.budgetRepository,
      recurringRepository: deps.recurringRepository,
      clock: deps.clock,
      idGen: deps.idGen,
    );
    final items = await service.collect(bookId: deps.bookId, prefs: prefs);
    // G-3：响铃/静默推系统通知
    await service.pushToSystem(items);
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(reminderPrefsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('提醒'),
        actions: [
          IconButton(
            tooltip: prefs.allMuted ? '取消全部静音' : '全部静音',
            icon: Icon(prefs.allMuted ? Icons.notifications_off_outlined : Icons.notifications_active_outlined),
            onPressed: () {
              ref.read(reminderPrefsProvider.notifier).toggleAllMuted();
              _reload();
            },
          ),
          IconButton(
            tooltip: '刷新',
            icon: const Icon(Icons.refresh),
            onPressed: _reload,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(Spacing.lg),
              children: [
                if (_items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: Spacing.xl),
                    child: Center(
                      child: Text(
                        '暂无提醒',
                        style: TextStyle(color: context.colors.inkTertiary),
                      ),
                    ),
                  )
                else
                  for (final r in _items)
                    Card(
                      child: ListTile(
                        leading: Icon(
                          r.level == ReminderLevel.ring
                              ? Icons.notifications_active_outlined
                              : Icons.notifications_none_outlined,
                          color: r.level == ReminderLevel.ring
                              ? context.colors.primary
                              : context.colors.inkTertiary,
                        ),
                        title: Text(r.title),
                        subtitle: Text(r.body, style: const TextStyle(fontSize: 12)),
                      ),
                    ),
                const SizedBox(height: Spacing.lg),
                Text('提醒类型', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: Spacing.sm),
                Card(
                  child: Column(
                    children: [
                      for (final k in ReminderKind.values)
                        SwitchListTile(
                          dense: true,
                          title: Text(_labelOf(k)),
                          value: prefs.isEnabled(k),
                          onChanged: prefs.allMuted
                              ? null
                              : (_) {
                                  ref.read(reminderPrefsProvider.notifier).toggleKind(k);
                                  _reload();
                                },
                        ),
                    ],
                  ),
                ),
                Text(
                  '夜间 23:00–07:00 响铃自动降为静默（G-3）',
                  style: TextStyle(fontSize: 11, color: context.colors.inkTertiary),
                ),
              ],
            ),
    );
  }

  String _labelOf(ReminderKind k) {
    return switch (k) {
      ReminderKind.creditDue => '信用卡还款',
      ReminderKind.subscription => '订阅到期',
      ReminderKind.budgetWarn => '预算预警',
      ReminderKind.lowBalance => '余额不足',
      ReminderKind.anomalySpend => '异常支出',
      ReminderKind.recurringPosted => '周期账单',
      ReminderKind.reconcile => '对账提醒',
      ReminderKind.savingsGoal => '储蓄目标',
      ReminderKind.backup => '备份提醒',
    };
  }
}
