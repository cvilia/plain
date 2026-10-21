/// Theme preferences: local key-value storage. See 04-技术架构设计.md §16.1.
/// Keys: `pref.theme.id` (ThemeId), `pref.theme.mode` (ThemeMode),
/// `pref.theme.cardOpacity` (卡片底的白色占比，0–1，默认 [kCardOpacityDefault]).
/// Theme/appearance are local-only — never synced to cloud (INV-3).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plain/app/theme/theme_registry.dart';
import 'package:plain/app/theme/theme_resolver.dart';
import 'package:plain/core/refresh/data_invalidation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Storage keys ────────────────────────────────────────────────────────────
const String kPrefThemeId = 'pref.theme.id';
const String kPrefThemeMode = 'pref.theme.mode';
const String kPrefCardOpacity = 'pref.theme.cardOpacity';

/// Immutable preference snapshot. Never mutate in place — assign a new instance
/// so Riverpod listeners rebuild and the previous state stays clean.
class ThemePrefs {
  const ThemePrefs({
    this.themeId = ThemeId.subai,
    this.themeMode = ThemeMode.system,
    this.cardOpacity = kCardOpacityDefault,
  });

  final ThemeId themeId;
  final ThemeMode themeMode;

  /// 方框底色里「白」的占比：1.0 = 纯白实心，0.0 = 完全融入纸色（方框消失）。
  /// 见 `theme_resolver.dart` 的「卡片底预混」段。
  final double cardOpacity;

  Map<String, String> toJson() => {
    kPrefThemeId: themeId.id,
    kPrefThemeMode: themeMode.name,
    kPrefCardOpacity: cardOpacity.toString(),
  };

  static ThemePrefs fromJson(Map<String, String?> json) {
    final idRaw = json[kPrefThemeId];
    final modeRaw = json[kPrefThemeMode];
    return ThemePrefs(
      themeId: ThemeId.fromId(idRaw),
      themeMode: _parseMode(modeRaw),
      cardOpacity: _parseOpacity(json[kPrefCardOpacity]),
    );
  }

  /// 老版本没这个键 → 用默认值；脏数据/越界一律夹回 [0, 1]。
  static double _parseOpacity(String? v) {
    final d = double.tryParse(v ?? '');
    if (d == null || d.isNaN) return kCardOpacityDefault;
    return d.clamp(0.0, 1.0);
  }

  static ThemeMode _parseMode(String? v) {
    return switch (v) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }
}

// ─── Preload (first-frame must already know the saved theme, §5.2) ──────────

ThemePrefs? _preloaded;

/// Read prefs before `runApp`. Failures fall back to defaults — never block boot.
Future<void> preloadThemePrefs() async {
  try {
    final sp = await SharedPreferences.getInstance();
    _preloaded = ThemePrefs.fromJson({
      kPrefThemeId: sp.getString(kPrefThemeId),
      kPrefThemeMode: sp.getString(kPrefThemeMode),
      // 存的是 double（`setDouble`），读也必须 `getDouble`：
      // `getString` 对 double 键会抛类型错误。
      kPrefCardOpacity: sp.getDouble(kPrefCardOpacity)?.toString(),
    });
  } catch (_) {
    _preloaded = const ThemePrefs();
  }
}

/// Snapshot for tests / diagnostics.
ThemePrefs? get preloadedThemePrefs => _preloaded;

// ─── Riverpod providers ──────────────────────────────────────────────────────

class ThemePrefsNotifier extends Notifier<ThemePrefs> {
  @override
  ThemePrefs build() => _preloaded ?? const ThemePrefs();

  void setTheme(ThemeId id) {
    state = ThemePrefs(
      themeId: id,
      themeMode: state.themeMode,
      cardOpacity: state.cardOpacity,
    );
    ref.invalidateData.bumpTheme();
    _persist();
  }

  void setMode(ThemeMode mode) {
    state = ThemePrefs(
      themeId: state.themeId,
      themeMode: mode,
      cardOpacity: state.cardOpacity,
    );
    ref.invalidateData.bumpTheme();
    _persist();
  }

  /// 拖动滑杆时用 `persist: false`（每帧一次写盘没必要，且会抖），
  /// 松手（`onChangeEnd`）再 `persist: true` 落盘。
  void setCardOpacity(double value, {bool persist = true}) {
    final v = value.clamp(0.0, 1.0);
    if (v != state.cardOpacity) {
      state = ThemePrefs(
        themeId: state.themeId,
        themeMode: state.themeMode,
        cardOpacity: v,
      );
      ref.invalidateData.bumpTheme();
    }
    // ⚠️ 不能和上面一起 `return`：拖动用 `persist: false`，松手的 `onChangeEnd`
    // 传来的值与当前状态相同，若提前 return 就永远不会落盘。
    if (persist) _persist();
  }

  void load(Map<String, String?> saved) {
    state = ThemePrefs.fromJson(saved);
    ref.invalidateData.bumpTheme();
  }

  Future<void> _persist() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(kPrefThemeId, state.themeId.id);
      await sp.setString(kPrefThemeMode, state.themeMode.name);
      await sp.setDouble(kPrefCardOpacity, state.cardOpacity);
    } catch (_) {
      // Prefs are best-effort; in-memory state remains authoritative for the session.
    }
  }
}

final themePrefsProvider = NotifierProvider<ThemePrefsNotifier, ThemePrefs>(ThemePrefsNotifier.new);

/// Current theme ID (derived).
final currentThemeProvider = Provider<ThemeId>((ref) => ref.watch(themePrefsProvider).themeId);

/// Current theme mode (derived).
final currentThemeModeProvider = Provider<ThemeMode>((ref) => ref.watch(themePrefsProvider).themeMode);
