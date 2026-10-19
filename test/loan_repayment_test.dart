/// STORY-10.2 AC4/AC5：贷款每期还款生成两笔（利息计入支出，本金不计入）。
library;
import 'package:flutter_test/flutter_test.dart';
import 'package:plain/app/l10n/strings_core.dart';
import 'package:plain/core/id/uuid_v7.dart';
import 'package:plain/core/time/clock.dart';
import 'package:plain/data/db/database.dart';
import 'package:plain/data/repositories/account_repository.dart';
import 'package:plain/data/repositories/ledger_repository.dart';
import 'package:plain/data/repositories/recurring_repository.dart';
import 'package:plain/data/sync/change_log_writer.dart';
import 'package:plain/domain/entities/category.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/entities/recurring_rule.dart';
import 'package:plain/domain/repositories/repositories.dart';
import 'package:plain/domain/services/loan_amortization_service.dart';
import 'package:plain/domain/usecases/loan_usecases.dart';
import 'package:plain/domain/usecases/recurring_usecases.dart';

void main() {
  late AppDatabase db;
  late FixedClock clock;
  late LedgerRepositoryImpl ledgerRepo;
  late AccountRepositoryImpl accountRepo;
  late RecurringRepositoryImpl recurringRepo;
  late UuidV7 idGen;

  const bookId = 'book-1';
  const deviceId = 'dev-1';

  setUp(() async {
    db = AppDatabase.inMemory();
    clock = FixedClock(DateTime.utc(2026, 2, 20, 9));
    idGen = UuidV7();
    final changeLog = ChangeLogWriter(db, clock: clock);
    ledgerRepo = LedgerRepositoryImpl(db: db, changeLogWriter: changeLog, clock: clock);
    accountRepo = AccountRepositoryImpl(db: db, changeLogWriter: changeLog, clock: clock);
    recurringRepo = RecurringRepositoryImpl(db: db, changeLogWriter: changeLog, clock: clock);

    // 还款来源账户
    await accountRepo.create(Account(
      id: 'acc-cash', name: '工资卡', type: AccountType.debit,
      currency: 'CNY', openingBalance: 10000000, sortOrder: 0,
      createdAt: clock.now(), updatedAt: clock.now(), deviceId: deviceId,
    ));
    // 贷款账户：期初 = −本金（欠款为负）
    await accountRepo.create(Account(
      id: 'acc-loan', name: '房贷', type: AccountType.loanIn,
      currency: 'CNY', openingBalance: -80000000, sortOrder: 1,
      loanPrincipalCents: 80000000,
      loanAnnualRateBp: 490,
      loanTermMonths: 360,
      loanRepayMethod: LoanRepayMethod.equalInstallment,
      loanFirstPaymentAt: DateTime.utc(2026, 2, 20),
      createdAt: clock.now(), updatedAt: clock.now(), deviceId: deviceId,
    ));
    // 利息分类
    db.raw.execute(
      "INSERT INTO categories (id,name,kind,icon_ref,sort_order,is_hidden,is_preset,created_at,updated_at,device_id) "
      "VALUES ('preset_housing_mortgage','房贷','expense','housing',0,0,1,0,0,'d')",
    );
  });

  tearDown(() => db.close());

  Future<RecurringRule> setupRule({bool autoConfirm = false}) async {
    final loan = (await accountRepo.getById('acc-loan')).successOrNull!;
    final r = await SetLoanRepaymentScheduleUseCase(
      recurringRepository: recurringRepo,
      clock: clock,
      idGen: idGen,
    ).call(
      loanAccount: loan,
      bookId: bookId,
      repayAccountId: 'acc-cash',
      interestCategoryId: 'preset_housing_mortgage',
      autoConfirm: autoConfirm,
    );
    expect(r.isSuccess, true, reason: r.failureOrNull?.toString() ?? '');
    return r.successOrNull!;
  }

  int statsExpenseCents() {
    final rows = db.raw.select(
        "SELECT COALESCE(SUM(expense_cents),0) AS s FROM daily_stats WHERE book_id = '$bookId'");
    return (rows.first['s'] as int?) ?? 0;
  }

  test('AC4: 规则锚定首次还款日、按期数结束、默认待确认', () async {
    final rule = await setupRule();
    expect(rule.kind, RecurringKind.loanRepayment);
    expect(rule.frequency, RecurringFrequency.monthly);
    expect(rule.anchorDay, 20);
    expect(rule.endType, RecurringEndType.count);
    expect(rule.endCount, 360);
    expect(rule.nextRunAt, DateTime.utc(2026, 2, 20));
    expect(rule.autoConfirm, false);
    // 转出端 = 还款账户，转入端 = 贷款账户
    expect(rule.accountId, 'acc-cash');
    expect(rule.toAccountId, 'acc-loan');

    // 待确认：到期也不自动入账
    final gen = await GenerateDueRecurringUseCase(
      recurringRepository: recurringRepo,
      ledgerRepository: ledgerRepo,
      clock: clock,
      idGen: idGen,
    )(s: kDefaultAppStrings);
    expect(gen.isSuccess, true);
    expect(gen.successOrNull!.created, isEmpty);
    expect(gen.successOrNull!.needConfirm, hasLength(1));
  });

  test('AC4: 确认后生成利息 + 本金两笔，同属一个批次', () async {
    final rule = await setupRule();
    final res = await ConfirmRecurringRuleUseCase(
      repository: recurringRepo,
      ledgerRepository: ledgerRepo,
      clock: clock,
      idGen: idGen,
      accountRepository: accountRepo,
    )(rule, s: kDefaultAppStrings);
    expect(res.isSuccess, true, reason: res.failureOrNull?.toString() ?? '');
    final entries = res.successOrNull!;
    expect(entries, hasLength(2));

    final interest = entries.firstWhere((e) => e.type == EntryType.expense);
    final principal = entries.firstWhere((e) => e.type == EntryType.transfer);

    // 首期利息 = 800000 × 4.9% / 12 = 3266.67
    expect(interest.amount.cents, 326667);
    expect(interest.categoryId, 'preset_housing_mortgage');
    // 本金 = 月供 − 利息
    final pay = const LoanAmortizationService()
        .equalInstallmentPaymentCents(LoanTerms.ofAccount(
            (await accountRepo.getById('acc-loan')).successOrNull!)!);
    expect(principal.amount.cents, pay - 326667);
    // 同批次
    expect(interest.batchId, isNotNull);
    expect(interest.batchId, principal.batchId);
    // 只有一笔进账本
    expect(entries.map((e) => e.id).toSet(), hasLength(2));
  });

  test('AC5: 支出只增利息，本金不计入；负债按本金减少', () async {
    final rule = await setupRule();
    await ConfirmRecurringRuleUseCase(
      repository: recurringRepo,
      ledgerRepository: ledgerRepo,
      clock: clock,
      idGen: idGen,
      accountRepository: accountRepo,
    )(rule, s: kDefaultAppStrings);

    // 支出统计 = 仅利息
    expect(statsExpenseCents(), 326667);

    // 贷款账户余额（负债）增加本金 → 欠款减少
    final loanBal = (await accountRepo.balanceOf('acc-loan')).successOrNull!;
    final principalPaid = loanBal.balanceCents - (-80000000);
    expect(principalPaid, greaterThan(0));
    // 还款账户按「利息 + 本金」合计减少
    final cashBal = (await accountRepo.balanceOf('acc-cash')).successOrNull!;
    expect(10000000 - cashBal.balanceCents, 326667 + principalPaid);

    // C11：口径一致
    expect((await ledgerRepo.verifyDailyStats()).successOrNull, true);
  });

  test('撤销批次会同批撤掉两笔', () async {
    final rule = await setupRule();
    final res = await ConfirmRecurringRuleUseCase(
      repository: recurringRepo,
      ledgerRepository: ledgerRepo,
      clock: clock,
      idGen: idGen,
      accountRepository: accountRepo,
    )(rule, s: kDefaultAppStrings);
    final batchId = res.successOrNull!.first.batchId!;

    final undo = await UndoRecurringBatchUseCase(
        repository: ledgerRepo, clock: clock)(batchId);
    expect(undo.isSuccess, true);
    expect(undo.successOrNull, 2);
    expect(statsExpenseCents(), 0);
  });

  test('第二期按摊销表取利息（逐期递减）', () async {
    var rule = await setupRule();
    final confirm = ConfirmRecurringRuleUseCase(
      repository: recurringRepo,
      ledgerRepository: ledgerRepo,
      clock: clock,
      idGen: idGen,
      accountRepository: accountRepo,
    );
    final first = await confirm(rule, s: kDefaultAppStrings);
    expect(first.successOrNull![0].amount.cents, 326667);

    // 推进到下一期
    rule = (await recurringRepo.getById(rule.id)).successOrNull!;
    clock.set(DateTime.utc(2026, 3, 20, 9));
    final second = await confirm(rule, s: kDefaultAppStrings);
    final interest2 = second.successOrNull!
        .firstWhere((e) => e.type == EntryType.expense)
        .amount
        .cents;
    // 等额本息下利息逐期递减
    expect(interest2, lessThan(326667));
    expect(statsExpenseCents(), 326667 + interest2);
  });

  test('AC2/AC3（7.2 还债目标）：剩余信息与提前还款测算全部来自贷款派生', () async {
    const svc = LoanAmortizationService();
    var rule = await setupRule();
    final confirm = ConfirmRecurringRuleUseCase(
      repository: recurringRepo,
      ledgerRepository: ledgerRepo,
      clock: clock,
      idGen: idGen,
      accountRepository: accountRepo,
    );
    // 已还 3 期
    for (var i = 0; i < 3; i++) {
      await confirm(rule, s: kDefaultAppStrings);
      rule = (await recurringRepo.getById(rule.id)).successOrNull!;
    }

    final loan = (await accountRepo.getById('acc-loan')).successOrNull!;
    final terms = LoanTerms.ofAccount(loan)!;
    final schedule = svc.schedule(terms);
    final bal = (await accountRepo.balanceOf('acc-loan')).successOrNull!;
    final remaining = -bal.balanceCents;

    // 已还期数由账本事实（本金转账笔数）得出，不写死
    final page = await ledgerRepo.listPage(
      filter: EntryFilter(accountId: 'acc-loan'),
      limit: 2000,
    );
    final paid = page.successOrNull!.items
        .where((e) =>
            !e.isDeleted &&
            e.type == EntryType.transfer &&
            e.toAccountId == 'acc-loan')
        .length;
    expect(paid, 3);

    final prog = svc.progress(
      schedule: schedule,
      remainingPrincipalCents: remaining,
      paidPeriods: paid,
    );
    // AC2：剩余期数 / 剩余利息 / 预计还清日
    expect(prog.remainingMonths, 357);
    expect(prog.remainingInterestCents, greaterThan(0));
    expect(prog.payoffDate, schedule.payoffDate);
    // 剩余本金确实减少了
    expect(prog.remainingPrincipalCents, lessThan(80000000));

    // AC3：追加一次性还款 10,000 → 提前 N 月、少付利息
    final r = svc.prepay(
      terms,
      extraMonthlyCents: 100000,
      lumpSumCents: 1000000,
    );
    expect(r.monthsSaved, greaterThan(0));
    expect(r.interestSavedCents, greaterThan(0));
    // 方案比基准更快还清
    expect(r.withExtra.payoffDate!.isBefore(r.baseline.payoffDate!), true);
  });
}
