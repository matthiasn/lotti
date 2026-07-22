import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_job.dart';

void main() {
  final createdAt = DateTime.utc(2026, 7, 18, 7, 42);

  DayProcessingJob job({
    DayProcessingJobStatus status = DayProcessingJobStatus.queued,
    DateTime? leaseUntil,
    DateTime? retryNotBefore,
    DayProcessingPayload payload = const TranscribeAudioPayload(
      activityEntryId: 'activity-1',
      recordingSessionId: 'session-1',
      audioId: 'audio-1',
      audioPath: '/audio/one.wav',
    ),
  }) => DayProcessingJob(
    id: 'transcribe_session-1',
    status: status,
    dayId: 'dayplan-2026-07-18',
    payload: payload,
    createdAt: createdAt,
    updatedAt: createdAt,
    requestedAt: createdAt,
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

  group('schema v1 → v2 tolerant parsing', () {
    test('a v1 transcription file (no payload envelope) parses correctly', () {
      final v1Json = <String, Object?>{
        'schemaVersion': 1,
        'id': 'transcribe_legacy',
        'kind': 'transcribeAudio',
        'status': 'succeeded',
        'dayId': 'dayplan-2026-07-10',
        'activityEntryId': 'activity-legacy',
        'recordingSessionId': 'session-legacy',
        'audioId': 'audio-legacy',
        'audioPath': '/audio/legacy.wav',
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': createdAt.toIso8601String(),
        'nextAttemptAt': createdAt.toIso8601String(),
        'attempts': 1,
        'generation': 2,
        'resultTranscript': 'Legacy note.',
      };

      final restored = DayProcessingJob.fromJson(v1Json);

      expect(restored.kind, DayProcessingJobKind.transcribeAudio);
      expect(restored.activityEntryId, 'activity-legacy');
      expect(restored.recordingSessionId, 'session-legacy');
      expect(restored.audioId, 'audio-legacy');
      expect(restored.audioPath, '/audio/legacy.wav');
      // v1 files carry no requestedAt; it falls back to createdAt.
      expect(restored.requestedAt, restored.createdAt);
      expect(restored.resultTranscript, 'Legacy note.');
    });

    test('a v2 file with a nested payload round-trips per kind', () {
      final parse = job(
        payload: const ParseCapturePayload(captureId: 'cap-1'),
      );
      final draft = job(
        payload: const DraftPlanPayload(
          captureId: 'cap-2',
          decidedTaskIds: ['task-1'],
          decidedCaptureItemIds: ['parsed-1'],
        ),
      );
      final refine = job(
        payload: const RefinePlanPayload(transcriptCaptureId: 'cap-3'),
      );

      for (final original in [parse, draft, refine]) {
        final restored = DayProcessingJob.fromJson(original.toJson());
        expect(restored.kind, original.kind);
        expect(restored.payload, original.payload);
      }
    });

    test('an unknown kind throws instead of silently misreading', () {
      final json = <String, Object?>{
        'schemaVersion': 2,
        'id': 'unknown-1',
        'kind': 'somethingElse',
        'status': 'queued',
        'dayId': 'dayplan-2026-07-18',
        'payload': <String, Object?>{},
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': createdAt.toIso8601String(),
        'nextAttemptAt': createdAt.toIso8601String(),
        'attempts': 0,
        'generation': 0,
      };

      expect(() => DayProcessingJob.fromJson(json), throwsArgumentError);
    });
  });

  group('kind-specific convenience getters', () {
    test('audio fields are null for non-transcription payloads', () {
      final parse = job(payload: const ParseCapturePayload(captureId: 'c1'));
      expect(parse.activityEntryId, isNull);
      expect(parse.recordingSessionId, isNull);
      expect(parse.audioId, isNull);
      expect(parse.audioPath, isNull);
    });
  });

  group('DraftPlanPayload re-arm equality', () {
    test('payload equality reflects field-by-field comparison', () {
      const a = DraftPlanPayload(decidedTaskIds: ['t1', 't2']);
      const b = DraftPlanPayload(decidedTaskIds: ['t1', 't2']);
      const c = DraftPlanPayload(decidedTaskIds: ['t1']);
      expect(a, b);
      expect(a, isNot(c));
    });
  });
}
