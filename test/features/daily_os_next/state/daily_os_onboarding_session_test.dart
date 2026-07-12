import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_onboarding_session.dart';
import 'package:lotti/features/onboarding/model/onboarding_event.dart';

void main() {
  group('DailyOsOnboardingSession', () {
    test('exposes its id and origin', () {
      final session = DailyOsOnboardingSession(
        sessionId: 's-1',
        origin: DailyOsOnboardingOrigin.replay,
      );

      expect(session.sessionId, 's-1');
      expect(session.origin, DailyOsOnboardingOrigin.replay);
    });

    test('defaults to visible tips and no recorded skip', () {
      final session = DailyOsOnboardingSession(
        sessionId: 's-1',
        origin: DailyOsOnboardingOrigin.auto,
      );

      expect(session.tipsVisible, isTrue);
      expect(session.skipRecorded, isFalse);
    });

    test('records each stage event at most once', () {
      final emitted = <OnboardingEventName>[];
      DailyOsOnboardingSession(
          sessionId: 's-1',
          origin: DailyOsOnboardingOrigin.auto,
          onEvent: emitted.add,
        )
        ..recordStageOnce(OnboardingEventName.dailyOsReconcileReached)
        ..recordStageOnce(OnboardingEventName.dailyOsReconcileReached)
        ..recordStageOnce(OnboardingEventName.dailyOsDraftingStarted);

      expect(emitted, [
        OnboardingEventName.dailyOsReconcileReached,
        OnboardingEventName.dailyOsDraftingStarted,
      ]);
    });

    test('records the skip event at most once', () {
      final emitted = <OnboardingEventName>[];
      final session =
          DailyOsOnboardingSession(
              sessionId: 's-1',
              origin: DailyOsOnboardingOrigin.auto,
              onEvent: emitted.add,
            )
            ..recordSkippedOnce()
            ..recordSkippedOnce();

      expect(emitted, [OnboardingEventName.dailyOsWalkthroughSkipped]);
      expect(session.skipRecorded, isTrue);
    });

    test('hideTips hides tips and records the skip once', () {
      final emitted = <OnboardingEventName>[];
      final session = DailyOsOnboardingSession(
        sessionId: 's-1',
        origin: DailyOsOnboardingOrigin.auto,
        onEvent: emitted.add,
      )..hideTips();

      expect(session.tipsVisible, isFalse);
      expect(emitted, [OnboardingEventName.dailyOsWalkthroughSkipped]);

      // A subsequent explicit skip does not double-count.
      session.recordSkippedOnce();
      expect(emitted, [OnboardingEventName.dailyOsWalkthroughSkipped]);
    });

    test('skip and stage events are independent once-flags', () {
      final emitted = <OnboardingEventName>[];
      DailyOsOnboardingSession(
          sessionId: 's-1',
          origin: DailyOsOnboardingOrigin.auto,
          onEvent: emitted.add,
        )
        ..recordSkippedOnce()
        ..recordStageOnce(OnboardingEventName.dailyOsDraftingStarted);

      expect(emitted, [
        OnboardingEventName.dailyOsWalkthroughSkipped,
        OnboardingEventName.dailyOsDraftingStarted,
      ]);
    });

    test('tolerates a null onEvent sink', () {
      final session =
          DailyOsOnboardingSession(
              sessionId: 's-1',
              origin: DailyOsOnboardingOrigin.auto,
            )
            ..recordStageOnce(OnboardingEventName.dailyOsReconcileReached)
            ..recordSkippedOnce();

      expect(session.skipRecorded, isTrue);
    });

    test('honours an initial tipsVisible of false', () {
      final session = DailyOsOnboardingSession(
        sessionId: 's-1',
        origin: DailyOsOnboardingOrigin.auto,
        tipsVisible: false,
      );

      expect(session.tipsVisible, isFalse);
    });
  });
}
