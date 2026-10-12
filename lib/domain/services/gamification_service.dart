/// STORY-5.5 游戏化留存：连续记账、成就徽章、权益券。
/// 约束：不做积分商城、不做排行榜、权益券标注「V4.0 起生效」。
library;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:plain/core/constants/app_constants.dart';

/// 徽章定义。
class Badge {
  const Badge({
    required this.id,
    required this.category,
    required this.name,
    required this.description,
  });
  final String id;
  final BadgeCategory category;
  final String name;
  final String description;
}

/// 权益券。
class Voucher {
  const Voucher({required this.id, required this.grantDay, required this.note});
  final String id;
  final String grantDay;
  final String note;
}

/// 连续记账状态。
class StreakStatus {
  const StreakStatus({
    required this.currentDays,
    required this.bestDays,
    required this.isBroken,
  });
  final int currentDays;
  final int bestDays;
  final bool isBroken;
}

/// 游戏化状态管理（本地偏好）。
class GamificationService {
  /// 读取连续记账天数。断签时清零并持久化。
  static Future<StreakStatus> getStreak(DateTime now) async {
    try {
      final sp = await SharedPreferences.getInstance();
      int days = sp.getInt(GamificationRules.kPrefStreakDays) ?? 0;
      final best = sp.getInt(GamificationRules.kPrefStreakBest) ?? 0;
      final lastDay = sp.getString(GamificationRules.kPrefLastEntryDay) ?? '';
      final today = _dayKey(now);
      final yesterday = _dayKey(now.subtract(const Duration(days: 1)));
      final isBroken = lastDay.isNotEmpty && lastDay != today && lastDay != yesterday;
      if (isBroken && days > 0) {
        // 断签：清零当前连续天数，保留最长纪录
        days = 0;
        await sp.setInt(GamificationRules.kPrefStreakDays, 0);
      }
      return StreakStatus(currentDays: days, bestDays: best, isBroken: isBroken);
    } catch (_) {
      return const StreakStatus(currentDays: 0, bestDays: 0, isBroken: false);
    }
  }

  /// 记一笔后更新连续天数，返回是否有里程碑奖励。
  static Future<List<String>> recordEntry(DateTime now) async {
    final rewards = <String>[];
    try {
      final sp = await SharedPreferences.getInstance();
      final today = _dayKey(now);
      final yesterday = _dayKey(now.subtract(const Duration(days: 1)));
      final lastDay = sp.getString(GamificationRules.kPrefLastEntryDay) ?? '';

      // 累计笔数：每次记账都 +1
      final total = (sp.getInt(GamificationRules.kPrefTotalEntries) ?? 0) + 1;
      await sp.setInt(GamificationRules.kPrefTotalEntries, total);

      if (lastDay == today) {
        // 今天已记过，不重复更新连胜
        return rewards;
      }

      int days = sp.getInt(GamificationRules.kPrefStreakDays) ?? 0;
      int best = sp.getInt(GamificationRules.kPrefStreakBest) ?? 0;

      if (lastDay == yesterday) {
        days += 1;
      } else {
        days = 1; // 断签或首次
      }

      await sp.setString(GamificationRules.kPrefLastEntryDay, today);
      await sp.setInt(GamificationRules.kPrefStreakDays, days);
      if (days > best) {
        await sp.setInt(GamificationRules.kPrefStreakBest, days);
      }

      // 里程碑奖励
      final milestone = GamificationRules.streakVoucherMilestones[days];
      if (milestone != null && milestone > 0) {
        for (var i = 0; i < milestone; i++) {
          await _grantVoucher(sp, now, '连续 $days 天');
        }
        rewards.add('连续 $days 天');
      } else if (milestone == 0 && days == 100) {
        rewards.add('连续 100 天 · 终身卡抽奖资格');
      }

      // 累计笔数徽章
      if (GamificationRules.entryCountMilestones.contains(total)) {
        rewards.add('累计 $total 笔');
        await _addBadge(sp, 'accum_$total');
      }
    } catch (_) {}
    return rewards;
  }

  /// 获取所有已解锁徽章 id。
  static Future<Set<String>> getBadges() async {
    try {
      final sp = await SharedPreferences.getInstance();
      return (sp.getStringList(GamificationRules.kPrefBadges) ?? []).toSet();
    } catch (_) {
      return {};
    }
  }

  /// 获取所有权益券。
  static Future<List<Voucher>> getVouchers() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getStringList(GamificationRules.kPrefVouchers) ?? [];
      return raw.map((s) {
        final parts = s.split('|');
        return Voucher(
          id: parts.isNotEmpty ? parts[0] : s,
          grantDay: parts.length > 1 ? parts[1] : '',
          note: parts.length > 2 ? parts[2] : '',
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _grantVoucher(SharedPreferences sp, DateTime now, String note) async {
    // 加随机后缀避免同毫秒碰撞
    final id = 'v_${now.millisecondsSinceEpoch}_${DateTime.now().microsecondsSinceEpoch % 999999}';
    final day = _dayKey(now);
    final raw = sp.getStringList(GamificationRules.kPrefVouchers) ?? [];
    raw.add('$id|$day|$note');
    await sp.setStringList(GamificationRules.kPrefVouchers, raw);
  }

  static Future<void> _addBadge(SharedPreferences sp, String badgeId) async {
    final raw = sp.getStringList(GamificationRules.kPrefBadges) ?? [];
    if (!raw.contains(badgeId)) {
      raw.add(badgeId);
      await sp.setStringList(GamificationRules.kPrefBadges, raw);
    }
  }

  /// 解锁探索类徽章（首次使用某功能时调用）。
  static Future<void> unlockExplorationBadge(String featureId) async {
    try {
      final sp = await SharedPreferences.getInstance();
      await _addBadge(sp, 'explore_$featureId');
    } catch (_) {}
  }

  static String _dayKey(DateTime dt) {
    final t = dt.toLocal();
    return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
  }
}
