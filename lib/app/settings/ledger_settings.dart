/// Ledger settings that affect data interpretation (not theme/appearance).
/// 月起始日属「可同步设置」，落 `app_meta`（主题与外观不入同步，见 INV-3）。
/// See PRD STORY-5.1 / G-1, 06-C1.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plain/core/refresh/data_invalidation.dart';

const String kMetaMonthStartDay = 'pref.month_start_day';

class LedgerSettings {
  const LedgerSettings({this.monthStartDay = 1});
  final int monthStartDay;
}

int _preloadedMonthStartDay = 1;

/// Called from bootstrap after `app_meta` is readable.
void preloadLedgerSettings(int monthStartDay) {
  _preloadedMonthStartDay = monthStartDay.clamp(1, 28);
}

typedef MetaWriter = void Function(String key, String value);
MetaWriter? _metaWriter;

/// Registered from bootstrap so the notifier can persist to `app_meta`.
void registerMetaWriter(MetaWriter writer) => _metaWriter = writer;

class LedgerSettingsNotifier extends Notifier<LedgerSettings> {
  @override
  LedgerSettings build() => LedgerSettings(monthStartDay: _preloadedMonthStartDay);

  /// G-1：月起始日变更只重切查询期，统计数据一行不改写。
  /// bump ledger/budget 让报表与预算条按新边界重取。
  void setMonthStartDay(int day) {
    final d = day.clamp(1, 28);
    if (d == state.monthStartDay) return;
    state = LedgerSettings(monthStartDay: d);
    ref.invalidateData.bumpAll(const {
      DataScope.ledger,
      DataScope.budget,
    });
    _metaWriter?.call(kMetaMonthStartDay, '$d');
  }
}

final ledgerSettingsProvider =
    NotifierProvider<LedgerSettingsNotifier, LedgerSettings>(LedgerSettingsNotifier.new);

/// Derived: current 记账月起始日 (1–28).
final monthStartDayProvider = Provider<int>(
  (ref) => ref.watch(ledgerSettingsProvider).monthStartDay,
);
