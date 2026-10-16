import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plain/design_system/plain_icons_v3.dart';

void main() {
  testWidgets('every v3 icon loads via flutter_svg', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Wrap(
            children: [
              for (final icon in PlainIconData.all)
                SizedBox(
                  width: 32,
                  height: 32,
                  child: PlainIcon(icon, size: 24, color: Colors.black),
                ),
            ],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull);
    expect(find.byType(SvgPicture), findsNWidgets(PlainIconData.all.length));
  });

  test('asset paths point at assets/icons', () {
    for (final icon in PlainIconData.all) {
      expect(icon.assetPath, startsWith('assets/icons/ic_'));
      expect(icon.assetPath, endsWith('.svg'));
    }
  });
}
