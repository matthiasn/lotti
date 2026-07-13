import 'package:lotti/features/onboarding/model/onboarding_event.dart';

/// Sink for a Daily OS onboarding event.
///
/// Mirrors the optional `reason` / `valueBucket` columns of
/// `OnboardingMetricsRepository.recordEvent` so stage events that carry
/// attributes are forwarded intact rather than flattened to a bare name. In
/// particular `dailyOsTaskMaterialized` is documented to carry a 1–5 count
/// bucket; keeping those parameters on the seam means the wiring layer that
/// binds this to the real recorder cannot silently drop them.
typedef DailyOsOnboardingEventSink =
    void Function(
      OnboardingEventName event, {
      String? reason,
      int? valueBucket,
    });

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
/// [origin], and exactly-once guards for the stage and skip events.
///
/// Emission is injected via an `onEvent` callback rather than reaching for the
/// metrics repository directly, so the contract is testable in isolation. A
/// later phase wires `onEvent` to `OnboardingMetricsRepository.recordEvent` and
/// has the modal pages call [recordStageOnce] as the real flow advances. The
/// callback carries `reason` / `valueBucket` (see [DailyOsOnboardingEventSink])
/// so attribute-bearing events survive that wiring intact.
class DailyOsOnboardingSession {
  DailyOsOnboardingSession({
    required this.sessionId,
    required this.origin,
    DailyOsOnboardingEventSink? onEvent,
  }) : // Private field, public param: an initializing formal would force a
       // private named parameter, which Dart forbids.
       // ignore: prefer_initializing_formals
       _onEvent = onEvent;

  /// Stable id for this walkthrough run, used to tie its events together.
  final String sessionId;

  /// Whether this run was auto-shown or replayed.
  final DailyOsOnboardingOrigin origin;

  final DailyOsOnboardingEventSink? _onEvent;
  final Set<OnboardingEventName> _recordedStages = {};
  bool _skipRecorded = false;

  /// Whether the session-level skip has been recorded.
  bool get skipRecorded => _skipRecorded;

  /// Records a stage event at most once per session. Repeat calls for an event
  /// already recorded are no-ops, so a rebuilt page cannot double-count.
  ///
  /// [reason] / [valueBucket] are forwarded to the sink unchanged -- e.g.
  /// `dailyOsTaskMaterialized` passes the 1–5 materialized-task count as
  /// [valueBucket]. The once-guard keys on [event] alone, so the attributes of
  /// the first recorded call are the ones that land.
  void recordStageOnce(
    OnboardingEventName event, {
    String? reason,
    int? valueBucket,
  }) {
    if (!_recordedStages.add(event)) return;
    _onEvent?.call(event, reason: reason, valueBucket: valueBucket);
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
