/// 复现用户走查链路（2026-10-19）：全新库 → 记一笔支出 →
/// 流水列表应出现该笔、账户余额/资产合计应变化。
///
/// 用户报告「对账结束后资产合计没有变化 / 流水只有一条」。
/// 对账本身是「逐笔勾选，不改余额」（STORY-2.3），不参与余额计算；
/// 余额 = 期初 - 支出 + 收入 - 转出 + 转入 - 借出 + 借入，由账单实时派生。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:plain/app/l10n/strings_core.dart';
import 'package:plain/core/id/uuid_v7.dart';
import 'package:plain/core/time/clock.dart';
import 'package:plain/data/db/database.dart';
import 'package:plain/data/repositories/account_repository.dart';
import 'package:plain/data/repositories/ledger_repository.dart';
import 'package:plain/data/sync/change_log_writer.dart';
import 'package:plain/domain/entities/category.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/services/reconcile_mode_service.dart';
import 'package:plain/domain/usecases/entry_usecases.dart';

void main() {
  late AppDatabase db;
  late LedgerRepositoryImpl ledgerRepo;
  late AccountRepositoryImpl accountRepo;
  late CreateEntryUseCase createEntry;
  late FixedClock clock;

  setUp(() async {
    db = AppDatabase.inMemory();
    clock = FixedClock(DateTime.utc(2026, 10, 19, 4, 0));
    final changeLog = ChangeLogWriter(db, clock: clock);
    ledgerRepo = LedgerRepositoryImpl(db: db, changeLogWriter: changeLog, clock: clock);
    accountRepo = AccountRepositoryImpl(db: db, changeLogWriter: changeLog, clock: clock);
    createEntry = CreateEntryUseCase(repository: ledgerRepo, clock: clock, idGen: UuidV7());

    // 种子账户：现金 5000（与真机全新库的最小等价物）
    await accountRepo.create(Account(
      id: 'acc-cash', name: '现金', type: AccountType.cash,
      currency: 'CNY', openingBalance: 500000, sortOrder: 0,
      createdAt: clock.now(), updatedAt: clock.now(), deviceId: 'dev-1',
    ));
  });

  tearDown(() => db.close());

  test('记一笔 ¥27 午餐 → 流水 1 条，现金余额 -27；对账勾选不改余额', () async {
    final before = await accountRepo.listWithBalances();
    final totalBefore = before.successOrNull!.fold<int>(0, (s, a) => s + a.balanceCents);

    // 记一笔 ¥27 支出（不选账户 → 控制器会落第一个账户，这里直接给现金）
    final saved = await createEntry(CreateEntryInput(
      amountExpression: '27',
      type: EntryType.expense,
      categoryId: 'preset_food',
      accountId: 'acc-cash',
      bookId: 'book-1',
      deviceId: 'dev-1',
    ), s: kDefaultAppStrings);
    expect(saved.isSuccess, true, reason: saved.failureOrNull?.code);

    // 余额：现金应 5000 - 27 = 4973，资产合计同步变化
    final after = await accountRepo.listWithBalances();
    final list = after.successOrNull!;
    final totalAfter = list.fold<int>(0, (s, a) => s + a.balanceCents);
    expect(totalAfter, totalBefore - 2700,
        reason: '资产合计应减少 27.00，实际 $totalBefore → $totalAfter');
    expect(
      list.firstWhere((a) => a.account.id == 'acc-cash').balanceCents,
      497300,
    );

    // 流水：全新库应恰好 1 条
    final page = await ledgerRepo.listPage(limit: 50);
    expect(page.successOrNull!.items.length, 1);

    // 对账勾选不改余额（STORY-2.3 口径）
    final service = ReconcileModeService(repository: ledgerRepo, clock: clock);
    final entry = page.successOrNull!.items.first;
    final checked = await service.check(entry);
    expect(checked.isSuccess, true);
    final afterReconcile = await accountRepo.listWithBalances();
    expect(
      afterReconcile.successOrNull!
          .firstWhere((a) => a.account.id == 'acc-cash')
          .balanceCents,
      497300,
      reason: '对账不改变余额（设计口径）',
    );
  });
}
