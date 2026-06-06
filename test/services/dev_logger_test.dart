import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/services/dev_logger.dart';

void main() {
  setUp(() {
    DevLogger.clear();
    DevLogger.suppressOutput = true;
  });

  tearDown(() {
    DevLogger.clear();
    DevLogger.suppressOutput = false;
  });

  group('DevLogger', () {
    test('log captures the bracketed name and message', () {
      DevLogger.log(name: 'MyClass', message: 'something happened');

      expect(DevLogger.capturedLogs, ['[MyClass] something happened']);
    });

    test('captures regardless of suppressOutput state', () {
      DevLogger.suppressOutput = false;
      DevLogger.log(name: 'A', message: 'visible');
      DevLogger.suppressOutput = true;
      DevLogger.log(name: 'A', message: 'suppressed');

      expect(DevLogger.capturedLogs, [
        '[A] visible',
        '[A] suppressed',
      ]);
    });

    test('log appends error and stack trace segments when provided', () {
      final trace = StackTrace.fromString('#0 main (file.dart:1)');
      DevLogger.log(
        name: 'Repo',
        message: 'failed',
        error: const FormatException('bad input'),
        stackTrace: trace,
      );

      final entry = DevLogger.capturedLogs.single;
      expect(entry, startsWith('[Repo] failed'));
      expect(entry, contains('| error: FormatException: bad input'));
      expect(entry, contains('| stackTrace: #0 main (file.dart:1)'));
    });

    test('warning prepends WARNING:', () {
      DevLogger.warning(name: 'Svc', message: 'low disk');

      expect(DevLogger.capturedLogs, ['[Svc] WARNING: low disk']);
    });

    test('error prepends ERROR: and carries the original error', () {
      DevLogger.error(
        name: 'Svc',
        message: 'crashed',
        error: StateError('boom'),
      );

      expect(
        DevLogger.capturedLogs.single,
        '[Svc] ERROR: crashed | error: Bad state: boom',
      );
    });

    test('clear empties the captured logs', () {
      DevLogger.log(name: 'X', message: 'one');
      expect(DevLogger.capturedLogs, isNotEmpty);

      DevLogger.clear();

      expect(DevLogger.capturedLogs, isEmpty);
    });
  });
}
