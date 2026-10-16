/// STORY-9.3 锁定汇率仓储。
///
/// **同步**（audit 2026-10-15 收口）：锁定汇率是**账本数据**——换一台设备后
/// 「原币 → 本位币」必须按同一汇率折算，否则同一个账本在两台设备上算出不同金额。
/// 因此这里写 change_log（整行 payload 形态，缺列会让该列在跨端合并时静默丢失）。
library;

import 'package:plain/core/constants/app_constants.dart';
import 'package:plain/core/id/uuid_v7.dart';
import 'package:plain/core/result/result.dart';
import 'package:plain/core/time/clock.dart';
import 'package:plain/data/db/database.dart';
import 'package:plain/data/db/row_x.dart';
import 'package:plain/data/sync/change_log_writer.dart';
import 'package:plain/domain/entities/currency_rate.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/repositories/repositories.dart';

class CurrencyRateRepositoryImpl implements CurrencyRateRepository {
  CurrencyRateRepositoryImpl({
    required AppDatabase db,
    required UuidV7 idGen,
    Clock? clock,
    ChangeLogWriter? changeLogWriter,
    String deviceId = '',
  })  : _db = db,
        _idGen = idGen,
        _clock = clock ?? SystemClock(),
        _changeLog = changeLogWriter,
        _deviceId = deviceId;

  final AppDatabase _db;
  final UuidV7 _idGen;
  final Clock _clock;
  final ChangeLogWriter? _changeLog;
  final String _deviceId;

  @override
  Future<Result<List<CurrencyRate>>> listByBook(String bookId) async {
    try {
      final rows = _db.raw.select(
        'SELECT * FROM currency_rates WHERE book_id = ? ORDER BY from_currency',
        [bookId],
      );
      return ok([for (final r in rows) _fromRow(r)]);
    } on Exception catch (e) {
      return err(StorageFailure('db.query_failed', e.toString(), isRetryable: true));
    }
  }

  @override
  Future<Result<CurrencyRate>> setRate({
    required String bookId,
    required String fromCurrency,
    required String toCurrency,
    required double rate,
    required String deviceId,
  }) async {
    if (rate <= 0) {
      return err<CurrencyRate>(
          const ValidationFailure('fx.rate_invalid', 'rate must be > 0'));
    }
    if (fromCurrency == toCurrency) {
      return err<CurrencyRate>(
          const ValidationFailure('fx.same_currency', 'same'));
    }
    try {
      final now = _clock.now();
      final before = _rowOf(bookId, fromCurrency, toCurrency);
      // 唯一索引按 (book_id, from_currency, to_currency)，存在则覆盖
      _db.raw.execute(
        'INSERT INTO currency_rates (id,book_id,from_currency,to_currency,rate_micro,'
        'updated_at,revision,device_id,base_revision) VALUES (?,?,?,?,?,?,?,?,?) '
        'ON CONFLICT(book_id, from_currency, to_currency) DO UPDATE SET '
        'rate_micro=excluded.rate_micro, updated_at=excluded.updated_at, '
        'revision=currency_rates.revision+1',
        [
          _idGen.generate(at: now), bookId, fromCurrency, toCurrency,
          CurrencyRules.rateToMicro(rate),
          now.millisecondsSinceEpoch, 1, deviceId, 0,
        ],
      );
      final rows = _db.raw.select(
        'SELECT * FROM currency_rates WHERE book_id = ? AND from_currency = ? AND to_currency = ?',
        [bookId, fromCurrency, toCurrency],
      );
      final saved = _fromRow(rows.first);
      _changeLog?.write(
        entityType: EntityType.currencyRate,
        entityId: saved.id,
        op: before == null ? ChangeOp.insert : ChangeOp.update,
        deviceId: _deviceId.isEmpty ? deviceId : _deviceId,
        baseRevision: before == null
            ? 0
            : _fromRow(before).revision,
        before: before == null ? const {} : _payload(_fromRow(before)),
        after: _payload(saved),
        changedAt: now,
      );
      return ok(saved);
    } on Exception catch (e) {
      return err(StorageFailure('db.insert_failed', e.toString(), isRetryable: true));
    }
  }

  @override
  Future<Result<void>> removeRate({
    required String bookId,
    required String fromCurrency,
    required String toCurrency,
  }) async {
    try {
      final rows = _db.raw.select(
        'SELECT * FROM currency_rates WHERE book_id = ? AND from_currency = ? AND to_currency = ?',
        [bookId, fromCurrency, toCurrency],
      );
      if (rows.isEmpty) {
        return err<void>(const NotFoundFailure('fx.not_locked', 'nf'));
      }
      final old = _fromRow(rows.first);
      final now = _clock.now();
      _db.raw.execute(
        'DELETE FROM currency_rates WHERE book_id = ? AND from_currency = ? AND to_currency = ?',
        [bookId, fromCurrency, toCurrency],
      );
      // 解除锁定也要跨端：否则对端仍按旧汇率折算（幽灵汇率）。
      // 注意：currency_rates 没有 deleted_at 列，同步端按**物理删除**处理
      // （见 ColumnWriter.deleteRow），不然这行会永远留在对端。
      _changeLog?.write(
        entityType: EntityType.currencyRate,
        entityId: old.id,
        op: ChangeOp.delete,
        deviceId: _deviceId.isEmpty ? old.deviceId : _deviceId,
        baseRevision: old.revision,
        before: _payload(old),
        after: const {},
        changedAt: now,
      );
      return ok(null);
    } on Exception catch (e) {
      return err(StorageFailure('db.delete_failed', e.toString(), isRetryable: true));
    }
  }

  Map<String, Object?>? _rowOf(String bookId, String from, String to) {
    final rows = _db.raw.select(
      'SELECT * FROM currency_rates WHERE book_id = ? AND from_currency = ? AND to_currency = ?',
      [bookId, from, to],
    );
    return rows.isEmpty ? null : rows.first;
  }

  CurrencyRate _fromRow(Map<String, Object?> row) => CurrencyRate(
        id: row['id']! as String,
        bookId: row['book_id']! as String,
        fromCurrency: row['from_currency']! as String,
        toCurrency: row['to_currency']! as String,
        rate: CurrencyRules.rateFromMicro(row.intOr('rate_micro', 0)),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
            row.intOr('updated_at', 0), isUtc: true),
        revision: row.intOr('revision', 1),
        deviceId: row['device_id']! as String,
        baseRevision: row.intOr('base_revision', 0),
      );

  /// 同步 payload：`currency_rates` 的**整行形态**（缺列 = 跨端静默丢列）。
  Map<String, Object?> _payload(CurrencyRate r) => {
        'id': r.id,
        'book_id': r.bookId,
        'from_currency': r.fromCurrency,
        'to_currency': r.toCurrency,
        'rate_micro': CurrencyRules.rateToMicro(r.rate),
        'updated_at': r.updatedAt.millisecondsSinceEpoch,
        'revision': r.revision,
        'device_id': r.deviceId,
        'base_revision': r.baseRevision,
      };
}
