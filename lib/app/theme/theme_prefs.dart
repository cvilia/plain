/// Theme preferences: local key-value storage. See 需求变更.md §5.
/// Keys: `pref.theme.id` (ThemeId), `pref.theme.mode` (ThemeMode).
/// Theme/appearance are local-only — never synced to cloud (INV-3).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plain/app/theme/theme_registry.dart';
import 'package:plain/core/refresh/data_invalidation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Storage keys ────────────────────────────────────────────────────────────
const String kPrefThemeId = 'pref.theme.id';
const String kPrefThemeMode = 'pref.theme.mode';

/// Immutable preference snapshot. Never mutate in place — assign a new instance
/// so Riverpod listeners rebuild and the previous state stays clean.
class ThemePrefs {
  const ThemePrefs({
    this.themeId = ThemeId.qingci,
    this.themeMode = ThemeMode.system,
  });

  final ThemeId themeId;
  final ThemeMode themeMode;

  Map<String, String> toJson() => {
    kPrefThemeId: themeId.id,
    kPrefThemeMode: themeMode.name,
  };

  static ThemePrefs fromJson(Map<String, String?> json) {
    final idRaw = json[kPrefThemeId];
    final modeRaw = json[kPrefThemeMode];
    return ThemePrefs(
      themeId: ThemeId.fromId(idRaw),
      themeMode: _parseMode(modeRaw),
    );
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
    state = ThemePrefs(themeId: id, themeMode: state.themeMode);
    ref.invalidateData.bumpTheme();
    _persist();
  }

  void setMode(ThemeMode mode) {
    state = ThemePrefs(themeId: state.themeId, themeMode: mode);
    ref.invalidateData.bumpTheme();
    _persist();
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
