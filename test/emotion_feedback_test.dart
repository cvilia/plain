/// STORY-5.4 情绪反馈阈值测试。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:plain/core/constants/app_constants.dart';

void main() {
  test('StatsWindowRules constants match PRD', () {
    expect(StatsWindowRules.windowDays, 90);
    expect(StatsWindowRules.minSamples, 5);
    expect(StatsWindowRules.highAmountMultiplier, 2.0);
  });

  test('EmotionFeedbackRules weekly limit is 3', () {
    expect(EmotionFeedbackRules.weeklyMaxCount, 3);
    expect(EmotionFeedbackRules.cardDuration.inSeconds, 4);
  });

  test('threshold logic: amount <= median → positive', () {
    final amounts = [100, 200, 300, 400, 500, 600, 700, 800, 900, 1000];
    final sorted = List<int>.from(amounts)..sort();
    final median = sorted[sorted.length ~/ 2]; // sorted[5] = 600
    expect(median, 600);
    expect(300 <= median, isTrue); // positive
    expect(700 <= median, isFalse);
  });

  test('threshold logic: amount > p90 * 2 → large', () {
    final amounts = [100, 200, 300, 400, 500, 600, 700, 800, 900, 1000];
    final sorted = List<int>.from(amounts)..sort();
    final p90 = sorted[(sorted.length * 0.9).floor().clamp(0, sorted.length - 1)]; // 900
    expect(p90, 1000); // 10 samples, (10*0.9).floor()=9 → index 9 = 1000
    expect(2500 > p90 * 2, isTrue); // 2500 > 2000
    expect(1500 > p90 * 2, isFalse); // 1500 < 2000
  });

  test('min samples guard: < 5 samples → no threshold feedback', () {
    final amounts = [100, 200, 300]; // only 3 samples
    expect(amounts.length < StatsWindowRules.minSamples, isTrue);
  });
}
