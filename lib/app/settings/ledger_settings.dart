/// Ledger settings that affect data interpretation (not theme/appearance).
/// 月起始日与预算方法论属「可同步设置」，落 `app_meta`
/// （主题与外观不入同步，见 INV-3）。See PRD STORY-5.1 / G-1 / STORY-11.1, 06-C1.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plain/core/refresh/data_invalidation.dart';
import 'package:plain/domain/entities/enums.dart';

const String kMetaMonthStartDay = 'pref.month_start_day';
const String kMetaBudgetMethodology = 'pref.budget_methodology';

class LedgerSettings {
  const LedgerSettings({
    this.monthStartDay = 1,
    this.budgetMethodology = BudgetMethodology.custom,
  });
  final int monthStartDay;

  /// STORY-11.1：当前预算方法论（只改呈现与校验，不改历史数据）。
  final BudgetMethodology budgetMethodology;

  LedgerSettings copyWith({
    int? monthStartDay,
    BudgetMethodology? budgetMethodology,
  }) =>
      LedgerSettings(
        monthStartDay: monthStartDay ?? this.monthStartDay,
        budgetMethodology: budgetMethodology ?? this.budgetMethodology,
      );
}

int _preloadedMonthStartDay = 1;
BudgetMethodology _preloadedMethodology = BudgetMethodology.custom;

/// Called from bootstrap after `app_meta` is readable.
void preloadLedgerSettings(
  int monthStartDay, {
  BudgetMethodology methodology = BudgetMethodology.custom,
}) {
  _preloadedMonthStartDay = monthStartDay.clamp(1, 28);
  _preloadedMethodology = methodology;
}

typedef MetaWriter = void Function(String key, String value);
MetaWriter? _metaWriter;

/// Registered from bootstrap so the notifier can persist to `app_meta`.
void registerMetaWriter(MetaWriter writer) => _metaWriter = writer;

class LedgerSettingsNotifier extends Notifier<LedgerSettings> {
  @override
  LedgerSettings build() => LedgerSettings(
        monthStartDay: _preloadedMonthStartDay,
        budgetMethodology: _preloadedMethodology,
      );

  /// G-1：月起始日变更只重切查询期，统计数据一行不改写。
  /// bump ledger/budget 让报表与预算条按新边界重取。
  void setMonthStartDay(int day) {
    final d = day.clamp(1, 28);
    if (d == state.monthStartDay) return;
    state = state.copyWith(monthStartDay: d);
    ref.invalidateData.bumpAll(const {
      DataScope.ledger,
      DataScope.budget,
    });
    _metaWriter?.call(kMetaMonthStartDay, '$d');
  }

  /// STORY-11.1 AC5：切换方法论**只改呈现与校验**，不碰任何账单/报表数据，
  /// 因此这里只 bump budget（让预算页重取视图），不动 ledger。
  void setBudgetMethodology(BudgetMethodology m) {
    if (m == state.budgetMethodology) return;
    state = state.copyWith(budgetMethodology: m);
    ref.invalidateData.bumpBudgetMutated();
    _metaWriter?.call(kMetaBudgetMethodology, m.wire);
  }
}

final ledgerSettingsProvider =
    NotifierProvider<LedgerSettingsNotifier, LedgerSettings>(LedgerSettingsNotifier.new);

/// Derived: current 记账月起始日 (1–28).
final monthStartDayProvider = Provider<int>(
  (ref) => ref.watch(ledgerSettingsProvider).monthStartDay,
);
