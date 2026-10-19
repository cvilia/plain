/// 预置分类树的**产品口径**守卫（2026-10-19 爸爸拍板）。
///
/// 1. 支出一级恰好 30 个，一一对应 30 枚不同图标；
/// 2. 每一个一级下面都必须有二级（记账时只能选二级）；
/// 3. 收入每个一级也必须有二级；
/// 4. 二级不单独配图标（继承一级），否则「30 个支出图标」的口径会失效；
/// 5. **名字在整棵树里唯一** —— 一笔支出只能有一个最贴切的归属，
///    跨一级重名（「咖啡」既在餐饮又在饮品）就是边界失守；
/// 6. 一级名不能与任何二级名相同（避免「学习 › 学习」这种套娃）。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:plain/core/time/clock.dart';
import 'package:plain/data/db/database.dart';
import 'package:plain/data/seed/preset_categories.dart';
import 'package:plain/design_system/category_icon_v3.dart';

void main() {
  test('支出一级恰好 30 个，图标互不重复且都能解析', () {
    expect(presetExpenseCategories.length, 30);

    final icons = <String>{};
    for (final cat in presetExpenseCategories) {
      expect(cat.iconRef, isNotEmpty, reason: '${cat.name} 没有图标');
      expect(icons.add(cat.iconRef), isTrue,
          reason: '图标重复：${cat.name} 用了 ${cat.iconRef}');
      expect(plainIconForRef(cat.iconRef), isNotNull,
          reason: '${cat.name} 的图标 ${cat.iconRef} 在映射表里不存在');
    }
  });

  test('支出每个一级都有二级，二级不单独配图标', () {
    for (final cat in presetExpenseCategories) {
      expect(cat.children, isNotEmpty, reason: '${cat.name} 下面没有二级');
      for (final child in cat.children) {
        expect(child.iconRef, isEmpty,
            reason: '${cat.name} · ${child.name} 不该单独配图标（继承一级）');
      }
    }
  });

  test('收入每个一级都有二级', () {
    expect(presetIncomeCategories.length, greaterThanOrEqualTo(10));
    for (final cat in presetIncomeCategories) {
      expect(cat.children, isNotEmpty, reason: '${cat.name} 下面没有二级');
      for (final child in cat.children) {
        expect(child.iconRef, isEmpty);
      }
    }
  });

  test('二级名在同一侧整棵树里唯一，一级名不与二级重名', () {
    // 支出与收入各有独立的「其他 / 待归类」，选择器也从不混排 ——
    // 唯一性只在同一 kind 内要求。
    void check(List<PresetCategory> roots, String side) {
      final topNames = <String>[];
      final leafNames = <String>[];
      void walk(PresetCategory c, {required bool isTop}) {
        (isTop ? topNames : leafNames).add(c.name);
        for (final child in c.children) {
          walk(child, isTop: false);
        }
      }

      for (final c in roots) {
        walk(c, isTop: true);
      }

      expect(topNames.length, topNames.toSet().length,
          reason: '$side 一级重名：${_dups(topNames)}');
      // 二级跨一级也不能重名 —— 这是「边界清晰」的机械判据
      expect(leafNames.length, leafNames.toSet().length,
          reason: '$side 二级重名：${_dups(leafNames)}');
      // 一级名不能出现在二级里（「学习 › 学习」这种套娃）
      final overlap = leafNames.toSet().intersection(topNames.toSet());
      expect(overlap, isEmpty, reason: '$side 一级与二级同名：$overlap');
    }

    check(presetExpenseCategories, '支出');
    check(presetIncomeCategories, '收入');
  });

  test('二级名避开四字格（命名口径：书面术语，2/3/5 字）', () {
    for (final tree in [presetExpenseCategories, presetIncomeCategories]) {
      for (final top in tree) {
        for (final child in top.children) {
          expect(child.name.length, isNot(4),
              reason: '${top.name} · ${child.name} 是四字格，改成 2/3 字或 5 字以上');
        }
      }
    }
  });

  test('分类 key 全局唯一，且「其他」垫底', () {
    final keys = <String>[];
    void walk(PresetCategory c) {
      keys.add(c.key);
      c.children.forEach(walk);
    }

    presetExpenseCategories.forEach(walk);
    presetIncomeCategories.forEach(walk);
    expect(keys.length, keys.toSet().length, reason: 'key 有重复');
    expect(keys.where((k) => k == 'other' || k == 'income_other').length, 2);
    expect(presetExpenseCategories.last.key, 'other');
    expect(presetIncomeCategories.last.key, 'income_other');
  });

  test('落库后：支出 30 个一级顺序与预置一致，且每级都有二级', () async {
    final db = AppDatabase.inMemory();
    addTearDown(db.close);
    db.raw.execute("INSERT INTO app_meta (key,value,updated_at) VALUES ('device.id','dev',0)");
    await seedPresetCategories(db, SystemClock());
    await backfillPresetCategories(db, SystemClock());

    final tops = db.raw.select(
        "SELECT id FROM categories WHERE kind = 'expense' AND parent_id IS NULL "
        "AND deleted_at IS NULL ORDER BY sort_order").map((r) => r['id']! as String).toList();
    expect(tops, [for (final c in presetExpenseCategories) 'preset_${c.key}']);

    final presetOrphan = db.raw.select(
        "SELECT COUNT(*) AS c FROM categories p WHERE p.is_preset = 1 AND p.kind = 'expense' "
        "AND p.parent_id IS NULL AND p.deleted_at IS NULL AND NOT EXISTS ("
        "  SELECT 1 FROM categories c WHERE c.parent_id = p.id AND c.deleted_at IS NULL)");
    expect(presetOrphan.first['c'], 0);
  });

  test('落库后：收入 13 个一级，每个都有二级', () async {
    final db = AppDatabase.inMemory();
    addTearDown(db.close);
    db.raw.execute("INSERT INTO app_meta (key,value,updated_at) VALUES ('device.id','dev',0)");
    await seedPresetCategories(db, SystemClock());

    final tops = db.raw.select(
        "SELECT id FROM categories WHERE kind = 'income' AND parent_id IS NULL "
        "AND deleted_at IS NULL ORDER BY sort_order").map((r) => r['id']! as String).toList();
    expect(tops.length, 13);
    expect(tops.last, 'preset_income_other');

    for (final id in tops) {
      final kids =
          db.raw.select('SELECT COUNT(*) AS c FROM categories WHERE parent_id = ?', [id]);
      expect((kids.first['c'] as int) > 0, isTrue, reason: '$id 没有二级');
    }
  });
}

/// 返回重复出现的名字，测试失败时直接打印出来。
String _dups(List<String> names) {
  final seen = <String>{};
  final dup = <String>{};
  for (final n in names) {
    if (!seen.add(n)) dup.add(n);
  }
  return dup.join('、');
}
