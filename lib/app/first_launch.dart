/// First-launch / onboarding gate. Local-only preference (not cloud-synced).
library;

import 'package:shared_preferences/shared_preferences.dart';

const String kPrefOnboardDone = 'pref.onboard.done';

/// True until the user finishes onboarding once.
Future<bool> isOnboardingPending() async {
  try {
    final sp = await SharedPreferences.getInstance();
    return !(sp.getBool(kPrefOnboardDone) ?? false);
  } catch (_) {
    // Fail open to the app — never block startup.
    return false;
  }
}

Future<void> markOnboardingDone() async {
  try {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(kPrefOnboardDone, true);
  } catch (_) {}
}
