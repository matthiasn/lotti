import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/widgets/timeline/timeline_models.dart';

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
