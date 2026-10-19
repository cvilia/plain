/// 启动分段计时 + 慢帧记录。
///
/// 为什么不用 `AppLog`：release 包的门禁是 `warn` 起，启动计时属于 info，
/// 会在真机上被过滤掉，而「真机 release 首帧 1.9s」恰恰是最需要看的数据。
/// 所以这里直接走 `debugPrint`（release 也输出到 logcat），只打几行。
///
/// 用法：
/// ```dart
/// StartupTrace.mark('db.open');      // → [startup] +412ms db.open (Δ412ms)
/// ```
/// 输出的 `+Xms` 是从进程 main() 起算的累计，括号里是距上一次 mark 的增量。
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// 出问题排查时置 true；稳定后可以关掉（只是少几行 logcat）。
const bool kStartupTraceEnabled = true;

/// 首帧耗时超过这个值就单独打一行（120Hz 设备下一帧 8.3ms，100ms 已是卡顿）。
const int kSlowFrameMs = 100;

class StartupTrace {
  StartupTrace._();

  static final Stopwatch _sw = Stopwatch()..start();
  static int _lastMs = 0;
  static bool _installed = false;

  static void mark(String name) {
    if (!kStartupTraceEnabled) return;
    final ms = _sw.elapsedMilliseconds;
    debugPrint('[startup] +${ms}ms $name (Δ${ms - _lastMs}ms)');
    _lastMs = ms;
  }

  /// 记录慢帧：build = Dart 侧构建，raster = GPU 光栅化。
  ///
  /// 「Skipped 122 frames」只说明掉帧，分不清是构建慢还是光栅慢；这里给拆分。
  /// 注意 `addTimingsCallback` 的回调本身在引擎线程之外聚合，开销可忽略。
  static void installSlowFrameLogger() {
    if (!kStartupTraceEnabled || _installed) return;
    _installed = true;
    SchedulerBinding.instance.addTimingsCallback((timings) {
      for (final t in timings) {
        final build = t.buildDuration.inMilliseconds;
        final raster = t.rasterDuration.inMilliseconds;
        if (build < kSlowFrameMs && raster < kSlowFrameMs) continue;
        debugPrint(
          '[perf] slow frame build=${build}ms raster=${raster}ms '
          'total=${t.totalSpan.inMilliseconds}ms',
        );
      }
    });
  }
}
