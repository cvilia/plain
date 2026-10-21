/// 通用的「按列 upsert」写库助手（同步落库用）。
///
/// 同步拿到的是**列形态**的 payload，且可能来自更早的 schema（少列或多列），
/// 因此必须按两边列交集写，与 `AppDatabase.restoreFrom` 同一套规矩。
library;

import 'package:plain/data/db/database.dart';

class ColumnWriter {
  static final Map<String, Set<String>> _cache = {};

  /// 表的列名集合（带缓存）。
  static Set<String> columnsOf(AppDatabase db, String table) {
    final cached = _cache[table];
    if (cached != null) return cached;
    final cols = db.raw
        .select('SELECT name FROM pragma_table_info(?)', [table])
        .map((r) => r['name']! as String)
        .toSet();
    _cache[table] = cols;
    return cols;
  }

  static void clearCache() {
    _cache.clear();
    _notNullCache.clear();
    _requiredCache.clear();
  }

  static final Map<String, Set<String>> _notNullCache = {};

  /// 表里 `NOT NULL` 的列（不含主键）。
  ///
  /// 同步合并时用来决定「远端把这一列置 null」要不要照写：可空列必须写 NULL
  /// （否则「清空备注」「解绑账户」这类**置空**改动永远传不到对端），
  /// 非空列则跳过（写了会整条失败）。
  static Set<String> notNullColumnsOf(AppDatabase db, String table) {
    final cached = _notNullCache[table];
    if (cached != null) return cached;
    final cols = db.raw
        .select('SELECT name, "notnull" AS nn FROM pragma_table_info(?)', [table])
        .where((r) => ((r['nn'] as int?) ?? 0) == 1)
        .map((r) => r['name']! as String)
        .toSet();
    _notNullCache[table] = cols;
    return cols;
  }

  static final Map<String, Map<String, String>> _requiredCache = {};

  /// 表里「`NOT NULL` 且没有默认值」的列 → 列类型（不含主键）。
  ///
  /// 同步 payload 可能来自更早的版本、也可能被某条旁路写成「部分列」形态。
  /// 插入时缺这些列，SQLite 会直接拒绝整条 `INSERT` —— 后果不是「少一列」，
  /// 而是这条变更永远应用不上、`applyAll` 整批失败、同步位点停在原地。
  static Map<String, String> requiredColumnsOf(AppDatabase db, String table) {
    final cached = _requiredCache[table];
    if (cached != null) return cached;
    final rows = db.raw.select(
      'SELECT name, type, "notnull" AS nn, dflt_value AS dv FROM pragma_table_info(?)',
      [table],
    );
    final map = <String, String>{};
    for (final r in rows) {
      final name = r['name']! as String;
      final notNull = ((r['nn'] as int?) ?? 0) == 1;
      final hasDefault = r['dv'] != null;
      if (name != 'id' && notNull && !hasDefault) {
        map[name] = (r['type'] as String?) ?? 'TEXT';
      }
    }
    _requiredCache[table] = map;
    return map;
  }

  /// 缺列时的兜底值。只用来「让这条变更能落库」，正常 payload 不该走到这里。
  static Object? _defaultFor(String column, String type, int nowMs) {
    switch (column) {
      case 'created_at':
      case 'updated_at':
        return nowMs;
      case 'revision':
        return 1;
      case 'base_revision':
        return 0;
      case 'device_id':
        return '';
    }
    final t = type.toUpperCase();
    if (t.contains('INT') ||
        t.contains('REAL') ||
        t.contains('FLOA') ||
        t.contains('DOUB') ||
        t.contains('NUM') ||
        t.contains('DEC')) {
      return 0;
    }
    return '';
  }

  /// 用 [values] 里**表里真实存在**的列，插入或更新 id 对应的行。
  ///
  /// 不返回结果——异常交给调用方（仓储）包成 Failure。
  ///
  /// [nowMs] 仅供测试注入「现在」；省略时取系统时间。
  static void upsert(
    AppDatabase db,
    String table,
    Map<String, Object?> values, {
    int? nowMs,
  }) {
    final allowed = columnsOf(db, table);
    final pairs = <MapEntry<String, Object?>>[
      for (final e in values.entries)
        if (allowed.contains(e.key) && e.key != 'id') e,
    ];
    if (pairs.isEmpty) return;
    final id = values['id'];
    if (id == null) return;

    final exists = db.raw
        .select('SELECT 1 AS x FROM $table WHERE id = ?', [id])
        .isNotEmpty;
    if (!exists) {
      final cols = ['id', for (final p in pairs) p.key];
      final vals = <Object?>[id, for (final p in pairs) p.value];
      // 补齐「NOT NULL 且无默认值」的缺列：漏了它们不是少一列，而是整条插入失败，
      // 于是这条变更永远应用不上、同步位点不推进（见 [requiredColumnsOf]）。
      final at = nowMs ?? DateTime.now().millisecondsSinceEpoch;
      final present = {for (final p in pairs) p.key};
      requiredColumnsOf(db, table).forEach((name, type) {
        if (present.contains(name)) return;
        cols.add(name);
        vals.add(_defaultFor(name, type, at));
      });
      final marks = List.filled(cols.length, '?').join(',');
      db.raw.execute(
        'INSERT INTO $table (${cols.join(',')}) VALUES ($marks)',
        vals,
      );
    } else {
      final sets = [for (final p in pairs) '${p.key}=?'].join(',');
      db.raw.execute(
        'UPDATE $table SET $sets WHERE id = ?',
        [for (final p in pairs) p.value, id],
      );
    }
  }

  /// 软删除（同步来的删除）：置 `deleted_at`。
  static void softDeleteRow(
    AppDatabase db,
    String table,
    String id,
    DateTime at,
  ) {
    final allowed = columnsOf(db, table);
    if (!allowed.contains('deleted_at')) return;
    db.raw.execute(
      'UPDATE $table SET deleted_at = ? WHERE id = ?',
      [at.millisecondsSinceEpoch, id],
    );
  }

  /// 同步来的删除：有 `deleted_at` 就软删（保留行，回收站/审计口径一致），
  /// **没有该列的表**（`currency_rates`）只能物理删。
  ///
  /// 用 [softDeleteRow] 处理后者等于什么都没做（它会对缺列的表静默返回），
  /// 于是「解除汇率锁定」这类删除永远传不到对端——对端继续用旧汇率折算。
  static void deleteRow(
    AppDatabase db,
    String table,
    String id,
    DateTime at,
  ) {
    final allowed = columnsOf(db, table);
    if (!allowed.contains('deleted_at')) {
      db.raw.execute('DELETE FROM $table WHERE id = ?', [id]);
      return;
    }
    db.raw.execute(
      'UPDATE $table SET deleted_at = ? WHERE id = ?',
      [at.millisecondsSinceEpoch, id],
    );
  }
}
