/// 规则匹配与施用引擎（STORY-6.1）。
library;

import 'dart:convert';

import 'package:plain/app/l10n/app_strings.dart';
import 'package:plain/domain/entities/automation_rule.dart';
import 'package:plain/domain/entities/ledger_entry.dart';
import 'package:plain/app/l10n/strings_domain.dart';

/// 命中结果：记录命中的规则与动作摘要（供试运行 / 预览）。
class RuleHit {
  const RuleHit({required this.rule, required this.actionSummaries});
  final AutomationRule rule;
  final List<String> actionSummaries;
}

class RuleEngine {
  const RuleEngine();

  /// [entry] 是否匹配 [rule]（不修改数据）。
  bool matches(LedgerEntry entry, AutomationRule rule) {
    if (!rule.isEnabled || rule.isDeleted) return false;
    if (rule.conditions.isEmpty) return true;
    var andOk = true;
    var orOk = false;
    var hasOr = false;
    for (final c in rule.conditions) {
      final hit = _matchCondition(entry, c);
      if (c.logic == RuleLogic.or) {
        hasOr = true;
        if (hit) orOk = true;
      } else {
        if (!hit) andOk = false;
      }
    }
    if (hasOr) return andOk && orOk;
    return andOk;
  }

  bool _matchCondition(LedgerEntry e, RuleCondition c) {
    final field = c.field;
    if (field == RuleField.amount) {
      final v = int.tryParse(c.value) ?? 0;
      final amt = e.amount.cents;
      switch (c.op) {
        case RuleOp.eq:
          return amt == v;
        case RuleOp.gt:
          return amt > v;
        case RuleOp.lt:
          return amt < v;
        case RuleOp.between:
          final v2 = int.tryParse(c.value2 ?? '') ?? v;
          final lo = v < v2 ? v : v2;
          final hi = v < v2 ? v2 : v;
          return amt >= lo && amt <= hi;
        default:
          return false;
      }
    }

    final text = switch (field) {
      RuleField.note => e.note ?? '',
      RuleField.merchant => e.note ?? '', // 商户暂用备注（学习表 V2 后续）
      RuleField.accountId => e.accountId ?? '',
      RuleField.categoryId => e.categoryId ?? '',
      RuleField.source => e.source.wire,
      RuleField.type => e.type.wire,
      _ => '',
    };

    switch (c.op) {
      case RuleOp.eq:
        return text == c.value;
      case RuleOp.contains:
        return text.contains(c.value);
      case RuleOp.regex:
        try {
          return RegExp(c.value).hasMatch(text);
        } on FormatException {
          return false;
        }
      default:
        return false;
    }
  }

  /// 按优先级施用规则，返回变换后的 entry 与命中列表。
  /// 后面的规则可覆盖前面的同类动作（AC4：priority 数值大者后执行并覆盖）。
  (LedgerEntry, List<RuleHit>) applyAll(
    LedgerEntry entry,
    List<AutomationRule> rules, {
    required AppStrings s,
    RuleScope scope = RuleScope.manual,
  }) {
    final sorted = [...rules]
      ..sort((a, b) {
        final byPri = a.priority.compareTo(b.priority);
        if (byPri != 0) return byPri;
        return a.createdAt.compareTo(b.createdAt);
      });

    var current = entry;
    final hits = <RuleHit>[];
    for (final r in sorted) {
      if (!_scopeOk(r, scope)) continue;
      if (!matches(current, r)) continue;
      final summaries = <String>[];
      current = _applyActions(current, r, summaries, s);
      hits.add(RuleHit(rule: r, actionSummaries: summaries));
    }
    return (current, hits);
  }

  bool _scopeOk(AutomationRule r, RuleScope scope) {
    if (r.scope == RuleScope.all) return true;
    return r.scope == scope;
  }

  LedgerEntry _applyActions(
    LedgerEntry e,
    AutomationRule rule,
    List<String> summaries,
    AppStrings s,
  ) {
    var out = e;
    for (final a in rule.actions) {
      switch (a.type) {
        case RuleActionType.setCategory:
          if (a.value != null && a.value!.isNotEmpty) {
            out = out.copyWith(categoryId: a.value);
            summaries.add(s.ruleSetCategory(a.value!));
          }
        case RuleActionType.setAccount:
          if (a.value != null && a.value!.isNotEmpty) {
            out = out.copyWith(accountId: a.value);
            summaries.add(s.ruleSetAccount(a.value!));
          }
        case RuleActionType.setNotePrefix:
          final prefix = a.value ?? '';
          if (prefix.isEmpty) break;
          final note = out.note == null || out.note!.isEmpty
              ? prefix
              : (out.note!.startsWith(prefix) ? out.note! : '$prefix${out.note}');
          out = out.copyWith(note: note);
          summaries.add(s.ruleSetNotePrefix(prefix));
        case RuleActionType.setNotInOutflow:
          // G-2：标记「不计入收支」。只改统计口径，不影响账户余额。
          if (out.canMarkExcluded && !out.excludeFromStats) {
            out = out.copyWith(excludeFromStats: true);
            summaries.add(s.ruleMarkExcluded);
          }
        case RuleActionType.setReimbursable:
          summaries.add(s.ruleMarkReimbursable);
        case RuleActionType.unknown:
          break;
      }
    }
    return out;
  }

  /// 试运行：对 [entries] 只算不改。
  List<({LedgerEntry entry, List<String> summaries})> dryRun(
    List<LedgerEntry> entries,
    AutomationRule rule, {
    required AppStrings s,
  }) {
    final out = <({LedgerEntry entry, List<String> summaries})>[];
    for (final e in entries) {
      if (!matches(e, rule)) continue;
      final summaries = <String>[];
      _applyActions(e, rule, summaries, s);
      out.add((entry: e, summaries: summaries));
    }
    return out;
  }

  /// AC5：校验正则条件，返回错误位置（无效则非 null）。
  static String? validateConditions(
    List<RuleCondition> conditions, {
    required AppStrings s,
  }) {
    for (var i = 0; i < conditions.length; i++) {
      final c = conditions[i];
      if (c.op != RuleOp.regex) continue;
      try {
        RegExp(c.value);
      } on FormatException catch (e) {
        return s.ruleRegexInvalid(i + 1, e.message);
      }
    }
    return null;
  }

  /// 解析 JSON 条件列表。
  static List<RuleCondition> parseConditions(String raw) {
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return [
        for (final j in list)
          RuleCondition.fromJson((j as Map).cast<String, Object?>()),
      ];
    } catch (_) {
      return const [];
    }
  }

  static List<RuleAction> parseActions(String raw) {
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return [
        for (final j in list)
          RuleAction.fromJson((j as Map).cast<String, Object?>()),
      ];
    } catch (_) {
      return const [];
    }
  }

  static String encodeConditions(List<RuleCondition> cs) =>
      jsonEncode([for (final c in cs) c.toJson()]);

  static String encodeActions(List<RuleAction> as) =>
      jsonEncode([for (final a in as) a.toJson()]);
}
