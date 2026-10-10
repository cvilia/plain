/// Local notification bridge (no third-party notify plugin).
library;

import 'package:flutter/services.dart';

class NotificationBridge {
  static const MethodChannel _channel = MethodChannel('app/notification');

  /// Android 13+ needs notification permission before showing.
  static Future<bool> requestPermission() async {
    try {
      final ok = await _channel.invokeMethod<bool>('requestPermission');
      return ok ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Show a local notification. [id] replaces an existing one with the same id.
  /// [silent] true → 仅进通知中心（G-3 静默）；false → 响铃通道。
  static Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
    bool silent = false,
  }) async {
    try {
      await _channel.invokeMethod<void>('show', {
        'id': id,
        'title': title,
        'body': body,
        'payload': payload,
        'silent': silent,
      });
    } on PlatformException {
      // ignore — notifications are best-effort
    } on MissingPluginException {
      // ignore
    }
  }

  static Future<void> cancel(int id) async {
    try {
      await _channel.invokeMethod<void>('cancel', {'id': id});
    } on PlatformException {
      // ignore
    } on MissingPluginException {
      // ignore
    }
  }
}
