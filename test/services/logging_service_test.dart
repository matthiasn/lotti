// ignore_for_file: cascade_invocations

import 'dart:async';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/get_it.dart';
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
}
