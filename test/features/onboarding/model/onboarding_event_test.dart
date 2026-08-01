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
}
