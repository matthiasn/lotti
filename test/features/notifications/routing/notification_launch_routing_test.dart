import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/notifications/routing/notification_launch_routing.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  late MockNotificationService service;
  late MockNotificationTapRouter router;
  late MockDomainLogger logger;

  /// How often the bootstrap thunk was asked for the service — the number
  /// of times the lazily registered plugin would have been materialised.
  late int serviceResolutions;

  setUp(() {
    resetNotificationLaunchRouting();
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    service = MockNotificationService();
    router = MockNotificationTapRouter();
    logger = MockDomainLogger();
    serviceResolutions = 0;
    when(
      () => service.launchNotificationPayload(),
    ).thenAnswer((_) async => null);
    when(() => router.handleTap(any())).thenAnswer((_) async {});
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    resetNotificationLaunchRouting();
  });

  Future<void> run({NotificationService Function()? notificationService}) =>
      routeNotificationLaunch(
        notificationService:
            notificationService ??
            () {
              serviceResolutions++;
              return service;
            },
        router: router,
        logger: logger,
      );

  void launchedWith(String? payload) {
    when(
      () => service.launchNotificationPayload(),
    ).thenAnswer((_) async => payload);
  }

  group('routeNotificationLaunch', () {
    test('routes the notification that launched the app', () async {
      launchedWith('/people/rel-1');

      await run();

      verify(() => router.handleTap('/people/rel-1')).called(1);
    });

    test('an ordinary launch reads the details and routes nothing', () async {
      await run();

      expect(serviceResolutions, 1);
      verifyNever(() => router.handleTap(any()));
    });

    for (final platform in [TargetPlatform.linux, TargetPlatform.windows]) {
      test('$platform never materialises the notification service', () async {
        debugDefaultTargetPlatformOverride = platform;
        launchedWith('/people/rel-1');

        await run();

        expect(serviceResolutions, 0);
        verifyNever(() => router.handleTap(any()));
      });
    }

    test(
      'asks once per process, however many service generations boot',
      () async {
        // `registerSingletons` runs again on a profile switch, and the launch
        // details describe the same tap every time they are read.
        launchedWith('/people/rel-1');

        await run();
        await run();

        expect(serviceResolutions, 1);
        verify(() => router.handleTap('/people/rel-1')).called(1);
      },
    );

    test('a service that cannot be built is logged, never thrown', () async {
      final failure = StateError('plugin failed to register');

      await expectLater(
        run(notificationService: () => throw failure),
        completes,
      );

      verify(
        () => logger.error(
          LogDomain.notifications,
          failure,
          stackTrace: any(named: 'stackTrace'),
          subDomain: 'launch',
        ),
      ).called(1);
      verifyNever(() => router.handleTap(any()));
    });

    test('a read that rejects its future is caught too', () async {
      when(
        () => service.launchNotificationPayload(),
      ).thenAnswer((_) async => throw StateError('late boom'));

      await expectLater(run(), completes);

      verify(
        () => logger.error(
          LogDomain.notifications,
          any<Object>(),
          stackTrace: any(named: 'stackTrace'),
          subDomain: 'launch',
        ),
      ).called(1);
    });
  });
}
