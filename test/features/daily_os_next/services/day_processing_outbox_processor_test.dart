import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/repository/transcription_exception.dart';
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

  test(
    'missing saved audio waits for recovery without a retry loop',
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
      expect(saved.status, DayProcessingJobStatus.waitingForUser);
      expect(saved.lastFailureClass, DayProcessingFailureClass.missingAsset);
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
    },
  );
}
