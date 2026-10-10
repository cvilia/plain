/// STORY-7.1 储蓄目标：每月需存与进度。
library;
import 'package:flutter_test/flutter_test.dart';
import 'package:plain/domain/entities/savings_goal.dart';

void main() {
  final now = DateTime.utc(2026, 1, 1);
  final due = DateTime.utc(2026, 12, 31);

  SavingsGoal goal({int target = 300000, int saved = 0, DateTime? dueAt}) {
    return SavingsGoal(
      id: 'g1', bookId: 'b1', name: '车险',
      targetCents: target, savedCents: saved,
      dueAt: dueAt ?? due,
      createdAt: now, updatedAt: now, deviceId: 'd1',
    );
  }

  test('AC1 monthly required = (target-saved)/months', () {
    // 3000 元 / 12 个月 = 250
    final g = goal(target: 300000);
    expect(g.monthlyRequiredCentsAt(now), 25000);
  });

  test('progress clamps 0..1', () {
    expect(goal(target: 100000, saved: 25000).progress, 0.25);
    expect(goal(target: 100000, saved: 200000).progress, 1.0);
  });

  test('overdue when due date passed and not achieved', () {
    final g = goal(target: 100000, saved: 1000, dueAt: DateTime.utc(2025, 1, 1));
    expect(g.isOverdueAt(DateTime.utc(2026, 1, 1)), true);
    expect(goal().isOverdueAt(now), false);
  });

  test('min remaining months avoids div by zero', () {
    final g = goal(target: 100000, dueAt: now);
    expect(g.monthlyRequiredCentsAt(now), 100000);
  });

  test('AC2 debt progress = repaid/total (STORY-7.2)', () {
    final g = SavingsGoal(
      id: 'd1', bookId: 'b1', name: '房贷',
      goalType: GoalType.debt,
      targetCents: 80000000, savedCents: 12000000,
      remainingTerms: 120,
      createdAt: now, updatedAt: now, deviceId: 'd1',
    );
    expect(g.progress, 0.15);
    expect(g.remainingCents, 68000000);
    expect(g.isAchieved, false);
  });
}
