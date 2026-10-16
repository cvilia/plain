/// STORY-5.5 游戏化常量与逻辑测试。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:plain/core/constants/app_constants.dart';
import 'package:plain/domain/services/gamification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('坚持类徽章在里程碑点亮（原先只发券、徽章永远灰着）', () async {
    SharedPreferences.setMockInitialValues({});
    final day = DateTime(2026, 6, 1, 10);
    // 连续 7 天记账
    for (var i = 0; i < 7; i++) {
      await GamificationService.recordEntry(day.add(Duration(days: i)));
    }
    final badges = await GamificationService.getBadges();
    expect(badges.contains('streak_7'), isTrue, reason: '连续 7 天要点亮徽章，不只是发券');
    expect(badges.contains('streak_30'), isFalse);

    // 里程碑阈值与成就页的 id 定义一致
    expect(GamificationRules.streakBadgeMilestones, containsAll([7, 30, 100]));
  });

  test('探索类徽章按功能 id 点亮，且不重复累积', () async {
    SharedPreferences.setMockInitialValues({});
    await GamificationService.unlockExplorationBadge('budget');
    await GamificationService.unlockExplorationBadge('budget');
    await GamificationService.unlockExplorationBadge('export');
    final badges = await GamificationService.getBadges();
    expect(badges.contains('explore_budget'), isTrue);
    expect(badges.contains('explore_export'), isTrue);
    expect(badges.where((b) => b == 'explore_budget').length, 1, reason: '幂等');
    expect(badges.contains('explore_rules'), isFalse, reason: '没触发就不该有');
  });
  test('streak voucher milestones match PRD', () {
    expect(GamificationRules.streakVoucherMilestones[7], 1);
    expect(GamificationRules.streakVoucherMilestones[30], 3);
    expect(GamificationRules.streakVoucherMilestones[100], 0); // 终身卡抽奖
  });

  test('entry count milestones include 1000', () {
    expect(GamificationRules.entryCountMilestones.contains(100), isTrue);
    expect(GamificationRules.entryCountMilestones.contains(1000), isTrue);
    expect(GamificationRules.entryCountMilestones.contains(5000), isTrue);
  });

  test('voucher activation label is V4.0', () {
    expect(GamificationRules.voucherActivateLabel, 'V4.0 起生效');
  });

  test('badge categories are 5 types', () {
    expect(BadgeCategory.values.length, 5);
  });
}
