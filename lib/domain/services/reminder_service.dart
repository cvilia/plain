/// 从当前数据生成提醒（STORY-6.3）。只读，不改账。
library;

import 'package:plain/core/constants/app_constants.dart';
import 'package:plain/core/id/uuid_v7.dart';
import 'package:plain/core/time/clock.dart';
import 'package:plain/data/platform/notification_bridge.dart';
import 'package:plain/domain/entities/budget.dart';
import 'package:plain/domain/entities/reminder.dart';
import 'package:plain/domain/entities/recurring_rule.dart';
import 'package:plain/domain/repositories/repositories.dart';

class ReminderService {
  ReminderService({
    required BudgetRepository budgetRepository,
    required RecurringRepository recurringRepository,
    required Clock clock,
    required UuidV7 idGen,
  })  : _budget = budgetRepository,
        _recurring = recurringRepository,
        _clock = clock,
        _idGen = idGen;

  final BudgetRepository _budget;
  final RecurringRepository _recurring;
  final Clock _clock;
  final UuidV7 _idGen;

  /// 扫描并生成当前应提醒项（已按开关过滤、已应用夜间规则）。
  Future<List<AppReminder>> collect({
    required String bookId,
    required ReminderPrefs prefs,
  }) async {
    final now = _clock.now();
    final out = <AppReminder>[];

    void add(
      ReminderKind kind,
      String title,
      String body, {
      ReminderLevel level = ReminderLevel.ring,
    }) {
      if (!prefs.isEnabled(kind)) return;
      out.add(AppReminder(
        id: _idGen.generate(),
        kind: kind,
        title: title,
        body: body,
        level: level,
        triggeredAt: now,
      ).applyQuietHours());
    }

    // 1) 周期待确认 / 已入账
    final due = await _recurring.listDue(now: now);
    final dueList = due.successOrNull ?? const <RecurringRule>[];
    final needConfirm = dueList.where((r) => !r.autoConfirm).length;
    if (needConfirm > 0) {
      add(ReminderKind.recurringPosted, '周期账单待确认', '有 $needConfirm 条周期账单等待确认');
    }

    // 2) 预算 80% / 100%
    final budgets = await _budget.listByBook(bookId);
    for (final b in budgets.successOrNull ?? const <Budget>[]) {
      if (!b.isEnabled) continue;
      final from = now.subtract(const Duration(days: 31));
      final spent = await _budget.spentCents(
        bookId: bookId,
        categoryId: b.categoryId,
        fromMs: from.millisecondsSinceEpoch,
        toMs: now.millisecondsSinceEpoch,
      );
      final s = spent.successOrNull ?? 0;
      final limit = b.amount.cents;
      if (limit <= 0) continue;
      final ratio = s / limit;
      final label = b.categoryId == null ? '总预算' : '分类预算';
      if (ratio >= ReminderRules.budgetOverRatio) {
        add(ReminderKind.budgetWarn, '预算超支', '$label 已超支');
      } else if (ratio >= ReminderRules.budgetWarnRatio) {
        add(ReminderKind.budgetWarn, '预算预警',
            '$label 已用 ${(ratio * 100).toStringAsFixed(0)}%');
      }
    }

    return out;
  }

  /// G-3：把提醒推到系统通知。响铃/静默走不同通道参数。
  Future<void> pushToSystem(List<AppReminder> items) async {
    var i = 0;
    for (final r in items) {
      // id 稳定可重复覆盖，避免通知轰炸
      final id = 1000 + i;
      await NotificationBridge.show(
        id: id,
        title: r.title,
        body: r.body,
        payload: r.kind.wire,
        silent: r.level == ReminderLevel.silent,
      );
      i++;
    }
  }
}
