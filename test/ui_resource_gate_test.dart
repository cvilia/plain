/// 图标资源门禁（v3：flutter_svg + assets/icons/）。
///
/// 旧版针对 PlainIcons 字体（323 枚 IconData）的断言已随字体库一并移除；
/// 这里守住「资产路径」「12 个一级分类可解析」「未知 ref 静默回落」三件事。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:plain/design_system/category_icon_v3.dart';
import 'package:plain/design_system/category_icons.dart';
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

  test('12 个一级分类 ref 都解析到对应图标', () {
    const expected = {
      'food': PlainIconData.catFood,
      'grocery': PlainIconData.catGrocery,
      'shopping': PlainIconData.catShopping,
      'daily': PlainIconData.catDaily,
      'transport': PlainIconData.catTransport,
      'housing': PlainIconData.catHousing,
      'telecom': PlainIconData.catTelecom,
      'entertainment': PlainIconData.catEntertainment,
      'medical': PlainIconData.catMedical,
      'study': PlainIconData.catStudy,
      'social': PlainIconData.catSocial,
      'other': PlainIconData.catOther,
    };
    expected.forEach((ref, icon) {
      expect(plainIconForRef(ref), icon, reason: 'ref `$ref` 映射错了');
    });
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
