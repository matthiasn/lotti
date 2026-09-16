import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/logging_types.dart';
import 'package:lotti/features/notifications/model/notification_tap_payload.dart';
import 'package:lotti/features/notifications/routing/notification_tap_router.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  late MockNavService navService;
  late MockNotificationRepository repository;
  late MockDomainLogger logger;
  late NotificationTapRouter router;

  setUp(() {
    navService = MockNavService();
    repository = MockNotificationRepository();
    logger = MockDomainLogger();
    when(() => repository.markSeen(any())).thenAnswer((_) async => null);
    router = NotificationTapRouter(
      navService: navService,
      notificationRepository: repository,
      logger: logger,
    );
  });

  String encoded(String route, {String? inboxId}) =>
      NotificationTapPayload(route: route, inboxId: inboxId).encode();

  void verifyNothingLogged() {
    verifyNever(
      () => logger.log(
        any<LogDomain>(),
        any(),
        subDomain: any(named: 'subDomain'),
        level: any(named: 'level'),
      ),
    );
    verifyNever(
      () => logger.error(
        any<LogDomain>(),
        any<Object>(),
        stackTrace: any(named: 'stackTrace'),
        subDomain: any(named: 'subDomain'),
      ),
    );
  }

  group('NotificationTapRouter.handleTap', () {
    test('an inbox row opens its route and is marked seen', () async {
      await router.handleTap(encoded('/people/rel-1', inboxId: 'row-1'));

      verify(() => navService.beamToNamedWhenReady('/people/rel-1')).called(1);
      verify(() => repository.markSeen('row-1')).called(1);
      verifyNothingLogged();
    });

    test('a bare route opens its screen and touches no row', () async {
      await router.handleTap('/calendar');

      verify(() => navService.beamToNamedWhenReady('/calendar')).called(1);
      verifyNever(() => repository.markSeen(any()));
      verifyNothingLogged();
    });

    test('the screen opens before the row is marked', () async {
      await router.handleTap(encoded('/tasks/t-1', inboxId: 'row-1'));

      verifyInOrder([
        () => navService.beamToNamedWhenReady('/tasks/t-1'),
        () => repository.markSeen('row-1'),
      ]);
    });

    for (final (label, raw) in <(String, String?)>[
      ('no payload', null),
      ('a payload nothing can be read from', 'not a payload'),
    ]) {
      test('a tap with $label is dropped with a warning', () async {
        await router.handleTap(raw);

        verifyNever(() => navService.beamToNamedWhenReady(any()));
        verifyNever(() => repository.markSeen(any()));
        verify(
          () => logger.log(
            LogDomain.notifications,
            any(that: contains('no routable payload')),
            subDomain: 'tap',
            level: InsightLevel.warn,
          ),
        ).called(1);
      });
    }

    test(
      'a failing markSeen is logged and does not undo the navigation',
      () async {
        final failure = StateError('notifications.sqlite unavailable');
        when(() => repository.markSeen('row-1')).thenThrow(failure);

        await expectLater(
          router.handleTap(encoded('/tasks/t-1', inboxId: 'row-1')),
          completes,
        );

        verify(() => navService.beamToNamedWhenReady('/tasks/t-1')).called(1);
        verify(
          () => logger.error(
            LogDomain.notifications,
            failure,
            stackTrace: any(named: 'stackTrace'),
            subDomain: 'tap.markSeen',
          ),
        ).called(1);
      },
    );

    test('an asynchronous markSeen failure is caught too', () async {
      // The repository rejects its future rather than throwing synchronously,
      // so the catch has to wrap the await — not just the call.
      when(
        () => repository.markSeen('row-1'),
      ).thenAnswer((_) async => throw StateError('late boom'));

      await expectLater(
        router.handleTap(encoded('/tasks/t-1', inboxId: 'row-1')),
        completes,
      );

      verify(
        () => logger.error(
          LogDomain.notifications,
          any<Object>(),
          stackTrace: any(named: 'stackTrace'),
          subDomain: 'tap.markSeen',
        ),
      ).called(1);
    });
  });
}
