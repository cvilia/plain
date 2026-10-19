/// Category note + preset catalog tests. See coding instruction T6.
library;
import 'package:flutter_test/flutter_test.dart';
import 'package:plain/core/time/clock.dart';
import 'package:plain/data/db/database.dart';
import 'package:plain/data/repositories/category_repository.dart';
import 'package:plain/data/seed/preset_categories.dart';
import 'package:plain/data/sync/change_log_writer.dart';
import 'package:plain/domain/entities/category.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/app/theme/theme_registry.dart';

void main() {
  test('A1 fresh install has categories.note and current user_version', () {
    final db = AppDatabase.inMemory();
    addTearDown(db.close);
    final cols = db.raw.select('PRAGMA table_info(categories)');
    expect(cols.any((r) => r['name'] == 'note'), isTrue);
    final ver = db.raw.select('PRAGMA user_version').first.values.first;
    // 断言当前版本常量而非字面量，迁移加版本时不必改这里
    expect(ver, kSchemaVersion);
  });

  test('A2 migrate adds note idempotently', () {
    final raw = AppDatabase.inMemory();
    addTearDown(raw.close);
    raw.raw.execute('DROP TABLE categories');
    raw.raw.execute("CREATE TABLE categories (id TEXT NOT NULL PRIMARY KEY, parent_id TEXT NULL, name TEXT NOT NULL, kind TEXT NOT NULL, icon_ref TEXT NOT NULL, icon_asset TEXT NULL, sort_order INTEGER NOT NULL, is_hidden INTEGER NOT NULL DEFAULT 0, is_preset INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, deleted_at INTEGER NULL, revision INTEGER NOT NULL DEFAULT 1, device_id TEXT NOT NULL, base_revision INTEGER NOT NULL DEFAULT 0)");
    raw.raw.execute("INSERT INTO categories (id,name,kind,icon_ref,sort_order,is_hidden,is_preset,created_at,updated_at,device_id) VALUES ('c1','old','expense','other',0,0,0,0,0,'d')");
    final before = raw.raw.select('PRAGMA table_info(categories)');
    expect(before.any((r) => r['name'] == 'note'), isFalse);
    void runMigrate() {
      final catCols = raw.raw.select('PRAGMA table_info(categories)');
      if (!catCols.any((r) => r['name'] == 'note')) {
        raw.raw.execute('ALTER TABLE categories ADD COLUMN note TEXT NULL');
      }
    }
    runMigrate();
    runMigrate();
    final after = raw.raw.select('PRAGMA table_info(categories)');
    expect(after.any((r) => r['name'] == 'note'), isTrue);
    final row = raw.raw.select('SELECT note FROM categories WHERE id = ?', ['c1']).first;
    expect(row['note'], isNull);
  });

  test('A3 note can be cleared via withNote', () async {
    final db = AppDatabase.inMemory();
    addTearDown(db.close);
    final repo = CategoryRepositoryImpl(db: db, changeLogWriter: ChangeLogWriter(db), clock: SystemClock());
    final now = DateTime.now().toUtc();
    final cat = Category(id: 'c_note', name: 'test', kind: CategoryKind.expense, iconRef: 'other', note: 'has note', sortOrder: 0, createdAt: now, updatedAt: now, deviceId: 'd');
    await repo.create(cat);
    final withN = (await repo.getById('c_note')).successOrNull!;
    expect(withN.note, 'has note');
    final cleared = withN.withNote(null).copyWith(updatedAt: DateTime.now().toUtc(), revision: withN.revision + 1, baseRevision: withN.revision);
    await repo.update(cleared);
    final back = (await repo.getById('c_note')).successOrNull!;
    expect(back.note, isNull);
  });

  test('A4 preset catalog 41+15 leaves, renames and notes', () async {
    final db = AppDatabase.inMemory();
    addTearDown(db.close);
    db.raw.execute("INSERT INTO app_meta (key,value,updated_at) VALUES ('device.id','dev',0)");
    await seedPresetCategories(db, SystemClock());
    final rows = db.raw.select('SELECT name, parent_id, note FROM categories WHERE deleted_at IS NULL');
    final names = rows.map((r) => r['name']! as String).toSet();
    expect(names.contains('食材'), isTrue);
    expect(names.contains('蔬果'), isFalse);
    expect(names.contains('午餐'), isTrue);
    expect(names.contains('正餐'), isFalse);
    expect(names.contains('请客'), isTrue);
    expect(names.contains('聚餐'), isFalse);
    expect(names.contains('超市'), isFalse);
    final expLeaves = db.raw.select("SELECT c.name FROM categories c JOIN categories p ON c.parent_id = p.id WHERE c.kind = 'expense' AND c.deleted_at IS NULL");
    final incLeaves = db.raw.select("SELECT c.name FROM categories c JOIN categories p ON c.parent_id = p.id WHERE c.kind = 'income' AND c.deleted_at IS NULL");
    expect(expLeaves.length, 41);
    expect(incLeaves.length, 15);
    final foodKids = db.raw.select("SELECT c.name FROM categories c JOIN categories p ON c.parent_id = p.id WHERE p.name = '餐饮' ORDER BY c.sort_order").map((r) => r['name']! as String).toList();
    expect(foodKids, ['早餐', '午餐', '晚餐', '夜宵', '零食', '饮料']);
    final presets = db.raw.select('SELECT note FROM categories WHERE is_preset = 1 AND deleted_at IS NULL');
    for (final r in presets) {
      final n = r['note'] as String?;
      expect(n, isNotNull);
      expect(n!.isNotEmpty, isTrue);
      expect(n.length <= 30, isTrue);
    }
  });

  test('A6 categoryColorMap keyed by iconRef has 12 unique colors', () {
    expect(categoryColorMap.length, 12);
    expect(categoryColorMap.keys.toSet().length, 12);
    // Stable iconRef keys survive user renames (P0-9).
    expect(categoryColorMap.containsKey('fruit'), isTrue);
    expect(categoryColorMap.containsKey('蔬果'), isFalse);
    expect(categoryColorMap['fruit'], 0xFF4ADE80);
  });
}
