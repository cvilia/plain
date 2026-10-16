/// 从当前数据生成**九类**提醒（STORY-6.3 表 / G-3）。只读账、不改账。
///
/// 九类的触发规则与级别一律以 PRD STORY-6.3 的表为准：
///   信用卡还款日 / 订阅到期 / 预算分级 / 余额不足 → **响铃**
///   异常支出 / 周期账单已入账 / 对账 / 储蓄目标待存 / 备份 → **静默**
///
/// 三条硬约束：
///   ① **取不到数据就不产生**该提醒（如卡没设还款日、从没备份过、样本不足），
///      禁止为了「让提醒出现」而编一个业务数字；
///   ② 同类**去重**（同一预算周期的同一分类 80%/100% 各一次）与**历史**
///      都落 `reminders` 表（schema v24），不是内存状态；
///   ③ 夜间 23:00–07:00 响铃降级为静默（复用 [AppReminder.applyQuietHours]），
///      次日 08:00 汇总（[buildDigest]）。
///
/// 异常支出的统计窗口与样本口径**逐字**引用 STORY-5.4「共同统计口径」：
/// 近 90 天、按二级分类（样本不足退化到一级）、< 5 笔不触发、只算
/// 「进消费/分类统计 = 是」的账单（G-2.0）。
library;

import 'package:plain/core/constants/app_constants.dart';
import 'package:plain/core/id/uuid_v7.dart';
import 'package:plain/core/time/clock.dart';
import 'package:plain/data/platform/notification_bridge.dart';
import 'package:plain/data/repositories/app_meta_repository.dart';
import 'package:plain/domain/entities/budget.dart';
import 'package:plain/domain/entities/category.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/entities/ledger_entry.dart';
import 'package:plain/domain/entities/recurring_rule.dart';
import 'package:plain/domain/entities/reminder.dart';
import 'package:plain/domain/entities/savings_goal.dart';
import 'package:plain/domain/repositories/repositories.dart';
import 'package:plain/domain/services/accounting_calendar.dart';
import 'package:plain/domain/services/goal_progress_service.dart';
import 'package:plain/domain/services/safe_to_spend_service.dart';

/// 候选提醒 + 它的去重窗口（[sinceMs]）。
class _Candidate {
  const _Candidate(this.reminder, {this.sinceMs = 0});
  final AppReminder reminder;

  /// 去重查询的起始时刻：窗口内已存在同键记录则本候选不产生。
  /// 0 = 「有史以来」（受 90 天历史保留约束）。
  final int sinceMs;
}

/// 候选收集器：统一套用「逐项开关」与「级别表」。
class _Collector {
  _Collector({
    required this.prefs,
    required this.idGen,
    required this.now,
  });

  final ReminderPrefs prefs;
  final UuidV7 idGen;
  final DateTime now;
  final List<_Candidate> candidates = [];

  /// 关掉的种类直接不产生（PRD 边界：可逐项开关 + 全部静音）。
  void add(
    ReminderKind kind,
    String title,
    String body, {
    required String dedupKey,
    int sinceMs = 0,
    String? actionRef,
  }) {
    if (!prefs.isEnabled(kind)) return;
    candidates.add(_Candidate(
      AppReminder(
        id: idGen.generate(at: now),
        kind: kind,
        title: title,
        body: body,
        // 级别由种类定死（PRD 表），不由调用方覆盖
        level: kind.level,
        triggeredAt: now,
        dedupKey: dedupKey,
        actionRef: actionRef,
      ),
      sinceMs: sinceMs,
    ));
  }
}

class ReminderService {
  ReminderService({
    required LedgerRepository ledgerRepository,
    required AccountRepository accountRepository,
    required BudgetRepository budgetRepository,
    required RecurringRepository recurringRepository,
    required SavingsGoalRepository savingsGoalRepository,
    required CategoryRepository categoryRepository,
    required ReminderRepository reminderRepository,
    required AppMetaRepository appMetaRepository,
    required AccountingCalendar calendar,
    required Clock clock,
    required UuidV7 idGen,
  })  : _ledger = ledgerRepository,
        _accounts = accountRepository,
        _budget = budgetRepository,
        _recurring = recurringRepository,
        _goals = savingsGoalRepository,
        _categories = categoryRepository,
        _history = reminderRepository,
        _appMeta = appMetaRepository,
        _calendar = calendar,
        _clock = clock,
        _idGen = idGen;

  final LedgerRepository _ledger;
  final AccountRepository _accounts;
  final BudgetRepository _budget;
  final RecurringRepository _recurring;
  final SavingsGoalRepository _goals;
  final CategoryRepository _categories;
  final ReminderRepository _history;
  final AppMetaRepository _appMeta;
  final AccountingCalendar _calendar;
  final Clock _clock;
  final UuidV7 _idGen;

  /// 扫描并生成当前应提醒项（已按开关过滤、已去重、已应用夜间规则）。
  ///
  /// [persist] 为 false 时只算不落历史（纯查询用）。
  Future<List<AppReminder>> collect({
    required String bookId,
    required ReminderPrefs prefs,
    bool persist = true,
  }) async {
    final now = _clock.now();
    final local = now.toLocal();
    final today = DateTime(local.year, local.month, local.day);
    final c = _Collector(prefs: prefs, idGen: _idGen, now: now);

    final cats = await _categoryIndex();

    // 按 PRD 表内顺序收集，便于阅读与断言
    await _creditDue(c, today);
    await _subscriptions(c, bookId, today);
    await _budgets(c, bookId, today, cats);
    await _lowBalance(c, bookId, local);
    await _anomalySpend(c, bookId, now, today, cats);
    await _recurringPosted(c, now);
    await _reconcile(c);
    await _savingsGoals(c, bookId, now);
    await _backup(c, now);

    final out = <AppReminder>[];
    for (final candidate in c.candidates) {
      final seen = await _history.hasSince(
        bookId: bookId,
        dedupKey: candidate.reminder.dedupKey,
        sinceMs: candidate.sinceMs,
      );
      if (seen.successOrNull == true) continue;
      final applied = candidate.reminder.applyQuietHours();
      out.add(applied);
      if (persist) {
        await _history.append(bookId: bookId, reminder: applied);
      }
    }
    out.sort((a, b) => a.kind.index.compareTo(b.kind.index));
    if (persist) {
      await _history.gc(before: now.subtract(ReminderRules.historyTtl));
    }
    return out;
  }

  // ── 1) 信用卡还款日：到期前 3 天、当天各一次（响铃） ──
  Future<void> _creditDue(_Collector c, DateTime today) async {
    final accounts =
        (await _accounts.listAll()).successOrNull ?? const <Account>[];
    for (final a in accounts) {
      if (!a.isCredit) continue;
      final dueDay = a.dueDay;
      // 没设还款日 / 没有欠款 → 取不到数据，不产生
      if (dueDay == null || a.creditDebtCents <= 0) continue;
      final due = _nextDayOfMonth(today, dueDay);
      final days = due.difference(today).inDays;
      final dueKey = Clock.dayKeyOf(due);
      if (days == ReminderRules.creditDueAheadDays) {
        c.add(
          ReminderKind.creditDue,
          '信用卡还款日临近',
          '「${a.name}」$dueKey 到期，欠款 ${_yuan(a.creditDebtCents)}',
          dedupKey: 'credit_due:${a.id}:$dueKey:ahead',
        );
      } else if (days == 0) {
        c.add(
          ReminderKind.creditDue,
          '今天信用卡还款日',
          '「${a.name}」$dueKey 今天到期，欠款 ${_yuan(a.creditDebtCents)}',
          dedupKey: 'credit_due:${a.id}:$dueKey:today',
        );
      }
    }
  }

  // ── 2) 订阅到期前取消：连续扣款的订阅，下次扣款前 3 天（响铃） ──
  Future<void> _subscriptions(_Collector c, String bookId, DateTime today) async {
    final rules = (await _recurring.listByBook(bookId)).successOrNull ??
        const <RecurringRule>[];
    for (final r in rules) {
      if (!r.isEnabled || r.kind != RecurringKind.recurring) continue;
      if (r.entryType != EntryType.expense) continue;
      // 订阅 = 已经连续扣过款（≥2 次）的周期性支出，且周期像订阅（月/年）
      if (r.generatedCount < ReminderRules.subscriptionMinCharges) continue;
      if (r.frequency != RecurringFrequency.monthly &&
          r.frequency != RecurringFrequency.yearly) {
        continue;
      }
      final next = r.nextRunAt.toLocal();
      final nextDay = DateTime(next.year, next.month, next.day);
      if (nextDay.difference(today).inDays != ReminderRules.subscriptionAheadDays) {
        continue;
      }
      final key = Clock.dayKeyOf(nextDay);
      final name = (r.name ?? '').trim();
      c.add(
        ReminderKind.subscription,
        '订阅即将扣款',
        // PRD：给「取消路径指引」——扣款渠道要用户自己去关，我们只能关这条周期规则
        '「${name.isEmpty ? '周期扣款' : name}」$key 将扣款 '
        '${_yuan(r.amount.cents)}。不再需要的话，先到原扣款渠道取消自动续费，'
        '再点这里的「不再需要」关掉这条周期规则。',
        dedupKey: 'subscription:${r.id}:$key',
        // 一键处理：卡片上的「不再需要」据此停用这条规则
        actionRef: r.id,
      );
    }
  }

  // ── 3) 预算分级：80% / 100% 各一次（每周期每分类各一次，响铃） ──
  Future<void> _budgets(
    _Collector c,
    String bookId,
    DateTime today,
    _CategoryIndex cats,
  ) async {
    final budgets =
        (await _budget.listByBook(bookId)).successOrNull ?? const <Budget>[];
    for (final b in budgets) {
      if (!b.isEnabled) continue;
      final limit = b.amount.cents;
      if (limit <= 0) continue;

      // 用**该预算自己的周期**取窗口（原实现是滚动 31 天，与记账月不一致）
      final w = budgetPeriodWindow(today: today, startDay: b.startDay);
      final fromMs = w.start.toUtc().millisecondsSinceEpoch;
      final toMs = w.end.toUtc().millisecondsSinceEpoch;
      final spent = (await _budget.spentCents(
                bookId: bookId,
                categoryId: b.categoryId,
                fromMs: fromMs,
                toMs: toMs,
              )).successOrNull ??
          0;

      final ratio = spent / limit;
      final periodKey = Clock.dayKeyOf(w.start);
      final label = b.categoryId == null
          ? '总预算'
          : '「${cats.nameOf(b.categoryId) ?? '分类'}」';
      final pct = (ratio * 100).toStringAsFixed(0);

      if (ratio >= ReminderRules.budgetOverRatio) {
        c.add(
          ReminderKind.budgetWarn,
          '预算已超支',
          '$label 本期已用 $pct%，超出 ${_yuan(spent - limit)}',
          dedupKey: 'budget_warn:${b.id}:$periodKey:100',
          sinceMs: fromMs,
        );
      } else if (ratio >= ReminderRules.budgetWarnRatio) {
        c.add(
          ReminderKind.budgetWarn,
          '预算预警',
          '$label 本期已用 $pct%，剩余 ${_yuan(limit - spent)}',
          dedupKey: 'budget_warn:${b.id}:$periodKey:80',
          sinceMs: fromMs,
        );
      }
    }
  }

  // ── 4) 余额不足：安全可花为负（响铃） ──
  Future<void> _lowBalance(_Collector c, String bookId, DateTime local) async {
    final result = await SafeToSpendCalculator(
      accountRepository: _accounts,
      budgetRepository: _budget,
      recurringRepository: _recurring,
      savingsGoalRepository: _goals,
      categoryRepository: _categories,
      calendar: _calendar,
      bookId: bookId,
    ).calculate();

    // 没有预算时安全可花卡片本就是隐藏的，这里同口径不产生
    if (!result.hasAnyBudget || !result.isNegative) return;
    c.add(
      ReminderKind.lowBalance,
      '余额不足预警',
      '安全可花为负（${_yuan(result.safeToSpendCents)}），本月可用资金已被预留项吃掉',
      dedupKey: 'low_balance:${Clock.dayKeyOf(local)}',
    );
  }

  // ── 5) 异常支出：单笔 > 该分类近 90 天 P90×2，或当日合计 > 近 30 日均值×3（静默） ──
  Future<void> _anomalySpend(
    _Collector c,
    String bookId,
    DateTime now,
    DateTime today,
    _CategoryIndex cats,
  ) async {
    final windowStart =
        now.subtract(const Duration(days: StatsWindowRules.windowDays));
    final entries = await _expenseEntries(
      bookId: bookId,
      fromMs: windowStart.millisecondsSinceEpoch,
      toMs: now.millisecondsSinceEpoch,
    );
    // STORY-5.4 共同口径：只算「进消费/分类统计 = 是」的账单（G-2.0）
    final stat = entries.where((e) => e.countsInCategoryStats).toList();

    final todayStart = today.toUtc();
    final todayEnd = today.add(const Duration(days: 1)).toUtc();
    final todayEntries = stat
        .where((e) =>
            !e.occurredAt.isBefore(todayStart) && e.occurredAt.isBefore(todayEnd))
        .toList();

    // 单笔异常扫**近几天**而不是只看今天：素记不常驻后台，某天没打开 App，
    // 那天的异常支出就永远漏报。按账单 id 去重（见下方 dedupKey），
    // 重复扫描不会重复提醒，因此把窗口放宽是安全的。
    final scanStart = today
        .subtract(Duration(days: ReminderRules.anomalyScanLookbackDays - 1))
        .toUtc();
    final recentEntries = stat
        .where((e) => !e.occurredAt.isBefore(scanStart))
        .toList();

    // ① 单笔异常：样本按二级分类，不足 5 笔退化到所属一级分类
    for (final e in recentEntries) {
      final samples = _samplesFor(stat, e, cats);
      if (samples.length < StatsWindowRules.minSamples) continue;
      samples.sort();
      final p90 =
          samples[((samples.length * 0.9).floor()).clamp(0, samples.length - 1)];
      if (p90 <= 0) continue;
      if (e.amount.cents <= p90 * ReminderRules.anomalyP90Factor) continue;
      c.add(
        ReminderKind.anomalySpend,
        '异常支出',
        '${_yuan(e.amount.cents)} 高于该分类近 90 天的常见水平',
        dedupKey: 'anomaly_spend:${e.id}',
      );
    }

    // ② 当日合计异常：与近 30 天的日均支出比较
    final dailyAverage = await _dailyAverageCents(bookId: bookId, today: today);
    if (dailyAverage <= 0) return;
    final todayTotal =
        todayEntries.fold<int>(0, (sum, e) => sum + e.amount.cents);
    if (todayTotal <= dailyAverage * ReminderRules.anomalyDailyFactor) return;
    c.add(
      ReminderKind.anomalySpend,
      '当日支出偏高',
      '今日已支出 ${_yuan(todayTotal)}，高于近 30 天日均 ${_yuan(dailyAverage)}',
      dedupKey: 'anomaly_spend_day:${Clock.dayKeyOf(today)}',
    );
  }

  // ── 6) 周期账单已入账：免确认入账后（静默） ──
  Future<void> _recurringPosted(_Collector c, DateTime now) async {
    final due = (await _recurring.listDue(now: now)).successOrNull ??
        const <RecurringRule>[];
    // 免确认 = 自动入账；需确认的规则由周期页处理，不是九类提醒之一
    final posted = due.where((r) => r.autoConfirm).toList();
    if (posted.isEmpty) return;
    c.add(
      ReminderKind.recurringPosted,
      '周期账单已入账',
      '已自动入账 ${posted.length} 笔周期账单',
      dedupKey: 'recurring_posted:${Clock.dayKeyOf(now.toLocal())}',
    );
  }

  // ── 7) 对账提醒：提醒**上一个记账月**未对账的账单（静默） ──
  //
  // ⚠️ 触发口径：PRD 写「每月记账月首日」，但离线 App 没有后台唤醒——若那天没开
  // App，到点提醒就等于永不提醒。因此按项目既有口径（同 STORY-9.5 周报的
  // 「到点后首次启动补发」）取**记账月内首次扫描补发**，去重键带记账月标签，
  // 所以每个记账月仍然只出一次。
  // 统计范围按 PRD 取**上一个记账月**（对账是对完上个月的账，不是清历史欠账）。
  Future<void> _reconcile(_Collector c) async {
    final period = _calendar.previousPeriod();
    final fromMs = DateTime.parse(period.dayFrom).toUtc().millisecondsSinceEpoch;
    final toMs = DateTime.parse(period.dayTo)
        .add(const Duration(days: 1))
        .toUtc()
        .millisecondsSinceEpoch;

    final accounts =
        (await _accounts.listAll()).successOrNull ?? const <Account>[];
    var pending = 0;
    for (final a in accounts) {
      final page = await _ledger.listPage(
        filter: EntryFilter(accountId: a.id, fromMs: fromMs, toMs: toMs),
        limit: 500,
      );
      final items = page.successOrNull?.items ?? const <LedgerEntry>[];
      pending += items.where((e) => !e.isDeleted && !e.isReconciled).length;
    }
    // 上个月都核对完了就没什么可提醒的
    if (pending <= 0) return;
    c.add(
      ReminderKind.reconcile,
      '对账提醒',
      '${period.label} 有 $pending 笔账单未对账',
      dedupKey: 'reconcile:${_calendar.currentLabel()}',
    );
  }

  // ── 8) 储蓄目标待存：每月记账月首日（静默，同上按「记账月内首次扫描」补发） ──
  Future<void> _savingsGoals(
    _Collector c,
    String bookId,
    DateTime now,
  ) async {
    final goals =
        (await _goals.listByBook(bookId)).successOrNull ?? const <SavingsGoal>[];
    // 目标进度按 V3.0 口径读**虚拟账户派生余额**（不是存储的 saved_cents），
    // 否则删掉「存入」转账后这里还会按虚高的进度判断「已存满」而不再提醒。
    final accounts =
        (await _accounts.listWithBalances()).successOrNull ?? const <AccountWithBalance>[];
    final progress = const GoalProgressService().ofAll(
      goals: goals,
      balanceByAccount: GoalProgressService.balanceIndex(accounts),
    );
    final period = _calendar.currentLabel();
    for (final v in progress) {
      // 还债目标靠还款推进，不做「存入」
      if (v.goal.isDebt || v.isAchieved) continue;
      final need = v.monthlyRequiredCentsAt(now);
      if (need <= 0) continue;
      c.add(
        ReminderKind.savingsGoal,
        '储蓄目标待存',
        '「${v.goal.name}」本月需存 ${_yuan(need)}',
        dedupKey: 'savings_goal:${v.goal.id}:$period',
      );
    }
  }

  // ── 9) 备份提醒：距上次备份 > 30 天（静默） ──
  Future<void> _backup(_Collector c, DateTime now) async {
    final lastMs = _appMeta.lastBackupAtMs();
    // 从来没备份过 → 没有「距上次备份」这个量，不产生（不编造天数）
    if (lastMs == null) return;
    final last = DateTime.fromMillisecondsSinceEpoch(lastMs, isUtc: true);
    final elapsed = now.difference(last);
    if (elapsed < ReminderRules.backupRemindInterval) return;
    // 每满一个提醒间隔最多提示一次（30 天一次，而不是每天一次）
    final bucket = elapsed.inDays ~/ ReminderRules.backupRemindInterval.inDays;
    c.add(
      ReminderKind.backup,
      '备份提醒',
      '距上次备份已 ${elapsed.inDays} 天，建议导出一次整库备份',
      dedupKey: 'backup:$bucket',
    );
  }

  // ── G-3：夜间降级项的次日 08:00 汇总 ──
  //
  // 离线 App 没有后台唤醒，所以「次日 08:00」是**到点后首次启动/回前台补发**
  // （与 STORY-9.5 周报同款口径）：08:00 起到夜间免打扰开始前，只要还有夜间
  // 产生且未汇总的提醒，就发一条摘要；发过即标记，不重复。
  Future<ReminderDigest?> buildDigest({required String bookId}) async {
    final now = _clock.now();
    final hour = now.toLocal().hour;
    if (hour < ReminderRules.summaryHour ||
        hour >= ReminderRules.quietStartHour) {
      return null;
    }
    final sinceMs = now
        .subtract(const Duration(hours: ReminderRules.quietLookbackHours))
        .millisecondsSinceEpoch;
    final rows = (await _history.listRecent(
              bookId: bookId,
              sinceMs: sinceMs,
              limit: 500,
              undigestedOnly: true,
            )).successOrNull ??
        const <AppReminder>[];
    final quiet = rows.where((r) => r.isQuiet).toList();
    if (quiet.isEmpty) return null;

    final digest = ReminderDigest(
      total: quiet.length,
      postedCount:
          quiet.where((r) => r.kind == ReminderKind.recurringPosted).length,
      budgetWarnCount:
          quiet.where((r) => r.kind == ReminderKind.budgetWarn).length,
      downgradedCount: quiet.where((r) => r.wasQuietDowngraded).length,
    );
    await _history.markDigested(ids: [for (final r in quiet) r.id]);
    return digest;
  }

  /// G-3：把提醒推到系统通知。响铃/静默走不同通道参数。
  ///
  /// 「全部静音」时 [collect] 不返回任何条目，因此这里天然不会推系统通知
  /// （PRD AC5：仅进 App 内提醒列表）。
  Future<void> pushToSystem(List<AppReminder> items) async {
    var i = 0;
    for (final r in items) {
      // id 稳定可重复覆盖，避免通知轰炸
      final id = ReminderRules.notificationIdBase + i;
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

  /// 夜间汇总的系统通知（含预算跨阈值时升级为响铃）。
  Future<void> pushDigestIfDue({
    required String bookId,
    required ReminderPrefs prefs,
  }) async {
    // 全部静音 → 连汇总也不推（AC5 是「均不产生系统通知」）
    if (prefs.allMuted) return;
    final digest = await buildDigest(bookId: bookId);
    if (digest == null) return;
    await NotificationBridge.show(
      id: ReminderRules.digestNotificationId,
      title: digest.title,
      body: digest.body,
      payload: 'reminder_digest',
      silent: digest.level == ReminderLevel.silent,
    );
  }

  // ── 取数辅助 ──

  /// 近 90 天支出账单（游标翻页取全，不设任意条数上限）。
  Future<List<LedgerEntry>> _expenseEntries({
    required String bookId,
    required int fromMs,
    required int toMs,
  }) async {
    final out = <LedgerEntry>[];
    EntryCursor? cursor;
    var lastCursorId = '';
    while (true) {
      final page = (await _ledger.listPage(
        filter: EntryFilter(
          bookId: bookId,
          type: EntryType.expense.wire,
          fromMs: fromMs,
          toMs: toMs,
        ),
        cursor: cursor,
        limit: 500,
      ))
          .successOrNull;
      if (page == null) break;
      out.addAll(page.items);
      final next = page.nextCursor;
      if (!page.hasMore || next == null) break;
      if (next.id == lastCursorId) break; // 防御：游标不前进
      lastCursorId = next.id;
      cursor = next;
    }
    return out;
  }

  /// 单笔异常的比较样本：先二级分类，样本不足退化到所属一级分类（STORY-5.4）。
  List<int> _samplesFor(
    List<LedgerEntry> entries,
    LedgerEntry target,
    _CategoryIndex cats,
  ) {
    final catId = target.categoryId;
    if (catId == null) return [];
    final samples = [
      for (final e in entries)
        if (e.id != target.id && e.categoryId == catId) e.amount.cents,
    ];
    if (samples.length >= StatsWindowRules.minSamples) return samples;

    final root = cats.rootOf(catId);
    if (root == null) return samples;
    return [
      for (final e in entries)
        if (e.id != target.id && cats.rootOf(e.categoryId) == root)
          e.amount.cents,
    ];
  }

  /// 近 30 天的日均支出（分）。走 daily_stats 月汇总，与报表同一口径。
  Future<int> _dailyAverageCents({
    required String bookId,
    required DateTime today,
  }) async {
    final from = today
        .subtract(const Duration(days: ReminderRules.anomalyDailyWindowDays));
    final to = today.subtract(const Duration(days: 1));
    final summary = (await _ledger.monthSummary(
      bookId: bookId,
      dayFrom: Clock.dayKeyOf(from),
      dayTo: Clock.dayKeyOf(to),
    ))
        .successOrNull;
    if (summary == null || summary.expenseCents <= 0) return 0;
    return summary.expenseCents ~/ ReminderRules.anomalyDailyWindowDays;
  }

  Future<_CategoryIndex> _categoryIndex() async {
    final cats =
        (await _categories.listAll()).successOrNull ?? const <Category>[];
    return _CategoryIndex(cats);
  }

  /// 下一个 [day] 号（本月还没到就是本月，过了就是下月）。
  static DateTime _nextDayOfMonth(DateTime today, int day) {
    final d = day.clamp(CreditCardRules.minDay, CreditCardRules.maxDay);
    if (today.day <= d) return DateTime(today.year, today.month, d);
    return DateTime(today.year, today.month + 1, d);
  }

  static String _yuan(int cents) =>
      '${cents < 0 ? '-' : ''}¥${(cents.abs() / 100).toStringAsFixed(2)}';
}

/// 分类索引：id → 名称、id → 所属一级分类。
class _CategoryIndex {
  _CategoryIndex(List<Category> cats)
      : _names = {for (final c in cats) c.id: c.name},
        _parents = {for (final c in cats) c.id: c.parentId};

  final Map<String, String> _names;
  final Map<String, String?> _parents;

  String? nameOf(String? id) => id == null ? null : _names[id];

  /// 所属一级分类 id（自身即一级时返回自身）。
  String? rootOf(String? id) {
    if (id == null) return null;
    var current = id;
    var parent = _parents[current];
    var depth = 0;
    // 分类只有两级，深度上限只是防御脏数据成环
    while (parent != null && depth < 8) {
      current = parent;
      parent = _parents[current];
      depth++;
    }
    return current;
  }
}
