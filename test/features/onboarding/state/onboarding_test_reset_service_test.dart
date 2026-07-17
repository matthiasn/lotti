import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/onboarding_metrics_db.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/onboarding/model/onboarding_event.dart';
import 'package:lotti/features/onboarding/state/onboarding_rollout.dart';
import 'package:lotti/features/onboarding/state/onboarding_test_reset_service.dart';

void main() {
  late SettingsDb settingsDb;
  late OnboardingMetricsDb metricsDb;

  setUp(() {
    settingsDb = SettingsDb(inMemoryDatabase: true);
    metricsDb = OnboardingMetricsDb(
      inMemoryDatabase: true,
      background: false,
    );
  });

  tearDown(() async {
    await settingsDb.close();
    await metricsDb.close();
  });

  test(
    'clears cadences and metrics without touching the backfill marker',
    () async {
      for (final key in onboardingTestCadenceKeys) {
        await settingsDb.saveSettingsItem(key, 'seeded');
      }
      await settingsDb.saveSettingsItem(
        onboardingRolloutBackfillAppliedKey,
        'true',
      );
      await settingsDb.saveSettingsItem('unrelated_setting', 'keep');
      await metricsDb.insertOnboardingEvent(
        id: 'event-1',
        eventName: OnboardingEventName.welcomeSkipped.wireName,
        createdAt: DateTime.utc(2026, 7, 17, 9),
        dayBucket: 0,
      );

      await resetOnboardingTestState(
        settingsDb: settingsDb,
        metricsDb: metricsDb,
      );

      expect(
        await settingsDb.itemsByKeys(onboardingTestCadenceKeys),
        {for (final key in onboardingTestCadenceKeys) key: null},
      );
      expect(await metricsDb.getAllEvents(), isEmpty);
      expect(
        await settingsDb.itemByKey(onboardingRolloutBackfillAppliedKey),
        'true',
      );
      expect(await settingsDb.itemByKey('unrelated_setting'), 'keep');
    },
  );

  test('is idempotent when no onboarding state exists', () async {
    await resetOnboardingTestState(
      settingsDb: settingsDb,
      metricsDb: metricsDb,
    );

    await expectLater(
      resetOnboardingTestState(
        settingsDb: settingsDb,
        metricsDb: metricsDb,
      ),
      completes,
    );
  });
}
