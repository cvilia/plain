/// App lock: biometric + PIN. See PRD STORY-4.2, 06-D3.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:plain/app/theme/design_tokens.dart';

/// Whether app lock is enabled.
class AppLockEnabledNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle(bool value) => state = value;
}

final appLockEnabledProvider =
    NotifierProvider<AppLockEnabledNotifier, bool>(AppLockEnabledNotifier.new);

/// Lock state.
class AppLockState {
  const AppLockState({this.isLocked = false, this.failedAttempts = 0});

  final bool isLocked;
  final int failedAttempts;

  AppLockState copyWith({bool? isLocked, int? failedAttempts}) {
    return AppLockState(
      isLocked: isLocked ?? this.isLocked,
      failedAttempts: failedAttempts ?? this.failedAttempts,
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
    // Only lock if backgrounded long enough AND app lock is enabled
    if (bgAt == null) return;
    final elapsed = DateTime.now().difference(bgAt);
    if (elapsed >= backgroundLockDelay && ref.read(appLockEnabledProvider)) {
      lock();
    }
  }

  void lock() {
    state = const AppLockState(isLocked: true, failedAttempts: 0);
  }

  void unlock() {
    state = const AppLockState(isLocked: false, failedAttempts: 0);
  }

  bool get canUseBiometric => state.failedAttempts < maxAttempts;

  void recordFailure() {
    state = state.copyWith(failedAttempts: state.failedAttempts + 1);
  }
}

final appLockControllerProvider =
    NotifierProvider<AppLockController, AppLockState>(AppLockController.new);

/// Lock screen widget - simple, no lifecycle observer here.
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
    // Try biometric on first show
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
      );

      if (didAuth && mounted) {
        lock.unlock();
      }
    } on Exception {
      // Biometric failed, fall through to PIN
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  void _verifyPin(String pin) {
    // Default PIN is 000000 for demo
    if (pin == '000000') {
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
      backgroundColor: BrandColors.surface,
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
                    color: BrandColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(Radii.lg),
                  ),
                  child: Icon(Icons.lock_outline, size: 40, color: BrandColors.primary),
                ),
                const SizedBox(height: Spacing.xl),
                Text('素记已锁定', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: Spacing.sm),
                Text(
                  lockState.failedAttempts > 0
                      ? '失败次数: ${lockState.failedAttempts}/${AppLockController.maxAttempts}'
                      : '使用生物识别或 PIN 解锁',
                  style: TextStyle(fontSize: 13, color: BrandColors.inkTertiary),
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
                  Text('或输入 PIN 码', style: TextStyle(fontSize: 12, color: BrandColors.inkTertiary)),
                  const SizedBox(height: Spacing.lg),
                ],
                SizedBox(
                  width: 200,
                  child: TextField(
                    controller: _pinCtrl,
                    obscureText: true,
                    maxLength: 6,
                    keyboardType: TextInputType.number,
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
