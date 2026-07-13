import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_onboarding_session.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_onboarding_session_controller.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_onboarding_trigger_service.dart';
import 'package:lotti/features/onboarding/model/onboarding_event.dart';
import 'package:lotti/features/onboarding/repository/onboarding_metrics_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

/// Counts `markCompleted` without touching SettingsDb.
class _CountingCadence extends DailyOsOnboardingCadence {
  int markCompletedCount = 0;

  @override
  FutureOr<void> build() {}

  @override
  Future<void> markCompleted() async => markCompletedCount++;
}

void main() {
  final targetDate = DateTime(2026, 7, 10);

  setUp(setUpTestGetIt);
  tearDown(tearDownTestGetIt);

  setUpAll(() {
    registerFallbackValue(OnboardingEventName.dailyOsWalkthroughShown);
  });

  ProviderContainer makeContainer({List<Override> overrides = const []}) {
    final container = ProviderContainer(overrides: overrides);
    addTearDown(container.dispose);
    return container;
  }

  DailyOsOnboardingSessionController controllerOf(ProviderContainer c) =>
      c.read(dailyOsOnboardingSessionControllerProvider.notifier);

  group('lifecycle', () {
    test('starts with no active session', () {
      final container = makeContainer();
      expect(
        container.read(dailyOsOnboardingSessionControllerProvider),
        isNull,
      );
    });

    test('start makes a session with the given origin the active session', () {
      final container = makeContainer();
      final session =
          controllerOf(
            container,
          ).start(
            origin: DailyOsOnboardingOrigin.replay,
            targetDate: targetDate,
          );

      expect(session.origin, DailyOsOnboardingOrigin.replay);
      expect(session.targetDate, targetDate);
      expect(
        container.read(dailyOsOnboardingSessionControllerProvider),
        same(session),
      );
    });

    test('start honours an explicit session id', () {
      final container = makeContainer();
      final session = controllerOf(container).start(
        origin: DailyOsOnboardingOrigin.auto,
        targetDate: targetDate,
        sessionId: 'fixed-id',
      );

      expect(session.sessionId, 'fixed-id');
    });

    test('start generates a non-empty id when none is given', () {
      final container = makeContainer();
      final session =
          controllerOf(
            container,
          ).start(
            origin: DailyOsOnboardingOrigin.auto,
            targetDate: targetDate,
          );

      expect(session.sessionId, isNotEmpty);
    });

    test('end clears the active session and is idempotent', () {
      final container = makeContainer();
      final controller = controllerOf(container)
        ..start(
          origin: DailyOsOnboardingOrigin.auto,
          targetDate: targetDate,
        )
        ..end();

      expect(
        container.read(dailyOsOnboardingSessionControllerProvider),
        isNull,
      );

      // Ending again is a no-op, not an error.
      controller.end();
      expect(
        container.read(dailyOsOnboardingSessionControllerProvider),
        isNull,
      );
    });
  });

  group('metrics emission', () {
    late MockOnboardingMetricsRepository repo;

    setUp(() {
      repo = MockOnboardingMetricsRepository();
      when(
        () => repo.recordEvent(
          any(),
          provider: any(named: 'provider'),
          reason: any(named: 'reason'),
          valueBucket: any(named: 'valueBucket'),
        ),
      ).thenAnswer((_) async {});
      getIt.registerSingleton<OnboardingMetricsRepository>(repo);
    });

    test('records a stage event tagged with the session origin', () {
      final container = makeContainer();
      controllerOf(container)
          .start(
            origin: DailyOsOnboardingOrigin.auto,
            targetDate: targetDate,
          )
          .recordStageOnce(OnboardingEventName.dailyOsReconcileReached);

      verify(
        () => repo.recordEvent(
          OnboardingEventName.dailyOsReconcileReached,
          reason: 'auto',
          // ignore: avoid_redundant_argument_values
          valueBucket: null,
        ),
      ).called(1);
    });

    test('uses the replay origin as the reason for a replay session', () {
      final container = makeContainer();
      controllerOf(
            container,
          )
          .start(
            origin: DailyOsOnboardingOrigin.replay,
            targetDate: targetDate,
          )
          .recordSkippedOnce();

      verify(
        () => repo.recordEvent(
          OnboardingEventName.dailyOsWalkthroughSkipped,
          reason: 'replay',
          // ignore: avoid_redundant_argument_values
          valueBucket: null,
        ),
      ).called(1);
    });

    test('a per-event reason overrides the origin', () {
      final container = makeContainer();
      controllerOf(container)
          .start(
            origin: DailyOsOnboardingOrigin.auto,
            targetDate: targetDate,
          )
          .recordStageOnce(
            OnboardingEventName.dailyOsDraftingStarted,
            reason: 'custom',
          );

      verify(
        () => repo.recordEvent(
          OnboardingEventName.dailyOsDraftingStarted,
          reason: 'custom',
          // ignore: avoid_redundant_argument_values
          valueBucket: null,
        ),
      ).called(1);
    });

    test('forwards the value bucket (materialized-task count)', () {
      final container = makeContainer();
      controllerOf(container)
          .start(
            origin: DailyOsOnboardingOrigin.auto,
            targetDate: targetDate,
          )
          .recordStageOnce(
            OnboardingEventName.dailyOsTaskMaterialized,
            valueBucket: 3,
          );

      verify(
        () => repo.recordEvent(
          OnboardingEventName.dailyOsTaskMaterialized,
          reason: 'auto',
          valueBucket: 3,
        ),
      ).called(1);
    });

    test('the once-guard is honoured through the metrics hop', () {
      final container = makeContainer();
      final session =
          controllerOf(
              container,
            ).start(
              origin: DailyOsOnboardingOrigin.auto,
              targetDate: targetDate,
            )
            ..recordStageOnce(OnboardingEventName.dailyOsReconcileReached)
            ..recordStageOnce(OnboardingEventName.dailyOsReconcileReached);

      // Second call is a no-op — only one metrics write.
      expect(session.sessionId, isNotEmpty);
      verify(
        () => repo.recordEvent(
          OnboardingEventName.dailyOsReconcileReached,
          reason: any(named: 'reason'),
          valueBucket: any(named: 'valueBucket'),
        ),
      ).called(1);
    });

    test('asynchronous metrics failures are swallowed', () async {
      when(
        () => repo.recordEvent(
          any(),
          provider: any(named: 'provider'),
          reason: any(named: 'reason'),
          valueBucket: any(named: 'valueBucket'),
        ),
      ).thenAnswer(
        (_) => Future<void>.error(StateError('metrics unavailable')),
      );
      final errors = <Object>[];

      await runZonedGuarded(
        () async {
          final container = makeContainer();
          controllerOf(container)
              .start(
                origin: DailyOsOnboardingOrigin.auto,
                targetDate: targetDate,
              )
              .recordStageOnce(OnboardingEventName.dailyOsReconcileReached);
          await Future<void>.value();
          await Future<void>.value();
        },
        (error, _) => errors.add(error),
      );

      expect(errors, isEmpty);
    });
  });

  group('complete', () {
    late MockOnboardingMetricsRepository repo;
    late _CountingCadence cadence;

    setUp(() {
      repo = MockOnboardingMetricsRepository();
      when(
        () => repo.recordEvent(
          any(),
          provider: any(named: 'provider'),
          reason: any(named: 'reason'),
          valueBucket: any(named: 'valueBucket'),
        ),
      ).thenAnswer((_) async {});
      getIt.registerSingleton<OnboardingMetricsRepository>(repo);
      cadence = _CountingCadence();
    });

    ProviderContainer completingContainer() => makeContainer(
      overrides: [
        dailyOsOnboardingCadenceProvider.overrideWith(() => cadence),
      ],
    );

    test(
      'records materialized tasks + completion, retires cadence, ends session',
      () async {
        final container = completingContainer();
        final controller = controllerOf(container)
          ..start(
            origin: DailyOsOnboardingOrigin.auto,
            targetDate: targetDate,
          );

        await controller.complete(createdTaskIds: const ['t1', 't2']);

        verify(
          () => repo.recordEvent(
            OnboardingEventName.dailyOsTaskMaterialized,
            reason: 'auto',
            valueBucket: 2,
          ),
        ).called(1);
        verify(
          () => repo.recordEvent(
            OnboardingEventName.dailyOsWalkthroughCompleted,
            reason: 'auto',
            valueBucket: any(named: 'valueBucket'),
          ),
        ).called(1);
        expect(cadence.markCompletedCount, 1);
        expect(
          container.read(dailyOsOnboardingSessionControllerProvider),
          isNull,
        );
      },
    );

    test('clamps the materialized-task bucket to 5', () async {
      final container = completingContainer();
      await (controllerOf(container)..start(
            origin: DailyOsOnboardingOrigin.auto,
            targetDate: targetDate,
          ))
          .complete(createdTaskIds: List.generate(9, (i) => 't$i'));

      verify(
        () => repo.recordEvent(
          OnboardingEventName.dailyOsTaskMaterialized,
          reason: 'auto',
          valueBucket: 5,
        ),
      ).called(1);
    });

    test('records no materialized event when no tasks were created', () async {
      final container = completingContainer();
      await (controllerOf(
            container,
          )..start(
            origin: DailyOsOnboardingOrigin.auto,
            targetDate: targetDate,
          ))
          .complete();

      verifyNever(
        () => repo.recordEvent(
          OnboardingEventName.dailyOsTaskMaterialized,
          reason: any(named: 'reason'),
          valueBucket: any(named: 'valueBucket'),
        ),
      );
      verify(
        () => repo.recordEvent(
          OnboardingEventName.dailyOsWalkthroughCompleted,
          reason: 'auto',
          valueBucket: any(named: 'valueBucket'),
        ),
      ).called(1);
    });

    test('is a no-op when no session is active (ordinary create)', () async {
      final container = completingContainer();
      await controllerOf(container).complete(createdTaskIds: const ['t1']);

      expect(cadence.markCompletedCount, 0);
      verifyNever(
        () => repo.recordEvent(
          any(),
          reason: any(named: 'reason'),
          valueBucket: any(named: 'valueBucket'),
        ),
      );
    });

    test('dismiss records the skip and ends the session', () async {
      final container = completingContainer();
      controllerOf(container)
        ..start(
          origin: DailyOsOnboardingOrigin.auto,
          targetDate: targetDate,
        )
        ..dismiss();

      verify(
        () => repo.recordEvent(
          OnboardingEventName.dailyOsWalkthroughSkipped,
          reason: 'auto',
          valueBucket: any(named: 'valueBucket'),
        ),
      ).called(1);
      expect(
        container.read(dailyOsOnboardingSessionControllerProvider),
        isNull,
      );
    });

    test('dismiss is a no-op when no session is active', () {
      final container = completingContainer();
      controllerOf(container).dismiss();
      verifyNever(
        () => repo.recordEvent(
          any(),
          reason: any(named: 'reason'),
          valueBucket: any(named: 'valueBucket'),
        ),
      );
    });
  });

  test('recording is swallowed when no metrics repo is registered', () {
    final container = makeContainer();

    // Must not throw despite the repository being absent.
    expect(
      () => controllerOf(container)
          .start(
            origin: DailyOsOnboardingOrigin.auto,
            targetDate: targetDate,
          )
          .recordStageOnce(OnboardingEventName.dailyOsReconcileReached),
      returnsNormally,
    );
  });
}
