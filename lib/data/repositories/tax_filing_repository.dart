/// STORY-11.5 税务申报状态仓储。
library;

import 'package:plain/core/result/result.dart';
import 'package:plain/core/time/clock.dart';
import 'package:plain/data/db/database.dart';
import 'package:plain/data/db/row_x.dart';
import 'package:plain/data/sync/change_log_writer.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/entities/tax_filing.dart';
import 'package:plain/domain/repositories/repositories.dart';

class TaxFilingRepositoryImpl implements TaxFilingRepository {
  TaxFilingRepositoryImpl({
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
  Future<Result<List<TaxFiling>>> listByBook(String bookId) async {
    try {
      final rows = _db.raw.select(
        'SELECT * FROM tax_filings WHERE book_id = ? AND deleted_at IS NULL '
        'ORDER BY filed_at DESC',
        [bookId],
      );
      return ok([for (final r in rows) _fromRow(r)]);
    } on Exception catch (e) {
      return err(StorageFailure('db.query_failed', e.toString(), isRetryable: true));
    }
  }

  @override
  Future<Result<TaxFiling>> markFiled({
    required String id,
    required String bookId,
    required String periodKey,
    required TaxPeriodKind periodKind,
    required String deviceId,
    String? note,
  }) async {
    try {
      final now = _clock.now();
      final filing = TaxFiling(
        id: id,
        bookId: bookId,
        periodKey: periodKey,
        periodKind: periodKind,
        filedAt: now,
        note: note,
        createdAt: now,
        updatedAt: now,
        deviceId: deviceId,
      );
      _db.transaction(() {
        _insert(filing);
        _changeLog.write(
          entityType: EntityType.taxFiling,
          entityId: id,
          op: ChangeOp.insert,
          deviceId: deviceId,
          baseRevision: 0,
          before: const {},
          after: _payload(filing),
        );
      });
      return ok(filing);
    } on Exception catch (e) {
      return err(StorageFailure('db.insert_failed', e.toString(), isRetryable: true));
    }
  }

  @override
  Future<Result<void>> unmarkFiled(String id) async {
    try {
      final rows = _db.raw.select('SELECT * FROM tax_filings WHERE id = ?', [id]);
      if (rows.isEmpty) {
        return err<void>(const NotFoundFailure('tax_filing.not_found', 'nf'));
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
        _db.raw.execute(
          'UPDATE tax_filings SET updated_at=?,deleted_at=?,revision=?,base_revision=? WHERE id=?',
          [
            deleted.updatedAt.millisecondsSinceEpoch,
            deleted.deletedAt?.millisecondsSinceEpoch,
            deleted.revision,
            deleted.baseRevision,
            deleted.id,
          ],
        );
        _changeLog.write(
          entityType: EntityType.taxFiling,
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

  void _insert(TaxFiling f) {
    _db.raw.execute(
      'INSERT INTO tax_filings (id,book_id,period_key,period_kind,filed_at,note,'
      'created_at,updated_at,deleted_at,revision,device_id,base_revision) '
      'VALUES (?,?,?,?,?,?,?,?,?,?,?,?)',
      [
        f.id, f.bookId, f.periodKey, f.periodKind.wire,
        f.filedAt.millisecondsSinceEpoch, f.note,
        f.createdAt.millisecondsSinceEpoch, f.updatedAt.millisecondsSinceEpoch,
        f.deletedAt?.millisecondsSinceEpoch, f.revision, f.deviceId, f.baseRevision,
      ],
    );
  }

  TaxFiling _fromRow(Map<String, Object?> row) => TaxFiling(
        id: row['id']! as String,
        bookId: row['book_id']! as String,
        periodKey: row['period_key']! as String,
        periodKind: TaxPeriodKind.fromWire(row['period_kind'] as String?),
        filedAt: row.dateTime('filed_at'),
        note: row['note'] as String?,
        createdAt: row.dateTime('created_at'),
        updatedAt: row.dateTime('updated_at'),
        deletedAt: row.nullableDateTime('deleted_at'),
        revision: row.intOr('revision', 1),
        deviceId: row['device_id']! as String,
        baseRevision: row.intOr('base_revision', 0),
      );

  Map<String, Object?> _payload(TaxFiling f) => {
        'id': f.id,
        'book_id': f.bookId,
        'period_key': f.periodKey,
        'period_kind': f.periodKind.wire,
        'filed_at': f.filedAt.millisecondsSinceEpoch,
        // 备注也要同步：漏列会让对端静默丢掉这条信息（audit 2026-10-15）
        'note': f.note,
      };
}
