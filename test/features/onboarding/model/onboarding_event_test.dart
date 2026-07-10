import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/onboarding/model/onboarding_event.dart';

void main() {
  group('OnboardingEventName.isDailyOsOnboarding', () {
    const dailyOsEvents = {
      OnboardingEventName.dailyOsWalkthroughShown,
      OnboardingEventName.dailyOsWalkthroughSkipped,
      OnboardingEventName.dailyOsReconcileReached,
      OnboardingEventName.dailyOsDraftingStarted,
      OnboardingEventName.dailyOsTaskMaterialized,
      OnboardingEventName.dailyOsWalkthroughCompleted,
    };

    test('is true for exactly the Daily OS vocabulary', () {
      for (final name in OnboardingEventName.values) {
        expect(
          name.isDailyOsOnboarding,
          dailyOsEvents.contains(name),
          reason: '${name.name} classification mismatch',
        );
      }
    });

    test('general FTUE events are not classified as Daily OS', () {
      expect(OnboardingEventName.realAha.isDailyOsOnboarding, isFalse);
      expect(OnboardingEventName.appFirstSeen.isDailyOsOnboarding, isFalse);
      expect(OnboardingEventName.welcomeShown.isDailyOsOnboarding, isFalse);
    });
  });

  group('OnboardingEventName.fromWireName', () {
    test('round-trips every event name', () {
      for (final name in OnboardingEventName.values) {
        expect(OnboardingEventName.fromWireName(name.wireName), name);
      }
    });

    test('returns null for an unknown/future wire name', () {
      expect(OnboardingEventName.fromWireName('someFutureEvent'), isNull);
    });
  });

  group('DailyOsOnboardingFunnelState', () {
    test('empty state has no activity', () {
      const state = DailyOsOnboardingFunnelState.empty();
      expect(state.activeDaysCount, 0);
      expect(state.shownCount, 0);
      expect(state.skippedCount, 0);
      expect(state.reconcileReachedCount, 0);
      expect(state.draftingStartedCount, 0);
      expect(state.taskMaterializedCount, 0);
      expect(state.completedCount, 0);
      expect(state.completed, isFalse);
      expect(
        state.reached(OnboardingEventName.dailyOsWalkthroughShown),
        isFalse,
      );
    });

    test('exposes each stage count from the event map', () {
      final state = DailyOsOnboardingFunnelState(
        activeDayBuckets: const [10, 11],
        eventCounts: {
          OnboardingEventName.dailyOsWalkthroughShown.wireName: 3,
          OnboardingEventName.dailyOsWalkthroughSkipped.wireName: 1,
          OnboardingEventName.dailyOsReconcileReached.wireName: 2,
          OnboardingEventName.dailyOsDraftingStarted.wireName: 2,
          OnboardingEventName.dailyOsTaskMaterialized.wireName: 1,
          OnboardingEventName.dailyOsWalkthroughCompleted.wireName: 1,
        },
      );

      expect(state.activeDaysCount, 2);
      expect(state.shownCount, 3);
      expect(state.skippedCount, 1);
      expect(state.reconcileReachedCount, 2);
      expect(state.draftingStartedCount, 2);
      expect(state.taskMaterializedCount, 1);
      expect(state.completedCount, 1);
      expect(state.completed, isTrue);
      expect(
        state.reached(OnboardingEventName.dailyOsWalkthroughShown),
        isTrue,
      );
      expect(
        state.countOf(OnboardingEventName.dailyOsWalkthroughShown),
        3,
      );
    });

    test('completed is false until the completion event is present', () {
      final state = DailyOsOnboardingFunnelState(
        activeDayBuckets: const [10],
        eventCounts: {
          OnboardingEventName.dailyOsWalkthroughShown.wireName: 1,
          OnboardingEventName.dailyOsDraftingStarted.wireName: 1,
        },
      );

      expect(state.completed, isFalse);
      expect(state.completedCount, 0);
    });
  });
}
