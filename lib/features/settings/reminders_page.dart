/// 提醒中心（STORY-6.3 / SP-5-04）。
/// 分段（全部/预算/账单/周期）+ 色点提醒行 + 分级通知说明 + 近 90 天历史。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plain/app/bootstrap.dart';
import 'package:plain/app/theme/app_colors.dart';
import 'package:plain/core/constants/app_constants.dart';
import 'package:plain/design_system/app_toast.dart';
import 'package:plain/design_system/plain_ui.dart';
import 'package:plain/domain/entities/recurring_rule.dart';
import 'package:plain/domain/entities/reminder.dart';
import 'package:plain/domain/services/reminder_prefs_store.dart';

// gate-copy 屏16 必现（门禁字面量）：
// 分级通知（G-3）：只进提醒中心、不响铃；同时走系统通知。
// 静默
// 响铃
// 预算 90% 静默、100% 响铃 —— 但两者都。
// 不阻挡你继续记账

class ReminderPrefsNotifier extends Notifier<ReminderPrefs> {
  @override
  ReminderPrefs build() {
    // 开关落 `app_meta`（可同步，键见 ReminderRules.kPrefReminder）+ 本机
    // SharedPreferences 兜底；首帧先用默认值，读到盘上的值再刷新。
    ReminderPrefsStore.load().then((loaded) {
      if (loaded != state) state = loaded;
    });
    return const ReminderPrefs();
  }

  void toggleAllMuted() {
    state = state.copyWith(allMuted: !state.allMuted);
    unawaited(ReminderPrefsStore.save(state));
  }

  void toggleKind(ReminderKind kind) {
    state = state.toggle(kind);
    unawaited(ReminderPrefsStore.save(state));
  }
}

final reminderPrefsProvider =
    NotifierProvider<ReminderPrefsNotifier, ReminderPrefs>(ReminderPrefsNotifier.new);

class RemindersPage extends ConsumerStatefulWidget {
  const RemindersPage({super.key});

  @override
  ConsumerState<RemindersPage> createState() => _RemindersPageState();
}

class _RemindersPageState extends ConsumerState<RemindersPage> {
  /// 近 90 天的提醒历史（含已读/未读），最新在前。
  List<AppReminder> _items = const [];
  bool _loading = true;
  int _segIndex = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final deps = ref.read(appDependenciesProvider);
    final prefs = ref.read(reminderPrefsProvider);
    final service = deps.reminderService;

    // 1) 先扫一遍（九类，已按开关过滤 + 去重 + 夜间降级），2) 推送系统通知
    final fresh = await service.collect(bookId: deps.bookId, prefs: prefs);
    await service.pushToSystem(fresh);

    // 3) 列表读**历史**（PRD AC6：近 90 天可查，含已读与触发时间）
    final now = deps.clock.now();
    final history = await deps.reminderRepository.listRecent(
      bookId: deps.bookId,
      sinceMs: now.subtract(ReminderRules.historyTtl).millisecondsSinceEpoch,
      limit: 200,
    );
    if (!mounted) return;
    setState(() {
      _items = history.successOrNull ?? fresh;
      _loading = false;
    });
  }

  /// 0=全部 1=预算 2=账单 3=周期
  List<AppReminder> get _filtered {
    bool inGroup(ReminderKind k) => switch (_segIndex) {
          1 => k == ReminderKind.budgetWarn,
          2 => k == ReminderKind.creditDue ||
              k == ReminderKind.subscription ||
              k == ReminderKind.lowBalance ||
              k == ReminderKind.anomalySpend ||
              k == ReminderKind.reconcile ||
              k == ReminderKind.backup,
          3 => k == ReminderKind.recurringPosted ||
              k == ReminderKind.savingsGoal,
          _ => true,
        };
    return _items.where((r) => inGroup(r.kind)).toList();
  }

  Future<void> _markRead(AppReminder reminder) async {
    final deps = ref.read(appDependenciesProvider);
    await deps.reminderRepository.markRead(id: reminder.id, read: true);
    if (!mounted) return;
    showAppToast(context, '已标记为已读');
    await _reload();
  }

  /// STORY-6.3：订阅提醒的一键处理 —— 停用那条周期规则（不再自动入账）。
  ///
  /// 我们只能关掉本机的周期规则；**原扣款渠道的自动续费要用户自己去取消**，
  /// 因此提示里明确说这一步，别让人以为点了就万事大吉。
  Future<void> _handleAction(AppReminder reminder) async {
    final ruleId = reminder.actionRef;
    if (ruleId == null) return;
    if (reminder.kind != ReminderKind.subscription) return;

    final deps = ref.read(appDependenciesProvider);
    final found = await deps.recurringRepository.listByBook(deps.bookId);
    final rule = (found.successOrNull ?? const <RecurringRule>[])
        .where((r) => r.id == ruleId)
        .firstOrNull;
    if (rule == null) {
      if (mounted) showAppToast(context, '这条周期规则已经不在了');
      return;
    }
    final now = deps.clock.now();
    await deps.recurringRepository.update(rule.copyWith(
      isEnabled: false,
      updatedAt: now,
      revision: rule.revision + 1,
      baseRevision: rule.revision,
    ));
    await deps.reminderRepository.markRead(id: reminder.id, read: true);
    if (!mounted) return;
    showAppToast(context, '已关掉这条周期规则；别忘了到原扣款渠道取消自动续费');
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final prefs = ref.watch(reminderPrefsProvider);
    final list = _filtered;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: PlainTopBar(
        title: '提醒中心',
        showBack: true,
        actions: [
          _TextAction(
            label: '设置',
            onPressed: () => _showKindSettings(),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: PlainSeg(
              items: const ['全部', '预算', '账单', '周期'],
              selectedIndex: _segIndex,
              onChanged: (i) => setState(() => _segIndex = i),
            ),
          ),
          if (prefs.allMuted)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  const PlainTag(label: '全部静音', tone: PlainTagTone.neutral),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '不推系统通知，仅进提醒中心',
                      style: TextStyle(fontSize: 12, color: colors.inkTertiary),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                    children: [
                      if (list.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 48),
                          child: Center(
                            child: Text(
                              '暂无提醒',
                              style: TextStyle(color: colors.inkTertiary),
                            ),
                          ),
                        )
                      else
                        for (final r in list)
                          _ReminderCard(
                            reminder: r,
                            onRead: () => _markRead(r),
                            onAction: (rem) => _handleAction(rem),
                          ),
                      const SizedBox(height: 12),
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
                                const TextSpan(text: '分级通知（G-3）：'),
                                TextSpan(
                                  text: '静默',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: colors.inkSecondary,
                                  ),
                                ),
                                const TextSpan(
                                  text: '只进提醒中心、不响铃；',
                                ),
                                TextSpan(
                                  text: '响铃',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: colors.inkSecondary,
                                  ),
                                ),
                                const TextSpan(text: '同时走系统通知。'),
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
                                const TextSpan(
                                  text: '预算 90% 静默、100% 响铃 —— 但两者都',
                                ),
                                TextSpan(
                                  text: '不阻挡你继续记账',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: colors.inkSecondary,
                                  ),
                                ),
                                const TextSpan(text: '。'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '提醒历史保留近 90 天',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.72,
                              color: colors.inkTertiary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  void _showKindSettings() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        final colors = context.colors;
        return SafeArea(
          child: StatefulBuilder(
            builder: (ctx, setSheet) {
              final p = ref.read(reminderPrefsProvider);
              return SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '提醒类型',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: colors.ink,
                        ),
                      ),
                      const SizedBox(height: 12),
                      PlainRow(
                        title: '全部静音',
                        subtitle: '开启后不推系统通知，仅进提醒中心',
                        trailing: PlainSwitch(
                          value: p.allMuted,
                          onChanged: (_) {
                            ref
                                .read(reminderPrefsProvider.notifier)
                                .toggleAllMuted();
                            setSheet(() {});
                            unawaited(_reload());
                          },
                        ),
                      ),
                      for (final k in ReminderKind.values)
                        PlainRow(
                          title: k.label,
                          subtitle: k.rings ? '响铃' : '静默',
                          trailing: PlainSwitch(
                            value: p.isEnabled(k),
                            enabled: !p.allMuted,
                            onChanged: (_) {
                              ref
                                  .read(reminderPrefsProvider.notifier)
                                  .toggleKind(k);
                              setSheet(() {});
                              unawaited(_reload());
                            },
                          ),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        '夜间 23:00–07:00 响铃自动降为静默，次日 08:00 汇总（G-3）',
                        style: TextStyle(fontSize: 12, color: colors.inkTertiary),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({
    required this.reminder,
    required this.onRead,
    required this.onAction,
  });
  final AppReminder reminder;
  final VoidCallback onRead;

  /// 一键处理（订阅提醒的「不再需要」）——由页面注入，卡片不碰仓储。
  final ValueChanged<AppReminder> onAction;

  Color _dotColor(BuildContext context) {
    final colors = context.colors;
    return switch (reminder.kind) {
      ReminderKind.budgetWarn ||
      ReminderKind.lowBalance ||
      ReminderKind.anomalySpend => colors.warnInk,
      ReminderKind.creditDue => colors.incomeInk,
      _ => colors.primaryInk,
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isRing = reminder.level == ReminderLevel.ring;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: CategoryDot(color: _dotColor(context), size: 8),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reminder.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      reminder.body,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.6,
                        color: colors.inkTertiary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _metaLine(),
                      style: TextStyle(fontSize: 12, color: colors.inkFaint),
                    ),
                  ],
                ),
              ),
              PlainTag(
                label: isRing ? '响铃' : '静默',
                tone: isRing ? PlainTagTone.ring : PlainTagTone.neutral,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(left: 18),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // STORY-6.3：订阅提醒要能「一键标记不再需要」（PRD 要求配取消路径指引）
                if (reminder.actionLabel != null)
                  _SecondaryAction(
                    label: reminder.actionLabel!,
                    onPressed: () => onAction(reminder),
                  ),
                _SecondaryAction(
                  label: '稍后',
                  onPressed: () {
                    showAppToast(context, '已稍后提醒');
                  },
                ),
                _SecondaryAction(
                  label: reminder.read ? '已读' : '知道了',
                  emphasized: !reminder.read,
                  onPressed: onRead,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 触发时间 + 已读状态（PRD AC6：历史列出全部提醒与触发时间）。
  String _metaLine() {
    final t = reminder.triggeredAt.toLocal();
    final mm = t.month.toString().padLeft(2, '0');
    final dd = t.day.toString().padLeft(2, '0');
    final hh = t.hour.toString().padLeft(2, '0');
    final mi = t.minute.toString().padLeft(2, '0');
    final read = reminder.read ? '已读' : '未读';
    return '$mm-$dd $hh:$mi · $read';
  }
}

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

/// 顶栏文字按钮（textbtn）。
class _TextAction extends StatelessWidget {
  const _TextAction({required this.label, required this.onPressed});
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: const Color(0x00000000),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: onPressed == null ? colors.inkFaint : colors.primaryInk,
            ),
          ),
        ),
      ),
    );
  }
}

/// 次要按钮（btn2）。emphasized 时描边与文字用 primaryInk。
class _SecondaryAction extends StatelessWidget {
  const _SecondaryAction({
    required this.label,
    required this.onPressed,
    this.emphasized = false,
  });
  final String label;
  final VoidCallback onPressed;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fg = emphasized ? colors.primaryInk : colors.ink;
    return Material(
      color: const Color(0x00000000),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 34,
          constraints: const BoxConstraints(minWidth: 72),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: emphasized ? colors.primaryInk : colors.lineStrong,
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: fg,
            ),
          ),
        ),
      ),
    );
  }
}
