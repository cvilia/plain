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
  @override
  FlowListState build() {
    // Any entry mutation bumps ledgerVersion — list follows automatically.
    // MUST defer: listen can fire while the widget tree is building (TickerMode
    // / layout callbacks), and `state=` inside a build phase throws.
    ref.listen(ledgerVersionProvider, (prev, next) {
      if (prev == next || state.isLoading) return;
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
      filter: EntryFilter(bookId: _bookId),
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
      },
      failure: (f) {
        state = state.copyWith(isLoading: false, errorMessage: f.code);
      },
    );
  }

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore || _cursor == null) return;
    state = state.copyWith(isLoading: true);

    final result = await _repository.listPage(
      filter: EntryFilter(bookId: _bookId),
      cursor: _cursor,
      limit: 50,
    );

    result.when(
      success: (page) {
        _cursor = page.nextCursor;
        final allEntries = [
          for (final g in state.groups) ...g.entries,
          ...page.items,
        ];
        state = state.copyWith(
          groups: _groupByDay(allEntries),
          isLoading: false,
          hasMore: page.hasMore,
        );
      },
      failure: (f) {
        state = state.copyWith(isLoading: false, errorMessage: f.code);
      },
    );
  }

  Future<void> refresh() => loadInitial();

  /// Soft-deleted entry stash for undo (PRD STORY-1.2 AC3).
  LedgerEntry? _lastDeleted;

  Future<bool> deleteEntry(String id) async {
    // Stash for undo before deleting
    final entryResult = await _repository.getById(id);
    _lastDeleted = entryResult.successOrNull;

    final result = await _repository.softDelete(id);
    if (result.isSuccess) {
      ref.invalidateData.bumpEntryMutated();
      return true;
    }
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
