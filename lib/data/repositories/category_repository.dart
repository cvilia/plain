/// Category repository implementation.
library;

import 'package:plain/core/result/result.dart';
import 'package:plain/core/time/clock.dart';
import 'package:plain/data/db/database.dart';
import 'package:plain/data/sync/change_log_writer.dart';
import 'package:plain/domain/entities/category.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/repositories/repositories.dart';

class CategoryRepositoryImpl implements CategoryRepository {
  CategoryRepositoryImpl({
    required AppDatabase db, required ChangeLogWriter changeLogWriter, required Clock clock,
  })  : _db = db, _changeLog = changeLogWriter, _clock = clock;

  final AppDatabase _db;
  final ChangeLogWriter _changeLog;
  final Clock _clock;

  @override
  Future<Result<List<Category>>> listVisible({CategoryKind? kind}) async {
    final all = await listAll(kind: kind);
    return all.when(
      success: (list) => ok(list.where((c) => !c.isHidden).toList()),
      failure: (f) => err(f),
    );
  }

  @override
  Future<Result<List<Category>>> listAll({CategoryKind? kind}) async {
    try {
      final where = StringBuffer('deleted_at IS NULL');
      final args = <Object?>[];
      if (kind != null) { where.write(' AND kind = ?'); args.add(kind.wire); }
      final rows = _db.raw.select('SELECT * FROM categories WHERE $where ORDER BY sort_order ASC', args);
      return ok(rows.map(_fromRow).toList());
    } on Exception catch (e) {
      return err(StorageFailure('db.query_failed', e.toString(), isRetryable: true));
    }
  }

  @override
  Future<Result<Category>> getById(String id) async {
    final rows = _db.raw.select('SELECT * FROM categories WHERE id = ? AND deleted_at IS NULL', [id]);
    if (rows.isEmpty) return err<Category>(const NotFoundFailure('category.not_found', 'nf'));
    return ok(_fromRow(rows.first));
  }

  @override
  Future<Result<Category>> create(Category category) async {
    try {
      _db.transaction(() {
        _insert(category);
        _changeLog.write(
          entityType: EntityType.category, entityId: category.id, op: ChangeOp.insert,
          deviceId: category.deviceId, baseRevision: 0, before: const {}, after: _payload(category));
      });
      return ok(category);
    } on Exception catch (e) {
      return err(StorageFailure('db.insert_failed', e.toString(), isRetryable: true));
    }
  }

  @override
  Future<Result<Category>> update(Category category) async {
    try {
      _db.transaction(() {
        _update(category);
        _changeLog.write(
          entityType: EntityType.category, entityId: category.id, op: ChangeOp.update,
          deviceId: category.deviceId, baseRevision: category.baseRevision,
          before: const {}, after: _payload(category));
      });
      return ok(category);
    } on Exception catch (e) {
      return err(StorageFailure('db.update_failed', e.toString(), isRetryable: true));
    }
  }

  @override
  Future<Result<void>> softDelete(String id) async {
    try {
      final existing = await getById(id);
      final f = existing.failureOrNull;
      if (f != null) return err<void>(f);
      final cat = existing.successOrNull!;
      final now = _clock.now();
      final deleted = cat.copyWith(deletedAt: now, updatedAt: now, revision: cat.revision + 1, baseRevision: cat.revision);
      _db.transaction(() {
        _update(deleted);
        _changeLog.write(
          entityType: EntityType.category, entityId: id, op: ChangeOp.delete,
          deviceId: cat.deviceId, baseRevision: cat.revision, before: _payload(cat), after: const {});
      });
      return ok(null);
    } on Exception catch (e) {
      return err(StorageFailure('db.delete_failed', e.toString(), isRetryable: true));
    }
  }

  @override
  Future<Result<int>> merge({required String sourceId, required String targetId}) async {
    try {
      var moved = 0;
      _db.transaction(() {
        _db.raw.execute('UPDATE transactions SET category_id = ? WHERE category_id = ? AND deleted_at IS NULL', [targetId, sourceId]);
        moved = _db.raw.updatedRows;
        final src = _db.raw.select('SELECT * FROM categories WHERE id = ?', [sourceId]);
        if (src.isNotEmpty) {
          final cat = _fromRow(src.first);
          final now = _clock.now();
          _update(cat.copyWith(deletedAt: now, updatedAt: now, revision: cat.revision + 1, baseRevision: cat.revision));
        }
      });
      return ok(moved);
    } on Exception catch (e) {
      return err(StorageFailure('db.merge_failed', e.toString(), isRetryable: true));
    }
  }

  void _insert(Category c) {
    _db.raw.execute(
      'INSERT INTO categories (id,parent_id,name,kind,icon_ref,icon_asset,sort_order,is_hidden,is_preset,created_at,updated_at,deleted_at,revision,device_id,base_revision) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
      [c.id, c.parentId, c.name, c.kind.wire, c.iconRef, c.iconAsset, c.sortOrder, c.isHidden ? 1 : 0, c.isPreset ? 1 : 0, c.createdAt.millisecondsSinceEpoch, c.updatedAt.millisecondsSinceEpoch, c.deletedAt?.millisecondsSinceEpoch, c.revision, c.deviceId, c.baseRevision]);
  }

  void _update(Category c) {
    _db.raw.execute(
      'UPDATE categories SET name=?,icon_ref=?,icon_asset=?,sort_order=?,is_hidden=?,updated_at=?,deleted_at=?,revision=?,base_revision=? WHERE id=?',
      [c.name, c.iconRef, c.iconAsset, c.sortOrder, c.isHidden ? 1 : 0, c.updatedAt.millisecondsSinceEpoch, c.deletedAt?.millisecondsSinceEpoch, c.revision, c.baseRevision, c.id]);
  }

  Category _fromRow(Map<String, Object?> row) => Category(
    id: row['id']! as String, parentId: row['parent_id'] as String?,
    name: row['name']! as String, kind: CategoryKind.fromWire(row['kind'] as String?),
    iconRef: row['icon_ref']! as String, iconAsset: row['icon_asset'] as String?,
    sortOrder: row['sort_order']! as int, isHidden: (row['is_hidden'] as int?) == 1,
    isPreset: (row['is_preset'] as int?) == 1,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at']! as int, isUtc: true),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at']! as int, isUtc: true),
    deletedAt: row['deleted_at'] == null ? null : DateTime.fromMillisecondsSinceEpoch(row['deleted_at']! as int, isUtc: true),
    revision: (row['revision'] as int?) ?? 1, deviceId: row['device_id']! as String,
    baseRevision: (row['base_revision'] as int?) ?? 0);

  Map<String, Object?> _payload(Category c) => {
    'id': c.id, 'parent_id': c.parentId, 'name': c.name, 'kind': c.kind.wire,
    'icon_ref': c.iconRef, 'sort_order': c.sortOrder, 'is_hidden': c.isHidden, 'is_preset': c.isPreset,
  };
}
