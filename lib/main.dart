/// SuJi (素记) - local-first minimal bookkeeping.
/// main() only bootstraps. See 04-8.2.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plain/app/bootstrap.dart';
import 'package:plain/app/l10n/app_strings.dart';
import 'package:plain/app/router/app_router.dart';
import 'package:plain/app/theme/design_tokens.dart';
import 'package:plain/app/theme/theme_prefs.dart';
import 'package:plain/app/theme/theme_resolver.dart';
import 'package:plain/core/id/uuid_v7.dart';
import 'package:plain/data/db/database.dart';
import 'package:plain/data/seed/preset_categories.dart';
import 'package:plain/features/security/app_lock_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  AppDatabase? db;
  AppDependencies? deps;

  try {
    // Startup: at most 2 awaits (DB handle + device meta). See 04-8.2.
    db = await AppDatabase.open();
    final meta = await ensureDeviceMeta(db, UuidV7());
    deps = buildDependencies(db: db, deviceId: meta.deviceId, bookId: meta.bookId);

    // Seed preset categories (idempotent).
    await seedPresetCategories(db, deps.clock);
  } catch (e, stack) {
    // If DB init fails, still show the app with an in-memory DB
    debugPrint('Startup init failed: $e');
    debugPrint('$stack');
    db ??= AppDatabase.inMemory();
    try {
      final meta = await ensureDeviceMeta(db, UuidV7());
      deps ??= buildDependencies(db: db, deviceId: meta.deviceId, bookId: meta.bookId);
    } catch (_) {
      deps ??= buildDependencies(db: db, deviceId: 'fallback-dev', bookId: 'fallback-book');
    }
  }

  runApp(
    ProviderScope(
      overrides: [appDependenciesProvider.overrideWithValue(deps)],
      child: const PlainApp(),
    ),
  );
}

class PlainApp extends ConsumerStatefulWidget {
  const PlainApp({super.key});
  @override
  ConsumerState<PlainApp> createState() => _PlainAppState();
}

class _PlainAppState extends ConsumerState<PlainApp> with WidgetsBindingObserver {
  late final _router = buildRouter();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Fire-and-forget: generate any due recurring entries + purge expired trash after first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(generateDueRecurringProvider)().ignore();
      ref.read(purgeTrashProvider)().ignore();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final lock = ref.read(appLockControllerProvider.notifier);
    switch (state) {
      case AppLifecycleState.paused:
        lock.onAppPaused();
      case AppLifecycleState.resumed:
        lock.onAppResumed();
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lockState = ref.watch(appLockControllerProvider);
    final prefs = ref.watch(themePrefsProvider);
    final platformBrightness = MediaQuery.platformBrightnessOf(context);

    final effectiveBrightness = resolveBrightness(prefs.themeMode, platformBrightness);

    // Update global BrandColors so all existing UI follows the theme.
    setActiveTheme(prefs.themeId, effectiveBrightness);

    final (_, lightTheme) = themeDataFor(prefs.themeId, Brightness.light);
    final (_, darkTheme) = themeDataFor(prefs.themeId, Brightness.dark);

    return MaterialApp.router(
      title: 'SuJi',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: prefs.themeMode,
      locale: const Locale('zh', 'CN'),
      localizationsDelegates: const [
        AppStrings.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppStrings.supportedLocales,
      routerConfig: _router,
      builder: (context, child) {
        if (lockState.isLocked) {
          return const KeyedSubtree(
            key: ValueKey('app-lock'),
            child: AppLockScreen(),
          );
        }
        return child ?? const SizedBox.shrink();
      },
    );
  }
}
