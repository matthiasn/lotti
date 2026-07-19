import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/audio_note.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/daily_os_next/services/day_audio_spool_recovery_service.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_job.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_outbox_repository.dart';
import 'package:lotti/features/speech/services/durable_audio_spool.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  final capturedAt = DateTime(2026, 7, 18, 8);
  late Directory root;
  late MockJournalDb journalDb;
  late DayProcessingOutboxRepository outbox;

  setUp(() {
    root = Directory.systemTemp.createTempSync('day-spool-recovery-test-');
    Directory('${root.path}/.audio_spool').createSync();
    journalDb = MockJournalDb();
    outbox = DayProcessingOutboxRepository(
      rootDirectory: Directory('${root.path}/outbox'),
      now: () => capturedAt,
    );
  });

  tearDown(() async {
    await outbox.dispose();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  test(
    'finalizes an interrupted spool and publishes its outbox intent',
    () async {
      final spool = await DurableAudioSpool.start(
        rootDirectory: Directory('${root.path}/.audio_spool'),
        context: DurableAudioSpoolContext(
          recordingSessionId: 'session-1',
          activityEntryId: 'activity-1',
          createdAt: capturedAt,
          assetRootPath: root.absolute.path,
          origin: AudioCaptureOrigin.dailyOs,
          intent: AudioCaptureIntent.dayPlan,
          dayId: 'dayplan-2026-07-18',
          planDate: DateTime(2026, 7, 18),
        ),
        chunkBytes: 4,
      );
      expect(
        await spool.append(Uint8List.fromList([1, 2, 3, 4])),
        SpoolAppendResult.persisted,
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
      ).thenAnswer((_) async => []);
      AudioNote? persistedNote;
      final service = DayAudioSpoolRecoveryService(
        journalDb: journalDb,
        outbox: outbox,
        assetRoot: root,
        persistAudio: (note) async {
          persistedNote = note;
          return JournalAudio(
            meta: Metadata(
              id: 'audio-1',
              createdAt: note.createdAt,
              updatedAt: note.createdAt,
              dateFrom: note.createdAt,
              dateTo: note.createdAt.add(note.duration),
            ),
            data: AudioData(
              dateFrom: note.createdAt,
              dateTo: note.createdAt.add(note.duration),
              audioFile: note.audioFile,
              audioDirectory: note.audioDirectory,
              duration: note.duration,
              dayContext: note.dayContext,
            ),
          );
        },
      );

      final recovered = await service.recoverSession('session-1');

      expect(recovered?.meta.id, 'audio-1');
      expect(persistedNote?.dayContext?.activityEntryId, 'activity-1');
      expect(
        File(
          '${root.path}/audio/2026-07-18/recovered_session-1.wav',
        ).existsSync(),
        isTrue,
      );
      final job = await outbox.getById('transcribe_session-1');
      expect(job?.audioId, 'audio-1');
      expect(job?.status, DayProcessingJobStatus.queued);
      final manifest = (await DurableAudioSpool.recover(
        sessionDirectory: Directory('${root.path}/.audio_spool/session-1'),
      )).manifest;
      expect(manifest.journalAudioId, 'audio-1');
    },
  );

  test('reuses a published WAV target after restart', () async {
    final spool = await DurableAudioSpool.start(
      rootDirectory: Directory('${root.path}/.audio_spool'),
      context: DurableAudioSpoolContext(
        recordingSessionId: 'session-published',
        activityEntryId: 'activity-published',
        createdAt: capturedAt,
        assetRootPath: root.absolute.path,
        origin: AudioCaptureOrigin.dailyOs,
        intent: AudioCaptureIntent.dayPlan,
        dayId: 'dayplan-2026-07-18',
        planDate: DateTime(2026, 7, 18),
      ),
      chunkBytes: 4,
    );
    await spool.append(Uint8List.fromList([1, 2, 3, 4]));
    final originalTarget = File('${root.path}/audio/original.wav');
    await spool.finalize(destinationFile: originalTarget);
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
    ).thenAnswer((_) async => []);
    AudioNote? persistedNote;
    final service = DayAudioSpoolRecoveryService(
      journalDb: journalDb,
      outbox: outbox,
      assetRoot: root,
      persistAudio: (note) async {
        persistedNote = note;
        return JournalAudio(
          meta: Metadata(
            id: 'audio-published',
            createdAt: note.createdAt,
            updatedAt: note.createdAt,
            dateFrom: note.createdAt,
            dateTo: note.createdAt.add(note.duration),
          ),
          data: AudioData(
            dateFrom: note.createdAt,
            dateTo: note.createdAt.add(note.duration),
            audioFile: note.audioFile,
            audioDirectory: note.audioDirectory,
            duration: note.duration,
            dayContext: note.dayContext,
          ),
        );
      },
    );

    final recovered = await service.recoverSession('session-published');

    expect(recovered?.meta.id, 'audio-published');
    expect(persistedNote?.audioFile, 'original.wav');
    expect(persistedNote?.audioDirectory, '/audio/');
    expect(originalTarget.existsSync(), isTrue);
    expect(
      File(
        '${root.path}/audio/2026-07-18/recovered_session-published.wav',
      ).existsSync(),
      isFalse,
    );
  });
}
