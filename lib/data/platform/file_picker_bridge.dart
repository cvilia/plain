/// Minimal file-picker over MethodChannel (no file_picker plugin).
///
/// Android uses ACTION_GET_CONTENT; the native side copies the picked
/// content URI into the app cache so Dart gets a readable file path.
library;

import 'dart:io';

import 'package:flutter/services.dart';

class FilePickerBridge {
  static const MethodChannel _channel = MethodChannel('app/file_picker');

  /// Opens the system picker. Returns a local file path or null if cancelled.
  ///
  /// [mime] e.g. `*/*`, `application/octet-stream`, `application/vnd.sqlite3`.
  /// [mimeTypes] 用于多类型白名单（STORY-1.5：jpg/png/heic/pdf 一起选）。
  static Future<String?> pickFile({
    String mime = '*/*',
    String? extension,
    List<String> mimeTypes = const [],
  }) async {
    try {
      final result = await _channel.invokeMethod<String>('pickFile', {
        'mime': mime,
        'extension': extension,
        'mimeTypes': mimeTypes,
      });
      if (result == null || result.isEmpty) return null;
      final file = File(result);
      return await file.exists() ? result : null;
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
