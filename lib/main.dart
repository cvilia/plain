/// SuJi (素记) - local-first minimal bookkeeping.
/// main() only bootstraps. See 04-8.2.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plain/app/bootstrap.dart';
import 'package:plain/app/first_launch.dart';
import 'package:plain/app/l10n/app_strings.dart';
import 'package:plain/app/router/app_router.dart';
import 'package:plain/app/settings/display_prefs.dart';
import 'package:plain/app/settings/locale_prefs.dart';
import 'package:plain/app/theme/theme_prefs.dart';
import 'package:plain/app/theme/theme_resolver.dart';
import 'package:plain/core/id/uuid_v7.dart';
import 'package:plain/core/refresh/data_invalidation.dart';
import 'package:plain/data/db/database.dart';
import 'package:plain/data/platform/legacy_dir_cleanup.dart';
import 'package:plain/data/platform/platform_bridge.dart';
import 'package:plain/data/sync/sync_scheduler.dart';
import 'package:plain/data/seed/default_account.dart';
import 'package:plain/data/seed/preset_categories.dart';
import 'package:plain/features/security/app_lock_prefs.dart';
import 'package:plain/features/security/app_lock_screen.dart';
import 'package:plain/features/settings/onboarding_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Theme prefs must be known before first frame (§5.2). Failure → defaults.
  await preloadThemePrefs();
  await preloadDisplayPrefs();
  await preloadLanguagePrefs();
  final appLock = await AppLockPrefs.load();
  final onboardPending = await isOnboardingPending();

  AppDatabase? db;
  AppDependencies? deps;

  try {
    // Startup: at most 2 awaits (DB handle + device meta). See 04-8.2.
    db = await AppDatabase.open();
    final meta = await ensureDeviceMeta(db, UuidV7());
    deps = buildDependencies(db: db, deviceId: meta.deviceId, bookId: meta.bookId);

    // 种子延后到首帧之后，不阻塞启动（幂等，仅空表时写入）。
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

  // 用具名 container（而不是 ProviderScope）：首帧后的补种子/补预设要能自己
  // 抬一下版本号 —— 否则已经加载完的读模型（记账页的分类宫格就是第一个）
  // 看不到新写进去的分类，得等下次启动。
  final container = ProviderContainer(
    overrides: [appDependenciesProvider.overrideWithValue(deps)],
  );
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: PlainApp(showOnboarding: onboardPending, appLockInitiallyEnabled: appLock.isConfigured),
    ),
  );
  // 08-§8 巡检 + 06-C3 change_log GC 不阻塞首帧，空闲后再跑。
  // 首帧后补种子（幂等），不挡启动
  final dbRef = db;
  final depsRef = deps;
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    try {
      // ignore: unnecessary_null_comparison
      if (dbRef != null && depsRef != null) {
        await seedPresetCategories(dbRef, depsRef.clock);
        // 后加的预设分类（老库按主键补插，幂等）
        await backfillPresetCategories(dbRef, depsRef.clock);
        // 上面两步都可能写入分类 → 抬版本，让宫格/选择器立刻刷新
        container.read(dataInvalidationProvider.notifier).bumpCategoriesMutated();
        await seedDefaultAccount(dbRef, depsRef.clock);
        // STORY-8.2：首次登记「我」（所有者），幂等
        await depsRef.memberService
            .ensureMe(bookId: depsRef.bookId, deviceId: depsRef.deviceId);
        unawaited(runDailyStatsIntegrityCheck(depsRef));
        unawaited(runChangeLogGc(depsRef));
        unawaited(runWeeklyReportPush(depsRef));
        // 已下线功能的历史目录清理：附件（表在 DB 迁移里 DROP）
        // + 自定义分类图标（`icon_asset` 在迁移里清空）
        unawaited(purgeAttachmentDirectory());
        unawaited(purgeCustomIconDirectory());
        // 目标「已存」计数按账本重算（撤销/生成中途失败留下的漂移）
        unawaited(runGoalCounterReconcile(depsRef));
        // STORY-6.3：启动扫一次九类提醒（含夜间降级的次日 08:00 汇总）
        unawaited(runReminderScan(depsRef));
      }
    } catch (_) {}
  });
}

class PlainApp extends ConsumerStatefulWidget {
  const PlainApp({super.key, this.showOnboarding = false, this.appLockInitiallyEnabled = false});
  final bool showOnboarding;
  final bool appLockInitiallyEnabled;

  @override
  ConsumerState<PlainApp> createState() => _PlainAppState();
}

class _PlainAppState extends ConsumerState<PlainApp> with WidgetsBindingObserver {
  late final _router = buildRouter();
  late bool _onboarding = widget.showOnboarding;
  late final bool _appLockReady = widget.appLockInitiallyEnabled;

  /// STORY-8.1：前台增量同步调度（写后即推 + 每 10 秒轮询拉取）。
  late final SyncScheduler _syncScheduler = SyncScheduler(
    readConfig: () {
      final deps = ref.read(appDependenciesProvider);
      return syncConfigIfEnabled(deps.db);
    },
    runSync: (config) async {
      final deps = ref.read(appDependenciesProvider);
      final service = buildIncrementalSync(deps, config);
      try {
        return await service.syncNow(config);
      } finally {
        service.dispose();
      }
    },
    // 拉到的变更要立刻反映到界面（口径仍走 bump/watch，不手动 refresh 页面）
    onResult: (result) {
      if (!result.changed && result.conflicts == 0) return;
      ref.invalidateData.bumpAll(const {
        DataScope.ledger,
        DataScope.accounts,
        DataScope.categories,
        DataScope.budget,
        DataScope.recurring,
      });
    },
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(appLockEnabledProvider.notifier).set(_appLockReady);
    });
    // Fire-and-forget: generate any due recurring entries + purge expired trash after first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(generateDueRecurringProvider)(s: AppStrings.of(context)).ignore();
      ref.read(purgeTrashProvider)().ignore();
    });
    // 本地写入 → 安排一次推送（唯一触发点，见 DataInvalidation.bump）
    DataInvalidation.localMutationHook = _syncScheduler.notifyLocalMutation;
    _syncScheduler.start();
  }

  @override
  void dispose() {
    DataInvalidation.localMutationHook = null;
    _syncScheduler.stop();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final lock = ref.read(appLockControllerProvider.notifier);
    switch (state) {
      case AppLifecycleState.paused:
        // 切后台：仅应用锁打码，不禁截屏
        final lockEnabled = ref.read(appLockEnabledProvider);
        if (lockEnabled) {
          PlatformBridge.setPrivacyOverlay(true);
        }
        lock.onAppPaused();
        // 后台不停轮询（省电；回到前台会立刻补一轮）
        _syncScheduler.stop();
      case AppLifecycleState.resumed:
        PlatformBridge.setPrivacyOverlay(false);
        lock.onAppResumed();
        // STORY-9.5：回到前台再检查一次周报推送（离线无后台唤醒，靠启动/回前台补发）
        unawaited(runWeeklyReportPush(ref.read(appDependenciesProvider)));
        // STORY-6.3：同理，回前台再扫一次提醒（不新增常驻轮询）
        unawaited(runReminderScan(ref.read(appDependenciesProvider)));
        _syncScheduler.start();
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lockState = ref.watch(appLockControllerProvider);
    final prefs = ref.watch(themePrefsProvider);
    final languagePrefs = ref.watch(languagePrefsProvider);



    final (_, lightTheme) = themeDataFor(prefs.themeId, Brightness.light);
    final (_, darkTheme) = themeDataFor(prefs.themeId, Brightness.dark);

    // First launch: full-screen onboarding (SP-0-01), no shell chrome.
    if (_onboarding) {
      return MaterialApp(
        title: 'SuJi',
        debugShowCheckedModeBanner: false,
        theme: lightTheme,
        darkTheme: darkTheme,
        themeMode: prefs.themeMode,
        locale: languagePrefs.locale,
        localizationsDelegates: const [
          AppStrings.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppStrings.supportedLocales,
        home: OnboardingPage(
          onDone: () async {
            await markOnboardingDone();
            if (mounted) setState(() => _onboarding = false);
          },
        ),
      );
    }

    return MaterialApp.router(
      title: 'SuJi',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: prefs.themeMode,
      // locale 为 null（跟随系统）时交给 MaterialApp 按 supportedLocales 分辨。
      locale: languagePrefs.locale,
      localizationsDelegates: const [
        AppStrings.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppStrings.supportedLocales,
      routerConfig: _router,
      builder: (context, child) {
        final display = ref.watch(displayPrefsProvider);
        final scaled = MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(display.fontScale)),
          child: child ?? const SizedBox.shrink(),
        );
        if (!lockState.isLocked) return scaled;
        // ⚠️ 锁屏必须「叠」在树上，不能把 child 摘掉。
        //
        // child 就是整个 Router（含 go_router 的每一个 Navigator），而 go_router
        // 的 Navigator 是用 `GlobalObjectKey(navigatorKey.hashCode)` 保活的
        // （go_router/src/builder.dart）。摘掉 child 会把 Router 子树整体卸载，
        // 解锁时装回去时旧元素还在 _inactiveElements 里 → GlobalKey 被「重挂」，
        // 连锁炸出 InheritedGoRouter / _ScaffoldMessengerScope / Theme 一堆断言。
        // 叠起来则 Router 原地保留，页面状态也不丢。
        return Stack(
          fit: StackFit.expand,
          children: [
            // 保挂载、不绘制、不响应点击：锁屏期间内容既不可见也不可点。
            Offstage(
              child: TickerMode(enabled: false, child: scaled),
            ),
            const KeyedSubtree(
              key: ValueKey('app-lock'),
              child: AppLockScreen(),
            ),
          ],
        );
      },
    );
  }
}
