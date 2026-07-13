import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_onboarding_session.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_onboarding_session_controller.dart';
import 'package:lotti/features/onboarding/model/onboarding_event.dart';
import 'package:lotti/features/onboarding/repository/onboarding_metrics_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(OnboardingEventName.dailyOsWalkthroughShown);
  });

  ProviderContainer makeContainer() {
    final container = ProviderContainer();
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
      final session = controllerOf(
        container,
      ).start(origin: DailyOsOnboardingOrigin.replay);

      expect(session.origin, DailyOsOnboardingOrigin.replay);
      expect(
        container.read(dailyOsOnboardingSessionControllerProvider),
        same(session),
      );
    });

    test('start honours an explicit session id', () {
      final container = makeContainer();
      final session = controllerOf(container).start(
        origin: DailyOsOnboardingOrigin.auto,
        sessionId: 'fixed-id',
      );

      expect(session.sessionId, 'fixed-id');
    });

    test('start generates a non-empty id when none is given', () {
      final container = makeContainer();
      final session = controllerOf(
        container,
      ).start(origin: DailyOsOnboardingOrigin.auto);

      expect(session.sessionId, isNotEmpty);
    });

    test('end clears the active session and is idempotent', () {
      final container = makeContainer();
      final controller = controllerOf(container)
        ..start(origin: DailyOsOnboardingOrigin.auto)
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
      if (getIt.isRegistered<OnboardingMetricsRepository>()) {
        getIt.unregister<OnboardingMetricsRepository>();
      }
      getIt.registerSingleton<OnboardingMetricsRepository>(repo);
    });

    tearDown(() {
      if (getIt.isRegistered<OnboardingMetricsRepository>()) {
        getIt.unregister<OnboardingMetricsRepository>();
      }
    });

    test('records a stage event tagged with the session origin', () {
      final container = makeContainer();
      controllerOf(container)
          .start(origin: DailyOsOnboardingOrigin.auto)
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
      ).start(origin: DailyOsOnboardingOrigin.replay).recordSkippedOnce();

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
          .start(origin: DailyOsOnboardingOrigin.auto)
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
          .start(origin: DailyOsOnboardingOrigin.auto)
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
            ).start(origin: DailyOsOnboardingOrigin.auto)
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
  });

  test('recording is swallowed when no metrics repo is registered', () {
    if (getIt.isRegistered<OnboardingMetricsRepository>()) {
      getIt.unregister<OnboardingMetricsRepository>();
    }
    final container = makeContainer();

    // Must not throw despite the repository being absent.
    expect(
      () => controllerOf(container)
          .start(origin: DailyOsOnboardingOrigin.auto)
          .recordStageOnce(OnboardingEventName.dailyOsReconcileReached),
      returnsNormally,
    );
  });
}
