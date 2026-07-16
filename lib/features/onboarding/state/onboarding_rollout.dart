import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/journal_db/config_flags.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_planner_readiness.dart';
import 'package:lotti/features/onboarding/state/onboarding_trigger_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/utils/consts.dart';

/// Marker key: set once [applyOnboardingRolloutFlags] has force-enabled the two
/// onboarding master flags on this install.
///
/// The marker — not the flag value — is what makes the force-enable one-time.
/// Without it, a user who turns either flag back off in Settings > Advanced >
/// Flags would have their choice overridden on every subsequent launch. The
/// `_v1` suffix leaves room for a deliberate future re-rollout under a new key.
const onboardingRolloutFlagsAppliedKey = 'onboarding_rollout_v1_flags_applied';

/// Marker key: set once [applyOnboardingRolloutBackfill] has decided whether
/// this install was already set up before the rollout reached it.
///
/// Separate from [onboardingRolloutFlagsAppliedKey] because the two halves run
/// at different times with different prerequisites — see the library docs on
/// [applyOnboardingRolloutBackfill].
const onboardingRolloutBackfillAppliedKey =
    'onboarding_rollout_v1_backfill_applied';

/// The master flags the rollout force-enables. Both gate an interruptive
/// first-run surface, and both shipped defaulted-off while their flows were
/// built, so every install that ran one of those builds carries a `false` row.
const onboardingRolloutFlags = <String>[
  enableOnboardingFtueFlag,
  dailyOsOnboardingEnabledFlag,
];

/// Force-enables the onboarding master flags exactly once per install.
///
/// [initConfigFlags] seeds via `insertFlagIfNotExists`, which never touches an
/// existing row — so flipping the seed defaults to `true` reaches fresh
/// installs and upgraders who never ran a build carrying these flags, but
/// leaves the beta/dev cohort pinned at the `false` row their build wrote. This
/// closes that gap by overwriting the row via `upsertConfigFlag`.
///
/// Runs from `registerSingletons()` *after* [initConfigFlags] (the row must
/// exist) and *before* `runApp`, so no UI can read a stale `false`. In
/// particular `_showAiSetupPrompt` reads [enableOnboardingFtueFlag] directly to
/// decide between the FTUE welcome and the legacy provider-selection modal;
/// awaiting this first is what stops that check from racing the flip and
/// showing the legacy modal once on the upgrade launch.
///
/// A deliberate opt-out made *before* this migration is indistinguishable from
/// the beta/dev cohort's untouched `false` row, so it is overridden exactly
/// once. Any opt-out made *after* is permanent — the marker means we never
/// re-force.
///
/// Failures are logged and swallowed, and the marker is deliberately *not*
/// written on the failure path so the next launch retries: this runs on the
/// startup path, where throwing would take the app down over an optional
/// rollout.
///
/// **Why the flags are written before the marker, and why that is safe without
/// a transaction.** The flags live in [JournalDb] and the marker in
/// [SettingsDb] — separate Drift databases, so no transaction spans them and
/// the two writes cannot be made atomic. The ordering is chosen instead:
///
/// - *Process death between the two writes* is benign. The flag loop is
///   idempotent — a re-run sees `existing.status == true` and skips — so the
///   next launch merely writes the marker and converges on the same state. No
///   opt-out can interleave, because reaching the Flags page requires a running
///   app and the migration completes before any UI is reachable.
/// - *The marker write throwing while the app lives on* is the one residual: an
///   opt-out made later in that same degraded session is re-forced once on the
///   next launch. It needs a [SettingsDb] failure and a same-session opt-out,
///   and it self-heals — once the marker lands, the next opt-out is permanent.
///
/// Writing the marker first would trade that self-healing case for a worse one:
/// a crash before the flag loop would mark the install migrated without ever
/// forcing the flags, silently denying the rollout to the exact beta/dev cohort
/// it exists to reach — with no retry, since the marker is the guard.
Future<void> applyOnboardingRolloutFlags({
  required JournalDb journalDb,
  required SettingsDb settingsDb,
  required DomainLogger logger,
}) async {
  try {
    final alreadyApplied = await settingsDb.itemByKey(
      onboardingRolloutFlagsAppliedKey,
    );
    if (alreadyApplied == 'true') return;

    for (final name in onboardingRolloutFlags) {
      final existing = await journalDb.getConfigFlagByName(name);
      // Absent means [initConfigFlags] has not seeded it (nothing to correct);
      // already-`true` means the seed default covered this install.
      if (existing == null || existing.status) continue;
      // `copyWith` rather than a fresh `ConfigFlag`: `upsertConfigFlag`
      // overwrites the whole row, and `config_flags.description` carries a
      // UNIQUE constraint — reusing the seeded description keeps the rollout
      // from having to restate (and drift from) it.
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

/// Retires the FTUE welcome, once per install, for users who were already set
/// up before the rollout reached them.
///
/// The welcome is a *connect-your-brain* flow. Turning the flag on makes it
/// auto-show to every install that has no `welcome_completed` key — which
/// correctly includes pre-FTUE users who never went through onboarding, but
/// also includes long-time users who already have a working provider and would
/// be dropped into a redundant provider-setup flow. Marking those installs
/// completed hands them to the Daily OS walkthrough instead, which is the beat
/// that actually fits them: they have a provider, they just never planned a
/// day. They can still replay the welcome from Settings > Onboarding.
///
/// "Already set up" reuses [dailyOsOnboardingProviderReadyProvider] — the same
/// readiness the Daily OS gate computes. That is deliberately *stricter* than
/// "has any provider": it suppresses the welcome only when a full thinking
/// route resolves, so a half-configured install errs toward showing the welcome
/// rather than being left with no onboarding at all. The readiness provider
/// waits for agent initialization before resolving, so concurrent template
/// seeding cannot be mistaken for a permanently incomplete setup by this
/// one-shot migration.
///
/// Unlike the flag flip this cannot run in `get_it`: readiness resolves through
/// Riverpod providers (`agentRepositoryProvider`, `agentTemplateServiceProvider`,
/// `profileResolverProvider`), and no container exists before `runApp`. It is
/// instead awaited by [shouldAutoShowOnboarding] before it reads the cadence
/// keys, so the gate can never observe pre-migration state — running it from a
/// widget would race the gate and flash the welcome at a configured user.
///
/// Readiness is read once (`ref.read`), not watched: this is a point-in-time
/// migration answering "was this install already set up when the rollout
/// arrived?". Re-running it as AI config changes would retire the welcome for a
/// user who connects a provider midway through the flow itself.
///
/// Every failure path defaults to *not* retiring the welcome and leaves the
/// marker unwritten so the next launch retries — a readiness hiccup, or a
/// failed retire, must never silently suppress onboarding. The retire goes
/// through [writeOnboardingWelcomeCompleted] rather than the swallowing
/// `markOnboardingWelcomeCompleted` precisely so a failed write reaches the
/// catch below instead of being recorded as a completed migration.
Future<void> applyOnboardingRolloutBackfill({
  required Future<bool> Function() readProviderReady,
  required SettingsDb settingsDb,
  required DomainLogger logger,
}) async {
  try {
    final alreadyApplied = await settingsDb.itemByKey(
      onboardingRolloutBackfillAppliedKey,
    );
    if (alreadyApplied == 'true') return;

    if (await readProviderReady()) {
      await writeOnboardingWelcomeCompleted(settingsDb: settingsDb);
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

/// Riverpod entry point for [applyOnboardingRolloutBackfill] — the composition
/// root that resolves its collaborators, mirroring how `registerSingletons()`
/// supplies [applyOnboardingRolloutFlags]'.
///
/// Not `autoDispose`: the migration is a one-shot, and keeping the completed
/// future cached for the container's lifetime is what bounds it to a single run
/// per app session no matter how often the autoDispose gate above it rebuilds.
final FutureProvider<void> onboardingRolloutBackfillProvider =
    FutureProvider<void>(
      (ref) => applyOnboardingRolloutBackfill(
        readProviderReady: () =>
            ref.read(dailyOsOnboardingProviderReadyProvider.future),
        settingsDb: getIt<SettingsDb>(),
        logger: getIt<DomainLogger>(),
      ),
      name: 'onboardingRolloutBackfillProvider',
    );
