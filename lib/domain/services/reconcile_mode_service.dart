/// 账户对账模式（STORY-2.3）：逐笔勾选，不改余额。
library;

import 'package:plain/core/result/result.dart';
import 'package:plain/core/time/clock.dart';
import 'package:plain/domain/entities/ledger_entry.dart';
import 'package:plain/domain/repositories/repositories.dart';

class ReconcileProgress {
  const ReconcileProgress({
    required this.total,
    required this.reconciled,
    this.lastReconciledAt,
  });

  final int total;
  final int reconciled;
  final DateTime? lastReconciledAt;

  int get pending => total - reconciled;
  bool get isComplete => total > 0 && pending == 0;
}

/// 对账模式：只勾选，**不修改任何余额**（AC2）。
class ReconcileModeService {
  ReconcileModeService({
    required LedgerRepository repository,
    required Clock clock,
  })  : _repository = repository,
        _clock = clock;

  final LedgerRepository _repository;
  final Clock _clock;

  /// 勾选为「已核对」。
  Future<Result<LedgerEntry>> check(LedgerEntry entry) async {
    final now = _clock.now();
    final updated = entry.copyWith(
      reconciledAt: now,
      updatedAt: now,
      revision: entry.revision + 1,
      baseRevision: entry.revision,
    );
    return _repository.update(updated);
  }

  /// 取消勾选（恢复待对账）。
  Future<Result<LedgerEntry>> uncheck(LedgerEntry entry) async {
    final now = _clock.now();
    final updated = entry.copyWith(
      clearReconciledAt: true,
      updatedAt: now,
      revision: entry.revision + 1,
      baseRevision: entry.revision,
    );
    return _repository.update(updated);
  }

  /// 汇总某账户对账进度。
  Future<Result<ReconcileProgress>> progressFor(String accountId) async {
    final page = await _repository.listPage(
      filter: EntryFilter(accountId: accountId),
      limit: 500,
    );
    final items = page.successOrNull?.items ?? const <LedgerEntry>[];
    var reconciled = 0;
    DateTime? last;
    for (final e in items) {
      if (e.isReconciled) {
        reconciled++;
        final t = e.reconciledAt!;
        if (last == null || t.isAfter(last)) last = t;
      }
    }
    return ok(ReconcileProgress(
      total: items.length,
      reconciled: reconciled,
      lastReconciledAt: last,
    ));
  }
}
