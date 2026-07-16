import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_planner_readiness.dart';
import 'package:lotti/features/onboarding/model/onboarding_event.dart';
import 'package:lotti/features/onboarding/repository/onboarding_metrics_repository.dart';
import 'package:lotti/features/onboarding/state/onboarding_rollout.dart';
import 'package:lotti/features/whats_new/state/whats_new_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/utils/consts.dart';

/// Prefix for every private [SettingsDb] key backing the onboarding welcome's
/// auto-show cadence. Deliberately *not* a `ConfigFlags` row -- `ConfigFlags`
/// is for public, user-toggleable flags (Settings > Advanced > Flags); this
/// is per-install bookkeeping the user never edits directly.
const _welcomeKeyPrefix = 'welcome_';

/// Set once the user completes the essential setup (a provider is connected)
/// via [OnboardingWelcomeCadence.markCompleted] -- permanently retires the
/// auto-show gate regardless of the shown-count/window budget below. This is
/// what stops the welcome from re-appearing after a user finishes the flow
/// but before any structured task has landed (so `reachedRealAha` is still
/// false); without it such a user would keep seeing the welcome until the
/// shown-count/window cap ran out.
const onboardingWelcomeCompletedKey = '${_welcomeKeyPrefix}completed';

/// How many times the welcome has auto-shown so far.
const onboardingWelcomeShownCountKey = '${_welcomeKeyPrefix}shown_count';

/// ISO-8601 UTC timestamp of the first time the welcome auto-showed --
/// the anchor [isOnboardingWelcomeEligible] measures [onboardingWelcomeWindow]
/// from.
const onboardingWelcomeFirstShownAtKey = '${_welcomeKeyPrefix}first_shown_at';

/// Maximum number of times the welcome auto-shows before it retires. Beyond
/// this the user has had ample opportunity to notice it without the app
/// nagging indefinitely.
const onboardingWelcomeMaxShows = 4;

/// The grace window, measured from the first auto-show, during which the
/// welcome may keep re-appearing on cold start while the user has not yet
/// reached the real "aha" (a structured task actually landing). Gives a slow
/// starter multiple sessions without pestering them forever.
const onboardingWelcomeWindow = Duration(days: 14);

/// Pure re-show predicate. Every input is already resolved by the caller, so
/// this is synchronous and independently unit-testable across every branch
/// without any async/DB/Riverpod plumbing.
///
/// Eligible while:
/// - no unseen What's New content is blocking it (so the welcome never races
///   the What's New modal for the screen),
/// - the flow has not been marked complete,
/// - the user has not yet reached the real "aha" -- a structured task
///   actually landing ([OnboardingFunnelState.reachedRealAha]). Per the
///   approved plan this replaces a raw created-task counter: graduating on
///   real activation rather than a vanity count that a floor/failure path
///   could inflate,
/// - the welcome has auto-shown fewer than [onboardingWelcomeMaxShows]
///   times, and
/// - once it has shown at least once, [now] is still within
///   [onboardingWelcomeWindow] of the first auto-show.
bool isOnboardingWelcomeEligible({
  required bool hasUnseenWhatsNew,
  required bool completed,
  required bool reachedRealAha,
  required int shownCount,
  required DateTime? firstShownAt,
  required DateTime now,
}) {
  if (hasUnseenWhatsNew) return false;
  if (completed) return false;
  if (reachedRealAha) return false;
  if (shownCount >= onboardingWelcomeMaxShows) return false;
  if (firstShownAt != null &&
      now.difference(firstShownAt) >= onboardingWelcomeWindow) {
    return false;
  }
  return true;
}

/// Provider that checks whether the onboarding (FTUE) welcome should
/// auto-show.
///
/// Mirrors [shouldAutoShowWhatsNewProvider]'s shape exactly: a plain
/// top-level async function wrapped in an `autoDispose` [FutureProvider],
/// read once per evaluation window by `BeamerApp`'s `ref.listen` chain --
/// sequenced to run only once What's New has nothing left to show.
final FutureProvider<bool> shouldAutoShowOnboardingProvider =
    FutureProvider.autoDispose<bool>(
      shouldAutoShowOnboarding,
      name: 'shouldAutoShowOnboardingProvider',
    );

/// Readiness-dependent second half of the prepared rollout migration.
///
/// Cached for the container lifetime. With [onboardingRolloutEnabled] false,
/// [applyOnboardingRolloutBackfill] returns before reading readiness, cadence,
/// or its marker, which keeps manual production testing isolated.
final FutureProviderFamily<void, bool> onboardingRolloutBackfillProvider =
    FutureProvider.family<void, bool>(
      (ref, rolloutEnabled) {
        final settingsDb = getIt<SettingsDb>();
        return applyOnboardingRolloutBackfill(
          readProviderReady: () =>
              ref.read(dailyOsOnboardingProviderReadyProvider.future),
          retireWelcome: () => settingsDb.saveSettingsItem(
            onboardingWelcomeCompletedKey,
            'true',
          ),
          settingsDb: settingsDb,
          logger: getIt<DomainLogger>(),
          rolloutEnabled: rolloutEnabled,
        );
      },
      name: 'onboardingRolloutBackfillProvider',
    );

Future<bool> shouldAutoShowOnboarding(Ref ref) async {
  final db = ref.watch(journalDbProvider);
  // Establish dependencies synchronously, before the first await, so the
  // provider stays reactive to What's New changes (watching after an async gap
  // would not register the dependency). The rollout provider is a read/write-
  // free no-op while its release lever is off.
  final whatsNewFuture = ref.watch(whatsNewControllerProvider.future);
  final rolloutBackfillFuture = ref.watch(
    onboardingRolloutBackfillProvider(onboardingRolloutEnabled).future,
  );

  // Sequenced after What's New -- an unseen release still owns the first
  // overlay slot, so the two auto-shown surfaces never race each other for the
  // screen. Gated on
  // `enableWhatsNewFlag` too: `whatsNewControllerProvider` reports unseen
  // remote content regardless of whether the What's New *feature* is turned
  // on, so without this check a disabled What's New (its default) would
  // report unseen content forever with no modal ever able to dismiss it,
  // permanently blocking the welcome.
  final whatsNewEnabled = await db.getConfigFlag(enableWhatsNewFlag);
  final whatsNewState = await whatsNewFuture;
  final hasUnseenWhatsNew = whatsNewEnabled && whatsNewState.hasUnseenRelease;

  await rolloutBackfillFuture;

  final settingsDb = getIt<SettingsDb>();
  final stored = await settingsDb.itemsByKeys(const [
    onboardingWelcomeCompletedKey,
    onboardingWelcomeShownCountKey,
    onboardingWelcomeFirstShownAtKey,
  ]);

  final firstShownAtRaw = stored[onboardingWelcomeFirstShownAtKey];

  return isOnboardingWelcomeEligible(
    hasUnseenWhatsNew: hasUnseenWhatsNew,
    completed: stored[onboardingWelcomeCompletedKey] == 'true',
    reachedRealAha: await _reachedRealAha(),
    shownCount: int.tryParse(stored[onboardingWelcomeShownCountKey] ?? '') ?? 0,
    firstShownAt: firstShownAtRaw == null
        ? null
        : DateTime.tryParse(firstShownAtRaw),
    now: DateTime.now(),
  );
}

/// Reads [OnboardingFunnelState.reachedRealAha] from the metrics repository.
/// Defaults to `false` (does not block the gate) when the repository is not
/// registered (most unit tests) or a read fails -- a metrics-store hiccup
/// must not crash or silently suppress the welcome forever.
Future<bool> _reachedRealAha() async {
  if (!getIt.isRegistered<OnboardingMetricsRepository>()) return false;
  try {
    final state = await getIt<OnboardingMetricsRepository>().funnelState();
    return state.reachedRealAha;
  } catch (_) {
    return false;
  }
}

/// Provider for the onboarding welcome's cadence bookkeeping -- the mutation
/// side of [shouldAutoShowOnboardingProvider]'s read-only eligibility check.
final AsyncNotifierProvider<OnboardingWelcomeCadence, void>
onboardingWelcomeCadenceProvider =
    AsyncNotifierProvider.autoDispose<OnboardingWelcomeCadence, void>(
      OnboardingWelcomeCadence.new,
      name: 'onboardingWelcomeCadenceProvider',
    );

/// Persists the onboarding welcome's auto-show bookkeeping in [SettingsDb].
/// Holds no meaningful state of its own ([build] is a no-op) -- the read
/// side lives entirely in [shouldAutoShowOnboarding].
class OnboardingWelcomeCadence extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  /// Records that the welcome auto-showed once more: bumps
  /// [onboardingWelcomeShownCountKey] and, only on the very first show,
  /// stamps [onboardingWelcomeFirstShownAtKey] so the grace window in
  /// [isOnboardingWelcomeEligible] has a fixed start point. Called by
  /// `BeamerApp` right when it decides to display the welcome -- not from
  /// `onDismiss` -- so the count reflects how many times it was actually
  /// shown, independent of how the user then interacts with it.
  ///
  /// A `SettingsDb` failure is logged and swallowed rather than thrown: the
  /// caller shows the welcome via `unawaited(...)`, so a thrown error would
  /// both surface as an uncaught async error and abort before the modal shows.
  /// Failing to persist the count only degrades the cadence (the welcome may
  /// show once more than budgeted) -- never worth blocking the welcome for.
  Future<void> recordShown() async {
    try {
      final settingsDb = getIt<SettingsDb>();
      final stored = await settingsDb.itemsByKeys(const [
        onboardingWelcomeShownCountKey,
        onboardingWelcomeFirstShownAtKey,
      ]);
      final shownCount =
          int.tryParse(stored[onboardingWelcomeShownCountKey] ?? '') ?? 0;
      await settingsDb.saveSettingsItem(
        onboardingWelcomeShownCountKey,
        '${shownCount + 1}',
      );
      if (stored[onboardingWelcomeFirstShownAtKey] == null) {
        await settingsDb.saveSettingsItem(
          onboardingWelcomeFirstShownAtKey,
          DateTime.now().toUtc().toIso8601String(),
        );
      }
    } catch (error, stackTrace) {
      getIt<DomainLogger>().error(
        LogDomain.onboarding,
        error,
        stackTrace: stackTrace,
        subDomain: 'onboardingWelcomeRecordShown',
      );
    }
  }

  /// Marks the welcome flow as completed once the user has connected a
  /// provider, permanently retiring the auto-show gate (see
  /// [onboardingWelcomeCompletedKey]). Called from the welcome modal's
  /// completion callback, not from its skip/dismiss path -- a plain skip
  /// leaves the shown-count/window grace period intact.
  ///
  /// Refreshes the read-side provider after persistence so gates sequenced
  /// behind the welcome (including Daily OS onboarding) can proceed in the
  /// same app session instead of observing the cached pre-completion value.
  Future<void> markCompleted() async {
    final keepAlive = ref.keepAlive();
    try {
      await markOnboardingWelcomeCompleted();
      ref.invalidate(shouldAutoShowOnboardingProvider);
    } finally {
      keepAlive.close();
    }
  }
}

/// Persists the onboarding welcome's "completed" flag, permanently retiring
/// the auto-show gate. Shared by [OnboardingWelcomeCadence.markCompleted]
/// (the auto-show path, via `BeamerApp`) and the Settings replay entry
/// (`OnboardingSettingsBody`), so both retire the gate the same way when the
/// user connects a provider -- without either call site reaching into the
/// storage key directly.
///
/// Like [OnboardingWelcomeCadence.recordShown], a `SettingsDb` failure is
/// logged and swallowed: both call sites invoke this fire-and-forget from a
/// modal completion callback, where a thrown error would be unhandled.
Future<void> markOnboardingWelcomeCompleted() async {
  try {
    await getIt<SettingsDb>().saveSettingsItem(
      onboardingWelcomeCompletedKey,
      'true',
    );
  } catch (error, stackTrace) {
    getIt<DomainLogger>().error(
      LogDomain.onboarding,
      error,
      stackTrace: stackTrace,
      subDomain: 'onboardingWelcomeMarkCompleted',
    );
  }
}
