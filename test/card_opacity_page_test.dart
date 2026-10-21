/// 主题 → 卡片透明度（独立页）回归：拖动滑杆必须「实时」改变卡片底色。
///
/// 用户需求（2026-10-20）：「透明度可以自定义（通过拖拽进度条的方式，
/// 并且可以实时的看到实际效果」。
///
/// 这条链有四段，断一段就变「拖了没反应」：
///   滑杆 onChanged → ThemePrefs.cardOpacity → MaterialApp.theme 重建
///   → AppColors 扩展换新 → 预览卡读到的 `colors.surface` 变。
/// 本测试直接从**渲染出来的 Container.decoration** 取色比对，
/// 而不是只看 provider 状态，才能覆盖第 2–4 段。
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plain/app/l10n/app_strings.dart';
import 'package:plain/app/l10n/strings_core.dart';
import 'package:plain/app/l10n/strings_settings_a.dart';
import 'package:plain/app/theme/app_colors.dart';
import 'package:plain/app/theme/theme_prefs.dart';
import 'package:plain/app/theme/theme_registry.dart';
import 'package:plain/app/theme/theme_resolver.dart';
import 'package:plain/features/settings/card_opacity_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 复刻 `main.dart` 里 App 的接线：watch prefs → 拿带透明度的 ThemeData。
/// 少了 `cardOpacity:` 这一句，滑杆就变成「能拖但页面不动」。
class _Harness extends ConsumerWidget {
  const _Harness();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(themePrefsProvider);
    final (_, theme) = themeDataFor(
      prefs.themeId,
      Brightness.light,
      cardOpacity: prefs.cardOpacity,
    );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      locale: const Locale('zh', 'CN'),
      localizationsDelegates: const [
        AppStrings.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppStrings.supportedLocales,
      home: const CardOpacityPage(),
    );
  }
}

void _phone(WidgetTester tester) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(393, 852);
  tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
  addTearDown(tester.view.reset);
}

/// 预览卡**实际渲染**出来的底色。
Color _renderedCardColor(WidgetTester tester) {
  final box = tester.widget<Container>(find.byKey(kCardOpacityPreviewCardKey));
  final deco = box.decoration;
  expect(deco, isA<BoxDecoration>(), reason: '预览卡必须自带底色');
  return (deco as BoxDecoration).color!;
}

/// 当前主题令牌里的卡片底（= 预览卡「应该」是什么色）。
Color _tokenSurface(WidgetTester tester) {
  final ctx = tester.element(find.byKey(kCardOpacitySliderKey));
  return Theme.of(ctx).extension<AppColors>()!.surface;
}

Color _tokenPageBg(WidgetTester tester) {
  final ctx = tester.element(find.byKey(kCardOpacitySliderKey));
  return Theme.of(ctx).extension<AppColors>()!.pageBg;
}

double _sliderValue(WidgetTester tester) =>
    tester.widget<Slider>(find.byKey(kCardOpacitySliderKey)).value;

/// 滑杆右侧的百分比读数（15 号 / w600）。
/// 不能直接 `find.text('60%')`：页面底部「恢复默认」行的副标题也是 `60%`。
String? _readout(WidgetTester tester) {
  for (final w in tester.widgetList<Text>(find.byType(Text))) {
    if (w.style?.fontSize == 15 && w.style?.fontWeight == FontWeight.w600) {
      return w.data;
    }
  }
  return null;
}

/// 取一个颜色有多「亮」——用来判断朝白走还是朝纸色走（不关心色相）。
double _lum(Color c) => c.computeLuminance();

Future<ProviderContainer> _pumpPage(
  WidgetTester tester, {
  double? cardOpacity,
}) async {
  SharedPreferences.setMockInitialValues({});
  _phone(tester);
  final container = ProviderContainer();
  addTearDown(container.dispose);
  if (cardOpacity != null) {
    // 真实启动路径是 `preloadThemePrefs()` 读盘后 `build()` 直接用；
    // 测试里没走 preload，就用 `load()` 灌同一份快照。
    container
        .read(themePrefsProvider.notifier)
        .load({kPrefCardOpacity: '$cardOpacity'});
  }
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const _Harness()),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  final s = kDefaultAppStrings;

  testWidgets('默认 60%：滑杆、百分比、实时预览都在，预览卡用真实令牌色', (tester) async {
    await _pumpPage(tester);

    expect(find.byKey(kCardOpacitySliderKey), findsOneWidget);
    expect(find.byKey(kCardOpacityPreviewCardKey), findsOneWidget);
    expect(_readout(tester), s.cardOpacityValue(60));
    expect(_sliderValue(tester), closeTo(kCardOpacityDefault, 0.001));
    expect(find.text(s.cardOpacityPreviewTitle), findsOneWidget);

    // 预览不是画上去的假图 —— 必须等于主题令牌。
    expect(_renderedCardColor(tester), _tokenSurface(tester));
  });

  testWidgets('拖动滑杆 → 卡片底色当帧就变（实时预览）', (tester) async {
    final container = await _pumpPage(tester);
    final before = _renderedCardColor(tester);

    // 从滑杆中心往右拖到底。
    await tester.drag(find.byKey(kCardOpacitySliderKey), const Offset(400, 0));
    await tester.pumpAndSettle();

    expect(container.read(themePrefsProvider).cardOpacity, greaterThan(0.9),
        reason: '拖到底应当接近 100%');
    final after = _renderedCardColor(tester);
    expect(after, isNot(before), reason: '拖动后卡片底色必须变，否则就是「拖了没反应」');
    expect(_lum(after), greaterThan(_lum(before)), reason: '白占比越高，卡片越亮');
    // 仍然与令牌一致 → 全 app 同色，不是本页单独刷的。
    expect(after, _tokenSurface(tester));
  });

  testWidgets('100% = 纯白；0% = 与页面纸色同色（预览与全局同源）', (tester) async {
    final container = await _pumpPage(tester);

    container.read(themePrefsProvider.notifier).setCardOpacity(1);
    await tester.pumpAndSettle();
    final white = _renderedCardColor(tester);
    expect(white, const Color(0xFFFFFFFF), reason: '1.0 应当就是纯白');
    expect(_renderedCardColor(tester), _tokenSurface(tester));

    container.read(themePrefsProvider.notifier).setCardOpacity(0);
    await tester.pumpAndSettle();
    final flat = _renderedCardColor(tester);
    expect(flat, _tokenPageBg(tester), reason: '0 应当完全融入纸色（方框只剩描边）');
    expect(_lum(flat), lessThan(_lum(white)));
  });

  testWidgets('松手才落盘：拖动过程中不写盘，结束时写入 0–1 的 double', (tester) async {
    final container = await _pumpPage(tester);

    await tester.drag(find.byKey(kCardOpacitySliderKey), const Offset(400, 0));
    await tester.pumpAndSettle();

    final sp = await SharedPreferences.getInstance();
    expect(sp.getDouble(kPrefCardOpacity), isNotNull,
        reason: 'onChangeEnd 必须落盘（否则重启回到默认值）');
    expect(sp.getDouble(kPrefCardOpacity),
        closeTo(container.read(themePrefsProvider).cardOpacity, 0.001));
  });

  testWidgets('老版本没有这个键 → 读成默认 60%，不会被写成 0', (tester) async {
    await _pumpPage(tester);
    expect(ThemePrefs.fromJson(const {}).cardOpacity, kCardOpacityDefault);
    // 脏数据也要夹回 [0,1]
    expect(ThemePrefs.fromJson(const {kPrefCardOpacity: '9'}).cardOpacity, 1.0);
    expect(ThemePrefs.fromJson(const {kPrefCardOpacity: '-3'}).cardOpacity, 0.0);
    expect(ThemePrefs.fromJson(const {kPrefCardOpacity: 'abc'}).cardOpacity,
        kCardOpacityDefault);
  });

  testWidgets('恢复默认 → 回到 60%', (tester) async {
    final container = await _pumpPage(tester, cardOpacity: 0.9);
    expect(container.read(themePrefsProvider).cardOpacity, closeTo(0.9, 0.001));
    expect(_readout(tester), s.cardOpacityValue(90));

    await tester.tap(find.text(s.cardOpacityReset));
    await tester.pumpAndSettle();

    expect(container.read(themePrefsProvider).cardOpacity,
        closeTo(kCardOpacityDefault, 0.001));
    expect(_sliderValue(tester), closeTo(kCardOpacityDefault, 0.001));
    expect(_readout(tester), s.cardOpacityValue(60));
  });

  testWidgets('20 个主题组合在 0 / 0.6 / 1 三档下都满足 bg < appBg < surface 之外的可读性', (tester) async {
    // 只查「0 = 融入纸色、1 = 卡片本色不越界」这两条硬边界，防止有人把
    // 预混方向写反（surfaceBase 与 appBg 顺序颠倒 → 0% 比 100% 还白）。
    for (final id in ThemeId.values) {
      final spec = themeSpecOf(id);
      for (final b in Brightness.values) {
        final zero = resolveTokens(spec, b, cardOpacity: 0).surface;
        final full = resolveTokens(spec, b, cardOpacity: 1).surface;
        final page = resolveTokens(spec, b).appBg;
        expect(_lum(zero), closeTo(_lum(page), 0.0001),
            reason: '${id.id}/${b.name}: 0% 应与纸色同色');
        expect(_lum(full), greaterThan(_lum(page)),
            reason: '${id.id}/${b.name}: 100% 必须比纸色更「白/亮」');
      }
    }
  });

  test('缓存不会因拖动无限膨胀（分档有上限）', () {
    const id = ThemeId.subai;
    for (var i = 0; i <= 200; i++) {
      themeDataFor(id, Brightness.light, cardOpacity: i / 200);
    }
    // 越界值应夹到 1.0 并命中同一缓存条目（而不是每次新建 ThemeData）。
    final a = themeDataFor(id, Brightness.light, cardOpacity: 2);
    final b = themeDataFor(id, Brightness.light, cardOpacity: 1);
    expect(identical(a, b), isTrue, reason: '越界值应夹到 1.0 并命中同一缓存');
  });
}
