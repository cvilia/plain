/// `daily_stats` 的**唯一维护实现**（账本仓储与分类仓储共用）。
///
/// 抽出来的原因：分类合并/删除改派会把账单从一个分类挪到另一个分类，
/// 这件事也必须同步维护按天统计 —— 原先分类仓储是裸 `UPDATE transactions`，
/// 金额就永久挂在旧分类上（报表分类汇总看不到这笔，巡检只比对条数也发现不了）。
/// 统计口径只能有一份实现，所以放在这里，谁都要调它。
library;

import 'package:plain/core/constants/app_constants.dart';
import 'package:plain/core/money/money.dart';
import 'package:plain/core/time/clock.dart';
import 'package:plain/data/db/database.dart';
import 'package:plain/data/db/row_x.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/entities/ledger_entry.dart';

/// `daily_stats` 行的唯一口径，与 [LedgerEntry.countsInCategoryStats] 一一对应：
/// 只统计收入/支出、排除对账调整、排除拆分父笔（父笔金额由子笔承担）、
/// 排除手动标记「不计入收支」的账单。
const String kStatsRowPredicate =
    "deleted_at IS NULL AND type IN ('expense','income') "
    "AND source <> 'reconcile' AND split_role <> 'parent' "
    'AND exclude_from_stats = 0';

/// `transactions` 行 → 实体（账本仓储与分类仓储共用，避免两套读法）。
LedgerEntry ledgerEntryFromRow(Map<String, Object?> row) => LedgerEntry(
      id: row['id']! as String,
      bookId: row['book_id']! as String,
      type: EntryType.fromWire(row['type'] as String?),
      amount: Money(row['amount_cents']! as int),
      currency: (row['currency'] as String?) ?? 'CNY',
      categoryId: row['category_id'] as String?,
      accountId: row['account_id'] as String?,
      toAccountId: row['to_account_id'] as String?,
      occurredAt: row.dateTime('occurred_at'),
      note: row['note'] as String?,
      source: EntrySource.fromWire(row['source'] as String?),
      batchId: row['batch_id'] as String?,
      splitRole: SplitRole.fromWire(row['split_role'] as String?),
      parentId: row['parent_id'] as String?,
      reimburseStatus: ReimburseStatus.fromWire(row['reimburse_status'] as String?),
      excludeFromStats: row.boolOr('exclude_from_stats'),
      originalAmountCents: row['original_amount_cents'] as int?,
      exchangeRate: row['exchange_rate_micro'] == null
          ? null
          : CurrencyRules.rateFromMicro(row['exchange_rate_micro']! as int),
      reconciledAt: row.nullableDateTime('reconciled_at'),
      memberId: row.containsKey('member_id') ? row['member_id'] as String? : null,
      createdAt: row.dateTime('created_at'),
      updatedAt: row.dateTime('updated_at'),
      deletedAt: row.nullableDateTime('deleted_at'),
      revision: row.intOr('revision', 1),
      deviceId: row['device_id']! as String,
      baseRevision: row.intOr('base_revision', 0),
    );

/// 按「本机日」算 day_key（与写入侧同一入口）。
String statsDayKeyOf(Clock clock, DateTime occurredAt) =>
    clock.localDayKey(occurredAt);

/// 加/减一行统计。父笔与对账调整不进统计（谓词与实体 getter 同源）。
void upsertDailyStatsRow(
  AppDatabase db, {
  required LedgerEntry entry,
  required bool isIncrement,
  required String dayKey,
  required int nowMs,
}) {
  if (!entry.countsInCategoryStats) return;
  final sign = isIncrement ? 1 : -1;
  final exp = entry.type == EntryType.expense ? entry.amount.cents * sign : 0;
  final inc = entry.type == EntryType.income ? entry.amount.cents * sign : 0;
  db.raw.execute(
    'INSERT INTO daily_stats (book_id,day_key,category_id,account_id,expense_cents,income_cents,tx_count,updated_at) VALUES (?,?,?,?,?,?,?,?) '
    'ON CONFLICT(book_id,day_key,category_id,account_id) DO UPDATE SET expense_cents=expense_cents+?,income_cents=income_cents+?,tx_count=tx_count+?,updated_at=?',
    [
      entry.bookId, dayKey, entry.categoryId ?? '', entry.accountId ?? '',
      exp, inc, sign, nowMs, exp, inc, sign, nowMs,
    ],
  );
}

/// 分类改派/合并：把这一行账单的分类统计从旧分类搬到 [toCategoryId]。
void moveStatsToCategory(
  AppDatabase db, {
  required LedgerEntry oldEntry,
  required String toCategoryId,
  required String dayKey,
  required int nowMs,
}) {
  upsertDailyStatsRow(db,
      entry: oldEntry, isIncrement: false, dayKey: dayKey, nowMs: nowMs);
  upsertDailyStatsRow(db,
      entry: oldEntry.copyWith(categoryId: toCategoryId),
      isIncrement: true,
      dayKey: dayKey,
      nowMs: nowMs);
}
