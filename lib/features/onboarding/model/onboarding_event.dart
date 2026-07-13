/// Vocabulary and derived-state model for the first-time-user-experience
/// (FTUE) funnel.
///
/// These names form the content-free event vocabulary written to
/// `OnboardingMetricsDb`. They are emitted across the onboarding phases
/// (welcome → connect → capture → structure → return); Phase 0 only defines
/// the vocabulary and the derivation logic so the funnel is queryable before
/// any user-facing UI exists.
library;

/// The day this measurement substrate shipped, in UTC. Any install whose first
/// `appFirstSeen` predates this — or that is tagged as a pre-existing user —
/// is treated as a pre-FTUE baseline cohort for before/after comparison.
final DateTime kFtueReleaseDateUtc = DateTime.utc(2026, 6, 21);

/// Reason tag recorded on [OnboardingEventName.appFirstSeen] to distinguish a
/// genuinely new install from a pre-existing user upgrading into the FTUE
/// build (the latter is part of the pre-FTUE baseline cohort).
const String onboardingExistingUserReason = 'existing_user';
const String onboardingNewInstallReason = 'new_install';

/// Whole days since the Unix epoch in UTC. Used for active-day grouping so the
/// funnel does not depend on local wall-clock or timezone.
int onboardingDayBucket(DateTime dt) =>
    dt.toUtc().difference(DateTime.utc(1970)).inDays;

/// The day bucket of [kFtueReleaseDateUtc].
final int kFtueReleaseDayBucketUtc = onboardingDayBucket(kFtueReleaseDateUtc);

/// The funnel events. Stored as their [name] (camelCase) in the DB; the wire
/// format only needs to be stable and grep-friendly, not snake_case.
enum OnboardingEventName {
  /// First launch of the app on this device/install (idempotent, once ever).
  appFirstSeen,

  /// The cinematic welcome was shown.
  welcomeShown,

  /// The user dismissed/skipped the welcome.
  welcomeSkipped,

  /// The provider-connect modal was shown.
  providerModalShown,

  /// The user connected an AI provider (provider dimension carries which).
  providerConnected,

  /// The user skipped/deferred connecting a provider.
  providerSkipped,

  /// A pasted API key was rejected (reason carries invalid|quota|network).
  keyPasteError,

  /// Microphone permission resolved (reason carries granted|denied).
  micPermissionOutcome,

  /// A real voice note was captured (value bucket carries a duration bucket).
  firstAudioCaptured,

  /// The user used the typed-capture fallback instead of voice.
  typedCaptureUsed,

  /// The user tapped "make this a task" / started structuring.
  makeTaskTapped,

  /// The marquee aha: a real-LLM structured task (title + checklist) landed.
  realAha,

  /// The structuring failure floor: a title-only task was produced instead.
  structuringFloorUsed,

  /// Structuring failed (reason carries the error class).
  structuringFailed,

  /// The user started a second in-session capture.
  secondCaptureStarted,

  /// The user completed a second in-session capture.
  secondCaptureCompleted,

  /// A D1 return reminder was scheduled (iOS/macOS only).
  returnNudgeScheduled,

  /// Notification permission resolved (reason carries granted|denied).
  notificationPermissionOutcome,

  /// The pull-first next-launch "welcome back" beat was shown.
  nextLaunchReturnBeatShown,

  /// A return session occurred (value bucket carries days since first seen).
  returnSession,

  // ── Daily OS onboarding walkthrough ──────────────────────────────────────
  // A distinct vocabulary sharing the same physical event store. These events
  // are partitioned out of the general FTUE funnel derivation (see
  // [OnboardingFunnelState]) and feed [DailyOsOnboardingFunnelState] instead,
  // so reusing the table never changes the meaning of the FTUE metrics.

  /// The Daily OS onboarding spotlight was shown (reason carries auto|replay).
  dailyOsWalkthroughShown,

  /// The user dismissed Daily OS onboarding guidance (at most once per
  /// session).
  dailyOsWalkthroughSkipped,

  /// The coached create modal reached its Reconcile stage.
  dailyOsReconcileReached,

  /// The coached create modal reached its Drafting stage.
  dailyOsDraftingStarted,

  /// Drafting materialized one or more real tasks from approved capture items
  /// (value bucket carries the count, 1–5 where 5 means "five or more").
  dailyOsTaskMaterialized,

  /// The walkthrough completed with a persisted day plan.
  dailyOsWalkthroughCompleted;

  /// The string written to / read from the DB.
  String get wireName => name;

  /// Whether this event belongs to the Daily OS onboarding vocabulary rather
  /// than the general FTUE funnel. Used to partition the two derived funnels
  /// over the shared event store.
  bool get isDailyOsOnboarding => _dailyOsOnboardingEvents.contains(this);

  /// Resolves a stored [wireName] back to its [OnboardingEventName], or null if
  /// the name is unknown (e.g. a future event recorded by a newer build). Neither
  /// funnel projection treats an unknown name as activity.
  static OnboardingEventName? fromWireName(String wireName) =>
      _byWireName[wireName];
}

/// The Daily OS onboarding event vocabulary. Declared explicitly (rather than
/// inferred from the `dailyOs` name prefix) so adding an unrelated event that
/// happens to start with `dailyOs` cannot silently join this partition.
const Set<OnboardingEventName> _dailyOsOnboardingEvents = {
  OnboardingEventName.dailyOsWalkthroughShown,
  OnboardingEventName.dailyOsWalkthroughSkipped,
  OnboardingEventName.dailyOsReconcileReached,
  OnboardingEventName.dailyOsDraftingStarted,
  OnboardingEventName.dailyOsTaskMaterialized,
  OnboardingEventName.dailyOsWalkthroughCompleted,
};

final Map<String, OnboardingEventName> _byWireName = {
  for (final name in OnboardingEventName.values) name.wireName: name,
};

/// Derived, read-only snapshot of the general FTUE funnel, computed from the
/// append-only event log. Never persisted as a second store.
///
/// This projection is partitioned to the **general FTUE** vocabulary: Daily OS
/// onboarding events (and any unknown/future names) share the same physical
/// store but are excluded from these counts and active-day metrics, so reusing
/// the table for Daily OS onboarding never shifts `activeDaysCount`,
/// `activeDaysInFirst7`, or any FTUE event count. See
/// [DailyOsOnboardingFunnelState] for the Daily OS projection.
class OnboardingFunnelState {
  const OnboardingFunnelState({
    required this.installFirstSeen,
    required this.activeDayBuckets,
    required this.isBaselineCohort,
    required this.eventCounts,
  });

  /// Empty state used before any event has been recorded.
  const OnboardingFunnelState.empty()
    : installFirstSeen = null,
      activeDayBuckets = const [],
      isBaselineCohort = false,
      eventCounts = const {};

  /// Earliest [OnboardingEventName.appFirstSeen] timestamp, if recorded.
  final DateTime? installFirstSeen;

  /// Sorted, de-duplicated UTC day buckets on which any event occurred.
  final List<int> activeDayBuckets;

  /// Whether this install predates the FTUE (pre-FTUE baseline cohort).
  final bool isBaselineCohort;

  /// Count of events per [OnboardingEventName.wireName].
  final Map<String, int> eventCounts;

  /// Number of distinct active days.
  int get activeDaysCount => activeDayBuckets.length;

  /// The day bucket of first launch, if known.
  int? get installDayBucket =>
      installFirstSeen == null ? null : onboardingDayBucket(installFirstSeen!);

  /// Active days within the first 7 days of install — the in-v1 leading
  /// indicator for D30 retention (real D30 cohorts are months away).
  int get activeDaysInFirst7 {
    final start = installDayBucket;
    if (start == null) return 0;
    return activeDayBuckets.where((d) => d >= start && d <= start + 6).length;
  }

  /// How many times [name] occurred.
  int countOf(OnboardingEventName name) => eventCounts[name.wireName] ?? 0;

  /// Whether [name] occurred at least once.
  bool reached(OnboardingEventName name) => countOf(name) > 0;

  bool get connectedProvider => reached(OnboardingEventName.providerConnected);
  bool get capturedAudio => reached(OnboardingEventName.firstAudioCaptured);
  bool get tappedMakeTask => reached(OnboardingEventName.makeTaskTapped);
  bool get reachedRealAha => reached(OnboardingEventName.realAha);
  bool get usedStructuringFloor =>
      reached(OnboardingEventName.structuringFloorUsed);
}

/// Derived, read-only snapshot of the Daily OS onboarding funnel, computed from
/// the same append-only event log as [OnboardingFunnelState] but partitioned to
/// the Daily OS onboarding vocabulary. Never persisted as a second store.
class DailyOsOnboardingFunnelState {
  const DailyOsOnboardingFunnelState({
    required this.activeDayBuckets,
    required this.eventCounts,
  });

  /// Empty state used before any Daily OS onboarding event has been recorded.
  const DailyOsOnboardingFunnelState.empty()
    : activeDayBuckets = const [],
      eventCounts = const {};

  /// Sorted, de-duplicated UTC day buckets on which a Daily OS onboarding event
  /// occurred.
  final List<int> activeDayBuckets;

  /// Count of Daily OS onboarding events per [OnboardingEventName.wireName].
  final Map<String, int> eventCounts;

  /// Number of distinct days with Daily OS onboarding activity.
  int get activeDaysCount => activeDayBuckets.length;

  /// How many times [name] occurred.
  int countOf(OnboardingEventName name) => eventCounts[name.wireName] ?? 0;

  /// Whether [name] occurred at least once.
  bool reached(OnboardingEventName name) => countOf(name) > 0;

  int get shownCount => countOf(OnboardingEventName.dailyOsWalkthroughShown);
  int get skippedCount =>
      countOf(OnboardingEventName.dailyOsWalkthroughSkipped);
  int get reconcileReachedCount =>
      countOf(OnboardingEventName.dailyOsReconcileReached);
  int get draftingStartedCount =>
      countOf(OnboardingEventName.dailyOsDraftingStarted);
  int get taskMaterializedCount =>
      countOf(OnboardingEventName.dailyOsTaskMaterialized);
  int get completedCount =>
      countOf(OnboardingEventName.dailyOsWalkthroughCompleted);

  /// Whether the walkthrough has completed at least once (a persisted plan
  /// landed).
  bool get completed =>
      reached(OnboardingEventName.dailyOsWalkthroughCompleted);
}
