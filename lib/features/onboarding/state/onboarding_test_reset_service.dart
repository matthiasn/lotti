import 'package:lotti/database/onboarding_metrics_db.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_onboarding_trigger_service.dart';
import 'package:lotti/features/onboarding/state/onboarding_trigger_service.dart';

/// Every private cadence key that can suppress an onboarding auto-show.
///
/// This deliberately excludes config flags and real Daily OS plan history:
/// testers choose when to enable the dark-launched flows, and deleting user
/// plans would be an unsafe way to recreate first-run eligibility.
const onboardingTestCadenceKeys = <String>[
  onboardingWelcomeCompletedKey,
  onboardingWelcomeShownCountKey,
  onboardingWelcomeFirstShownAtKey,
  dailyOsOnboardingCompletedKey,
  dailyOsOnboardingShownCountKey,
  dailyOsOnboardingFirstShownAtKey,
];

/// Clears onboarding prompt cadence and content-free funnel metrics for QA.
///
/// The operation is intentionally narrower than a profile reset. In
/// particular, the Daily OS `hasEverHadPlan` eligibility signal remains true
/// after any real or soft-deleted plan, so a clean profile is still required
/// to exercise that exact first-run path after planning a day.
Future<void> resetOnboardingTestState({
  required SettingsDb settingsDb,
  required OnboardingMetricsDb metricsDb,
}) async {
  for (final key in onboardingTestCadenceKeys) {
    await settingsDb.removeSettingsItem(key);
  }
  await metricsDb.clearAll();
}
