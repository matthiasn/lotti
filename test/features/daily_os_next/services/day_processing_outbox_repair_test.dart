import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/day_audio_context.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_job.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_outbox_repair.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_outbox_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  late Directory root;
  late DayProcessingOutboxRepository repository;
  late MockJournalDb journalDb;
  final now = DateTime.utc(2026, 7, 18, 8);

  JournalAudio audio({
    required bool completed,
    String? originHostId,
  }) => JournalAudio(
    meta: Metadata(
      id: completed ? 'audio-complete' : 'audio-pending',
      createdAt: now,
      updatedAt: now,
      dateFrom: now,
      dateTo: now.add(const Duration(minutes: 1)),
    ),
    data: AudioData(
      dateFrom: now,
      dateTo: now.add(const Duration(minutes: 1)),
      audioFile: completed ? 'complete.wav' : 'pending.wav',
      audioDirectory: '/audio/2026-07-18/',
      duration: const Duration(minutes: 1),
      dayContext: DayAudioContext(
        dayId: 'dayplan-2026-07-18',
        planDate: DateTime.utc(2026, 7, 18),
        recordingSessionId: completed ? 'session-complete' : 'session-pending',
        activityEntryId: completed ? 'activity-complete' : 'activity-pending',
        processingJobId: completed
            ? 'transcribe_session-complete'
            : 'transcribe_session-pending',
        capturedAt: now,
        intent: 'dayPlan',
        originHostId: originHostId,
      ),
      transcripts: completed
          ? <AudioTranscript>[
              AudioTranscript(
                created: now,
                library: 'daily-os-outbox',
                model: 'model',
                detectedLanguage: '-',
                transcript: 'Completed text',
                processingJobId: 'transcribe_session-complete',
              ),
            ]
          : null,
    ),
  );

  setUp(() {
    root = Directory.systemTemp.createTempSync('day-outbox-repair-test-');
    repository = DayProcessingOutboxRepository(
      rootDirectory: Directory('${root.path}/outbox'),
      now: () => now,
    );
    journalDb = MockJournalDb();
  });

  tearDown(() async {
    await repository.dispose();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  test(
    'rebuilds pending and receipt-backed jobs from journal provenance',
    () async {
      when(
        () => journalDb.getJournalEntities(
          types: const <String>['JournalAudio'],
          starredStatuses: const <bool>[true, false],
          privateStatuses: const <bool>[true, false],
          flaggedStatuses: const <int>[1, 0],
          ids: null,
          limit: 64,
          // ignore: avoid_redundant_argument_values
          offset: 0,
        ),
      ).thenAnswer(
        (_) async => <JournalEntity>[
          audio(completed: false),
          audio(completed: true),
        ],
      );
      final repair = DayProcessingOutboxRepair(
        repository: repository,
        journalDb: journalDb,
        assetRoot: root,
      );

      final repaired = await repair.repair();
      final jobs = await repository.getAll();

      expect(repaired, 2);
      expect(jobs, hasLength(2));
      expect(
        jobs
            .singleWhere((job) => job.recordingSessionId == 'session-pending')
            .status,
        DayProcessingJobStatus.queued,
      );
      final completed = jobs.singleWhere(
        (job) => job.recordingSessionId == 'session-complete',
      );
      expect(completed.status, DayProcessingJobStatus.succeeded);
      expect(completed.resultTranscript, 'Completed text');
    },
  );

  test('does not take over another host processing intent', () async {
    when(
      () => journalDb.getJournalEntities(
        types: const <String>['JournalAudio'],
        starredStatuses: const <bool>[true, false],
        privateStatuses: const <bool>[true, false],
        flaggedStatuses: const <int>[1, 0],
        ids: null,
        limit: 64,
        // ignore: avoid_redundant_argument_values
        offset: 0,
      ),
    ).thenAnswer(
      (_) async => <JournalEntity>[
        audio(completed: false, originHostId: 'remote-host'),
      ],
    );
    final repair = DayProcessingOutboxRepair(
      repository: repository,
      journalDb: journalDb,
      assetRoot: root,
      currentHostId: 'local-host',
    );

    expect(await repair.repair(), 0);
    expect(await repository.getAll(), isEmpty);
  });
}
