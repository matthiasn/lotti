// ignore_for_file: cascade_invocations

import 'dart:async';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_types.dart';
import 'package:lotti/database/slow_query_logging.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/dev_logger.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/platform.dart' as platform;
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;

import '../mocks/mocks.dart';

/// Finds the first `.log` file matching [prefix] in the logs/ subdirectory.
/// Returns `null` when no matching file exists yet.
File? _findLogFile(Directory docsDir, {String prefix = 'lotti-'}) {
  final logDir = Directory(p.join(docsDir.path, 'logs'));
  if (!logDir.existsSync()) return null;
  final matches = logDir
      .listSync()
      .whereType<File>()
      .where((f) => p.basename(f.path).startsWith(prefix))
      .toList();
  return matches.isEmpty ? null : matches.first;
}

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
    when(
      () => journalDb.watchConfigFlag(logSlowQueriesFlag),
    ).thenAnswer((_) => Stream<bool>.value(false));

    SlowQueryLoggingGate.resetForTest();

    logging = getIt<LoggingService>();
    await logging.listenToConfigFlag();
  });

  tearDown(SlowQueryLoggingGate.resetForTest);

  /// Builds a [LoggingService] wired to two controllable config-flag streams so
  /// tests can drive values, errors and `done` deterministically. Registers
  /// teardown for the controllers and the service.
  ({
    LoggingService service,
    StreamController<bool> logging,
    StreamController<bool> slowQuery,
  })
  makeControlledService() {
    final loggingController = StreamController<bool>();
    final slowQueryController = StreamController<bool>();
    addTearDown(loggingController.close);
    addTearDown(slowQueryController.close);
    when(
      () => journalDb.watchConfigFlag(enableLoggingFlag),
    ).thenAnswer((_) => loggingController.stream);
    when(
      () => journalDb.watchConfigFlag(logSlowQueriesFlag),
    ).thenAnswer((_) => slowQueryController.stream);
    final service = LoggingService();
    addTearDown(service.dispose);
    return (
      service: service,
      logging: loggingController,
      slowQuery: slowQueryController,
    );
  }

  test('captureEvent writes to file when enabled', () {
    fakeAsync((async) {
      logging.captureEvent(
        'hello world',
        domain: 'TEST',
        subDomain: 'sub',
      );

      async.flushMicrotasks();

      final logDir = Directory(p.join(tempDocs.path, 'logs'));
      if (!logDir.existsSync()) {
        fail('Log directory not created');
      }
      final logFiles = logDir.listSync().whereType<File>().where(
        (f) => f.path.endsWith('.log'),
      );
      expect(logFiles, isNotEmpty);
      final content = logFiles.first.readAsStringSync();
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

      final logDir = Directory(p.join(tempDocs.path, 'logs'));
      final logFiles = logDir.listSync().whereType<File>().where(
        (f) => f.path.endsWith('.log'),
      );
      expect(logFiles, isNotEmpty);
      final logPath = logFiles.first.path;
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

  test('captureException is mirrored to the daily error log', () {
    fakeAsync((async) {
      logging.captureException(
        'kaboom',
        domain: 'DB',
        subDomain: 'insert',
        stackTrace: 'trace',
      );

      async.flushMicrotasks();

      final errorFile = _findLogFile(tempDocs, prefix: 'error-');
      expect(errorFile, isNotNull, reason: 'error-*.log should exist');
      expect(
        errorFile!.readAsStringSync(),
        contains(' [ERROR] DB insert: kaboom trace'),
      );
    });
  });

  test('error-level captureEvent is mirrored to the daily error log', () {
    fakeAsync((async) {
      logging.captureEvent(
        'something bad',
        domain: 'DB',
        subDomain: 'query',
        level: InsightLevel.error,
      );

      async.flushMicrotasks();

      final errorFile = _findLogFile(tempDocs, prefix: 'error-');
      expect(errorFile, isNotNull, reason: 'error-*.log should exist');
      expect(
        errorFile!.readAsStringSync(),
        contains(' [ERROR] DB query: something bad'),
      );
    });
  });

  test('info-level captureEvent does not write to the daily error log', () {
    fakeAsync((async) {
      logging.captureEvent('all good', domain: 'DB', subDomain: 'query');

      async.flushMicrotasks();

      expect(
        _findLogFile(tempDocs, prefix: 'error-'),
        isNull,
        reason: 'info events must not reach the error log',
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

      final logFile = _findLogFile(tempDocs);
      expect(logFile, isNotNull, reason: 'Log file should exist');
      final content = logFile!.readAsStringSync();
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

      final logFile = _findLogFile(tempDocs);
      expect(logFile, isNull, reason: 'Log file should not exist');
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
      final brokenLogging = LoggingService();
      unawaited(brokenLogging.listenToConfigFlag());

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
      final brokenLogging = LoggingService();
      unawaited(brokenLogging.listenToConfigFlag());

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

  test('captureEvent supports warn level', () {
    fakeAsync((async) {
      logging.captureEvent(
        'warn message',
        domain: 'WARN_TEST',
        level: InsightLevel.warn,
      );

      async.flushMicrotasks();

      final logFile = _findLogFile(tempDocs);
      expect(logFile, isNotNull, reason: 'Log file should exist');
      final content = logFile!.readAsStringSync();
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

      final logFile = _findLogFile(tempDocs);
      expect(logFile, isNotNull, reason: 'Log file should exist');
      final content = logFile!.readAsStringSync();
      // Should not have extra space before colon when no subDomain
      expect(content.contains('[INFO] NOSUB: no subdomain'), isTrue);
      expect(content.contains('NOSUB : '), isFalse); // No trailing space
    });
  });

  test('config flag listener dynamically toggles logging', () async {
    // Create a StreamController to control the flag stream
    final flagController = StreamController<bool>();
    final slowQueryController = StreamController<bool>();
    addTearDown(flagController.close);
    addTearDown(slowQueryController.close);

    when(
      () => journalDb.watchConfigFlag(enableLoggingFlag),
    ).thenAnswer((_) => flagController.stream);
    when(
      () => journalDb.watchConfigFlag(logSlowQueriesFlag),
    ).thenAnswer((_) => slowQueryController.stream);

    final svc = LoggingService();
    unawaited(svc.listenToConfigFlag());

    // Initially disabled (isTestEnv = true means _enableLogging = false)
    svc.captureEvent('should be skipped', domain: 'TOGGLE');
    await Future<void>.delayed(Duration.zero);

    expect(_findLogFile(tempDocs), isNull);

    // Enable logging via config flag
    flagController.add(true);
    await Future<void>.delayed(Duration.zero);

    svc.captureEvent('should be logged', domain: 'TOGGLE');
    await svc.flushAllForTest();

    final logFile = _findLogFile(tempDocs);
    expect(logFile, isNotNull, reason: 'Log file should exist after enabling');
    final content = logFile!.readAsStringSync();
    expect(content.contains('TOGGLE: should be logged'), isTrue);
    // The skipped event should NOT be in the file
    expect(content.contains('should be skipped'), isFalse);

    // Disable logging via config flag
    flagController.add(false);
    await Future<void>.delayed(Duration.zero);

    svc.captureEvent('should be skipped again', domain: 'TOGGLE');
    await svc.flushAllForTest();

    // File content should not contain the disabled event
    final content2 = logFile.readAsStringSync();
    expect(content2.contains('should be skipped again'), isFalse);
  });

  test(
    'slow query gate requires both global logging and slow query flag',
    () async {
      final loggingController = StreamController<bool>();
      final slowQueryController = StreamController<bool>();
      addTearDown(loggingController.close);
      addTearDown(slowQueryController.close);

      when(
        () => journalDb.watchConfigFlag(enableLoggingFlag),
      ).thenAnswer((_) => loggingController.stream);
      when(
        () => journalDb.watchConfigFlag(logSlowQueriesFlag),
      ).thenAnswer((_) => slowQueryController.stream);

      final svc = LoggingService();
      unawaited(svc.listenToConfigFlag());
      expect(svc, isNotNull);

      loggingController.add(false);
      slowQueryController.add(true);
      await Future<void>.delayed(Duration.zero);
      expect(SlowQueryLoggingGate.isEnabled, isFalse);

      loggingController.add(true);
      await Future<void>.delayed(Duration.zero);
      expect(SlowQueryLoggingGate.isEnabled, isTrue);

      slowQueryController.add(false);
      await Future<void>.delayed(Duration.zero);
      expect(SlowQueryLoggingGate.isEnabled, isFalse);
    },
  );

  test(
    'listenToConfigFlag completes after seeding initial slow query gate state',
    () async {
      when(
        () => journalDb.watchConfigFlag(enableLoggingFlag),
      ).thenAnswer((_) => Stream<bool>.value(true));
      when(
        () => journalDb.watchConfigFlag(logSlowQueriesFlag),
      ).thenAnswer((_) => Stream<bool>.value(true));

      SlowQueryLoggingGate.resetForTest();
      final svc = LoggingService();
      addTearDown(svc.dispose);

      await svc.listenToConfigFlag();

      expect(SlowQueryLoggingGate.isEnabled, isTrue);
      expect(SlowQueryLoggingGate.captureFirstCallStack, isTrue);
    },
  );

  test(
    'dispose cancels config-flag subscriptions so later events are ignored',
    () async {
      final loggingController = StreamController<bool>();
      final slowQueryController = StreamController<bool>();
      addTearDown(loggingController.close);
      addTearDown(slowQueryController.close);

      when(
        () => journalDb.watchConfigFlag(enableLoggingFlag),
      ).thenAnswer((_) => loggingController.stream);
      when(
        () => journalDb.watchConfigFlag(logSlowQueriesFlag),
      ).thenAnswer((_) => slowQueryController.stream);

      final svc = LoggingService();
      unawaited(svc.listenToConfigFlag());

      // Enable both flags so the slow-query gate is on, proving the
      // subscriptions are live before dispose.
      loggingController.add(true);
      slowQueryController.add(true);
      await Future<void>.delayed(Duration.zero);
      expect(
        SlowQueryLoggingGate.isEnabled,
        isTrue,
        reason: 'gate should reflect live subscriptions before dispose',
      );

      // dispose() awaits cancellation of both subscriptions (lines 70-72).
      await svc.dispose();

      // After dispose, further stream events must NOT mutate the gate, proving
      // both subscriptions were cancelled.
      loggingController.add(false);
      slowQueryController.add(false);
      await Future<void>.delayed(Duration.zero);
      expect(
        SlowQueryLoggingGate.isEnabled,
        isTrue,
        reason: 'cancelled subscriptions must ignore post-dispose events',
      );
    },
  );

  test('dispose is safe when listenToConfigFlag was never called', () async {
    final svc = LoggingService();
    // Both subscriptions are null; dispose must complete without throwing.
    await expectLater(svc.dispose(), completes);
  });

  test(
    'listenToConfigFlag cancels prior subscriptions when called again',
    () async {
      final logging1 = StreamController<bool>();
      final slowQuery1 = StreamController<bool>();
      final logging2 = StreamController<bool>();
      final slowQuery2 = StreamController<bool>();
      addTearDown(logging1.close);
      addTearDown(slowQuery1.close);
      addTearDown(logging2.close);
      addTearDown(slowQuery2.close);

      when(
        () => journalDb.watchConfigFlag(enableLoggingFlag),
      ).thenAnswer((_) => logging1.stream);
      when(
        () => journalDb.watchConfigFlag(logSlowQueriesFlag),
      ).thenAnswer((_) => slowQuery1.stream);

      final svc = LoggingService();
      addTearDown(svc.dispose);

      unawaited(svc.listenToConfigFlag());
      logging1.add(true);
      slowQuery1.add(true);
      await Future<void>.delayed(Duration.zero);
      expect(logging1.hasListener, isTrue);
      expect(slowQuery1.hasListener, isTrue);

      // Point the next call at fresh controllers, then re-invoke. The repeated
      // call must cancel the prior subscriptions before creating new ones.
      when(
        () => journalDb.watchConfigFlag(enableLoggingFlag),
      ).thenAnswer((_) => logging2.stream);
      when(
        () => journalDb.watchConfigFlag(logSlowQueriesFlag),
      ).thenAnswer((_) => slowQuery2.stream);

      unawaited(svc.listenToConfigFlag());
      logging2.add(true);
      slowQuery2.add(true);
      await Future<void>.delayed(Duration.zero);

      expect(
        logging1.hasListener,
        isFalse,
        reason: 'prior logging subscription must be cancelled',
      );
      expect(
        slowQuery1.hasListener,
        isFalse,
        reason: 'prior slow-query subscription must be cancelled',
      );
      expect(
        logging2.hasListener,
        isTrue,
        reason: 'new logging subscription must be live',
      );
      expect(
        slowQuery2.hasListener,
        isTrue,
        reason: 'new slow-query subscription must be live',
      );
    },
  );

  test(
    'listenToConfigFlag surfaces a logging-flag stream error',
    () async {
      final controlled = makeControlledService();
      final ready = controlled.service.listenToConfigFlag();

      final error = StateError('logging flag stream failed');
      controlled.logging.addError(error);
      // The slow-query side must still complete so Future.wait resolves and
      // the logging error is the one propagated.
      controlled.slowQuery.add(true);

      await expectLater(ready, throwsA(same(error)));
    },
  );

  test(
    'listenToConfigFlag surfaces a slow-query-flag stream error',
    () async {
      final controlled = makeControlledService();
      final ready = controlled.service.listenToConfigFlag();

      controlled.logging.add(true);
      final error = StateError('slow-query flag stream failed');
      controlled.slowQuery.addError(error);

      await expectLater(ready, throwsA(same(error)));
    },
  );

  test(
    'listenToConfigFlag ignores a stream error after the gate is seeded',
    () async {
      final controlled = makeControlledService();
      final ready = controlled.service.listenToConfigFlag();

      // Seed both flags so the gate turns on and both completers complete.
      controlled.logging.add(true);
      controlled.slowQuery.add(true);
      await ready;
      expect(SlowQueryLoggingGate.isEnabled, isTrue);

      // A late error must be swallowed by the already-completed guard: it must
      // neither throw an unhandled error nor disturb the seeded gate state.
      controlled.slowQuery.addError(StateError('late stream error'));
      await Future<void>.delayed(Duration.zero);

      expect(
        SlowQueryLoggingGate.isEnabled,
        isTrue,
        reason: 'late error must not disturb the already-seeded gate',
      );
    },
  );

  test('captureException with null stackTrace handles gracefully', () {
    fakeAsync((async) {
      logging.captureException(
        'error without stack',
        domain: 'NULL_STACK',
      );

      async.flushMicrotasks();

      final logFile = _findLogFile(tempDocs);
      expect(logFile, isNotNull, reason: 'Log file should exist');
      final content = logFile!.readAsStringSync();
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

      final logFile = _findLogFile(tempDocs);
      expect(logFile, isNotNull, reason: 'Log file should exist');
      final content = logFile!.readAsStringSync();
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

      final logFile = _findLogFile(tempDocs);
      expect(logFile, isNotNull, reason: 'Log file should exist');
      final content = logFile!.readAsStringSync();
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
      when(
        () => bufferedJournalDb.watchConfigFlag(logSlowQueriesFlag),
      ).thenAnswer((_) => Stream<bool>.value(false));

      bufferedLogging = getIt<LoggingService>();
      await bufferedLogging.listenToConfigFlag();
    });

    File? findGeneralLog() => _findLogFile(bufferedTempDocs);
    File? findSyncLog() => _findLogFile(bufferedTempDocs, prefix: 'sync-');

    test(
      'single buffered line is flushed when the 500 ms flush timer fires',
      () async {
        // A lone, non-force info event neither hits the line threshold nor
        // force-flushes, so the only thing that drains it is the buffered
        // flush timer scheduled in `_appendToNamedFile` (lines 94-100 of
        // logging_service.dart). We deliberately do NOT call
        // `flushAllForTest()` to trigger the buffering — only the timer
        // firing performs the drain. The `timerFactory` seam lets us drive
        // that 500 ms timer deterministically under `fakeAsync` instead of
        // polling wall-clock time, which was flaky on slow CI.
        Duration? scheduledDelay;
        void Function()? productionFlushCallback;

        // Override the production timer factory so the buffered-flush timer is
        // driven by `fakeAsync` (via a virtual `Timer.new`) while the actual
        // file-write callback runs OUTSIDE the fake zone. The production
        // callback performs genuine async file I/O, which a virtual clock
        // cannot complete; capturing it and invoking it in the real zone keeps
        // the assertion deterministic without losing 500 ms-timer coverage.
        bufferedLogging.timerFactory = (duration, callback) {
          scheduledDelay = duration;
          // Virtual timer: `async.elapse` advances it. When it fires we record
          // the production flush callback rather than running its real I/O
          // inside the fake zone.
          return Timer(duration, () => productionFlushCallback = callback);
        };

        fakeAsync((async) {
          bufferedLogging.captureEvent(
            'timer flushed line',
            domain: 'TIMER_FLUSH',
          );
          // Drain the captureEvent microtasks so the buffered line is queued
          // and the flush timer is scheduled.
          async.flushMicrotasks();

          // Buffered only — the flush timer was scheduled at 500 ms but has
          // not fired, so nothing is on disk and the callback isn't captured.
          expect(scheduledDelay, const Duration(milliseconds: 500));
          expect(findGeneralLog(), isNull);

          // Just shy of 500 ms: still buffered, timer not yet fired.
          async
            ..elapse(const Duration(milliseconds: 499))
            ..flushMicrotasks();
          expect(productionFlushCallback, isNull);
          expect(findGeneralLog(), isNull);

          // Crossing 500 ms fires the virtual timer, capturing the production
          // flush callback.
          async
            ..elapse(const Duration(milliseconds: 1))
            ..flushMicrotasks();
        });

        // The timer fired inside the fake zone; now run the production flush
        // callback in the real zone so its async file write actually lands.
        expect(
          productionFlushCallback,
          isNotNull,
          reason: 'the 500 ms flush timer should have fired its callback',
        );
        productionFlushCallback!();
        // Deterministically drain the genuine async file write the callback
        // kicked off. `pumpEventQueue()` runs the real event loop until it is
        // idle — no fixed sleep, no wall-clock polling — so the timer-initiated
        // write has landed once it returns.
        await pumpEventQueue();

        final file = findGeneralLog();
        expect(
          file,
          isNotNull,
          reason: 'firing the 500 ms flush timer should have written the file',
        );
        expect(
          file!.readAsStringSync(),
          contains('[INFO] TIMER_FLUSH: timer flushed line'),
        );
      },
    );

    test('buffered lines are flushed to file', () async {
      bufferedLogging.captureEvent(
        'buffered line',
        domain: 'BUF_TEST',
      );

      // Line is only in the in-memory buffer; no file yet.
      expect(findGeneralLog(), isNull);

      // Deterministic flush instead of racing real timers (flaky on CI).
      await bufferedLogging.flushAllForTest();

      final file = findGeneralLog();
      expect(file, isNotNull, reason: 'Log file should exist after flush');
      final content = file!.readAsStringSync();
      expect(content, contains('[INFO] BUF_TEST: buffered line'));
    });

    test('force flush writes immediately for error level', () async {
      bufferedLogging.captureEvent(
        'error event',
        domain: 'ERR_FLUSH',
        level: InsightLevel.error,
      );

      await bufferedLogging.flushAllForTest();

      final file = findGeneralLog();
      expect(file, isNotNull, reason: 'Log file should exist');
      final content = file!.readAsStringSync();
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

      // Deterministically flush the buffered write chain (fake-time policy).
      await bufferedLogging.flushAllForTest();

      final file = findGeneralLog();
      expect(file, isNotNull, reason: 'Log file should exist');
      final content = file!.readAsStringSync();
      // Verify first and last lines are present
      expect(content, contains('[INFO] THRESHOLD: line 0'));
      expect(content, contains('[INFO] THRESHOLD: line 39'));
    });

    test('captureException force-flushes in non-test env', () async {
      bufferedLogging.captureException(
        'exc in buffered mode',
        domain: 'EXC_BUF',
      );

      // Deterministically flush the buffered write chain (fake-time policy).
      await bufferedLogging.flushAllForTest();

      final file = findGeneralLog();
      expect(file, isNotNull, reason: 'Log file should exist');
      final content = file!.readAsStringSync();
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
        expect(findGeneralLog(), isNull);
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

      // Deterministically flush the buffered write chain (fake-time policy).
      await bufferedLogging.flushAllForTest();

      final file = findGeneralLog();
      expect(file, isNotNull, reason: 'Log file should exist');
      final content = file!.readAsStringSync();
      // Both lines should be flushed together
      expect(content, contains('[INFO] CANCEL_TIMER: queued line'));
      expect(content, contains('[ERROR] CANCEL_TIMER: forced line'));
    });

    test('sync-family info events are routed to sync log only', () async {
      bufferedLogging.captureEvent(
        'timeline callback',
        domain: 'sync',
        subDomain: 'signal',
      );

      await bufferedLogging.flushAllForTest();

      final generalFile = findGeneralLog();
      final syncFile = findSyncLog();

      expect(generalFile, isNull, reason: 'General log should not exist');
      expect(syncFile, isNotNull, reason: 'Sync log should exist');
      expect(
        syncFile!.readAsStringSync(),
        contains('[INFO] sync signal: timeline callback'),
      );
    });

    test(
      'sync-family exceptions are written to both general and sync logs',
      () async {
        bufferedLogging.captureException(
          'sync blew up',
          domain: 'sync',
          subDomain: 'liveScan',
          stackTrace: 'trace',
        );

        await bufferedLogging.flushAllForTest();

        final generalFile = findGeneralLog();
        final syncFile = findSyncLog();

        expect(generalFile, isNotNull, reason: 'General log should exist');
        expect(syncFile, isNotNull, reason: 'Sync log should exist');
        expect(
          generalFile!.readAsStringSync(),
          contains('[ERROR] sync liveScan: sync blew up trace'),
        );
        expect(
          syncFile!.readAsStringSync(),
          contains('[ERROR] sync liveScan: sync blew up trace'),
        );
      },
    );
  });
}
