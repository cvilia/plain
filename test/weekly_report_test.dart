/// STORY-9.5 消费周报测试。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:plain/core/constants/app_constants.dart';
import 'package:plain/domain/entities/reminder.dart';
import 'package:plain/domain/services/weekly_report_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('推送时刻与周窗口', () {
    test('周报推送时间为周日 20:00，周首日为周一', () {
      expect(WeeklyReportRules.pushWeekday, DateTime.sunday);
      expect(WeeklyReportRules.pushHour, 20);
      expect(WeeklyReportRules.weekStartWeekday, DateTime.monday);
    });

    test('本周起点是本周一 00:00', () {
      // 2026-01-11 是周日，本周一为 2026-01-05
      final start = WeeklyReportService.weekStartOf(DateTime(2026, 1, 11, 20, 30));
      expect(start, DateTime(2026, 1, 5));
      // 周一当天取到的就是自己
      expect(
        WeeklyReportService.weekStartOf(DateTime(2026, 1, 5, 6)),
        DateTime(2026, 1, 5),
      );
      // 跨月：2026-03-01 是周日，本周一为 2026-02-23
      expect(
        WeeklyReportService.weekStartOf(DateTime(2026, 3, 1, 9)),
        DateTime(2026, 2, 23),
      );
    });

    test('本周推送时刻是周日 20:00', () {
      expect(
        WeeklyReportService.weekDueAt(DateTime(2026, 1, 8, 9)),
        DateTime(2026, 1, 11, 20),
      );
      expect(
        WeeklyReportService.weekKeyOf(DateTime(2026, 1, 11, 20)),
        '2026-01-05',
      );
    });
  });

  group('推送判定', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('到点前不推，到点后推且只推一次', () async {
      expect(await WeeklyReportService
          .shouldPush(DateTime(2026, 1, 11, 19, 59)), isFalse);
      expect(
          await WeeklyReportService.shouldPush(DateTime(2026, 1, 11, 20)), isTrue);
      await WeeklyReportService.markPushed(DateTime(2026, 1, 11, 20, 1));
      expect(await WeeklyReportService
          .shouldPush(DateTime(2026, 1, 11, 23)), isFalse);
    });

    test('AC3：关闭后到点也不推', () async {
      await WeeklyReportService.setEnabled(false);
      expect(await WeeklyReportService
          .shouldPush(DateTime(2026, 1, 11, 21)), isFalse);
      await WeeklyReportService.setEnabled(true);
      expect(
          await WeeklyReportService.shouldPush(DateTime(2026, 1, 11, 21)), isTrue);
    });

    test('新的一周重新可推', () async {
      await WeeklyReportService.markPushed(DateTime(2026, 1, 11, 20, 30));
      // 1/12 周一：本周的周日晚是 1/18，尚未到点
      expect(await WeeklyReportService
          .shouldPush(DateTime(2026, 1, 12, 9)), isFalse);
      expect(await WeeklyReportService
          .shouldPush(DateTime(2026, 1, 18, 20)), isTrue);
    });

    test('提醒方式默认响铃，可切静默并持久化', () async {
      expect(await WeeklyReportService.level(), ReminderLevel.ring);
      await WeeklyReportService.setLevel(ReminderLevel.silent);
      expect(await WeeklyReportService.level(), ReminderLevel.silent);
    });
  });

  group('周报正文', () {
    test('有对比：环比与主要分类都有陈述', () {
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
      expect(r.highlights, contains('支出比上周同期有所减少，继续保持'));
      expect(r.highlights, contains('「餐饮」是本周主要支出，占 42%'));
      expect(r.topCategory, '餐饮');
      // 没给上周分类 → 不写占比变化（不能把「没数据」当 0%）
      expect(r.highlights.any((h) => h.contains('→')), isFalse);
    });

    test('无对比：不写环比结论', () {
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

    test('AC2：结论只陈述、不含贬义与说教', () {
      const blameWords = ['浪费', '败家', '克制', '应该', '注意', '建议', '警告', '超支'];
      for (final change in [-40, -5, 5, 60]) {
        final r = WeeklyReportService.generate(
          weekStart: '2026-01-05',
          weekEnd: '2026-01-11',
          totalExpenseCents: 100000 + change * 100,
          totalIncomeCents: 200000,
          entryCount: 12,
          topCategories: {'购物': 60000, '餐饮': 40000},
          lastWeekExpenseCents: 100000,
          lastWeekCategories: {'购物': 20000, '餐饮': 80000},
          largestExpenseCents: 30000,
        );
        for (final h in r.highlights) {
          for (final w in blameWords) {
            expect(h.contains(w), isFalse, reason: '命中贬义词「$w」：$h');
          }
        }
      }
    });

    test('占比上升用中性算式陈述，不用评价词', () {
      final r = WeeklyReportService.generate(
        weekStart: '2026-01-05',
        weekEnd: '2026-01-11',
        totalExpenseCents: 100000,
        totalIncomeCents: 0,
        entryCount: 6,
        topCategories: {'购物': 60000, '餐饮': 40000},
        lastWeekExpenseCents: 100000,
        lastWeekCategories: {'购物': 20000, '餐饮': 80000},
      );
      expect(r.highlights, contains('「购物」占比 20% → 60%'));
    });

    test('单笔最大只陈述金额', () {
      final r = WeeklyReportService.generate(
        weekStart: '2026-01-05',
        weekEnd: '2026-01-11',
        totalExpenseCents: 100000,
        totalIncomeCents: 0,
        entryCount: 6,
        topCategories: const {},
        lastWeekExpenseCents: 0,
        largestExpenseCents: 30000,
      );
      expect(r.highlights, contains('本周单笔最大 ¥300.00'));
    });

    test('summary 含关键信息', () {
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

    test('通知正文一行，无评价', () {
      final r = WeeklyReportService.generate(
        weekStart: '2026-01-05',
        weekEnd: '2026-01-11',
        totalExpenseCents: 120000,
        totalIncomeCents: 0,
        entryCount: 12,
        topCategories: {'餐饮': 50000, '购物': 70000},
        lastWeekExpenseCents: 0,
      );
      expect(r.notificationBody, '支出 ¥1200.00 · 主要「购物」 · 12 笔');
      expect(r.notificationBody.contains('\n'), isFalse);
    });

    test('空周不生成噪音文案', () {
      final r = WeeklyReportService.generate(
        weekStart: '2026-01-05',
        weekEnd: '2026-01-11',
        totalExpenseCents: 0,
        totalIncomeCents: 0,
        entryCount: 0,
        topCategories: const {},
        lastWeekExpenseCents: 0,
      );
      expect(r.isEmpty, isTrue);
      expect(r.highlights, isEmpty);
    });
  });

  group('夜间免打扰', () {
    test('23:00–07:00 响铃降级为静默（与提醒中心同一阈值）', () {
      expect(
        WeeklyReportService.applyQuietHours(
            ReminderLevel.ring, DateTime(2026, 1, 11, 23, 30)),
        ReminderLevel.silent,
      );
      expect(
        WeeklyReportService.applyQuietHours(
            ReminderLevel.ring, DateTime(2026, 1, 11, 6, 30)),
        ReminderLevel.silent,
      );
      // 周日晚 20:00 不在夜间，保持用户设置
      expect(
        WeeklyReportService.applyQuietHours(
            ReminderLevel.ring, DateTime(2026, 1, 11, 20)),
        ReminderLevel.ring,
      );
      expect(
        WeeklyReportService.applyQuietHours(
            ReminderLevel.silent, DateTime(2026, 1, 11, 20)),
        ReminderLevel.silent,
      );
    });
  });
}
