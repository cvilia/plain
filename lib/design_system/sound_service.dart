/// 记一笔音效：音效开关打开时播放 coin 声，关闭时不播放。
library;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plain/app/settings/display_prefs.dart';

class _SoundService {
  static AudioPlayer? _player;
  static bool _initFailed = false;

  /// 懒加载 AudioPlayer，避免启动时初始化阻塞。
  static AudioPlayer? _getOrCreatePlayer() {
    if (_initFailed) return null;
    if (_player != null) return _player;
    try {
      _player = AudioPlayer();
      return _player;
    } catch (_) {
      _initFailed = true;
      return null;
    }
  }

  /// 播放记一笔音效（仅在音效开关打开时）。
  static Future<void> playEntrySaved(BuildContext context) async {
    try {
      final container = ProviderScope.containerOf(context);
      final enabled = container.read(displayPrefsProvider).soundEnabled;
      if (!enabled) return;
      final player = _getOrCreatePlayer();
      if (player == null) return;
      await player.stop();
      await player.play(AssetSource('audio/sfx_play_coin.wav'));
    } catch (_) {
      // 音效失败不影响业务
    }
  }
}

/// 记一笔音效播放（外部调用）。
Future<void> playEntrySavedSound(BuildContext context) => _SoundService.playEntrySaved(context);
