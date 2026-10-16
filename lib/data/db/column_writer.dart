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

  static void clearCache() => _cache.clear();

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

  /// 用 [values] 里**表里真实存在**的列，插入或更新 id 对应的行。
  ///
  /// 不返回结果——异常交给调用方（仓储）包成 Failure。
  static void upsert(
    AppDatabase db,
    String table,
    Map<String, Object?> values,
  ) {
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
      final marks = List.filled(cols.length, '?').join(',');
      db.raw.execute(
        'INSERT INTO $table (${cols.join(',')}) VALUES ($marks)',
        [id, for (final p in pairs) p.value],
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
