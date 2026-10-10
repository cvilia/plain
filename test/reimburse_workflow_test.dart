/// STORY-1.8 报销状态机测试。
library;
import 'package:flutter_test/flutter_test.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/services/reimburse_workflow.dart';

void main() {
  test('valid transitions', () {
    expect(canTransition(ReimburseStatus.none, ReimburseStatus.pending), true);
    expect(canTransition(ReimburseStatus.pending, ReimburseStatus.submitted), true);
    expect(canTransition(ReimburseStatus.submitted, ReimburseStatus.partial), true);
    expect(canTransition(ReimburseStatus.partial, ReimburseStatus.reimbursed), true);
    expect(canTransition(ReimburseStatus.pending, ReimburseStatus.abandoned), true);
  });

  test('invalid transitions blocked', () {
    expect(canTransition(ReimburseStatus.none, ReimburseStatus.reimbursed), false);
    expect(canTransition(ReimburseStatus.reimbursed, ReimburseStatus.pending), false);
    expect(canTransition(ReimburseStatus.abandoned, ReimburseStatus.submitted), false);
    expect(canTransition(ReimburseStatus.pending, ReimburseStatus.partial), false);
  });

  test('inFlow excludes none and abandoned (AC5)', () {
    expect(ReimburseStatus.pending.inFlow, true);
    expect(ReimburseStatus.none.inFlow, false);
    expect(ReimburseStatus.abandoned.inFlow, false);
    expect(ReimburseStatus.reimbursed.inFlow, true);
  });
}
