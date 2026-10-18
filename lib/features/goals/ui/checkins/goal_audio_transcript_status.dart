import 'dart:async';

import 'package:clock/clock.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/widgets/timeline/timeline_models.dart';
import 'package:material_ui/material_ui.dart';

/// Rebuilds a surface showing goal recordings the moment the soonest grace
/// window closes ([goalAudioTranscriptStatus]).
///
/// Without it the status is only recomputed when something else rebuilds —
/// a transcript arriving, an inference status changing, a database
/// notification. A user who records and stays on the page gets none of those
/// when the recording is exactly the one nothing picked up, so it would sit
/// on "Transcribing…" for as long as the page stayed open: the one case the
/// stalled state exists to catch is the one case nothing would have
/// refreshed. Shared by the check-in rail and the charter's recordings.
mixin GoalTranscriptGraceRebuild<T extends StatefulWidget> on State<T> {
  Timer? _graceTimer;
  DateTime? _armedFor;

  @override
  void dispose() {
    _graceTimer?.cancel();
    super.dispose();
  }

  /// Arms (or re-arms, or cancels) the rebuild for [deadline].
  ///
  /// Idempotent on the deadline, because this is called from `build` and must
  /// not restart the timer on every unrelated rebuild — that would push the
  /// wake-up further out each time and never fire.
  void armGraceRebuild(DateTime? deadline) {
    if (deadline == _armedFor) return;
    _graceTimer?.cancel();
    _armedFor = deadline;
    if (deadline == null) return;
    final remaining = deadline.difference(clock.now());
    _graceTimer = Timer(
      remaining.isNegative ? Duration.zero : remaining,
      () {
        if (!mounted) return;
        // Cleared so the next build's deadline is never mistaken for the one
        // just served, which would leave the following recording unarmed.
        setState(() => _armedFor = null);
      },
    );
  }
}

/// What a goal's recording shows where its words would be — the one rule the
/// check-in rail and the charter share, so a recording reads the same on
/// both.
///
/// Words win. Without them: a running transcription is pending; a live or
/// durable failure is failed; and an idle recording is pending until
/// [graceExpiry], then stalled — nobody picked it up, which is a different
/// thing from a provider error and offers the same Retry.
TimelineTranscriptStatus goalAudioTranscriptStatus({
  required bool hasTranscript,
  required InferenceStatus inference,
  required bool durableFailure,
  required DateTime graceExpiry,
  required DateTime now,
}) {
  if (hasTranscript) return TimelineTranscriptStatus.none;
  if (inference == InferenceStatus.running) {
    return TimelineTranscriptStatus.pending;
  }
  if (inference == InferenceStatus.error || durableFailure) {
    return TimelineTranscriptStatus.failed;
  }
  return graceExpiry.isAfter(now)
      ? TimelineTranscriptStatus.pending
      : TimelineTranscriptStatus.stalled;
}
