import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_job.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_outbox_repository.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

void main() {
  late Directory root;
  late DateTime now;
  late DayProcessingOutboxRepository repository;
  var tokenCounter = 0;

  setUp(() {
    root = Directory.systemTemp.createTempSync('day-processing-outbox-test-');
    now = DateTime.utc(2026, 7, 18, 7, 42);
    tokenCounter = 0;
    repository = DayProcessingOutboxRepository(
      rootDirectory: root,
      now: () => now,
      tokenFactory: () => 'claim-${++tokenCounter}',
    );
  });

  tearDown(() async {
    await repository.dispose();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  Future<DayProcessingJob> enqueue() => repository.enqueueTranscription(
    dayId: 'dayplan-2026-07-18',
    activityEntryId: 'activity-1',
    recordingSessionId: 'session-1',
    audioId: 'audio-1',
    audioPath: path.join(root.path, 'audio.wav'),
    capturedAt: DateTime.utc(2026, 7, 18, 7, 40),
  );

  test('enqueue is durable across repository restart and idempotent', () async {
    final first = await enqueue();
    final duplicate = await enqueue();
    await repository.dispose();
    repository = DayProcessingOutboxRepository(
      rootDirectory: root,
      now: () => now,
      tokenFactory: () => 'restart-claim',
    );

    final restored = await repository.getAll();

    expect(duplicate.id, first.id);
    expect(restored, hasLength(1));
    expect(restored.single.id, 'transcribe_session-1');
    expect(restored.single.audioId, 'audio-1');
    expect(restored.single.status, DayProcessingJobStatus.queued);
  });

  test(
    'deterministic job reuse rejects conflicting immutable intent',
    () async {
      await enqueue();

      final conflict = repository.enqueueTranscription(
        dayId: 'dayplan-2026-07-19',
        activityEntryId: 'activity-1',
        recordingSessionId: 'session-1',
        audioId: 'audio-1',
        audioPath: path.join(root.path, 'audio.wav'),
        capturedAt: DateTime.utc(2026, 7, 18, 7, 40),
      );
      await expectLater(conflict, throwsA(isA<DayProcessingIntentConflict>()));
      await conflict.catchError((Object error) {
        expect(
          error.toString(),
          contains('immutable fields differ for transcribe_session-1'),
        );
        return enqueue();
      });
      expect((await repository.getAll()).single.dayId, 'dayplan-2026-07-18');
    },
  );

  test('default claim tokens are UUIDs', () async {
    await repository.dispose();
    repository = DayProcessingOutboxRepository(
      rootDirectory: root,
      now: () => now,
    );

    await enqueue();
    final claim = await repository.claimNext();

    expect(claim, isNotNull);
    expect(Uuid.isValidUUID(fromString: claim!.token), isTrue);
  });

  test('interactive enqueue validates an existing immutable intent', () async {
    await enqueue();

    final claim = await repository.enqueueAndClaimTranscription(
      dayId: 'dayplan-2026-07-18',
      activityEntryId: 'activity-1',
      recordingSessionId: 'session-1',
      audioId: 'audio-1',
      audioPath: path.join(root.path, 'audio.wav'),
      capturedAt: DateTime.utc(2026, 7, 18, 7, 40),
    );

    expect(claim?.job.id, 'transcribe_session-1');
    expect(claim?.token, 'claim-1');
  });

  test(
    'repair restores missing pending and completed intents idempotently',
    () async {
      final pending = await repository.restoreTranscriptionIntent(
        dayId: 'dayplan-2026-07-18',
        activityEntryId: 'activity-repaired',
        recordingSessionId: 'session-repaired',
        audioId: 'audio-repaired',
        audioPath: path.join(root.path, 'repaired.wav'),
        capturedAt: now,
      );
      final completed = await repository.restoreTranscriptionIntent(
        dayId: 'dayplan-2026-07-18',
        activityEntryId: 'activity-complete',
        recordingSessionId: 'session-complete',
        audioId: 'audio-complete',
        audioPath: path.join(root.path, 'complete.wav'),
        capturedAt: now,
        completedTranscript: 'Already transcribed',
      );
      final duplicate = await repository.restoreTranscriptionIntent(
        dayId: 'dayplan-2026-07-18',
        activityEntryId: 'activity-repaired',
        recordingSessionId: 'session-repaired',
        audioId: 'audio-repaired',
        audioPath: path.join(root.path, 'repaired.wav'),
        capturedAt: now,
      );

      expect(pending, isTrue);
      expect(completed, isTrue);
      expect(duplicate, isFalse);
      expect(
        (await repository.getById('transcribe_session-repaired'))!.status,
        DayProcessingJobStatus.queued,
      );
      final receipt = await repository.getById('transcribe_session-complete');
      expect(receipt!.status, DayProcessingJobStatus.succeeded);
      expect(receipt.resultTranscript, 'Already transcribed');
    },
  );

  test('repair receipt upgrades an existing pending intent', () async {
    await enqueue();

    final restored = await repository.restoreTranscriptionIntent(
      dayId: 'dayplan-2026-07-18',
      activityEntryId: 'activity-1',
      recordingSessionId: 'session-1',
      audioId: 'audio-1',
      audioPath: path.join(root.path, 'audio.wav'),
      capturedAt: DateTime.utc(2026, 7, 18, 7, 40),
      completedTranscript: 'Receipt survived elsewhere',
    );

    final job = await repository.getById('transcribe_session-1');
    expect(restored, isTrue);
    expect(job!.status, DayProcessingJobStatus.succeeded);
    expect(job.resultTranscript, 'Receipt survived elsewhere');
  });

  test('claim uses a lease and fenced completion', () async {
    await enqueue();

    final claim = await repository.claimNext();
    final completed = await repository.markSucceeded(
      jobId: claim!.job.id,
      claimToken: claim.token,
    );

    expect(claim.token, 'claim-1');
    expect(claim.job.leaseUntil, now.add(const Duration(minutes: 3)));
    expect(completed.status, DayProcessingJobStatus.succeeded);
    expect(completed.completedAt, now);
    expect(completed.claimToken, isNull);
    await expectLater(
      repository.markSucceeded(
        jobId: completed.id,
        claimToken: claim.token,
      ),
      throwsStateError,
    );
  });

  test('interactive claim targets the requested immutable job', () async {
    await enqueue();

    final missing = await repository.claimById('missing-job');
    final claim = await repository.claimById('transcribe_session-1');

    expect(missing, isNull);
    expect(claim!.job.id, 'transcribe_session-1');
    expect(claim.token, 'claim-1');
    expect(await repository.claimById(claim.job.id), isNull);
  });

  test('provider output is durable before journal completion', () async {
    await enqueue();
    final claim = await repository.claimNext();

    final ready = await repository.markTranscriptReady(
      jobId: claim!.job.id,
      claimToken: claim.token,
      transcript: '  Gym first, then the proposal.  ',
    );
    await repository.markFailure(
      jobId: ready.id,
      claimToken: claim.token,
      failureClass: DayProcessingFailureClass.local,
      error: 'database busy',
    );

    await repository.dispose();
    repository = DayProcessingOutboxRepository(
      rootDirectory: root,
      now: () => now,
    );
    final restored = await repository.getById(ready.id);
    expect(restored!.resultTranscript, 'Gym first, then the proposal.');
    expect(restored.attempts, 1);
  });

  test('rejects blank output and unknown claimed jobs', () async {
    await enqueue();
    final claim = await repository.claimNext();

    await expectLater(
      repository.markTranscriptReady(
        jobId: claim!.job.id,
        claimToken: claim.token,
        transcript: '   ',
      ),
      throwsArgumentError,
    );
    await expectLater(
      repository.markSucceeded(
        jobId: 'missing-job',
        claimToken: claim.token,
      ),
      throwsStateError,
    );
  });

  test('reviewed text satisfies pending inference work', () async {
    await enqueue();

    final satisfied = await repository.satisfyWithReviewedText(
      'transcribe_session-1',
      '  User-reviewed text ',
    );

    expect(satisfied!.status, DayProcessingJobStatus.succeeded);
    expect(satisfied.resultTranscript, 'User-reviewed text');
    expect(await repository.claimNext(), isNull);
  });

  test('expired running work is reclaimed with a new token', () async {
    await enqueue();
    final first = await repository.claimNext();
    now = now.add(const Duration(minutes: 4));

    final reclaimed = await repository.claimNext();

    expect(first, isNotNull);
    expect(reclaimed, isNotNull);
    expect(reclaimed!.job.id, first!.job.id);
    expect(reclaimed.token, 'claim-2');
  });

  test(
    'offline failure preserves attempt count until connectivity returns',
    () async {
      await enqueue();
      final claim = await repository.claimNext();
      final waiting = await repository.markFailure(
        jobId: claim!.job.id,
        claimToken: claim.token,
        failureClass: DayProcessingFailureClass.network,
        error: 'offline',
      );

      expect(waiting.status, DayProcessingJobStatus.waitingForNetwork);
      expect(waiting.attempts, 0);

      now = now.add(const Duration(seconds: 1));
      await repository.signalConnectivityRestored();
      final retried = await repository.getById(waiting.id);
      expect(retried!.status, DayProcessingJobStatus.queued);
      expect(retried.nextAttemptAt, now);
    },
  );

  test('provider request increments attempts and honors Retry-After', () async {
    await enqueue();
    final claim = await repository.claimNext();
    final busy = await repository.markFailure(
      jobId: claim!.job.id,
      claimToken: claim.token,
      failureClass: DayProcessingFailureClass.providerBusy,
      error: 'HTTP 429',
      retryAfter: const Duration(minutes: 2),
    );

    expect(busy.status, DayProcessingJobStatus.queued);
    expect(busy.attempts, 1);
    expect(busy.retryNotBefore, now.add(const Duration(minutes: 2)));
    expect(await repository.claimNext(), isNull);

    now = now.add(const Duration(minutes: 2));
    expect(await repository.claimNext(), isNotNull);
  });

  test('orders ready work by due time and then stable job id', () async {
    await enqueue();
    final claim = await repository.claimNext();
    await repository.markFailure(
      jobId: claim!.job.id,
      claimToken: claim.token,
      failureClass: DayProcessingFailureClass.providerBusy,
      error: 'later',
      retryDelay: const Duration(minutes: 1),
    );
    for (final session in ['session-b', 'session-a']) {
      await repository.enqueueTranscription(
        dayId: 'dayplan-2026-07-18',
        activityEntryId: 'activity-$session',
        recordingSessionId: session,
        audioId: 'audio-$session',
        audioPath: path.join(root.path, '$session.wav'),
        capturedAt: now,
      );
    }

    expect((await repository.getAll()).map((job) => job.id), [
      'transcribe_session-1',
      'transcribe_session-a',
      'transcribe_session-b',
    ]);
    expect((await repository.claimNext())!.job.id, 'transcribe_session-a');
  });

  test('manual retry cannot bypass a hard provider boundary', () async {
    await enqueue();
    final claim = await repository.claimNext();
    final busy = await repository.markFailure(
      jobId: claim!.job.id,
      claimToken: claim.token,
      failureClass: DayProcessingFailureClass.providerBusy,
      error: 'busy',
      retryAfter: const Duration(minutes: 2),
    );

    final retried = await repository.retryNow(busy.id);

    expect(retried!.nextAttemptAt, now.add(const Duration(minutes: 2)));
    expect(await repository.claimNext(), isNull);
  });

  test('startup publishes a valid orphan partial job', () async {
    final job = await enqueue();
    final target = root.listSync().whereType<File>().single;
    final partial = File('${target.path}.part');
    await target.rename(partial.path);
    await repository.dispose();
    repository = DayProcessingOutboxRepository(
      rootDirectory: root,
      now: () => now,
    );

    final restored = await repository.getAll();

    expect(restored.single.id, job.id);
    expect(target.existsSync(), isTrue);
    expect(partial.existsSync(), isFalse);
  });

  test('startup removes a stale partial beside its published job', () async {
    await enqueue();
    final target = root.listSync().whereType<File>().single;
    final partial = File('${target.path}.part')
      ..writeAsBytesSync(target.readAsBytesSync());

    final jobs = await repository.getAll();

    expect(jobs, hasLength(1));
    expect(target.existsSync(), isTrue);
    expect(partial.existsSync(), isFalse);
  });

  test('startup quarantines a corrupt orphan partial', () async {
    File(
      path.join(root.path, 'corrupt.json.part'),
    ).writeAsStringSync('not an envelope');

    expect(await repository.getAll(), isEmpty);
    expect(
      File(
        path.join(root.path, 'quarantine', 'corrupt.json.part'),
      ).existsSync(),
      isTrue,
    );
  });

  test('lookup quarantines a corrupt job at its deterministic path', () async {
    await enqueue();
    final targetPath = root.listSync().whereType<File>().single.path;
    File(targetPath).writeAsStringSync('corrupt');

    expect(await repository.getById('transcribe_session-1'), isNull);
    expect(
      File(
        path.join(root.path, 'quarantine', path.basename(targetPath)),
      ).existsSync(),
      isTrue,
    );
  });

  test(
    'cancel terminalizes a pending job and no-ops on terminal ones',
    () async {
      final job = await enqueue();
      final cancelled = await repository.cancel(job.id);

      expect(cancelled!.status, DayProcessingJobStatus.cancelled);
      expect(cancelled.completedAt, isNotNull);
      expect(cancelled.isTerminal, isTrue);
      // A terminal job stays exactly as it is.
      final again = await repository.cancel(job.id);
      expect(again!.status, DayProcessingJobStatus.cancelled);
      expect(again.generation, cancelled.generation);
    },
  );

  test(
    'getAll skips and quarantines a corrupt job file',
    () async {
      await enqueue();
      final corrupt = File(path.join(root.path, 'corrupt.json'))
        ..writeAsStringSync('not an envelope');

      final jobs = await repository.getAll();

      expect(jobs.map((job) => job.id), ['transcribe_session-1']);
      expect(corrupt.existsSync(), isFalse);
      expect(
        File(path.join(root.path, 'quarantine', 'corrupt.json')).existsSync(),
        isTrue,
      );
    },
  );

  test(
    'corrupt jobs are quarantined instead of blocking healthy work',
    () async {
      await enqueue();
      final corruptPayload = jsonEncode(<String, Object?>{'id': 'bad'});
      final quarantine = Directory(path.join(root.path, 'quarantine'))
        ..createSync();
      final quarantined = File(path.join(quarantine.path, 'corrupt.json'))
        ..writeAsStringSync('stale quarantine entry');
      await File(path.join(root.path, 'corrupt.json')).writeAsString(
        jsonEncode(<String, Object?>{
          'payload': corruptPayload,
          'sha256': sha256.convert(utf8.encode('different')).toString(),
        }),
        flush: true,
      );

      final claim = await repository.claimNext();

      expect(claim?.job.id, 'transcribe_session-1');
      expect(quarantined.existsSync(), isTrue);
      final quarantinedEnvelope =
          jsonDecode(await quarantined.readAsString())! as Map<String, Object?>;
      expect(quarantinedEnvelope['payload'], corruptPayload);
    },
  );
}
