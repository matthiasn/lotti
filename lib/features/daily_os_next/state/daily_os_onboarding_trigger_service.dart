import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_service.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/features/daily_os_next/state/selected_date_provider.dart';
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
/// - both the Daily OS onboarding flag and the Daily OS page flag are on
///   (no point coaching a surface the user cannot reach),
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
  required bool dailyOsPageEnabled,
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
  if (!dailyOsPageEnabled) return false;
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

/// Whether two [DateTime]s fall on the same local calendar day.
bool _isSameLocalDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Seam for the real planning-flow provider/profile readiness signal.
///
/// Phase 0 defaults this to `false` so the walkthrough never auto-shows before
/// a later phase wires it to the same readiness truth the real
/// `DayPlanningCreate` flow relies on. Combined with the off-by-default
/// [dailyOsOnboardingEnabledFlag], this keeps the substrate inert until the
/// walkthrough UI and its readiness check ship. Tests and the wiring phase
/// override this provider.
final FutureProvider<bool> dailyOsOnboardingProviderReadyProvider =
    FutureProvider<bool>(
      (ref) async => false,
      name: 'dailyOsOnboardingProviderReadyProvider',
    );

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
  final db = ref.watch(journalDbProvider);

  final onboardingEnabled = await db.getConfigFlag(
    dailyOsOnboardingEnabledFlag,
  );
  if (!onboardingEnabled) return false;
  final pageEnabled = await db.getConfigFlag(enableDailyOsPageFlag);
  if (!pageEnabled) return false;

  final now = clock.now();
  final selectedDate = ref.watch(dailyOsNextSelectedDateProvider);
  final selectedDateIsToday = _isSameLocalDay(selectedDate, now);

  // Resolve the plan-existence signals. The "ever" count includes
  // soft-deleted tombstones; the "today" read reflects the active plan only.
  final agentRepository = ref.watch(agentRepositoryProvider);
  final everPlanCount = await agentRepository.countEntitiesByAgentAndType(
    agentId: dailyOsPlannerAgentId,
    type: AgentEntityTypes.dayPlan,
  );
  final todayPlan = await ref.watch(
    currentDraftPlanProvider(selectedDate).future,
  );

  final providerReady = await ref.watch(
    dailyOsOnboardingProviderReadyProvider.future,
  );

  final settingsDb = getIt<SettingsDb>();
  final stored = await settingsDb.itemsByKeys(const [
    dailyOsOnboardingCompletedKey,
    dailyOsOnboardingShownCountKey,
    dailyOsOnboardingFirstShownAtKey,
  ]);
  final firstShownAtRaw = stored[dailyOsOnboardingFirstShownAtKey];

  return isDailyOsOnboardingEligible(
    dailyOsOnboardingFlagEnabled: onboardingEnabled,
    dailyOsPageEnabled: pageEnabled,
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
