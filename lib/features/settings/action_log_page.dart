/// 操作日志 — recent local mutations (from change_log).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plain/app/bootstrap.dart';
import 'package:plain/app/theme/app_colors.dart';
import 'package:plain/app/theme/design_tokens.dart';
import 'package:plain/core/refresh/data_invalidation.dart';
import 'package:plain/core/time/date_format.dart';
import 'package:plain/data/repositories/change_log_repository.dart';
import 'package:plain/design_system/app_empty_state.dart';

final _actionLogProvider = FutureProvider<List<ChangeLogItem>>((ref) async {
  ref.watch(ledgerVersionProvider);
  final deps = ref.watch(appDependenciesProvider);
  final res = await deps.changeLogRepository.listRecent(limit: 200);
  return res.successOrNull ?? const [];
});

class ActionLogPage extends ConsumerWidget {
  const ActionLogPage({super.key});

  String _entityLabel(String type) => switch (type) {
        'transaction' => '账单',
        'category' => '分类',
        'account' => '账户',
        'budget' => '预算',
        'recurring_rule' => '周期记账',
        _ => type,
      };

  String _opLabel(String op) => switch (op) {
        'insert' => '新增',
        'update' => '修改',
        'delete' => '删除',
        _ => op,
      };

  Color _opColor(BuildContext context, String op) => switch (op) {
        'insert' => context.colors.income,
        'delete' => context.colors.expense,
        _ => context.colors.inkSecondary,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_actionLogProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('操作日志')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
        data: (items) {
          if (items.isEmpty) {
            return const AppEmptyState(
              icon: Icons.history,
              title: '暂无操作记录',
              subtitle: '记账、改分类等操作会记录在这里',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(Spacing.lg),
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final item = items[i];
              return ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
                leading: Icon(
                  switch (item.op) {
                    'insert' => Icons.add_circle_outline,
                    'delete' => Icons.remove_circle_outline,
                    _ => Icons.edit_outlined,
                  },
                  size: 20,
                  color: _opColor(context, item.op),
                ),
                title: Text(
                  '${_opLabel(item.op)}${_entityLabel(item.entityType)}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  formatDateTime(item.changedAt),
                  style: TextStyle(fontSize: 12, color: context.colors.inkTertiary),
                ),
                trailing: Text(
                  '#${item.localRevision}',
                  style: TextStyle(fontSize: 11, color: context.colors.inkTertiary),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
