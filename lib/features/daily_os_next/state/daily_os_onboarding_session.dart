import 'package:lotti/features/onboarding/model/onboarding_event.dart';

/// Where a Daily OS onboarding walkthrough session came from.
enum DailyOsOnboardingOrigin {
  /// Auto-shown to an eligible new user via the auto-show gate.
  auto,

  /// Re-armed by the Settings → Onboarding replay entry.
  replay,
}

/// One Daily OS onboarding walkthrough session.
///
/// The walkthrough spans the empty-Day spotlight and the real create modal
/// (Capture → Reconcile → Drafting). Those surfaces rebuild constantly, and the
/// Wolt modal recreates its page widgets across page swaps, so per-widget
/// booleans cannot enforce "record this stage once." This session owns that
/// bookkeeping for the whole walkthrough instead: a stable [sessionId], its
/// [origin], whether coaching tips are still visible, and exactly-once guards
/// for the stage and skip events.
///
/// Emission is injected via an `onEvent` callback rather than reaching for the
/// metrics repository directly, so the contract is testable in isolation. A
/// later phase wires `onEvent` to `OnboardingMetricsRepository.recordEvent` and
/// has the modal pages call [recordStageOnce] as the real flow advances.
class DailyOsOnboardingSession {
  DailyOsOnboardingSession({
    required this.sessionId,
    required this.origin,
    void Function(OnboardingEventName event)? onEvent,
    bool tipsVisible = true,
  }) : // Private field, public param: an initializing formal would force a
       // private named parameter, which Dart forbids.
       // ignore: prefer_initializing_formals
       _onEvent = onEvent,
       // ignore: prefer_initializing_formals
       _tipsVisible = tipsVisible;

  /// Stable id for this walkthrough run, used to tie its events together.
  final String sessionId;

  /// Whether this run was auto-shown or replayed.
  final DailyOsOnboardingOrigin origin;

  final void Function(OnboardingEventName event)? _onEvent;
  final Set<OnboardingEventName> _recordedStages = {};
  bool _tipsVisible;
  bool _skipRecorded = false;

  /// Whether coaching tips should still render. Flips to false once the user
  /// hides tips; it never flips back within a session.
  bool get tipsVisible => _tipsVisible;

  /// Whether the session-level skip has been recorded.
  bool get skipRecorded => _skipRecorded;

  /// Hides coaching for the remainder of this session without interrupting the
  /// real modal. Also records the session skip (hiding tips is a rejection of
  /// guidance, distinct from completing the plan).
  void hideTips() {
    _tipsVisible = false;
    recordSkippedOnce();
  }

  /// Records a stage event at most once per session. Repeat calls for an event
  /// already recorded are no-ops, so a rebuilt page cannot double-count.
  void recordStageOnce(OnboardingEventName event) {
    if (!_recordedStages.add(event)) return;
    _onEvent?.call(event);
  }

  /// Records the session-level `dailyOsWalkthroughSkipped` at most once --
  /// fired when the user dismisses the initial spotlight, hides tips, or closes
  /// an incomplete coached modal. Skip measures rejection of guidance; a later
  /// successful plan in the same session still records completion separately.
  void recordSkippedOnce() {
    if (_skipRecorded) return;
    _skipRecorded = true;
    _onEvent?.call(OnboardingEventName.dailyOsWalkthroughSkipped);
  }
}
