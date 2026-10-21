/// 主题配色门禁（R1–R7）—— `theme_registry.dart` 顶部注释的可执行版本。
///
/// 背景：这一版 10 套主题的品牌色是从「约束」反推出来的，不是从设计稿抄的。
/// 抄来的那套有三类硬伤（都在下面有对应断言）：
///   ① 品牌色与语义色撞色 —— `青瓷 p=#14B8A6` 反推出的文字级 ink 和收入绿
///      同屏分不开；`绯樱 p=#EF4444` 与支出红 OKLab 只差 6.1。
///   ② 跨主题重复 —— 青瓷 vs 海盐、竹青 vs 豆绿 差 7～8，选择器里像两个同款。
///   ③ 页面纸色全白 —— 20 个组合的 `appBg` 都是中性白，主题只在按钮上体现。
///
/// 改任何品牌色 / wash / 中性层后跑这个文件。断言失败不是「阈值太严」——
/// 先读 `theme_registry.dart` 里 R1–R7 的注释，那是判定依据。
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plain/app/theme/app_colors.dart';
import 'package:plain/app/theme/color_math.dart' as cm;
import 'package:plain/design_system/plain_ui.dart';
import 'package:plain/app/theme/theme_registry.dart';
import 'package:plain/app/theme/theme_resolver.dart';

int _a(Color c) => c.toARGB32();

double _lin(int v) {
  final c = v / 255.0;
  return c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
}

/// OKLab（Björn Ottosson）。ΔE 用它的欧氏距离 ×100，和设计侧审计脚本同口径。
List<double> _oklab(int argb) {
  final r = _lin((argb >> 16) & 0xFF);
  final g = _lin((argb >> 8) & 0xFF);
  final b = _lin(argb & 0xFF);
  var l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b;
  var m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b;
  var s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b;
  l = math.pow(l.abs(), 1 / 3).toDouble() * (l < 0 ? -1 : 1);
  m = math.pow(m.abs(), 1 / 3).toDouble() * (m < 0 ? -1 : 1);
  s = math.pow(s.abs(), 1 / 3).toDouble() * (s < 0 ? -1 : 1);
  return [
    0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
    1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
    0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s,
  ];
}

double _de(int a, int b) {
  final x = _oklab(a), y = _oklab(b);
  return math.sqrt(math.pow(y[0] - x[0], 2) +
          math.pow(y[1] - x[1], 2) +
          math.pow(y[2] - x[2], 2)) *
      100;
}

/// HSL 色相（0–360），无彩返回 null。
double? _hue(int argb) {
  final r = (argb >> 16) & 0xFF, g = (argb >> 8) & 0xFF, b = argb & 0xFF;
  final mx = math.max(r, math.max(g, b)), mn = math.min(r, math.min(g, b));
  if (mx == mn) return null;
  final d = (mx - mn).toDouble();
  final double h;
  if (mx == r) {
    h = ((g - b) / d) % 6;
  } else if (mx == g) {
    h = (b - r) / d + 2;
  } else {
    h = (r - g) / d + 4;
  }
  return h * 60;
}

double _hueGap(int a, int b) {
  final ha = _hue(a), hb = _hue(b);
  if (ha == null || hb == null) return 0;
  final d = (ha - hb).abs();
  return math.min(d, 360 - d);
}

/// 「两色可区分」：色差够，或色相拉开（橄榄绿 vs 翡翠绿这类同明度不同相的）。
bool _sep(int a, int b, {double minDe = 10, double minHue = 25}) =>
    _de(a, b) >= minDe || _hueGap(a, b) >= minHue;

String _hex(int c) => cm.hexString(c);

void main() {
  for (final isDark in [false, true]) {
    final mode = isDark ? '暗色' : '亮色';
    final brightness = isDark ? Brightness.dark : Brightness.light;

    group(mode, () {
      for (final id in ThemeId.values) {
        final spec = themeSpecOf(id);
        final name = spec.name;
        final t = resolveTokens(spec, brightness);
        final paper = _a(t.appBg);
        final primary = _a(t.primary);
        final accent = _a(t.accent);
        final pInk = _a(t.primaryInk);
        final expenseInk = _a(t.incomeInk);
        final incomeInk = _a(t.dnInk);

        test('$name：R1 主色与强调色不是同一个色', () {
          // ΔE 15 或色相 60° —— 「同色系抬一档」不算两支色。
          expect(
            _sep(primary, accent, minDe: 15, minHue: 60),
            isTrue,
            reason: '$name($mode) 主色 ${_hex(primary)} ≈ 强调色 ${_hex(accent)} '
                '(ΔE ${_de(primary, accent).toStringAsFixed(1)}, '
                '色相 ${_hueGap(primary, accent).toStringAsFixed(0)}°)',
          );
        });

        test('$name：R2 品牌文字色不与收支红绿混淆', () {
          expect(
            _sep(pInk, expenseInk),
            isTrue,
            reason: '$name($mode) primaryInk ${_hex(pInk)} ≈ 支出红 ${_hex(expenseInk)} '
                '(ΔE ${_de(pInk, expenseInk).toStringAsFixed(1)}, '
                '色相 ${_hueGap(pInk, expenseInk).toStringAsFixed(0)}°)',
          );
          expect(
            _sep(pInk, incomeInk),
            isTrue,
            reason: '$name($mode) primaryInk ${_hex(pInk)} ≈ 收入绿 ${_hex(incomeInk)} '
                '(ΔE ${_de(pInk, incomeInk).toStringAsFixed(1)}, '
                '色相 ${_hueGap(pInk, incomeInk).toStringAsFixed(0)}°)',
          );
        });

        test('$name：R4 页面纸色带主题色，不是纯白/中性底', () {
          if (isDark) {
            // 暗色阈值给到 0.8 而不是 1.5：暗底上的彩度预算本就极小，
            // 要同时满足「能看出偏色」和「卡片比页面亮」只能到这个量级；
            // 素白是刻意的中性主题（品牌色饱和度 5%），它最低，0.86。
            final bare = toneOf(spec.tone, true).appBg;
            expect(
              _de(paper, bare) >= 0.8,
              isTrue,
              reason: '$name 暗色纸色 ${_hex(paper)} 与中性底 ${_hex(bare)} '
                  'ΔE ${_de(paper, bare).toStringAsFixed(1)} < 0.8',
            );
          } else {
            expect(
              _de(paper, 0xFFFFFFFF) >= 2.2,
              isTrue,
              reason: '$name 亮色纸色 ${_hex(paper)} 与纯白 '
                  'ΔE ${_de(paper, 0xFFFFFFFF).toStringAsFixed(1)} < 2.2',
            );
          }
        });

        test('$name：R5 ink 四级对纸色对比度', () {
          expect(cm.contrast(_a(t.ink), paper) >= 12, isTrue,
              reason: '$name($mode) ink ${cm.contrast(_a(t.ink), paper).toStringAsFixed(1)} < 12');
          expect(cm.contrast(_a(t.ink2), paper) >= 7, isTrue,
              reason: '$name($mode) ink2 ${cm.contrast(_a(t.ink2), paper).toStringAsFixed(1)} < 7');
          expect(cm.contrast(_a(t.muted), paper) >= 4.5, isTrue,
              reason: '$name($mode) muted ${cm.contrast(_a(t.muted), paper).toStringAsFixed(1)} < 4.5');
          expect(cm.contrast(_a(t.faint), paper) >= 3.0, isTrue,
              reason: '$name($mode) faint ${cm.contrast(_a(t.faint), paper).toStringAsFixed(1)} < 3');
        });

        test('$name：R6 描边看得见、且不抢品牌色', () {
          final line = _a(t.line);
          expect(cm.contrast(line, paper) >= 1.06, isTrue,
              reason: '$name($mode) 描边/纸 ${cm.contrast(line, paper).toStringAsFixed(2)} < 1.06');
          final minDe = isDark ? 12.0 : 15.0;
          expect(_de(line, primary) >= minDe, isTrue,
              reason: '$name($mode) 描边 ${_hex(line)} ≈ 品牌 ${_hex(primary)} '
                  'ΔE ${_de(line, primary).toStringAsFixed(1)} < $minDe');
        });

        test('$name：R7 FAB 底色 == 导航选中色，图标可读', () {
          final fabBg = _a(t.fabBg);
          expect(fabBg, pInk, reason: '$name($mode) FAB 底色必须等于 primaryInk（导航选中色）');
          expect(cm.contrast(pInk, paper) >= 4.5, isTrue,
              reason: '$name($mode) primaryInk ${cm.contrast(pInk, paper).toStringAsFixed(1)} < 4.5');
          expect(cm.contrast(_a(t.fabIc), fabBg) >= 4.5, isTrue,
              reason: '$name($mode) FAB 图标 ${cm.contrast(_a(t.fabIc), fabBg).toStringAsFixed(1)} < 4.5');
        });

        test('$name：hero 渐变四端点白字可读', () {
          for (final e in {
            'hero0': _a(t.heroGrad0),
            'hero1': _a(t.heroGrad1),
            'heroDark0': _a(t.heroDarkGrad0),
            'heroDark1': _a(t.heroDarkGrad1),
          }.entries) {
            final c = cm.contrast(0xFFFFFFFF, e.value);
            expect(c >= 4.6, isTrue,
                reason: '$name($mode) ${e.key} ${_hex(e.value)} 白字 ${c.toStringAsFixed(1)} < 4.6');
          }
        });
      }

      test('R3 跨主题主色两两可分', () {
        final ids = ThemeId.values;
        for (var i = 0; i < ids.length; i++) {
          for (var j = i + 1; j < ids.length; j++) {
            final a = _a(resolveTokens(themeSpecOf(ids[i]), brightness).primary);
            final b = _a(resolveTokens(themeSpecOf(ids[j]), brightness).primary);
            expect(_de(a, b) >= 8, isTrue,
                reason: '$mode ${themeSpecOf(ids[i]).name} ${_hex(a)} vs '
                    '${themeSpecOf(ids[j]).name} ${_hex(b)} '
                    'ΔE ${_de(a, b).toStringAsFixed(1)} < 8');
          }
        }
      });

      test('R4 跨主题纸色两两可分', () {
        final ids = ThemeId.values;
        for (var i = 0; i < ids.length; i++) {
          for (var j = i + 1; j < ids.length; j++) {
            final a = _a(resolveTokens(themeSpecOf(ids[i]), brightness).appBg);
            final b = _a(resolveTokens(themeSpecOf(ids[j]), brightness).appBg);
            expect(_de(a, b) >= 0.6, isTrue,
                reason: '$mode ${themeSpecOf(ids[i]).name} ${_hex(a)} vs '
                    '${themeSpecOf(ids[j]).name} ${_hex(b)} '
                    'ΔE ${_de(a, b).toStringAsFixed(1)} < 0.6');
          }
        }
      });
    });
  }

  test('层级顺序：bg < appBg < surface（暗色染色不许把页面顶到卡片之上）', () {
    for (final id in ThemeId.values) {
      for (final isDark in [false, true]) {
        final t = resolveTokens(
            themeSpecOf(id), isDark ? Brightness.dark : Brightness.light);
        final yBg = cm.lum(_a(t.bg));
        final yApp = cm.lum(_a(t.appBg));
        final ySurf = cm.lum(_a(t.surface));
        final mode = isDark ? '暗' : '亮';
        expect(yBg < yApp, isTrue,
            reason: '${themeSpecOf(id).name}($mode) bg ${_hex(_a(t.bg))} 不该比 '
                'appBg ${_hex(_a(t.appBg))} 亮');
        expect(yApp < ySurf, isTrue,
            reason: '${themeSpecOf(id).name}($mode) appBg ${_hex(_a(t.appBg))} 不该比 '
                '卡片 ${_hex(_a(t.surface))} 亮 —— 否则卡片像「凹进去」');
      }
    }
  });

  testWidgets('PlainPanel 卡片底 ≠ 页面底（「卡片消失」事故的守卫）', (tester) async {
    final tokens =
        resolveTokens(themeSpecOf(ThemeId.qingci), Brightness.light);
    final colors = AppColors.fromTokens(tokens);
    await tester.pumpWidget(MaterialApp(
      theme: buildThemeData(tokens, Brightness.light),
      home: const PlainPanel(children: [SizedBox(height: 20)]),
    ));
    final boxes =
        tester.widgetList<DecoratedBox>(find.byType(DecoratedBox)).toList();
    final panel = boxes
        .map((b) => b.decoration as BoxDecoration)
        .firstWhere((d) => d.borderRadius != null && d.color != null);
    expect(panel.color, colors.surfaceCard,
        reason: 'PlainPanel 必须用卡片底（surface/surfaceCard），'
            '涂成 pageBg 会让卡片和页面融为一体');
    expect(panel.color, isNot(colors.pageBg));
  });

  test('卡片透明度参数：0 → 与纸色同色，1 → 纯白，默认 0.6', () {
    for (final id in ThemeId.values) {
      final spec = themeSpecOf(id);
      final t0 = resolveTokens(spec, Brightness.light, cardOpacity: 0);
      final t1 = resolveTokens(spec, Brightness.light, cardOpacity: 1);
      final tD = resolveTokens(spec, Brightness.light);
      expect(_a(t0.surface), _a(t0.appBg),
          reason: '${spec.name} 透明度 0 时方框应与页面同色（方框消失）');
      expect(_a(t1.surface), 0xFFFFFFFF,
          reason: '${spec.name} 透明度 1 时应为纯白实心');
      expect(_a(tD.surface),
          cm.mix(_a(tD.appBg), 0xFFFFFFFF, kCardOpacityDefault),
          reason: '${spec.name} 默认必须是 white × $kCardOpacityDefault');
      // 暗色也走同一参数，但基色是「卡片色」而不是纯白：
      // 0 → 与页面同色；1 → 卡片本色（比页面亮，但绝不会变成纯白）。
      final d0 = resolveTokens(spec, Brightness.dark, cardOpacity: 0);
      final d1 = resolveTokens(spec, Brightness.dark, cardOpacity: 1);
      expect(_a(d0.surface), _a(d0.appBg),
          reason: '${spec.name}(暗) 透明度 0 时方框应与页面同色');
      expect(cm.lum(_a(d1.surface)) > cm.lum(_a(d0.surface)), isTrue,
          reason: '${spec.name}(暗) 透明度 1 应比 0 更接近卡片本色');
      expect(_a(d1.surface), isNot(0xFFFFFFFF),
          reason: '${spec.name}(暗) 暗色卡片不该被推到纯白');
    }
  });

  test('凸起面同色：surface2/card 与 surface 完全一致（白色 60% 口径）', () {
    // 用户口径（2026-10-20）：「所有方框的背景色全部改成白色 60% 透明度」。
    // 曾被指出的两次事故：记一笔页 chip(surface) 与键帽(surface2) 两种白；
    // 流水页与报表页卡片两种白。这支断言把「一个 app 只有一个卡片白」钉死。
    for (final id in ThemeId.values) {
      for (final isDark in [false, true]) {
        final t = resolveTokens(
            themeSpecOf(id), isDark ? Brightness.dark : Brightness.light);
        final c = AppColors.fromTokens(t);
        final mode = isDark ? '暗' : '亮';
        expect(_a(t.surface2), _a(t.surface),
            reason: '${themeSpecOf(id).name}($mode) surface2 ${_hex(_a(t.surface2))} '
                '≠ surface ${_hex(_a(t.surface))} —— 键帽/输入框会和卡片两个白');
        expect(_a(c.surfaceMuted), _a(t.surface),
            reason: '${themeSpecOf(id).name}($mode) surfaceMuted 必须等于卡片白');
        expect(_a(c.surfaceCard), _a(t.surface),
            reason: '${themeSpecOf(id).name}($mode) surfaceCard 必须等于卡片白');
        expect(_a(c.surface), _a(t.surface),
            reason: '${themeSpecOf(id).name}($mode) surface 必须等于卡片白');
      }
    }
  });

  test('页面底色 ≠ 卡片底色（否则「页面有主题色」等于没做）', () {
    for (final id in ThemeId.values) {
      for (final isDark in [false, true]) {
        final t = resolveTokens(
            themeSpecOf(id), isDark ? Brightness.dark : Brightness.light);
        expect(_a(t.appBg) != _a(t.surface), isTrue,
            reason: '${themeSpecOf(id).name} 页面底与卡片底同色');
        expect(_a(t.appBg) != _a(t.bg), isTrue,
            reason: '${themeSpecOf(id).name} appBg 与 bg 同色，滚动层与页面层分不开');
      }
    }
  });

  test('AppColors 桥接：surface=卡片底、pageBg=页面底（不许再混）', () {
    for (final id in ThemeId.values) {
      for (final isDark in [false, true]) {
        final t = resolveTokens(
            themeSpecOf(id), isDark ? Brightness.dark : Brightness.light);
        final c = AppColors.fromTokens(t);
        final mode = isDark ? '暗' : '亮';
        expect(_a(c.surface), _a(t.surface),
            reason: '${themeSpecOf(id).name}($mode) AppColors.surface 必须是卡片底 '
                't.surface —— 曾指到 t.appBg 导致全部卡片被涂成页面色');
        expect(_a(c.surfaceCard), _a(t.surface),
            reason: '${themeSpecOf(id).name}($mode) surfaceCard 必须是卡片底');
        expect(_a(c.pageBg), _a(t.appBg),
            reason: '${themeSpecOf(id).name}($mode) pageBg 必须是页面纸色 t.appBg');
        expect(_a(c.surface) != _a(c.pageBg), isTrue,
            reason: '${themeSpecOf(id).name}($mode) 卡片底与页面底同色，卡片会消失');
      }
    }
  });
}
