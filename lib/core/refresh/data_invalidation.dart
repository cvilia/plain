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

  /// Home card layout (order + hidden set). Local-only.
  homeLayout,
}

/// Monotonic per-scope versions. Bump on write; watch on the read side.
class DataInvalidation extends Notifier<Map<DataScope, int>> {
  /// STORY-8.1：本地写入的旁路钩子（同步调度器注册）。
  /// 放在这里是为了让「写→推」只有一个触发点，不给每个写路径都塞同步代码。
  static void Function()? localMutationHook;

  static const Map<DataScope, int> _zero = {
    DataScope.ledger: 0,
    DataScope.accounts: 0,
    DataScope.categories: 0,
    DataScope.budget: 0,
    DataScope.recurring: 0,
    DataScope.theme: 0,
    DataScope.homeLayout: 0,
  };

  @override
  Map<DataScope, int> build() => _zero;

  int versionOf(DataScope scope) => state[scope] ?? 0;

  /// Increment one scope. Readers of that scope rebuild.
  void bump(DataScope scope) {
    state = {...state, scope: (state[scope] ?? 0) + 1};
    // STORY-8.1 AC1：本地写入后立刻安排一次推送，另一端 ≤10 秒可见。
    // 主题/首页布局是本机偏好（不同步），不触发。
    if (scope != DataScope.theme && scope != DataScope.homeLayout) {
      localMutationHook?.call();
    }
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

  /// 所有 scope 各抬一格。
  ///
  /// 「加载失败 → 重试」用它：缓存型读模型全部 watch 版本号，抬一格即全部重取，
  /// 不用每个页面各写一遍「该 invalidate 哪个 provider」。
  void bumpEverything() => bumpAll(DataScope.values);

  /// Home card layout change (order / hidden / preset).
  void bumpHomeLayout() => bump(DataScope.homeLayout);
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

/// Watch in home page card layout.
final homeLayoutVersionProvider = Provider<int>(
  (ref) => ref.watch(dataInvalidationProvider)[DataScope.homeLayout] ?? 0,
);

/// One-shot bump helpers on the notifier handle.
extension DataInvalidationRefX on Ref {
  DataInvalidation get invalidateData => read(dataInvalidationProvider.notifier);
}

/// Same helper for widget-layer [WidgetRef].
extension DataInvalidationWidgetRefX on WidgetRef {
  DataInvalidation get invalidateData => read(dataInvalidationProvider.notifier);
}
