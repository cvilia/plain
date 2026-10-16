/// STORY-11.5 税务 / 可抵扣支出报表。
library;
import 'package:flutter_test/flutter_test.dart';
import 'package:plain/data/db/database.dart';
import 'package:plain/data/repositories/tax_filing_repository.dart';
import 'package:plain/data/sync/change_log_writer.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/services/tax_service.dart';

void main() {
  const svc = TaxService();

  // office（可抵扣）→ office_supplies；food（不可抵扣）
  const cats = <String, TaxCategoryInfo>{
    'office': TaxCategoryInfo(name: '办公', isDeductible: true),
    'office_supplies': TaxCategoryInfo(
        name: '办公用品', isDeductible: false, parentId: 'office'),
    'food': TaxCategoryInfo(name: '餐饮', isDeductible: false),
  };

  TaxEntry e(int cents, DateTime at, String? cat) =>
      TaxEntry(cents: cents, at: at, categoryId: cat);

  group('AC1 可抵扣分类计入汇总', () {
    test('标了可抵扣的分类支出出现在报表里', () {
      final s = svc.summarize(
        entries: [
          e(30000, DateTime.utc(2026, 3, 10), 'office_supplies'),
          e(20000, DateTime.utc(2026, 3, 12), 'food'),
          e(15000, DateTime.utc(2026, 3, 15), 'office'),
        ],
        categories: cats,
        periodKey: '2026-03',
        monthStartDay: 1,
        isFiled: false,
      );
      // 餐饮不可抵扣，不计入
      expect(s.lines, hasLength(2));
      expect(s.totalCents, 45000);
      expect(s.totalCount, 2);
    });

    test('二级分类继承根分类的可抵扣标记', () {
      final s = svc.summarize(
        entries: [e(30000, DateTime.utc(2026, 3, 10), 'office_supplies')],
        categories: cats,
        periodKey: '2026-03',
        monthStartDay: 1,
        isFiled: false,
      );
      // office_supplies 自身没标，但其根 office 标了
      expect(svc.isDeductible('office_supplies', cats), true);
      expect(s.lines.single.name, '办公用品');
      expect(s.lines.single.cents, 30000);
    });

    test('都没标记时汇总为空', () {
      final s = svc.summarize(
        entries: [e(20000, DateTime.utc(2026, 3, 12), 'food')],
        categories: cats,
        periodKey: '2026-03',
        monthStartDay: 1,
        isFiled: false,
      );
      expect(s.isEmpty, true);
      expect(s.totalCents, 0);
      expect(svc.isDeductible('food', cats), false);
    });

    test('未分类的支出不计入', () {
      final s = svc.summarize(
        entries: [e(10000, DateTime.utc(2026, 3, 12), null)],
        categories: cats,
        periodKey: '2026-03',
        monthStartDay: 1,
        isFiled: false,
      );
      expect(s.isEmpty, true);
    });
  });

  group('AC2 按周期汇总', () {
    final entries = [
      e(10000, DateTime.utc(2026, 1, 10), 'office'),
      e(20000, DateTime.utc(2026, 3, 10), 'office'),
      e(40000, DateTime.utc(2025, 12, 10), 'office'),
    ];

    test('年度汇总把该自然年的都算进来', () {
      final s = svc.summarize(
        entries: entries,
        categories: cats,
        periodKey: '2026',
        monthStartDay: 1,
        isFiled: false,
      );
      expect(s.totalCents, 30000); // 2025-12 不算
      expect(s.totalCount, 2);
    });

    test('记账月汇总走 G-1 边界', () {
      // 月起始日 5：1 月 3 日的支出归 2025-12
      final s = svc.summarize(
        entries: [e(7000, DateTime.utc(2026, 1, 3), 'office')],
        categories: cats,
        periodKey: '2025-12',
        monthStartDay: 5,
        isFiled: false,
      );
      expect(s.totalCents, 7000);
      expect(
        TaxService.accountingMonthOf(DateTime.utc(2026, 1, 3), 5),
        '2025-12',
      );
    });

    test('行按金额降序', () {
      final s = svc.summarize(
        entries: [
          e(10000, DateTime.utc(2026, 3, 10), 'office'),
          e(50000, DateTime.utc(2026, 3, 11), 'office_supplies'),
        ],
        categories: cats,
        periodKey: '2026-03',
        monthStartDay: 1,
        isFiled: false,
      );
      expect(s.lines.first.name, '办公用品');
      expect(s.lines.first.cents, 50000);
    });

    test('周期选项含最近记账月与相关年度', () {
      final opts = TaxService.periodOptions(
        now: DateTime(2026, 3, 15),
        monthStartDay: 1,
        months: 3,
      );
      final keys = opts.map((o) => o.key).toList();
      expect(keys, containsAll(['2026-03', '2026-02', '2026-01']));
      expect(opts.any((o) => o.isYear && o.key == '2026'), true);
    });
  });

  group('AC3 已申报状态持久化', () {
    late AppDatabase db;
    late TaxFilingRepositoryImpl repo;

    setUp(() {
      db = AppDatabase.inMemory();
      repo = TaxFilingRepositoryImpl(
          db: db, changeLogWriter: ChangeLogWriter(db));
    });
    tearDown(() => db.close());

    test('标记后读回为已申报，取消后消失', () async {
      final r = await repo.markFiled(
        id: 'f1',
        bookId: 'book-1',
        periodKey: '2026-03',
        periodKind: TaxPeriodKind.month,
        deviceId: 'dev-1',
      );
      expect(r.isSuccess, true);

      final list = (await repo.listByBook('book-1')).successOrNull!;
      expect(list, hasLength(1));
      expect(list.single.periodKey, '2026-03');
      expect(list.single.periodKind, TaxPeriodKind.month);

      await repo.unmarkFiled('f1');
      expect((await repo.listByBook('book-1')).successOrNull, isEmpty);
    });

    test('申报状态写入 change_log', () async {
      await repo.markFiled(
        id: 'f1',
        bookId: 'book-1',
        periodKey: '2026',
        periodKind: TaxPeriodKind.year,
        deviceId: 'dev-1',
      );
      final rows = db.raw.select(
          "SELECT COUNT(*) AS c FROM change_log WHERE entity_type = 'tax_filing'");
      expect(rows.first['c'], 1);
    });
  });
}
