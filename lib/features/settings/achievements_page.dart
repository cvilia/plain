/// STORY-5.5 成就徽章墙：展示已解锁徽章 + 权益券 + 连续记账状态。
/// 约束：不做排行榜、不做积分商城。
library;

import 'package:flutter/material.dart';
import 'package:plain/app/theme/app_colors.dart';
import 'package:plain/app/theme/design_tokens.dart';
import 'package:plain/core/constants/app_constants.dart';
import 'package:plain/domain/services/gamification_service.dart';

class AchievementsPage extends StatefulWidget {
  const AchievementsPage({super.key});

  @override
  State<AchievementsPage> createState() => _AchievementsPageState();
}

class _AchievementsPageState extends State<AchievementsPage> {
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
    if (!mounted) return;
    setState(() {
      _streak = streak;
      _badges = badges;
      _vouchers = vouchers;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的成就')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(Spacing.lg),
              children: [
                // 连续记账卡片
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(Spacing.xl),
                    child: Row(
                      children: [
                        Icon(Icons.local_fire_department, size: 36, color: context.colors.accent),
                        const SizedBox(width: Spacing.lg),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('连续记账', style: TextStyle(fontSize: 12, color: context.colors.inkTertiary, letterSpacing: 2)),
                              const SizedBox(height: 4),
                              Text(
                                _streak.isBroken ? '已断签' : '${_streak.currentDays} 天',
                                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: _streak.isBroken ? context.colors.inkTertiary : context.colors.ink),
                              ),
                              Text('历史最长 ${_streak.bestDays} 天', style: TextStyle(fontSize: 11, color: context.colors.inkTertiary)),
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
                  Text('我的奖励', style: TextStyle(fontSize: 12, color: context.colors.inkTertiary, letterSpacing: 2)),
                  const SizedBox(height: Spacing.sm),
                  ..._vouchers.map((v) => Card(
                    margin: const EdgeInsets.only(bottom: Spacing.xs),
                    child: ListTile(
                      leading: Icon(Icons.card_giftcard, color: context.colors.accent),
                      title: Text(v.note.isNotEmpty ? v.note : '权益券', style: const TextStyle(fontSize: 14)),
                      subtitle: Text(
                        '${v.grantDay} · ${GamificationRules.voucherActivateLabel}',
                        style: TextStyle(fontSize: 11, color: context.colors.inkTertiary),
                      ),
                      trailing: TextButton(
                        onPressed: () {
                          showDialog<void>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('权益券'),
                              content: Text('将在 ${GamificationRules.voucherActivateLabel} 自动激活，可抵扣订阅时长。\n\n当前版本暂不可使用。'),
                              actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('知道了'))],
                            ),
                          );
                        },
                        child: Text('详情', style: TextStyle(fontSize: 12, color: context.colors.primary)),
                      ),
                    ),
                  )),
                  const SizedBox(height: Spacing.lg),
                ],

                // 徽章墙
                Text('徽章墙', style: TextStyle(fontSize: 12, color: context.colors.inkTertiary, letterSpacing: 2)),
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
                  '记账是私事，这里不做排行榜和积分商城。\n坚持本身就是最好的奖励。',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: context.colors.inkTertiary, height: 1.6),
                ),
              ],
            ),
    );
  }

  /// 预定义徽章（key=展示名, value=存储 id）。
  List<MapEntry<String, String>> _badgeDefs(BadgeCategory cat) {
    return switch (cat) {
      BadgeCategory.persistence => [
        const MapEntry('连续 7 天', 'streak_7'),
        const MapEntry('连续 30 天', 'streak_30'),
        const MapEntry('连续 100 天', 'streak_100'),
      ],
      BadgeCategory.exploration => [
        const MapEntry('首次设预算', 'explore_budget'),
        const MapEntry('首次用规则', 'explore_rules'),
        const MapEntry('首次用导出', 'explore_export'),
      ],
      BadgeCategory.discipline => [
        const MapEntry('月度不超支', 'discipline_month'),
      ],
      BadgeCategory.accumulation => [
        const MapEntry('累计 100 笔', 'accum_100'),
        const MapEntry('累计 500 笔', 'accum_500'),
        const MapEntry('累计 1000 笔', 'accum_1000'),
      ],
      BadgeCategory.goal => [
        const MapEntry('达成储蓄目标', 'goal_savings'),
        const MapEntry('还清债务', 'goal_debt'),
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
          Icon(unlocked ? Icons.emoji_events : Icons.lock_outline, size: 16, color: unlocked ? color : context.colors.inkTertiary),
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
