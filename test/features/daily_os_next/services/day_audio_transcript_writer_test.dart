import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/day_audio_context.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/daily_os_next/services/day_audio_transcript_writer.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_job.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

void main() {
  final now = DateTime.utc(2026, 7, 18, 8);
  late MockJournalDb journalDb;
  late MockPersistenceLogic persistenceLogic;
  late DayAudioTranscriptWriter writer;

  DayProcessingJob job() => DayProcessingJob(
    id: 'transcribe_session-1',
    kind: DayProcessingJobKind.transcribeAudio,
    status: DayProcessingJobStatus.running,
    dayId: 'dayplan-2026-07-18',
    activityEntryId: 'activity-1',
    recordingSessionId: 'session-1',
    audioId: 'audio-1',
    audioPath: '/audio/one.wav',
    createdAt: now,
    updatedAt: now,
    nextAttemptAt: now,
    attempts: 1,
    generation: 1,
    claimToken: 'claim-1',
  );

  JournalAudio audio({
    String processingJobId = 'transcribe_session-1',
    List<AudioTranscript>? transcripts,
  }) => JournalAudio(
    meta: Metadata(
      id: 'audio-1',
      createdAt: now,
      updatedAt: now,
      dateFrom: now,
      dateTo: now.add(const Duration(minutes: 1)),
    ),
    data: AudioData(
      dateFrom: now,
      dateTo: now.add(const Duration(minutes: 1)),
      audioFile: 'one.wav',
      audioDirectory: '/audio/',
      duration: const Duration(minutes: 1),
      transcripts: transcripts,
      dayContext: DayAudioContext(
        dayId: 'dayplan-2026-07-18',
        planDate: DateTime.utc(2026, 7, 18),
        recordingSessionId: 'session-1',
        activityEntryId: 'activity-1',
        processingJobId: processingJobId,
        capturedAt: now,
        intent: 'dayPlan',
      ),
    ),
  );

  setUpAll(() {
    registerAllFallbackValues();
    registerFallbackValue(FakeJournalAudio());
  });

  setUp(() {
    journalDb = MockJournalDb();
    persistenceLogic = MockPersistenceLogic();
    writer = DayAudioTranscriptWriter(
      journalDb: journalDb,
      persistenceLogic: persistenceLogic,
      now: () => now,
    );
  });

  test('attaches a searchable, job-correlated transcript once', () async {
    final source = audio();
    when(
      () => journalDb.journalEntityById('audio-1'),
    ).thenAnswer((_) async => source);
    when(
      () => persistenceLogic.updateMetadata(source.meta),
    ).thenAnswer((_) async => source.meta.copyWith(updatedAt: now));
    JournalAudio? persisted;
    when(
      () => persistenceLogic.updateDbEntity(any()),
    ).thenAnswer((invocation) async {
      persisted = invocation.positionalArguments.single as JournalAudio;
      return true;
    });

    final attached = await writer.attach(
      job: job(),
      transcript: '  Gym first, then finish the proposal. ',
    );

    expect(attached, isTrue);
    expect(
      persisted!.entryText?.plainText,
      'Gym first, then finish the proposal.',
    );
    expect(persisted!.data.transcripts, hasLength(1));
    expect(
      persisted!.data.transcripts!.single.processingJobId,
      'transcribe_session-1',
    );
  });

  test('receipt dedupe avoids a second journal write', () async {
    final source = audio(
      transcripts: <AudioTranscript>[
        AudioTranscript(
          created: now,
          library: 'daily-os-outbox',
          model: 'configured-audio-model',
          detectedLanguage: '-',
          transcript: 'Already attached',
          processingJobId: 'transcribe_session-1',
        ),
      ],
    );
    when(
      () => journalDb.journalEntityById('audio-1'),
    ).thenAnswer((_) async => source);

    final attached = await writer.attach(job: job(), transcript: 'Duplicate');

    expect(attached, isTrue);
    verifyNever(() => persistenceLogic.updateDbEntity(any()));
  });

  test('rejects an audio row that does not own the processing job', () async {
    when(
      () => journalDb.journalEntityById('audio-1'),
    ).thenAnswer((_) async => audio(processingJobId: 'another-job'));

    final attached = await writer.attach(job: job(), transcript: 'Text');

    expect(attached, isFalse);
    verifyNever(() => persistenceLogic.updateDbEntity(any()));
  });

  test('manual text is persisted as a stable reviewed receipt', () async {
    final source = audio();
    when(
      () => journalDb.journalEntityById('audio-1'),
    ).thenAnswer((_) async => source);
    when(
      () => persistenceLogic.updateMetadata(source.meta),
    ).thenAnswer((_) async => source.meta.copyWith(updatedAt: now));
    JournalAudio? persisted;
    when(
      () => persistenceLogic.updateDbEntity(any()),
    ).thenAnswer((invocation) async {
      persisted = invocation.positionalArguments.single as JournalAudio;
      return true;
    });

    final attached = await writer.attachManual(
      audioId: 'audio-1',
      transcript: '  My own reviewed text. ',
    );

    expect(attached, isTrue);
    expect(persisted!.entryText?.plainText, 'My own reviewed text.');
    expect(
      persisted!.data.transcripts!.single.processingJobId,
      'manual:activity-1',
    );
  });

  test('automatic receipt does not overwrite reviewed manual text', () async {
    final manualReceipt = AudioTranscript(
      created: now,
      library: 'daily-os-manual',
      model: 'user-reviewed',
      detectedLanguage: '-',
      transcript: 'Reviewed text',
      processingJobId: 'manual:activity-1',
    );
    final source = audio(transcripts: [manualReceipt]).copyWith(
      entryText: const EntryText(
        plainText: 'Reviewed text',
        markdown: 'Reviewed text',
      ),
    );
    when(
      () => journalDb.journalEntityById('audio-1'),
    ).thenAnswer((_) async => source);
    when(
      () => persistenceLogic.updateMetadata(source.meta),
    ).thenAnswer((_) async => source.meta.copyWith(updatedAt: now));
    JournalAudio? persisted;
    when(
      () => persistenceLogic.updateDbEntity(any()),
    ).thenAnswer((invocation) async {
      persisted = invocation.positionalArguments.single as JournalAudio;
      return true;
    });

    final attached = await writer.attach(
      job: job(),
      transcript: 'Provider guess',
    );

    expect(attached, isTrue);
    expect(persisted!.entryText?.plainText, 'Reviewed text');
    expect(persisted!.data.transcripts, hasLength(2));
  });

  test('concurrent manual and automatic writes retain both receipts', () async {
    final source = audio();
    var current = source;
    when(
      () => journalDb.journalEntityById('audio-1'),
    ).thenAnswer((_) async => current);
    when(
      () => persistenceLogic.updateMetadata(any()),
    ).thenAnswer(
      (invocation) async =>
          (invocation.positionalArguments.single as Metadata).copyWith(
            updatedAt: now,
          ),
    );
    when(
      () => persistenceLogic.updateDbEntity(any()),
    ).thenAnswer((invocation) async {
      current = invocation.positionalArguments.single as JournalAudio;
      return true;
    });

    final results = await Future.wait([
      writer.attach(job: job(), transcript: 'Provider text'),
      writer.attachManual(audioId: 'audio-1', transcript: 'Reviewed text'),
    ]);

    expect(results, everyElement(isTrue));
    expect(current.data.transcripts, hasLength(2));
    expect(current.entryText?.plainText, 'Reviewed text');
    expect(
      current.data.transcripts!.map((item) => item.processingJobId),
      containsAll(['transcribe_session-1', 'manual:activity-1']),
    );
  });
}
