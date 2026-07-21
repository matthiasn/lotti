import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/day_audio_context.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/daily_os_next/services/day_audio_review_fence.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_job.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_outbox_repository.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as path;

import '../../../mocks/mocks.dart';

void main() {
  final now = DateTime.utc(2026, 7, 18, 8);
  late Directory root;
  late DayProcessingOutboxRepository repository;
  late MockJournalDb journalDb;
  late StreamController<Set<String>> updates;
  late DayAudioReviewFence fence;

  setUp(() async {
    root = Directory.systemTemp.createTempSync('day-review-fence-');
    repository = DayProcessingOutboxRepository(
      rootDirectory: Directory(path.join(root.path, 'outbox')),
      now: () => now,
      tokenFactory: () => 'claim-token',
    );
    journalDb = MockJournalDb();
    updates = StreamController<Set<String>>.broadcast(sync: true);
    fence = DayAudioReviewFence(
      updates: updates.stream,
      outbox: repository,
      journalDb: journalDb,
    );
  });

  tearDown(() async {
    await fence.dispose();
    await updates.close();
    await repository.dispose();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  Future<DayProcessingJob> enqueue({String session = 'session-1'}) =>
      repository.enqueueTranscription(
        dayId: 'dayplan-2026-07-18',
        activityEntryId: 'activity-$session',
        recordingSessionId: session,
        audioId: 'audio-$session',
        audioPath: path.join(root.path, '$session.m4a'),
        capturedAt: now,
      );

  JournalAudio audio({
    String session = 'session-1',
    String? processingJobId,
    String? entryText,
    List<AudioTranscript>? transcripts,
    DateTime? deletedAt,
    bool dayContext = true,
  }) => JournalAudio(
    meta: Metadata(
      id: 'audio-$session',
      createdAt: now,
      updatedAt: now,
      dateFrom: now,
      dateTo: now.add(const Duration(minutes: 1)),
      deletedAt: deletedAt,
    ),
    data: AudioData(
      dateFrom: now,
      dateTo: now.add(const Duration(minutes: 1)),
      audioFile: '$session.m4a',
      audioDirectory: '/audio/',
      duration: const Duration(minutes: 1),
      transcripts: transcripts,
      dayContext: dayContext
          ? DayAudioContext(
              dayId: 'dayplan-2026-07-18',
              planDate: DateTime.utc(2026, 7, 18),
              recordingSessionId: session,
              activityEntryId: 'activity-$session',
              processingJobId: processingJobId ?? 'transcribe_$session',
              capturedAt: now,
              intent: 'dayPlan',
            )
          : null,
    ),
    entryText: entryText == null
        ? null
        : EntryText(plainText: entryText, markdown: entryText),
  );

  test(
    'startup sweep satisfies a pending job with user-reviewed text',
    () async {
      final job = await enqueue();
      when(
        () => journalDb.journalEntityById('audio-session-1'),
      ).thenAnswer((_) async => audio(entryText: ' Reviewed wording. '));

      fence.start();
      await fence.checkNow();

      final saved = await repository.getById(job.id);
      expect(saved!.status, DayProcessingJobStatus.succeeded);
      expect(saved.resultTranscript, 'Reviewed wording.');
    },
  );

  test('audio update notifications trigger the sweep, others do not', () async {
    final job = await enqueue();
    var reviewed = false;
    var lookups = 0;
    when(() => journalDb.journalEntityById('audio-session-1')).thenAnswer((
      _,
    ) async {
      lookups += 1;
      return audio(entryText: reviewed ? 'Reviewed wording' : null);
    });

    fence.start();
    await fence.checkNow();
    final afterStart = lookups;
    expect(
      (await repository.getById(job.id))!.status,
      DayProcessingJobStatus.queued,
    );

    reviewed = true;
    updates.add(const {'unrelated-id', taskNotification});
    await fence.checkNow();
    // The final checkNow always sweeps once; the unrelated notification must
    // not have scheduled a sweep of its own.
    expect(lookups, afterStart + 1);
    expect(
      (await repository.getById(job.id))!.status,
      DayProcessingJobStatus.succeeded,
    );
  });

  test(
    'a notification-driven sweep satisfies without manual pumping',
    () async {
      final job = await enqueue();
      when(
        () => journalDb.journalEntityById('audio-session-1'),
      ).thenAnswer((_) async => audio(entryText: 'Reviewed wording'));

      fence.start();
      updates.add(const {'audio-session-1', audioNotification});
      // Serialized tail: awaiting a fresh sweep completes strictly after every
      // sweep the notifications enqueued.
      await fence.checkNow();

      final saved = await repository.getById(job.id);
      expect(saved!.status, DayProcessingJobStatus.succeeded);
      expect(saved.resultTranscript, 'Reviewed wording');
    },
  );

  test('a failed sweep does not break later sweeps', () async {
    final job = await enqueue();
    var lookups = 0;
    when(() => journalDb.journalEntityById('audio-session-1')).thenAnswer((
      _,
    ) async {
      lookups += 1;
      if (lookups == 1) throw StateError('database unavailable');
      return audio(entryText: 'Reviewed wording');
    });

    fence.start();
    updates.add(const {audioNotification});
    await fence.checkNow();

    expect(
      (await repository.getById(job.id))!.status,
      DayProcessingJobStatus.succeeded,
    );
  });

  test('leaves jobs alone without reviewed text or matching context', () async {
    final terminalJob = await enqueue();
    await repository.cancel(terminalJob.id);
    final noEntity = await enqueue(session: 'session-2');
    final deleted = await enqueue(session: 'session-3');
    final foreignContext = await enqueue(session: 'session-4');
    final noContext = await enqueue(session: 'session-5');
    final machineText = await enqueue(session: 'session-6');

    when(
      () => journalDb.journalEntityById(any()),
    ).thenAnswer((_) async => null);
    when(() => journalDb.journalEntityById('audio-session-3')).thenAnswer(
      (_) async =>
          audio(session: 'session-3', entryText: 'Edited', deletedAt: now),
    );
    when(() => journalDb.journalEntityById('audio-session-4')).thenAnswer(
      (_) async => audio(
        session: 'session-4',
        entryText: 'Edited',
        processingJobId: 'transcribe_other-session',
      ),
    );
    when(() => journalDb.journalEntityById('audio-session-5')).thenAnswer(
      (_) async =>
          audio(session: 'session-5', entryText: 'Edited', dayContext: false),
    );
    when(() => journalDb.journalEntityById('audio-session-6')).thenAnswer(
      (_) async => audio(
        session: 'session-6',
        entryText: 'Machine words',
        transcripts: [
          AudioTranscript(
            created: now,
            library: 'daily-os-outbox',
            model: 'configured-audio-model',
            detectedLanguage: '-',
            transcript: 'Machine words',
            processingJobId: 'earlier-job',
          ),
        ],
      ),
    );

    await fence.checkNow();

    // The cancelled job is never looked up at all.
    verifyNever(() => journalDb.journalEntityById('audio-session-1'));
    for (final job in [noEntity, deleted, foreignContext, noContext]) {
      expect(
        (await repository.getById(job.id))!.status,
        DayProcessingJobStatus.queued,
        reason: job.id,
      );
    }
    expect(
      (await repository.getById(machineText.id))!.status,
      DayProcessingJobStatus.queued,
    );
    expect(
      (await repository.getById(terminalJob.id))!.status,
      DayProcessingJobStatus.cancelled,
    );
  });

  test(
    'dispose stops reacting to notifications and start is idempotent',
    () async {
      await enqueue();
      var lookups = 0;
      when(() => journalDb.journalEntityById('audio-session-1')).thenAnswer((
        _,
      ) async {
        lookups += 1;
        return audio();
      });

      fence
        ..start()
        ..start();
      await fence.checkNow();
      // A single subscription and a single startup sweep, plus the awaited
      // checkNow above.
      expect(lookups, 2);

      await fence.dispose();
      updates.add(const {audioNotification});
      await fence.checkNow();
      expect(lookups, 3);
    },
  );
}
