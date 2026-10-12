/// Smoke tests: app shell actually builds and shows primary navigation.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plain/app/bootstrap.dart';
import 'package:plain/data/db/database.dart';
import 'package:plain/main.dart';
import 'package:plain/features/ledger/presentation/home_shell.dart';

Widget _app({required bool onboarding}) {
  final db = AppDatabase.inMemory();
  final deps = buildDependencies(
    db: db,
    deviceId: 'test-device',
    bookId: 'test-book',
  );
  return ProviderScope(
    overrides: [appDependenciesProvider.overrideWithValue(deps)],
    child: PlainApp(
      showOnboarding: onboarding,
      appLockInitiallyEnabled: false,
    ),
  );
}

void main() {
  testWidgets('PlainApp smoke: phone shell + bottom nav render', (tester) async {
    // Phone portrait so compact layout (NavigationBar) is used.
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_app(onboarding: false));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('流水'), findsAtLeastNWidgets(1)); // AppBar + NavigationBar
    expect(find.text('报表'), findsOneWidget);
    expect(find.text('资产'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);

    // FAB is the "记一笔" entry point (must carry a heroTag).
    expect(find.byType(EntryAppBarAction), findsOneWidget);
  });

  testWidgets('PlainApp smoke: wide shell uses NavigationRail', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_app(onboarding: false));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('PlainApp smoke: onboarding replaces shell chrome', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_app(onboarding: true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(NavigationRail), findsNothing);
  });
}
