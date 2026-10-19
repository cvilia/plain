/// Structured logging facade. See 06-A1.
library;

import 'package:flutter/foundation.dart' show debugPrint;

enum LogLevel { debug, info, warn, error }

class LogEvent {
  const LogEvent({
    required this.level,
    required this.name,
    this.fields = const {},
    this.errorCode,
    this.at,
  });
  final LogLevel level;
  final String name;
  final Map<String, Object?> fields;
  final String? errorCode;

  /// 事件时间。由 [AppLog._emit] 填，单独构造（如测试）时可留空。
  final DateTime? at;

  /// `HH:mm:ss`，诊断页展示用。
  String get clockLabel {
    final t = at;
    if (t == null) return '--:--:--';
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }

  @override
  String toString() => '$clockLabel [${level.name}] $name ${fields.entries.map((e) => '${e.key}=${e.value}').join(' ')}';
}

abstract interface class LogSink {
  void write(LogEvent event);
}

class RingBufferSink implements LogSink {
  RingBufferSink({this.capacity = 2000});
  final int capacity;
  final List<LogEvent> _buffer = [];
  List<LogEvent> get events => List.unmodifiable(_buffer);
  @override
  void write(LogEvent event) {
    _buffer.add(event);
    if (_buffer.length > capacity) _buffer.removeRange(0, _buffer.length - capacity);
  }

  void clear() => _buffer.clear();
}

/// 控制台出口：把事件打到 IDE / 终端，`flutter run` 时能看到。
///
/// 只做展示，不做缓冲——缓冲是 [RingBufferSink] 的职责，两者由 [MultiSink] 组合。
class ConsoleSink implements LogSink {
  const ConsoleSink({this.tag = 'Plain'});

  final String tag;

  @override
  void write(LogEvent event) {
    final b = StringBuffer('[$tag][${event.level.name.toUpperCase()}] ${event.name}');
    if (event.errorCode != null) b.write(' code=${event.errorCode}');
    for (final e in event.fields.entries) {
      b.write(' ${e.key}=${e.value}');
    }
    debugPrint(b.toString());
  }
}

/// 扇出到多个 sink。任一 sink 抛异常都不影响其余 sink，也不影响业务主流程。
class MultiSink implements LogSink {
  const MultiSink(this.sinks);

  final List<LogSink> sinks;

  @override
  void write(LogEvent event) {
    for (final s in sinks) {
      try {
        s.write(event);
      } catch (_) {
        // 日志不能反过来把业务打挂
      }
    }
  }
}

class AppLog {
  AppLog({required LogSink sink, LogLevel minLevel = LogLevel.debug}) : _sink = sink, _minLevel = minLevel;
  final LogSink _sink;
  final LogLevel _minLevel;

  void _emit(LogLevel level, String name, {Map<String, Object?> fields = const {}, String? errorCode}) {
    if (level.index < _minLevel.index) return;
    _sink.write(LogEvent(level: level, name: name, fields: fields, errorCode: errorCode, at: DateTime.now()));
  }

  void entrySaved({required String entryType, required String source}) =>
      _emit(LogLevel.info, 'entry.saved', fields: {'type': entryType, 'source': source});
  void entrySaveFailed({required String entryType, required String code}) =>
      _emit(LogLevel.error, 'entry.save_failed', fields: {'type': entryType}, errorCode: code);
  void warn(String name, {Map<String, Object?> fields = const {}}) => _emit(LogLevel.warn, name, fields: fields);
  void error(String name, {Map<String, Object?> fields = const {}, String? errorCode}) =>
      _emit(LogLevel.error, name, fields: fields, errorCode: errorCode);
  void info(String name, {Map<String, Object?> fields = const {}}) => _emit(LogLevel.info, name, fields: fields);
  void debug(String name, {Map<String, Object?> fields = const {}}) => _emit(LogLevel.debug, name, fields: fields);

  /// catch 块专用：把异常对象与堆栈一并留在日志里。
  ///
  /// 只记 `e.toString()` 会丢掉类型与调用栈——真机排查时这两样才是关键。
  void exception(
    String name,
    Object error, [
    StackTrace? stack,
    Map<String, Object?> fields = const {},
  ]) =>
      _emit(
        LogLevel.error,
        name,
        fields: {...fields, 'error': '$error', if (stack != null) 'stack': '$stack'},
        errorCode: name,
      );
}
