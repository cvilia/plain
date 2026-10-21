/// 操作日志 — recent local mutations (from change_log).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plain/app/bootstrap.dart';
import 'package:plain/app/l10n/app_strings.dart';
import 'package:plain/app/l10n/strings_domain.dart';
import 'package:plain/app/l10n/strings_settings_a.dart';
import 'package:plain/app/theme/app_colors.dart';
import 'package:plain/app/theme/design_tokens.dart';
import 'package:plain/core/refresh/data_invalidation.dart';
import 'package:plain/core/time/date_format.dart';
import 'package:plain/design_system/plain_icons_v3.dart';
import 'package:plain/design_system/plain_ui.dart';
import 'package:plain/data/repositories/change_log_repository.dart';
import 'package:plain/design_system/app_empty_state.dart';
import 'package:plain/design_system/app_error_state.dart';

final _actionLogProvider = FutureProvider<List<ChangeLogItem>>((ref) async {
  ref.watch(ledgerVersionProvider);
  final deps = ref.watch(appDependenciesProvider);
  final res = await deps.changeLogRepository.listRecent(limit: 200);
  return res.successOrNull ?? const [];
});

class ActionLogPage extends ConsumerWidget {
  const ActionLogPage({super.key});

  String _entityLabel(AppStrings s, String type) => switch (type) {
        'transaction' => s.entityTransaction,
        'category' => s.category,
        'account' => s.account,
        'budget' => s.entityBudget,
        'recurring_rule' => s.actionLogEntityRecurring,
        'currency_rate' => s.entityCurrencyRate,
        'merchant_rule' => s.entityMerchantRule,
        'rule' => s.entityAutomationRule,
        'savings_goal' => s.entitySavingsGoal,
        'holding' => s.entityHolding,
        'saved_report' => s.entitySavedReport,
        'tax_filing' => s.entityTaxFiling,
        'member' => s.entityMember,
        'entry_participant' => s.entityEntryParticipant,
        'setting' => s.entitySetting,
        _ => type,
      };

  String _opLabel(AppStrings s, String op) => switch (op) {
        'insert' => s.actionLogOpInsert,
        'update' => s.actionLogOpUpdate,
        'delete' => s.delete,
        _ => op,
      };

  Color _opColor(BuildContext context, String op) => switch (op) {
        'insert' => context.colors.income,
        'delete' => context.colors.expense,
        _ => context.colors.inkSecondary,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final async = ref.watch(_actionLogProvider);
    return Scaffold(
      appBar: PlainTopBar(title: s.actionLogTitle, showBack: true),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AppErrorState.of(context, e, onRetry: () => ref.invalidateData.bumpEverything()),
        data: (items) {
          if (items.isEmpty) {
            return AppEmptyState(
              icon: PlainIconData.history,
              title: s.actionLogEmptyTitle,
              subtitle: s.actionLogEmptySubtitle,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(Spacing.lg),
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final item = items[i];
              return PlainRow(
                leading: PlainIcon(
                  switch (item.op) {
                    'insert' => PlainIconData.circlePlus,
                    'delete' => PlainIconData.circleMinus,
                    _ => PlainIconData.edit,
                  },
                  size: 20,
                  color: _opColor(context, item.op),
                ),
                title: '${_opLabel(s, item.op)}${_entityLabel(s, item.entityType)}',
                subtitle: formatDateTime(item.changedAt),
                trailing: Text(
                  '#${item.localRevision}',
                  style: TextStyle(fontSize: 12, color: context.colors.inkTertiary),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
