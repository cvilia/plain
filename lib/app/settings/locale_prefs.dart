/// 语言偏好：跟随系统 / 简体中文 / English。
///
/// 与主题一样是**本机外观偏好**（INV-3，不入同步）。
/// Keys: `pref.locale`（`system` / `zh` / `en`）。
///
/// 2026-10-19 起放开双语：英文文案早已随 `isZh ? :` 双分支写进各
/// strings 文件，这里只负责把选择接进 `MaterialApp.locale`。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kPrefLocale = 'pref.locale';

/// 用户可显式选择的语言。`system` 交给 MaterialApp 按 `supportedLocales`
/// 分辨率匹配（zh 系 → 中文，其余 → 英文）。
enum AppLanguage { system, zh, en }

/// 不可变快照。不要原地改 —— 赋新实例，Riverpod 监听才能重建。
class LanguagePrefs {
  const LanguagePrefs({this.language = AppLanguage.system});

  final AppLanguage language;

  /// `null` → MaterialApp 不锁 locale，走系统分辨率。
  Locale? get locale => switch (language) {
        AppLanguage.zh => const Locale('zh', 'CN'),
        AppLanguage.en => const Locale('en'),
        AppLanguage.system => null,
      };

  static AppLanguage _parse(String? v) => switch (v) {
        'zh' => AppLanguage.zh,
        'en' => AppLanguage.en,
        _ => AppLanguage.system,
      };
}

// ─── Preload（首帧就得知道语言，§5.2 同主题）──────────────────────────────────

LanguagePrefs? _preloaded;

/// `runApp` 前读偏好。失败回落默认值，绝不阻塞启动。
Future<void> preloadLanguagePrefs() async {
  try {
    final sp = await SharedPreferences.getInstance();
    _preloaded = LanguagePrefs(language: LanguagePrefs._parse(sp.getString(kPrefLocale)));
  } catch (_) {
    _preloaded = const LanguagePrefs();
  }
}

/// 测试 / 诊断快照。
LanguagePrefs? get preloadedLanguagePrefs => _preloaded;

// ─── Riverpod ────────────────────────────────────────────────────────────────

class LanguagePrefsNotifier extends Notifier<LanguagePrefs> {
  @override
  LanguagePrefs build() => _preloaded ?? const LanguagePrefs();

  void set(AppLanguage language) {
    state = LanguagePrefs(language: language);
    _persist();
  }

  Future<void> _persist() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(kPrefLocale, state.language.name);
    } catch (_) {
      // 偏好尽力而为；本会话以内存状态为准。
    }
  }
}

final languagePrefsProvider =
    NotifierProvider<LanguagePrefsNotifier, LanguagePrefs>(LanguagePrefsNotifier.new);
