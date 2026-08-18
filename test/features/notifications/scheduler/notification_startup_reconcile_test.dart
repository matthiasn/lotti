import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/notifications/scheduler/notification_startup_reconcile.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  late MockNotificationScheduler scheduler;
  late MockDomainLogger logger;

  setUp(() {
    scheduler = MockNotificationScheduler();
    logger = MockDomainLogger();
  });

  Future<void> run() => reconcileScheduledNotifications(
    scheduler: scheduler,
    logger: logger,
  );

  group('reconcileScheduledNotifications', () {
    test('re-arms through the scheduler', () async {
      when(() => scheduler.reconcile()).thenAnswer((_) async {});

      await run();

      verify(() => scheduler.reconcile()).called(1);
      verifyNever(
        () => logger.error(
          any<LogDomain>(),
          any<Object>(),
          stackTrace: any(named: 'stackTrace'),
          subDomain: any(named: 'subDomain'),
        ),
      );
    });

    test('a failure is logged, never thrown', () async {
      // Startup calls this fire-and-forget, so an escaping error would arrive
      // as an unhandled async error during boot — for a notification database
      // read that the next write re-schedules anyway.
      final failure = StateError('notifications.sqlite unreadable');
      when(() => scheduler.reconcile()).thenThrow(failure);

      await expectLater(run(), completes);

      verify(
        () => logger.error(
          LogDomain.notifications,
          failure,
          stackTrace: any(named: 'stackTrace'),
          subDomain: 'reconcile',
        ),
      ).called(1);
    });

    test('an asynchronous failure is caught too', () async {
      // The plugin rejects its future rather than throwing synchronously, so
      // the catch has to wrap the await — not just the call.
      when(
        () => scheduler.reconcile(),
      ).thenAnswer((_) async => throw StateError('late boom'));

      await expectLater(run(), completes);

      verify(
        () => logger.error(
          LogDomain.notifications,
          any<Object>(),
          stackTrace: any(named: 'stackTrace'),
          subDomain: 'reconcile',
        ),
      ).called(1);
    });
  });
}
