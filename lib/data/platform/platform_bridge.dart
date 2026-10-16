/// Platform channel contracts. See 04-7.
/// Only raw types across boundary: String / int / `Map<String, Object?>`.
library;

import 'package:flutter/services.dart';

/// Widget snapshot contract (frozen fields).
class WidgetSnapshot {
  const WidgetSnapshot({
    required this.monthExpenseCents,
    required this.monthIncomeCents,
    required this.entryCount,
    required this.updatedAtMs,
  });

  final int monthExpenseCents;
  final int monthIncomeCents;
  final int entryCount;
  final int updatedAtMs;

  Map<String, Object?> toJson() => {
        'monthExpenseCents': monthExpenseCents,
        'monthIncomeCents': monthIncomeCents,
        'entryCount': entryCount,
        'updatedAtMs': updatedAtMs,
      };
}

/// Platform bridge for widget updates and security flags.
class PlatformBridge {
  static const MethodChannel _widgetChannel = MethodChannel('app/widget');
  static const MethodChannel _securityChannel = MethodChannel('app/security');

  /// Push snapshot to native widgets (1x4, 2x2).
  static Future<void> updateWidgetSnapshot(WidgetSnapshot snapshot) async {
    try {
      await _widgetChannel.invokeMethod('updateSnapshot', snapshot.toJson());
    } on PlatformException {
      // Widget bridge not available on this platform (e.g. tests)
    }
  }

  /// Trigger widget timeline reload (iOS WidgetKit / Android AppWidget).
  static Future<void> reloadWidgetTimelines() async {
    try {
      await _widgetChannel.invokeMethod('reloadTimelines');
    } on PlatformException {
      // Not available
    }
  }

  /// 已禁用：允许截图/录屏，不再设置 FLAG_SECURE。
  static Future<void> setSecureFlag(bool enabled) async {}

  /// Set iOS privacy overlay (covers content when backgrounded).
  static Future<void> setPrivacyOverlay(bool enabled) async {
    try {
      await _securityChannel.invokeMethod('setPrivacyOverlay', enabled);
    } on PlatformException {
      // Not available
    }
  }

  /// Get initial intent route (from widget tap / deep link).
  static Future<String?> getInitialIntent() async {
    try {
      final result = await _widgetChannel.invokeMethod<String>('initialIntent');
      return result;
    } on PlatformException {
      return null;
    }
  }
}

/// Snapshot builder: queries DB and builds widget snapshot.
class SnapshotBuilder {
  static WidgetSnapshot build({
    required int monthExpenseCents,
    required int monthIncomeCents,
    required int entryCount,
  }) {
    return WidgetSnapshot(
      monthExpenseCents: monthExpenseCents,
      monthIncomeCents: monthIncomeCents,
      entryCount: entryCount,
      updatedAtMs: DateTime.now().toUtc().millisecondsSinceEpoch,
    );
  }
}
