/// Recently used category ids (per kind) for the entry grid.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const int kRecentCategoryLimit = 7;

String _key(String kind) => 'pref.cat.recent.$kind';

/// Most-recent-first list of category ids for [kind] ('expense' | 'income').
class RecentCategoriesNotifier extends Notifier<Map<String, List<String>>> {
  @override
  Map<String, List<String>> build() {
    Future.microtask(_load);
    return const {};
  }

  Future<void> _load() async {
    try {
      final sp = await SharedPreferences.getInstance();
      state = {
        'expense': sp.getStringList(_key('expense')) ?? const [],
        'income': sp.getStringList(_key('income')) ?? const [],
      };
    } catch (_) {}
  }

  List<String> idsFor(String kind) => state[kind] ?? const [];

  Future<void> use(String kind, String categoryId) async {
    if (categoryId.isEmpty) return;
    final current = List<String>.from(state[kind] ?? const []);
    current.remove(categoryId);
    current.insert(0, categoryId);
    final trimmed = current.take(kRecentCategoryLimit).toList();
    state = {...state, kind: trimmed};
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setStringList(_key(kind), trimmed);
    } catch (_) {}
  }
}

final recentCategoriesProvider =
    NotifierProvider<RecentCategoriesNotifier, Map<String, List<String>>>(
        RecentCategoriesNotifier.new);
