/// STORY-10.1 投资持仓仓储。
library;

import 'package:plain/core/result/result.dart';
import 'package:plain/data/db/database.dart';
import 'package:plain/data/db/row_x.dart';
import 'package:plain/data/sync/change_log_writer.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/entities/holding.dart';
import 'package:plain/domain/repositories/repositories.dart';

class HoldingRepositoryImpl implements HoldingRepository {
  HoldingRepositoryImpl({
    required AppDatabase db,
    required ChangeLogWriter changeLogWriter,
  })  : _db = db,
        _changeLog = changeLogWriter;

  final AppDatabase _db;
  final ChangeLogWriter _changeLog;

  @override
  Future<Result<List<Holding>>> listByAccount(String accountId) async {
    try {
      final rows = _db.raw.select(
        'SELECT * FROM holdings WHERE account_id = ? AND deleted_at IS NULL '
        'ORDER BY created_at ASC',
        [accountId],
      );
      return ok([for (final r in rows) _fromRow(r)]);
    } on Exception catch (e) {
      return err(StorageFailure('db.query_failed', e.toString(), isRetryable: true));
    }
  }

  @override
  Future<Result<List<Holding>>> listByBook(String bookId) async {
    try {
      final rows = _db.raw.select(
        'SELECT * FROM holdings WHERE book_id = ? AND deleted_at IS NULL '
        'ORDER BY created_at ASC',
        [bookId],
      );
      return ok([for (final r in rows) _fromRow(r)]);
    } on Exception catch (e) {
      return err(StorageFailure('db.query_failed', e.toString(), isRetryable: true));
    }
  }

  @override
  Future<Result<Holding>> getById(String id) async {
    try {
      final rows = _db.raw.select('SELECT * FROM holdings WHERE id = ?', [id]);
      if (rows.isEmpty) {
        return err<Holding>(const NotFoundFailure('holding.not_found', 'nf'));
      }
      return ok(_fromRow(rows.first));
    } on Exception catch (e) {
      return err(StorageFailure('db.query_failed', e.toString(), isRetryable: true));
    }
  }

  @override
  Future<Result<Holding>> create(Holding holding) async {
    try {
      _db.transaction(() {
        _insert(holding);
        _changeLog.write(
          entityType: EntityType.holding,
          entityId: holding.id,
          op: ChangeOp.insert,
          deviceId: holding.deviceId,
          baseRevision: 0,
          before: const {},
          after: _payload(holding),
        );
      });
      return ok(holding);
    } on Exception catch (e) {
      return err(StorageFailure('db.insert_failed', e.toString(), isRetryable: true));
    }
  }

  @override
  Future<Result<Holding>> update(Holding holding) async {
    try {
      // `before` = 改动前的整行；空 map 会被同步端当成「没有共同祖先」，
      // 每次普通修改都凭空产生一批字段冲突。
      final oldRows = _db.raw.select('SELECT * FROM holdings WHERE id = ?', [holding.id]);
      final before = oldRows.isEmpty ? const <String, Object?>{} : _payload(_fromRow(oldRows.first));
      _db.transaction(() {
        _updateRow(holding);
        _changeLog.write(
          entityType: EntityType.holding,
          entityId: holding.id,
          op: ChangeOp.update,
          deviceId: holding.deviceId,
          baseRevision: holding.baseRevision,
          before: before,
          after: _payload(holding),
        );
      });
      return ok(holding);
    } on Exception catch (e) {
      return err(StorageFailure('db.update_failed', e.toString(), isRetryable: true));
    }
  }

  @override
  Future<Result<void>> softDelete(String id) async {
    try {
      final found = await getById(id);
      final f = found.failureOrNull;
      if (f != null) return err<void>(f);
      final old = found.successOrNull!;
      final now = DateTime.now().toUtc();
      final deleted = old.copyWith(
        deletedAt: now,
        updatedAt: now,
        revision: old.revision + 1,
        baseRevision: old.revision,
      );
      _db.transaction(() {
        _updateRow(deleted);
        _changeLog.write(
          entityType: EntityType.holding,
          entityId: id,
          op: ChangeOp.delete,
          deviceId: old.deviceId,
          baseRevision: old.revision,
          before: _payload(old),
          after: const {},
        );
      });
      return ok(null);
    } on Exception catch (e) {
      return err(StorageFailure('db.delete_failed', e.toString(), isRetryable: true));
    }
  }

  void _insert(Holding h) {
    _db.raw.execute(
      'INSERT INTO holdings (id,book_id,account_id,name,code,asset_type,'
      'shares_x10000,cost_price_cents,last_price_cents,price_updated_at,realized_pnl_cents,'
      'created_at,updated_at,deleted_at,revision,device_id,base_revision) '
      'VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
      _rowArgs(h, includeCreated: true),
    );
  }

  void _updateRow(Holding h) {
    _db.raw.execute(
      'UPDATE holdings SET name=?,code=?,asset_type=?,shares_x10000=?,'
      'cost_price_cents=?,last_price_cents=?,price_updated_at=?,realized_pnl_cents=?,'
      'updated_at=?,deleted_at=?,revision=?,base_revision=? WHERE id=?',
      [
        h.name, h.code, h.assetType.wire, h.sharesX10000,
        h.costPriceCents, h.lastPriceCents, h.priceUpdatedAt?.millisecondsSinceEpoch,
        h.realizedPnlCents,
        h.updatedAt.millisecondsSinceEpoch, h.deletedAt?.millisecondsSinceEpoch,
        h.revision, h.baseRevision, h.id,
      ],
    );
  }

  List<Object?> _rowArgs(Holding h, {required bool includeCreated}) => [
        h.id, h.bookId, h.accountId, h.name, h.code, h.assetType.wire,
        h.sharesX10000, h.costPriceCents, h.lastPriceCents,
        h.priceUpdatedAt?.millisecondsSinceEpoch, h.realizedPnlCents,
        h.createdAt.millisecondsSinceEpoch, h.updatedAt.millisecondsSinceEpoch,
        h.deletedAt?.millisecondsSinceEpoch, h.revision, h.deviceId, h.baseRevision,
      ];

  Holding _fromRow(Map<String, Object?> row) => Holding(
        id: row['id']! as String,
        bookId: row['book_id']! as String,
        accountId: row['account_id']! as String,
        name: row['name']! as String,
        code: row['code'] as String?,
        assetType: AssetType.fromWire(row['asset_type'] as String?),
        sharesX10000: row.intOr('shares_x10000', 0),
        costPriceCents: row.intOr('cost_price_cents', 0),
        lastPriceCents: row.intOr('last_price_cents', 0),
        priceUpdatedAt: row.nullableDateTime('price_updated_at'),
        realizedPnlCents: row.intOr('realized_pnl_cents', 0),
        createdAt: row.dateTime('created_at'),
        updatedAt: row.dateTime('updated_at'),
        deletedAt: row.nullableDateTime('deleted_at'),
        revision: row.intOr('revision', 1),
        deviceId: row['device_id']! as String,
        baseRevision: row.intOr('base_revision', 0),
      );

  Map<String, Object?> _payload(Holding h) => {
        'id': h.id,
        'book_id': h.bookId,
        'account_id': h.accountId,
        'name': h.name,
        'code': h.code,
        'asset_type': h.assetType.wire,
        'shares_x10000': h.sharesX10000,
        'cost_price_cents': h.costPriceCents,
        'last_price_cents': h.lastPriceCents,
        'price_updated_at': h.priceUpdatedAt?.millisecondsSinceEpoch,
        'realized_pnl_cents': h.realizedPnlCents,
        // 必填审计列（见 syncMetaOf），漏了会让对端插入该持仓直接失败。
        ...syncMetaOf(
          createdAt: h.createdAt,
          updatedAt: h.updatedAt,
          deletedAt: h.deletedAt,
          revision: h.revision,
          deviceId: h.deviceId,
          baseRevision: h.baseRevision,
        ),
      };
}
