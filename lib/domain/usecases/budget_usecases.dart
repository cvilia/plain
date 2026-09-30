/// Budget use cases: status resolution for a period. See PRD F5.1/F5.2.
library;

import 'package:plain/core/result/result.dart';
import 'package:plain/core/time/clock.dart';
import 'package:plain/domain/entities/budget.dart';
import 'package:plain/domain/repositories/repositories.dart';

class ResolveBudgetStatusUseCase {
  ResolveBudgetStatusUseCase({
    required BudgetRepository repository, required Clock clock,
  }) : _repository = repository, _clock = clock;

  final BudgetRepository _repository;
  final Clock _clock;

  /// Status for the total budget of [bookId], or null when unset.
  Future<Result<BudgetStatus?>> totalStatus(String bookId) async {
    final budgetRes = await _repository.getTotal(bookId);
    if (budgetRes.isFailure) {
      final f = budgetRes.failureOrNull!;
      if (f is NotFoundFailure) return ok(null);
      return err(f);
    }
    final budget = budgetRes.requireValue;
    return _statusFor(budget);
  }

  /// Status for every enabled budget in the book (total + categories).
  Future<Result<List<BudgetStatus>>> allStatuses(String bookId) async {
    final listRes = await _repository.listByBook(bookId);
    if (listRes.isFailure) return err(listRes.failureOrNull!);
    final out = <BudgetStatus>[];
    for (final b in listRes.requireValue) {
      if (!b.isEnabled) continue;
      final s = await _statusFor(b);
      if (s.isFailure) return err(s.failureOrNull!);
      final v = s.successOrNull;
      if (v != null) out.add(v);
    }
    return ok(out);
  }

  Future<Result<BudgetStatus?>> _statusFor(Budget budget) async {
    final window = budgetPeriodWindow(
      today: _clock.now().toLocal(), startDay: budget.startDay);
    final spentRes = await _repository.spentCents(
      bookId: budget.bookId, categoryId: budget.categoryId,
      fromMs: window.start.toUtc().millisecondsSinceEpoch,
      toMs: window.end.toUtc().millisecondsSinceEpoch,
    );
    if (spentRes.isFailure) return err(spentRes.failureOrNull!);
    return ok(BudgetStatus(
      budget: budget, spentCents: spentRes.requireValue,
      periodStart: window.start, periodEnd: window.end,
      today: _clock.now().toLocal(),
    ));
  }
}
