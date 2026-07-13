import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_onboarding_session.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_onboarding_trigger_service.dart';
import 'package:lotti/features/onboarding/model/onboarding_event.dart';
import 'package:lotti/features/onboarding/repository/onboarding_metrics_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/utils/file_utils.dart';

/// Holds the single active Daily OS onboarding walkthrough session, or `null`
/// when no walkthrough is running.
///
/// This is the coordination point the walkthrough UI reads: the empty-Day
/// spotlight and the modal coach strips both watch this provider to decide
/// whether to render and which session to record against. The session is armed
/// by the auto-show gate or the Settings replay entry (a later phase) and ends
/// on completion or dismissal.
///
/// Session events (stage transitions, skip) are emitted to
/// `OnboardingMetricsRepository` via the session's injected `onEvent`, so the
/// exactly-once bookkeeping lives in [DailyOsOnboardingSession] and the
/// controller only owns the lifecycle and the metrics hop.
class DailyOsOnboardingSessionController
    extends Notifier<DailyOsOnboardingSession?> {
  @override
  DailyOsOnboardingSession? build() => null;

  /// Starts a walkthrough session with metrics-wired event emission and makes
  /// it the active session. Returns the started session.
  ///
  /// [sessionId] defaults to a fresh id; pass one only to correlate with an
  /// externally-generated id. Recording the `Shown` event is not part of
  /// starting the session — `DayCheckInSpotlightHost` records it once the
  /// spotlight is actually on-screen, so the metric reflects a walkthrough the
  /// user genuinely saw.
  DailyOsOnboardingSession start({
    required DailyOsOnboardingOrigin origin,
    required DateTime targetDate,
    String? sessionId,
  }) {
    final localTargetDate = targetDate.toLocal();
    final session = DailyOsOnboardingSession(
      sessionId: sessionId ?? uuid.v1(),
      origin: origin,
      targetDate: DateTime(
        localTargetDate.year,
        localTargetDate.month,
        localTargetDate.day,
      ),
      onEvent: (event, {reason, valueBucket}) => _record(
        event,
        origin: origin,
        reason: reason,
        valueBucket: valueBucket,
      ),
    );
    state = session;
    return session;
  }

  /// Ends the active walkthrough session (completed or dismissed). Idempotent.
  void end() {
    if (state == null) return;
    state = null;
  }

  /// Records a successful walkthrough completion for the active session: the
  /// materialized-task count (when any tasks were created), the completion
  /// event, and the permanent cadence retirement, then ends the session.
  ///
  /// No-op when no session is active — the ordinary (un-onboarded) create flow
  /// calls this too, and simply does nothing. [createdTaskIds] is the set
  /// attributed by the modal; its size feeds the 1–5 `dailyOsTaskMaterialized`
  /// bucket.
  Future<void> complete({List<String> createdTaskIds = const []}) async {
    final session = state;
    if (session == null) return;
    if (createdTaskIds.isNotEmpty) {
      session.recordStageOnce(
        OnboardingEventName.dailyOsTaskMaterialized,
        valueBucket: createdTaskIds.length.clamp(1, 5),
      );
    }
    session.recordStageOnce(OnboardingEventName.dailyOsWalkthroughCompleted);
    await ref.read(dailyOsOnboardingCadenceProvider.notifier).markCompleted();
    end();
  }

  /// Records a dismissal (the coached modal closed without a plan) for the
  /// active session: the session skip, then ends it. No-op when no session is
  /// active.
  void dismiss() {
    final session = state;
    if (session == null) return;
    session.recordSkippedOnce();
    end();
  }

  /// Records a session event to the onboarding metrics store. Best-effort:
  /// swallowed when the repository is not registered (most tests) so a metrics
  /// hiccup never disrupts the walkthrough.
  ///
  /// The event's own [reason] wins when present; otherwise the session
  /// [origin] (`auto` / `replay`) is recorded so the funnel can segment
  /// auto-shown runs from replays. [valueBucket] (e.g. the materialized-task
  /// count) is forwarded unchanged.
  void _record(
    OnboardingEventName event, {
    required DailyOsOnboardingOrigin origin,
    String? reason,
    int? valueBucket,
  }) {
    if (!getIt.isRegistered<OnboardingMetricsRepository>()) return;
    unawaited(
      _recordBestEffort(
        getIt<OnboardingMetricsRepository>(),
        event,
        reason: reason ?? origin.name,
        valueBucket: valueBucket,
      ),
    );
  }

  Future<void> _recordBestEffort(
    OnboardingMetricsRepository repository,
    OnboardingEventName event, {
    required String reason,
    int? valueBucket,
  }) async {
    try {
      await repository.recordEvent(
        event,
        reason: reason,
        valueBucket: valueBucket,
      );
    } catch (_) {}
  }
}

final dailyOsOnboardingSessionControllerProvider =
    NotifierProvider<
      DailyOsOnboardingSessionController,
      DailyOsOnboardingSession?
    >(
      DailyOsOnboardingSessionController.new,
      name: 'dailyOsOnboardingSessionControllerProvider',
    );
