// ignore_for_file: cascade_invocations

import 'dart:async';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_types.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/dev_logger.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/platform.dart' as platform;
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;

import '../mocks/mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDocs;
  late MockJournalDb journalDb;
  late LoggingService logging;

  setUp(() async {
    // Fresh temp directory per test for file sink
    tempDocs = Directory.systemTemp.createTempSync('logging_svc_test_');
    addTearDown(
      () => tempDocs.existsSync() ? tempDocs.deleteSync(recursive: true) : null,
    );

    // Clear captured logs from previous tests
    DevLogger.capturedLogs.clear();

    // Reset DI and register dependencies used by LoggingService
    await getIt.reset();
    getIt
      ..registerSingleton<Directory>(tempDocs)
      ..registerSingleton<LoggingService>(LoggingService());

    journalDb = MockJournalDb();
    getIt.registerSingleton<JournalDb>(journalDb);

    // By default, tests run with logging disabled; enable it via config flag
    when(
      () => journalDb.watchConfigFlag(enableLoggingFlag),
    ).thenAnswer((_) => Stream<bool>.value(true));

    logging = getIt<LoggingService>();
    logging.listenToConfigFlag();
    // Allow the stream microtask to flip the internal flag
    await Future<void>.delayed(Duration.zero);
  });

  test('captureEvent writes to file when enabled', () {
    fakeAsync((async) {
      logging.captureEvent(
        'hello world',
        domain: 'TEST',
        subDomain: 'sub',
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
      expect(
        content.contains(' [INFO] TEST sub: hello world'),
        isTrue,
      );
    });
  });

  test('captureException writes to file; includes stack trace', () {
    fakeAsync((async) {
      logging.captureException(
        Exception('boom'),
        domain: 'PIPE',
        subDomain: 'liveScan',
        stackTrace: StackTrace.current,
      );

      async.flushMicrotasks();

      final logPath = p.join(
        tempDocs.path,
        'logs',
        'lotti-${DateTime.now().toIso8601String().substring(0, 10)}.log',
      );
      final content = File(logPath).readAsStringSync();
      expect(
        content.contains(' [ERROR] PIPE liveScan: Exception: boom'),
        isTrue,
      );

      // Verify DevLogger.error was called
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

  test('captureException writes file line with stack trace text', () {
    fakeAsync((async) {
      logging.captureException(
        'oops',
        domain: 'DB',
        subDomain: 'insert',
        stackTrace: 'trace',
      );

      async.flushMicrotasks();

      final content = File(
        p.join(
          tempDocs.path,
          'logs',
          'lotti-${DateTime.now().toIso8601String().substring(0, 10)}.log',
        ),
      ).readAsStringSync();
      expect(content.contains(' [ERROR] DB insert: oops trace'), isTrue);

      // Verify DevLogger.error was called for captureException
      expect(
        DevLogger.capturedLogs.any(
          (log) => log.contains('EXCEPTION DB insert') && log.contains('oops'),
        ),
        isTrue,
        reason: 'captureException should call DevLogger.error',
      );
    });
  });

  test('captureEvent is gated when logging disabled', () {
    fakeAsync((async) {
      // Create a new service with logging disabled (do not listen to flag)
      final svc = LoggingService();

      svc.captureEvent('disabled', domain: 'TEST');
      async.flushMicrotasks();

      final logPath = p.join(
        tempDocs.path,
        'logs',
        'lotti-${DateTime.now().toIso8601String().substring(0, 10)}.log',
      );
      expect(File(logPath).existsSync(), isFalse);
    });
  });

  test('captureEvent silently swallows file write errors', () {
    fakeAsync((async) {
      // Use a file as the "directory" so creating logs/ underneath always fails
      getIt.unregister<Directory>();
      final blocker = File(p.join(tempDocs.path, 'not_a_directory'))
        ..writeAsStringSync('x');
      final invalidDir = Directory(blocker.path);
      getIt.registerSingleton<Directory>(invalidDir);

      // Create fresh service pointing to the invalid directory
      final brokenLogging = LoggingService()..listenToConfigFlag();

      // Wait for stream microtask to enable logging
      async.flushMicrotasks();

      // captureEvent should not throw even when the file sink fails
      brokenLogging.captureEvent('critical test', domain: 'CRITICAL');
      async.flushMicrotasks();

      // No log dir should have been created
      expect(
        Directory(p.join(blocker.path, 'logs')).existsSync(),
        isFalse,
      );
    });
  });

  test('captureException CRITICAL fallback failure logs errors when '
      'file write fails', () {
    fakeAsync((async) {
      // Use a file as the "directory" so creating logs/ underneath always fails
      getIt.unregister<Directory>();
      final blocker = File(p.join(tempDocs.path, 'not_a_directory_exc'))
        ..writeAsStringSync('x');
      final invalidDir = Directory(blocker.path);
      getIt.registerSingleton<Directory>(invalidDir);

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
    });
  });

  test('captureEvent supports different InsightLevel values', () {
    fakeAsync((async) {
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

    when(
      () => journalDb.watchConfigFlag(enableLoggingFlag),
    ).thenAnswer((_) => flagController.stream);

    final svc = LoggingService()..listenToConfigFlag();

    // Initially disabled (isTestEnv = true means _enableLogging = false)
    svc.captureEvent('should be skipped', domain: 'TOGGLE');
    await Future<void>.delayed(Duration.zero);

    final logPath = p.join(
      tempDocs.path,
      'logs',
      'lotti-${DateTime.now().toIso8601String().substring(0, 10)}.log',
    );
    expect(File(logPath).existsSync(), isFalse);

    // Enable logging via config flag
    flagController.add(true);
    await Future<void>.delayed(Duration.zero);

    svc.captureEvent('should be logged', domain: 'TOGGLE');
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(File(logPath).existsSync(), isTrue);
    final content = File(logPath).readAsStringSync();
    expect(content.contains('TOGGLE: should be logged'), isTrue);
    // The skipped event should NOT be in the file
    expect(content.contains('should be skipped'), isFalse);

    // Disable logging via config flag
    flagController.add(false);
    await Future<void>.delayed(Duration.zero);

    svc.captureEvent('should be skipped again', domain: 'TOGGLE');
    await Future<void>.delayed(const Duration(milliseconds: 10));

    // File content should not contain the disabled event
    final content2 = File(logPath).readAsStringSync();
    expect(content2.contains('should be skipped again'), isFalse);
  });

  test('captureException with null stackTrace handles gracefully', () {
    fakeAsync((async) {
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
        content.contains('[ERROR] NULL_STACK: error without stack'),
        isTrue,
      );
    });
  });

  test('captureEvent uses exception InsightType in file output', () {
    fakeAsync((async) {
      logging.captureEvent(
        'exceptional event',
        domain: 'EXCEPTION_TYPE',
        type: InsightType.exception,
      );

      async.flushMicrotasks();

      final logPath = p.join(
        tempDocs.path,
        'logs',
        'lotti-${DateTime.now().toIso8601String().substring(0, 10)}.log',
      );
      final content = File(logPath).readAsStringSync();
      expect(content.contains('EXCEPTION_TYPE: exceptional event'), isTrue);
    });
  });

  test('captureEvent verifies error level in file output', () {
    fakeAsync((async) {
      logging.captureEvent(
        'error level event',
        domain: 'ERROR_TEST',
        level: InsightLevel.error,
      );

      async.flushMicrotasks();

      final logPath = p.join(
        tempDocs.path,
        'logs',
        'lotti-${DateTime.now().toIso8601String().substring(0, 10)}.log',
      );
      final content = File(logPath).readAsStringSync();
      expect(content.contains('[ERROR] ERROR_TEST: error level event'), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // Buffered file writing (non-test-env path)
  // ---------------------------------------------------------------------------
  group('buffered file writing (non-test env)', () {
    late Directory bufferedTempDocs;
    late MockJournalDb bufferedJournalDb;
    late LoggingService bufferedLogging;

    setUp(() async {
      // Switch to non-test env to exercise buffered path
      platform.isTestEnv = false;

      bufferedTempDocs = Directory.systemTemp.createTempSync(
        'logging_svc_buf_test_',
      );
      addTearDown(() {
        platform.isTestEnv = true;
        if (bufferedTempDocs.existsSync()) {
          bufferedTempDocs.deleteSync(recursive: true);
        }
      });

      DevLogger.capturedLogs.clear();

      await getIt.reset();
      getIt
        ..registerSingleton<Directory>(bufferedTempDocs)
        ..registerSingleton<LoggingService>(LoggingService());

      bufferedJournalDb = MockJournalDb();
      getIt.registerSingleton<JournalDb>(bufferedJournalDb);

      when(
        () => bufferedJournalDb.watchConfigFlag(enableLoggingFlag),
      ).thenAnswer((_) => Stream<bool>.value(true));

      bufferedLogging = getIt<LoggingService>()..listenToConfigFlag();
      await Future<void>.delayed(Duration.zero);
    });

    String logPath0() => p.join(
      bufferedTempDocs.path,
      'logs',
      'lotti-${DateTime.now().toIso8601String().substring(0, 10)}.log',
    );

    test('timer flush writes buffered lines after interval', () async {
      bufferedLogging.captureEvent(
        'buffered line',
        domain: 'BUF_TEST',
      );

      // Give the async write time to settle
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // File should not exist yet (below threshold, timer not fired)
      expect(File(logPath0()).existsSync(), isFalse);

      // Wait for the flush timer to fire (500ms interval + margin)
      await Future<void>.delayed(const Duration(milliseconds: 600));

      final file = File(logPath0());
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(content, contains('[INFO] BUF_TEST: buffered line'));
    });

    test('force flush writes immediately for error level', () async {
      bufferedLogging.captureEvent(
        'error event',
        domain: 'ERR_FLUSH',
        level: InsightLevel.error,
      );

      // Give the async write chain time to complete
      await Future<void>.delayed(const Duration(milliseconds: 200));

      final file = File(logPath0());
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(content, contains('[ERROR] ERR_FLUSH: error event'));
    });

    test('threshold flush triggers when enough lines accumulate', () async {
      // Send exactly _fileFlushLineThreshold (40) events to trigger threshold
      for (var i = 0; i < 40; i++) {
        bufferedLogging.captureEvent(
          'line $i',
          domain: 'THRESHOLD',
        );
      }

      // Give the async write chain time to complete
      await Future<void>.delayed(const Duration(milliseconds: 500));

      final file = File(logPath0());
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      // Verify first and last lines are present
      expect(content, contains('[INFO] THRESHOLD: line 0'));
      expect(content, contains('[INFO] THRESHOLD: line 39'));
    });

    test('captureException force-flushes in non-test env', () async {
      bufferedLogging.captureException(
        'exc in buffered mode',
        domain: 'EXC_BUF',
      );

      // Give the async write chain time to complete
      await Future<void>.delayed(const Duration(milliseconds: 200));

      final file = File(logPath0());
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(content, contains('[ERROR] EXC_BUF: exc in buffered mode'));
    });

    test('flushPendingLines is no-op when no pending lines', () {
      fakeAsync((async) {
        // captureEvent with logging disabled => nothing queued
        final svc = LoggingService();
        // Don't call listenToConfigFlag, so _enableLogging stays false

        svc.captureEvent('should be skipped', domain: 'NOOP');
        async.elapse(const Duration(milliseconds: 100));
        async.flushMicrotasks();

        // No log file created since nothing was logged
        expect(File(logPath0()).existsSync(), isFalse);
      });
    });

    test('timer cancels when force flush arrives before timer fires', () async {
      // Queue a non-force event to start the timer
      bufferedLogging.captureEvent(
        'queued line',
        domain: 'CANCEL_TIMER',
      );

      // Immediately queue a force-flush event (error level)
      bufferedLogging.captureEvent(
        'forced line',
        domain: 'CANCEL_TIMER',
        level: InsightLevel.error,
      );

      // Give the async write chain time to complete
      await Future<void>.delayed(const Duration(milliseconds: 300));

      final file = File(logPath0());
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      // Both lines should be flushed together
      expect(content, contains('[INFO] CANCEL_TIMER: queued line'));
      expect(content, contains('[ERROR] CANCEL_TIMER: forced line'));
    });

    test('sync-family info events are routed to sync log only', () async {
      bufferedLogging.captureEvent(
        'timeline callback',
        domain: 'MATRIX_SYNC',
        subDomain: 'signal',
      );

      await bufferedLogging.flushAllForTest();

      final generalFile = File(logPath0());
      final syncFile = File(
        p.join(
          bufferedTempDocs.path,
          'logs',
          'sync-${DateTime.now().toIso8601String().substring(0, 10)}.log',
        ),
      );

      expect(generalFile.existsSync(), isFalse);
      expect(syncFile.existsSync(), isTrue);
      expect(
        syncFile.readAsStringSync(),
        contains('[INFO] MATRIX_SYNC signal: timeline callback'),
      );
    });

    test(
      'sync-family exceptions are written to both general and sync logs',
      () async {
        bufferedLogging.captureException(
          'sync blew up',
          domain: 'MATRIX_SYNC',
          subDomain: 'liveScan',
          stackTrace: 'trace',
        );

        await bufferedLogging.flushAllForTest();

        final generalFile = File(logPath0());
        final syncFile = File(
          p.join(
            bufferedTempDocs.path,
            'logs',
            'sync-${DateTime.now().toIso8601String().substring(0, 10)}.log',
          ),
        );

        expect(generalFile.existsSync(), isTrue);
        expect(syncFile.existsSync(), isTrue);
        expect(
          generalFile.readAsStringSync(),
          contains('[ERROR] MATRIX_SYNC liveScan: sync blew up trace'),
        );
        expect(
          syncFile.readAsStringSync(),
          contains('[ERROR] MATRIX_SYNC liveScan: sync blew up trace'),
        );
      },
    );
  });
}
