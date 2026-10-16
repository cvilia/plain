/// STORY-7.2 目标体系 · 限额目标（AC4：复用分类预算，不产生第二套数据）。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:plain/core/id/uuid_v7.dart';
import 'package:plain/core/money/money.dart';
import 'package:plain/core/time/clock.dart';
import 'package:plain/data/db/database.dart';
import 'package:plain/data/repositories/account_repository.dart';
import 'package:plain/data/repositories/budget_repository.dart';
import 'package:plain/data/repositories/category_repository.dart';
import 'package:plain/data/repositories/ledger_repository.dart';
import 'package:plain/data/sync/change_log_writer.dart';
import 'package:plain/domain/entities/budget.dart';
import 'package:plain/domain/entities/category.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/services/goal_system_service.dart';
import 'package:plain/domain/usecases/entry_usecases.dart';

void main() {
  const bookId = 'book-1';
  const deviceId = 'dev-1';

  late AppDatabase db;
  late FixedClock clock;
  late BudgetRepositoryImpl budgetRepo;
  late CategoryRepositoryImpl categoryRepo;
  late LedgerRepositoryImpl ledgerRepo;
  late CreateEntryUseCase createEntry;
  late GoalSystemService service;

  setUp(() async {
    db = AppDatabase.inMemory();
    clock = FixedClock(DateTime.utc(2026, 10, 15, 12));
    final changeLog = ChangeLogWriter(db, clock: clock);
    final idGen = UuidV7();
    budgetRepo = BudgetRepositoryImpl(db: db, changeLogWriter: changeLog, clock: clock);
    categoryRepo = CategoryRepositoryImpl(db: db, changeLogWriter: changeLog, clock: clock);
    ledgerRepo = LedgerRepositoryImpl(db: db, changeLogWriter: changeLog, clock: clock);
    createEntry = CreateEntryUseCase(repository: ledgerRepo, clock: clock, idGen: idGen);
    service = GoalSystemService(budgets: budgetRepo, idGen: idGen, clock: clock);

    final accountRepo = AccountRepositoryImpl(db: db, changeLogWriter: changeLog, clock: clock);
    await accountRepo.create(Account(
      id: 'acc-cash', name: '现金', type: AccountType.cash,
      currency: 'CNY', openingBalance: 0, sortOrder: 0,
      createdAt: clock.now(), updatedAt: clock.now(), deviceId: deviceId,
    ));
    await categoryRepo.create(Category(
      id: 'cat-food', name: '餐饮', kind: CategoryKind.expense,
      iconRef: 'other', sortOrder: 0,
      createdAt: clock.now(), updatedAt: clock.now(), deviceId: deviceId,
    ));
  });

  tearDown(() => db.close());

  Future<void> addFood(int cents) async {
    final res = await createEntry(CreateEntryInput(
      amountExpression: '${cents / 100}',
      type: EntryType.expense,
      categoryId: 'cat-food',
      accountId: 'acc-cash',
      bookId: bookId,
      deviceId: deviceId,
    ));
    expect(res.isSuccess, isTrue, reason: '${res.failureOrNull}');
  }

  int budgetRows() =>
      (db.raw.select('SELECT COUNT(*) AS c FROM budgets').first['c'] as int?) ?? 0;

  Future<List<LimitGoalView>> views() async {
    final res = await service.limitGoals(
      bookId: bookId,
      from: DateTime.utc(2026, 10, 1),
      to: DateTime.utc(2026, 11, 1),
      categoryNames: const {'cat-food': '餐饮'},
    );
    expect(res.isSuccess, isTrue, reason: '${res.failureOrNull}');
    return res.requireValue;
  }

  group('AC4：限额目标 = 分类预算（同一份数据）', () {
    test('创建「本月餐饮 ≤ 2000」只写一条分类预算行', () async {
      final res = await service.setCategoryLimit(
        bookId: bookId, categoryId: 'cat-food', amountCents: 200000,
        deviceId: deviceId,
      );
      expect(res.isSuccess, isTrue, reason: '${res.failureOrNull}');
      expect(res.requireValue.scope, BudgetScope.category);
      expect(res.requireValue.amount.cents, 200000);
      expect(budgetRows(), 1);

      // 预算页读的是同一行（不是另一套数据）
      final list = (await budgetRepo.listByBook(bookId)).requireValue;
      expect(list.length, 1);
      expect(list.first.id, res.requireValue.id);
      expect(list.first.amount.cents, 200000);
    });

    test('同一分类再设一次 → 改额度而不是新增第二行', () async {
      final first = await service.setCategoryLimit(
        bookId: bookId, categoryId: 'cat-food', amountCents: 200000,
        deviceId: deviceId,
      );
      final second = await service.setCategoryLimit(
        bookId: bookId, categoryId: 'cat-food', amountCents: 300000,
        deviceId: deviceId,
      );
      expect(second.requireValue.id, first.requireValue.id, reason: '同一行');
      expect(second.requireValue.amount.cents, 300000);
      expect(budgetRows(), 1, reason: '不许出现第二套数据');
    });

    test('预算页先建过同一分类 → 限额目标直接复用那一行', () async {
      // 模拟「预算页」自己建了一条分类预算
      final now = clock.now();
      final fromBudgetPage = await budgetRepo.create(Budget(
        id: 'b-existing', bookId: bookId, scope: BudgetScope.category,
        categoryId: 'cat-food', amount: Money(100000),
        createdAt: now, updatedAt: now, deviceId: deviceId,
      ));
      expect(fromBudgetPage.isSuccess, isTrue);

      final res = await service.setCategoryLimit(
        bookId: bookId, categoryId: 'cat-food', amountCents: 250000,
        deviceId: deviceId,
      );
      expect(res.requireValue.id, 'b-existing');
      expect(budgetRows(), 1);
    });

    test('金额非法（≤0）被拦，不落行', () async {
      final res = await service.setCategoryLimit(
        bookId: bookId, categoryId: 'cat-food', amountCents: 0,
        deviceId: deviceId,
      );
      expect(res.failureOrNull!.code, 'goal.limit_positive');
      expect(budgetRows(), 0);
    });
  });

  group('限额目标的进度是派生的', () {
    test('已用金额来自账单，不存第二份', () async {
      await service.setCategoryLimit(
        bookId: bookId, categoryId: 'cat-food', amountCents: 200000,
        deviceId: deviceId,
      );
      await addFood(80000);
      await addFood(20000);

      final v = (await views()).single;
      expect(v.categoryName, '餐饮');
      expect(v.limitCents, 200000);
      expect(v.spentCents, 100000);
      expect(v.remainingCents, 100000);
      expect(v.isOver, isFalse);
      expect(v.progress, closeTo(0.5, 0.0001));
      // 目标本身只占一行预算；进度没有额外落库
      expect(budgetRows(), 1);
    });

    test('超支时 isOver 为真、剩余转负', () async {
      await service.setCategoryLimit(
        bookId: bookId, categoryId: 'cat-food', amountCents: 100000,
        deviceId: deviceId,
      );
      await addFood(150000);
      final v = (await views()).single;
      expect(v.isOver, isTrue);
      expect(v.remainingCents, -50000);
      expect(v.progress, 1.0, reason: '进度条截到 1');
      expect(v.overRatio, closeTo(0.5, 0.0001));
    });

    test('只有启用中的分类预算才作为限额目标展示', () async {
      final now = clock.now();
      await budgetRepo.create(Budget(
        id: 'b-off', bookId: bookId, scope: BudgetScope.category,
        categoryId: 'cat-food', amount: Money(100000), isEnabled: false,
        createdAt: now, updatedAt: now, deviceId: deviceId,
      ));
      expect(await views(), isEmpty);

      // 总预算不是限额目标（它是全局额度，不在分类维度）
      await budgetRepo.create(Budget(
        id: 'b-total', bookId: bookId, scope: BudgetScope.total,
        amount: Money(500000), createdAt: now, updatedAt: now, deviceId: deviceId,
      ));
      expect(await views(), isEmpty);
    });

    test('删除限额目标 = 软删那条预算，账单不受影响', () async {
      final created = await service.setCategoryLimit(
        bookId: bookId, categoryId: 'cat-food', amountCents: 200000,
        deviceId: deviceId,
      );
      await addFood(50000);
      await service.removeLimit(created.requireValue.id);

      expect(await views(), isEmpty);
      // 账单还在（删目标不是删账）
      final rows = db.raw.select(
          "SELECT COUNT(*) AS c FROM transactions WHERE category_id='cat-food' AND deleted_at IS NULL");
      expect(rows.first['c'], 1);
    });

    test('AC1（储蓄进度口径）：已存 ÷ 目标是纯派生', () {
      // 储蓄目标侧的 25% 由 savings_goal 测试覆盖；这里锁住限额目标的进度口径：
      // 0 支出 = 0%，恰好用满 = 100%
      final budget = Budget(
        id: 'b1', bookId: bookId, scope: BudgetScope.category,
        categoryId: 'cat-food', amount: Money(20000),
        createdAt: clock.now(), updatedAt: clock.now(), deviceId: deviceId,
      );
      final zero = GoalSystemService.buildViews(
        budgets: [budget], spentByCategory: const {}, categoryNames: const {'cat-food': '餐饮'},
      ).single;
      expect(zero.progress, 0);
      final full = GoalSystemService.buildViews(
        budgets: [budget], spentByCategory: const {'cat-food': 20000}, categoryNames: const {'cat-food': '餐饮'},
      ).single;
      expect(full.progress, 1.0);
      expect(full.isOver, isFalse, reason: '刚好用满不算超支');
    });

    test('多个限额目标按「快用满」优先排序', () {
      final now = clock.now();
      Budget b(String id, String cat, int amt) => Budget(
            id: id, bookId: bookId, scope: BudgetScope.category, categoryId: cat,
            amount: Money(amt), createdAt: now, updatedAt: now, deviceId: deviceId,
          );
      final views = GoalSystemService.buildViews(
        budgets: [b('b1', 'c1', 10000), b('b2', 'c2', 10000)],
        spentByCategory: const {'c1': 1000, 'c2': 9000},
        categoryNames: const {'c1': 'A', 'c2': 'B'},
      );
      expect(views.first.categoryName, 'B');
    });
  });
}
