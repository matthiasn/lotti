import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/ai/constants/provider_config.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/settings/ai_config_by_type_controller.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_service.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/features/daily_os_next/state/selected_date_provider.dart';
import 'package:lotti/features/onboarding/state/onboarding_trigger_service.dart';
import 'package:lotti/features/whats_new/state/whats_new_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/utils/consts.dart';

/// Prefix for every private [SettingsDb] key backing the Daily OS onboarding
/// walkthrough's auto-show cadence. Deliberately *not* a `ConfigFlags` row --
/// that registry is for public, user-toggleable flags; this is per-install
/// bookkeeping the user never edits directly, mirroring the general FTUE's
/// `welcome_*` keys.
const _dailyOsOnboardingKeyPrefix = 'daily_os_onboarding_';

/// Set once the walkthrough completes (a persisted day plan lands) via
/// [DailyOsOnboardingCadence.markCompleted] -- permanently retires the
/// auto-show gate regardless of the shown-count/window budget below.
const dailyOsOnboardingCompletedKey = '${_dailyOsOnboardingKeyPrefix}completed';

/// How many times the walkthrough has auto-shown so far.
const dailyOsOnboardingShownCountKey =
    '${_dailyOsOnboardingKeyPrefix}shown_count';

/// ISO-8601 UTC timestamp of the first auto-show -- the anchor
/// [isDailyOsOnboardingEligible] measures [dailyOsOnboardingWindow] from.
const dailyOsOnboardingFirstShownAtKey =
    '${_dailyOsOnboardingKeyPrefix}first_shown_at';

/// Maximum number of times the walkthrough auto-shows before it retires.
const dailyOsOnboardingMaxShows = 4;

/// The grace window, measured from the first auto-show, during which the
/// walkthrough may keep re-appearing while the user has not yet completed it.
const dailyOsOnboardingWindow = Duration(days: 14);

/// Pure candidate-eligibility predicate. Every input is already resolved by the
/// caller, so this is synchronous and independently unit-testable across every
/// branch without any async/DB/Riverpod plumbing.
///
/// Establishing *candidate* eligibility only: the walkthrough overlay is
/// inserted after the separate app-level coordinator grants Daily OS the
/// auto-show slot (so it never races What's New or the general FTUE).
///
/// Eligible while:
/// - the Daily OS onboarding flag is on (the Daily OS surface itself is always
///   available, so only the walkthrough is gated),
/// - What's New has nothing unseen and the general FTUE welcome is not still
///   owed — the walkthrough is sequenced *behind* both so the three
///   auto-shown surfaces never race for the screen,
/// - the selected Daily OS date is local today (the empty-Day check-in CTA the
///   spotlight anchors to only exists on today's unplanned surface),
/// - today has no active day plan (the real CTA is present),
/// - no day plan has ever existed for the planner, including soft-deleted ones
///   (a returning user who deleted their only plan is not a new user),
/// - the real planning flow reports a usable provider/profile configuration
///   (never invite a user into a flow guaranteed to fail),
/// - the walkthrough has not been completed,
/// - it has auto-shown fewer than [dailyOsOnboardingMaxShows] times, and
/// - once shown at least once, [now] is still within [dailyOsOnboardingWindow]
///   of the first auto-show.
bool isDailyOsOnboardingEligible({
  required bool dailyOsOnboardingFlagEnabled,
  required bool hasUnseenWhatsNew,
  required bool welcomeStillOwed,
  required bool selectedDateIsToday,
  required bool todayHasActivePlan,
  required bool hasEverHadPlan,
  required bool providerReady,
  required bool completed,
  required int shownCount,
  required DateTime? firstShownAt,
  required DateTime now,
}) {
  if (!dailyOsOnboardingFlagEnabled) return false;
  if (hasUnseenWhatsNew) return false;
  if (welcomeStillOwed) return false;
  if (!selectedDateIsToday) return false;
  if (todayHasActivePlan) return false;
  if (hasEverHadPlan) return false;
  if (!providerReady) return false;
  if (completed) return false;
  if (shownCount >= dailyOsOnboardingMaxShows) return false;
  if (firstShownAt != null &&
      now.difference(firstShownAt) >= dailyOsOnboardingWindow) {
    return false;
  }
  return true;
}

/// Whether two [DateTime]s fall on the same local calendar day. Both are
/// normalized to local time first so a UTC/local mix cannot cross a day
/// boundary spuriously.
bool _isSameLocalDay(DateTime a, DateTime b) {
  final localA = a.toLocal();
  final localB = b.toLocal();
  return localA.year == localB.year &&
      localA.month == localB.month &&
      localA.day == localB.day;
}

/// Whether the day-planning flow has a usable AI provider to run against.
///
/// This is the same truth the real `DayPlanningCreate` drafting wake gates on:
/// `DayAgentWorkflow` fails with `'No inference provider configured'` unless the
/// planner's profile resolves a thinking slot, which ultimately requires **at
/// least one configured inference provider that is usable** (API key set, or a
/// keyless local provider with a base URL). Gating the walkthrough on this
/// keeps us from inviting a user into a capture-and-draft flow that is
/// guaranteed to fail — and, reading the reactive config controller, it flips
/// to `true` the moment the user connects a provider.
///
/// Transcription/image slots are non-fatal (resolved best-effort), so the
/// gate is the drafting thinking slot, mirrored here as "a usable provider
/// exists" — which is upstream of profile/template seeding and needs no
/// planner agent to exist yet.
final FutureProvider<bool> dailyOsOnboardingProviderReadyProvider =
    FutureProvider<bool>((ref) async {
      final providers = await ref.watch(
        aiConfigByTypeControllerProvider(AiConfigType.inferenceProvider).future,
      );
      return providers.whereType<AiConfigInferenceProvider>().any(
        (provider) => provider.isUsable,
      );
    }, name: 'dailyOsOnboardingProviderReadyProvider');

/// Candidate-eligibility check for the Daily OS onboarding walkthrough.
///
/// Read-only: mirrors [isDailyOsOnboardingEligible]'s inputs by resolving them
/// from config flags, the selected date, the current/ever plan existence, the
/// readiness seam, and the persisted cadence bookkeeping. The mutation side
/// lives in [DailyOsOnboardingCadence].
final FutureProvider<bool> shouldAutoShowDailyOsOnboardingProvider =
    FutureProvider.autoDispose<bool>(
      shouldAutoShowDailyOsOnboarding,
      name: 'shouldAutoShowDailyOsOnboardingProvider',
    );

Future<bool> shouldAutoShowDailyOsOnboarding(Ref ref) async {
  // Watch every provider synchronously up front: ref.watch after an await gap
  // escapes Riverpod's synchronous subscription tracking, so establish all
  // subscriptions here and only await the resolved futures below.
  final db = ref.watch(journalDbProvider);
  final selectedDate = ref.watch(dailyOsNextSelectedDateProvider);
  final agentRepository = ref.watch(agentRepositoryProvider);
  final todayPlanFuture = ref.watch(
    currentDraftPlanProvider(selectedDate).future,
  );
  final providerReadyFuture = ref.watch(
    dailyOsOnboardingProviderReadyProvider.future,
  );
  // Sequenced behind What's New and the general FTUE welcome: establish those
  // subscriptions synchronously too so this re-evaluates when either resolves.
  final whatsNewFuture = ref.watch(whatsNewControllerProvider.future);
  final welcomeOwedFuture = ref.watch(shouldAutoShowOnboardingProvider.future);

  final onboardingEnabled = await db.getConfigFlag(
    dailyOsOnboardingEnabledFlag,
  );
  if (!onboardingEnabled) return false;

  // What's New still owns the first overlay slot while it has unseen content
  // *and* its own feature is enabled (a disabled What's New reports unseen
  // content forever with no modal able to clear it — mirrors the general
  // FTUE welcome's own guard).
  final whatsNewEnabled = await db.getConfigFlag(enableWhatsNewFlag);
  final hasUnseenWhatsNew =
      whatsNewEnabled && (await whatsNewFuture).hasUnseenRelease;
  // The general FTUE welcome takes the slot ahead of Daily OS while it is
  // still owed.
  final welcomeStillOwed = await welcomeOwedFuture;

  final now = clock.now();
  final selectedDateIsToday = _isSameLocalDay(selectedDate, now);

  // Resolve the plan-existence signals. The "ever" count includes
  // soft-deleted tombstones; the "today" read reflects the active plan only.
  final everPlanCount = await agentRepository.countEntitiesByAgentAndType(
    agentId: dailyOsPlannerAgentId,
    type: AgentEntityTypes.dayPlan,
  );
  final todayPlan = await todayPlanFuture;

  final providerReady = await providerReadyFuture;

  final settingsDb = getIt<SettingsDb>();
  final stored = await settingsDb.itemsByKeys(const [
    dailyOsOnboardingCompletedKey,
    dailyOsOnboardingShownCountKey,
    dailyOsOnboardingFirstShownAtKey,
  ]);
  final firstShownAtRaw = stored[dailyOsOnboardingFirstShownAtKey];

  return isDailyOsOnboardingEligible(
    dailyOsOnboardingFlagEnabled: onboardingEnabled,
    hasUnseenWhatsNew: hasUnseenWhatsNew,
    welcomeStillOwed: welcomeStillOwed,
    selectedDateIsToday: selectedDateIsToday,
    todayHasActivePlan: todayPlan != null,
    hasEverHadPlan: everPlanCount > 0,
    providerReady: providerReady,
    completed: stored[dailyOsOnboardingCompletedKey] == 'true',
    shownCount: int.tryParse(stored[dailyOsOnboardingShownCountKey] ?? '') ?? 0,
    firstShownAt: firstShownAtRaw == null
        ? null
        : DateTime.tryParse(firstShownAtRaw),
    now: now,
  );
}

/// Provider for the Daily OS onboarding walkthrough's cadence bookkeeping --
/// the mutation side of [shouldAutoShowDailyOsOnboardingProvider]'s read-only
/// eligibility check.
final AsyncNotifierProvider<DailyOsOnboardingCadence, void>
dailyOsOnboardingCadenceProvider =
    AsyncNotifierProvider.autoDispose<DailyOsOnboardingCadence, void>(
      DailyOsOnboardingCadence.new,
      name: 'dailyOsOnboardingCadenceProvider',
    );

/// Persists the Daily OS onboarding walkthrough's auto-show bookkeeping in
/// [SettingsDb]. Holds no meaningful state of its own ([build] is a no-op) --
/// the read side lives entirely in [shouldAutoShowDailyOsOnboarding].
class DailyOsOnboardingCadence extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  /// Records that the walkthrough auto-showed once more: bumps
  /// [dailyOsOnboardingShownCountKey] and, only on the very first show, stamps
  /// [dailyOsOnboardingFirstShownAtKey] so the grace window has a fixed start.
  ///
  /// A `SettingsDb` failure is logged and swallowed: failing to persist the
  /// count only degrades the cadence (the walkthrough may show once more than
  /// budgeted), never worth blocking the walkthrough for.
  Future<void> recordShown() async {
    try {
      final settingsDb = getIt<SettingsDb>();
      final stored = await settingsDb.itemsByKeys(const [
        dailyOsOnboardingShownCountKey,
        dailyOsOnboardingFirstShownAtKey,
      ]);
      final shownCount =
          int.tryParse(stored[dailyOsOnboardingShownCountKey] ?? '') ?? 0;
      await settingsDb.saveSettingsItem(
        dailyOsOnboardingShownCountKey,
        '${shownCount + 1}',
      );
      if (stored[dailyOsOnboardingFirstShownAtKey] == null) {
        await settingsDb.saveSettingsItem(
          dailyOsOnboardingFirstShownAtKey,
          clock.now().toUtc().toIso8601String(),
        );
      }
    } catch (error, stackTrace) {
      getIt<DomainLogger>().error(
        LogDomain.onboarding,
        error,
        stackTrace: stackTrace,
        subDomain: 'dailyOsOnboardingRecordShown',
      );
    }
  }

  /// Marks the walkthrough completed once a persisted day plan lands,
  /// permanently retiring the auto-show gate (see
  /// [dailyOsOnboardingCompletedKey]). Called from the walkthrough's
  /// completion callback, not its skip/dismiss path.
  Future<void> markCompleted() => markDailyOsOnboardingCompleted();
}

/// Persists the Daily OS onboarding walkthrough's "completed" flag, permanently
/// retiring the auto-show gate. Shared by
/// [DailyOsOnboardingCadence.markCompleted] and the Settings replay entry so
/// both retire the gate the same way, without reaching into the storage key.
///
/// Like [DailyOsOnboardingCadence.recordShown], a `SettingsDb` failure is
/// logged and swallowed: both call sites invoke this fire-and-forget from a
/// completion callback where a thrown error would be unhandled.
Future<void> markDailyOsOnboardingCompleted() async {
  try {
    await getIt<SettingsDb>().saveSettingsItem(
      dailyOsOnboardingCompletedKey,
      'true',
    );
  } catch (error, stackTrace) {
    getIt<DomainLogger>().error(
      LogDomain.onboarding,
      error,
      stackTrace: stackTrace,
      subDomain: 'dailyOsOnboardingMarkCompleted',
    );
  }
}
