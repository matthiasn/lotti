import 'package:lotti/database/database.dart';
import 'package:lotti/database/journal_db/config_flags.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/utils/consts.dart';

/// The single release lever for the onboarding rollout.
///
/// Keep this `false` throughout production testing. Testers opt in to the Daily
/// OS walkthrough with its public config flag instead. Flipping this to `true`
/// activates both one-shot migrations below: startup force-enables that flag
/// for every install, then the welcome gate retires FTUE for installs that
/// already have a working planner route.
const onboardingRolloutEnabled = false;

/// Marker written after the rollout force-enables its remaining master flag.
const onboardingRolloutFlagsAppliedKey = 'onboarding_rollout_v1_flags_applied';

/// Marker written after rollout backfill classifies an existing install.
const onboardingRolloutBackfillAppliedKey =
    'onboarding_rollout_v1_backfill_applied';

/// The remaining interruptive flow activated when the lever is pulled.
///
/// The welcome no longer has a config flag; its cadence and completion state
/// are the only gates. Daily OS remains separately switchable while its
/// walkthrough completes production testing.
const onboardingRolloutFlags = <String>[dailyOsOnboardingEnabledFlag];

/// Force-enables the remaining onboarding master flag exactly once per install.
///
/// [initConfigFlags] is insert-only, so merely changing a seed default cannot
/// reach installs that already carry a `false` row. This overwrite migration
/// runs after seeding and before `runApp`, avoiding a race with the Daily OS
/// gate. The marker makes later user opt-outs permanent.
///
/// When [rolloutEnabled] is false the method performs no reads or writes. The
/// optional parameter keeps the production lever compile-time explicit while
/// allowing the armed migration to be tested before release.
Future<void> applyOnboardingRolloutFlags({
  required JournalDb journalDb,
  required SettingsDb settingsDb,
  required DomainLogger logger,
  bool rolloutEnabled = onboardingRolloutEnabled,
}) async {
  if (!rolloutEnabled) return;

  try {
    final alreadyApplied = await settingsDb.itemByKey(
      onboardingRolloutFlagsAppliedKey,
    );
    if (alreadyApplied == 'true') return;

    for (final name in onboardingRolloutFlags) {
      final existing = await journalDb.getConfigFlagByName(name);
      if (existing == null || existing.status) continue;
      await journalDb.upsertConfigFlag(existing.copyWith(status: true));
    }

    await settingsDb.saveSettingsItem(onboardingRolloutFlagsAppliedKey, 'true');
  } catch (error, stackTrace) {
    logger.error(
      LogDomain.onboarding,
      error,
      stackTrace: stackTrace,
      subDomain: 'onboardingRolloutFlags',
    );
  }
}

/// Retires FTUE once for installs that were configured before rollout.
///
/// A resolvable Daily OS planner thinking route is deliberately stricter than
/// merely having an AI provider row. The readiness provider waits for agent
/// initialization, so its one-shot answer cannot race template/version seeding.
/// Failures leave the marker absent for a later retry.
///
/// When [rolloutEnabled] is false this returns before reading the marker or
/// invoking [readProviderReady], so manual production testing cannot silently
/// retire the welcome.
Future<void> applyOnboardingRolloutBackfill({
  required Future<bool> Function() readProviderReady,
  required Future<void> Function() retireWelcome,
  required SettingsDb settingsDb,
  required DomainLogger logger,
  bool rolloutEnabled = onboardingRolloutEnabled,
}) async {
  if (!rolloutEnabled) return;

  try {
    final alreadyApplied = await settingsDb.itemByKey(
      onboardingRolloutBackfillAppliedKey,
    );
    if (alreadyApplied == 'true') return;

    if (await readProviderReady()) {
      await retireWelcome();
    }

    await settingsDb.saveSettingsItem(
      onboardingRolloutBackfillAppliedKey,
      'true',
    );
  } catch (error, stackTrace) {
    logger.error(
      LogDomain.onboarding,
      error,
      stackTrace: stackTrace,
      subDomain: 'onboardingRolloutBackfill',
    );
  }
}
