/// Change log writer. See 04-6.1, 08-5.4.
library;

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:plain/core/constants/app_constants.dart';
import 'package:plain/core/time/clock.dart';
import 'package:plain/data/db/database.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/entities/ledger_entry.dart';

class ChangeLogWriter {
  ChangeLogWriter(this._db, {Clock? clock}) : _clock = clock ?? SystemClock();
  final AppDatabase _db;
  final Clock _clock;

  void write({
    required EntityType entityType, required String entityId, required ChangeOp op,
    required String deviceId, required int baseRevision,
    required Map<String, Object?> before, required Map<String, Object?> after,
    DateTime? changedAt,
  }) {
    final payload = jsonEncode({'before': before, 'after': after});
    final hash = sha256.convert(utf8.encode(payload)).toString();
    final at = changedAt ?? _clock.now();
    _db.raw.execute(
      'INSERT INTO change_log (entity_type,entity_id,op,device_id,base_revision,payload,payload_hash,changed_at) VALUES (?,?,?,?,?,?,?,?)',
      [entityType.wire, entityId, op.wire, deviceId, baseRevision, payload, hash, at.millisecondsSinceEpoch],
    );
  }
}

/// 账单的 change_log payload。
///
/// 字段须覆盖 `transactions` 表中所有**参与同步语义**的列：同步端拿到 before/after
/// 后要能重建同一行，漏列会让该列在跨端合并时静默丢失。
Map<String, Object?> entryPayload({
  required String id, required String bookId, required String type,
  required int amountCents, required String currency,
  String? categoryId, String? accountId, String? toAccountId,
  required int occurredAtMs, String? note, required String source,
  String? batchId,
  String? splitRole, String? parentId, String? reimburseStatus,
  bool excludeFromStats = false, int? reconciledAtMs,
  int? originalAmountCents, int? exchangeRateMicro,
  String? memberId,
  required int createdAtMs, required int updatedAtMs, int? deletedAtMs,
  required int revision, required String deviceId, required int baseRevision,
}) {
  return {
    'id': id, 'book_id': bookId, 'type': type, 'amount_cents': amountCents,
    'currency': currency, 'category_id': categoryId, 'account_id': accountId,
    'to_account_id': toAccountId, 'occurred_at': occurredAtMs, 'note': note,
    'source': source, 'batch_id': batchId,
    'split_role': splitRole, 'parent_id': parentId,
    'reimburse_status': reimburseStatus,
    'exclude_from_stats': excludeFromStats,
    'original_amount_cents': originalAmountCents,
    'exchange_rate_micro': exchangeRateMicro,
    'reconciled_at': reconciledAtMs,
    'member_id': memberId,
    'created_at': createdAtMs, 'updated_at': updatedAtMs,
    'deleted_at': deletedAtMs, 'revision': revision, 'device_id': deviceId,
    'base_revision': baseRevision,
  };
}

/// 账单实体 → 同步 payload（列形态）。账本仓储与分类仓储共用一份，
/// 避免「分类改派」这类旁路写出**部分列** payload（对端缺该行时插入必填列失败，
/// 会让整批 pull 失败且位点不推进）。
Map<String, Object?> ledgerEntryPayloadOf(LedgerEntry e) => entryPayload(
      id: e.id,
      bookId: e.bookId,
      type: e.type.wire,
      amountCents: e.amount.cents,
      currency: e.currency,
      categoryId: e.categoryId,
      accountId: e.accountId,
      toAccountId: e.toAccountId,
      occurredAtMs: e.occurredAt.millisecondsSinceEpoch,
      note: e.note,
      source: e.source.wire,
      batchId: e.batchId,
      splitRole: e.splitRole.wire,
      parentId: e.parentId,
      reimburseStatus: e.reimburseStatus.wire,
      excludeFromStats: e.excludeFromStats,
      originalAmountCents: e.originalAmountCents,
      exchangeRateMicro:
          e.exchangeRate == null ? null : CurrencyRules.rateToMicro(e.exchangeRate!),
      reconciledAtMs: e.reconciledAt?.millisecondsSinceEpoch,
      memberId: e.memberId,
      createdAtMs: e.createdAt.millisecondsSinceEpoch,
      updatedAtMs: e.updatedAt.millisecondsSinceEpoch,
      deletedAtMs: e.deletedAt?.millisecondsSinceEpoch,
      revision: e.revision,
      deviceId: e.deviceId,
      baseRevision: e.baseRevision,
    );
