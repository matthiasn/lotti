import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/repository/transcription_exception.dart';
import 'package:lotti/features/ai_chat/services/audio_transcription_service.dart'
    show AttributedTranscriptionException, TranscriptionEvidenceState;
import 'package:lotti/features/daily_os_next/services/day_agent_job_executor.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_job.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_outbox_processor.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_outbox_repository.dart';
import 'package:path/path.dart' as path;

void main() {
  late Directory root;
  late File audio;
  late DateTime now;
  late DayProcessingOutboxRepository repository;

  setUp(() async {
    root = Directory.systemTemp.createTempSync('day-processor-test-');
    audio = File(path.join(root.path, 'audio.wav'));
    await audio.writeAsBytes(<int>[1, 2, 3], flush: true);
    now = DateTime.utc(2026, 7, 18, 8);
    repository = DayProcessingOutboxRepository(
      rootDirectory: Directory(path.join(root.path, 'outbox')),
      now: () => now,
      tokenFactory: () => 'claim-token',
    );
    await repository.enqueueTranscription(
      dayId: 'dayplan-2026-07-18',
      activityEntryId: 'activity-1',
      recordingSessionId: 'session-1',
      audioId: 'audio-1',
      audioPath: audio.path,
      capturedAt: now,
    );
  });

  tearDown(() async {
    await repository.dispose();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  test('persists provider output, commits it, then marks success', () async {
    DayProcessingJob? attachedJob;
    final processor = DayProcessingOutboxProcessor(
      repository: repository,
      transcribe: (_) async => 'Gym first, then the proposal.',
      attachTranscript: (job, transcript) async {
        attachedJob = job;
        expect(transcript, 'Gym first, then the proposal.');
        return true;
      },
    );

    final result = await processor.processNext();
    final saved = await repository.getById('transcribe_session-1');

    expect(result, DayProcessingRunResult.succeeded);
    expect(attachedJob!.resultTranscript, 'Gym first, then the proposal.');
    expect(saved!.status, DayProcessingJobStatus.succeeded);
    expect(saved.attempts, 1);
  });

  test('journal retry reuses durable provider output', () async {
    var transcribeCalls = 0;
    var attachCalls = 0;
    final processor = DayProcessingOutboxProcessor(
      repository: repository,
      transcribe: (_) async {
        transcribeCalls += 1;
        return 'Recovered text';
      },
      attachTranscript: (_, _) async {
        attachCalls += 1;
        return attachCalls > 1;
      },
    );

    expect(await processor.processNext(), DayProcessingRunResult.deferred);
    now = now.add(const Duration(seconds: 1));
    expect(await processor.processNext(), DayProcessingRunResult.succeeded);

    expect(transcribeCalls, 1);
    expect(attachCalls, 2);
  });

  test('offline preflight waits without invoking inference', () async {
    var transcribeCalls = 0;
    final processor = DayProcessingOutboxProcessor(
      repository: repository,
      isOnline: () async => false,
      transcribe: (_) async {
        transcribeCalls += 1;
        return 'unreachable';
      },
      attachTranscript: (_, _) async => true,
    );

    final result = await processor.processNext();
    final saved = await repository.getById('transcribe_session-1');

    expect(result, DayProcessingRunResult.deferred);
    expect(transcribeCalls, 0);
    expect(saved!.status, DayProcessingJobStatus.waitingForNetwork);
    expect(saved.attempts, 0);
  });

  test('retryable provider failure uses deterministic full jitter', () async {
    final processor = DayProcessingOutboxProcessor(
      repository: repository,
      randomUnit: () => 0.5,
      transcribe: (_) async => throw TimeoutException('slow'),
      attachTranscript: (_, _) async => true,
    );

    final result = await processor.processNext();
    final saved = await repository.getById('transcribe_session-1');

    expect(result, DayProcessingRunResult.deferred);
    expect(saved!.attempts, 1);
    expect(saved.nextAttemptAt, now.add(const Duration(milliseconds: 2500)));
  });

  test('default jitter and bounded drain process available work', () async {
    final processor = DayProcessingOutboxProcessor(
      repository: repository,
      transcribe: (_) async => throw TimeoutException('slow'),
      attachTranscript: (_, _) async => true,
    );

    expect(await processor.drain(maxJobs: 1), 1);
    final saved = await repository.getById('transcribe_session-1');
    expect(saved!.nextAttemptAt, now.add(const Duration(milliseconds: 2500)));
  });

  test(
    'missing saved audio remains queued for automatic recovery retry',
    () async {
      await audio.delete();
      final processor = DayProcessingOutboxProcessor(
        repository: repository,
        transcribe: (_) async => 'never',
        attachTranscript: (_, _) async => true,
      );

      final result = await processor.processNext();
      final saved = await repository.getById('transcribe_session-1');

      expect(result, DayProcessingRunResult.deferred);
      expect(saved!.attempts, 0);
      expect(saved.status, DayProcessingJobStatus.queued);
      expect(saved.nextAttemptAt, now.add(const Duration(seconds: 5)));
      expect(saved.lastFailureClass, DayProcessingFailureClass.missingAsset);
    },
  );

  test(
    'a claim revoked mid-flight defers instead of escaping as an error',
    () async {
      final processor = DayProcessingOutboxProcessor(
        repository: repository,
        transcribe: (_) async {
          // Reviewed text satisfied the job while the provider call ran; the
          // claim token is gone by the time this attempt reports back.
          await repository.satisfyWithReviewedText(
            'transcribe_session-1',
            'User reviewed wording',
          );
          throw TimeoutException('slow provider');
        },
        attachTranscript: (_, _) async => true,
      );

      final result = await processor.processNext();
      final saved = await repository.getById('transcribe_session-1');

      expect(result, DayProcessingRunResult.deferred);
      expect(saved!.status, DayProcessingJobStatus.succeeded);
      expect(saved.resultTranscript, 'User reviewed wording');
    },
  );

  test(
    'failure classifier separates setup, retryable, and terminal errors',
    () {
      final cases = <(Object, DayProcessingFailureClass)>[
        (
          TranscriptionException('unauthorized', statusCode: 401),
          DayProcessingFailureClass.setupRequired,
        ),
        (
          TranscriptionException('busy', statusCode: 429),
          DayProcessingFailureClass.providerBusy,
        ),
        (
          TranscriptionException('server', statusCode: 503),
          DayProcessingFailureClass.timeout,
        ),
        (
          TranscriptionException('unsupported', statusCode: 422),
          DayProcessingFailureClass.deterministic,
        ),
        (
          const FormatException('empty'),
          DayProcessingFailureClass.deterministic,
        ),
        (const SocketException('offline'), DayProcessingFailureClass.network),
      ];

      for (final (error, expected) in cases) {
        expect(
          classifyDayProcessingFailure(error).failureClass,
          expected,
          reason: error.toString(),
        );
      }

      for (final message in [
        'No audio-capable model is available',
        'Audio model not configured',
        'Missing provider credential',
      ]) {
        expect(
          classifyDayProcessingFailure(
            TranscriptionException(message),
          ).failureClass,
          DayProcessingFailureClass.setupRequired,
        );
        // Model resolution throws plain exceptions before any HTTP status
        // exists; they must land on setup, not retry-forever timeout.
        expect(
          classifyDayProcessingFailure(Exception(message)).failureClass,
          DayProcessingFailureClass.setupRequired,
        );
      }

      // Attribution wraps the provider failure; the cause decides the class.
      expect(
        classifyDayProcessingFailure(
          const AttributedTranscriptionException(
            cause: SocketException('offline'),
            evidenceState: TranscriptionEvidenceState.uncertain,
          ),
        ).failureClass,
        DayProcessingFailureClass.network,
      );
      expect(
        classifyDayProcessingFailure(
          AttributedTranscriptionException(
            cause: Exception('No audio-capable models configured'),
            evidenceState: TranscriptionEvidenceState.uncertain,
          ),
        ).failureClass,
        DayProcessingFailureClass.setupRequired,
      );
    },
  );

  group('agent-job dispatch (ADR 0032 phase 1)', () {
    Future<DayProcessingJob> enqueueParse() => repository.enqueueParseCapture(
      dayId: 'dayplan-2026-07-18',
      captureId: 'cap-1',
    );

    test('a successful agent job marks the outbox row succeeded', () async {
      DayProcessingJob? seen;
      final processor = DayProcessingOutboxProcessor(
        repository: repository,
        transcribe: (_) async => 'unused',
        attachTranscript: (_, _) async => true,
        agentJobExecutor: (job) async {
          seen = job;
          return const DayAgentJobSucceeded(resultEntityId: 'parsed-1');
        },
      );
      await enqueueParse();

      final result = await processor.processNext(
        kinds: const {DayProcessingJobKind.parseCapture},
      );
      final saved = await repository.getById('parse_cap-1');

      expect(result, DayProcessingRunResult.succeeded);
      expect(seen!.kind, DayProcessingJobKind.parseCapture);
      expect(saved!.status, DayProcessingJobStatus.succeeded);
      expect(saved.resultEntityId, 'parsed-1');
    });

    test(
      'a deterministic agent-job failure surfaces as failed, not deferred',
      () async {
        final processor = DayProcessingOutboxProcessor(
          repository: repository,
          transcribe: (_) async => 'unused',
          attachTranscript: (_, _) async => true,
          agentJobExecutor: (job) async => const DayAgentJobFailed(
            failureClass: DayProcessingFailureClass.deterministic,
            error: 'ambiguous day resolution',
          ),
        );
        await enqueueParse();

        final result = await processor.processNext(
          kinds: const {DayProcessingJobKind.parseCapture},
        );
        final saved = await repository.getById('parse_cap-1');

        expect(result, DayProcessingRunResult.failed);
        expect(saved!.status, DayProcessingJobStatus.failed);
        expect(saved.lastError, 'ambiguous day resolution');
      },
    );

    test(
      'a retryable agent-job failure defers and preserves attempts',
      () async {
        final processor = DayProcessingOutboxProcessor(
          repository: repository,
          transcribe: (_) async => 'unused',
          attachTranscript: (_, _) async => true,
          agentJobExecutor: (job) async => const DayAgentJobFailed(
            failureClass: DayProcessingFailureClass.providerBusy,
            error: 'missing tool call',
          ),
        );
        await enqueueParse();

        final result = await processor.processNext(
          kinds: const {DayProcessingJobKind.parseCapture},
        );
        final saved = await repository.getById('parse_cap-1');

        expect(result, DayProcessingRunResult.deferred);
        expect(saved!.status, DayProcessingJobStatus.queued);
      },
    );

    test(
      'no registered executor fails the job instead of hanging silently',
      () async {
        final processor = DayProcessingOutboxProcessor(
          repository: repository,
          transcribe: (_) async => 'unused',
          attachTranscript: (_, _) async => true,
        );
        await enqueueParse();

        final result = await processor.processNext(
          kinds: const {DayProcessingJobKind.parseCapture},
        );
        final saved = await repository.getById('parse_cap-1');

        expect(result, DayProcessingRunResult.failed);
        expect(saved!.lastError, contains('No agent-job executor'));
      },
    );

    test(
      'a claim revoked mid-flight defers the agent job like transcription',
      () async {
        final processor = DayProcessingOutboxProcessor(
          repository: repository,
          transcribe: (_) async => 'unused',
          attachTranscript: (_, _) async => true,
          agentJobExecutor: (job) async {
            // Simulate the job being terminalized by another actor before
            // this attempt reports back.
            await repository.cancel(job.id);
            throw StateError('unexpected');
          },
        );
        await enqueueParse();

        final result = await processor.processNext(
          kinds: const {DayProcessingJobKind.parseCapture},
        );

        expect(result, DayProcessingRunResult.deferred);
      },
    );

    test(
      'an agent executor that throws (not a claim-revoked error) marks the '
      'job failed via the classified failure class',
      () async {
        final finished = <DayProcessingJob>[];
        final processor = DayProcessingOutboxProcessor(
          repository: repository,
          transcribe: (_) async => 'unused',
          attachTranscript: (_, _) async => true,
          onJobFinished: finished.add,
          agentJobExecutor: (job) async =>
              throw StateError('ambiguous day resolution'),
        );
        await enqueueParse();

        final result = await processor.processNext(
          kinds: const {DayProcessingJobKind.parseCapture},
        );

        // classifyDayAgentJobFailure maps "ambiguous" to `deterministic`,
        // which _processAgentJob's catch handler turns into `failed`.
        expect(result, DayProcessingRunResult.failed);
        final saved = await repository.getById('parse_cap-1');
        expect(saved!.status, DayProcessingJobStatus.failed);
        expect(saved.lastError, contains('ambiguous day resolution'));
        // `failed` is not one of DayProcessingJob.isTerminal's two statuses
        // (succeeded/cancelled), so _finished's onJobFinished gate stays
        // closed here — this only proves _finished(failed) was reached.
        expect(finished, isEmpty);
      },
    );

    test(
      'a thrown setupRequired-classified error also fails (not just '
      'deterministic)',
      () async {
        final processor = DayProcessingOutboxProcessor(
          repository: repository,
          transcribe: (_) async => 'unused',
          attachTranscript: (_, _) async => true,
          agentJobExecutor: (job) async =>
              throw StateError('provider not configured'),
        );
        await enqueueParse();

        final result = await processor.processNext(
          kinds: const {DayProcessingJobKind.parseCapture},
        );

        expect(result, DayProcessingRunResult.failed);
        final saved = await repository.getById('parse_cap-1');
        expect(
          saved!.lastFailureClass,
          DayProcessingFailureClass.setupRequired,
        );
      },
    );

    test('onJobFinished fires only for terminal outcomes', () async {
      final finished = <DayProcessingJob>[];
      final processor = DayProcessingOutboxProcessor(
        repository: repository,
        transcribe: (_) async => 'unused',
        attachTranscript: (_, _) async => true,
        onJobFinished: finished.add,
        agentJobExecutor: (job) async => const DayAgentJobFailed(
          failureClass: DayProcessingFailureClass.providerBusy,
          error: 'retryable',
        ),
      );
      await enqueueParse();

      await processor.processNext(
        kinds: const {DayProcessingJobKind.parseCapture},
      );

      // A deferred (non-terminal) outcome must not fire onJobFinished.
      expect(finished, isEmpty);
    });

    test(
      'two independent kind lanes drain without one blocking the other',
      () async {
        final agentCalls = <String>[];
        final processor = DayProcessingOutboxProcessor(
          repository: repository,
          transcribe: (_) async => 'Gym first, then the proposal.',
          attachTranscript: (_, _) async => true,
          agentJobExecutor: (job) async {
            agentCalls.add(job.id);
            return const DayAgentJobSucceeded();
          },
        );
        await enqueueParse();

        final counts = await Future.wait([
          processor.drain(
            kinds: const {DayProcessingJobKind.transcribeAudio},
          ),
          processor.drain(kinds: const {DayProcessingJobKind.parseCapture}),
        ]);

        expect(counts[0], 1);
        expect(counts[1], 1);
        expect(agentCalls, ['parse_cap-1']);
        expect(
          (await repository.getById('transcribe_session-1'))!.status,
          DayProcessingJobStatus.succeeded,
        );
        expect(
          (await repository.getById('parse_cap-1'))!.status,
          DayProcessingJobStatus.succeeded,
        );
      },
    );
  });
}
