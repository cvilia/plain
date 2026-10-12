/// STORY-5.5 游戏化常量与逻辑测试。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:plain/core/constants/app_constants.dart';

void main() {
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
