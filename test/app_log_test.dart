/// 日志门面的行为契约：分级门禁、扇出、环形淘汰、异常留痕。
///
/// 这几条是「日志到底有没有用」的底线——之前在 app 里调了 `AppLog` 却看不到
/// 任何输出，根因就是 sink 只有环形缓冲、没有出口，且没有任何测试盯着。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:plain/core/logging/app_log.dart';

class _Recorder implements LogSink {
  final List<LogEvent> events = [];

  @override
  void write(LogEvent event) => events.add(event);
}

void main() {
  group('AppLog', () {
    test('minLevel 过滤掉低级别事件', () {
      final sink = _Recorder();
      final log = AppLog(sink: sink, minLevel: LogLevel.warn);

      log.debug('d');
      log.info('i');
      log.warn('w');
      log.error('e');

      expect(sink.events.map((e) => e.name), ['w', 'e']);
    });

    test('默认 minLevel 是 debug，四级全放行', () {
      final sink = _Recorder();
      final log = AppLog(sink: sink);

      log.debug('d');
      log.info('i');
      log.warn('w');
      log.error('e');

      expect(sink.events.map((e) => e.level), [
        LogLevel.debug,
        LogLevel.info,
        LogLevel.warn,
        LogLevel.error,
      ]);
    });

    test('entrySaveFailed 记录 errorCode', () {
      final sink = _Recorder();
      AppLog(sink: sink).entrySaveFailed(entryType: 'expense', code: 'db.insert_failed');

      expect(sink.events.single.level, LogLevel.error);
      expect(sink.events.single.errorCode, 'db.insert_failed');
      expect(sink.events.single.fields['type'], 'expense');
    });

    test('exception 把异常与堆栈都留在 fields 里', () {
      final sink = _Recorder();
      final err = StateError('boom');
      AppLog(sink: sink).exception('db.insert_failed', err, StackTrace.current);

      final e = sink.events.single;
      expect(e.errorCode, 'db.insert_failed');
      expect('${e.fields['error']}', contains('boom'));
      expect(e.fields['stack'], isNotNull);
    });

    test('事件带时间戳，clockLabel 为 HH:mm:ss', () {
      final sink = _Recorder();
      AppLog(sink: sink).info('x');

      final e = sink.events.single;
      expect(e.at, isNotNull);
      expect(e.clockLabel, matches(RegExp(r'^\d{2}:\d{2}:\d{2}$')));
    });
  });

  group('sink', () {
    test('RingBufferSink 超出容量淘汰最旧的', () {
      final buf = RingBufferSink(capacity: 2);
      final log = AppLog(sink: buf);

      log.info('1');
      log.info('2');
      log.info('3');

      expect(buf.events.map((e) => e.name), ['2', '3']);
    });

    test('RingBufferSink.clear 清空缓冲', () {
      final buf = RingBufferSink();
      AppLog(sink: buf).info('x');
      buf.clear();

      expect(buf.events, isEmpty);
    });

    test('MultiSink 扇出到每一个 sink', () {
      final a = _Recorder();
      final b = _Recorder();
      final log = AppLog(sink: MultiSink([a, b]));

      log.info('x');

      expect(a.events.length, 1);
      expect(b.events.length, 1);
    });

    test('单个 sink 抛异常不影响其余 sink', () {
      final good = _Recorder();
      final log = AppLog(sink: MultiSink([_Exploding(), good]));

      log.info('x');

      expect(good.events.single.name, 'x');
    });
  });
}

class _Exploding implements LogSink {
  @override
  void write(LogEvent event) => throw StateError('sink down');
}
