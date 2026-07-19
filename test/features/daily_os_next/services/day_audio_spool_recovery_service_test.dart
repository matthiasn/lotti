import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/audio_note.dart';
import 'package:lotti/classes/day_audio_context.dart';
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

  Future<DurableAudioSpool> createSpool(String sessionId) async {
    final spool = await DurableAudioSpool.start(
      rootDirectory: Directory('${root.path}/.audio_spool'),
      context: DurableAudioSpoolContext(
        recordingSessionId: sessionId,
        activityEntryId: 'activity-$sessionId',
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
    return spool;
  }

  JournalAudio audioForNote(
    AudioNote note, {
    required String id,
    String? transcript,
  }) => JournalAudio(
    meta: Metadata(
      id: id,
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
      transcripts: transcript == null
          ? null
          : [
              AudioTranscript(
                created: capturedAt,
                library: 'test',
                model: 'test',
                detectedLanguage: 'en',
                transcript: transcript,
                processingJobId: note.dayContext?.processingJobId,
              ),
            ],
    ),
  );

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

  test('reuses journal ownership and restores a completed receipt', () async {
    final spool = await createSpool('session-owned');
    final destination = File('${root.path}/audio/owned.wav');
    final finalized = await spool.finalize(destinationFile: destination);
    await spool.markCommitted(journalAudioId: 'audio-owned');
    final source = (await DurableAudioSpool.recover(
      sessionDirectory: spool.sessionDirectory,
    )).manifest.context;
    final note = AudioNote(
      createdAt: source.createdAt,
      audioFile: 'owned.wav',
      audioDirectory: '/audio/',
      duration: finalized.duration,
      dayContext: DayAudioContext(
        dayId: source.dayId!,
        planDate: source.planDate!,
        recordingSessionId: source.recordingSessionId,
        activityEntryId: source.activityEntryId,
        processingJobId: 'transcribe_session-owned',
        capturedAt: source.createdAt,
        intent: 'dayPlan',
        originHostId: source.originHostId,
      ),
    );
    final owned = audioForNote(
      note,
      id: 'audio-owned',
      transcript: '  Receipt text survived  ',
    );
    when(
      () => journalDb.journalEntityById('audio-owned'),
    ).thenAnswer((_) async => owned);
    final service = DayAudioSpoolRecoveryService(
      journalDb: journalDb,
      outbox: outbox,
      assetRoot: root,
      persistAudio: (_) async => throw StateError('must reuse owner'),
    );

    final recovered = await service.recoverSession('session-owned');

    expect(recovered, same(owned));
    final job = await outbox.getById('transcribe_session-owned');
    expect(job!.status, DayProcessingJobStatus.succeeded);
    expect(job.resultTranscript, 'Receipt text survived');
  });

  test(
    'finds a matching journal row when persistence result is lost',
    () async {
      final spool = await createSpool('session-fallback');
      await spool.finalize(
        destinationFile: File(
          '${root.path}/audio/2026-07-18/recovered_session-fallback.wav',
        ),
      );
      final source = (await DurableAudioSpool.recover(
        sessionDirectory: spool.sessionDirectory,
      )).manifest.context;
      final note = AudioNote(
        createdAt: source.createdAt,
        audioFile: 'recovered_session-fallback.wav',
        audioDirectory: '/audio/2026-07-18/',
        duration: const Duration(microseconds: 125),
        dayContext: DayAudioContext(
          dayId: source.dayId!,
          planDate: source.planDate!,
          recordingSessionId: source.recordingSessionId,
          activityEntryId: source.activityEntryId,
          processingJobId: 'transcribe_session-fallback',
          capturedAt: source.createdAt,
          intent: 'dayPlan',
          originHostId: source.originHostId,
        ),
      );
      final matching = audioForNote(note, id: 'audio-fallback');
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
      ).thenAnswer((_) async => [matching]);
      final service = DayAudioSpoolRecoveryService(
        journalDb: journalDb,
        outbox: outbox,
        assetRoot: root,
        persistAudio: (_) async => null,
      );

      final recovered = await service.recoverSession('session-fallback');

      expect(recovered, same(matching));
      expect(
        (await outbox.getById('transcribe_session-fallback'))?.audioId,
        'audio-fallback',
      );
    },
  );

  test('searches later journal pages for an existing recording', () async {
    final spool = await createSpool('session-page-two');
    final destination = File('${root.path}/audio/page-two.wav');
    final finalized = await spool.finalize(destinationFile: destination);
    final source = (await DurableAudioSpool.recover(
      sessionDirectory: spool.sessionDirectory,
    )).manifest.context;
    final matching = audioForNote(
      AudioNote(
        createdAt: source.createdAt,
        audioFile: 'page-two.wav',
        audioDirectory: '/audio/',
        duration: finalized.duration,
        dayContext: DayAudioContext(
          dayId: source.dayId!,
          planDate: source.planDate!,
          recordingSessionId: source.recordingSessionId,
          activityEntryId: source.activityEntryId,
          processingJobId: 'transcribe_session-page-two',
          capturedAt: source.createdAt,
          intent: 'dayPlan',
          originHostId: source.originHostId,
        ),
      ),
      id: 'audio-page-two',
    );
    final unrelated = audioForNote(
      AudioNote(
        createdAt: capturedAt,
        audioFile: 'unrelated.wav',
        audioDirectory: '/audio/',
        duration: const Duration(seconds: 1),
        dayContext: DayAudioContext(
          dayId: 'dayplan-2026-07-18',
          planDate: DateTime(2026, 7, 18),
          recordingSessionId: 'another-session',
          activityEntryId: 'another-activity',
          processingJobId: 'transcribe_another-session',
          capturedAt: capturedAt,
          intent: 'dayPlan',
          originHostId: 'test-host',
        ),
      ),
      id: 'unrelated-audio',
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
    ).thenAnswer((_) async => List<JournalEntity>.filled(64, unrelated));
    when(
      () => journalDb.getJournalEntities(
        types: const ['JournalAudio'],
        starredStatuses: const [true, false],
        privateStatuses: const [true, false],
        flaggedStatuses: const [1, 0],
        ids: null,
        limit: 64,
        offset: 64,
      ),
    ).thenAnswer((_) async => [matching]);
    final service = DayAudioSpoolRecoveryService(
      journalDb: journalDb,
      outbox: outbox,
      assetRoot: root,
      persistAudio: (_) async => throw StateError('must reuse journal audio'),
    );

    final recovered = await service.recoverSession('session-page-two');

    expect(recovered, same(matching));
    expect(
      (await outbox.getById('transcribe_session-page-two'))?.audioId,
      'audio-page-two',
    );
  });

  test(
    'recoverAll heals valid sessions while isolating damaged ones',
    () async {
      await createSpool('session-valid');
      Directory('${root.path}/.audio_spool/session-damaged').createSync();
      File(
        '${root.path}/.audio_spool/session-damaged/manifest-00000001.json',
      ).writeAsStringSync('damaged');
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
      final service = DayAudioSpoolRecoveryService(
        journalDb: journalDb,
        outbox: outbox,
        assetRoot: root,
        persistAudio: (note) async => audioForNote(note, id: 'audio-valid'),
      );

      expect(await service.recoverAll(), 1);
      expect(
        (await outbox.getById('transcribe_session-valid'))?.audioId,
        'audio-valid',
      );
    },
  );
}
