/// STORY-10.2 贷款摊销与提前还款测算。
///
/// **纯派生，不落库**（《08》§10.1）：摊销表完全由贷款参数算出，
/// 仓库里只存参数，不存每期数字——避免「参数改了但表没跟着改」的双份真相。
///
/// 金额一律用 int64「分」；利率用**基点**（bp，1bp = 0.01%）的整数表达，
/// 避免浮点累积误差（4.9% = 490bp）。
library;

import 'dart:math' as math;

import 'package:plain/domain/entities/category.dart';
import 'package:plain/domain/entities/enums.dart';

/// 贷款参数（来自贷款账户）。
class LoanTerms {
  const LoanTerms({
    required this.principalCents,
    required this.annualRateBp,
    required this.termMonths,
    required this.method,
    required this.firstPaymentAt,
  });

  /// 贷款总额（分）。
  final int principalCents;

  /// 年利率，基点（490 = 4.9%）。
  final int annualRateBp;

  /// 期数（月）。
  final int termMonths;

  final LoanRepayMethod method;

  /// 首次还款日（UTC）。
  final DateTime firstPaymentAt;

  bool get isUsable =>
      principalCents > 0 &&
      termMonths > 0 &&
      method != LoanRepayMethod.unknown;

  /// 从贷款账户读取参数；非贷款或未配置齐全时返回 null。
  static LoanTerms? ofAccount(Account account) {
    final term = account.loanTermMonths;
    final first = account.loanFirstPaymentAt;
    if (account.loanPrincipalCents <= 0 || term == null || term <= 0 || first == null) {
      return null;
    }
    return LoanTerms(
      principalCents: account.loanPrincipalCents,
      annualRateBp: account.loanAnnualRateBp,
      termMonths: term,
      method: LoanRepayMethod.fromWire(account.loanRepayMethod?.wire),
      firstPaymentAt: first,
    );
  }

  LoanTerms copyWith({
    int? principalCents,
    int? annualRateBp,
    int? termMonths,
    LoanRepayMethod? method,
    DateTime? firstPaymentAt,
  }) =>
      LoanTerms(
        principalCents: principalCents ?? this.principalCents,
        annualRateBp: annualRateBp ?? this.annualRateBp,
        termMonths: termMonths ?? this.termMonths,
        method: method ?? this.method,
        firstPaymentAt: firstPaymentAt ?? this.firstPaymentAt,
      );
}

/// 摊销表的一期。
class LoanPeriod {
  const LoanPeriod({
    required this.index,
    required this.dueDate,
    required this.paymentCents,
    required this.interestCents,
    required this.principalCents,
    required this.remainingCents,
  });

  /// 期号（1-based）。
  final int index;
  final DateTime dueDate;

  /// 本期应还合计 = 利息 + 本金。
  final int paymentCents;
  final int interestCents;
  final int principalCents;

  /// 本期结束后的剩余本金。
  final int remainingCents;
}

/// 完整摊销计划（AC1/AC3）。
class LoanSchedule {
  const LoanSchedule({required this.terms, required this.periods});

  final LoanTerms terms;
  final List<LoanPeriod> periods;

  bool get isEmpty => periods.isEmpty;
  int get totalInterestCents =>
      periods.fold(0, (s, p) => s + p.interestCents);
  int get totalPaymentCents => periods.fold(0, (s, p) => s + p.paymentCents);
  DateTime? get payoffDate => periods.isEmpty ? null : periods.last.dueDate;
}

/// 「还剩多少」的通用结果：提前还款测算与还债目标共用。
class LoanRemaining {
  const LoanRemaining({
    required this.months,
    required this.interestCents,
    required this.payoffDate,
    required this.totalPaymentCents,
  });

  /// 还需还款期数。
  final int months;

  /// 剩余利息合计。
  final int interestCents;
  final DateTime? payoffDate;
  final int totalPaymentCents;

  static const LoanRemaining none = LoanRemaining(
    months: 0, interestCents: 0, payoffDate: null, totalPaymentCents: 0);
}

/// 提前还款测算结果（AC2/AC6）。
class LoanPrepaymentResult {
  const LoanPrepaymentResult({
    required this.baseline,
    required this.withExtra,
    required this.extraMonthlyCents,
    required this.lumpSumCents,
  });

  final LoanRemaining baseline;
  final LoanRemaining withExtra;
  final int extraMonthlyCents;
  final int lumpSumCents;

  /// 可提前还清的月数。
  int get monthsSaved =>
      baseline.months - withExtra.months > 0 ? baseline.months - withExtra.months : 0;

  /// 少付的利息。
  int get interestSavedCents {
    final d = baseline.interestCents - withExtra.interestCents;
    return d > 0 ? d : 0;
  }
}

/// 贷款当前进度（STORY-10.2 → 7.2 还债目标共用）。
class LoanProgress {
  const LoanProgress({
    required this.paidPeriods,
    required this.totalPeriods,
    required this.remainingPrincipalCents,
    required this.remainingInterestCents,
    required this.remainingMonths,
    required this.payoffDate,
    required this.nextPaymentCents,
  });

  final int paidPeriods;
  final int totalPeriods;
  final int remainingPrincipalCents;
  final int remainingInterestCents;
  final int remainingMonths;
  final DateTime? payoffDate;

  /// 下一期应还（贷款已结清时为 0）。
  final int nextPaymentCents;

  bool get isSettled => remainingPrincipalCents <= 0;
}

class LoanAmortizationService {
  const LoanAmortizationService();

  /// 每期利息 = 期初剩余本金 × 年利率 ÷ 12。
  ///
  /// 用整数分运算（`remaining × bp ÷ 120000`，四舍五入），不用浮点累积。
  int interestForPeriod(int remainingCents, int annualRateBp) {
    if (remainingCents <= 0 || annualRateBp <= 0) return 0;
    return (remainingCents * annualRateBp / 120000).round();
  }

  /// 等额本息的月供：P·r·(1+r)^n / ((1+r)^n − 1)。
  int equalInstallmentPaymentCents(LoanTerms terms) {
    final p = terms.principalCents;
    final n = terms.termMonths;
    if (p <= 0 || n <= 0) return 0;
    if (terms.annualRateBp <= 0) return (p / n).ceil();
    final r = terms.annualRateBp / 120000.0;
    final factor = math.pow(1 + r, n).toDouble();
    if (factor <= 1) return (p / n).ceil();
    return (p * r * factor / (factor - 1)).round();
  }

  /// 生成完整摊销计划（AC1 等额本息 / AC3 等额本金）。
  LoanSchedule schedule(LoanTerms terms) {
    if (!terms.isUsable) {
      return LoanSchedule(terms: terms, periods: const []);
    }
    final periods = terms.method == LoanRepayMethod.equalPrincipal
        ? _buildEqualPrincipal(terms)
        : _buildEqualInstallment(terms);
    return LoanSchedule(terms: terms, periods: periods);
  }

  List<LoanPeriod> _buildEqualInstallment(LoanTerms terms) {
    final n = terms.termMonths;
    final pay = equalInstallmentPaymentCents(terms);
    final out = <LoanPeriod>[];
    var remaining = terms.principalCents;
    for (var i = 1; i <= n; i++) {
      final interest = interestForPeriod(remaining, terms.annualRateBp);
      var principal = pay - interest;
      var payment = pay;
      // 末期结清余额；月供不足以覆盖利息时也用余额兜底，避免出现负本金
      if (i == n || principal >= remaining) {
        principal = remaining;
        payment = principal + interest;
      }
      remaining -= principal;
      out.add(LoanPeriod(
        index: i,
        dueDate: _dueDate(terms.firstPaymentAt, i),
        paymentCents: payment,
        interestCents: interest,
        principalCents: principal,
        remainingCents: remaining,
      ));
    }
    return out;
  }

  List<LoanPeriod> _buildEqualPrincipal(LoanTerms terms) {
    final n = terms.termMonths;
    final base = terms.principalCents ~/ n;
    final out = <LoanPeriod>[];
    var remaining = terms.principalCents;
    for (var i = 1; i <= n; i++) {
      final interest = interestForPeriod(remaining, terms.annualRateBp);
      final principal = i == n ? remaining : base;
      remaining -= principal;
      out.add(LoanPeriod(
        index: i,
        dueDate: _dueDate(terms.firstPaymentAt, i),
        paymentCents: principal + interest,
        interestCents: interest,
        principalCents: principal,
        remainingCents: remaining,
      ));
    }
    return out;
  }

  /// 从 [nextIndex] 期起（剩余本金 [remainingPrincipalCents]）继续摊销，
  /// 给出还需期数 / 剩余利息 / 还清日。
  ///
  /// [extraMonthlyCents] 为每月额外还款，月供金额不变、多还的部分全部冲本金，
  /// 因此期数缩短——这正是提前还款测算的口径（AC2）。
  LoanRemaining remainingFrom({
    required LoanTerms terms,
    required int remainingPrincipalCents,
    required int nextIndex,
    int extraMonthlyCents = 0,
  }) {
    if (remainingPrincipalCents <= 0 || terms.method == LoanRepayMethod.unknown) {
      return LoanRemaining(
        months: 0,
        interestCents: 0,
        payoffDate: null,
        totalPaymentCents: 0,
      );
    }
    final extra = extraMonthlyCents > 0 ? extraMonthlyCents : 0;
    final isEqualPrincipal = terms.method == LoanRepayMethod.equalPrincipal;
    final fixedPayment = equalInstallmentPaymentCents(terms);
    final basePrincipal = terms.termMonths > 0
        ? terms.principalCents ~/ terms.termMonths
        : remainingPrincipalCents;

    var remaining = remainingPrincipalCents;
    var interest = 0;
    var payments = 0;
    // 理论上限：原期数 + 额外月供可能拉长的余量，防止死循环
    final guardLimit = terms.termMonths + 1200;
    while (remaining > 0 && payments < guardLimit) {
      final periodInterest = interestForPeriod(remaining, terms.annualRateBp);
      var principal = isEqualPrincipal
          ? basePrincipal + extra
          : fixedPayment + extra - periodInterest;
      if (principal <= 0) {
        // 月供不足以覆盖利息：本金永远还不完，按「无法还清」返回已算部分
        break;
      }
      if (principal > remaining) principal = remaining;
      interest += periodInterest;
      remaining -= principal;
      payments++;
    }
    return LoanRemaining(
      months: payments,
      interestCents: interest,
      payoffDate: payments == 0 ? null : _dueDate(terms.firstPaymentAt, nextIndex + payments - 1),
      totalPaymentCents: remainingPrincipalCents + interest,
    );
  }

  /// 从摊销表的第 [nextIndex] 期（1-based）起截取剩余部分。
  ///
  /// 与 [remainingFrom] 的区别：本方法**直接读表**，不存在逐期模拟的
  /// 四舍五入漂移，因此「按计划还款」的基准值必须用它（模拟会多出 1 期）。
  /// 已知当前剩余本金时用它最准（例如还债目标显示剩余期数/剩余利息）。
  LoanRemaining remainingFromSchedule(
    LoanSchedule schedule, {
    required int nextIndex,
  }) {
    final tail = schedule.periods.where((p) => p.index >= nextIndex).toList();
    if (tail.isEmpty) return LoanRemaining.none;
    return LoanRemaining(
      months: tail.length,
      interestCents: tail.fold(0, (s, p) => s + p.interestCents),
      payoffDate: tail.last.dueDate,
      totalPaymentCents: tail.fold(0, (s, p) => s + p.paymentCents),
    );
  }

  /// 提前还款测算（AC2 / AC6）。
  ///
  /// [extraMonthlyCents]：每月额外还款；[lumpSumCents]：期初一次性还款。
  /// 两者可同时给出。基准值取摊销表尾部（精确），提前方案则必须模拟。
  LoanPrepaymentResult prepay(
    LoanTerms terms, {
    int extraMonthlyCents = 0,
    int lumpSumCents = 0,
  }) {
    final baseline = remainingFromSchedule(schedule(terms), nextIndex: 1);
    final lump = lumpSumCents.clamp(0, terms.principalCents);
    final withExtra = remainingFrom(
      terms: terms,
      remainingPrincipalCents: terms.principalCents - lump,
      nextIndex: 1,
      extraMonthlyCents: extraMonthlyCents,
    );
    return LoanPrepaymentResult(
      baseline: baseline,
      withExtra: withExtra,
      extraMonthlyCents: extraMonthlyCents < 0 ? 0 : extraMonthlyCents,
      lumpSumCents: lump,
    );
  }

  /// 两种还款方式的总利息对比（AC3 / AC6）。
  ({int equalInstallmentCents, int equalPrincipalCents}) compareMethods(
    LoanTerms terms,
  ) => (
    equalInstallmentCents:
        schedule(terms.copyWith(method: LoanRepayMethod.equalInstallment))
            .totalInterestCents,
    equalPrincipalCents:
        schedule(terms.copyWith(method: LoanRepayMethod.equalPrincipal))
            .totalInterestCents,
  );

  /// 当前贷款进度。
  ///
  /// [remainingPrincipalCents] 是**实测剩余本金**（取贷款账户余额的相反数）。
  /// [paidPeriods] 是已还期数（由该贷款已入账的本金还款笔数得出）。
  ///
  /// 优先用摊销表尾部（精确无漂移）；若实测剩余本金与计划值不符
  /// （用户提前还款过），则退回逐期模拟，从实际余额继续算。
  LoanProgress progress({
    required LoanSchedule schedule,
    required int remainingPrincipalCents,
    required int paidPeriods,
  }) {
    final total = schedule.periods.length;
    final paid = paidPeriods.clamp(0, total);
    if (remainingPrincipalCents <= 0 || paid >= total) {
      return LoanProgress(
        paidPeriods: paid,
        totalPeriods: total,
        remainingPrincipalCents: remainingPrincipalCents > 0 ? remainingPrincipalCents : 0,
        remainingInterestCents: 0,
        remainingMonths: 0,
        payoffDate: null,
        nextPaymentCents: 0,
      );
    }

    // 已还 paid 期后的计划剩余本金：paid=0 时即贷款总额，否则是第 paid 期期末
    final planned = paid == 0
        ? schedule.terms.principalCents
        : schedule.periods[paid - 1].remainingCents;
    // 与计划一致（容忍 1 分舍入）→ 直接用表尾
    if ((planned - remainingPrincipalCents).abs() <= 1) {
      final tail = remainingFromSchedule(schedule, nextIndex: paid + 1);
      return LoanProgress(
        paidPeriods: paid,
        totalPeriods: total,
        remainingPrincipalCents: remainingPrincipalCents,
        remainingInterestCents: tail.interestCents,
        remainingMonths: tail.months,
        payoffDate: tail.payoffDate,
        nextPaymentCents: schedule.periods[paid].paymentCents,
      );
    }

    // 实际余额与计划不符 → 从实测余额继续模拟
    final sim = remainingFrom(
      terms: schedule.terms,
      remainingPrincipalCents: remainingPrincipalCents,
      nextIndex: paid + 1,
    );
    return LoanProgress(
      paidPeriods: paid,
      totalPeriods: total,
      remainingPrincipalCents: remainingPrincipalCents,
      remainingInterestCents: sim.interestCents,
      remainingMonths: sim.months,
      payoffDate: sim.payoffDate,
      nextPaymentCents: isEqualPrincipalMethod(schedule.terms)
          ? _equalPrincipalNextPayment(schedule.terms, remainingPrincipalCents)
          : equalInstallmentPaymentCents(schedule.terms),
    );
  }

  bool isEqualPrincipalMethod(LoanTerms terms) =>
      terms.method == LoanRepayMethod.equalPrincipal;

  int _equalPrincipalNextPayment(LoanTerms terms, int remainingCents) {
    final base = terms.termMonths > 0
        ? terms.principalCents ~/ terms.termMonths
        : remainingCents;
    final principal = base > remainingCents ? remainingCents : base;
    return principal + interestForPeriod(remainingCents, terms.annualRateBp);
  }

  /// 第 [index] 期（1-based）的到期日。短月顺延至月末（G-4）。
  DateTime _dueDate(DateTime first, int index) {
    final y = first.year;
    final m = first.month + (index - 1);
    final lastDay = DateTime.utc(y, m + 1, 0).day;
    final day = first.day > lastDay ? lastDay : first.day;
    return DateTime.utc(y, m, day);
  }
}
