import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks/mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LoggingService Tests', () {
    late MockJournalDb mockJournalDb;
    late MockLoggingDb mockLoggingDb;
    late StreamController<bool> configFlagController;
    late LoggingService loggingService;

    setUpAll(() {
      registerFallbackValue(
        LogEntry(
          id: 'test-id',
          createdAt: DateTime.now().toIso8601String(),
          domain: 'test',
          message: 'test',
          level: 'INFO',
          type: 'LOG',
        ),
      );
    });

    setUp(() {
      if (getIt.isRegistered<JournalDb>()) {
        getIt.unregister<JournalDb>();
      }
      if (getIt.isRegistered<LoggingDb>()) {
        getIt.unregister<LoggingDb>();
      }

      mockJournalDb = MockJournalDb();
      mockLoggingDb = MockLoggingDb();
      configFlagController = StreamController<bool>();

      when(() => mockJournalDb.watchConfigFlag(enableLoggingFlag))
          .thenAnswer((_) => configFlagController.stream);

      when(() => mockLoggingDb.log(any())).thenAnswer((_) async => 1);

      getIt
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<LoggingDb>(mockLoggingDb);

      loggingService = LoggingService();
    });

    tearDown(() async {
      await configFlagController.close();
    });

    test('listenToConfigFlag enables logging when flag is true', () async {
      loggingService.listenToConfigFlag();

      configFlagController.add(true);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      loggingService.captureEvent(
        'test event',
        domain: 'test-domain',
      );

      await Future<void>.delayed(const Duration(milliseconds: 100));

      verify(() => mockLoggingDb.log(any())).called(1);
    });

    test('listenToConfigFlag disables logging when flag is false', () async {
      loggingService.listenToConfigFlag();

      configFlagController.add(false);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      loggingService.captureEvent(
        'test event',
        domain: 'test-domain',
      );

      await Future<void>.delayed(const Duration(milliseconds: 100));

      verifyNever(() => mockLoggingDb.log(any()));
    });

    test('captureEvent logs with correct parameters', () async {
      loggingService.listenToConfigFlag();

      configFlagController.add(true);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      loggingService.captureEvent(
        'test event message',
        domain: 'test-domain',
        subDomain: 'test-subdomain',
        level: InsightLevel.warn,
      );

      await Future<void>.delayed(const Duration(milliseconds: 100));

      final captured = verify(() => mockLoggingDb.log(captureAny()))
          .captured
          .single as LogEntry;

      expect(captured.domain, 'test-domain');
      expect(captured.subDomain, 'test-subdomain');
      expect(captured.message, 'test event message');
      expect(captured.level, 'WARN');
      expect(captured.type, 'LOG');
    });

    test('captureEvent uses default level and type', () async {
      loggingService.listenToConfigFlag();

      configFlagController.add(true);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      loggingService.captureEvent(
        'test event',
        domain: 'test-domain',
      );

      await Future<void>.delayed(const Duration(milliseconds: 100));

      final captured = verify(() => mockLoggingDb.log(captureAny()))
          .captured
          .single as LogEntry;

      expect(captured.level, 'INFO');
      expect(captured.type, 'LOG');
    });

    test('captureException logs with stack trace', () async {
      loggingService.listenToConfigFlag();

      configFlagController.add(true);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final exception = Exception('Test exception');
      final stackTrace = StackTrace.current;

      loggingService.captureException(
        exception,
        domain: 'error-domain',
        subDomain: 'error-subdomain',
        stackTrace: stackTrace,
      );

      await Future<void>.delayed(const Duration(milliseconds: 100));

      final captured = verify(() => mockLoggingDb.log(captureAny()))
          .captured
          .single as LogEntry;

      expect(captured.domain, 'error-domain');
      expect(captured.subDomain, 'error-subdomain');
      expect(captured.message, contains('Test exception'));
      expect(captured.stacktrace, isNotNull);
      expect(captured.level, 'ERROR');
      expect(captured.type, 'EXCEPTION');
    });

    test('captureException uses default level and type', () async {
      loggingService.listenToConfigFlag();

      configFlagController.add(true);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final exception = Exception('Test exception');

      loggingService.captureException(
        exception,
        domain: 'error-domain',
      );

      await Future<void>.delayed(const Duration(milliseconds: 100));

      final captured = verify(() => mockLoggingDb.log(captureAny()))
          .captured
          .single as LogEntry;

      expect(captured.level, 'ERROR');
      expect(captured.type, 'EXCEPTION');
    });

    test('captureException without stack trace', () async {
      loggingService.listenToConfigFlag();

      configFlagController.add(true);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final exception = Exception('Test exception');

      loggingService.captureException(
        exception,
        domain: 'error-domain',
      );

      await Future<void>.delayed(const Duration(milliseconds: 100));

      final captured = verify(() => mockLoggingDb.log(captureAny()))
          .captured
          .single as LogEntry;

      expect(captured.stacktrace, isNotNull);
    });
  });
}
