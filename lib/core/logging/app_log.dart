/// Structured logging facade. See 06-A1.
library;

enum LogLevel { debug, info, warn, error }

class LogEvent {
  const LogEvent({required this.level, required this.name, this.fields = const {}, this.errorCode});
  final LogLevel level;
  final String name;
  final Map<String, Object?> fields;
  final String? errorCode;
  @override
  String toString() => '[${level.name}] $name ${fields.entries.map((e) => '${e.key}=${e.value}').join(' ')}';
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
}

class AppLog {
  AppLog({required LogSink sink, LogLevel minLevel = LogLevel.debug}) : _sink = sink, _minLevel = minLevel;
  final LogSink _sink;
  final LogLevel _minLevel;

  void _emit(LogLevel level, String name, {Map<String, Object?> fields = const {}, String? errorCode}) {
    if (level.index < _minLevel.index) return;
    _sink.write(LogEvent(level: level, name: name, fields: fields, errorCode: errorCode));
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
}
