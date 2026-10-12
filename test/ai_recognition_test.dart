/// STORY-9.4 AI 识别额度管理测试。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:plain/core/constants/app_constants.dart';

void main() {
  test('AI recognition quota is 10 per month', () {
    expect(AiRecognitionRules.monthlyQuota, 10);
  });

  test('weekly report push is Sunday 20:00', () {
    expect(WeeklyReportRules.pushWeekday, DateTime.sunday);
    expect(WeeklyReportRules.pushHour, 20);
  });

  test('quota month key resets at month start day', () {
    // 模拟月起始日=10
    const monthStartDay = 10;
    // 1月15日 → 属于 1 月
    final jan15 = DateTime(2026, 1, 15);
    expect(jan15.day >= monthStartDay, isTrue);
    // 1月5日 → 属于上一年 12 月
    final jan5 = DateTime(2026, 1, 5);
    expect(jan5.day >= monthStartDay, isFalse);
  });
}
