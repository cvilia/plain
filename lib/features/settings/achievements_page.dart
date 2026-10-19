/// STORY-5.5 成就徽章墙：展示已解锁徽章 + 权益券 + 连续记账状态。
/// 约束：不做排行榜、不做积分商城。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plain/app/bootstrap.dart';
import 'package:plain/app/l10n/app_strings.dart';
import 'package:plain/app/l10n/strings_settings_b.dart';
import 'package:plain/app/theme/app_colors.dart';
import 'package:plain/app/theme/design_tokens.dart';
import 'package:plain/app/theme/typography.dart';
import 'package:plain/core/constants/app_constants.dart';
import 'package:plain/design_system/plain_icons_v3.dart';
import 'package:plain/design_system/plain_ui.dart';
import 'package:plain/domain/repositories/repositories.dart';
import 'package:plain/domain/services/gamification_service.dart';

class AchievementsPage extends ConsumerStatefulWidget {
  const AchievementsPage({super.key});

  @override
  ConsumerState<AchievementsPage> createState() => _AchievementsPageState();
}

class _AchievementsPageState extends ConsumerState<AchievementsPage> {
  StreakStatus _streak = const StreakStatus(currentDays: 0, bestDays: 0, isBroken: false);
  Set<String> _badges = {};
  List<Voucher> _vouchers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final streak = await GamificationService.getStreak(DateTime.now());
    final badges = await GamificationService.getBadges();
    final vouchers = await GamificationService.getVouchers();
    // 节制 / 目标两类徽章不是「某动作触发」而是**从数据派生**，随算随亮
    final derived = await _derivedBadges();
    if (!mounted) return;
    setState(() {
      _streak = streak;
      _badges = {...badges, ...derived};
      _vouchers = vouchers;
      _loading = false;
    });
  }

  /// 节制：**上一个已结束的记账月**有预算且没超支（不拿本月算，本月还没过完）。
  /// 目标：任一储蓄目标达标 / 任一贷款账户已还清。
  ///
  /// 派生而非落库：这些「事实」本来就在预算与账本里，存一份反而会漂。
  Future<Set<String>> _derivedBadges() async {
    final out = <String>{};
    try {
      final deps = ref.read(appDependenciesProvider);
      final calendar = ref.read(calendarProvider);

      // ── 节制 ──
      final budgets = (await deps.budgetRepository.listByBook(deps.bookId))
              .successOrNull ??
          const [];
      final enabled = budgets.where((b) => b.isEnabled && !b.isDeleted).toList();
      if (enabled.isNotEmpty) {
        final prev = calendar.previousPeriod();
        final fromMs = DateTime.parse(prev.dayFrom).toUtc().millisecondsSinceEpoch;
        final toMs =
            DateTime.parse(prev.dayTo).add(const Duration(days: 1)).toUtc().millisecondsSinceEpoch;
        final total = enabled.where((b) => b.isTotal).firstOrNull;
        if (total != null) {
          final spent = await deps.budgetRepository.spentCents(
              bookId: deps.bookId, fromMs: fromMs, toMs: toMs);
          if ((spent.successOrNull ?? 0) <= total.amount.cents) {
            out.add('discipline_month');
          }
        } else {
          // 没设总预算：各分类预算当月都没超算「不超支」
          var allWithin = true;
          for (final b in enabled) {
            final spent = await deps.budgetRepository.spentCents(
                bookId: deps.bookId,
                categoryId: b.categoryId,
                fromMs: fromMs,
                toMs: toMs);
            if ((spent.successOrNull ?? 0) > b.amount.cents) {
              allWithin = false;
              break;
            }
          }
          if (allWithin) out.add('discipline_month');
        }
      }

      // ── 目标：储蓄达标 ──
      final goals = (await deps.savingsGoalRepository.listByBook(deps.bookId))
              .successOrNull ??
          const [];
      if (goals.any((g) => g.targetCents > 0 && g.savedCents >= g.targetCents)) {
        out.add('goal_savings');
      }

      // ── 目标：还清债务（只看参与债务测算的贷款，外币贷款口径见 Account.supportsDebtTracking）──
      final accounts = (await deps.accountRepository.listWithBalances())
              .successOrNull ??
          const <AccountWithBalance>[];
      final loans = accounts
          .where((ab) => ab.account.supportsDebtTracking)
          .toList();
      if (loans.isNotEmpty && loans.every((ab) => ab.balanceCents >= 0)) {
        out.add('goal_debt');
      }
    } catch (_) {
      // 派生失败就当没点亮，不影响其它徽章
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Scaffold(
      appBar: PlainTopBar(title: s.myAchievements, showBack: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(Spacing.lg),
              children: [
                // 连续记账卡片
                Container(
                  decoration: BoxDecoration(
                    color: context.colors.surfaceCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.colors.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(Spacing.xl),
                    child: Row(
                      children: [
                        PlainIcon(
                          PlainIconData.flame,
                          size: 36,
                          color: context.colors.accent,
                        ),
                        const SizedBox(width: Spacing.lg),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.streakTracking, style: AppTextStyles.eyebrow.copyWith(color: context.colors.inkTertiary)),
                              const SizedBox(height: 4),
                              // 卡片主数字。设计稿字阶无 24 → 收到 `.amt.l` 档的 22；
                              // 但这不是金额（「12 天」），行高按 `normal` 走 29，不是 1.24。
                              Text(
                                _streak.isBroken ? s.streakBroken : s.daysCount(_streak.currentDays),
                                style: TextStyle(
                                  fontSize: 22,
                                  height: designLineHeight(22),
                                  fontWeight: FontWeight.w600,
                                  color: _streak.isBroken ? context.colors.inkTertiary : context.colors.ink,
                                ),
                              ),
                              Text(s.bestStreakDays(_streak.bestDays), style: TextStyle(fontSize: 12, color: context.colors.inkTertiary)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: Spacing.lg),

                // 权益券
                if (_vouchers.isNotEmpty) ...[
                  Text(s.myRewards, style: AppTextStyles.eyebrow.copyWith(color: context.colors.inkTertiary)),
                  const SizedBox(height: Spacing.sm),
                  ..._vouchers.map((v) => Container(
                    margin: const EdgeInsets.only(bottom: Spacing.xs),
                    decoration: BoxDecoration(
                      color: context.colors.surfaceCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: context.colors.border),
                    ),
                    child: PlainRow(
                      leading: PlainIcon(
                        PlainIconData.gift,
                        color: context.colors.accent,
                      ),
                      title: v.note.isNotEmpty ? v.note : s.voucher,
                      subtitle: '${v.grantDay} · ${GamificationRules.voucherActivateLabel}',
                      trailing: TextButton(
                        onPressed: () {
                          showDialog<void>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text(s.voucher),
                              content: Text('将在 ${GamificationRules.voucherActivateLabel} 自动激活，可抵扣订阅时长。\n\n当前版本暂不可使用。'),
                              actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.gotIt))],
                            ),
                          );
                        },
                        child: Text(s.detail, style: TextStyle(fontSize: 12, color: context.colors.primary)),
                      ),
                    ),
                  )),
                  const SizedBox(height: Spacing.lg),
                ],

                // 徽章墙
                Text(s.badgeWall, style: AppTextStyles.eyebrow.copyWith(color: context.colors.inkTertiary)),
                const SizedBox(height: Spacing.sm),
                Wrap(
                  spacing: Spacing.sm,
                  runSpacing: Spacing.sm,
                  children: [
                    for (final cat in BadgeCategory.values) ...[
                      for (final entry in _badgeDefs(cat))
                        _BadgeChip(
                          name: entry.key,
                          unlocked: _badges.contains(entry.value),
                          color: context.colors.primary,
                        ),
                    ],
                  ],
                ),
                const SizedBox(height: Spacing.xl),
                Text(
                  s.badgeFooter,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: context.colors.inkTertiary, height: 1.6),
                ),
              ],
            ),
    );
  }

  /// 预定义徽章（key=展示名, value=存储 id）。
  List<MapEntry<String, String>> _badgeDefs(BadgeCategory cat) {
    final s = AppStrings.of(context);
    return switch (cat) {
      BadgeCategory.persistence => [
        MapEntry(s.badgeStreak7, 'streak_7'),
        MapEntry(s.badgeStreak30, 'streak_30'),
        MapEntry(s.badgeStreak100, 'streak_100'),
      ],
      BadgeCategory.exploration => [
        MapEntry(s.badgeFirstBudget, 'explore_budget'),
        MapEntry(s.badgeFirstRule, 'explore_rules'),
        MapEntry(s.badgeFirstExport, 'explore_export'),
      ],
      BadgeCategory.discipline => [
        MapEntry(s.badgeMonthNoOverspend, 'discipline_month'),
      ],
      BadgeCategory.accumulation => [
        MapEntry(s.badgeAccum100, 'accum_100'),
        MapEntry(s.badgeAccum500, 'accum_500'),
        MapEntry(s.badgeAccum1000, 'accum_1000'),
      ],
      BadgeCategory.goal => [
        MapEntry(s.badgeGoalSavings, 'goal_savings'),
        MapEntry(s.badgeDebtClear, 'goal_debt'),
      ],
    };
  }
}

class _BadgeChip extends StatelessWidget {
  const _BadgeChip({required this.name, required this.unlocked, required this.color});
  final String name;
  final bool unlocked;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: unlocked ? color.withValues(alpha: 0.1) : context.colors.surfaceMuted,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: unlocked ? color : context.colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PlainIcon(
            unlocked ? PlainIconData.trophy : PlainIconData.lock,
            size: 16,
            color: unlocked ? color : context.colors.inkTertiary,
          ),
          const SizedBox(width: 6),
          Text(
            name,
            style: TextStyle(fontSize: 12, color: unlocked ? color : context.colors.inkTertiary),
          ),
        ],
      ),
    );
  }
}
