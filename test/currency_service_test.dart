/// STORY-9.3 多币种：汇率换算、双显示、跨币种转账校验、锁定汇率持久化。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:plain/core/constants/app_constants.dart';
import 'package:plain/core/id/uuid_v7.dart';
import 'package:plain/core/time/clock.dart';
import 'package:plain/data/db/database.dart';
import 'package:plain/data/repositories/currency_rate_repository.dart';
import 'package:plain/data/repositories/ledger_repository.dart';
import 'package:plain/data/sync/change_log_writer.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/services/currency_service.dart';
import 'package:plain/domain/usecases/entry_usecases.dart';

void main() {
  const svc = CurrencyService();

  test('CurrencyRules symbols cover common currencies', () {
    expect(CurrencyRules.symbols.containsKey('CNY'), isTrue);
    expect(CurrencyRules.symbols.containsKey('USD'), isTrue);
    expect(CurrencyRules.symbolOf('CNY'), '¥');
    expect(CurrencyRules.symbolOf('USD'), r'$');
    expect(CurrencyRules.symbolOf('XYZ'), 'XYZ'); // unknown → code
  });

  test('CurrencyRules：symbols 与 names 两张表必须完全对齐', () {
    // 两张表分开维护，迟早会漏改一张。这里把它们钉死：
    // 加币种必须同时加符号和中文名，否则选择器里会出现空名或豆腐块。
    expect(
      CurrencyRules.names.keys.toSet(),
      CurrencyRules.symbols.keys.toSet(),
      reason: 'symbols 与 names 的 key 集合必须一致',
    );
    for (final code in CurrencyRules.symbols.keys) {
      expect(CurrencyRules.nameOf(code), isNot(code),
          reason: '$code 没有中文名');
      expect(CurrencyRules.nameOf(code), isNotEmpty,
          reason: '$code 的中文名为空');
    }
  });

  test('CurrencyRules：常用外币恰好 15 种，且都在列', () {
    const foreign = [
      'USD', 'EUR', 'GBP', 'JPY', 'HKD', 'MOP', 'TWD', 'KRW',
      'SGD', 'THB', 'MYR', 'AUD', 'NZD', 'CAD', 'CHF',
    ];
    final actual =
        CurrencyRules.symbols.keys.where((c) => c != 'CNY').toSet();
    // 外币清单是产品口径，不是"至少要有几个"，增减必须同步改这里。
    expect(actual, foreign.toSet());
    expect(actual.length, 15);
  });

  test('同币种换算恒等，不做任何折算', () {
    final r = svc.convert(
      originalCents: 12345,
      fromCurrency: 'CNY',
      toCurrency: 'CNY',
    );
    expect(r.convertedCents, 12345);
    expect(r.rate, 1.0);
    expect(r.isConverted, false);
    expect(r.dualDisplay, '¥123.45'); // 同币种只显示一次
  });

  test('用传入的锁定汇率换算（服务不再持有可变状态）', () {
    final r = svc.convert(
      originalCents: 10000, // $100
      fromCurrency: 'USD',
      toCurrency: 'CNY',
      lockedRates: const {'USD/CNY': 7.20},
    );
    expect(r.convertedCents, 72000); // ¥720
    expect(r.rate, 7.20);
    expect(r.dualDisplay, r'$100.00 ≈ ¥720.00');
  });

  test('这笔账单自带的汇率优先于锁定汇率', () {
    final r = svc.convert(
      originalCents: 10000,
      fromCurrency: 'USD',
      toCurrency: 'CNY',
      overrideRate: 6.90,
      lockedRates: const {'USD/CNY': 7.20},
    );
    expect(r.rate, 6.90);
    expect(r.convertedCents, 69000);
  });

  test('跨币种且没有任何汇率时给出 0，由调用方拦截而不是当成结果', () {
    final r = svc.convert(
      originalCents: 10000,
      fromCurrency: 'USD',
      toCurrency: 'CNY',
    );
    expect(r.rate, 0);
    expect(r.convertedCents, 0);
  });

  test('跨币种转账需填汇率与两边金额（AC3）', () {
    expect(
      svc.validateTransfer(
        fromCurrency: 'USD', toCurrency: 'CNY',
        rate: null, fromAmountCents: 10000, toAmountCents: 72000,
      ),
      '需填写两边金额与汇率',
    );
    expect(
      svc.validateTransfer(
        fromCurrency: 'USD', toCurrency: 'CNY',
        rate: 7.20, fromAmountCents: null, toAmountCents: 72000,
      ),
      '需填写两边金额与汇率',
    );
    expect(
      svc.validateTransfer(
        fromCurrency: 'USD', toCurrency: 'CNY',
        rate: 7.20, fromAmountCents: 10000, toAmountCents: 72000,
      ),
      isNull,
    );
    expect(
      svc.validateTransfer(
        fromCurrency: 'CNY', toCurrency: 'CNY',
        rate: null, fromAmountCents: null, toAmountCents: null,
      ),
      isNull,
    );
  });

  test('双显示格式', () {
    final r = svc.convert(
      originalCents: 1250,
      fromCurrency: 'USD',
      toCurrency: 'CNY',
      overrideRate: 7.12,
    );
    expect(r.originalDisplay, r'$12.50');
    expect(r.convertedDisplay, '¥89.00');
  });

  group('汇率以整数微单位入库（不引入浮点）', () {
    test('微单位往返保留 6 位小数', () {
      expect(CurrencyRules.rateToMicro(7.2), 7200000);
      expect(CurrencyRules.rateFromMicro(7203456), 7.203456);
      expect(CurrencyRules.rateFromMicro(CurrencyRules.rateToMicro(7.203456)),
          closeTo(7.203456, 1e-9));
    });

    late AppDatabase db;
    late CurrencyRateRepositoryImpl repo;

    setUp(() {
      db = AppDatabase.inMemory();
      repo = CurrencyRateRepositoryImpl(
        db: db,
        idGen: UuidV7(),
        clock: FixedClock(DateTime.utc(2026, 10, 15)),
      );
    });
    tearDown(() => db.close());

    test('设定后可读回，跨重启仍在（AC2 的前提）', () async {
      final set = await repo.setRate(
        bookId: 'book-1', fromCurrency: 'USD', toCurrency: 'CNY',
        rate: 7.203456, deviceId: 'dev-1',
      );
      expect(set.isSuccess, true);

      final list = (await repo.listByBook('book-1')).successOrNull!;
      expect(list, hasLength(1));
      expect(list.single.pairKey, 'USD/CNY');
      expect(list.single.rate, closeTo(7.203456, 1e-9));

      // 新开一个仓储实例（等价于重启后重新读库）
      final repo2 = CurrencyRateRepositoryImpl(db: db, idGen: UuidV7());
      final again = (await repo2.listByBook('book-1')).successOrNull!;
      expect(again.single.rate, closeTo(7.203456, 1e-9));
    });

    test('同一币种对重复设定是覆盖，不产生第二行', () async {
      await repo.setRate(
          bookId: 'book-1', fromCurrency: 'USD', toCurrency: 'CNY',
          rate: 7.20, deviceId: 'dev-1');
      await repo.setRate(
          bookId: 'book-1', fromCurrency: 'USD', toCurrency: 'CNY',
          rate: 6.95, deviceId: 'dev-1');
      final list = (await repo.listByBook('book-1')).successOrNull!;
      expect(list, hasLength(1));
      expect(list.single.rate, closeTo(6.95, 1e-9));
    });

    test('解除锁定后不再返回该币种对', () async {
      await repo.setRate(
          bookId: 'book-1', fromCurrency: 'USD', toCurrency: 'CNY',
          rate: 7.20, deviceId: 'dev-1');
      await repo.removeRate(
          bookId: 'book-1', fromCurrency: 'USD', toCurrency: 'CNY');
      expect((await repo.listByBook('book-1')).successOrNull, isEmpty);
    });

    test('非法汇率与同币种被拒', () async {
      expect(
        (await repo.setRate(
                bookId: 'book-1', fromCurrency: 'USD', toCurrency: 'CNY',
                rate: 0, deviceId: 'dev-1'))
            .isFailure,
        true,
      );
      expect(
        (await repo.setRate(
                bookId: 'book-1', fromCurrency: 'CNY', toCurrency: 'CNY',
                rate: 1, deviceId: 'dev-1'))
            .isFailure,
        true,
      );
    });
  });

  group('原币记账：入账时折算成本位币（AC1/AC2）', () {
    late AppDatabase db;
    late LedgerRepositoryImpl ledger;
    late CreateEntryUseCase createEntry;
    late FixedClock clock;

    setUp(() {
      db = AppDatabase.inMemory();
      clock = FixedClock(DateTime.utc(2026, 10, 15, 12));
      ledger = LedgerRepositoryImpl(
        db: db, changeLogWriter: ChangeLogWriter(db, clock: clock), clock: clock);
      createEntry = CreateEntryUseCase(
        repository: ledger, clock: clock, idGen: UuidV7());
    });
    tearDown(() => db.close());

    test('100 USD @7.20 → 本位币 720.00，原币与汇率都保留', () async {
      final r = await createEntry(CreateEntryInput(
        amountExpression: '100',
        type: EntryType.expense,
        categoryId: 'cat-food',
        accountId: 'acc-usd',
        bookId: 'book-1',
        deviceId: 'dev-1',
        exchangeRate: 7.20,
        originalCurrency: 'USD',
      ));
      expect(r.isSuccess, true, reason: r.failureOrNull?.toString() ?? '');
      final e = r.successOrNull!;
      // 本位币金额：所有统计口径都用它
      expect(e.amount.cents, 72000);
      expect(e.currency, MoneyRules.defaultCurrency);
      // 原币与锁定汇率
      expect(e.originalAmountCents, 10000);
      expect(e.exchangeRate, closeTo(7.20, 1e-9));

      // 落库后往返一致（汇率以整数微单位存）
      final back = (await ledger.getById(e.id)).successOrNull!;
      expect(back.originalAmountCents, 10000);
      expect(back.exchangeRate, closeTo(7.20, 1e-9));
      expect(back.amount.cents, 72000);
    });

    test('AC2：汇率锁定后，同一汇率算出的折算金额恒定', () async {
      Future<int> record(double rate) async {
        final r = await createEntry(CreateEntryInput(
          amountExpression: '100',
          type: EntryType.expense,
          categoryId: 'cat-food',
          accountId: 'acc-usd',
          bookId: 'book-1',
          deviceId: 'dev-1',
          exchangeRate: rate,
          originalCurrency: 'USD',
        ));
        return r.successOrNull!.amount.cents;
      }

      expect(await record(7.20), 72000);
      // 后来"市场变了"，但已锁的这笔仍按 7.20 折算（不会回溯改动）
      expect(await record(7.20), 72000);
      final rows = db.raw.select(
          'SELECT original_amount_cents, exchange_rate_micro FROM transactions');
      expect(rows, hasLength(2));
      expect(rows.every((r) => r['original_amount_cents'] == 10000), true);
      expect(rows.every((r) => r['exchange_rate_micro'] == 7200000), true);
    });

    test('本位币记账不带原币与汇率（不受多币种影响）', () async {
      final r = await createEntry(CreateEntryInput(
        amountExpression: '100',
        type: EntryType.expense,
        categoryId: 'cat-food',
        accountId: 'acc-cny',
        bookId: 'book-1',
        deviceId: 'dev-1',
      ));
      final e = r.successOrNull!;
      expect(e.amount.cents, 10000);
      expect(e.originalAmountCents, isNull);
      expect(e.exchangeRate, isNull);
    });

    test('折算后不足 1 分被拦下（金额列有 CHECK(>0)）', () async {
      final r = await createEntry(CreateEntryInput(
        amountExpression: '0.01', // 1 分
        type: EntryType.expense,
        categoryId: 'cat-food',
        accountId: 'acc-usd',
        bookId: 'book-1',
        deviceId: 'dev-1',
        exchangeRate: 0.4, // 1 × 0.4 = 0.4 → 四舍五入为 0 分
        originalCurrency: 'USD',
      ));
      expect(r.isFailure, true);
      expect(r.failureOrNull!.code, 'entry.amount_rounds_to_zero');
    });

    test('汇率非法（<=0）被拦下', () async {
      final r = await createEntry(CreateEntryInput(
        amountExpression: '100',
        type: EntryType.expense,
        categoryId: 'cat-food',
        accountId: 'acc-usd',
        bookId: 'book-1',
        deviceId: 'dev-1',
        exchangeRate: 0,
        originalCurrency: 'USD',
      ));
      expect(r.isFailure, true);
      expect(r.failureOrNull!.code, 'entry.fx_rate_invalid');
    });
  });
}
