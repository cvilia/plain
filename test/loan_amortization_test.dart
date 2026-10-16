/// STORY-10.2 贷款摊销与提前还款测算（纯派生）。
library;
import 'package:flutter_test/flutter_test.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/services/loan_amortization_service.dart';

void main() {
  const svc = LoanAmortizationService();

  // AC1 的贷款：本金 80 万、年利率 4.9%、360 期、等额本息
  final ac1 = LoanTerms(
    principalCents: 80000000,
    annualRateBp: 490,
    termMonths: 360,
    method: LoanRepayMethod.equalInstallment,
    firstPaymentAt: DateTime.utc(2026, 2, 20),
  );

  group('等额本息（AC1）', () {
    test('首期利息 = 本金 × 年利率 ÷ 12', () {
      // 800000 × 4.9% / 12 = 3266.666… → 326667 分
      expect(svc.interestForPeriod(80000000, 490), 326667);
    });

    test('每期还款额一致，末期后剩余本金为 0', () {
      final s = svc.schedule(ac1);
      expect(s.periods, hasLength(360));

      final pay = s.periods.first.paymentCents;
      // 除末期结清尾差外，月供恒定
      for (var i = 0; i < 359; i++) {
        expect(s.periods[i].paymentCents, pay, reason: '第 ${i + 1} 期月供应一致');
      }
      expect(s.periods.last.remainingCents, 0);
      // 本金合计 = 贷款总额
      final principalSum = s.periods.fold(0, (a, p) => a + p.principalCents);
      expect(principalSum, 80000000);
      // 首期利息占比高：利息递减、本金递增
      expect(s.periods.first.interestCents, greaterThan(s.periods.last.interestCents));
    });

    test('每期都还的是「利息 + 本金」', () {
      for (final p in svc.schedule(ac1).periods) {
        expect(p.paymentCents, p.interestCents + p.principalCents);
      }
    });
  });

  group('等额本金（AC3）', () {
    final terms = ac1.copyWith(method: LoanRepayMethod.equalPrincipal);

    test('每期本金一致，利息逐期递减', () {
      final s = svc.schedule(terms);
      expect(s.periods, hasLength(360));
      final base = s.periods.first.principalCents;
      for (var i = 0; i < 359; i++) {
        expect(s.periods[i].principalCents, base);
      }
      expect(s.periods.last.remainingCents, 0);
      for (var i = 1; i < s.periods.length; i++) {
        expect(s.periods[i].interestCents,
            lessThanOrEqualTo(s.periods[i - 1].interestCents));
      }
    });

    test('总利息少于等额本息，且月供逐期递减', () {
      final cmp = svc.compareMethods(ac1);
      expect(cmp.equalPrincipalCents, lessThan(cmp.equalInstallmentCents));
      final s = svc.schedule(terms);
      expect(s.periods.first.paymentCents,
          greaterThan(s.periods.last.paymentCents));
    });
  });

  group('提前还款测算（AC2 / AC6）', () {
    test('每月额外还 1000 元可提前还清且少付利息', () {
      final r = svc.prepay(
        ac1,
        extraMonthlyCents: 100000, // 1000 元
      );
      expect(r.baseline.months, 360);
      expect(r.withExtra.months, lessThan(360));
      expect(r.monthsSaved, greaterThan(0));
      expect(r.interestSavedCents, greaterThan(0));
      // 还清日提前
      expect(r.withExtra.payoffDate!.isBefore(r.baseline.payoffDate!), true);
    });

    test('期初一次性还款同样缩短期数', () {
      final r = svc.prepay(ac1, lumpSumCents: 10000000); // 10 万
      expect(r.monthsSaved, greaterThan(0));
      expect(r.interestSavedCents, greaterThan(0));
    });

    test('两种方案可并列比较（AC6）', () {
      final a = svc.prepay(ac1, extraMonthlyCents: 100000);
      final b = svc.prepay(ac1, lumpSumCents: 10000000);
      expect(a.monthsSaved, greaterThan(0));
      expect(b.monthsSaved, greaterThan(0));
      expect(a.interestSavedCents, greaterThan(0));
      expect(b.interestSavedCents, greaterThan(0));

      // 单位投入的效率：一次性还本钱更早到位，每元少付的利息更多。
      // 月供方案的投入总额 = 额外月供 × 实际还款期数。
      final monthlyTotalExtra = a.extraMonthlyCents * a.withExtra.months;
      final perYuanMonthly = a.interestSavedCents / monthlyTotalExtra;
      final perYuanLump = b.interestSavedCents / b.lumpSumCents;
      expect(perYuanLump, greaterThan(perYuanMonthly));
    });
  });

  group('边界', () {
    test('0 利率：月供 = 本金 ÷ 期数，总利息为 0', () {
      final t = ac1.copyWith(annualRateBp: 0, termMonths: 10);
      final s = svc.schedule(t);
      expect(s.totalInterestCents, 0);
      expect(s.periods.first.paymentCents, 8000000);
      expect(s.periods.last.remainingCents, 0);
    });

    test('首次还款日在 31 号：短月顺延至月末（G-4）', () {
      final t = ac1.copyWith(
        termMonths: 3,
        firstPaymentAt: DateTime.utc(2026, 1, 31),
      );
      final s = svc.schedule(t);
      expect(s.periods[0].dueDate, DateTime.utc(2026, 1, 31));
      // 2 月没有 31 号 → 顺延到 2 月末
      expect(s.periods[1].dueDate, DateTime.utc(2026, 2, 28));
      expect(s.periods[2].dueDate, DateTime.utc(2026, 3, 31));
    });

    test('参数不全时给出空表而不是抛错', () {
      final bad = ac1.copyWith(termMonths: 0);
      expect(svc.schedule(bad).isEmpty, true);
      final unknown = ac1.copyWith(method: LoanRepayMethod.unknown);
      expect(svc.schedule(unknown).isEmpty, true);
    });

    test('剩余本金反推剩余期数（7.2 还债目标复用）', () {
      // 已还 24 期后，剩余期数/剩余利息/还清日应精确等于摊销表尾部
      final s = svc.schedule(ac1);
      final rest = svc.remainingFromSchedule(s, nextIndex: 25);
      expect(rest.months, 336);
      expect(rest.payoffDate, s.periods.last.dueDate);
      expect(rest.interestCents, greaterThan(0));
      // 剩余利息必然小于总利息
      expect(rest.interestCents, lessThan(s.totalInterestCents));
    });

    test('模拟法用于提前还款：同等条件下期数不增加', () {
      // 不额外还款时，模拟的剩余期数不超过计划期数（四舍五入只可能多算 1 期）
      final rest = svc.remainingFrom(
        terms: ac1,
        remainingPrincipalCents: 80000000,
        nextIndex: 1,
      );
      expect(rest.months, lessThanOrEqualTo(361));
      expect(rest.interestCents, greaterThan(0));
    });
  });
}
