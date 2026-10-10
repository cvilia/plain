/// App lock: biometric + PIN. See PRD STORY-4.2.
/// Lock ONLY when enabled and a PIN has been set (isConfigured).
library;

import 'package:plain/app/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:plain/app/theme/design_tokens.dart';
import 'package:plain/features/security/app_lock_prefs.dart';

/// Runtime enable flag (mirrors persisted prefs after preload).
class AppLockEnabledNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

final appLockEnabledProvider =
    NotifierProvider<AppLockEnabledNotifier, bool>(AppLockEnabledNotifier.new);

class AppLockState {
  const AppLockState({this.isLocked = false, this.failedAttempts = 0, this.biometricAllowed = true});

  final bool isLocked;
  final int failedAttempts;
  final bool biometricAllowed;

  AppLockState copyWith({bool? isLocked, int? failedAttempts, bool? biometricAllowed}) {
    return AppLockState(
      isLocked: isLocked ?? this.isLocked,
      failedAttempts: failedAttempts ?? this.failedAttempts,
      biometricAllowed: biometricAllowed ?? this.biometricAllowed,
    );
  }
}

class AppLockController extends Notifier<AppLockState> {
  DateTime? _backgroundedAt;

  static const int maxAttempts = 3;
  static const Duration backgroundLockDelay = Duration(seconds: 30);

  @override
  AppLockState build() => const AppLockState();

  void onAppPaused() {
    _backgroundedAt = DateTime.now();
  }

  void onAppResumed() {
    final bgAt = _backgroundedAt;
    _backgroundedAt = null;
    if (bgAt == null) return;
    final elapsed = DateTime.now().difference(bgAt);
    // Only lock when feature is ON and a PIN exists.
    if (elapsed >= backgroundLockDelay && ref.read(appLockEnabledProvider)) {
      lock();
    }
  }

  /// Never lock unless app lock is actually configured.
  void lock() {
    if (!ref.read(appLockEnabledProvider)) return;
    state = const AppLockState(isLocked: true, failedAttempts: 0);
  }

  void unlock() {
    state = const AppLockState(isLocked: false, failedAttempts: 0);
  }

  bool get canUseBiometric => state.failedAttempts < maxAttempts;

  void recordFailure() {
    final n = state.failedAttempts + 1;
    state = state.copyWith(
      failedAttempts: n,
      biometricAllowed: n < maxAttempts,
    );
  }
}

final appLockControllerProvider =
    NotifierProvider<AppLockController, AppLockState>(AppLockController.new);

/// Unlock screen — shown only when locked.
class AppLockScreen extends ConsumerStatefulWidget {
  const AppLockScreen({super.key});

  @override
  ConsumerState<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends ConsumerState<AppLockScreen> {
  final TextEditingController _pinCtrl = TextEditingController();
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometric());
  }

  @override
  void dispose() {
    _pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _tryBiometric() async {
    if (_checking || !mounted) return;
    final lock = ref.read(appLockControllerProvider.notifier);
    if (!lock.canUseBiometric) return;

    setState(() => _checking = true);
    try {
      final localAuth = LocalAuthentication();
      final canCheck = await localAuth.canCheckBiometrics;
      final isDeviceSupported = await localAuth.isDeviceSupported();
      if (!canCheck || !isDeviceSupported || !mounted) {
        setState(() => _checking = false);
        return;
      }

      final didAuth = await localAuth.authenticate(
        localizedReason: '解锁素记',
        options: const AuthenticationOptions(biometricOnly: true),
      );

      if (didAuth && mounted) {
        lock.unlock();
      } else if (!didAuth && mounted) {
        // STORY-4.2 AC3：生物识别失败计入失败次数，3 次后强制回退 PIN
        lock.recordFailure();
      }
    } on Exception {
      // Fall through to PIN.
      if (mounted) {
        ref.read(appLockControllerProvider.notifier).recordFailure();
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _verifyPin(String pin) async {
    if (pin.length < 4) return;
    final prefs = await AppLockPrefs.load();
    if (!mounted) return;
    if (AppLockPrefs.verifyPin(pin, prefs.pinHash)) {
      ref.read(appLockControllerProvider.notifier).unlock();
    } else {
      ref.read(appLockControllerProvider.notifier).recordFailure();
      _pinCtrl.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final lockState = ref.watch(appLockControllerProvider);
    final lock = ref.read(appLockControllerProvider.notifier);

    return Scaffold(
      backgroundColor: context.colors.surfaceCard,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Spacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: context.colors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(Radii.lg),
                  ),
                  child: Icon(Icons.lock_outline, size: 40, color: context.colors.primary),
                ),
                const SizedBox(height: Spacing.xl),
                Text('素记已锁定', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: Spacing.sm),
                Text(
                  lockState.failedAttempts > 0
                      ? '失败次数: ${lockState.failedAttempts}/${AppLockController.maxAttempts}'
                      : '使用生物识别或 PIN 解锁',
                  style: TextStyle(fontSize: 13, color: context.colors.inkTertiary),
                ),
                const SizedBox(height: Spacing.xxl),
                if (lock.canUseBiometric) ...[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _checking ? null : _tryBiometric,
                      icon: const Icon(Icons.fingerprint),
                      label: const Text('使用生物识别'),
                    ),
                  ),
                  const SizedBox(height: Spacing.lg),
                  Text('或输入 PIN 码', style: TextStyle(fontSize: 12, color: context.colors.inkTertiary)),
                  const SizedBox(height: Spacing.lg),
                ],
                SizedBox(
                  width: 200,
                  child: TextField(
                    controller: _pinCtrl,
                    obscureText: true,
                    maxLength: 6,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 24, letterSpacing: 8),
                    decoration: const InputDecoration(
                      counterText: '',
                      border: OutlineInputBorder(),
                      hintText: 'PIN',
                    ),
                    onSubmitted: _verifyPin,
                  ),
                ),
                const SizedBox(height: Spacing.lg),
                SizedBox(
                  width: 200,
                  child: FilledButton(
                    onPressed: () => _verifyPin(_pinCtrl.text),
                    child: const Text('解锁'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Setup dialog: set PIN before enabling app lock. Returns true on success.
Future<bool> showAppLockSetupDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => const _AppLockSetupDialog(),
  );
  return result ?? false;
}

class _AppLockSetupDialog extends StatefulWidget {
  const _AppLockSetupDialog();

  @override
  State<_AppLockSetupDialog> createState() => _AppLockSetupDialogState();
}

class _AppLockSetupDialogState extends State<_AppLockSetupDialog> {
  final _pinCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _useBiometric = true;
  String? _error;

  @override
  void dispose() {
    _pinCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final pin = _pinCtrl.text.trim();
    final confirm = _confirmCtrl.text.trim();
    if (pin.length < 4) {
      setState(() => _error = 'PIN 至少 4 位数字');
      return;
    }
    if (pin != confirm) {
      setState(() => _error = '两次输入的 PIN 不一致');
      return;
    }
    await AppLockPrefs.savePin(
      pinHash: hashPin(pin),
      biometric: _useBiometric,
    );
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('设置应用锁'),
      // Scrollable so the dialog never overflows on short windows / large text.
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          const Text('设置数字密码后才会开启应用锁。请牢记 PIN，忘记后只能清除应用数据。'),
          const SizedBox(height: Spacing.lg),
          TextField(
            controller: _pinCtrl,
            obscureText: true,
            maxLength: 6,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'PIN（4–6 位）', border: OutlineInputBorder()),
          ),
          const SizedBox(height: Spacing.md),
          TextField(
            controller: _confirmCtrl,
            obscureText: true,
            maxLength: 6,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: '确认 PIN', border: OutlineInputBorder()),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('同时启用生物识别'),
            value: _useBiometric,
            onChanged: (v) => setState(() => _useBiometric = v),
          ),
          if (_error != null)
            Text(_error!, style: TextStyle(color: context.colors.expense, fontSize: 12)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
        FilledButton(onPressed: _submit, child: const Text('开启')),
      ],
    );
  }
}
