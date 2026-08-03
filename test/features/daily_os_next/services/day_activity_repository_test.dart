import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/day_audio_context.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/daily_os_next/services/day_activity_repository.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_job.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_outbox_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../agents/test_data/entity_factories.dart';
import 'day_processing_test_db.dart';

void main() {
  final capturedAt = DateTime(2026, 7, 18, 8);
  const dayId = 'dayplan-2026-07-18';
  late Directory root;
  late MockJournalDb journalDb;
  late DayProcessingOutboxRepository outbox;
  late DayActivityRepository repository;

  JournalAudio audio({
    required String id,
    required String activityId,
    required String sessionId,
    String? transcript,
  }) => JournalAudio(
    meta: Metadata(
      id: id,
      createdAt: capturedAt,
      updatedAt: capturedAt,
      dateFrom: capturedAt,
      dateTo: capturedAt.add(const Duration(minutes: 1)),
    ),
    data: AudioData(
      dateFrom: capturedAt,
      dateTo: capturedAt.add(const Duration(minutes: 1)),
      audioFile: '$id.wav',
      audioDirectory: '/audio/',
      duration: const Duration(minutes: 1),
      dayContext: DayAudioContext(
        dayId: dayId,
        planDate: DateTime(2026, 7, 18),
        recordingSessionId: sessionId,
        activityEntryId: activityId,
        processingJobId: 'transcribe_$sessionId',
        capturedAt: capturedAt,
        intent: 'dayPlan',
      ),
      transcripts: transcript == null
          ? null
          : [
              AudioTranscript(
                created: capturedAt,
                library: 'test',
                model: 'test',
                detectedLanguage: 'en',
                transcript: transcript,
                processingJobId: 'transcribe_$sessionId',
              ),
            ],
    ),
  );

  setUp(() {
    root = Directory.systemTemp.createTempSync('day-activity-test-');
    journalDb = MockJournalDb();
    outbox = DayProcessingOutboxRepository(
      db: createTestDayProcessingDb(),
      now: () => capturedAt,
    );
    repository = DayActivityRepository(
      journalDb: journalDb,
      outbox: outbox,
      assetRoot: root,
    );
  });

  tearDown(() async {
    await outbox.dispose();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  test(
    'coalesces journal, outbox, and submitted capture by activity id',
    () async {
      final saved = audio(
        id: 'audio-1',
        activityId: 'activity-1',
        sessionId: 'session-1',
        transcript: 'Gym check-in',
      );
      when(
        () => journalDb.getDayAudioEntries(dayId),
      ).thenAnswer((_) async => [saved]);
      await outbox.enqueueTranscription(
        dayId: dayId,
        activityEntryId: 'activity-1',
        recordingSessionId: 'session-1',
        audioId: 'audio-1',
        audioPath: '${root.path}/audio-1.wav',
        capturedAt: capturedAt,
      );
      final capture =
          AgentDomainEntity.capture(
                id: 'capture-1',
                agentId: 'planner',
                transcript: 'Gym check-in',
                capturedAt: capturedAt,
                createdAt: capturedAt,
                vectorClock: null,
                dayId: dayId,
                audioRef: 'audio-1',
              )
              as CaptureEntity;

      final entries = await repository.load(dayId: dayId, captures: [capture]);

      expect(entries, hasLength(1));
      expect(entries.single.audio, same(saved));
      expect(entries.single.processingJob?.id, 'transcribe_session-1');
      expect(entries.single.capture, same(capture));
      expect(entries.single.transcript, 'Gym check-in');
      expect(entries.single.isSubmitted, isTrue);
    },
  );

  test(
    'includes typed and unresolved-audio check-ins chronologically',
    () async {
      when(
        () => journalDb.getDayAudioEntries(dayId),
      ).thenAnswer((_) async => []);
      final typed =
          AgentDomainEntity.capture(
                id: 'capture-typed',
                agentId: 'planner',
                transcript: 'Typed at the gym',
                capturedAt: capturedAt,
                createdAt: capturedAt,
                vectorClock: null,
                dayId: dayId,
              )
              as CaptureEntity;
      final unresolvedAudio =
          AgentDomainEntity.capture(
                id: 'capture-audio',
                agentId: 'planner',
                transcript: 'Audio submitted elsewhere',
                capturedAt: capturedAt.add(const Duration(minutes: 2)),
                createdAt: capturedAt.add(const Duration(minutes: 2)),
                vectorClock: null,
                dayId: dayId,
                audioRef: 'missing-audio',
              )
              as CaptureEntity;

      final entries = await repository.load(
        dayId: dayId,
        captures: [unresolvedAudio, typed],
      );

      expect(
        entries.map((entry) => entry.id),
        ['capture-typed', 'capture-audio'],
      );
      expect(
        entries.map((entry) => entry.kind),
        everyElement(DayActivityEntryKind.checkIn),
      );
    },
  );

  test('includes the generated plan in chronological activity', () async {
    when(
      () => journalDb.getDayAudioEntries(dayId),
    ).thenAnswer((_) async => []);
    final plan = makeTestDayPlan(
      dayId: dayId,
      planDate: capturedAt,
      createdAt: capturedAt,
    );

    final entries = await repository.load(dayId: dayId, plan: plan);

    expect(entries, hasLength(1));
    expect(entries.single.kind, DayActivityEntryKind.plan);
    expect(entries.single.plan, same(plan));
    expect(entries.single.createdAt, capturedAt);
  });

  test('includes the planner-authored day summary', () async {
    when(
      () => journalDb.getDayAudioEntries(dayId),
    ).thenAnswer((_) async => []);
    final summary =
        AgentDomainEntity.daySummary(
              id: 'summary-1',
              agentId: 'planner',
              dayId: dayId,
              text: 'You protected the focus block and moved training later.',
              createdAt: capturedAt,
              updatedAt: capturedAt,
              vectorClock: null,
            )
            as DaySummaryEntity;

    final entries = await repository.load(dayId: dayId, summaries: [summary]);

    expect(entries, hasLength(1));
    expect(entries.single.kind, DayActivityEntryKind.summary);
    expect(entries.single.summary, same(summary));
  });

  test('projects reviewed text, receipt fallback, and local asset state', () {
    final reviewed =
        audio(
          id: 'reviewed',
          activityId: 'reviewed',
          sessionId: 'reviewed',
          transcript: 'Provider text',
        ).copyWith(
          entryText: const EntryText(
            plainText: '  Reviewed text  ',
            markdown: 'Reviewed text',
          ),
        );
    final receipt = audio(
      id: 'receipt',
      activityId: 'receipt',
      sessionId: 'receipt',
      transcript: '  Receipt text  ',
    );
    final emptyReceipt = audio(
      id: 'empty',
      activityId: 'empty',
      sessionId: 'empty',
      transcript: '   ',
    );
    final local = File('${root.path}/local.wav')..writeAsBytesSync([0]);

    expect(
      DayActivityEntry(
        id: 'reviewed',
        kind: DayActivityEntryKind.recording,
        createdAt: capturedAt,
        audio: reviewed,
      ).transcript,
      'Reviewed text',
    );
    expect(
      DayActivityEntry(
        id: 'receipt',
        kind: DayActivityEntryKind.recording,
        createdAt: capturedAt,
        audio: receipt,
      ).transcript,
      'Receipt text',
    );
    expect(
      DayActivityEntry(
        id: 'empty',
        kind: DayActivityEntryKind.recording,
        createdAt: capturedAt,
        audio: emptyReceipt,
      ).transcript,
      isNull,
    );
    for (final (audioPath, expected) in <(String?, bool?)>[
      (null, null),
      (local.path, true),
      ('${root.path}/missing.wav', false),
    ]) {
      expect(
        DayActivityEntry(
          id: 'asset-$expected',
          kind: DayActivityEntryKind.recording,
          createdAt: capturedAt,
          audioPath: audioPath,
        ).audioAvailableLocally,
        expected,
      );
    }
  });

  test('combines indexed day audio with outbox-only recordings', () async {
    final saved = audio(
      id: 'saved',
      activityId: 'saved',
      sessionId: 'saved',
    );
    when(
      () => journalDb.getDayAudioEntries(dayId),
    ).thenAnswer((_) async => [saved]);
    await outbox.enqueueTranscription(
      dayId: dayId,
      activityEntryId: 'outbox-only',
      recordingSessionId: 'outbox-only',
      audioId: 'outbox-only',
      audioPath: '${root.path}/outbox-only.wav',
      capturedAt: capturedAt.add(const Duration(minutes: 1)),
    );

    final entries = await repository.load(dayId: dayId);

    expect(entries.map((entry) => entry.id), [
      'saved',
      'outbox-only',
    ]);
    expect(entries.last.audio, isNull);
    expect(entries.last.audioPath, '${root.path}/outbox-only.wav');
    expect(
      entries.last.createdAt,
      (await outbox.getById('transcribe_outbox-only'))!.createdAt,
    );
  });

  test('terminal ledger jobs do not resurrect deleted recordings', () async {
    // The recording rows were soft-deleted, so the indexed journal query no
    // longer returns them; only the outbox ledger remembers the jobs.
    when(
      () => journalDb.getDayAudioEntries(dayId),
    ).thenAnswer((_) async => const []);
    await outbox.enqueueTranscription(
      dayId: dayId,
      activityEntryId: 'deleted-pending',
      recordingSessionId: 'deleted-pending',
      audioId: 'deleted-pending',
      audioPath: '${root.path}/deleted-pending.wav',
      capturedAt: capturedAt,
    );
    await outbox.cancel('transcribe_deleted-pending');
    await outbox.enqueueTranscription(
      dayId: dayId,
      activityEntryId: 'deleted-transcribed',
      recordingSessionId: 'deleted-transcribed',
      audioId: 'deleted-transcribed',
      audioPath: '${root.path}/deleted-transcribed.wav',
      capturedAt: capturedAt,
    );
    await outbox.satisfyWithReviewedText(
      'transcribe_deleted-transcribed',
      'Transcribed before deletion',
    );
    // Pending work without a journal row (e.g. mid-delete crash window)
    // must still surface so the user can retry or delete it.
    await outbox.enqueueTranscription(
      dayId: dayId,
      activityEntryId: 'still-pending',
      recordingSessionId: 'still-pending',
      audioId: 'still-pending',
      audioPath: '${root.path}/still-pending.wav',
      capturedAt: capturedAt,
    );

    final entries = await repository.load(dayId: dayId);

    expect(
      entries.map((entry) => entry.id),
      ['still-pending'],
    );
  });

  group('stalled agent jobs', () {
    setUp(() {
      when(() => journalDb.getDayAudioEntries(dayId)).thenAnswer(
        (_) async => const <JournalAudio>[],
      );
    });

    Future<DayProcessingJob> failDraft({
      DayProcessingFailureClass failureClass =
          DayProcessingFailureClass.deterministic,
      String error = 'the model returned no plan',
    }) async {
      await outbox.enqueueDraftPlan(
        dayId: dayId,
        // ignore: avoid_redundant_argument_values
        payload: const DraftPlanPayload(decidedTaskIds: []),
      );
      final claim = await outbox.claimNext();
      return outbox.markFailure(
        jobId: claim!.job.id,
        claimToken: claim.token,
        failureClass: failureClass,
        error: error,
      );
    }

    test(
      'a failed draft earns its own row, keyed by the durable job id',
      () async {
        final failed = await failDraft();

        final entries = await repository.load(dayId: dayId);

        final row = entries.single;
        expect(row.kind, DayActivityEntryKind.agentJob);
        expect(
          row.id,
          'draft_$dayId',
          reason:
              'Agent jobs carry no activityEntryId; the deterministic job id is '
              'the join key, so retries update one row instead of adding cards.',
        );
        expect(row.processingJob?.status, DayProcessingJobStatus.failed);
        expect(
          row.processingJob?.lastError,
          'the model returned no plan',
          reason: 'The card explains what failed from the durable record.',
        );
        expect(
          row.createdAt.isAtSameMomentAs(failed.updatedAt),
          isTrue,
          reason: 'The row sits where the failure happened in the day.',
        );
      },
    );

    test('a retried job stops earning a row', () async {
      await failDraft();

      await outbox.retryNow('draft_$dayId');

      expect(
        await repository.load(dayId: dayId),
        isEmpty,
        reason:
            'retryNow re-queues the job; in-flight work belongs to the plan '
            "surface's progress affordance, not to a failure card.",
      );
    });

    test(
      'an offline draft surfaces as waiting rather than silently parked',
      () async {
        await failDraft(failureClass: DayProcessingFailureClass.network);

        final row = (await repository.load(dayId: dayId)).single;

        expect(
          row.processingJob?.status,
          DayProcessingJobStatus.waitingForNetwork,
        );
      },
    );

    test('a parse failure for a deleted capture stops being offered', () async {
      await outbox.enqueueParseCapture(dayId: dayId, captureId: 'capture-1');
      final claim = await outbox.claimNext();
      await outbox.markFailure(
        jobId: claim!.job.id,
        claimToken: claim.token,
        failureClass: DayProcessingFailureClass.deterministic,
        error: 'could not read it',
      );
      final deleted =
          AgentDomainEntity.capture(
                id: 'capture-1',
                agentId: 'planner',
                transcript: 'gone',
                capturedAt: capturedAt,
                createdAt: capturedAt,
                vectorClock: null,
                dayId: dayId,
                deletedAt: capturedAt,
              )
              as CaptureEntity;

      expect(
        await repository.load(dayId: dayId, captures: [deleted]),
        isEmpty,
        reason:
            'The intent no longer exists — nothing reschedules it, and Retry '
            'would only run a pre-check that terminates on its own.',
      );
    });

    test(
      'a parse failure stops being offered once parsing completes',
      () async {
        await outbox.enqueueParseCapture(dayId: dayId, captureId: 'capture-1');
        final claim = await outbox.claimNext();
        await outbox.markFailure(
          jobId: claim!.job.id,
          claimToken: claim.token,
          failureClass: DayProcessingFailureClass.deterministic,
          error: 'could not read it',
        );
        // A peer parsed it and synced the result; the local job row stays
        // `failed` forever because nothing reschedules a failed job.
        final parsed =
            AgentDomainEntity.capture(
                  id: 'capture-1',
                  agentId: 'planner',
                  transcript: 'read elsewhere',
                  capturedAt: capturedAt,
                  createdAt: capturedAt,
                  vectorClock: null,
                  dayId: dayId,
                  parseCompletedAt: capturedAt,
                )
                as CaptureEntity;

        final entries = await repository.load(
          dayId: dayId,
          captures: [parsed],
        );

        expect(
          entries.map((e) => e.kind),
          [DayActivityEntryKind.checkIn],
          reason:
              'The check-in itself still belongs on the day; only the stale '
              'failure row goes. Offering Retry for work already done sends '
              'the user to spend a model request re-deriving what exists.',
        );
      },
    );

    test('a succeeded agent job leaves no trace in Activity', () async {
      await outbox.enqueueParseCapture(dayId: dayId, captureId: 'capture-1');
      final claim = await outbox.claimNext();
      await outbox.markSucceeded(
        jobId: claim!.job.id,
        claimToken: claim.token,
      );

      expect(await repository.load(dayId: dayId), isEmpty);
    });

    test('agent rows interleave with the rest of the day by time', () async {
      await failDraft();
      final summary = makeTestDaySummary(
        dayId: dayId,
        agentId: 'daily_os_planner',
        text: 'a note from earlier',
        createdAt: capturedAt.subtract(const Duration(hours: 1)),
      );

      final entries = await repository.load(dayId: dayId, summaries: [summary]);

      expect(
        entries.map((e) => e.kind),
        [DayActivityEntryKind.summary, DayActivityEntryKind.agentJob],
        reason: 'One chronological narrative, not a separate failures list.',
      );
    });
  });
}
