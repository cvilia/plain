/// STORY-8.1 前台同步调度：写后即推 + 每 [SyncRules.pollInterval] 拉一次。
///
/// 素记没有服务端推送通道（WebDAV 只有轮询），因此延迟目标靠两件事合起来达成：
/// ①本地写入后**立即**触发一次推拉；②前台每 10 秒轮询。两者都不做后台常驻，
/// 退到后台即停（省电，也避免多端同时长连接）。
library;

import 'dart:async';

import 'package:plain/core/constants/app_constants.dart';
import 'package:plain/core/logging/app_log.dart';
import 'package:plain/data/sync/incremental_sync_service.dart';
import 'package:plain/data/sync/webdav_client.dart';

class SyncScheduler {
  SyncScheduler({
    required WebDavConfig? Function() readConfig,
    required Future<SyncRunResult> Function(WebDavConfig config) runSync,
    void Function(SyncRunResult result)? onResult,
    AppLog? log,
  })  : _readConfig = readConfig,
        _runSync = runSync,
        _onResult = onResult,
        _log = log;

  final WebDavConfig? Function() _readConfig;
  final Future<SyncRunResult> Function(WebDavConfig config) _runSync;
  final void Function(SyncRunResult result)? _onResult;
  final AppLog? _log;

  /// 写后触发的合并窗口：连写 10 笔只推一次。
  static const Duration _debounce = Duration(seconds: 1);

  Timer? _poll;
  Timer? _debounceTimer;
  bool _running = false;
  bool _started = false;

  bool get isRunning => _started;

  void start() {
    if (_started) return;
    _started = true;
    _poll = Timer.periodic(SyncRules.pollInterval, (_) => unawaited(syncNow()));
    unawaited(syncNow());
  }

  void stop() {
    _started = false;
    _poll?.cancel();
    _poll = null;
    _debounceTimer?.cancel();
    _debounceTimer = null;
  }

  /// 本地写入后调用（由 `DataInvalidation.bump` 的统一钩子触发）。
  void notifyLocalMutation() {
    if (!_started) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () => unawaited(syncNow()));
  }

  /// 立刻跑一轮（手动「立即同步」也走这里）。
  Future<SyncRunResult> syncNow() async {
    if (_running) {
      return const SyncRunResult(success: false, pushed: 0, pulled: 0, conflicts: 0);
    }
    final config = _readConfig();
    if (config == null) {
      return const SyncRunResult(success: false, pushed: 0, pulled: 0, conflicts: 0);
    }
    _running = true;
    try {
      final result = await _runSync(config);
      if (result.success) _onResult?.call(result);
      return result;
    } catch (e) {
      _log?.warn('sync.round_failed', fields: {'error': '$e'});
      return SyncRunResult(
          success: false, pushed: 0, pulled: 0, conflicts: 0, message: '$e');
    } finally {
      _running = false;
    }
  }
}
