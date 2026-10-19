/// Recently used category ids (per kind) for the entry grid.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const int kRecentCategoryLimit = 11;

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

  /// 记一次「用过」。
  ///
  /// [alreadyVisible]：该分类是否**已经在宫格当前展示的那 11 格里**（由宫格
  /// 判定后传进来）。在的话**不动顺序** —— 用户口径（2026-10-16）：点一个已经
  /// 看得见的分类，不该把它挪到第一格，否则每点一次整版布局就重排一次，刚点的
  /// 那格反而找不到了。只有「从『更多』里选了个当前没显示的」才顶到第一格，
  /// 因为不顶上去它根本不在宫格里。
  Future<void> use(
    String kind,
    String categoryId, {
    bool alreadyVisible = false,
  }) async {
    if (categoryId.isEmpty) return;
    if (alreadyVisible) return;
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
