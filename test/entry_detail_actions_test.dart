/// 账单详情页（SP-1-02）顶栏与动作区的回归契约。
///
/// 三件此前出过问题的事：
///
/// 1. **标题不居中**。`PlainTopBar` 默认绝对居中，但只有「两侧留得出标题空间」时才走
///    `Stack`（见 `_minCenteredTitleWidth` 判据）。页面原先在右侧塞了
///    「拆分 / 编辑 / 删除」三枚自绘控件，估算宽度 64+64+44+4 = 176pt → 判据不成立 →
///    静默退回老布局，标题跟着左偏 66pt。这类退化不报错、不崩，只能靠断言盯住。
///
/// 2. **删除图标被撑大**。原先自绘 `SizedBox(44,44, child: PlainIcon(delete, size: 20))`：
///    `SvgPicture` 的 `width/height` 只在**松**约束下生效，紧约束会把图标拉到 44×44。
///    `PlainTopBarAction` 内部包 `Center` 正是为了松约束。
///
/// 3. **删除按钮同屏出现两次**（顶栏一枚 + 正文底部「删除这笔账单」）。已按产品口径
///    只保留顶栏那一枚。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plain/app/bootstrap.dart';
import 'package:plain/app/l10n/strings_core.dart';
import 'package:plain/app/theme/theme_registry.dart';
import 'package:plain/app/theme/theme_resolver.dart';
import 'package:plain/core/id/uuid_v7.dart';
import 'package:plain/core/time/clock.dart';
import 'package:plain/data/db/database.dart';
import 'package:plain/design_system/plain_icons_v3.dart';
import 'package:plain/design_system/plain_ui.dart';
import 'package:plain/domain/entities/enums.dart';
import 'package:plain/domain/usecases/entry_usecases.dart';
import 'package:plain/features/ledger/presentation/entry_detail_page.dart';

const double _kStatusBar = 47;

ThemeData _theme() => buildThemeData(
      resolveTokens(themeSpecOf(ThemeId.subai), Brightness.light),
      Brightness.light,
    );

void _phone(WidgetTester tester, {double height = 852}) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = Size(393, height);
  tester.view.padding = const FakeViewPadding(top: _kStatusBar);
  addTearDown(tester.view.reset);
}

/// 建一笔普通支出并打开它的详情页。
Future<void> _openDetail(WidgetTester tester) async {
  final db = AppDatabase.inMemory();
  addTearDown(db.close);

  final clock = FixedClock(DateTime.utc(2026, 10, 12, 4));
  final deps = buildDependencies(
    db: db,
    deviceId: 'dev-1',
    bookId: 'book-1',
    clock: clock,
  );

  final created = await CreateEntryUseCase(
    repository: deps.ledgerRepository,
    clock: clock,
    idGen: UuidV7(),
  )(CreateEntryInput(
    amountExpression: '12',
    type: EntryType.expense,
    categoryId: 'preset_shopping_clothes',
    accountId: 'default_cash',
    bookId: 'book-1',
    deviceId: 'dev-1',
    occurredAt: DateTime.utc(2026, 10, 12, 4),
  ), s: kDefaultAppStrings);
  expect(created.isSuccess, true, reason: '前置账单没写进去，详情页会走「账单不存在」分支');

  await tester.pumpWidget(ProviderScope(
    overrides: [appDependenciesProvider.overrideWithValue(deps)],
    child: MaterialApp(
      theme: _theme(),
      home: EntryDetailPage(entryId: created.successOrNull!.id),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('标题在整条顶栏里绝对居中（右侧动作不挤走标题）', (tester) async {
    _phone(tester);
    await _openDetail(tester);

    // 自检：详情页确实渲染出来了，不是空态/错误态。
    expect(find.text('账单详情'), findsOneWidget);

    final bar = tester.getRect(find.byType(PlainTopBar));
    final title = tester.getRect(find.text('账单详情'));
    expect(
      (title.center.dx - bar.center.dx).abs(),
      lessThanOrEqualTo(0.5),
      reason: '标题偏了 ${(title.center.dx - bar.center.dx).toStringAsFixed(1)}pt —— '
          '右侧动作又变宽了，`PlainTopBar` 的居中判据不成立会静默退回左偏布局',
    );
  });

  testWidgets('顶栏只有「返回 + 删除」两枚动作，两个图标同尺寸（22）', (tester) async {
    _phone(tester);
    await _openDetail(tester);

    // 返回 + 删除。多一枚动作就会挤走居中标题（见上一个用例）。
    expect(find.byType(PlainTopBarAction), findsNWidgets(2));

    Finder iconOf(PlainIconData data) => find.byWidgetPredicate(
          (w) => w is PlainIcon && identical(w.icon, data),
        );
    final backIcon = iconOf(PlainIconData.back);
    final deleteIcon = iconOf(PlainIconData.delete);
    expect(deleteIcon, findsOneWidget, reason: '顶栏应有且只有一枚删除图标');

    expect(
      tester.getSize(deleteIcon),
      tester.getSize(backIcon),
      reason: '同一根顶栏里两枚图标必须同尺寸 —— 原先自绘的 44 盒把删除图标'
          '拉伸到了 44×44（`SvgPicture` 的 width/height 只在松约束下生效）',
    );
    expect(tester.getSize(deleteIcon).width, 22, reason: '顶栏图标统一 22');
  });

  testWidgets('正文动作区：编辑是主按钮，拆分是次级按钮，底部不再有删除', (tester) async {
    // 动作区在正文末尾，852 高的视口下不进入 ListView 的懒加载树 —— 拉高视口才能断言它的存在。
    _phone(tester, height: 1600);
    await _openDetail(tester);

    // 两个动作都搬到了正文，顶栏不再是裸文字按钮。
    expect(find.text('编辑'), findsOneWidget);
    expect(find.text('拆分这笔账单'), findsOneWidget);
    expect(find.byType(PlainPrimaryButton), findsOneWidget);
    expect(find.byType(PlainSecondaryButton), findsOneWidget);

    // 删除只留顶栏那一枚：「删除这笔账单」按钮与脚注都撤掉，避免同屏两个同一动作。
    expect(find.text('删除这笔账单'), findsNothing);
    expect(find.text('删除后不可恢复'), findsNothing);
    expect(find.byType(PlainDangerButton), findsNothing);
  });
}
