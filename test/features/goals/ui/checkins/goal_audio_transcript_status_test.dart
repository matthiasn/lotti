import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/goals/ui/checkins/goal_audio_transcript_status.dart';
import 'package:lotti/widgets/timeline/timeline_models.dart';

void main() {
  final now = DateTime(2026, 8, 11, 12);
  final graceOpen = now.add(const Duration(minutes: 5));
  final graceClosed = now.subtract(const Duration(minutes: 1));

  TimelineTranscriptStatus status({
    bool hasTranscript = false,
    InferenceStatus inference = InferenceStatus.idle,
    bool durableFailure = false,
    DateTime? graceExpiry,
  }) => goalAudioTranscriptStatus(
    hasTranscript: hasTranscript,
    inference: inference,
    durableFailure: durableFailure,
    graceExpiry: graceExpiry ?? graceOpen,
    now: now,
  );

  test('words win over every other signal', () {
    expect(
      status(
        hasTranscript: true,
        inference: InferenceStatus.error,
        durableFailure: true,
        graceExpiry: graceClosed,
      ),
      TimelineTranscriptStatus.none,
    );
  });

  test('a running transcription is pending, even past the grace window', () {
    expect(
      status(inference: InferenceStatus.running, graceExpiry: graceClosed),
      TimelineTranscriptStatus.pending,
    );
  });

  test('a live or a durable failure is a failure', () {
    expect(
      status(inference: InferenceStatus.error),
      TimelineTranscriptStatus.failed,
    );
    expect(status(durableFailure: true), TimelineTranscriptStatus.failed);
  });

  test('an idle recording waits out the grace window, then has stalled', () {
    expect(status(), TimelineTranscriptStatus.pending);
    expect(
      status(graceExpiry: graceClosed),
      TimelineTranscriptStatus.stalled,
    );
  });
}
