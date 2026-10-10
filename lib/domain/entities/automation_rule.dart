/// 自动化规则实体（STORY-6.1 规则引擎）。
library;

/// 条件字段。
enum RuleField {
  amount('amount'),
  note('note'),
  merchant('merchant'),
  accountId('account_id'),
  categoryId('category_id'),
  source('source'),
  type('type'),
  unknown('unknown');

  const RuleField(this.wire);
  final String wire;
  static RuleField fromWire(String? v) {
    for (final e in values) {
      if (e.wire == v) return e;
    }
    return RuleField.unknown;
  }
}

enum RuleOp {
  eq('eq'),
  contains('contains'),
  gt('gt'),
  lt('lt'),
  between('between'),
  regex('regex'),
  unknown('unknown');

  const RuleOp(this.wire);
  final String wire;
  static RuleOp fromWire(String? v) {
    for (final e in values) {
      if (e.wire == v) return e;
    }
    return RuleOp.unknown;
  }
}

enum RuleLogic {
  and('and'),
  or('or');

  const RuleLogic(this.wire);
  final String wire;
  static RuleLogic fromWire(String? v) => v == 'or' ? RuleLogic.or : RuleLogic.and;
}

enum RuleStage {
  pre('pre'),
  post('post');

  const RuleStage(this.wire);
  final String wire;
  static RuleStage fromWire(String? v) => v == 'pre' ? RuleStage.pre : RuleStage.post;
}

enum RuleScope {
  manual('manual'),
  recurring('recurring'),
  import('import'),
  split('split'),
  all('all');

  const RuleScope(this.wire);
  final String wire;
  static RuleScope fromWire(String? v) {
    for (final e in values) {
      if (e.wire == v) return e;
    }
    return RuleScope.manual;
  }
}

enum RuleActionType {
  setCategory('set_category'),
  setAccount('set_account'),
  setNotePrefix('set_note_prefix'),
  setNotInOutflow('set_not_in_outflow'),
  setReimbursable('set_reimbursable'),
  unknown('unknown');

  const RuleActionType(this.wire);
  final String wire;
  static RuleActionType fromWire(String? v) {
    for (final e in values) {
      if (e.wire == v) return e;
    }
    return RuleActionType.unknown;
  }
}

class RuleCondition {
  const RuleCondition({
    required this.field,
    required this.op,
    required this.value,
    this.value2,
    this.logic = RuleLogic.and,
  });

  final RuleField field;
  final RuleOp op;

  /// 主值：金额为分（int 的字符串形式），其余为文本。
  final String value;
  final String? value2;
  final RuleLogic logic;

  Map<String, Object?> toJson() => {
        'field': field.wire,
        'op': op.wire,
        'value': value,
        if (value2 != null) 'value2': value2,
        'logic': logic.wire,
      };

  static RuleCondition fromJson(Map<String, Object?> j) => RuleCondition(
        field: RuleField.fromWire(j['field'] as String?),
        op: RuleOp.fromWire(j['op'] as String?),
        value: (j['value'] ?? '') as String,
        value2: j['value2'] as String?,
        logic: RuleLogic.fromWire(j['logic'] as String?),
      );
}

class RuleAction {
  const RuleAction({
    required this.type,
    this.value,
  });

  final RuleActionType type;

  /// set_category → categoryId；set_account → accountId；
  /// set_note_prefix → 前缀文本；布尔类忽略。
  final String? value;

  Map<String, Object?> toJson() => {
        'type': type.wire,
        if (value != null) 'value': value,
      };

  static RuleAction fromJson(Map<String, Object?> j) => RuleAction(
        type: RuleActionType.fromWire(j['type'] as String?),
        value: j['value'] as String?,
      );
}

class AutomationRule {
  const AutomationRule({
    required this.id,
    required this.bookId,
    this.name,
    required this.stage,
    required this.priority,
    required this.scope,
    required this.conditions,
    required this.actions,
    this.isEnabled = true,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.revision = 1,
    required this.deviceId,
    this.baseRevision = 0,
  });

  final String id;
  final String bookId;
  final String? name;
  final RuleStage stage;
  final int priority;
  final RuleScope scope;
  final List<RuleCondition> conditions;
  final List<RuleAction> actions;
  final bool isEnabled;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int revision;
  final String deviceId;
  final int baseRevision;

  bool get isDeleted => deletedAt != null;

  AutomationRule copyWith({
    String? name,
    RuleStage? stage,
    int? priority,
    RuleScope? scope,
    List<RuleCondition>? conditions,
    List<RuleAction>? actions,
    bool? isEnabled,
    DateTime? updatedAt,
    DateTime? deletedAt,
    int? revision,
    int? baseRevision,
  }) {
    return AutomationRule(
      id: id,
      bookId: bookId,
      name: name ?? this.name,
      stage: stage ?? this.stage,
      priority: priority ?? this.priority,
      scope: scope ?? this.scope,
      conditions: conditions ?? this.conditions,
      actions: actions ?? this.actions,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      revision: revision ?? this.revision,
      deviceId: deviceId,
      baseRevision: baseRevision ?? this.baseRevision,
    );
  }
}
