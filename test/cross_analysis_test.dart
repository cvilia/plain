/// STORY-11.3 交叉分析矩阵。
library;
import 'package:flutter_test/flutter_test.dart';
import 'package:plain/app/l10n/strings_core.dart';
import 'package:plain/data/db/database.dart';
import 'package:plain/data/repositories/saved_report_repository.dart';
import 'package:plain/data/sync/change_log_writer.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/entities/saved_report.dart';
import 'package:plain/domain/services/cross_analysis_service.dart';

void main() {
  const svc = CrossAnalysisService();
  const cats = {'food': '餐饮', 'life': '生活'};
  const accounts = {'acc-a': '工资卡', 'acc-b': '信用卡'};

  CrossEntry e({
    required int cents,
    required DateTime at,
    String? categoryId,
    String? accountId,
    String? note,
    bool isIncome = false,
  }) =>
      CrossEntry(
        cents: cents,
        at: at,
        isIncome: isIncome,
        categoryId: categoryId,
        accountId: accountId,
        note: note,
      );

  group('AC1 行=分类 列=月份', () {
    final entries = [
      e(cents: 10000, at: DateTime.utc(2026, 1, 5), categoryId: 'food'),
      e(cents: 20000, at: DateTime.utc(2026, 1, 20), categoryId: 'food'),
      e(cents: 5000, at: DateTime.utc(2026, 1, 10), categoryId: 'life'),
      e(cents: 30000, at: DateTime.utc(2026, 2, 5), categoryId: 'food'),
    ];

    test('单元格金额与笔数正确', () {
      final t = svc.build(
        entries: entries,
        rowDim: CrossDimension.category,
        colDim: CrossDimension.month,
        categoryNames: cats,
        monthStartDay: 1,
        s: kDefaultAppStrings,
      );
      expect(t.rowLabels, ['餐饮', '生活']); // 按行合计降序
      expect(t.colLabels, ['2026-01', '2026-02']);

      expect(t.cellAt('food', '2026-01')!.cents, 30000);
      expect(t.cellAt('food', '2026-01')!.count, 2);
      expect(t.cellAt('food', '2026-02')!.cents, 30000);
      expect(t.cellAt('life', '2026-01')!.cents, 5000);
      // 该单元格在另一个维度下不存在
      expect(t.cellAt('life', '2026-02'), isNull);
    });

    test('行列合计与总计正确', () {
      final t = svc.build(
        entries: entries,
        rowDim: CrossDimension.category,
        colDim: CrossDimension.month,
        categoryNames: cats,
        monthStartDay: 1,
        s: kDefaultAppStrings,
      );
      expect(t.rowTotals['food'], 60000);
      expect(t.rowTotals['life'], 5000);
      expect(t.colTotals['2026-01'], 35000);
      expect(t.colTotals['2026-02'], 30000);
      expect(t.grandTotalCents, 65000);
    });

    test('AC2 热力按最大单元格归一', () {
      final t = svc.build(
        entries: entries,
        rowDim: CrossDimension.category,
        colDim: CrossDimension.month,
        categoryNames: cats,
        monthStartDay: 1,
        s: kDefaultAppStrings,
      );
      expect(t.maxCellCents, 30000);
      expect(t.heatOf('food', '2026-01'), closeTo(1.0, 1e-9));
      expect(t.heatOf('life', '2026-01'), closeTo(5000 / 30000, 1e-9));
      expect(t.heatOf('life', '2026-02'), 0); // 无单元格
    });

    test('记账月起始日影响月份归属（G-1）', () {
      final t = svc.build(
        entries: [e(cents: 1000, at: DateTime.utc(2026, 1, 3), categoryId: 'food')],
        rowDim: CrossDimension.category,
        colDim: CrossDimension.month,
        categoryNames: cats,
        monthStartDay: 5, // 3 日 < 5 日 → 归上一个月,
        s: kDefaultAppStrings,
      );
      expect(t.colLabels, ['2025-12']);
    });
  });

  group('AC1 其它维度组合', () {
    test('分类 × 账户', () {
      final t = svc.build(
        entries: [
          e(cents: 10000, at: DateTime.utc(2026, 1, 5), categoryId: 'food', accountId: 'acc-b'),
          e(cents: 20000, at: DateTime.utc(2026, 1, 6), categoryId: 'food', accountId: 'acc-a'),
        ],
        rowDim: CrossDimension.category,
        colDim: CrossDimension.account,
        categoryNames: cats,
        accountNames: accounts,
        monthStartDay: 1,
        s: kDefaultAppStrings,
      );
      expect(t.colLabels, ['工资卡', '信用卡']); // 列标签（按列合计降序，此处并列按稳定序）
      expect(t.cellAt('food', 'acc-a')!.cents, 20000);
      expect(t.cellAt('food', 'acc-b')!.cents, 10000);
    });

    test('金额区间分档', () {
      final t = svc.build(
        entries: [
          e(cents: 5000, at: DateTime.utc(2026, 1, 5), categoryId: 'food'), // 50 元
          e(cents: 60000, at: DateTime.utc(2026, 1, 6), categoryId: 'food'), // 600 元
          e(cents: 600000, at: DateTime.utc(2026, 1, 7), categoryId: 'food'), // 6000 元
        ],
        rowDim: CrossDimension.category,
        colDim: CrossDimension.amountRange,
        categoryNames: cats,
        monthStartDay: 1,
        s: kDefaultAppStrings,
      );
      expect(t.colLabels,
          ['100 元以下', '500–1000 元', '5000 元及以上']);
      expect(t.cellAt('food', '0')!.cents, 5000);
      expect(t.cellAt('food', '2')!.cents, 60000);
      expect(t.cellAt('food', '4')!.cents, 600000);
    });

    test('商户维度沿用备注承载', () {
      final t = svc.build(
        entries: [
          e(cents: 10000, at: DateTime.utc(2026, 1, 5), categoryId: 'food', note: '星巴克'),
          e(cents: 20000, at: DateTime.utc(2026, 1, 6), categoryId: 'food', note: '星巴克'),
          e(cents: 30000, at: DateTime.utc(2026, 1, 7), categoryId: 'food'),
        ],
        rowDim: CrossDimension.merchant,
        colDim: CrossDimension.month,
        monthStartDay: 1,
        s: kDefaultAppStrings,
      );
      expect(t.rowLabels.first, '星巴克');
      expect(t.cellAt('星巴克', '2026-01')!.cents, 30000);
      expect(t.cellAt('星巴克', '2026-01')!.count, 2);
      expect(t.rowLabels.last, '未填商户');
    });
  });

  group('边界', () {
    test('未分类 / 未指定账户各有兜底标签', () {
      final t = svc.build(
        entries: [e(cents: 1000, at: DateTime.utc(2026, 1, 5))],
        rowDim: CrossDimension.category,
        colDim: CrossDimension.account,
        monthStartDay: 1,
        s: kDefaultAppStrings,
      );
      expect(t.rowLabels, ['未分类']);
      expect(t.colLabels, ['未指定账户']);
    });

    test('零与负金额不入表；空输入得到空表', () {
      final t = svc.build(
        entries: [e(cents: 0, at: DateTime.utc(2026, 1, 5), categoryId: 'food')],
        rowDim: CrossDimension.category,
        colDim: CrossDimension.month,
        monthStartDay: 1,
        s: kDefaultAppStrings,
      );
      expect(t.isEmpty, true);
      expect(t.grandTotalCents, 0);
      expect(t.heatOf('food', '2026-01'), 0);
    });

    test('收入与支出都可参与（由调用方决定传入哪些）', () {
      final t = svc.build(
        entries: [
          e(cents: 500000, at: DateTime.utc(2026, 1, 5), isIncome: true),
          e(cents: 10000, at: DateTime.utc(2026, 1, 6), categoryId: 'food'),
        ],
        rowDim: CrossDimension.category,
        colDim: CrossDimension.month,
        categoryNames: cats,
        monthStartDay: 1,
        s: kDefaultAppStrings,
      );
      expect(t.grandTotalCents, 510000);
      expect(t.cellAt('__none__', '2026-01')!.cents, 500000);
    });
  });

  group('AC4「我的报表」持久化', () {
    late AppDatabase db;
    late SavedReportRepositoryImpl repo;

    setUp(() {
      db = AppDatabase.inMemory();
      repo = SavedReportRepositoryImpl(
        db: db,
        changeLogWriter: ChangeLogWriter(db),
      );
    });
    tearDown(() => db.close());

    SavedReport make(String id, String name) => SavedReport(
          id: id,
          bookId: 'book-1',
          name: name,
          rowDim: CrossDimension.category,
          colDim: CrossDimension.account,
          fromMs: DateTime.utc(2026, 1, 1).millisecondsSinceEpoch,
          toMs: DateTime.utc(2026, 7, 1).millisecondsSinceEpoch,
          entryFilter: ReportEntryFilter.income,
          heatmap: false,
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1),
          deviceId: 'dev-1',
        );

    test('保存后可按账本读回，维度与筛选完整保留', () async {
      expect((await repo.create(make('r1', '餐饮 × 账户'))).isSuccess, true);

      final list = (await repo.listByBook('book-1')).successOrNull!;
      expect(list, hasLength(1));
      final r = list.single;
      expect(r.name, '餐饮 × 账户');
      expect(r.rowDim, CrossDimension.category);
      expect(r.colDim, CrossDimension.account);
      expect(r.entryFilter, ReportEntryFilter.income);
      expect(r.heatmap, false);
      expect(r.fromMs, DateTime.utc(2026, 1, 1).millisecondsSinceEpoch);
      expect(r.describe(kDefaultAppStrings), contains('分类'));
      expect(r.describe(kDefaultAppStrings), contains('账户'));
    });

    test('软删后不再出现在列表里', () async {
      await repo.create(make('r1', 'A'));
      await repo.create(make('r2', 'B'));
      expect((await repo.listByBook('book-1')).successOrNull, hasLength(2));
      await repo.softDelete('r1');
      final left = (await repo.listByBook('book-1')).successOrNull!;
      expect(left, hasLength(1));
      expect(left.single.name, 'B');
    });

    test('变更写入 change_log', () async {
      await repo.create(make('r1', 'A'));
      final rows = db.raw.select(
          "SELECT COUNT(*) AS c FROM change_log WHERE entity_type = 'saved_report'");
      expect(rows.first['c'], 1);
    });
  });
}
