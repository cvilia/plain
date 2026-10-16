/// Category repository implementation.
library;

import 'package:plain/core/result/result.dart';
import 'package:plain/core/time/clock.dart';
import 'package:plain/data/db/database.dart';
import 'package:plain/data/db/row_x.dart';
import 'package:plain/data/db/run_write.dart';
import 'package:plain/data/db/stats_maintenance.dart';
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
    return runWrite(
      _db,
      failCode: 'db.insert_failed',
      result: category,
      body: () {
        _insert(category);
        _changeLog.write(
          entityType: EntityType.category, entityId: category.id, op: ChangeOp.insert,
          deviceId: category.deviceId, baseRevision: 0, before: const {}, after: _payload(category));
      },
    );
  }

  @override
  Future<Result<Category>> update(Category category) async {
    final existing = await getById(category.id);
    final f = existing.failureOrNull;
    if (f != null) return err<Category>(f);
    final old = existing.successOrNull!;
    return runWrite(
      _db,
      failCode: 'db.update_failed',
      result: category,
      body: () {
        _update(category);
        _changeLog.write(
          entityType: EntityType.category, entityId: category.id, op: ChangeOp.update,
          deviceId: category.deviceId, baseRevision: category.baseRevision,
          before: _payload(old), after: _payload(category));
      },
    );
  }

  @override
  Future<Result<void>> softDelete(String id) async {
    final existing = await getById(id);
    final f = existing.failureOrNull;
    if (f != null) return err<void>(f);
    final cat = existing.successOrNull!;
    final now = _clock.now();
    final deleted = cat.copyWith(
      deletedAt: now, updatedAt: now,
      revision: cat.revision + 1, baseRevision: cat.revision,
    );
    return runWrite<void>(
      _db,
      failCode: 'db.delete_failed',
      result: null,
      body: () {
        _update(deleted);
        _changeLog.write(
          entityType: EntityType.category, entityId: id, op: ChangeOp.delete,
          deviceId: cat.deviceId, baseRevision: cat.revision,
          before: _payload(cat), after: const {});
      },
    );
  }

  @override
  Future<Result<Category>> moveToParent({
    required String categoryId,
    required String newParentId,
  }) async {
    final catRes = await getById(categoryId);
    final f = catRes.failureOrNull;
    if (f != null) return err<Category>(f);
    final cat = catRes.successOrNull!;

    if (cat.isRoot) {
      return err<Category>(const ValidationFailure('category.root_not_movable', 'root'));
    }

    final parentRes = await getById(newParentId);
    final pf = parentRes.failureOrNull;
    if (pf != null) return err<Category>(pf);
    final parent = parentRes.successOrNull!;
    if (!parent.isRoot) {
      return err<Category>(const ValidationFailure('category.parent_must_be_root', 'parent'));
    }
    if (parent.kind != cat.kind) {
      return err<Category>(const ValidationFailure('category.kind_mismatch', 'kind'));
    }
    if (parent.id == cat.parentId) {
      return err<Category>(const ConflictFailure('category.same_parent', 'same'));
    }

    final now = _clock.now();
    final moved = cat.withParent(parent.id).copyWith(
          updatedAt: now,
          revision: cat.revision + 1,
          baseRevision: cat.revision,
        );
    return runWrite(
      _db,
      failCode: 'db.update_failed',
      result: moved,
      body: () {
        _update(moved);
        _changeLog.write(
          entityType: EntityType.category,
          entityId: cat.id,
          op: ChangeOp.update,
          deviceId: cat.deviceId,
          baseRevision: cat.baseRevision,
          before: _payload(cat),
          after: _payload(moved),
        );
      },
    );
  }

  @override
  Future<Result<int>> countLiveEntries({
    required String categoryId,
    bool includeDescendants = false,
  }) async {
    try {
      final ids = <String>[categoryId];
      if (includeDescendants) {
        final kids = _db.raw.select(
          'SELECT id FROM categories WHERE parent_id = ? AND deleted_at IS NULL',
          [categoryId],
        );
        for (final r in kids) {
          ids.add(r['id']! as String);
        }
      }
      final placeholders = List.filled(ids.length, '?').join(',');
      final rows = _db.raw.select(
        'SELECT COUNT(*) AS c FROM transactions '
        "WHERE category_id IN ($placeholders) AND deleted_at IS NULL "
        "AND source <> 'reconcile'",
        ids,
      );
      return ok((rows.first['c'] as int?) ?? 0);
    } on Exception catch (e) {
      return err(StorageFailure('db.query_failed', e.toString(), isRetryable: true));
    }
  }

  @override
  Future<Result<int>> deleteAndReassign({
    required String categoryId,
    required String fallbackCategoryId,
    bool includeDescendants = false,
  }) async {
    var moved = 0;
    final result = runWrite<int>(
      _db,
      failCode: 'db.delete_failed',
      result: 0,
      body: () {
        final sourceIds = <String>[categoryId];
        if (includeDescendants) {
          final kids = _db.raw.select(
            'SELECT id FROM categories WHERE parent_id = ? AND deleted_at IS NULL',
            [categoryId],
          );
          for (final r in kids) {
            final id = r['id']! as String;
            if (id != fallbackCategoryId) sourceIds.add(id);
          }
        }

        for (final sid in sourceIds) {
          final affected = _db.raw.select(
            'SELECT * FROM transactions WHERE category_id = ? AND deleted_at IS NULL',
            [sid],
          );
          if (affected.isEmpty) continue;
          final nowMs = _clock.now().millisecondsSinceEpoch;
          _db.raw.execute(
            'UPDATE transactions SET category_id = ? WHERE category_id = ? AND deleted_at IS NULL',
            [fallbackCategoryId, sid],
          );
          moved += _db.raw.updatedRows;
          for (final row in affected) {
            final old = ledgerEntryFromRow(row);
            // ⚠️ 改派分类必须同步搬动按天统计，否则金额永久挂在旧分类上
            // （报表/预算分类汇总看不到这笔；巡检只比对条数，发现不了）
            moveStatsToCategory(
              _db,
              oldEntry: old,
              toCategoryId: fallbackCategoryId,
              dayKey: statsDayKeyOf(_clock, old.occurredAt),
              nowMs: nowMs,
            );
            // ⚠️ 写**整行** payload：只写 category_id 的话，对端若没有这一行
            // （新设备/GC 之后）会因缺必填列插入失败 → 整批 pull 失败且位点不推进
            // → 那台设备同步永久卡住。
            final updated = old.copyWith(
              categoryId: fallbackCategoryId,
              updatedAt: _clock.now(),
              revision: old.revision + 1,
              baseRevision: old.revision,
            );
            _changeLog.write(
              entityType: EntityType.transaction,
              entityId: old.id,
              op: ChangeOp.update,
              deviceId: old.deviceId,
              baseRevision: old.revision,
              before: ledgerEntryPayloadOf(old),
              after: ledgerEntryPayloadOf(updated),
            );
          }
        }

        for (final sid in sourceIds) {
          final src = _db.raw.select('SELECT * FROM categories WHERE id = ?', [sid]);
          if (src.isEmpty) continue;
          final cat = _fromRow(src.first);
          final now = _clock.now();
          final deleted = cat.copyWith(
            deletedAt: now, updatedAt: now,
            revision: cat.revision + 1, baseRevision: cat.revision,
          );
          _update(deleted);
          _changeLog.write(
            entityType: EntityType.category, entityId: sid, op: ChangeOp.delete,
            deviceId: cat.deviceId, baseRevision: cat.revision,
            before: _payload(cat), after: const {},
          );
        }
      },
    );
    return result.when(
      success: (_) => ok(moved),
      failure: (f) => err(f),
    );
  }

  @override
  Future<Result<CategoryMergeResult>> mergeCategories({
    required String sourceId,
    required String targetId,
  }) async {
    if (sourceId == targetId) {
      return err(const ValidationFailure('category.merge_same', 'same'));
    }
    var movedEntries = 0;
    var movedChildren = 0;
    var mergedSameName = 0;

    final result = runWrite<CategoryMergeResult>(
      _db,
      failCode: 'db.merge_failed',
      result: const CategoryMergeResult(movedEntries: 0, movedChildren: 0, mergedSameNameChildren: 0),
      body: () {
        final srcRow = _db.raw.select('SELECT * FROM categories WHERE id = ? AND deleted_at IS NULL', [sourceId]);
        final dstRow = _db.raw.select('SELECT * FROM categories WHERE id = ? AND deleted_at IS NULL', [targetId]);
        if (srcRow.isEmpty || dstRow.isEmpty) {
          throw StateError('category.merge_not_found');
        }
        final src = _fromRow(srcRow.first);
        final dst = _fromRow(dstRow.first);
        // 仅同层级合并
        if ((src.parentId == null) != (dst.parentId == null)) {
          throw StateError('category.merge_level_mismatch');
        }

        int moveEntries(String fromId, String toId) {
          final affected = _db.raw.select(
            'SELECT * FROM transactions WHERE category_id = ? AND deleted_at IS NULL',
            [fromId],
          );
          if (affected.isEmpty) return 0;
          final nowMs = _clock.now().millisecondsSinceEpoch;
          _db.raw.execute(
            'UPDATE transactions SET category_id = ? WHERE category_id = ? AND deleted_at IS NULL',
            [toId, fromId],
          );
          for (final row in affected) {
            final old = ledgerEntryFromRow(row);
            // 与 deleteAndReassign 同一套：搬统计 + 写整行 payload
            moveStatsToCategory(
              _db,
              oldEntry: old,
              toCategoryId: toId,
              dayKey: statsDayKeyOf(_clock, old.occurredAt),
              nowMs: nowMs,
            );
            final updated = old.copyWith(
              categoryId: toId,
              updatedAt: _clock.now(),
              revision: old.revision + 1,
              baseRevision: old.revision,
            );
            _changeLog.write(
              entityType: EntityType.transaction,
              entityId: old.id,
              op: ChangeOp.update,
              deviceId: old.deviceId,
              baseRevision: old.revision,
              before: ledgerEntryPayloadOf(old),
              after: ledgerEntryPayloadOf(updated),
            );
          }
          return affected.length;
        }

        void softDeleteCategory(Category cat) {
          final now = _clock.now();
          final deleted = cat.copyWith(
            deletedAt: now, updatedAt: now,
            revision: cat.revision + 1, baseRevision: cat.revision,
          );
          _update(deleted);
          _changeLog.write(
            entityType: EntityType.category, entityId: cat.id, op: ChangeOp.delete,
            deviceId: cat.deviceId, baseRevision: cat.revision,
            before: _payload(cat), after: const {},
          );
        }

        if (src.parentId == null) {
          // 一级合并：二级整体迁移；同名二级并入目标同名项
          final kids = _db.raw.select(
            'SELECT * FROM categories WHERE parent_id = ? AND deleted_at IS NULL',
            [sourceId],
          );
          final dstKids = _db.raw.select(
            'SELECT * FROM categories WHERE parent_id = ? AND deleted_at IS NULL',
            [targetId],
          );
          final dstByName = <String, Category>{
            for (final r in dstKids) (_fromRow(r).name): _fromRow(r),
          };
          for (final r in kids) {
            final child = _fromRow(r);
            final same = dstByName[child.name];
            if (same != null) {
              movedEntries += moveEntries(child.id, same.id);
              softDeleteCategory(child);
              mergedSameName++;
            } else {
              // 挂到目标一级下
              final now = _clock.now();
              final reparented = child.copyWith(
                // parent change is applied via raw update (copyWith has no parentId)
                updatedAt: now,
                revision: child.revision + 1,
                baseRevision: child.revision,
              );
              _db.raw.execute(
                'UPDATE categories SET parent_id = ?, updated_at = ?, revision = ?, base_revision = ? WHERE id = ?',
                [targetId, now.millisecondsSinceEpoch, reparented.revision, child.revision, child.id],
              );
              _changeLog.write(
                entityType: EntityType.category,
                entityId: child.id,
                op: ChangeOp.update,
                deviceId: child.deviceId,
                baseRevision: child.revision,
                before: _payload(child),
                after: {..._payload(child), 'parent_id': targetId},
              );
              movedChildren++;
            }
          }
          movedEntries += moveEntries(sourceId, targetId);
          softDeleteCategory(src);
        } else {
          // 二级合并：账单并入目标，源软删
          movedEntries += moveEntries(sourceId, targetId);
          softDeleteCategory(src);
        }
      },
    );

    return result.when(
      success: (_) => ok(CategoryMergeResult(
        movedEntries: movedEntries,
        movedChildren: movedChildren,
        mergedSameNameChildren: mergedSameName,
      )),
      failure: (f) => err(f),
    );
  }

  void _insert(Category c) {
    _db.raw.execute(
      'INSERT INTO categories (id,parent_id,name,kind,icon_ref,icon_asset,note,sort_order,is_hidden,is_preset,is_rigid,is_deductible,created_at,updated_at,deleted_at,revision,device_id,base_revision) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
      [c.id, c.parentId, c.name, c.kind.wire, c.iconRef, c.iconAsset, c.note, c.sortOrder, c.isHidden ? 1 : 0, c.isPreset ? 1 : 0, c.isRigid ? 1 : 0, c.isDeductible ? 1 : 0, c.createdAt.millisecondsSinceEpoch, c.updatedAt.millisecondsSinceEpoch, c.deletedAt?.millisecondsSinceEpoch, c.revision, c.deviceId, c.baseRevision]);
  }

  void _update(Category c) {
    _db.raw.execute(
      'UPDATE categories SET name=?,icon_ref=?,icon_asset=?,note=?,sort_order=?,is_hidden=?,is_rigid=?,is_deductible=?,updated_at=?,deleted_at=?,revision=?,base_revision=? WHERE id=?',
      [c.name, c.iconRef, c.iconAsset, c.note, c.sortOrder, c.isHidden ? 1 : 0, c.isRigid ? 1 : 0, c.isDeductible ? 1 : 0, c.updatedAt.millisecondsSinceEpoch, c.deletedAt?.millisecondsSinceEpoch, c.revision, c.baseRevision, c.id]);
  }

  Category _fromRow(Map<String, Object?> row) => Category(
    id: row['id']! as String, parentId: row['parent_id'] as String?,
    name: row['name']! as String, kind: CategoryKind.fromWire(row['kind'] as String?),
    iconRef: row['icon_ref']! as String, iconAsset: row['icon_asset'] as String?,
    note: row['note'] as String?,
    sortOrder: row['sort_order']! as int, isHidden: row.boolOr('is_hidden'),
    isPreset: row.boolOr('is_preset'),
    isRigid: row.boolOr('is_rigid'),
    isDeductible: row.boolOr('is_deductible'),
    createdAt: row.dateTime('created_at'),
    updatedAt: row.dateTime('updated_at'),
    deletedAt: row.nullableDateTime('deleted_at'),
    revision: row.intOr('revision', 1), deviceId: row['device_id']! as String,
    baseRevision: row.intOr('base_revision', 0));

  Map<String, Object?> _payload(Category c) => {
    'id': c.id, 'parent_id': c.parentId, 'name': c.name, 'kind': c.kind.wire,
    'icon_ref': c.iconRef, 'note': c.note, 'sort_order': c.sortOrder,
    'is_hidden': c.isHidden, 'is_preset': c.isPreset, 'is_rigid': c.isRigid,
    // 漏列会让对端静默丢两件事：自定义图标、以及税务报表的「可抵扣」
    // 标记（audit 2026-10-15）
    'icon_asset': c.iconAsset, 'is_deductible': c.isDeductible,
  };
}
