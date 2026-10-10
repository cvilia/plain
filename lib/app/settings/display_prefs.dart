/// 用户可调显示/交互偏好（STORY-5.1 / F9.1）。
/// 本地偏好，不参与云同步（与主题一致，INV-3）。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kPrefFontScale = 'pref.font_scale';
const String kPrefSoundEnabled = 'pref.sound_enabled';
const String kPrefStayAfterSave = 'pref.stay_after_save';

/// 字号三档：0.9 / 1.0 / 1.15（对应小 / 标准 / 大）。
const List<double> kFontScales = [0.9, 1.0, 1.15];
const List<String> kFontScaleLabels = ['小', '标准', '大'];

class DisplayPrefs {
  const DisplayPrefs({
    this.fontScaleIndex = 1,
    this.soundEnabled = false,
    this.stayAfterSave = true,
  });

  /// 索引进 [kFontScales]。
  final int fontScaleIndex;
  final bool soundEnabled;
  final bool stayAfterSave;

  double get fontScale => kFontScales[fontScaleIndex.clamp(0, kFontScales.length - 1)];
}

int _preloadedFontScale = 1;
bool _preloadedSound = false;
bool _preloadedStay = true;

Future<void> preloadDisplayPrefs() async {
  try {
    final sp = await SharedPreferences.getInstance();
    _preloadedFontScale = sp.getInt(kPrefFontScale) ?? 1;
    _preloadedSound = sp.getBool(kPrefSoundEnabled) ?? false;
    _preloadedStay = sp.getBool(kPrefStayAfterSave) ?? true;
  } catch (_) {}
}

class DisplayPrefsNotifier extends Notifier<DisplayPrefs> {
  @override
  DisplayPrefs build() => DisplayPrefs(
        fontScaleIndex: _preloadedFontScale,
        soundEnabled: _preloadedSound,
        stayAfterSave: _preloadedStay,
      );

  void setFontScaleIndex(int index) {
    state = DisplayPrefs(
      fontScaleIndex: index.clamp(0, kFontScales.length - 1),
      soundEnabled: state.soundEnabled,
      stayAfterSave: state.stayAfterSave,
    );
    _persist();
  }

  void setSoundEnabled(bool v) {
    state = DisplayPrefs(
      fontScaleIndex: state.fontScaleIndex,
      soundEnabled: v,
      stayAfterSave: state.stayAfterSave,
    );
    _persist();
  }

  void setStayAfterSave(bool v) {
    state = DisplayPrefs(
      fontScaleIndex: state.fontScaleIndex,
      soundEnabled: state.soundEnabled,
      stayAfterSave: v,
    );
    _persist();
  }

  Future<void> _persist() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setInt(kPrefFontScale, state.fontScaleIndex);
      await sp.setBool(kPrefSoundEnabled, state.soundEnabled);
      await sp.setBool(kPrefStayAfterSave, state.stayAfterSave);
    } catch (_) {}
  }
}

final displayPrefsProvider =
    NotifierProvider<DisplayPrefsNotifier, DisplayPrefs>(DisplayPrefsNotifier.new);
