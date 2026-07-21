import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/day_audio_context.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/daily_os_next/services/day_activity_repository.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_outbox_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../agents/test_data/entity_factories.dart';

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
      rootDirectory: Directory('${root.path}/outbox'),
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
        activityEntryId: 'reviewed',
        audio: reviewed,
      ).transcript,
      'Reviewed text',
    );
    expect(
      DayActivityEntry(
        id: 'receipt',
        kind: DayActivityEntryKind.recording,
        createdAt: capturedAt,
        activityEntryId: 'receipt',
        audio: receipt,
      ).transcript,
      'Receipt text',
    );
    expect(
      DayActivityEntry(
        id: 'empty',
        kind: DayActivityEntryKind.recording,
        createdAt: capturedAt,
        activityEntryId: 'empty',
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
          activityEntryId: 'asset-$expected',
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

    expect(entries.map((entry) => entry.activityEntryId), [
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
      entries.map((entry) => entry.activityEntryId),
      ['still-pending'],
    );
  });
}
