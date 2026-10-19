/// STORY-8.1 冲突中心的服务层：列出待裁决冲突 + 按用户选择落库。
library;

import 'dart:convert';

import 'package:plain/app/l10n/app_strings.dart';
import 'package:plain/core/result/result.dart';
import 'package:plain/core/time/clock.dart';
import 'package:plain/data/repositories/sync_conflict_repository.dart';
import 'package:plain/data/sync/sync_applier.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/entities/sync_conflict.dart';
import 'package:plain/domain/usecases/entry_usecases.dart';
import 'package:plain/app/l10n/strings_core.dart';

class SyncConflictService {
  SyncConflictService({
    required SyncConflictRepositoryImpl repository,
    required SyncApplier applier,
    required CreateEntryUseCase createEntry,
    required Clock clock,
    required String bookId,
    required String deviceId,
    AppStrings? strings,
  })  : _repository = repository,
        _applier = applier,
        _createEntry = createEntry,
        _clock = clock,
        _bookId = bookId,
        _deviceId = deviceId,
        _strings = strings ?? kDefaultAppStrings;

  final SyncConflictRepositoryImpl _repository;
  final SyncApplier _applier;
  final CreateEntryUseCase _createEntry;
  final Clock _clock;
  final String _bookId;
  final String _deviceId;
  final AppStrings _strings;

  Future<Result<List<SyncConflict>>> openConflicts() => _repository.listOpen(bookId: _bookId);

  Future<Result<int>> openCount() => _repository.countOpen(bookId: _bookId);

  /// 裁决。
  ///
  /// - 保留本机 / 保留远端：把对应快照强制写回（版本号推高，成为最后写入）
  /// - 都保留：先落远端，再把本机版本作为**冲突副本**另存一笔（账单才有意义）
  Future<Result<void>> resolve(SyncConflict conflict, ConflictResolution choice) async {
    switch (choice) {
      case ConflictResolution.keepLocal:
        final res = await _applySnapshot(conflict, local: true);
        if (res.isFailure) return res;
      case ConflictResolution.keepRemote:
        final res = await _applySnapshot(conflict, local: false);
        if (res.isFailure) return res;
      case ConflictResolution.keepBoth:
        final remote = await _applySnapshot(conflict, local: false);
        if (remote.isFailure) return remote;
        final copy = await _duplicateAsConflictCopy(conflict);
        if (copy.isFailure) return copy;
      case ConflictResolution.unresolved:
        return err(const ValidationFailure('sync.conflict_choice_required', 'choice'));
    }
    return _repository.resolve(conflict.id, choice, _clock.now());
  }

  Future<Result<void>> _applySnapshot(SyncConflict conflict, {required bool local}) async {
    final raw = local ? conflict.localPayload : conflict.remotePayload;
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return err(const ValidationFailure('sync.conflict_payload_bad', 'payload'));
    }
    if (decoded is! Map<String, Object?>) {
      return err(const ValidationFailure('sync.conflict_payload_bad', 'payload'));
    }
    return _applier.forceWrite(
      entityType: conflict.entityType,
      entityId: conflict.entityId,
      payload: decoded,
    );
  }

  /// 「都保留」：把本机那一版另存成一笔新账单（备注加「冲突副本」）。
  Future<Result<void>> _duplicateAsConflictCopy(SyncConflict conflict) async {
    if (conflict.entityType != 'transaction') {
      // 非账单实体复制一份没有业务含义，退化为「保留远端」
      return ok(null);
    }
    Object? decoded;
    try {
      decoded = jsonDecode(conflict.localPayload);
    } on FormatException {
      return err(const ValidationFailure('sync.conflict_payload_bad', 'payload'));
    }
    if (decoded is! Map<String, Object?>) {
      return err(const ValidationFailure('sync.conflict_payload_bad', 'payload'));
    }
    final p = decoded;
    final cents = (p['amount_cents'] as num?)?.toInt() ?? 0;
    if (cents <= 0) {
      return err(const ValidationFailure('sync.conflict_payload_bad', 'amount'));
    }
    final occurredMs = (p['occurred_at'] as num?)?.toInt();
    final note = (p['note'] as String?) ?? '';
    final res = await _createEntry(CreateEntryInput(
      amountExpression: (cents / 100).toStringAsFixed(2),
      type: EntryType.fromWire(p['type'] as String?),
      categoryId: (p['category_id'] as String?) ?? '',
      accountId: p['account_id'] as String?,
      toAccountId: p['to_account_id'] as String?,
      note: note.isEmpty ? '冲突副本' : '$note（冲突副本）',
      occurredAt: occurredMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(occurredMs, isUtc: true),
      bookId: _bookId,
      deviceId: _deviceId,
    ), s: _strings);
    if (res.isFailure) return err(res.failureOrNull!);
    return ok(null);
  }
}
