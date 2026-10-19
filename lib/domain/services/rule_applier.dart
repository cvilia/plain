/// 在写入账单前套用自动化规则（STORY-6.1）。
library;

import 'package:plain/app/l10n/app_strings.dart';
import 'package:plain/core/result/result.dart';
import 'package:plain/domain/entities/automation_rule.dart';
import 'package:plain/domain/entities/ledger_entry.dart';
import 'package:plain/domain/repositories/repositories.dart';
import 'package:plain/domain/services/rule_engine.dart';

/// 从仓储加载 post 阶段规则并套用到 [entry]。
/// [scope] 对应规则的适用范围（manual / recurring / import / split）。
Future<LedgerEntry> applyAutomationRules({
  required AppStrings s,
  required AutomationRuleRepository ruleRepository,
  required LedgerEntry entry,
  required RuleScope scope,
}) async {
  final res = await ruleRepository.listEnabled(
    bookId: entry.bookId,
    stage: RuleStage.post,
  );
  final rules = res.successOrNull ?? const <AutomationRule>[];
  if (rules.isEmpty) return entry;
  const engine = RuleEngine();
  return engine.applyAll(entry, rules, scope: scope, s: s).$1;
}

/// STORY-6.1 AC3：回溯历史账单（用户显式选择后执行）。
class ApplyRuleRetroactively {
  ApplyRuleRetroactively({
    required LedgerRepository repository,
  }) : _repository = repository;

  final LedgerRepository _repository;

  /// 对 [bookId] 最近 [limit] 笔账单套用 [rule]，返回实际更新条数。
  /// 只更新命中且有动作变化的账单。
  Future<Result<int>> call({
    required AppStrings s,
    required String bookId,
    required AutomationRule rule,
    int limit = 500,
  }) async {
    const engine = RuleEngine();
    final page = await _repository.listPage(
      filter: EntryFilter(bookId: bookId),
      limit: limit,
    );
    final items = page.successOrNull?.items ?? const <LedgerEntry>[];
    var updated = 0;
    for (final e in items) {
      if (!engine.matches(e, rule)) continue;
      final (next, _) = engine.applyAll(e, [rule], scope: RuleScope.all, s: s);
      if (next.categoryId == e.categoryId &&
          next.accountId == e.accountId &&
          next.note == e.note &&
          next.excludeFromStats == e.excludeFromStats) {
        continue;
      }
      final r = await _repository.update(next);
      if (r.isSuccess) updated++;
    }
    return ok(updated);
  }
}
