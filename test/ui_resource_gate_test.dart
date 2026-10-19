/// 图标资源门禁（v3：flutter_svg + assets/icons/）。
///
/// 旧版针对 PlainIcons 字体（323 枚 IconData）的断言已随字体库一并移除；
/// 这里守住「资产路径」「12 个一级分类可解析」「未知 ref 静默回落」三件事。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:plain/design_system/category_icon_v3.dart';
import 'package:plain/data/seed/preset_categories.dart';
import 'package:plain/design_system/category_icons.dart';
import 'package:plain/design_system/category_icon_picker.dart';
import 'package:plain/design_system/plain_icons_v3.dart';

void main() {
  test('每枚图标的 assetPath 都落在 assets/icons/ic_*.svg', () {
    expect(PlainIconData.all, isNotEmpty);
    for (final d in PlainIconData.all) {
      expect(d.assetPath, startsWith('assets/icons/ic_'),
          reason: '${d.name} 的资产路径不合规');
      expect(d.assetPath, endsWith('.svg'));
    }
  });

  test('byName 与常量表一一对应', () {
    expect(PlainIconData.byName.length, PlainIconData.all.length);
    for (final d in PlainIconData.all) {
      expect(PlainIconData.byName[d.name], same(d));
    }
  });

  test('30 个支出一级分类的 ref 都解析到**互不相同**的图标', () {
    final icons = <String>{};
    for (final cat in presetExpenseCategories) {
      final icon = plainIconForRef(cat.iconRef);
      expect(icon, isNotNull, reason: 'ref `${cat.iconRef}` 映射错了');
      expect(icons.add(icon!.name), isTrue,
          reason: '${cat.name} 与其他一级分类用了同一枚图标（${icon.name}）');
    }
    expect(icons.length, 30);
  });

  test('30 个一级分类用到的 SVG 资产真实存在', () {
    for (final cat in presetExpenseCategories) {
      final icon = plainIconForRef(cat.iconRef)!;
      final f = File('assets/icons/${icon.name}.svg');
      expect(f.existsSync(), isTrue, reason: '${cat.name} 的图标文件缺失：${f.path}');
    }
  });

  test('图标选择器：31 枚分类图标 + 12 枚收入通用图标 = 43', () {
    final names =
        kPickerCategoryIconRefs.map((r) => plainIconForRef(r)!.name).toSet();
    expect(names.where((n) => n.startsWith('ic_cat_')).length, 31);
    expect(names.length, 43);
  });

  test('分类选择清单里的 ref 都不抛异常', () {
    for (final ref in kAllCategoryIconRefs) {
      expect(() => plainIconForRef(ref), returnsNormally,
          reason: 'ref `$ref` 让解析器炸了');
    }
  });

  test('未知 ref 返回 null —— 由 CategoryIcon 回落到「其他」', () {
    expect(plainIconForRef('__不存在的_ref__'), isNull);
  });
}
