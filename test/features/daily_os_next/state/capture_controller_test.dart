import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/audio_note.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/realtime_transcription_event.dart';
import 'package:lotti/features/daily_os_next/state/capture_controller.dart';
import 'package:lotti/features/sync/vector_clock.dart';
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
        () => realtimeService.resolveRealtimeConfig(
          preferMistral: any(named: 'preferMistral'),
        ),
      ).thenAnswer((_) async => null);

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
        () => realtimeService.resolveRealtimeConfig(
          preferMistral: any(named: 'preferMistral'),
        ),
      ).thenAnswer((_) async => realtimeConfig);
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
        verify(
          () => realtimeService.resolveRealtimeConfig(
            preferMistral: true,
          ),
        ).called(1);
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
}

class _FakeRealtimeRecorder implements record.AudioRecorder {
  bool permissionGranted = true;
  Stream<Uint8List>? pcmStream;
  bool stopped = false;
  bool disposed = false;

  @override
  Future<bool> hasPermission({bool request = true}) async => permissionGranted;

  @override
  Future<Stream<Uint8List>> startStream(record.RecordConfig config) async {
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
