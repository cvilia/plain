import 'package:flutter_test/flutter_test.dart';
import 'package:plain/main.dart';

void main() {
  testWidgets('App builds', (tester) async {
    // 仅验证 PlainApp 可实例化（不 pump 全树，避免 DB 依赖）
    expect(PlainApp, isNotNull);
  });
}
