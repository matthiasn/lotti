import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_onboarding_session.dart';
import 'package:lotti/features/onboarding/model/onboarding_event.dart';

/// One captured emission from a [DailyOsOnboardingSession] sink.
typedef _Emission = ({
  OnboardingEventName event,
  String? reason,
  int? valueBucket,
});

/// Collects sink emissions so tests can assert both the event names and the
/// forwarded `reason` / `valueBucket` attributes.
class _EventSink {
  final emissions = <_Emission>[];

  DailyOsOnboardingEventSink get add =>
      (event, {reason, valueBucket}) => emissions.add((
        event: event,
        reason: reason,
        valueBucket: valueBucket,
      ));

  List<OnboardingEventName> get events =>
      emissions.map((e) => e.event).toList();
}

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

    test('defaults to no recorded skip', () {
      final session = DailyOsOnboardingSession(
        sessionId: 's-1',
        origin: DailyOsOnboardingOrigin.auto,
      );

      expect(session.skipRecorded, isFalse);
    });

    test('records each stage event at most once', () {
      final sink = _EventSink();
      DailyOsOnboardingSession(
          sessionId: 's-1',
          origin: DailyOsOnboardingOrigin.auto,
          onEvent: sink.add,
        )
        ..recordStageOnce(OnboardingEventName.dailyOsReconcileReached)
        ..recordStageOnce(OnboardingEventName.dailyOsReconcileReached)
        ..recordStageOnce(OnboardingEventName.dailyOsDraftingStarted);

      expect(sink.events, [
        OnboardingEventName.dailyOsReconcileReached,
        OnboardingEventName.dailyOsDraftingStarted,
      ]);
    });

    test('forwards reason and valueBucket to the sink', () {
      final sink = _EventSink();
      DailyOsOnboardingSession(
        sessionId: 's-1',
        origin: DailyOsOnboardingOrigin.auto,
        onEvent: sink.add,
      ).recordStageOnce(
        OnboardingEventName.dailyOsTaskMaterialized,
        reason: 'auto',
        valueBucket: 3,
      );

      expect(sink.emissions, [
        (
          event: OnboardingEventName.dailyOsTaskMaterialized,
          reason: 'auto',
          valueBucket: 3,
        ),
      ]);
    });

    test('keeps the first recorded attributes when a stage repeats', () {
      final sink = _EventSink();
      DailyOsOnboardingSession(
          sessionId: 's-1',
          origin: DailyOsOnboardingOrigin.auto,
          onEvent: sink.add,
        )
        ..recordStageOnce(
          OnboardingEventName.dailyOsTaskMaterialized,
          valueBucket: 2,
        )
        ..recordStageOnce(
          OnboardingEventName.dailyOsTaskMaterialized,
          valueBucket: 5,
        );

      expect(sink.emissions, [
        (
          event: OnboardingEventName.dailyOsTaskMaterialized,
          reason: null,
          valueBucket: 2,
        ),
      ]);
    });

    test('records the skip event at most once', () {
      final sink = _EventSink();
      final session =
          DailyOsOnboardingSession(
              sessionId: 's-1',
              origin: DailyOsOnboardingOrigin.auto,
              onEvent: sink.add,
            )
            ..recordSkippedOnce()
            ..recordSkippedOnce();

      expect(sink.events, [OnboardingEventName.dailyOsWalkthroughSkipped]);
      expect(session.skipRecorded, isTrue);
    });

    test('skip and stage events are independent once-flags', () {
      final sink = _EventSink();
      DailyOsOnboardingSession(
          sessionId: 's-1',
          origin: DailyOsOnboardingOrigin.auto,
          onEvent: sink.add,
        )
        ..recordSkippedOnce()
        ..recordStageOnce(OnboardingEventName.dailyOsDraftingStarted);

      expect(sink.events, [
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
  });
}
