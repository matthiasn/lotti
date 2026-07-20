import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/audio_note.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai_consumption/model/ai_attribution.dart';
import 'package:lotti/features/ai_consumption/service/transcript_attribution_coordinator.dart';
import 'package:lotti/features/daily_os_next/services/day_audio_ids.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_job.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_outbox_repository.dart';
import 'package:lotti/features/daily_os_next/state/capture_controller.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:mocktail/mocktail.dart';
import 'package:record/record.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../ai_consumption/test_utils.dart';

final _now = DateTime(2026, 7, 20, 9);
const _sessionId = 'session-fixed-0001';

AudioNote _audioNoteFixture() => AudioNote(
  createdAt: _now,
  audioFile: 'capture.m4a',
  audioDirectory: '/audio/2026-07-20/',
  duration: Duration.zero,
);

JournalAudio _persistedAudio(AudioNote note, {String id = 'audio_001'}) {
  return JournalAudio(
    meta: Metadata(
      id: id,
      createdAt: note.createdAt,
      updatedAt: note.createdAt,
      dateFrom: note.createdAt,
      dateTo: note.createdAt.add(note.duration),
      vectorClock: const VectorClock(<String, int>{}),
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
}

/// Shared wiring for the batch-first capture flow: mock recorder +
/// transcriber, a real file-backed outbox in a temp directory, and a
/// persistence seam that records what reached the journal.
class _Bench {
  _Bench._({
    required this.recorder,
    required this.transcriber,
    required this.ampController,
    required this.outboxRoot,
    required this.outbox,
    required this.docDir,
    required this.persistenceLogic,
  });

  factory _Bench.create({bool persistSucceeds = true}) {
    final recorder = MockAudioRecorderRepository();
    final transcriber = MockAudioTranscriptionService();
    final ampController = StreamController<Amplitude>.broadcast();
    final outboxRoot = Directory.systemTemp.createTempSync('capture-outbox-');
    final docDir = Directory.systemTemp.createTempSync('capture-docs-');
    final outbox = DayProcessingOutboxRepository(rootDirectory: outboxRoot);
    final persistenceLogic = MockPersistenceLogic();
    when(recorder.hasPermission).thenAnswer((_) async => true);
    when(recorder.stopRecording).thenAnswer((_) async {});
    when(
      () => recorder.amplitudeStream,
    ).thenAnswer((_) => ampController.stream);
    when(recorder.startRecording).thenAnswer((_) async => _audioNoteFixture());
    when(
      () => persistenceLogic.updateMetadata(any()),
    ).thenAnswer((inv) async => inv.positionalArguments.first as Metadata);
    when(
      () => persistenceLogic.updateDbEntity(any()),
    ).thenAnswer((_) async => true);
    final bench = _Bench._(
      recorder: recorder,
      transcriber: transcriber,
      ampController: ampController,
      outboxRoot: outboxRoot,
      outbox: outbox,
      docDir: docDir,
      persistenceLogic: persistenceLogic,
    );
    if (persistSucceeds) {
      bench.persistAudio = (note) async {
        bench.persistedNote = note;
        final audio = _persistedAudio(note);
        bench.persistedAudio = audio;
        return audio;
      };
    } else {
      bench.persistAudio = (note) async => null;
    }
    return bench;
  }

  final MockAudioRecorderRepository recorder;
  final MockAudioTranscriptionService transcriber;
  final StreamController<Amplitude> ampController;
  final Directory outboxRoot;
  final DayProcessingOutboxRepository outbox;
  final Directory docDir;
  final MockPersistenceLogic persistenceLogic;

  late Future<JournalAudio?> Function(AudioNote) persistAudio;
  AudioNote? persistedNote;
  JournalAudio? persistedAudio;
  JournalEntity? attachedEntity;

  void stubTranscript(String transcript) {
    when(
      () => transcriber.transcribe(
        any(),
        speechDictionaryTerms: any(named: 'speechDictionaryTerms'),
      ),
    ).thenAnswer((_) async => transcript);
  }

  void stubTranscribeThrows(Object error) {
    when(
      () => transcriber.transcribe(
        any(),
        speechDictionaryTerms: any(named: 'speechDictionaryTerms'),
      ),
    ).thenThrow(error);
  }

  void captureAttachedEntity() {
    when(() => persistenceLogic.updateDbEntity(any())).thenAnswer((inv) async {
      attachedEntity = inv.positionalArguments.first as JournalEntity;
      return true;
    });
  }

  ProviderContainer aliveContainer({DayProcessingOutboxRepository? outbox}) {
    final container = ProviderContainer(
      overrides: [
        captureControllerProvider.overrideWith(
          () => CaptureController(
            recorder: recorder,
            transcriber: transcriber,
            persistAudio: (note) => persistAudio(note),
            processingOutbox: outbox,
            docDir: () => docDir,
            sessionIdFactory: () => _sessionId,
            originHostId: () async => 'host-1',
            now: () => _now,
          ),
        ),
      ],
    )..listen(captureControllerProvider, (_, _) {});
    return container;
  }

  Future<void> dispose() async {
    await ampController.close();
    await outbox.dispose();
    if (outboxRoot.existsSync()) outboxRoot.deleteSync(recursive: true);
    if (docDir.existsSync()) docDir.deleteSync(recursive: true);
  }
}

AiInteractionCaptureTestBench _registerTranscriptAttribution() {
  final bench = AiInteractionCaptureTestBench.create()..register();
  if (getIt.isRegistered<TranscriptAttributionCoordinator>()) {
    getIt.unregister<TranscriptAttributionCoordinator>();
  }
  getIt.registerSingleton<TranscriptAttributionCoordinator>(
    TranscriptAttributionCoordinator(bench.service, bench.identity),
  );
  addTearDown(() {
    if (getIt.isRegistered<TranscriptAttributionCoordinator>()) {
      getIt.unregister<TranscriptAttributionCoordinator>();
    }
    bench.unregister();
  });
  return bench;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Bench bench;

  setUpAll(() {
    registerAllFallbackValues();
    registerFallbackValue(_audioNoteFixture());
    registerFallbackValue(
      Metadata(
        id: 'meta',
        createdAt: _now,
        updatedAt: _now,
        dateFrom: _now,
        dateTo: _now,
      ),
    );
    registerFallbackValue(
      JournalEntity.journalAudio(
        meta: Metadata(
          id: 'meta',
          createdAt: _now,
          updatedAt: _now,
          dateFrom: _now,
          dateTo: _now,
        ),
        data: AudioData(
          dateFrom: _now,
          dateTo: _now,
          audioFile: 'capture.m4a',
          audioDirectory: '/audio/2026-07-20/',
          duration: Duration.zero,
        ),
      ),
    );
  });

  setUp(() async {
    await getIt.reset();
    bench = _Bench.create();
    getIt.registerSingleton<PersistenceLogic>(bench.persistenceLogic);
  });

  tearDown(() async {
    await bench.dispose();
    await getIt.reset();
  });

  group('CaptureController batch-first commit ordering', () {
    test('persists journal audio with provenance before transcription '
        'and completes the claimed job in the foreground', () async {
      bench
        ..stubTranscript('  plan the day  ')
        ..captureAttachedEntity();
      final container = bench.aliveContainer(outbox: bench.outbox);
      addTearDown(container.dispose);
      final controller = container.read(captureControllerProvider.notifier);

      await controller.toggle(forDate: DateTime(2026, 7, 22, 14));
      expect(
        container.read(captureControllerProvider).phase,
        CapturePhase.listening,
      );

      await controller.toggle();
      final state = container.read(captureControllerProvider);
      expect(state.phase, CapturePhase.captured);
      expect(state.transcript, 'plan the day');
      expect(state.audioId, 'audio_001');

      // Provenance is stamped from the selected planning day, not the
      // wall clock at stop.
      final context = bench.persistedNote!.dayContext!;
      expect(context.dayId, 'dayplan-2026-07-22');
      expect(context.planDate, DateTime(2026, 7, 22));
      expect(context.recordingSessionId, _sessionId);
      expect(
        context.activityEntryId,
        audioActivityEntryIdForSession(_sessionId),
      );
      expect(
        context.processingJobId,
        DayProcessingOutboxRepository.transcriptionJobId(_sessionId),
      );
      expect(context.intent, 'dayPlan');
      expect(context.originHostId, 'host-1');
      expect(context.capturedAt, _now);

      // The claimed job ran through ready → attached → succeeded.
      final job = await bench.outbox.getById(context.processingJobId);
      expect(job!.status, DayProcessingJobStatus.succeeded);
      expect(job.resultTranscript, 'plan the day');

      // The journal commit carries the transcript + entryText mirror and
      // the job receipt.
      final attached = bench.attachedEntity! as JournalAudio;
      expect(attached.entryText!.plainText, 'plan the day');
      final receipt = attached.data.transcripts!.single;
      expect(receipt.transcript, 'plan the day');
      expect(receipt.processingJobId, context.processingJobId);
    });

    test('refine intent is stamped into provenance', () async {
      bench.stubTranscript('shift lunch');
      final container = bench.aliveContainer(outbox: bench.outbox);
      addTearDown(container.dispose);
      final controller = container.read(captureControllerProvider.notifier);

      await controller.toggle(
        forDate: DateTime(2026, 7, 20),
        intent: AudioCaptureIntent.dayRefine,
      );
      await controller.toggle();

      expect(bench.persistedNote!.dayContext!.intent, 'dayRefine');
    });

    test('transcription failure keeps the saved recording and hands the '
        'job back for background retry', () async {
      bench.stubTranscribeThrows(const SocketException('offline'));
      final container = bench.aliveContainer(outbox: bench.outbox);
      addTearDown(container.dispose);
      final controller = container.read(captureControllerProvider.notifier);

      await controller.toggle();
      await controller.toggle();

      final state = container.read(captureControllerProvider);
      expect(state.phase, CapturePhase.error);
      expect(state.error, CaptureError.recordingSavedPendingTranscription);
      expect(state.audioId, 'audio_001');
      expect(bench.persistedNote, isNotNull);

      final job = await bench.outbox.getById(
        DayProcessingOutboxRepository.transcriptionJobId(_sessionId),
      );
      expect(job!.status, DayProcessingJobStatus.waitingForNetwork);
      expect(job.lastFailureClass, DayProcessingFailureClass.network);
    });

    test(
      'empty transcript is a retryable failure, not a lost recording',
      () async {
        bench.stubTranscript('   ');
        final container = bench.aliveContainer(outbox: bench.outbox);
        addTearDown(container.dispose);
        final controller = container.read(captureControllerProvider.notifier);

        await controller.toggle();
        await controller.toggle();

        final state = container.read(captureControllerProvider);
        expect(state.error, CaptureError.recordingSavedPendingTranscription);
        final job = await bench.outbox.getById(
          DayProcessingOutboxRepository.transcriptionJobId(_sessionId),
        );
        expect(job!.status, DayProcessingJobStatus.queued);
        expect(job.lastFailureClass, DayProcessingFailureClass.timeout);
      },
    );

    test('journal rejection surfaces audioPersistFailed and never touches '
        'the outbox', () async {
      bench = _Bench.create(persistSucceeds: false);
      getIt
        ..unregister<PersistenceLogic>()
        ..registerSingleton<PersistenceLogic>(bench.persistenceLogic);
      bench.stubTranscript('never used');
      final container = bench.aliveContainer(outbox: bench.outbox);
      addTearDown(container.dispose);
      final controller = container.read(captureControllerProvider.notifier);

      await controller.toggle();
      await controller.toggle();

      final state = container.read(captureControllerProvider);
      expect(state.phase, CapturePhase.error);
      expect(state.error, CaptureError.audioPersistFailed);
      expect(state.audioId, isNull);
      expect(
        await bench.outbox.getById(
          DayProcessingOutboxRepository.transcriptionJobId(_sessionId),
        ),
        isNull,
      );
      verifyNever(
        () => bench.transcriber.transcribe(
          any(),
          speechDictionaryTerms: any(named: 'speechDictionaryTerms'),
        ),
      );
    });

    test('enqueue failure still reports the recording as saved', () async {
      final failingOutbox = MockDayProcessingOutboxRepository();
      when(
        () => failingOutbox.enqueueAndClaimTranscription(
          dayId: any(named: 'dayId'),
          activityEntryId: any(named: 'activityEntryId'),
          recordingSessionId: any(named: 'recordingSessionId'),
          audioId: any(named: 'audioId'),
          audioPath: any(named: 'audioPath'),
          capturedAt: any(named: 'capturedAt'),
        ),
      ).thenThrow(StateError('disk full'));
      bench.stubTranscript('never used');
      final container = bench.aliveContainer(outbox: failingOutbox);
      addTearDown(container.dispose);
      final controller = container.read(captureControllerProvider.notifier);

      await controller.toggle();
      await controller.toggle();

      final state = container.read(captureControllerProvider);
      expect(state.error, CaptureError.recordingSavedPendingTranscription);
      expect(state.audioId, 'audio_001');
    });

    test(
      'transcript-commit rejection fails the job locally for retry',
      () async {
        bench.stubTranscript('good words');
        when(
          () => bench.persistenceLogic.updateDbEntity(any()),
        ).thenAnswer((_) async => false);
        final container = bench.aliveContainer(outbox: bench.outbox);
        addTearDown(container.dispose);
        final controller = container.read(captureControllerProvider.notifier);

        await controller.toggle();
        await controller.toggle();

        final state = container.read(captureControllerProvider);
        expect(state.error, CaptureError.recordingSavedPendingTranscription);
        final job = await bench.outbox.getById(
          DayProcessingOutboxRepository.transcriptionJobId(_sessionId),
        );
        expect(job!.status, DayProcessingJobStatus.queued);
        expect(job.lastFailureClass, DayProcessingFailureClass.local);
        // The provider transcript survived for the background retry to
        // reuse without another inference round-trip.
        expect(job.resultTranscript, 'good words');
      },
    );

    test('without a processing outbox the transcript still lands on the '
        'journal entry', () async {
      bench
        ..stubTranscript('plain attach')
        ..captureAttachedEntity();
      final container = bench.aliveContainer();
      addTearDown(container.dispose);
      final controller = container.read(captureControllerProvider.notifier);

      await controller.toggle();
      await controller.toggle();

      final state = container.read(captureControllerProvider);
      expect(state.phase, CapturePhase.captured);
      expect(state.transcript, 'plain attach');
      final attached = bench.attachedEntity! as JournalAudio;
      expect(attached.data.transcripts!.single.processingJobId, isNull);
    });
  });

  group('CaptureController recording lifecycle', () {
    test('denied microphone permission surfaces the localized error', () async {
      when(bench.recorder.hasPermission).thenAnswer((_) async => false);
      final container = bench.aliveContainer();
      addTearDown(container.dispose);
      final controller = container.read(captureControllerProvider.notifier);

      await controller.toggle();

      final state = container.read(captureControllerProvider);
      expect(state.phase, CapturePhase.error);
      expect(state.error, CaptureError.microphonePermissionDenied);
      verifyNever(bench.recorder.startRecording);
    });

    test('recorder start failure surfaces recordingStartFailed', () async {
      when(bench.recorder.startRecording).thenAnswer((_) async => null);
      final container = bench.aliveContainer();
      addTearDown(container.dispose);
      final controller = container.read(captureControllerProvider.notifier);

      await controller.toggle();

      expect(
        container.read(captureControllerProvider).error,
        CaptureError.recordingStartFailed,
      );
    });

    test('amplitude stream feeds the rolling waveform window', () async {
      final container = bench.aliveContainer();
      addTearDown(container.dispose);
      final controller = container.read(captureControllerProvider.notifier);

      await controller.toggle();
      for (var i = 0; i < 90; i++) {
        bench.ampController.add(Amplitude(current: -20, max: 0));
      }
      await Future<void>.delayed(Duration.zero);

      final state = container.read(captureControllerProvider);
      expect(state.amplitudes.length, 80);
      expect(state.dbfs, -20);
    });

    test('toggle while transcribing is ignored', () async {
      final transcribeGate = Completer<String>();
      when(
        () => bench.transcriber.transcribe(
          any(),
          speechDictionaryTerms: any(named: 'speechDictionaryTerms'),
        ),
      ).thenAnswer((_) => transcribeGate.future);
      final container = bench.aliveContainer(outbox: bench.outbox);
      addTearDown(container.dispose);
      final controller = container.read(captureControllerProvider.notifier);

      await controller.toggle();
      final finish = controller.toggle();
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(captureControllerProvider).phase,
        CapturePhase.transcribing,
      );

      // A tap during the stop commit must not restart or reset anything.
      await controller.toggle();
      expect(
        container.read(captureControllerProvider).phase,
        CapturePhase.transcribing,
      );

      transcribeGate.complete('late words');
      await finish;
      expect(
        container.read(captureControllerProvider).phase,
        CapturePhase.captured,
      );
    });

    test('reset stops an active recording and returns to idle', () async {
      final container = bench.aliveContainer();
      addTearDown(container.dispose);
      final controller = container.read(captureControllerProvider.notifier);

      await controller.toggle();
      controller.reset();
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(captureControllerProvider).phase,
        CapturePhase.idle,
      );
      verify(bench.recorder.stopRecording).called(1);
    });

    test('startTyping opens the editable transcript path and '
        'updateTranscript edits it', () async {
      final container = bench.aliveContainer();
      addTearDown(container.dispose);
      final controller = container.read(captureControllerProvider.notifier)
        ..startTyping();

      expect(
        container.read(captureControllerProvider).phase,
        CapturePhase.captured,
      );
      controller.updateTranscript('typed instead');
      expect(
        container.read(captureControllerProvider).transcript,
        'typed instead',
      );

      controller
        ..reset()
        ..updateTranscript('ignored outside captured');
      expect(container.read(captureControllerProvider).transcript, '');
    });

    test('stopping with no active session surfaces noAudioRecorded', () async {
      when(bench.recorder.startRecording).thenAnswer((_) async {
        return _audioNoteFixture();
      });
      final container = bench.aliveContainer();
      addTearDown(container.dispose);
      final controller = container.read(captureControllerProvider.notifier);

      await controller.toggle();
      controller
        ..reset()
        // Force the finish path with the session already cleared: the
        // state machine treats this as no recorded audio, not a crash.
        ..state = const CaptureState(
          phase: CapturePhase.listening,
          transcript: '',
          amplitudes: <double>[],
        );
      await controller.toggle();

      expect(
        container.read(captureControllerProvider).error,
        CaptureError.noAudioRecorded,
      );
    });
  });

  group('CaptureController transcript attribution', () {
    void stubAttributedTranscribe(_Bench bench, String transcript) {
      when(
        () => bench.transcriber.transcribe(
          any(),
          attributionSession: any(named: 'attributionSession'),
          terminalizeAttributionFailure: false,
        ),
      ).thenAnswer((_) async => transcript);
    }

    test(
      'an attributed capture embeds and finalizes the transcript carrier',
      () async {
        final attribution = _registerTranscriptAttribution();
        stubAttributedTranscribe(bench, 'attributed journal');
        bench.captureAttachedEntity();
        final container = bench.aliveContainer(outbox: bench.outbox);
        addTearDown(container.dispose);
        final controller = container.read(captureControllerProvider.notifier);

        await controller.toggle();
        await controller.toggle();

        expect(
          container.read(captureControllerProvider).phase,
          CapturePhase.captured,
        );
        final receipt =
            (bench.attachedEntity! as JournalAudio).data.transcripts!.single;
        expect(receipt.transcript, 'attributed journal');
        expect(receipt.id, isNotEmpty);
        expect(receipt.aiAttribution?.id, 'attribution-1');
        verify(() => attribution.service.finalize(any())).called(1);
      },
    );

    test(
      'a rejected journal update terminalizes the missing carrier',
      () async {
        final attribution = _registerTranscriptAttribution();
        stubAttributedTranscribe(bench, 'not persisted');
        when(
          () => bench.persistenceLogic.updateDbEntity(any()),
        ).thenAnswer((_) async => false);
        final container = bench.aliveContainer(outbox: bench.outbox);
        addTearDown(container.dispose);
        final controller = container.read(captureControllerProvider.notifier);

        await controller.toggle();
        await controller.toggle();

        expect(
          container.read(captureControllerProvider).error,
          CaptureError.recordingSavedPendingTranscription,
        );
        verify(
          () => attribution.service.prepareCompletion(
            attributionId: 'attribution-1',
            outputs: const [],
            status: AiWorkStatus.failed,
            errorCode: 'transcript_persistence_failed',
          ),
        ).called(1);
      },
    );

    test('an empty transcript records an unusable attributed output', () async {
      final attribution = _registerTranscriptAttribution();
      stubAttributedTranscribe(bench, '   ');
      final container = bench.aliveContainer(outbox: bench.outbox);
      addTearDown(container.dispose);
      final controller = container.read(captureControllerProvider.notifier);

      await controller.toggle();
      await controller.toggle();

      expect(
        container.read(captureControllerProvider).error,
        CaptureError.recordingSavedPendingTranscription,
      );
      verify(
        () => attribution.service.prepareCompletion(
          attributionId: 'attribution-1',
          outputs: const [],
          status: AiWorkStatus.failed,
          errorCode: 'empty_transcript',
        ),
      ).called(1);
    });

    test('a transcription failure fails the attribution session', () async {
      final attribution = _registerTranscriptAttribution();
      when(
        () => bench.transcriber.transcribe(
          any(),
          attributionSession: any(named: 'attributionSession'),
          terminalizeAttributionFailure: false,
        ),
      ).thenThrow(const SocketException('offline'));
      final container = bench.aliveContainer(outbox: bench.outbox);
      addTearDown(container.dispose);
      final controller = container.read(captureControllerProvider.notifier);

      await controller.toggle();
      await controller.toggle();

      expect(
        container.read(captureControllerProvider).error,
        CaptureError.recordingSavedPendingTranscription,
      );
      verify(
        () => attribution.service.prepareCompletion(
          attributionId: 'attribution-1',
          outputs: const [],
          status: AiWorkStatus.failed,
          errorCode: 'SocketException',
        ),
      ).called(1);
    });
  });
}
