/// STORY-1.8 报销状态机。
library;

import 'package:plain/core/result/result.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/entities/ledger_entry.dart';
import 'package:plain/domain/repositories/repositories.dart';

/// 合法状态迁移。
const Map<ReimburseStatus, Set<ReimburseStatus>> kReimburseTransitions = {
  ReimburseStatus.none: {ReimburseStatus.pending},
  ReimburseStatus.pending: {
    ReimburseStatus.submitted,
    ReimburseStatus.abandoned,
  },
  ReimburseStatus.submitted: {
    ReimburseStatus.partial,
    ReimburseStatus.reimbursed,
    ReimburseStatus.abandoned,
  },
  ReimburseStatus.partial: {
    ReimburseStatus.reimbursed,
    ReimburseStatus.abandoned,
  },
  ReimburseStatus.reimbursed: {},
  ReimburseStatus.abandoned: {},
};

bool canTransition(ReimburseStatus from, ReimburseStatus to) =>
    kReimburseTransitions[from]?.contains(to) ?? false;

/// 标记「需报销」/ 推进状态 / 放弃（保留账单，只退出流程）。
class ReimburseWorkflow {
  ReimburseWorkflow({
    required LedgerRepository repository,
    required DateTime Function() now,
  })  : _repository = repository,
        _now = now;

  final LedgerRepository _repository;
  final DateTime Function() _now;

  Future<Result<LedgerEntry>> markPending(LedgerEntry entry) =>
      _transition(entry, ReimburseStatus.pending);

  Future<Result<LedgerEntry>> submit(LedgerEntry entry) =>
      _transition(entry, ReimburseStatus.submitted);

  Future<Result<LedgerEntry>> markPartial(LedgerEntry entry) =>
      _transition(entry, ReimburseStatus.partial);

  Future<Result<LedgerEntry>> markReimbursed(LedgerEntry entry) =>
      _transition(entry, ReimburseStatus.reimbursed);

  /// AC5：放弃报销，账单保留，橙标消失。
  Future<Result<LedgerEntry>> abandon(LedgerEntry entry) =>
      _transition(entry, ReimburseStatus.abandoned);

  Future<Result<LedgerEntry>> _transition(
    LedgerEntry entry,
    ReimburseStatus to,
  ) async {
    if (!canTransition(entry.reimburseStatus, to)) {
      return err<LedgerEntry>(const ValidationFailure(
          'reimburse.invalid_transition', 'state'));
    }
    final now = _now();
    final updated = entry.copyWith(
      reimburseStatus: to,
      updatedAt: now,
      revision: entry.revision + 1,
      baseRevision: entry.revision,
    );
    return _repository.update(updated);
  }
}
