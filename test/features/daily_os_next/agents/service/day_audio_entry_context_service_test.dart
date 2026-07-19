import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/day_audio_context.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_audio_entry_context_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';

void main() {
  final capturedAt = DateTime(2026, 7, 18, 8);
  const dayId = 'dayplan-2026-07-18';
  late MockJournalDb journalDb;
  late DayAudioEntryContextService service;

  JournalAudio audio({
    required String id,
    required String entryDayId,
    required String processingJobId,
    String? transcript,
    String? receiptJobId,
  }) => JournalAudio(
    meta: Metadata(
      id: id,
      createdAt: capturedAt,
      updatedAt: capturedAt,
      dateFrom: capturedAt,
      dateTo: capturedAt,
    ),
    data: AudioData(
      dateFrom: capturedAt,
      dateTo: capturedAt,
      audioFile: '$id.wav',
      audioDirectory: '/audio/',
      duration: const Duration(minutes: 1),
      dayContext: DayAudioContext(
        dayId: entryDayId,
        planDate: capturedAt,
        recordingSessionId: 'session-$id',
        activityEntryId: 'activity-$id',
        processingJobId: processingJobId,
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
                processingJobId: receiptJobId,
              ),
            ],
    ),
  );

  setUp(() {
    journalDb = MockJournalDb();
    service = DayAudioEntryContextService(journalDb: journalDb);
  });

  test(
    'returns ready and pending persisted recordings for the requested day',
    () async {
      when(
        () => journalDb.getJournalEntities(
          types: const ['JournalAudio'],
          starredStatuses: const [true, false],
          privateStatuses: const [true, false],
          flaggedStatuses: const [1, 0],
          ids: null,
          limit: 64,
          // ignore: avoid_redundant_argument_values
          offset: 0,
        ),
      ).thenAnswer(
        (_) async => [
          audio(
            id: 'included',
            entryDayId: dayId,
            processingJobId: 'job-included',
            transcript: 'Remember the gym check-in.',
            receiptJobId: 'job-included',
          ),
          audio(
            id: 'uncorrelated',
            entryDayId: dayId,
            processingJobId: 'job-expected',
            transcript: 'Wrong receipt',
            receiptJobId: 'job-other',
          ),
          audio(
            id: 'other-day',
            entryDayId: 'dayplan-2026-07-19',
            processingJobId: 'job-other-day',
            transcript: 'Tomorrow',
            receiptJobId: 'job-other-day',
          ),
        ],
      );

      final entries = await service.loadForDay(dayId);

      expect(entries, hasLength(2));
      final byId = {for (final entry in entries) entry.audioId: entry};
      expect(byId['included']!.activityEntryId, 'activity-included');
      expect(byId['included']!.processingState, 'ready');
      expect(
        byId['included']!.transcript,
        'Remember the gym check-in.',
      );
      expect(byId['uncorrelated']!.processingState, 'pending');
      expect(byId['uncorrelated']!.transcript, isNull);
    },
  );

  test('bounds transcript text while retaining recording metadata', () async {
    final root = Directory.systemTemp.createTempSync('day-audio-context-test-');
    addTearDown(() => root.deleteSync(recursive: true));
    final audioDirectory = Directory('${root.path}/audio')..createSync();
    File('${audioDirectory.path}/bounded.wav').writeAsBytesSync([1, 2, 3]);
    service = DayAudioEntryContextService(
      journalDb: journalDb,
      assetRoot: root,
    );
    when(
      () => journalDb.getJournalEntities(
        types: const ['JournalAudio'],
        starredStatuses: const [true, false],
        privateStatuses: const [true, false],
        flaggedStatuses: const [1, 0],
        ids: null,
        limit: 64,
        // ignore: avoid_redundant_argument_values
        offset: 0,
      ),
    ).thenAnswer(
      (_) async => [
        audio(
          id: 'bounded',
          entryDayId: dayId,
          processingJobId: 'job-bounded',
          transcript: 'abcdefghij',
          receiptJobId: 'job-bounded',
        ),
      ],
    );

    final entries = await service.loadForDay(
      dayId,
      maxTranscriptCharacters: 5,
    );

    expect(entries.single.transcript, 'abcde…');
    expect(entries.single.toJson()['audioAvailableLocally'], isTrue);
  });

  test('retains metadata for every persisted recording in the day', () async {
    when(
      () => journalDb.getJournalEntities(
        types: const ['JournalAudio'],
        starredStatuses: const [true, false],
        privateStatuses: const [true, false],
        flaggedStatuses: const [1, 0],
        ids: null,
        limit: 64,
        // ignore: avoid_redundant_argument_values
        offset: 0,
      ),
    ).thenAnswer(
      (_) async => [
        for (var index = 0; index < 21; index++)
          audio(
            id: 'recording-$index',
            entryDayId: dayId,
            processingJobId: 'job-$index',
          ),
      ],
    );

    final entries = await service.loadForDay(dayId);

    expect(entries, hasLength(21));
    expect(
      entries.map((entry) => entry.audioId),
      containsAll(<String>['recording-0', 'recording-20']),
    );
  });
}
