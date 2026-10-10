/// STORY-6.1 规则引擎单测。
library;
import 'package:flutter_test/flutter_test.dart';
import 'package:plain/core/money/money.dart';
import 'package:plain/domain/entities/automation_rule.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/entities/ledger_entry.dart';
import 'package:plain/domain/services/rule_engine.dart';

void main() {
  const engine = RuleEngine();
  final now = DateTime.utc(2026, 9, 29);

  LedgerEntry entry({String? note, int cents = 2500, String? categoryId}) {
    return LedgerEntry(
      id: 'e1', bookId: 'b1', type: EntryType.expense,
      amount: Money(cents), currency: 'CNY',
      categoryId: categoryId, accountId: 'a1',
      occurredAt: now, note: note, source: EntrySource.manual,
      createdAt: now, updatedAt: now, deviceId: 'd1',
    );
  }

  AutomationRule rule({
    required String id,
    int priority = 0,
    RuleScope scope = RuleScope.manual,
    List<RuleCondition>? conditions,
    List<RuleAction>? actions,
  }) {
    return AutomationRule(
      id: id, bookId: 'b1', stage: RuleStage.post, priority: priority,
      scope: scope,
      conditions: conditions ?? const [],
      actions: actions ?? const [],
      createdAt: now, updatedAt: now, deviceId: 'd1',
    );
  }

  test('note contains matches', () {
    final r = rule(
      id: 'r1',
      conditions: const [
        RuleCondition(field: RuleField.note, op: RuleOp.contains, value: '星巴克'),
      ],
    );
    expect(engine.matches(entry(note: '星巴克拿铁'), r), true);
    expect(engine.matches(entry(note: '瑞幸'), r), false);
  });

  test('amount gt and between', () {
    final gt = rule(
      id: 'r2',
      conditions: const [
        RuleCondition(field: RuleField.amount, op: RuleOp.gt, value: '10000'),
      ],
    );
    expect(engine.matches(entry(cents: 20000), gt), true);
    expect(engine.matches(entry(cents: 500), gt), false);

    final bt = rule(
      id: 'r3',
      conditions: const [
        RuleCondition(field: RuleField.amount, op: RuleOp.between, value: '1000', value2: '5000'),
      ],
    );
    expect(engine.matches(entry(cents: 2500), bt), true);
    expect(engine.matches(entry(cents: 999), bt), false);
  });

  test('invalid regex does not throw and does not match', () {
    final r = rule(
      id: 'r4',
      conditions: const [
        RuleCondition(field: RuleField.note, op: RuleOp.regex, value: '('),
      ],
    );
    expect(engine.matches(entry(note: 'x'), r), false);
  });

  test('priority later rule overwrites same action (AC4)', () {
    final a = rule(
      id: 'a', priority: 1,
      conditions: const [],
      actions: const [RuleAction(type: RuleActionType.setCategory, value: 'cat-food')],
    );
    final b = rule(
      id: 'b', priority: 2,
      conditions: const [],
      actions: const [RuleAction(type: RuleActionType.setCategory, value: 'cat-drink')],
    );
    final (out, hits) = engine.applyAll(entry(), [a, b]);
    expect(out.categoryId, 'cat-drink');
    expect(hits.length, 2);
  });

  test('dryRun does not modify entry', () {
    final e = entry(note: '星巴克');
    final r = rule(
      id: 'r',
      conditions: const [
        RuleCondition(field: RuleField.note, op: RuleOp.contains, value: '星巴克'),
      ],
      actions: const [RuleAction(type: RuleActionType.setCategory, value: 'c1')],
    );
    final results = engine.dryRun([e], r);
    expect(results.length, 1);
    expect(results.first.entry.categoryId, isNull);
    expect(results.first.summaries, isNotEmpty);
  });

  test('scope filter', () {
    final r = rule(
      id: 'r',
      scope: RuleScope.import,
      conditions: const [],
      actions: const [RuleAction(type: RuleActionType.setCategory, value: 'c1')],
    );
    final (out, hits) = engine.applyAll(entry(), [r], scope: RuleScope.manual);
    expect(hits, isEmpty);
    expect(out.categoryId, isNull);
  });

  test('AC5 invalid regex rejected with message', () {
    final err = RuleEngine.validateConditions(const [
      RuleCondition(field: RuleField.note, op: RuleOp.regex, value: '('),
    ]);
    expect(err, isNotNull);
    expect(err, contains('条件 1'));
    expect(
      RuleEngine.validateConditions(const [
        RuleCondition(field: RuleField.note, op: RuleOp.regex, value: r'星.*克'),
      ]),
      isNull,
    );
  });
}
