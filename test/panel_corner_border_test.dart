/// 面板圆角边框的像素契约。
///
/// 背景：`Container` 的组装顺序是
///   `DecoratedBox(边框+填充)` → `Padding(border 的 1px 内缩)` → `ClipPath` → 子级，
/// 而 `ClipPath` 按**整个** rect 取半径。子级只被推了 1px、四角仍是直角，
/// 于是行里的不透明白底（如 `_EntryRow` 的 `Material(color: surfaceCard)`）会在弧上
/// 盖住那 1px 边框：直边和弧的两端完好，中段（约 20°–70°）消失，看上去像「卡片没有圆角」。
///
/// 修法：子级再套一层**同心**内圆弧裁剪（半径 16 − 1 = 15），切在边框内沿上。
///
/// 这组断言就是为它设的门禁：四段圆弧的中段必须能取到边框本色 (#E4E4E8)。
/// `_DayPanel`（`flow_list_page.dart`）是同一个修法，但它要起 DB 才有数据，这里不重复搭台。
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plain/app/theme/app_colors.dart';
import 'package:plain/app/theme/theme_registry.dart';
import 'package:plain/app/theme/theme_resolver.dart';
import 'package:plain/design_system/plain_ui.dart';

/// 面板圆角；边框 1px（`.panel{radius:16;border:1px}`）。
const double _r = 16;
const double _border = 1;

/// 半径 r 的弧上 45° 点，离角 r·(1 − √2/2)。
const double _arc45 = 1 - 0.7071067811865476;

/// 3× 取样：柱状图和手机都是 2×~3×，1× 下取不到边框的中间调。
const double _dpr = 3;

/// 边框本色 #E4E4E8 的亮度 ≈ 229，页面底 #FBFBFC ≈ 251，卡片白 255。
/// 取 236 当门限：修好后实测 229，退化后是 245+，两边都留足余量。
const double _borderLumMax = 236;

ThemeData _theme() => buildThemeData(
  resolveTokens(themeSpecOf(ThemeId.subai), Brightness.light),
  Brightness.light,
);

/// 面板里放「自带白底的行」—— 这正是会盖住边框的写法，所以拿它当回归用例。
Widget _opaqueRow(Color cardColor) =>
    Material(color: cardColor, child: const SizedBox(height: 60));

double _lum(ByteData data, int width, int x, int y) {
  final i = (y * width + x) * 4;
  return (data.getUint8(i) + data.getUint8(i + 1) + data.getUint8(i + 2)) / 3;
}

/// 以 [cx],[cy] 为中心扫 ±[radius] 范围内最暗的像素。
double _darkest(ByteData data, int width, int height, double cx, double cy,
    {int radius = 3}) {
  var best = 255.0;
  for (var y = (cy - radius).round(); y <= (cy + radius).round(); y++) {
    for (var x = (cx - radius).round(); x <= (cx + radius).round(); x++) {
      if (x < 0 || y < 0 || x >= width || y >= height) continue;
      final v = _lum(data, width, x, y);
      if (v < best) best = v;
    }
  }
  return best;
}

void main() {
  testWidgets('PlainPanel：行自带白底时，四段圆弧的中段仍取得到 1px 边框', (tester) async {
    final colors = _theme().extension<AppColors>()!;
    final key = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        theme: _theme(),
        home: Center(
          child: RepaintBoundary(
            key: key,
            child: ColoredBox(
              color: colors.surface,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: 361,
                  child: PlainPanel(
                    children: [
                      _opaqueRow(colors.surfaceCard),
                      _opaqueRow(colors.surfaceCard),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final boundary =
        tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
    final image = await tester.runAsync(
      () => boundary.toImage(pixelRatio: _dpr),
    );
    final data = await tester.runAsync(
      () => image!.toByteData(format: ui.ImageByteFormat.rawRgba),
    );
    if (image == null || data == null) {
      fail('取样失败：toImage / toByteData 返回了 null');
    }

    // 面板位置换算到图像像素：boundary 的左上角是 (0,0)。
    final boundaryRect = tester.getRect(find.byKey(key));
    final panelRect = tester.getRect(find.byType(PlainPanel));
    final origin = (panelRect.topLeft - boundaryRect.topLeft) * _dpr;
    final w = image.width;
    final h = image.height;
    final r = _r * _dpr;
    final inset = r * _arc45;

    double at(double x, double y) =>
        _darkest(data, w, h, origin.dx + x, origin.dy + y);

    final corners = <String, Offset>{
      '左上': Offset(inset, inset),
      '右上': Offset(panelRect.width * _dpr - inset, inset),
      '左下': Offset(inset, panelRect.height * _dpr - inset),
      '右下': Offset(
        panelRect.width * _dpr - inset,
        panelRect.height * _dpr - inset,
      ),
    };

    for (final entry in corners.entries) {
      final lum = at(entry.value.dx, entry.value.dy);
      expect(
        lum,
        lessThanOrEqualTo(_borderLumMax),
        reason: '${entry.key}圆角：弧上取不到 1px 边框（最暗亮度 $lum，'
            '边框本色 229 / 页面底 251）。子级的白底又把边框盖住了 —— '
            '检查圆角裁剪半径是不是 16 − 边框宽（$_border）',
      );
    }
  });
}
