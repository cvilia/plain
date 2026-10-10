/// STORY-2.3 对账进度口径。
library;
import 'package:flutter_test/flutter_test.dart';
import 'package:plain/domain/services/reconcile_mode_service.dart';

void main() {
  test('pending = total - reconciled', () {
    const p = ReconcileProgress(total: 30, reconciled: 28);
    expect(p.pending, 2);
    expect(p.isComplete, false);
  });

  test('complete when all checked (AC3)', () {
    final p = ReconcileProgress(
      total: 3,
      reconciled: 3,
      lastReconciledAt: DateTime.utc(2026, 9, 30),
    );
    expect(p.isComplete, true);
    expect(p.pending, 0);
    expect(p.lastReconciledAt, DateTime.utc(2026, 9, 30));
  });
}
