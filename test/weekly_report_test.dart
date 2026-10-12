/// STORY-9.5 消费周报测试。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:plain/core/constants/app_constants.dart';
import 'package:plain/domain/services/weekly_report_service.dart';

void main() {
  test('weekly report push time is Sunday 20:00', () {
    expect(WeeklyReportRules.pushWeekday, DateTime.sunday);
    expect(WeeklyReportRules.pushHour, 20);
  });

  test('generate report with comparison', () {
    final r = WeeklyReportService.generate(
      weekStart: '2026-01-05',
      weekEnd: '2026-01-11',
      totalExpenseCents: 120000,
      totalIncomeCents: 200000,
      entryCount: 12,
      topCategories: {'餐饮': 50000, '购物': 40000, '交通': 30000},
      lastWeekExpenseCents: 150000,
    );
    expect(r.totalExpenseCents, 120000);
    expect(r.entryCount, 12);
    expect(r.isComparedToLastWeek, isTrue);
    expect(r.expenseChangePercent, closeTo(-20.0, 0.1));
    expect(r.highlights, contains('支出比上周有所减少，继续保持'));
    expect(r.highlights, contains('「餐饮」是本周主要支出'));
  });

  test('generate report without comparison', () {
    final r = WeeklyReportService.generate(
      weekStart: '2026-01-05',
      weekEnd: '2026-01-11',
      totalExpenseCents: 50000,
      totalIncomeCents: 100000,
      entryCount: 5,
      topCategories: {'餐饮': 50000},
      lastWeekExpenseCents: 0,
    );
    expect(r.isComparedToLastWeek, isFalse);
    expect(r.expenseChangePercent, 0);
  });

  test('report summary contains key info', () {
    final r = WeeklyReportService.generate(
      weekStart: '2026-01-05',
      weekEnd: '2026-01-11',
      totalExpenseCents: 120000,
      totalIncomeCents: 200000,
      entryCount: 12,
      topCategories: {'餐饮': 50000},
      lastWeekExpenseCents: 150000,
    );
    final s = r.summary;
    expect(s, contains('本周消费画像'));
    expect(s, contains('1200.00'));
    expect(s, contains('12 笔'));
  });
}
