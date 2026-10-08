/// App lock persistence. Local-only (INV-3 style: never cloud-synced).
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kPrefAppLockEnabled = 'pref.applock.enabled';
const String kPrefAppLockPinHash = 'pref.applock.pin_hash';
const String kPrefAppLockBiometric = 'pref.applock.biometric';

/// Hash PIN before storage — never persist plaintext.
String hashPin(String pin) => sha256.convert(utf8.encode('sujilock:$pin')).toString();

class AppLockPrefs {
  AppLockPrefs({
    required this.enabled,
    required this.pinHash,
    required this.biometricEnabled,
  });

  final bool enabled;
  final String? pinHash;
  final bool biometricEnabled;

  /// Lock is only meaningful when enabled AND a PIN exists.
  bool get isConfigured => enabled && pinHash != null && pinHash!.isNotEmpty;

  static Future<AppLockPrefs> load() async {
    try {
      final sp = await SharedPreferences.getInstance();
      return AppLockPrefs(
        enabled: sp.getBool(kPrefAppLockEnabled) ?? false,
        pinHash: sp.getString(kPrefAppLockPinHash),
        biometricEnabled: sp.getBool(kPrefAppLockBiometric) ?? false,
      );
    } catch (_) {
      return AppLockPrefs(enabled: false, pinHash: null, biometricEnabled: false);
    }
  }

  static Future<void> savePin({required String pinHash, bool biometric = false}) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(kPrefAppLockPinHash, pinHash);
    await sp.setBool(kPrefAppLockBiometric, biometric);
    await sp.setBool(kPrefAppLockEnabled, true);
  }

  static Future<void> setBiometric(bool value) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(kPrefAppLockBiometric, value);
  }

  static Future<void> disable() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(kPrefAppLockEnabled, false);
    await sp.remove(kPrefAppLockPinHash);
    await sp.remove(kPrefAppLockBiometric);
  }

  static bool verifyPin(String pin, String? pinHash) {
    if (pinHash == null || pinHash.isEmpty) return false;
    return hashPin(pin) == pinHash;
  }
}
