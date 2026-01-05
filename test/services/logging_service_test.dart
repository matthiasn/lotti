// ignore_for_file: cascade_invocations

import 'dart:async';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/dev_logger.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;

class MockLoggingDb extends Mock implements LoggingDb {}

class MockJournalDb extends Mock implements JournalDb {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // Required by mocktail for `any<LogEntry>()`
    registerFallbackValue(const LogEntry(
      id: 'x',
      createdAt: '1970-01-01T00:00:00Z',
      domain: 'D',
      type: 'LOG',
      level: 'INFO',
      message: 'M',
    ));
  });

  late Directory tempDocs;
  late MockLoggingDb loggingDb;
  late MockJournalDb journalDb;
  late LoggingService logging;

  setUp(() async {
    // Fresh temp directory per test for file sink
    tempDocs = Directory.systemTemp.createTempSync('logging_svc_test_');
    addTearDown(() =>
        tempDocs.existsSync() ? tempDocs.deleteSync(recursive: true) : null);

    // Clear captured logs from previous tests
    DevLogger.capturedLogs.clear();

    // Reset DI and register dependencies used by LoggingService
    await getIt.reset();
    getIt
      ..registerSingleton<Directory>(tempDocs)
      ..registerSingleton<LoggingService>(LoggingService());

    // Provide a mock LoggingDb and JournalDb
    loggingDb = MockLoggingDb();
    journalDb = MockJournalDb();
    getIt
      ..registerSingleton<LoggingDb>(loggingDb)
      ..registerSingleton<JournalDb>(journalDb);

    // By default, tests run with logging disabled; enable it via config flag
    when(() => journalDb.watchConfigFlag(enableLoggingFlag))
        .thenAnswer((_) => Stream<bool>.value(true));

    logging = getIt<LoggingService>();
    logging.listenToConfigFlag();
    // Allow the stream microtask to flip the internal flag
    await Future<void>.delayed(Duration.zero);
  });

  test('captureEvent writes to DB and file when enabled', () {
    fakeAsync((async) {
      when(() => loggingDb.log(any())).thenAnswer((_) async => 1);

      logging.captureEvent(
        'hello world',
        domain: 'TEST',
        subDomain: 'sub',
      );

      async.flushMicrotasks();

      verify(() => loggingDb.log(any(that: isA<LogEntry>())))
          .called(greaterThanOrEqualTo(1));

      final logPath = p.join(
        tempDocs.path,
        'logs',
        'lotti-${DateTime.now().toIso8601String().substring(0, 10)}.log',
      );
      final file = File(logPath);
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(
        content.contains(' [INFO] TEST sub: hello world'),
        isTrue,
      );
    });
  });

  test('captureEvent DB failure still writes file line', () {
    fakeAsync((async) {
      when(() => loggingDb.log(any())).thenThrow(Exception('db down'));

      logging.captureEvent(
        'evt',
        domain: 'OUTBOX',
        subDomain: 'watchdog',
      );

      async.flushMicrotasks();

      final logPath = p.join(
        tempDocs.path,
        'logs',
        'lotti-${DateTime.now().toIso8601String().substring(0, 10)}.log',
      );
      final file = File(logPath);
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      // Even on DB failure, original event line is still appended
      expect(content.contains(' [INFO] OUTBOX watchdog: evt'), isTrue);

      // Verify DevLogger.error was called for the DB write failure
      expect(
        DevLogger.capturedLogs.any(
          (log) =>
              log.contains('LOGGING_DB event.write failed') &&
              log.contains('db down'),
        ),
        isTrue,
        reason: 'DB write failure should be logged via DevLogger.error',
      );
    });
  });

  test('captureException writes to DB and file; includes stack trace', () {
    fakeAsync((async) {
      when(() => loggingDb.log(any())).thenAnswer((_) async => 1);

      logging.captureException(
        Exception('boom'),
        domain: 'PIPE',
        subDomain: 'liveScan',
        stackTrace: StackTrace.current,
      );

      async.flushMicrotasks();

      verify(() => loggingDb.log(any(that: isA<LogEntry>()))).called(1);

      final logPath = p.join(
        tempDocs.path,
        'logs',
        'lotti-${DateTime.now().toIso8601String().substring(0, 10)}.log',
      );
      final content = File(logPath).readAsStringSync();
      expect(
          content.contains(' [ERROR] PIPE liveScan: Exception: boom'), isTrue);

      // Verify DevLogger.error was called (lines 237-242 in logging_service.dart)
      expect(
        DevLogger.capturedLogs.any(
          (log) =>
              log.contains('EXCEPTION PIPE liveScan') &&
              log.contains('Exception: boom'),
        ),
        isTrue,
      );
    });
  });

  test('captureException DB failure still writes file line', () {
    fakeAsync((async) {
      when(() => loggingDb.log(any())).thenThrow(Exception('cantopen'));

      logging.captureException(
        'oops',
        domain: 'DB',
        subDomain: 'insert',
        stackTrace: 'trace',
      );

      async.flushMicrotasks();

      final content = File(p.join(
        tempDocs.path,
        'logs',
        'lotti-${DateTime.now().toIso8601String().substring(0, 10)}.log',
      )).readAsStringSync();
      expect(content.contains(' [ERROR] DB insert: oops trace'), isTrue);

      // Verify DevLogger.error calls for both captureException and DB failure
      expect(
        DevLogger.capturedLogs.any(
          (log) => log.contains('EXCEPTION DB insert') && log.contains('oops'),
        ),
        isTrue,
        reason: 'captureException should call DevLogger.error',
      );
      expect(
        DevLogger.capturedLogs.any(
          (log) =>
              log.contains('LOGGING_DB exception.write failed') &&
              log.contains('cantopen'),
        ),
        isTrue,
        reason: 'DB write failure should be logged via DevLogger.error',
      );
    });
  });

  test('captureEvent is gated when logging disabled', () {
    fakeAsync((async) {
      // Create a new service with logging disabled (do not listen to flag)
      final svc = LoggingService();
      when(() => loggingDb.log(any())).thenAnswer((_) async => 1);

      svc.captureEvent('disabled', domain: 'TEST');
      async.flushMicrotasks();

      verifyNever(() => loggingDb.log(any()));

      final logPath = p.join(
        tempDocs.path,
        'logs',
        'lotti-${DateTime.now().toIso8601String().substring(0, 10)}.log',
      );
      expect(File(logPath).existsSync(), isFalse);
    });
  });

  test(
      'captureEvent CRITICAL fallback failure logs all errors when both '
      'DB and file write fail', () {
    fakeAsync((async) {
      // Override DI to use a directory that doesn't exist and can't be created
      // This will cause file write to fail
      getIt.unregister<Directory>();
      // Use a path that should fail (nested under file instead of directory)
      final invalidDir = Directory('/invalid/nonexistent/path/for/test');
      getIt.registerSingleton<Directory>(invalidDir);

      // Make DB write fail
      when(() => loggingDb.log(any())).thenThrow(Exception('db failure'));

      // Create fresh service pointing to the invalid directory
      final brokenLogging = LoggingService()..listenToConfigFlag();

      // Wait for stream microtask to enable logging
      async.flushMicrotasks();

      DevLogger.capturedLogs.clear();

      brokenLogging.captureEvent('critical test', domain: 'CRITICAL');

      async.flushMicrotasks();

      // Verify DevLogger.error was called for the DB write failure
      expect(
        DevLogger.capturedLogs.any(
          (log) =>
              log.contains('LOGGING_DB event.write failed') &&
              log.contains('db failure'),
        ),
        isTrue,
        reason: 'DB write failure should be logged via DevLogger.error',
      );
    });
  });

  test(
      'captureException CRITICAL fallback failure logs all errors when both '
      'DB and file write fail', () {
    fakeAsync((async) {
      // Override DI to use a directory that doesn't exist and can't be created
      getIt.unregister<Directory>();
      final invalidDir = Directory('/invalid/nonexistent/path/for/test');
      getIt.registerSingleton<Directory>(invalidDir);

      // Make DB write fail
      when(() => loggingDb.log(any())).thenThrow(Exception('db exception'));

      // Create fresh service pointing to the invalid directory
      final brokenLogging = LoggingService()..listenToConfigFlag();

      // Wait for stream microtask to enable logging
      async.flushMicrotasks();

      DevLogger.capturedLogs.clear();

      brokenLogging.captureException(
        'critical exception test',
        domain: 'CRITICAL_EXC',
        subDomain: 'test',
        stackTrace: 'mock stack trace',
      );

      async.flushMicrotasks();

      // Verify DevLogger.error was called for captureException
      expect(
        DevLogger.capturedLogs.any(
          (log) =>
              log.contains('EXCEPTION CRITICAL_EXC test') &&
              log.contains('critical exception test'),
        ),
        isTrue,
        reason: 'captureException should call DevLogger.error',
      );

      // Verify DevLogger.error was called for the DB write failure
      expect(
        DevLogger.capturedLogs.any(
          (log) =>
              log.contains('LOGGING_DB exception.write failed') &&
              log.contains('db exception'),
        ),
        isTrue,
        reason: 'DB write failure should be logged via DevLogger.error',
      );
    });
  });

  test('captureEvent supports different InsightLevel values', () {
    fakeAsync((async) {
      when(() => loggingDb.log(any())).thenAnswer((_) async => 1);

      logging.captureEvent(
        'trace message',
        domain: 'TRACE_TEST',
        level: InsightLevel.trace,
      );

      async.flushMicrotasks();

      final logPath = p.join(
        tempDocs.path,
        'logs',
        'lotti-${DateTime.now().toIso8601String().substring(0, 10)}.log',
      );
      final content = File(logPath).readAsStringSync();
      expect(content.contains('[TRACE] TRACE_TEST: trace message'), isTrue);
    });
  });

  test('captureEvent supports warn level', () {
    fakeAsync((async) {
      when(() => loggingDb.log(any())).thenAnswer((_) async => 1);

      logging.captureEvent(
        'warn message',
        domain: 'WARN_TEST',
        level: InsightLevel.warn,
      );

      async.flushMicrotasks();

      final logPath = p.join(
        tempDocs.path,
        'logs',
        'lotti-${DateTime.now().toIso8601String().substring(0, 10)}.log',
      );
      final content = File(logPath).readAsStringSync();
      expect(content.contains('[WARN] WARN_TEST: warn message'), isTrue);
    });
  });

  test('captureEvent without subDomain formats line correctly', () {
    fakeAsync((async) {
      when(() => loggingDb.log(any())).thenAnswer((_) async => 1);

      logging.captureEvent(
        'no subdomain',
        domain: 'NOSUB',
      );

      async.flushMicrotasks();

      final logPath = p.join(
        tempDocs.path,
        'logs',
        'lotti-${DateTime.now().toIso8601String().substring(0, 10)}.log',
      );
      final content = File(logPath).readAsStringSync();
      // Should not have extra space before colon when no subDomain
      expect(content.contains('[INFO] NOSUB: no subdomain'), isTrue);
      expect(content.contains('NOSUB : '), isFalse); // No trailing space
    });
  });

  test('config flag listener dynamically toggles logging', () async {
    // Create a StreamController to control the flag stream
    final flagController = StreamController<bool>();
    addTearDown(flagController.close);

    when(() => journalDb.watchConfigFlag(enableLoggingFlag))
        .thenAnswer((_) => flagController.stream);
    when(() => loggingDb.log(any())).thenAnswer((_) async => 1);

    final svc = LoggingService()..listenToConfigFlag();

    // Initially disabled (isTestEnv = true means _enableLogging = false)
    svc.captureEvent('should be skipped', domain: 'TOGGLE');
    await Future<void>.delayed(Duration.zero);
    verifyNever(() => loggingDb.log(any()));

    // Enable logging via config flag
    flagController.add(true);
    await Future<void>.delayed(Duration.zero);

    svc.captureEvent('should be logged', domain: 'TOGGLE');
    await Future<void>.delayed(const Duration(milliseconds: 10));

    verify(() => loggingDb.log(any())).called(1);

    // Disable logging via config flag
    flagController.add(false);
    await Future<void>.delayed(Duration.zero);

    svc.captureEvent('should be skipped again', domain: 'TOGGLE');
    await Future<void>.delayed(const Duration(milliseconds: 10));

    // Should still be 1 call total (no new calls)
    verifyNever(() => loggingDb.log(any()));
  });

  test('captureException with null stackTrace handles gracefully', () {
    fakeAsync((async) {
      when(() => loggingDb.log(any())).thenAnswer((_) async => 1);

      logging.captureException(
        'error without stack',
        domain: 'NULL_STACK',
      );

      async.flushMicrotasks();

      final logPath = p.join(
        tempDocs.path,
        'logs',
        'lotti-${DateTime.now().toIso8601String().substring(0, 10)}.log',
      );
      final content = File(logPath).readAsStringSync();
      expect(
          content.contains('[ERROR] NULL_STACK: error without stack'), isTrue);
    });
  });

  test('captureEvent uses exception InsightType', () {
    fakeAsync((async) {
      when(() => loggingDb.log(any())).thenAnswer((_) async => 1);

      logging.captureEvent(
        'exceptional event',
        domain: 'EXCEPTION_TYPE',
        type: InsightType.exception,
      );

      async.flushMicrotasks();

      // Verify DB was called with correct type
      final captured = verify(() => loggingDb.log(captureAny())).captured;
      expect(captured.length, equals(1));
      final logEntry = captured.first as LogEntry;
      expect(logEntry.type, equals('EXCEPTION'));
    });
  });

  test('captureEvent verifies LogEntry level in DB', () {
    fakeAsync((async) {
      when(() => loggingDb.log(any())).thenAnswer((_) async => 1);

      logging.captureEvent(
        'error level event',
        domain: 'ERROR_TEST',
        level: InsightLevel.error,
      );

      async.flushMicrotasks();

      // Verify DB was called with correct level
      final captured = verify(() => loggingDb.log(captureAny())).captured;
      expect(captured.length, equals(1));
      final logEntry = captured.first as LogEntry;
      expect(logEntry.level, equals('ERROR'));
      expect(logEntry.domain, equals('ERROR_TEST'));
      expect(logEntry.message, equals('error level event'));
    });
  });
}
