/// Ledger data freshness version.
///
/// Bumped after any entry mutation so cached FutureProviders
/// (reports, budget strip, …) can refetch via `ref.watch`.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

class DataFreshness extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state = state + 1;
}

final dataFreshnessProvider = NotifierProvider<DataFreshness, int>(DataFreshness.new);
