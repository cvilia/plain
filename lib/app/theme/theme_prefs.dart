/// Theme preferences: local key-value storage. See 需求变更.md §5.
/// Keys: `pref.theme.id` (ThemeId), `pref.theme.mode` (ThemeMode).
/// Theme/appearance are local-only — never synced to cloud (INV-3).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plain/app/theme/theme_registry.dart';

// ─── Storage keys ────────────────────────────────────────────────────────────
const String kPrefThemeId = 'pref.theme.id';
const String kPrefThemeMode = 'pref.theme.mode';

// ─── In-memory preference store (backed by shared_preferences at launch) ─────

class ThemePrefs {
  ThemePrefs({this.themeId = ThemeId.qingci, this.themeMode = ThemeMode.system});

  ThemeId themeId;
  ThemeMode themeMode;

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

// ─── Riverpod providers ──────────────────────────────────────────────────────

class ThemePrefsNotifier extends Notifier<ThemePrefs> {
  @override
  ThemePrefs build() => ThemePrefs();

  void setTheme(ThemeId id) {
    state.themeId = id;
    state = ThemePrefs(themeId: id, themeMode: state.themeMode);
  }

  void setMode(ThemeMode mode) {
    state.themeMode = mode;
    state = ThemePrefs(themeId: state.themeId, themeMode: mode);
  }

  void load(Map<String, String?> saved) {
    state = ThemePrefs.fromJson(saved);
  }
}

final themePrefsProvider = NotifierProvider<ThemePrefsNotifier, ThemePrefs>(ThemePrefsNotifier.new);

/// Current theme ID (derived).
final currentThemeProvider = Provider<ThemeId>((ref) => ref.watch(themePrefsProvider).themeId);

/// Current theme mode (derived).
final currentThemeModeProvider = Provider<ThemeMode>((ref) => ref.watch(themePrefsProvider).themeMode);
