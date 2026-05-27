import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/audio_note.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/realtime_transcription_event.dart';
import 'package:lotti/features/daily_os_next/state/capture_controller.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:mocktail/mocktail.dart';
import 'package:record/record.dart' as record;
import 'package:record/record.dart';

import '../../../mocks/mocks.dart';

final _recordingStartedAt = DateTime(2026, 5, 26, 9);

AudioNote _audioNoteFixture() => AudioNote(
  createdAt: _recordingStartedAt,
  audioFile: 'capture.m4a',
  audioDirectory: '/audio/2026-05-26/',
  duration: Duration.zero,
);

JournalAudio _persistedAudio({String id = 'audio_001'}) {
  return JournalAudio(
    meta: Metadata(
      id: id,
      createdAt: _recordingStartedAt,
      updatedAt: _recordingStartedAt,
      dateFrom: _recordingStartedAt,
      dateTo: _recordingStartedAt.add(const Duration(seconds: 2)),
      vectorClock: const VectorClock(<String, int>{}),
    ),
    data: AudioData(
      dateFrom: _recordingStartedAt,
      dateTo: _recordingStartedAt.add(const Duration(seconds: 2)),
      audioFile: 'capture.m4a',
      audioDirectory: '/audio/2026-05-26/',
      duration: const Duration(seconds: 2),
    ),
  );
}

ProviderContainer _aliveContainer({
  required MockAudioRecorderRepository recorder,
  required MockAudioTranscriptionService transcriber,
  required MockRealtimeTranscriptionService realtimeService,
  required Future<JournalAudio?> Function(AudioNote) persistAudio,
}) {
  final container = ProviderContainer(
    overrides: [
      captureControllerProvider.overrideWith(
        () => CaptureController(
          recorder: recorder,
          transcriber: transcriber,
          realtimeService: realtimeService,
          persistAudio: persistAudio,
          docDir: Directory.systemTemp.createTempSync,
          now: () => _recordingStartedAt,
        ),
      ),
    ],
  )..listen(captureControllerProvider, (_, _) {});
  return container;
}

class _StreamFallback extends Fake implements Stream<Uint8List> {}

class _StopRecorderFallback extends Fake {
  Future<void> call() async {}
}

void main() {
  setUpAll(() {
    registerFallbackValue(_audioNoteFixture());
    registerFallbackValue(_StreamFallback());
    registerFallbackValue(_StopRecorderFallback().call);
  });

  group('CaptureController (batch path)', () {
    late MockAudioRecorderRepository recorder;
    late MockAudioTranscriptionService transcriber;
    late MockRealtimeTranscriptionService realtimeService;
    late StreamController<Amplitude> ampController;
    late List<AudioNote> persistedNotes;
    JournalAudio? persistResult;

    setUp(() {
      recorder = MockAudioRecorderRepository();
      transcriber = MockAudioTranscriptionService();
      realtimeService = MockRealtimeTranscriptionService();
      ampController = StreamController<Amplitude>.broadcast();
      persistedNotes = <AudioNote>[];
      persistResult = _persistedAudio();

      // Realtime not configured → controller falls back to the batch
      // path for every test in this group.
      when(
        () => realtimeService.resolveRealtimeConfig(),
      ).thenAnswer((_) async => null);
      // `_cleanupSync` disposes the realtime service unconditionally so
      // route teardown also tears down any active realtime session. The
      // batch tests still hit it because the dispose call sits before
      // the realtime/batch branching.
      when(realtimeService.dispose).thenAnswer((_) async {});

      when(recorder.hasPermission).thenAnswer((_) async => true);
      when(
        () => recorder.amplitudeStream,
      ).thenAnswer((_) => ampController.stream);
      when(
        recorder.startRecording,
      ).thenAnswer((_) async => _audioNoteFixture());
      when(recorder.stopRecording).thenAnswer((_) async {});
      when(
        () => transcriber.transcribe(
          any(),
          speechDictionaryTerms: any(named: 'speechDictionaryTerms'),
        ),
      ).thenAnswer((_) async => '  hello world  ');
    });

    tearDown(() async {
      await ampController.close();
    });

    Future<JournalAudio?> persistAudio(AudioNote note) async {
      persistedNotes.add(note);
      return persistResult;
    }

    test('starts in the idle phase', () {
      final container = _aliveContainer(
        recorder: recorder,
        transcriber: transcriber,
        realtimeService: realtimeService,
        persistAudio: persistAudio,
      );
      addTearDown(container.dispose);

      final state = container.read(captureControllerProvider);
      expect(state.phase, CapturePhase.idle);
      expect(state.transcript, '');
      expect(state.amplitudes, isEmpty);
      expect(state.audioId, isNull);
    });

    test(
      'toggle from idle requests permission, starts recording, '
      'and streams normalised amplitudes',
      () async {
        final container = _aliveContainer(
          recorder: recorder,
          transcriber: transcriber,
          realtimeService: realtimeService,
          persistAudio: persistAudio,
        );
        addTearDown(container.dispose);

        await container.read(captureControllerProvider.notifier).toggle();
        expect(
          container.read(captureControllerProvider).phase,
          CapturePhase.listening,
        );
        verify(() => recorder.hasPermission()).called(1);
        verify(() => recorder.startRecording()).called(1);

        ampController.add(Amplitude(current: 0, max: 0));
        await Future<void>.delayed(Duration.zero);
        ampController.add(Amplitude(current: -22.5, max: 0));
        await Future<void>.delayed(Duration.zero);
        ampController.add(Amplitude(current: -60, max: 0));
        await Future<void>.delayed(Duration.zero);

        final amplitudes = container.read(captureControllerProvider).amplitudes;
        expect(amplitudes, hasLength(3));
        expect(amplitudes.first, closeTo(1.0, 0.001));
        expect(amplitudes[1], closeTo(0.5, 0.001));
        // Below the -45 floor clamps to 0.
        expect(amplitudes.last, closeTo(0.0, 0.001));
      },
    );

    test(
      'toggle from listening stops recording, transcribes, '
      'persists audio, and exposes audioId + transcript',
      () async {
        final container = _aliveContainer(
          recorder: recorder,
          transcriber: transcriber,
          realtimeService: realtimeService,
          persistAudio: persistAudio,
        );
        addTearDown(container.dispose);

        final notifier = container.read(captureControllerProvider.notifier);
        await notifier.toggle();
        await notifier.toggle();

        final state = container.read(captureControllerProvider);
        expect(state.phase, CapturePhase.captured);
        expect(state.transcript, 'hello world');
        expect(state.audioId, 'audio_001');
        expect(persistedNotes, hasLength(1));
        expect(persistedNotes.single.audioFile, 'capture.m4a');
        verify(() => recorder.stopRecording()).called(1);
      },
    );

    test(
      'toggle from listening surfaces transcription failure as error',
      () async {
        when(
          () => transcriber.transcribe(
            any(),
            speechDictionaryTerms: any(named: 'speechDictionaryTerms'),
          ),
        ).thenThrow(StateError('transcription down'));

        final container = _aliveContainer(
          recorder: recorder,
          transcriber: transcriber,
          realtimeService: realtimeService,
          persistAudio: persistAudio,
        );
        addTearDown(container.dispose);

        final notifier = container.read(captureControllerProvider.notifier);
        await notifier.toggle();
        await notifier.toggle();

        final state = container.read(captureControllerProvider);
        expect(state.phase, CapturePhase.error);
        expect(state.errorMessage, contains('Transcription failed'));
        expect(state.audioId, isNull);
        expect(persistedNotes, isEmpty);
      },
    );

    test('toggle without permission lands in the error phase', () async {
      when(() => recorder.hasPermission()).thenAnswer((_) async => false);

      final container = _aliveContainer(
        recorder: recorder,
        transcriber: transcriber,
        realtimeService: realtimeService,
        persistAudio: persistAudio,
      );
      addTearDown(container.dispose);

      await container.read(captureControllerProvider.notifier).toggle();

      final state = container.read(captureControllerProvider);
      expect(state.phase, CapturePhase.error);
      expect(state.errorMessage, contains('Microphone permission'));
      verifyNever(() => recorder.startRecording());
    });

    test(
      'toggle when startRecording returns null lands in the error phase',
      () async {
        when(() => recorder.startRecording()).thenAnswer((_) async => null);

        final container = _aliveContainer(
          recorder: recorder,
          transcriber: transcriber,
          realtimeService: realtimeService,
          persistAudio: persistAudio,
        );
        addTearDown(container.dispose);

        await container.read(captureControllerProvider.notifier).toggle();

        final state = container.read(captureControllerProvider);
        expect(state.phase, CapturePhase.error);
        expect(state.errorMessage, contains('Failed to start'));
      },
    );

    test('reset clears state back to idle from captured', () async {
      final container = _aliveContainer(
        recorder: recorder,
        transcriber: transcriber,
        realtimeService: realtimeService,
        persistAudio: persistAudio,
      );
      addTearDown(container.dispose);

      final notifier = container.read(captureControllerProvider.notifier);
      await notifier.toggle();
      await notifier.toggle();
      expect(
        container.read(captureControllerProvider).phase,
        CapturePhase.captured,
      );

      notifier.reset();
      final state = container.read(captureControllerProvider);
      expect(state.phase, CapturePhase.idle);
      expect(state.transcript, '');
      expect(state.amplitudes, isEmpty);
      expect(state.audioId, isNull);
    });
  });

  group('CaptureController (realtime path)', () {
    late MockRealtimeTranscriptionService realtimeService;
    late MockAudioTranscriptionService transcriber;
    late _FakeRealtimeRecorder fakeRecorder;
    late StreamController<double> realtimeAmpController;
    late StreamController<Uint8List> pcmController;
    late List<AudioNote> persistedNotes;
    late void Function(String delta)? capturedOnDelta;
    late ({AiConfigInferenceProvider provider, AiConfigModel model})
    realtimeConfig;

    setUp(() {
      realtimeService = MockRealtimeTranscriptionService();
      transcriber = MockAudioTranscriptionService();
      fakeRecorder = _FakeRealtimeRecorder();
      realtimeAmpController = StreamController<double>.broadcast();
      pcmController = StreamController<Uint8List>.broadcast();
      persistedNotes = <AudioNote>[];
      capturedOnDelta = null;
      realtimeConfig = (provider: _FakeProvider(), model: _FakeModel());

      fakeRecorder.pcmStream = pcmController.stream;

      when(
        () => realtimeService.resolveRealtimeConfig(),
      ).thenAnswer((_) async => realtimeConfig);
      when(realtimeService.dispose).thenAnswer((_) async {});
      when(
        () => realtimeService.amplitudeStream,
      ).thenAnswer((_) => realtimeAmpController.stream);
      when(
        () => realtimeService.startRealtimeTranscription(
          pcmStream: any(named: 'pcmStream'),
          onDelta: any(named: 'onDelta'),
          config: any(named: 'config'),
        ),
      ).thenAnswer((invocation) async {
        capturedOnDelta =
            invocation.namedArguments[#onDelta] as void Function(String);
      });
      when(
        () => realtimeService.stop(
          stopRecorder: any(named: 'stopRecorder'),
          outputPath: any(named: 'outputPath'),
        ),
      ).thenAnswer((invocation) async {
        final stopRecorder =
            invocation.namedArguments[#stopRecorder] as Future<void> Function();
        final outputPath = invocation.namedArguments[#outputPath] as String;
        await stopRecorder();
        return RealtimeStopResult(
          transcript: 'hello realtime',
          audioFilePath: '$outputPath.m4a',
        );
      });
      when(
        () => transcriber.transcribe(
          any(),
          speechDictionaryTerms: any(named: 'speechDictionaryTerms'),
        ),
      ).thenAnswer((_) async => 'hello realtime');
      when(realtimeService.dispose).thenAnswer((_) async {});
    });

    tearDown(() async {
      await realtimeAmpController.close();
      await pcmController.close();
    });

    Future<JournalAudio?> persistAudio(AudioNote note) async {
      persistedNotes.add(note);
      return _persistedAudio();
    }

    ProviderContainer buildContainer() {
      final container = ProviderContainer(
        overrides: [
          captureControllerProvider.overrideWith(
            () => CaptureController(
              realtimeService: realtimeService,
              transcriber: transcriber,
              realtimeRecorderFactory: () => fakeRecorder,
              persistAudio: persistAudio,
              docDir: Directory.systemTemp.createTempSync,
              now: () => _recordingStartedAt,
            ),
          ),
        ],
      )..listen(captureControllerProvider, (_, _) {});
      return container;
    }

    test(
      'toggle prefers realtime when configured, starts the WebSocket, '
      'and streams partialTranscript + amplitudes',
      () async {
        final container = buildContainer();
        addTearDown(container.dispose);

        await container.read(captureControllerProvider.notifier).toggle();

        expect(
          container.read(captureControllerProvider).phase,
          CapturePhase.listening,
        );
        verify(realtimeService.resolveRealtimeConfig).called(1);
        verify(
          () => realtimeService.startRealtimeTranscription(
            pcmStream: any(named: 'pcmStream'),
            onDelta: any(named: 'onDelta'),
            config: realtimeConfig,
          ),
        ).called(1);

        // Push a delta + amplitude sample; both should land in state.
        capturedOnDelta!('hello ');
        await Future<void>.delayed(Duration.zero);
        capturedOnDelta!('realtime');
        await Future<void>.delayed(Duration.zero);
        realtimeAmpController.add(0);
        await Future<void>.delayed(Duration.zero);

        final state = container.read(captureControllerProvider);
        expect(state.partialTranscript, 'hello realtime');
        expect(state.amplitudes, hasLength(1));
        expect(state.amplitudes.single, closeTo(1.0, 0.001));
      },
    );

    test(
      'toggle from listening stops the realtime service, persists the '
      'audio, and exposes the final transcript + audioId',
      () async {
        final container = buildContainer();
        addTearDown(container.dispose);

        final notifier = container.read(captureControllerProvider.notifier);
        await notifier.toggle();
        await notifier.toggle();

        final state = container.read(captureControllerProvider);
        expect(state.phase, CapturePhase.captured);
        expect(state.transcript, 'hello realtime');
        expect(state.audioId, 'audio_001');
        expect(persistedNotes, hasLength(1));
        expect(persistedNotes.single.audioFile, endsWith('.m4a'));
        expect(persistedNotes.single.audioDirectory, startsWith('/audio/'));
      },
    );

    test(
      'uses full-file transcription when realtime final text is truncated',
      () async {
        when(
          () => realtimeService.stop(
            stopRecorder: any(named: 'stopRecorder'),
            outputPath: any(named: 'outputPath'),
          ),
        ).thenAnswer((invocation) async {
          final stopRecorder =
              invocation.namedArguments[#stopRecorder]
                  as Future<void> Function();
          final outputPath = invocation.namedArguments[#outputPath] as String;
          await stopRecorder();
          return RealtimeStopResult(
            transcript: 'plan client animation',
            audioFilePath: '$outputPath.m4a',
          );
        });
        when(
          () => transcriber.transcribe(
            any(),
            speechDictionaryTerms: any(named: 'speechDictionaryTerms'),
          ),
        ).thenAnswer(
          (_) async => 'plan client animation and commission work for tomorrow',
        );
        final container = buildContainer();
        addTearDown(container.dispose);

        final notifier = container.read(captureControllerProvider.notifier);
        await notifier.toggle();
        await notifier.toggle();

        final state = container.read(captureControllerProvider);
        expect(
          state.transcript,
          'plan client animation and commission work for tomorrow',
        );
      },
    );

    test(
      'can keep realtime text without full-file batch verification',
      () async {
        when(
          () => realtimeService.stop(
            stopRecorder: any(named: 'stopRecorder'),
            outputPath: any(named: 'outputPath'),
          ),
        ).thenAnswer((invocation) async {
          final stopRecorder =
              invocation.namedArguments[#stopRecorder]
                  as Future<void> Function();
          final outputPath = invocation.namedArguments[#outputPath] as String;
          await stopRecorder();
          return RealtimeStopResult(
            transcript: 'mistral realtime text',
            audioFilePath: '$outputPath.m4a',
          );
        });
        when(
          () => transcriber.transcribe(
            any(),
            speechDictionaryTerms: any(named: 'speechDictionaryTerms'),
          ),
        ).thenAnswer((_) async => 'mlx batch text should not replace it');
        final container = buildContainer();
        addTearDown(container.dispose);

        final notifier = container.read(captureControllerProvider.notifier)
          ..skipRealtimeTranscriptVerificationForNextCapture();
        await notifier.toggle();
        await notifier.toggle();

        expect(
          container.read(captureControllerProvider).transcript,
          'mistral realtime text',
        );
        verifyNever(
          () => transcriber.transcribe(
            any(),
            speechDictionaryTerms: any(named: 'speechDictionaryTerms'),
          ),
        );
      },
    );

    test(
      'toggle without microphone permission lands in error and never '
      'starts the realtime WebSocket',
      () async {
        fakeRecorder.permissionGranted = false;

        final container = buildContainer();
        addTearDown(container.dispose);

        await container.read(captureControllerProvider.notifier).toggle();

        final state = container.read(captureControllerProvider);
        expect(state.phase, CapturePhase.error);
        expect(state.errorMessage, contains('Microphone permission'));
        verifyNever(
          () => realtimeService.startRealtimeTranscription(
            pcmStream: any(named: 'pcmStream'),
            onDelta: any(named: 'onDelta'),
            config: any(named: 'config'),
          ),
        );
      },
    );
  });

  group('CaptureState shape', () {
    test('CaptureState.idle initializes every field to a known default', () {
      const state = CaptureState.idle();
      expect(state.phase, CapturePhase.idle);
      expect(state.transcript, '');
      expect(state.partialTranscript, '');
      expect(state.amplitudes, isEmpty);
      expect(state.audioId, isNull);
      expect(state.errorMessage, isNull);
    });

    test('copyWith replaces only the supplied fields', () {
      const base = CaptureState(
        phase: CapturePhase.listening,
        transcript: 'hi',
        amplitudes: <double>[0.1, 0.2],
        partialTranscript: 'p',
        audioId: 'a-1',
      );

      final next = base.copyWith(
        phase: CapturePhase.captured,
        transcript: 'final',
        partialTranscript: '',
        amplitudes: const <double>[],
        audioId: 'a-2',
        errorMessage: 'broken',
      );

      expect(next.phase, CapturePhase.captured);
      expect(next.transcript, 'final');
      expect(next.partialTranscript, '');
      expect(next.amplitudes, isEmpty);
      expect(next.audioId, 'a-2');
      expect(next.errorMessage, 'broken');

      final partial = base.copyWith(transcript: 'updated');
      expect(partial.transcript, 'updated');
      expect(partial.phase, base.phase);
      expect(partial.amplitudes, base.amplitudes);
      expect(partial.audioId, base.audioId);
    });
  });

  group('CaptureController toggle edge phases + updateTranscript', () {
    late MockAudioRecorderRepository recorder;
    late MockAudioTranscriptionService transcriber;
    late MockRealtimeTranscriptionService realtimeService;
    late StreamController<Amplitude> ampController;

    setUp(() {
      recorder = MockAudioRecorderRepository();
      transcriber = MockAudioTranscriptionService();
      realtimeService = MockRealtimeTranscriptionService();
      ampController = StreamController<Amplitude>.broadcast();

      when(
        () => realtimeService.resolveRealtimeConfig(),
      ).thenAnswer((_) async => null);
      when(realtimeService.dispose).thenAnswer((_) async {});
      when(recorder.hasPermission).thenAnswer((_) async => true);
      when(
        () => recorder.amplitudeStream,
      ).thenAnswer((_) => ampController.stream);
      when(
        recorder.startRecording,
      ).thenAnswer((_) async => _audioNoteFixture());
      when(recorder.stopRecording).thenAnswer((_) async {});
      when(
        () => transcriber.transcribe(
          any(),
          speechDictionaryTerms: any(named: 'speechDictionaryTerms'),
        ),
      ).thenAnswer((_) async => 'hello world');
    });

    tearDown(() async {
      await ampController.close();
    });

    test(
      'updateTranscript is a no-op outside captured and edits in place '
      'once captured',
      () async {
        final container = _aliveContainer(
          recorder: recorder,
          transcriber: transcriber,
          realtimeService: realtimeService,
          persistAudio: (_) async => _persistedAudio(),
        );
        addTearDown(container.dispose);

        final notifier = container.read(captureControllerProvider.notifier)
          ..updateTranscript('ignored');
        expect(container.read(captureControllerProvider).transcript, '');

        await notifier.toggle();
        notifier.updateTranscript('ignored');
        expect(container.read(captureControllerProvider).transcript, '');

        await notifier.toggle();
        expect(
          container.read(captureControllerProvider).phase,
          CapturePhase.captured,
        );

        notifier.updateTranscript('user edited');
        expect(
          container.read(captureControllerProvider).transcript,
          'user edited',
        );
      },
    );

    test('toggle from captured calls reset and returns to idle', () async {
      final container = _aliveContainer(
        recorder: recorder,
        transcriber: transcriber,
        realtimeService: realtimeService,
        persistAudio: (_) async => _persistedAudio(),
      );
      addTearDown(container.dispose);

      final notifier = container.read(captureControllerProvider.notifier);
      await notifier.toggle();
      await notifier.toggle();
      expect(
        container.read(captureControllerProvider).phase,
        CapturePhase.captured,
      );

      await notifier.toggle();
      final state = container.read(captureControllerProvider);
      expect(state.phase, CapturePhase.idle);
      expect(state.transcript, '');
    });

    test('amplitudes arriving outside listening are ignored', () async {
      final container = _aliveContainer(
        recorder: recorder,
        transcriber: transcriber,
        realtimeService: realtimeService,
        persistAudio: (_) async => _persistedAudio(),
      );
      addTearDown(container.dispose);

      final notifier = container.read(captureControllerProvider.notifier);
      await notifier.toggle();
      await notifier.toggle(); // listening -> captured

      ampController.add(Amplitude(current: 0, max: 0));
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(captureControllerProvider).amplitudes,
        isEmpty,
      );
    });
  });

  group('CaptureController batch path — error and empty branches', () {
    late MockAudioRecorderRepository recorder;
    late MockAudioTranscriptionService transcriber;
    late MockRealtimeTranscriptionService realtimeService;
    late StreamController<Amplitude> ampController;

    setUp(() {
      recorder = MockAudioRecorderRepository();
      transcriber = MockAudioTranscriptionService();
      realtimeService = MockRealtimeTranscriptionService();
      ampController = StreamController<Amplitude>.broadcast();
      when(
        () => realtimeService.resolveRealtimeConfig(),
      ).thenAnswer((_) async => null);
      when(realtimeService.dispose).thenAnswer((_) async {});
      when(recorder.hasPermission).thenAnswer((_) async => true);
      when(
        () => recorder.amplitudeStream,
      ).thenAnswer((_) => ampController.stream);
      when(
        recorder.startRecording,
      ).thenAnswer((_) async => _audioNoteFixture());
      when(recorder.stopRecording).thenAnswer((_) async {});
    });

    tearDown(() async {
      await ampController.close();
    });

    test(
      'when persist throws, transcript still surfaces in captured phase',
      () async {
        when(
          () => transcriber.transcribe(
            any(),
            speechDictionaryTerms: any(named: 'speechDictionaryTerms'),
          ),
        ).thenAnswer((_) async => 'hello world');

        final container = _aliveContainer(
          recorder: recorder,
          transcriber: transcriber,
          realtimeService: realtimeService,
          persistAudio: (_) async => throw StateError('disk full'),
        );
        addTearDown(container.dispose);

        final notifier = container.read(captureControllerProvider.notifier);
        await notifier.toggle();
        await notifier.toggle();

        final state = container.read(captureControllerProvider);
        expect(state.phase, CapturePhase.captured);
        expect(state.transcript, 'hello world');
        expect(state.audioId, isNull);
      },
    );

    test(
      'persist returning null yields captured state without audioId',
      () async {
        when(
          () => transcriber.transcribe(
            any(),
            speechDictionaryTerms: any(named: 'speechDictionaryTerms'),
          ),
        ).thenAnswer((_) async => 'spoken');

        final container = _aliveContainer(
          recorder: recorder,
          transcriber: transcriber,
          realtimeService: realtimeService,
          persistAudio: (_) async => null,
        );
        addTearDown(container.dispose);

        final notifier = container.read(captureControllerProvider.notifier);
        await notifier.toggle();
        await notifier.toggle();

        final state = container.read(captureControllerProvider);
        expect(state.phase, CapturePhase.captured);
        expect(state.audioId, isNull);
      },
    );
  });

  group('CaptureController realtime path — error branches + resolver', () {
    late MockRealtimeTranscriptionService realtimeService;
    late MockAudioTranscriptionService transcriber;
    late _FakeRealtimeRecorder fakeRecorder;
    late StreamController<double> realtimeAmpController;
    late StreamController<Uint8List> pcmController;

    setUp(() {
      realtimeService = MockRealtimeTranscriptionService();
      transcriber = MockAudioTranscriptionService();
      fakeRecorder = _FakeRealtimeRecorder();
      realtimeAmpController = StreamController<double>.broadcast();
      pcmController = StreamController<Uint8List>.broadcast();
      fakeRecorder.pcmStream = pcmController.stream;

      when(
        () => realtimeService.resolveRealtimeConfig(),
      ).thenAnswer(
        (_) async => (provider: _FakeProvider(), model: _FakeModel()),
      );
      when(
        () => realtimeService.amplitudeStream,
      ).thenAnswer((_) => realtimeAmpController.stream);
      when(realtimeService.dispose).thenAnswer((_) async {});
    });

    tearDown(() async {
      await realtimeAmpController.close();
      await pcmController.close();
    });

    ProviderContainer buildContainer({
      Future<JournalAudio?> Function(AudioNote)? persistAudio,
    }) {
      final container = ProviderContainer(
        overrides: [
          captureControllerProvider.overrideWith(
            () => CaptureController(
              realtimeService: realtimeService,
              transcriber: transcriber,
              realtimeRecorderFactory: () => fakeRecorder,
              persistAudio: persistAudio ?? ((_) async => _persistedAudio()),
              docDir: Directory.systemTemp.createTempSync,
              now: () => _recordingStartedAt,
            ),
          ),
        ],
      )..listen(captureControllerProvider, (_, _) {});
      return container;
    }

    test('startStream throwing surfaces an error state', () async {
      fakeRecorder.throwOnStartStream = true;

      final container = buildContainer();
      addTearDown(container.dispose);

      await container.read(captureControllerProvider.notifier).toggle();

      final state = container.read(captureControllerProvider);
      expect(state.phase, CapturePhase.error);
      expect(state.errorMessage, contains('Failed to start recording'));
      expect(fakeRecorder.disposed, isTrue);
    });

    test(
      'startRealtimeTranscription throwing surfaces error and disposes recorder',
      () async {
        when(
          () => realtimeService.startRealtimeTranscription(
            pcmStream: any(named: 'pcmStream'),
            onDelta: any(named: 'onDelta'),
            config: any(named: 'config'),
          ),
        ).thenThrow(StateError('socket failed'));

        final container = buildContainer();
        addTearDown(container.dispose);

        await container.read(captureControllerProvider.notifier).toggle();

        final state = container.read(captureControllerProvider);
        expect(state.phase, CapturePhase.error);
        expect(
          state.errorMessage,
          contains('Failed to start realtime transcription'),
        );
      },
    );

    test(
      'realtime stop throwing surfaces error and disposes recorder',
      () async {
        when(
          () => realtimeService.startRealtimeTranscription(
            pcmStream: any(named: 'pcmStream'),
            onDelta: any(named: 'onDelta'),
            config: any(named: 'config'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => realtimeService.stop(
            stopRecorder: any(named: 'stopRecorder'),
            outputPath: any(named: 'outputPath'),
          ),
        ).thenThrow(StateError('drain failed'));

        final container = buildContainer();
        addTearDown(container.dispose);

        final notifier = container.read(captureControllerProvider.notifier);
        await notifier.toggle();
        await notifier.toggle();

        final state = container.read(captureControllerProvider);
        expect(state.phase, CapturePhase.error);
        expect(state.errorMessage, contains('Realtime transcription failed'));
        expect(fakeRecorder.disposed, isTrue);
      },
    );

    test(
      'falls back to realtime transcript when batch transcriber throws',
      () async {
        when(
          () => realtimeService.startRealtimeTranscription(
            pcmStream: any(named: 'pcmStream'),
            onDelta: any(named: 'onDelta'),
            config: any(named: 'config'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => realtimeService.stop(
            stopRecorder: any(named: 'stopRecorder'),
            outputPath: any(named: 'outputPath'),
          ),
        ).thenAnswer((invocation) async {
          final stopRecorder =
              invocation.namedArguments[#stopRecorder]
                  as Future<void> Function();
          final outputPath = invocation.namedArguments[#outputPath] as String;
          await stopRecorder();
          return RealtimeStopResult(
            transcript: 'realtime text',
            audioFilePath: '$outputPath.m4a',
          );
        });
        when(
          () => transcriber.transcribe(
            any(),
            speechDictionaryTerms: any(named: 'speechDictionaryTerms'),
          ),
        ).thenThrow(StateError('boom'));

        final container = buildContainer();
        addTearDown(container.dispose);

        final notifier = container.read(captureControllerProvider.notifier);
        await notifier.toggle();
        await notifier.toggle();

        expect(
          container.read(captureControllerProvider).transcript,
          'realtime text',
        );
      },
    );

    test(
      'prefers the batch transcript when realtime used its fallback path',
      () async {
        when(
          () => realtimeService.startRealtimeTranscription(
            pcmStream: any(named: 'pcmStream'),
            onDelta: any(named: 'onDelta'),
            config: any(named: 'config'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => realtimeService.stop(
            stopRecorder: any(named: 'stopRecorder'),
            outputPath: any(named: 'outputPath'),
          ),
        ).thenAnswer((invocation) async {
          final stopRecorder =
              invocation.namedArguments[#stopRecorder]
                  as Future<void> Function();
          final outputPath = invocation.namedArguments[#outputPath] as String;
          await stopRecorder();
          return RealtimeStopResult(
            transcript: 'partial realtime',
            audioFilePath: '$outputPath.m4a',
            usedTranscriptFallback: true,
          );
        });
        when(
          () => transcriber.transcribe(
            any(),
            speechDictionaryTerms: any(named: 'speechDictionaryTerms'),
          ),
        ).thenAnswer((_) async => 'clean batch transcript');

        final container = buildContainer();
        addTearDown(container.dispose);

        final notifier = container.read(captureControllerProvider.notifier);
        await notifier.toggle();
        await notifier.toggle();

        expect(
          container.read(captureControllerProvider).transcript,
          'clean batch transcript',
        );
      },
    );

    test(
      'keeps the realtime transcript when no audio file is written',
      () async {
        when(
          () => realtimeService.startRealtimeTranscription(
            pcmStream: any(named: 'pcmStream'),
            onDelta: any(named: 'onDelta'),
            config: any(named: 'config'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => realtimeService.stop(
            stopRecorder: any(named: 'stopRecorder'),
            outputPath: any(named: 'outputPath'),
          ),
        ).thenAnswer((invocation) async {
          final stopRecorder =
              invocation.namedArguments[#stopRecorder]
                  as Future<void> Function();
          await stopRecorder();
          return const RealtimeStopResult(transcript: 'realtime only');
        });

        final container = buildContainer();
        addTearDown(container.dispose);

        final notifier = container.read(captureControllerProvider.notifier);
        await notifier.toggle();
        await notifier.toggle();

        expect(
          container.read(captureControllerProvider).transcript,
          'realtime only',
        );
        verifyNever(
          () => transcriber.transcribe(
            any(),
            speechDictionaryTerms: any(named: 'speechDictionaryTerms'),
          ),
        );
      },
    );
  });

  group('CaptureController attaches batch transcripts to journal audio', () {
    late MockAudioRecorderRepository recorder;
    late MockAudioTranscriptionService transcriber;
    late MockRealtimeTranscriptionService realtimeService;
    late StreamController<Amplitude> ampController;
    late MockPersistenceLogic persistenceLogic;
    JournalAudio? latestUpdated;

    setUp(() async {
      await getIt.reset();
      recorder = MockAudioRecorderRepository();
      transcriber = MockAudioTranscriptionService();
      realtimeService = MockRealtimeTranscriptionService();
      ampController = StreamController<Amplitude>.broadcast();
      persistenceLogic = MockPersistenceLogic();
      latestUpdated = null;

      when(
        () => realtimeService.resolveRealtimeConfig(),
      ).thenAnswer((_) async => null);
      when(realtimeService.dispose).thenAnswer((_) async {});
      when(recorder.hasPermission).thenAnswer((_) async => true);
      when(
        () => recorder.amplitudeStream,
      ).thenAnswer((_) => ampController.stream);
      when(
        recorder.startRecording,
      ).thenAnswer((_) async => _audioNoteFixture());
      when(recorder.stopRecording).thenAnswer((_) async {});

      registerFallbackValue(
        Metadata(
          id: 'fallback-meta',
          createdAt: _recordingStartedAt,
          updatedAt: _recordingStartedAt,
          dateFrom: _recordingStartedAt,
          dateTo: _recordingStartedAt,
          vectorClock: const VectorClock(<String, int>{}),
        ),
      );
      registerFallbackValue(_persistedAudio());

      when(
        () => persistenceLogic.updateMetadata(any()),
      ).thenAnswer(
        (invocation) async => invocation.positionalArguments.first as Metadata,
      );
      when(
        () => persistenceLogic.updateDbEntity(any()),
      ).thenAnswer((invocation) async {
        latestUpdated = invocation.positionalArguments.first as JournalAudio;
        return true;
      });

      getIt.registerSingleton<PersistenceLogic>(persistenceLogic);
    });

    tearDown(() async {
      await ampController.close();
      await getIt.reset();
    });

    test(
      'batch capture writes an AudioTranscript and mirrors the entry text',
      () async {
        when(
          () => transcriber.transcribe(
            any(),
            speechDictionaryTerms: any(named: 'speechDictionaryTerms'),
          ),
        ).thenAnswer((_) async => 'hello journal');

        final container = _aliveContainer(
          recorder: recorder,
          transcriber: transcriber,
          realtimeService: realtimeService,
          persistAudio: (_) async => _persistedAudio(),
        );
        addTearDown(container.dispose);

        final notifier = container.read(captureControllerProvider.notifier);
        await notifier.toggle();
        await notifier.toggle();

        expect(latestUpdated, isNotNull);
        final transcript = latestUpdated!.data.transcripts!.single;
        expect(transcript.transcript, 'hello journal');
        expect(transcript.library, 'batch-transcribe');
        expect(latestUpdated!.entryText, isA<EntryText>());
        expect(latestUpdated!.entryText!.plainText, 'hello journal');
      },
    );

    test(
      'empty batch transcript skips the journal-audio attach step',
      () async {
        when(
          () => transcriber.transcribe(
            any(),
            speechDictionaryTerms: any(named: 'speechDictionaryTerms'),
          ),
        ).thenAnswer((_) async => '   ');

        final container = _aliveContainer(
          recorder: recorder,
          transcriber: transcriber,
          realtimeService: realtimeService,
          persistAudio: (_) async => _persistedAudio(),
        );
        addTearDown(container.dispose);

        final notifier = container.read(captureControllerProvider.notifier);
        await notifier.toggle();
        await notifier.toggle();

        expect(latestUpdated, isNull);
        expect(
          container.read(captureControllerProvider).transcript,
          '',
        );
      },
    );
  });
}

class _FakeRealtimeRecorder implements record.AudioRecorder {
  bool permissionGranted = true;
  Stream<Uint8List>? pcmStream;
  bool stopped = false;
  bool disposed = false;
  bool throwOnStartStream = false;

  @override
  Future<bool> hasPermission({bool request = true}) async => permissionGranted;

  @override
  Future<Stream<Uint8List>> startStream(record.RecordConfig config) async {
    if (throwOnStartStream) {
      throw StateError('mic busy');
    }
    if (pcmStream == null) {
      throw StateError('pcmStream not configured');
    }
    return pcmStream!;
  }

  @override
  Future<String?> stop() async {
    stopped = true;
    return null;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    // Stubs the long tail of recorder methods the controller does not
    // touch. Returning `null` is safe for the calls we actually make
    // (`hasPermission`, `startStream`, `stop`, `dispose` are overridden
    // above).
    return null;
  }
}

class _FakeProvider implements AiConfigInferenceProvider {
  @override
  String get name => 'fake-provider';

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeModel implements AiConfigModel {
  @override
  String get providerModelId => 'fake-model';

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
