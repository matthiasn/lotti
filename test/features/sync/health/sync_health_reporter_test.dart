// ignore_for_file: avoid_redundant_argument_values
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/features/sync/health/sync_health_reporter.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

void main() {
  late MockSyncDatabase mockSyncDb;
  late MockLoggingService mockLoggingService;
  late DomainLogger domainLogger;

  setUpAll(registerAllFallbackValues);

  setUp(() {
    mockSyncDb = MockSyncDatabase();
    mockLoggingService = MockLoggingService();
    domainLogger = DomainLogger(loggingService: mockLoggingService);
  });

  group('SyncHealthReporter', () {
    test('emits health summary when sync domain is enabled', () {
      fakeAsync((async) {
        domainLogger.enabledDomains.add(LogDomains.sync);

        when(
          () => mockSyncDb.getPendingOutboxCount(),
        ).thenAnswer((_) async => 42);
        when(
          () => mockSyncDb.getMissingSequenceCount(),
        ).thenAnswer((_) async => 3);
        when(
          () => mockSyncDb.getRequestedSequenceCount(),
        ).thenAnswer((_) async => 7);
        when(
          () => mockSyncDb.getSentCountSince(any()),
        ).thenAnswer((_) async => 128);

        final reporter = SyncHealthReporter(
          syncDatabase: mockSyncDb,
          domainLogger: domainLogger,
          interval: const Duration(minutes: 5),
        )..start();

        // Advance past one interval
        async.elapse(const Duration(minutes: 5, seconds: 1));

        verify(() => mockSyncDb.getPendingOutboxCount()).called(1);
        verify(() => mockSyncDb.getMissingSequenceCount()).called(1);
        verify(() => mockSyncDb.getRequestedSequenceCount()).called(1);
        verify(() => mockSyncDb.getSentCountSince(any())).called(1);

        // Verify the logging service was called (DomainLogger delegates to it)
        verify(
          () => mockLoggingService.captureEvent(
            any<dynamic>(that: contains('health: outbox.pending=42')),
            domain: LogDomains.sync,
            subDomain: 'health',
            level: any<InsightLevel>(named: 'level'),
            type: any<InsightType>(named: 'type'),
          ),
        ).called(1);

        reporter.dispose();
      });
    });

    test('does not emit when sync domain is not enabled', () {
      fakeAsync((async) {
        // Do NOT add LogDomains.sync to enabledDomains

        final reporter = SyncHealthReporter(
          syncDatabase: mockSyncDb,
          domainLogger: domainLogger,
          interval: const Duration(minutes: 5),
        )..start();

        async.elapse(const Duration(minutes: 5, seconds: 1));

        // Should not query the DB at all
        verifyNever(() => mockSyncDb.getPendingOutboxCount());
        verifyNever(() => mockSyncDb.getMissingSequenceCount());

        reporter.dispose();
      });
    });

    test('does not emit after dispose', () {
      fakeAsync((async) {
        domainLogger.enabledDomains.add(LogDomains.sync);

        final reporter =
            SyncHealthReporter(
                syncDatabase: mockSyncDb,
                domainLogger: domainLogger,
                interval: const Duration(minutes: 5),
              )
              ..start()
              ..dispose();

        async.elapse(const Duration(minutes: 10));

        verifyNever(() => mockSyncDb.getPendingOutboxCount());

        reporter.dispose(); // safe to call twice
      });
    });

    test('handles DB errors gracefully', () {
      fakeAsync((async) {
        domainLogger.enabledDomains.add(LogDomains.sync);

        when(
          () => mockSyncDb.getPendingOutboxCount(),
        ).thenThrow(Exception('DB error'));

        final reporter = SyncHealthReporter(
          syncDatabase: mockSyncDb,
          domainLogger: domainLogger,
          interval: const Duration(minutes: 5),
        )..start();

        // Should not throw
        async.elapse(const Duration(minutes: 5, seconds: 1));

        // Error logger should have been called
        verify(
          () => mockLoggingService.captureException(
            any<dynamic>(),
            domain: LogDomains.sync,
            subDomain: 'health',
            stackTrace: any<dynamic>(named: 'stackTrace'),
            level: any<InsightLevel>(named: 'level'),
            type: any<InsightType>(named: 'type'),
          ),
        ).called(1);

        reporter.dispose();
      });
    });
  });
}
