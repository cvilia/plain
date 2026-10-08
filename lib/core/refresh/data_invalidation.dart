/// Domain invalidation clocks — the app-wide "data just changed" bus.
///
/// ## Architecture rules (see AGENTS.md 「数据刷新」)
///
/// 1. **Write → bump.** After *any* local mutation, bump the relevant
///    [DataScope] via [DataInvalidation]. Never rely on "the previous page
///    will refresh() when I pop".
/// 2. **Read → watch.** Every cached read model (FutureProvider / Notifier
///    that loads from DB) MUST `ref.watch(xxxVersionProvider)` (or
///    `ref.listen` it for controllers). Then it refetches automatically.
/// 3. **No cross-controller refresh.** Do not call another feature's
///    `refresh()` from a page. Bump a scope instead.
/// 4. Prefer a scope bump over ad-hoc `ref.invalidate(otherProvider)` so
///    the dependency graph stays one-way and greppable.
/// 5. **Defer writes in `ref.listen`.** The callback may run during widget
///    build; wrap side effects in `Future.microtask` or they will throw
///    "Tried to modify a provider while the widget tree was building".
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Local data domains. Mutations bump a scope; readers watch its version.
enum DataScope {
  /// Entries: create / edit / soft-delete / restore / import.
  ledger,

  /// Account list and balances.
  accounts,

  /// Category tree (also invalidates category pickers).
  categories,

  /// Budget rules and resolved budget status.
  budget,

  /// Recurring rules and generated batches.
  recurring,

  /// Theme / appearance prefs only. Local-only, never cloud-synced (INV-3).
  theme,
}

/// Monotonic per-scope versions. Bump on write; watch on the read side.
class DataInvalidation extends Notifier<Map<DataScope, int>> {
  static const Map<DataScope, int> _zero = {
    DataScope.ledger: 0,
    DataScope.accounts: 0,
    DataScope.categories: 0,
    DataScope.budget: 0,
    DataScope.recurring: 0,
    DataScope.theme: 0,
  };

  @override
  Map<DataScope, int> build() => _zero;

  int versionOf(DataScope scope) => state[scope] ?? 0;

  /// Increment one scope. Readers of that scope rebuild.
  void bump(DataScope scope) {
    state = {...state, scope: (state[scope] ?? 0) + 1};
  }

  /// Increment several scopes at once.
  void bumpAll(Iterable<DataScope> scopes) {
    final next = {...state};
    for (final s in scopes) {
      next[s] = (next[s] ?? 0) + 1;
    }
    state = next;
  }

  /// Entry write. Flows into list, budget strip, and account balances.
  void bumpEntryMutated() => bumpAll(const {
        DataScope.ledger,
        DataScope.budget,
        DataScope.accounts,
      });

  /// Category write (rename/merge/add/delete).
  void bumpCategoriesMutated() => bumpAll(const {
        DataScope.categories,
        DataScope.ledger,
      });

  /// Account write (add/reorder/balance edit).
  void bumpAccountsMutated() => bumpAll(const {
        DataScope.accounts,
        DataScope.ledger,
      });

  /// Budget rule write.
  void bumpBudgetMutated() => bump(DataScope.budget);

  /// Recurring rule write or batch generate/undo.
  void bumpRecurringMutated() => bumpAll(const {
        DataScope.recurring,
        DataScope.ledger,
        DataScope.budget,
        DataScope.accounts,
      });

  /// Theme / appearance change (id or mode).
  void bumpTheme() => bump(DataScope.theme);
}

final dataInvalidationProvider =
    NotifierProvider<DataInvalidation, Map<DataScope, int>>(DataInvalidation.new);

// ── Scoped versions — use these in read models ───────────────────────────────

/// Watch in anything that displays entries (lists, reports, exports).
final ledgerVersionProvider = Provider<int>(
  (ref) => ref.watch(dataInvalidationProvider)[DataScope.ledger] ?? 0,
);

/// Watch in account lists / balance summaries.
final accountsVersionProvider = Provider<int>(
  (ref) => ref.watch(dataInvalidationProvider)[DataScope.accounts] ?? 0,
);

/// Watch in category lists and pickers.
final categoriesVersionProvider = Provider<int>(
  (ref) => ref.watch(dataInvalidationProvider)[DataScope.categories] ?? 0,
);

/// Watch in budget UI.
final budgetVersionProvider = Provider<int>(
  (ref) => ref.watch(dataInvalidationProvider)[DataScope.budget] ?? 0,
);

/// Watch in recurring UI.
final recurringVersionProvider = Provider<int>(
  (ref) => ref.watch(dataInvalidationProvider)[DataScope.recurring] ?? 0,
);

/// Watch in anything that used to call `watchBrandTheme`.
/// Theme colors now live on ThemeData via AppColors ThemeExtension, so a
/// theme change rebuilds dependents automatically — this provider remains
/// for any non-widget listeners.
final themeVersionProvider = Provider<int>(
  (ref) => ref.watch(dataInvalidationProvider)[DataScope.theme] ?? 0,
);

/// One-shot bump helpers on the notifier handle.
extension DataInvalidationRefX on Ref {
  DataInvalidation get invalidateData => read(dataInvalidationProvider.notifier);
}

/// Same helper for widget-layer [WidgetRef].
extension DataInvalidationWidgetRefX on WidgetRef {
  DataInvalidation get invalidateData => read(dataInvalidationProvider.notifier);
}
