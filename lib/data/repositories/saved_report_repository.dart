/// STORY-11.3「我的报表」仓储。
library;

import 'package:plain/core/result/result.dart';
import 'package:plain/core/time/clock.dart';
import 'package:plain/data/db/database.dart';
import 'package:plain/data/db/row_x.dart';
import 'package:plain/data/sync/change_log_writer.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/entities/saved_report.dart';
import 'package:plain/domain/repositories/repositories.dart';

class SavedReportRepositoryImpl implements SavedReportRepository {
  SavedReportRepositoryImpl({
    required AppDatabase db,
    required ChangeLogWriter changeLogWriter,
    Clock? clock,
  })  : _db = db,
        _changeLog = changeLogWriter,
        _clock = clock ?? SystemClock();

  final AppDatabase _db;
  final ChangeLogWriter _changeLog;
  final Clock _clock;

  @override
  Future<Result<List<SavedReport>>> listByBook(String bookId) async {
    try {
      final rows = _db.raw.select(
        'SELECT * FROM saved_reports WHERE book_id = ? AND deleted_at IS NULL '
        'ORDER BY created_at ASC',
        [bookId],
      );
      return ok([for (final r in rows) _fromRow(r)]);
    } on Exception catch (e) {
      return err(StorageFailure('db.query_failed', e.toString(), isRetryable: true));
    }
  }

  @override
  Future<Result<SavedReport>> create(SavedReport report) async {
    try {
      _db.transaction(() {
        _insert(report);
        _changeLog.write(
          entityType: EntityType.savedReport,
          entityId: report.id,
          op: ChangeOp.insert,
          deviceId: report.deviceId,
          baseRevision: 0,
          before: const {},
          after: _payload(report),
        );
      });
      return ok(report);
    } on Exception catch (e) {
      return err(StorageFailure('db.insert_failed', e.toString(), isRetryable: true));
    }
  }

  @override
  Future<Result<SavedReport>> update(SavedReport report) async {
    try {
      final oldRows = _db.raw.select('SELECT * FROM saved_reports WHERE id = ?', [report.id]);
      final before = oldRows.isEmpty ? const <String, Object?>{} : _payload(_fromRow(oldRows.first));
      _db.transaction(() {
        _updateRow(report);
        _changeLog.write(
          entityType: EntityType.savedReport,
          entityId: report.id,
          op: ChangeOp.update,
          deviceId: report.deviceId,
          baseRevision: report.baseRevision,
          before: before,
          after: _payload(report),
        );
      });
      return ok(report);
    } on Exception catch (e) {
      return err(StorageFailure('db.update_failed', e.toString(), isRetryable: true));
    }
  }

  @override
  Future<Result<void>> softDelete(String id) async {
    try {
      final rows = _db.raw.select('SELECT * FROM saved_reports WHERE id = ?', [id]);
      if (rows.isEmpty) {
        return err<void>(const NotFoundFailure('report.not_found', 'nf'));
      }
      final old = _fromRow(rows.first);
      final now = _clock.now();
      final deleted = old.copyWith(
        deletedAt: now,
        updatedAt: now,
        revision: old.revision + 1,
        baseRevision: old.revision,
      );
      _db.transaction(() {
        _updateRow(deleted);
        _changeLog.write(
          entityType: EntityType.savedReport,
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

  void _insert(SavedReport r) {
    _db.raw.execute(
      'INSERT INTO saved_reports (id,book_id,name,row_dim,col_dim,from_ms,to_ms,'
      'entry_filter,heatmap,created_at,updated_at,deleted_at,revision,device_id,base_revision) '
      'VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
      [
        r.id, r.bookId, r.name, r.rowDim.wire, r.colDim.wire, r.fromMs, r.toMs,
        r.entryFilter.wire, r.heatmap ? 1 : 0,
        r.createdAt.millisecondsSinceEpoch, r.updatedAt.millisecondsSinceEpoch,
        r.deletedAt?.millisecondsSinceEpoch, r.revision, r.deviceId, r.baseRevision,
      ],
    );
  }

  void _updateRow(SavedReport r) {
    _db.raw.execute(
      'UPDATE saved_reports SET name=?,row_dim=?,col_dim=?,from_ms=?,to_ms=?,'
      'entry_filter=?,heatmap=?,updated_at=?,deleted_at=?,revision=?,base_revision=? '
      'WHERE id=?',
      [
        r.name, r.rowDim.wire, r.colDim.wire, r.fromMs, r.toMs,
        r.entryFilter.wire, r.heatmap ? 1 : 0,
        r.updatedAt.millisecondsSinceEpoch, r.deletedAt?.millisecondsSinceEpoch,
        r.revision, r.baseRevision, r.id,
      ],
    );
  }

  SavedReport _fromRow(Map<String, Object?> row) => SavedReport(
        id: row['id']! as String,
        bookId: row['book_id']! as String,
        name: row['name']! as String,
        rowDim: CrossDimension.fromWire(row['row_dim'] as String?),
        colDim: CrossDimension.fromWire(row['col_dim'] as String?),
        fromMs: row.intOr('from_ms', 0),
        toMs: row.intOr('to_ms', 0),
        entryFilter: ReportEntryFilter.fromWire(row['entry_filter'] as String?),
        heatmap: ((row['heatmap'] as int?) ?? 1) == 1,
        createdAt: row.dateTime('created_at'),
        updatedAt: row.dateTime('updated_at'),
        deletedAt: row.nullableDateTime('deleted_at'),
        revision: row.intOr('revision', 1),
        deviceId: row['device_id']! as String,
        baseRevision: row.intOr('base_revision', 0),
      );

  Map<String, Object?> _payload(SavedReport r) => {
        'id': r.id,
        'book_id': r.bookId,
        'name': r.name,
        'row_dim': r.rowDim.wire,
        'col_dim': r.colDim.wire,
        'from_ms': r.fromMs,
        'to_ms': r.toMs,
        'entry_filter': r.entryFilter.wire,
        'heatmap': r.heatmap,
        // 必填审计列（见 syncMetaOf），漏了会让对端插入该报表直接失败。
        ...syncMetaOf(
          createdAt: r.createdAt,
          updatedAt: r.updatedAt,
          deletedAt: r.deletedAt,
          revision: r.revision,
          deviceId: r.deviceId,
          baseRevision: r.baseRevision,
        ),
      };
}
