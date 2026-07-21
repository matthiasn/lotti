import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_job.dart';

void main() {
  final createdAt = DateTime.utc(2026, 7, 18, 7, 42);

  DayProcessingJob job({
    DayProcessingJobStatus status = DayProcessingJobStatus.queued,
    DateTime? leaseUntil,
    DateTime? retryNotBefore,
  }) => DayProcessingJob(
    id: 'transcribe_session-1',
    kind: DayProcessingJobKind.transcribeAudio,
    status: status,
    dayId: 'dayplan-2026-07-18',
    activityEntryId: 'activity-1',
    recordingSessionId: 'session-1',
    audioId: 'audio-1',
    audioPath: '/audio/one.wav',
    createdAt: createdAt,
    updatedAt: createdAt,
    nextAttemptAt: createdAt,
    attempts: 0,
    generation: 0,
    leaseUntil: leaseUntil,
    retryNotBefore: retryNotBefore,
  );

  test('round-trips every persisted retry boundary', () {
    final original =
        job(
          status: DayProcessingJobStatus.running,
          leaseUntil: createdAt.add(const Duration(minutes: 3)),
          retryNotBefore: createdAt.add(const Duration(minutes: 1)),
        ).copyWith(
          claimToken: 'claim-1',
          lastFailureClass: DayProcessingFailureClass.providerBusy,
          lastError: 'busy',
          resultTranscript: 'Gym first, then the proposal.',
        );

    final restored = DayProcessingJob.fromJson(original.toJson());

    expect(restored.toJson(), original.toJson());
    expect(restored.claimToken, 'claim-1');
    expect(restored.lastFailureClass, DayProcessingFailureClass.providerBusy);
    expect(restored.resultTranscript, 'Gym first, then the proposal.');
  });

  test('running work becomes due only after its persisted lease', () {
    final running = job(
      status: DayProcessingJobStatus.running,
      leaseUntil: createdAt.add(const Duration(minutes: 3)),
    );

    expect(running.isDue(createdAt.add(const Duration(minutes: 2))), isFalse);
    expect(running.isDue(createdAt.add(const Duration(minutes: 3))), isTrue);
  });

  test('hard retry boundary wins over an otherwise due job', () {
    final busy = job(
      retryNotBefore: createdAt.add(const Duration(minutes: 5)),
    );

    expect(busy.isDue(createdAt.add(const Duration(minutes: 4))), isFalse);
    expect(busy.isDue(createdAt.add(const Duration(minutes: 5))), isTrue);
  });
}
