/// Home flow list controller: keyset pagination + date grouping.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plain/app/bootstrap.dart';
import 'package:plain/core/refresh/data_invalidation.dart';
import 'package:plain/core/time/clock.dart';
import 'package:plain/domain/entities/category.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/entities/ledger_entry.dart';
import 'package:plain/domain/repositories/repositories.dart';

class DayGroup {
  DayGroup({required this.dayKey, required this.entries});
  final String dayKey;
  final List<LedgerEntry> entries;

  int get dayExpense =>
      entries.where((e) => e.type == EntryType.expense).fold(0, (s, e) => s + e.amount.cents);

  int get dayIncome =>
      entries.where((e) => e.type == EntryType.income).fold(0, (s, e) => s + e.amount.cents);
}

class FlowListState {
  const FlowListState({
    this.groups = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.errorMessage,
    this.categoryMap = const {},
  });

  final List<DayGroup> groups;
  final bool isLoading;
  final bool hasMore;
  final String? errorMessage;
  final Map<String, Category> categoryMap;

  FlowListState copyWith({
    List<DayGroup>? groups,
    bool? isLoading,
    bool? hasMore,
    String? errorMessage,
    Map<String, Category>? categoryMap,
    bool clearError = false,
  }) {
    return FlowListState(
      groups: groups ?? this.groups,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      categoryMap: categoryMap ?? this.categoryMap,
    );
  }
}

class FlowListController extends Notifier<FlowListState> {
  bool _pendingRefresh = false;

  @override
  FlowListState build() {
    // Any entry mutation bumps ledgerVersion — list follows automatically.
    // MUST defer: listen can fire while the widget tree is building (TickerMode
    // / layout callbacks), and `state=` inside a build phase throws.
    ref.listen(ledgerVersionProvider, (prev, next) {
      if (prev == next) return;
      // 正在加载时不要丢掉这次变更，记下待刷新，加载完再补
      if (state.isLoading) {
        _pendingRefresh = true;
        return;
      }
      Future.microtask(refresh);
    });
    // 分类筛选变化必须重载，否则列表停留在旧过滤结果
    ref.listen(flowCategoryFilterProvider, (prev, next) {
      if (prev == next) return;
      if (state.isLoading) {
        _pendingRefresh = true;
        return;
      }
      Future.microtask(refresh);
    });
    // STORY-8.2：成员筛选同理
    ref.listen(flowMemberFilterProvider, (prev, next) {
      if (prev == next) return;
      if (state.isLoading) {
        _pendingRefresh = true;
        return;
      }
      Future.microtask(refresh);
    });
    // Auto-load on first access
    Future.microtask(loadInitial);
    return const FlowListState();
  }

  LedgerRepository get _repository => ref.read(appDependenciesProvider).ledgerRepository;
  CategoryRepository get _categoryRepository => ref.read(appDependenciesProvider).categoryRepository;
  Clock get _clock => ref.read(appDependenciesProvider).clock;
  String get _bookId => ref.read(appDependenciesProvider).bookId;

  EntryCursor? _cursor;

  Future<void> loadInitial() async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, clearError: true);
    _cursor = null;

    final catResult = await _categoryRepository.listAll();
    final cats = catResult.successOrNull ?? const <Category>[];
    final catMap = {for (final c in cats) c.id: c};

    final result = await _repository.listPage(
      filter: EntryFilter(
        bookId: _bookId,
        categoryId: ref.read(flowCategoryFilterProvider),
        memberId: ref.read(flowMemberFilterProvider),
      ),
      limit: 50,
    );

    result.when(
      success: (page) {
        _cursor = page.nextCursor;
        state = state.copyWith(
          groups: _groupByDay(page.items),
          isLoading: false,
          hasMore: page.hasMore,
          categoryMap: catMap,
        );
        _flushPendingRefresh();
      },
      failure: (f) {
        state = state.copyWith(isLoading: false, errorMessage: f.code);
        _flushPendingRefresh();
      },
    );
  }

  /// 加载过程中又发生了写入：补一次刷新（防止丢更新）。
  void _flushPendingRefresh() {
    if (!_pendingRefresh) return;
    _pendingRefresh = false;
    Future.microtask(loadInitial);
  }

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore || _cursor == null) return;
    state = state.copyWith(isLoading: true);

    final result = await _repository.listPage(
      filter: EntryFilter(
        bookId: _bookId,
        categoryId: ref.read(flowCategoryFilterProvider),
        memberId: ref.read(flowMemberFilterProvider),
      ),
      cursor: _cursor,
      limit: 50,
    );

    result.when(
      success: (page) {
        _cursor = page.nextCursor;
        state = state.copyWith(
          groups: _appendGroups(state.groups, page.items),
          isLoading: false,
          hasMore: page.hasMore,
        );
      },
      failure: (f) {
        state = state.copyWith(isLoading: false, errorMessage: f.code);
      },
    );
  }

  /// 把新一页**增量**追加到已有分组尾部，而不是整表重排。
  ///
  /// 之前的写法是把「已加载全部条目 + 新一页」拉平后重新 `_groupByDay`——
  /// 每翻一页都要把截至目前的所有行再遍历一遍，翻到第 N 页就是 O(N²)。
  /// 数据量上万时，末尾那几次翻页会明显卡顿（每页都要重排上万条）。
  ///
  /// 之所以能安全增量：列表严格按 `dayKey` **降序**（新的在前），
  /// 新一页的日期一定不晚于已有最后一组的日期。所以只需处理两种情形：
  ///   · 新页首组与已有最后一组**同一天** → 并入那一组（同一天不能被切成两块）；
  ///   · 否则 → 追加为新组。
  ///
  /// ⚠️ 代价：本方法**不重排**已有分组。所以只有在「后续页日期不早于已有」
  /// 这个前提成立时结果才正确。该前提由 `listPage` 的 keyset 游标保证
  /// （`occurred_at` 降序 + id 兜底），若将来排序口径变了，这里必须同步改。
  List<DayGroup> _appendGroups(
    List<DayGroup> current,
    List<LedgerEntry> incoming,
  ) {
    if (incoming.isEmpty) return current;
    // 只对这一页（50 条）做分组，开销与已加载总量无关。
    final incomingGroups = _groupByDay(incoming);
    final merged = List<DayGroup>.of(current);
    for (final g in incomingGroups) {
      if (merged.isNotEmpty && merged.last.dayKey == g.dayKey) {
        final last = merged.removeLast();
        merged.add(DayGroup(dayKey: last.dayKey, entries: [...last.entries, ...g.entries]));
      } else {
        merged.add(g);
      }
    }
    return merged;
  }

  Future<void> refresh() => loadInitial();

  /// Soft-deleted entry stash for undo (PRD STORY-1.2 AC3).
  LedgerEntry? _lastDeleted;

  /// 同步从本地列表移除（Dismissible onDismissed 必须立刻让控件离开树）。
  void removeLocal(String id) {
    final groups = <DayGroup>[];
    for (final g in state.groups) {
      final kept = g.entries.where((e) => e.id != id).toList();
      if (kept.isEmpty) continue;
      groups.add(DayGroup(dayKey: g.dayKey, entries: kept));
    }
    state = state.copyWith(groups: groups);
  }

  Future<bool> deleteEntry(String id) async {
    // Stash for undo before deleting
    final entryResult = await _repository.getById(id);
    _lastDeleted = entryResult.successOrNull;

    // 幂等：UI 已先 removeLocal，这里再移一次无害
    removeLocal(id);

    final result = await _repository.softDelete(id);
    if (result.isSuccess) {
      // 不立刻 refresh，避免与 Dismissible 动画抢树；由页面 listen 在后续帧刷新
      ref.invalidateData.bumpEntryMutated();
      return true;
    }
    await loadInitial();
    return false;
  }

  /// Restore the last soft-deleted entry (undo).
  Future<bool> undoDelete() async {
    final entry = _lastDeleted;
    if (entry == null) return false;
    _lastDeleted = null;

    final result = await _repository.restore(entry.id);
    if (result.isSuccess) {
      ref.invalidateData.bumpEntryMutated();
      return true;
    }
    return false;
  }

  List<DayGroup> _groupByDay(List<LedgerEntry> entries) {
    final map = <String, List<LedgerEntry>>{};
    for (final e in entries) {
      final key = _clock.localDayKey(e.occurredAt);
      map.putIfAbsent(key, () => []).add(e);
    }
    final keys = map.keys.toList()..sort((a, b) => b.compareTo(a));
    return keys.map((k) => DayGroup(dayKey: k, entries: map[k]!)).toList();
  }
}

final flowListControllerProvider =
    NotifierProvider<FlowListController, FlowListState>(FlowListController.new);

/// 报表下钻用：流水列表的分类过滤（null = 不过滤）。
class FlowCategoryFilter extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? id) => state = id;
  /// 恢复完整流水（用户点「显示全部」）。
  void clear() => state = null;
}

final flowCategoryFilterProvider =
    NotifierProvider<FlowCategoryFilter, String?>(FlowCategoryFilter.new);

/// STORY-8.2 AC3：家庭页下钻用——流水列表的**归属成员**过滤（null = 不过滤）。
class FlowMemberFilter extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? id) => state = id;
  void clear() => state = null;
}

final flowMemberFilterProvider =
    NotifierProvider<FlowMemberFilter, String?>(FlowMemberFilter.new);
