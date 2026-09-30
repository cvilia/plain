/// Change log writer. See 04-6.1, 08-5.4.
library;

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:plain/data/db/database.dart';
import 'package:plain/domain/entities/enums.dart';

class ChangeLogWriter {
  ChangeLogWriter(this._db);
  final AppDatabase _db;

  void write({
    required EntityType entityType, required String entityId, required ChangeOp op,
    required String deviceId, required int baseRevision,
    required Map<String, Object?> before, required Map<String, Object?> after,
    DateTime? changedAt,
  }) {
    final payload = jsonEncode({'before': before, 'after': after});
    final hash = sha256.convert(utf8.encode(payload)).toString();
    final at = changedAt ?? DateTime.now().toUtc();
    _db.raw.execute(
      'INSERT INTO change_log (entity_type,entity_id,op,device_id,base_revision,payload,payload_hash,changed_at) VALUES (?,?,?,?,?,?,?,?)',
      [entityType.wire, entityId, op.wire, deviceId, baseRevision, payload, hash, at.millisecondsSinceEpoch],
    );
  }
}

Map<String, Object?> entryPayload({
  required String id, required String bookId, required String type,
  required int amountCents, required String currency,
  String? categoryId, String? accountId, String? toAccountId,
  required int occurredAtMs, String? note, required String source,
  String? batchId,
  required int createdAtMs, required int updatedAtMs, int? deletedAtMs,
  required int revision, required String deviceId, required int baseRevision,
}) {
  return {
    'id': id, 'book_id': bookId, 'type': type, 'amount_cents': amountCents,
    'currency': currency, 'category_id': categoryId, 'account_id': accountId,
    'to_account_id': toAccountId, 'occurred_at': occurredAtMs, 'note': note,
    'source': source, 'batch_id': batchId, 'created_at': createdAtMs, 'updated_at': updatedAtMs,
    'deleted_at': deletedAtMs, 'revision': revision, 'device_id': deviceId,
    'base_revision': baseRevision,
  };
}
