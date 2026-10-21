/// 回归：补记（选一个过去的日期记账）在同一天的流水分组里必须按「时刻」正常落位。
///
/// 用户 2026-10-20 报：新建昨天的食材消费，应该在昨天交通上面，结果排到了下面；
/// 选今天的日期有时也会掉到下面一条。
///
/// 根因：`showAppDatePicker` 只给「哪一天」，返回的是 `DateTime(y,m,d).toUtc()`，
/// 时分秒恒为 **00:00:00**。补记的账因此落在当天最早的一刻，流水页按
/// `occurred_at DESC` 排序就永远沉在分组最下面。
/// 修复：`mergeDayWithNowTime` 把选中日期补上「此刻的时分秒」。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plain/app/bootstrap.dart';
import 'package:plain/app/l10n/strings_core.dart';
import 'package:plain/app/l10n/strings_ledger.dart';
import 'package:plain/core/time/clock.dart';
import 'package:plain/core/time/date_format.dart';
import 'package:plain/data/db/database.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/repositories/repositories.dart';
import 'package:plain/domain/usecases/entry_usecases.dart';
import 'package:plain/features/ledger/controllers/entry_input_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 固定「现在」= 2026-10-20 15:51:20（本地时间），与用户截图里的场景一致。
final DateTime _nowLocal = DateTime(2026, 10, 20, 15, 51, 20);

void main() {
  late AppDatabase db;
  late AppDependencies deps;
  late ProviderContainer container;
  late CreateEntryUseCase createEntry;

  var booted = false;

  Future<void> boot({DateTime? nowLocal}) async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.inMemory();
    booted = true;
    deps = buildDependencies(
      db: db,
      deviceId: 'dev-1',
      bookId: 'book-1',
      clock: FixedClock((nowLocal ?? _nowLocal).toUtc()),
    );
    container = ProviderContainer(
      overrides: [appDependenciesProvider.overrideWithValue(deps)],
    );
    createEntry = CreateEntryUseCase(
      repository: deps.ledgerRepository,
      clock: deps.clock,
      idGen: deps.idGen,
    );
  }

  Future<void> add(String note, DateTime utcAt, String amount) async {
    final r = await createEntry(
      CreateEntryInput(
        amountExpression: amount,
        type: EntryType.expense,
        categoryId: 'cat-food',
        accountId: 'acc-a',
        note: note,
        occurredAt: utcAt,
        bookId: 'book-1',
        deviceId: 'dev-1',
      ),
      s: kDefaultAppStrings,
    );
    expect(r.isSuccess, isTrue, reason: '写入 $note 失败');
  }

  tearDown(() {
    // 纯函数用例没 boot，别在 tearDown 里炸 LateInitializationError。
    if (!booted) return;
    container.dispose();
    db.close();
  });

  // ── 纯函数：日期 + 此刻时刻 ────────────────────────────────────────────────

  test('mergeDayWithNowTime：保留选中的那一天，时刻取「此刻」', () {
    // 选择器产物：本地 10-19 00:00 → UTC
    final picked = DateTime(2026, 10, 19).toUtc();
    final at = mergeDayWithNowTime(picked, _nowLocal.toUtc()).toLocal();

    expect([at.year, at.month, at.day], [2026, 10, 19]);
    expect([at.hour, at.minute, at.second], [15, 51, 20]);
    expect(at.hour, isNot(0), reason: '这就是 bug 本体：不能留在 00:00');
  });

  test('mergeDayWithNowTime：选今天 = 就是现在', () {
    final at = mergeDayWithNowTime(DateTime(2026, 10, 20).toUtc(),
            _nowLocal.toUtc())
        .toLocal();
    expect(Clock.dayKeyOf(at), Clock.dayKeyOf(_nowLocal));
    expect(at.hour, _nowLocal.hour);
    expect(at.minute, _nowLocal.minute);
  });

  // ── 控制器：日期选择不再写 00:00 ──────────────────────────────────────────

  test('onDateSelected(昨天) → occurredAt 落在昨天且不是 00:00', () async {
    await boot();
    final ctl = container.read(entryInputControllerProvider.notifier);

    ctl.onDateSelected(DateTime(2026, 10, 19).toUtc());
    final st = container.read(entryInputControllerProvider);

    expect(st.occurredAtUserSet, isTrue);
    final at = st.occurredAt!.toLocal();
    expect(Clock.dayKeyOf(at), '2026-10-19');
    expect([at.hour, at.minute], [15, 51]);
  });

  test('用户报的场景：补记的「食材」排在当天早上录的「交通」上面', () async {
    await boot();
    // 昨天 09:00 录的交通
    await add('交通', DateTime(2026, 10, 19, 9).toUtc(), '8');

    // 现在「新建昨天的食材」：走的就是日期选择器这条路径
    final ctl = container.read(entryInputControllerProvider.notifier);
    ctl.onDateSelected(DateTime(2026, 10, 19).toUtc());
    await add('食材', container.read(entryInputControllerProvider).occurredAt!,
        '42');

    final page = await deps.ledgerRepository.listPage(
      filter: EntryFilter(bookId: 'book-1'),
      limit: 50,
    );
    final items = page.successOrNull!.items;
    expect(items.map((e) => e.note).toList(), ['食材', '交通'],
        reason: '同日按 occurred_at 降序：15:51 的食材要在 09:00 的交通之前');
    // 两天都不能被拆开
    expect(items.where((e) => Clock.dayKeyOf(e.occurredAt.toLocal()) == '2026-10-19').length, 2);
  });

  test('选「今天」的日期也不会掉到下面（曾经 00:00 落到最底）', () async {
    await boot();
    await add('早餐', DateTime(2026, 10, 20, 8, 30).toUtc(), '12');

    final ctl = container.read(entryInputControllerProvider.notifier);
    ctl.onDateSelected(DateTime(2026, 10, 20).toUtc());
    await add('咖啡', container.read(entryInputControllerProvider).occurredAt!,
        '18');

    final page = await deps.ledgerRepository.listPage(
      filter: EntryFilter(bookId: 'book-1'),
      limit: 50,
    );
    expect(page.successOrNull!.items.map((e) => e.note).toList(),
        ['咖啡', '早餐']);
  });

  // ── 附带修掉的：归属月 toast 的 UTC 月偏差 ────────────────────────────────

  test('月初凌晨（本地 11-01 00:30，UTC 仍是 10-31）补记当月账不误报「计入 11 月」',
      () async {
    // 北京时间 11-01 00:30 == 10-31 16:30Z：旧实现拿 UTC 月的 10 当「本月」，
    // 于是把 11 月的账判成跨月。
    await boot(nowLocal: DateTime(2026, 11, 1, 0, 30));
    final ctl = container.read(entryInputControllerProvider.notifier);

    ctl.onDateSelected(DateTime(2026, 11, 15).toUtc());
    expect(container.read(entryInputControllerProvider).toastMessage, isNull,
        reason: '同属 11 月，不该有跨月提示');
  });

  test('真的跨月才提示，且月份是选中那天所在的月', () async {
    await boot();
    final ctl = container.read(entryInputControllerProvider.notifier);

    ctl.onDateSelected(DateTime(2026, 9, 15).toUtc());
    expect(container.read(entryInputControllerProvider).toastMessage,
        kDefaultAppStrings.entryCountsInMonth(9));
  });

  // ── 历史数据修复（v28） ────────────────────────────────────────────────────

  test('v28 修复：老的 00:00 补记账改成「录入时刻」，日期不变、只影响当天内排序',
      () async {
    await boot();
    await add('交通', DateTime(2026, 10, 19, 9).toUtc(), '8');
    // 老版本写进库的坏形态：选了 10-19，时刻是 00:00
    await add('食材', DateTime(2026, 10, 19).toUtc(), '42');

    Future<List<String?>> notes() async {
      final page = await deps.ledgerRepository.listPage(
        filter: EntryFilter(bookId: 'book-1'),
        limit: 50,
      );
      return page.successOrNull!.items.map((e) => e.note).toList();
    }

    expect(await notes(), ['交通', '食材'], reason: '修复前：食材沉在最后');

    expect(repairBackdatedZeroTime(deps.db.raw), 1);

    expect(await notes(), ['食材', '交通'], reason: '修复后：按录入时刻 15:51 归位');

    // 日期不变（报表/统计口径不变）
    final page = await deps.ledgerRepository.listPage(
      filter: EntryFilter(bookId: 'book-1'),
      limit: 50,
    );
    final fixed = page.successOrNull!.items.first;
    expect(Clock.dayKeyOf(fixed.occurredAt.toLocal()), '2026-10-19');
    expect(fixed.occurredAt.toLocal().hour, _nowLocal.hour);

    // 幂等：再跑一次什么都不改
    expect(repairBackdatedZeroTime(deps.db.raw), 0);
  });

  test('v28 修复不动「本来就有正常时刻」的账', () async {
    await boot();
    await add('正常', DateTime(2026, 10, 19, 9, 30).toUtc(), '8');
    expect(repairBackdatedZeroTime(deps.db.raw), 0);
  });
}
