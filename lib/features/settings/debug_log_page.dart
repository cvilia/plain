/// 诊断日志 —— 直接读进程内环形缓冲，真机上不连调试器也能回溯操作。
///
/// 缓冲区由 `bootstrap.dart` 注入（与 [AppLog] 共用同一个 `RingBufferSink`），
/// 只保留本次进程的事件；退出应用即清空。这不是审计日志——审计看「操作日志」
/// （change_log 落库），这里看的是「运行时到底走了哪条分支」。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plain/app/bootstrap.dart';
import 'package:plain/app/breakpoints.dart';
import 'package:plain/app/l10n/app_strings.dart';
import 'package:plain/app/l10n/strings_settings_b.dart';
import 'package:plain/app/theme/app_colors.dart';
import 'package:plain/app/theme/design_tokens.dart';
import 'package:plain/app/theme/typography.dart';
import 'package:plain/core/logging/app_log.dart';
import 'package:plain/design_system/app_empty_state.dart';
import 'package:plain/design_system/plain_icons_v3.dart';
import 'package:plain/design_system/plain_ui.dart';

class DebugLogPage extends ConsumerStatefulWidget {
  const DebugLogPage({super.key});

  @override
  ConsumerState<DebugLogPage> createState() => _DebugLogPageState();
}

class _DebugLogPageState extends ConsumerState<DebugLogPage> {
  /// 0 = 全部 / 1 = info+ / 2 = warn+ / 3 = error
  int _levelIndex = 0;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // 环形缓冲没有 Stream：轮询 800ms 足够看，离开页面立刻停，不做常驻定时器。
    _ticker = Timer.periodic(const Duration(milliseconds: 800), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  LogLevel get _minLevel => switch (_levelIndex) {
        1 => LogLevel.info,
        2 => LogLevel.warn,
        3 => LogLevel.error,
        _ => LogLevel.debug,
      };

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final buffer = ref.watch(logBufferProvider);
    final all = buffer.events;
    // 最新的在最上面：排查时第一眼要看的是「刚刚发生了什么」。
    final items =
        all.where((e) => e.level.index >= _minLevel.index).toList().reversed.toList();

    return Scaffold(
      appBar: PlainTopBar(
        title: s.debugLog,
        showBack: true,
        actions: [
          if (all.isNotEmpty)
            PlainTopBarTextAction(
              label: s.debugLogClear,
              color: context.colors.expense,
              onTap: () {
                buffer.clear();
                setState(() {});
              },
            ),
        ],
      ),
      body: ContentWidthConstraint(
        // ContentWidthConstraint 只收宽度，用它包住 Column 里的 Expanded
        // 必须再给一个撑满的盒子，否则 Column 拿到的是 loose 约束。
        child: SizedBox.expand(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    Spacing.lg, Spacing.sm, Spacing.lg, Spacing.sm),
                child: PlainSeg(
                  items: [
                    s.debugLogLevelAll,
                    s.debugLogLevelInfo,
                    s.debugLogLevelWarn,
                    s.debugLogLevelError,
                  ],
                  selectedIndex: _levelIndex,
                  onChanged: (i) => setState(() => _levelIndex = i),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    Spacing.lg, 0, Spacing.lg, Spacing.sm),
                child: Text(
                  s.debugLogCount(items.length),
                  style:
                      TextStyle(fontSize: 12, color: context.colors.inkTertiary),
                ),
              ),
              Expanded(
                child: items.isEmpty
                    ? AppEmptyState(
                        icon: PlainIconData.history,
                        title: s.debugLogEmptyTitle,
                        subtitle: s.debugLogEmptySubtitle,
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: Spacing.xl),
                        itemCount: items.length,
                        itemBuilder: (context, i) => _LogRow(event: items[i]),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogRow extends StatelessWidget {
  const _LogRow({required this.event});

  final LogEvent event;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (Color fg, String tag) = switch (event.level) {
      LogLevel.debug => (colors.inkFaint, 'DBG'),
      LogLevel.info => (colors.inkSecondary, 'INF'),
      LogLevel.warn => (colors.warnInk, 'WRN'),
      LogLevel.error => (colors.expense, 'ERR'),
    };
    final detail = <String>[
      if (event.errorCode != null) 'code=${event.errorCode}',
      ...event.fields.entries.map((e) => '${e.key}=${e.value}'),
    ].join('  ');

    return Container(
      // 列表分割线走「每行画上边线」，与全库列表口径一致。
      padding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.divider)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 58,
            child: Text(
              event.clockLabel,
              style: TextStyle(
                fontSize: 12,
                color: colors.inkFaint,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          SizedBox(
            width: 34,
            child: Text(
              tag,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.name,
                  style: TextStyle(
                    fontSize: 14,
                    color: colors.ink,
                    height: designLineHeight(14) / 14,
                  ),
                ),
                if (detail.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      detail,
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.inkTertiary,
                        height: designLineHeight(12) / 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
