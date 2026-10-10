/// STORY-6.2 分割交易用例。
library;

import 'package:plain/core/constants/app_constants.dart';
import 'package:plain/core/id/uuid_v7.dart';
import 'package:plain/core/money/money.dart';
import 'package:plain/core/result/result.dart';
import 'package:plain/core/time/clock.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/entities/ledger_entry.dart';
import 'package:plain/domain/repositories/repositories.dart';

class SplitItem {
  const SplitItem({required this.amountCents, this.categoryId, this.note});
  final int amountCents;
  final String? categoryId;
  final String? note;
}

/// 把一笔账单拆成父笔 + N 子笔。
class SplitEntryUseCase {
  SplitEntryUseCase({
    required LedgerRepository repository,
    required Clock clock,
    required UuidV7 idGen,
  })  : _repository = repository,
        _clock = clock,
        _idGen = idGen;

  final LedgerRepository _repository;
  final Clock _clock;
  final UuidV7 _idGen;

  Future<Result<List<LedgerEntry>>> call({
    required LedgerEntry parent,
    required List<SplitItem> items,
  }) async {
    if (items.length < SplitRules.minChildren ||
        items.length > SplitRules.maxChildren) {
      return err<List<LedgerEntry>>(const ValidationFailure(
          'split.child_count_invalid', 'count'));
    }
    final sum = items.fold<int>(0, (s, i) => s + i.amountCents);
    if (sum != parent.amount.cents) {
      return err<List<LedgerEntry>>(ValidationFailure(
        'split.amount_mismatch',
        'sum=$sum parent=${parent.amount.cents}',
      ));
    }
    for (final i in items) {
      if (i.amountCents <= 0) {
        return err<List<LedgerEntry>>(
            const ValidationFailure('split.child_amount_invalid', 'zero'));
      }
    }

    final now = _clock.now();
    final created = <LedgerEntry>[];

    // 父笔：置空分类，split_role=parent
    final updatedParent = parent.copyWith(
      splitRole: SplitRole.parent,
      clearCategoryId: true,
      updatedAt: now,
      revision: parent.revision + 1,
      baseRevision: parent.revision,
    );
    final parentRes = await _repository.update(updatedParent);
    final p = parentRes.failureOrNull;
    if (p != null) return err(p);
    created.add(parentRes.requireValue);

    for (final item in items) {
      final child = LedgerEntry(
        id: _idGen.generate(at: parent.occurredAt),
        bookId: parent.bookId,
        type: parent.type,
        amount: Money(item.amountCents),
        currency: parent.currency,
        categoryId: item.categoryId,
        accountId: parent.accountId,
        toAccountId: parent.toAccountId,
        occurredAt: parent.occurredAt,
        note: item.note ?? parent.note,
        source: parent.source,
        batchId: parent.batchId,
        splitRole: SplitRole.child,
        parentId: parent.id,
        createdAt: now,
        updatedAt: now,
        deviceId: parent.deviceId,
      );
      final res = await _repository.create(child);
      final f = res.failureOrNull;
      if (f != null) return err(f);
      created.add(res.requireValue);
    }
    return ok(created);
  }
}

/// 合并子笔回父笔，父笔恢复普通账单（分类提示用户补充）。
class MergeSplitUseCase {
  MergeSplitUseCase({
    required LedgerRepository repository,
    required Clock clock,
  })  : _repository = repository,
        _clock = clock;

  final LedgerRepository _repository;
  final Clock _clock;

  Future<Result<LedgerEntry>> call({required LedgerEntry parent}) async {
    if (!parent.isSplitParent) {
      return err<LedgerEntry>(
          const ValidationFailure('split.not_parent', 'role'));
    }
    final now = _clock.now();
    // 软删子笔
    final all = await _repository.listPage(
      filter: EntryFilter(bookId: parent.bookId),
      limit: 200,
    );
    final items = all.successOrNull?.items ?? const <LedgerEntry>[];
    for (final e in items) {
      if (e.parentId == parent.id && e.isSplitChild && !e.isDeleted) {
        await _repository.softDelete(e.id);
      }
    }
    final restored = parent.copyWith(
      splitRole: SplitRole.normal,
      clearParentId: true,
      clearCategoryId: true,
      updatedAt: now,
      revision: parent.revision + 1,
      baseRevision: parent.revision,
    );
    return _repository.update(restored);
  }
}
