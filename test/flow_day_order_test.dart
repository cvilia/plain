/// 流水页「同一天内部的顺序」回归。
///
/// 用户反馈（2026-10-20）：
/// 「为什么有时候是今天的数据，却也都排到了下面，而且昨天的数据，有的排下面有的排上面」
///
/// 根因：天内顺序原本由 `occurred_at`（账**发生**的时刻）决定，而补记时那个
/// 「几点」是程序补的（此刻 / 曾经还是 00:00），用户既没设也不关心 →
/// 补记的账会插到当天中间或沉底，看起来毫无规律。
/// 口径改为：**天内的顺序按录入先后**（`created_at` 降序），跨天仍按 `occurred_at`。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plain/app/bootstrap.dart';
import 'package:plain/app/l10n/strings_core.dart';
import 'package:plain/core/money/money.dart';
import 'package:plain/core/time/clock.dart';
import 'package:plain/data/db/database.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/entities/ledger_entry.dart';
import 'package:plain/domain/repositories/repositories.dart';
import 'package:plain/domain/usecases/entry_usecases.dart';
import 'package:plain/features/ledger/controllers/flow_list_controller.dart';
import 'package:plain/features/ledger/controllers/entry_input_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppDatabase db;
  late AppDependencies deps;
  late ProviderContainer container;
  late FixedClock clock;
  late CreateEntryUseCase create;

  /// 固定「现在」从 2026-10-19 09:00 起，逐条推进，模拟真实录入时间。
  Future<void> boot() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.inMemory();
    clock = FixedClock(DateTime(2026, 10, 19, 9).toUtc());
    deps = buildDependencies(
      db: db,
      deviceId: 'dev-1',
      bookId: 'book-1',
      clock: clock,
    );
    container = ProviderContainer(
      overrides: [appDependenciesProvider.overrideWithValue(deps)],
    );
    create = CreateEntryUseCase(
      repository: deps.ledgerRepository,
      clock: clock,
      idGen: deps.idGen,
    );
  }

  tearDown(() {
    container.dispose();
    db.close();
  });

  /// 在 [at] 这一刻录入一笔，账发生时间 [occurredAt]。
  Future<void> record({
    required String note,
    required DateTime at,
    required DateTime occurredAt,
  }) async {
    clock.set(at.toUtc());
    final r = await create(
      CreateEntryInput(
        amountExpression: '10',
        type: EntryType.expense,
        categoryId: 'cat-food',
        accountId: 'acc-a',
        note: note,
        occurredAt: occurredAt.toUtc(),
        bookId: 'book-1',
        deviceId: 'dev-1',
      ),
      s: kDefaultAppStrings,
    );
    expect(r.isSuccess, isTrue, reason: '写入 $note 失败');
  }

  Future<List<String>> notesOfDay(String dayKey) async {
    final ctl = container.read(flowListControllerProvider.notifier);
    await ctl.loadInitial();
    final groups = container.read(flowListControllerProvider).groups;
    final g = groups.firstWhere((g) => g.dayKey == dayKey);
    return [for (final e in g.entries) e.note ?? ''];
  }

  test('昨天实时记 20:00 的交通，今天补记昨天的食材 → 食材在交通上面', () async {
    await boot();
    // 昨天 20:00 当场记的交通
    await record(
      note: '交通',
      at: DateTime(2026, 10, 19, 20),
      occurredAt: DateTime(2026, 10, 19, 20),
    );
    // 今天 16:00 补记昨天 —— 日期选择器只给「昨天」，时刻补成此刻（16:00）
    clock.set(DateTime(2026, 10, 20, 16).toUtc());
    final ctl = container.read(entryInputControllerProvider.notifier);
    ctl.onDateSelected(DateTime(2026, 10, 19).toUtc());
    final occurred =
        container.read(entryInputControllerProvider).occurredAt!.toLocal();
    expect([occurred.day, occurred.hour], [19, 16],
        reason: '补记的账：日期是昨天、时刻是此刻');

    clock.set(DateTime(2026, 10, 20, 16).toUtc());
    final r = await create(
      CreateEntryInput(
        amountExpression: '50',
        type: EntryType.expense,
        categoryId: 'cat-food',
        accountId: 'acc-a',
        note: '食材',
        occurredAt: occurred.toUtc(),
        bookId: 'book-1',
        deviceId: 'dev-1',
      ),
      s: kDefaultAppStrings,
    );
    expect(r.isSuccess, isTrue);

    // 按 occurred_at 排会是 [交通(20:00), 食材(16:00)]；按录入先后才是用户要的。
    expect(await notesOfDay('2026-10-19'), ['食材', '交通']);
  });

  test('今天补记今天：即使落库时刻是 00:00（周期/导入类写入）也排在最上面', () async {
    await boot();
    record(
      note: '早餐',
      at: DateTime(2026, 10, 20, 8),
      occurredAt: DateTime(2026, 10, 20, 8),
    );
    await Future<void>.delayed(Duration.zero);
    // 模拟「当天 00:00」的写入（周期记账、CSV 导入都长这样），录入发生在 16:00
    await record(
      note: '房租',
      at: DateTime(2026, 10, 20, 16),
      occurredAt: DateTime(2026, 10, 20, 0),
    );

    expect(await notesOfDay('2026-10-20'), ['房租', '早餐']);
  });

  test('跨天顺序仍按「哪一天」降序（今天整组在昨天之上）', () async {
    await boot();
    await record(
      note: '昨天',
      at: DateTime(2026, 10, 19, 20),
      occurredAt: DateTime(2026, 10, 19, 20),
    );
    await record(
      note: '今天',
      at: DateTime(2026, 10, 20, 9),
      occurredAt: DateTime(2026, 10, 20, 9),
    );

    final ctl = container.read(flowListControllerProvider.notifier);
    await ctl.loadInitial();
    final keys = [
      for (final g in container.read(flowListControllerProvider).groups)
        g.dayKey
    ];
    expect(keys, ['2026-10-20', '2026-10-19']);
  });

  test('编辑一笔旧账不会把它顶到最上面（created_at 不变）', () async {
    await boot();
    await record(
      note: '早餐',
      at: DateTime(2026, 10, 20, 8),
      occurredAt: DateTime(2026, 10, 20, 8),
    );
    await record(
      note: '午餐',
      at: DateTime(2026, 10, 20, 12),
      occurredAt: DateTime(2026, 10, 20, 12),
    );
    expect(await notesOfDay('2026-10-20'), ['午餐', '早餐']);

    final list = await deps.ledgerRepository.listPage(
      filter: EntryFilter(bookId: 'book-1'),
    );
    final breakfast =
        list.successOrNull!.items.firstWhere((e) => e.note == '早餐');
    clock.set(DateTime(2026, 10, 20, 18).toUtc());
    final upd = await deps.ledgerRepository.update(
      breakfast.copyWith(note: '早餐(改)', updatedAt: clock.now()),
    );
    expect(upd.isSuccess, isTrue);

    expect(await notesOfDay('2026-10-20'), ['午餐', '早餐(改)']);
  });

  test('排序纯函数：按 createdAt 降序，同毫秒用 id 兜底', () {
    final base = DateTime.utc(2026, 10, 20, 12);
    LedgerEntry mk(String id, DateTime created) => LedgerEntry(
          id: id,
          bookId: 'b',
          type: EntryType.expense,
          amount: const Money(100),
          currency: 'CNY',
          occurredAt: base,
          createdAt: created,
          updatedAt: created,
          source: EntrySource.manual,
          deviceId: 'd',
        );
    final sorted = sortByRecordedOrder([
      mk('a', base),
      mk('c', base.add(const Duration(minutes: 5))),
      mk('b', base),
    ]);
    expect([for (final e in sorted) e.id], ['c', 'b', 'a']);
  });
}
