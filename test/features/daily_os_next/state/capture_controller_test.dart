import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/audio_note.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/realtime_transcription_event.dart';
import 'package:lotti/features/ai_chat/services/realtime_transcription_service.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_job.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_outbox_repository.dart';
import 'package:lotti/features/daily_os_next/state/capture_controller.dart';
import 'package:lotti/features/speech/services/durable_audio_spool.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:mocktail/mocktail.dart';
import 'package:record/record.dart' as record;
import 'package:record/record.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

final _recordingStartedAt = DateTime(2026, 5, 26, 9);

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
      audioFile: 'capture.wav',
      audioDirectory: '/audio/2026-05-26/',
      duration: const Duration(seconds: 2),
    ),
  );
}

/// Builds the standard kept-alive container with a caller-owned raw recorder.
ProviderContainer _aliveContainer({
  required MockAudioTranscriptionService transcriber,
  required MockRealtimeTranscriptionService realtimeService,
  required Future<JournalAudio?> Function(AudioNote) persistAudio,
  AudioRecorder Function()? realtimeRecorderFactory,
  Directory Function()? docDir,
  DayProcessingOutboxRepository? processingOutbox,
}) {
  when(
    () => realtimeService.stopAndRetainForRecovery(
      capture: any(named: 'capture'),
      stopRecorder: any(named: 'stopRecorder'),
    ),
  ).thenAnswer((invocation) async {
    final stopRecorder =
        invocation.namedArguments[#stopRecorder] as Future<void> Function();
    await stopRecorder();
  });
  final container = ProviderContainer(
    overrides: [
      captureControllerProvider.overrideWith(
        () => CaptureController(
          transcriber: transcriber,
          realtimeService: realtimeService,
          realtimeRecorderFactory: realtimeRecorderFactory,
          persistAudio: persistAudio,
          processingOutbox: processingOutbox,
          docDir: docDir ?? Directory.systemTemp.createTempSync,
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
    registerAllFallbackValues();
    registerFallbackValue(fallbackAudioCaptureOrigin);
    registerFallbackValue(fallbackAudioCaptureIntent);
    registerFallbackValue(_StreamFallback());
    registerFallbackValue(_StopRecorderFallback().call);
    registerFallbackValue(Directory('/tmp'));
    registerFallbackValue(DateTime(2026, 5, 26));
    registerFallbackValue(MockDurableRealtimeCapture());
  });

  group('CaptureController (realtime path)', () {
    late MockRealtimeTranscriptionService realtimeService;
    late MockAudioTranscriptionService transcriber;
    late MockDurableRealtimeCapture durableCapture;
    late _FakeRealtimeRecorder fakeRecorder;
    late StreamController<double> realtimeAmpController;
    late StreamController<Uint8List> pcmController;
    late List<AudioNote> persistedNotes;
    late void Function(String delta)? capturedOnDelta;
    late RealtimeCaptureFailureCallback? capturedOnCaptureFailure;
    late ({AiConfigInferenceProvider provider, AiConfigModel model})
    realtimeConfig;

    setUp(() {
      realtimeService = MockRealtimeTranscriptionService();
      transcriber = MockAudioTranscriptionService();
      durableCapture = MockDurableRealtimeCapture();
      when(() => durableCapture.recordingSessionId).thenReturn('test-session');
      when(() => durableCapture.activityEntryId).thenReturn('activity-1');
      when(() => durableCapture.acceptedPcmBytes).thenReturn(0);
      fakeRecorder = _FakeRealtimeRecorder();
      realtimeAmpController = StreamController<double>.broadcast();
      pcmController = StreamController<Uint8List>.broadcast();
      persistedNotes = <AudioNote>[];
      capturedOnDelta = null;
      capturedOnCaptureFailure = null;
      realtimeConfig = (provider: _FakeProvider(), model: _FakeModel());

      fakeRecorder.pcmStream = pcmController.stream;

      when(
        () => realtimeService.resolveRealtimeConfig(),
      ).thenAnswer((_) async => realtimeConfig);
      when(
        () => realtimeService.prepareDefaultDurableCapture(
          assetRootDirectory: any(named: 'assetRootDirectory'),
          createdAt: any(named: 'createdAt'),
          origin: any(named: 'origin'),
          intent: any(named: 'intent'),
          dayId: any(named: 'dayId'),
          planDate: any(named: 'planDate'),
        ),
      ).thenAnswer((_) async => durableCapture);
      when(durableCapture.discard).thenAnswer((_) async {});
      when(
        () => durableCapture.markCommitted(
          journalAudioId: any(named: 'journalAudioId'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => realtimeService.amplitudeStream,
      ).thenAnswer((_) => realtimeAmpController.stream);
      when(
        () => realtimeService.startRealtimeTranscription(
          capture: any(named: 'capture'),
          pcmStream: any(named: 'pcmStream'),
          onDelta: any(named: 'onDelta'),
          onCaptureFailure: any(named: 'onCaptureFailure'),
          config: any(named: 'config'),
          resolveConfigWhenAbsent: false,
        ),
      ).thenAnswer((invocation) async {
        capturedOnDelta =
            invocation.namedArguments[#onDelta] as void Function(String);
        capturedOnCaptureFailure =
            invocation.namedArguments[#onCaptureFailure]
                as RealtimeCaptureFailureCallback;
      });
      when(
        () => realtimeService.stop(
          capture: any(named: 'capture'),
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
          recordingSessionId: 'test-session',
          audioFilePath: '$outputPath.wav',
          captureDisposition: RealtimeCaptureDisposition.complete,
          audioDuration: const Duration(seconds: 2),
        );
      });
      when(
        () => transcriber.transcribe(
          any(),
          speechDictionaryTerms: any(named: 'speechDictionaryTerms'),
        ),
      ).thenAnswer((_) async => 'hello realtime');
    });

    tearDown(() async {
      await realtimeAmpController.close();
      await pcmController.close();
    });

    Future<JournalAudio?> persistAudio(AudioNote note) async {
      persistedNotes.add(note);
      return _persistedAudio();
    }

    ProviderContainer buildContainer() => _aliveContainer(
      transcriber: transcriber,
      realtimeService: realtimeService,
      persistAudio: persistAudio,
      realtimeRecorderFactory: () => fakeRecorder,
    );

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
            capture: any(named: 'capture'),
            pcmStream: any(named: 'pcmStream'),
            onDelta: any(named: 'onDelta'),
            onCaptureFailure: any(named: 'onCaptureFailure'),
            config: realtimeConfig,
            resolveConfigWhenAbsent: false,
          ),
        ).called(1);

        // Push a delta + amplitude sample; both should land in state.
        capturedOnDelta!('hello ');
        await pumpEventQueue();
        capturedOnDelta!('realtime');
        await pumpEventQueue();
        realtimeAmpController.add(0);
        await pumpEventQueue();

        final state = container.read(captureControllerProvider);
        expect(state.partialTranscript, 'hello realtime');
        expect(state.amplitudes, hasLength(1));
        expect(state.amplitudes.single, closeTo(1.0, 0.001));
        expect(state.dbfs, 0);
      },
    );

    test(
      'keeps the durable PCM owner and batch-transcribes when no live '
      'backend is configured',
      () async {
        when(
          realtimeService.resolveRealtimeConfig,
        ).thenAnswer((_) async => null);
        final container = buildContainer();
        addTearDown(container.dispose);
        final notifier = container.read(captureControllerProvider.notifier);

        await notifier.toggle();

        expect(
          container.read(captureControllerProvider).phase,
          CapturePhase.listening,
        );
        verify(
          () => realtimeService.startRealtimeTranscription(
            capture: durableCapture,
            pcmStream: any(named: 'pcmStream'),
            onDelta: any(named: 'onDelta'),
            onCaptureFailure: any(named: 'onCaptureFailure'),
            config: any(named: 'config'),
            resolveConfigWhenAbsent: false,
          ),
        ).called(1);

        await notifier.toggle();

        final state = container.read(captureControllerProvider);
        expect(state.phase, CapturePhase.captured);
        expect(state.transcript, 'hello realtime');
        expect(state.audioId, 'audio_001');
        expect(persistedNotes, hasLength(1));
        verify(
          () => transcriber.transcribe(
            any(),
            speechDictionaryTerms: any(named: 'speechDictionaryTerms'),
          ),
        ).called(1);
      },
    );

    test(
      'prepares day-scoped durability before requesting the microphone',
      () async {
        final events = <String>[];
        fakeRecorder.onCall = events.add;
        when(
          () => realtimeService.prepareDefaultDurableCapture(
            assetRootDirectory: any(named: 'assetRootDirectory'),
            createdAt: any(named: 'createdAt'),
            origin: any(named: 'origin'),
            intent: any(named: 'intent'),
            dayId: any(named: 'dayId'),
            planDate: any(named: 'planDate'),
          ),
        ).thenAnswer((_) async {
          events.add('prepare');
          return durableCapture;
        });
        final container = buildContainer();
        addTearDown(container.dispose);

        await container
            .read(captureControllerProvider.notifier)
            .toggle(forDate: DateTime(2026, 5, 24));

        expect(
          events.take(3),
          orderedEquals(<String>['prepare', 'permission', 'stream']),
        );
        verify(
          () => realtimeService.prepareDefaultDurableCapture(
            assetRootDirectory: any(named: 'assetRootDirectory'),
            createdAt: _recordingStartedAt,
            origin: AudioCaptureOrigin.dailyOs,
            intent: AudioCaptureIntent.dayPlan,
            dayId: 'dayplan-2026-05-24',
            planDate: DateTime(2026, 5, 24),
          ),
        ).called(1);
        verify(
          () => realtimeService.startRealtimeTranscription(
            capture: durableCapture,
            pcmStream: any(named: 'pcmStream'),
            onDelta: any(named: 'onDelta'),
            onCaptureFailure: any(named: 'onCaptureFailure'),
            config: realtimeConfig,
            resolveConfigWhenAbsent: false,
          ),
        ).called(1);
      },
    );

    test(
      'does not open the microphone when durable admission fails',
      () async {
        final events = <String>[];
        fakeRecorder.onCall = events.add;
        when(
          () => realtimeService.prepareDefaultDurableCapture(
            assetRootDirectory: any(named: 'assetRootDirectory'),
            createdAt: any(named: 'createdAt'),
            origin: any(named: 'origin'),
            intent: any(named: 'intent'),
            dayId: any(named: 'dayId'),
            planDate: any(named: 'planDate'),
          ),
        ).thenThrow(StateError('spool unavailable'));
        final container = buildContainer();
        addTearDown(container.dispose);

        await container.read(captureControllerProvider.notifier).toggle();

        expect(
          container.read(captureControllerProvider),
          isA<CaptureState>()
              .having((value) => value.phase, 'phase', CapturePhase.error)
              .having(
                (value) => value.error,
                'error',
                CaptureError.recordingStartFailed,
              ),
        );
        expect(events, isEmpty);
        verifyNever(realtimeService.resolveRealtimeConfig);
        verifyNever(
          () => realtimeService.startRealtimeTranscription(
            capture: any(named: 'capture'),
            pcmStream: any(named: 'pcmStream'),
            onDelta: any(named: 'onDelta'),
            onCaptureFailure: any(named: 'onCaptureFailure'),
            config: any(named: 'config'),
            resolveConfigWhenAbsent: false,
          ),
        );
      },
    );

    test('reset fences a slow durable capture preparation', () async {
      final preparation = Completer<DurableRealtimeCapture>();
      final events = <String>[];
      fakeRecorder.onCall = events.add;
      when(
        () => realtimeService.prepareDefaultDurableCapture(
          assetRootDirectory: any(named: 'assetRootDirectory'),
          createdAt: any(named: 'createdAt'),
          origin: any(named: 'origin'),
          intent: any(named: 'intent'),
          dayId: any(named: 'dayId'),
          planDate: any(named: 'planDate'),
        ),
      ).thenAnswer((_) => preparation.future);
      final container = buildContainer();
      addTearDown(container.dispose);
      final notifier = container.read(captureControllerProvider.notifier);

      final start = notifier.toggle();
      await pumpEventQueue();
      notifier.reset();
      preparation.complete(durableCapture);
      await start;

      expect(
        container.read(captureControllerProvider).phase,
        CapturePhase.idle,
      );
      expect(events, isEmpty);
      verify(durableCapture.discard).called(1);
      verifyNever(realtimeService.resolveRealtimeConfig);
    });

    test(
      'continues with durable batch capture when config lookup fails',
      () async {
        when(
          realtimeService.resolveRealtimeConfig,
        ).thenThrow(StateError('configuration database unavailable'));
        final container = buildContainer();
        addTearDown(container.dispose);
        final notifier = container.read(captureControllerProvider.notifier);

        await notifier.toggle();
        await notifier.toggle();

        expect(
          container.read(captureControllerProvider),
          isA<CaptureState>()
              .having((value) => value.phase, 'phase', CapturePhase.captured)
              .having(
                (value) => value.transcript,
                'transcript',
                'hello realtime',
              ),
        );
        verify(
          () => realtimeService.startRealtimeTranscription(
            capture: durableCapture,
            pcmStream: any(named: 'pcmStream'),
            onDelta: any(named: 'onDelta'),
            onCaptureFailure: any(named: 'onCaptureFailure'),
            resolveConfigWhenAbsent: false,
          ),
        ).called(1);
      },
    );

    test(
      'reset fences slow config resolution after durable admission',
      () async {
        final resolution =
            Completer<
              ({AiConfigInferenceProvider provider, AiConfigModel model})?
            >();
        when(
          realtimeService.resolveRealtimeConfig,
        ).thenAnswer((_) => resolution.future);
        final container = buildContainer();
        addTearDown(container.dispose);
        final notifier = container.read(captureControllerProvider.notifier);

        final start = notifier.toggle();
        await pumpEventQueue();
        notifier.reset();
        resolution.complete(realtimeConfig);
        await start;

        expect(
          container.read(captureControllerProvider).phase,
          CapturePhase.idle,
        );
        verify(durableCapture.discard).called(1);
        verifyNever(
          () => realtimeService.startRealtimeTranscription(
            capture: any(named: 'capture'),
            pcmStream: any(named: 'pcmStream'),
            onDelta: any(named: 'onDelta'),
            onCaptureFailure: any(named: 'onCaptureFailure'),
            config: any(named: 'config'),
            resolveConfigWhenAbsent: false,
          ),
        );
      },
    );

    test('reset fences slow microphone permission resolution', () async {
      final permission = Completer<bool>();
      fakeRecorder.permissionFuture = permission.future;
      final container = buildContainer();
      addTearDown(container.dispose);
      final notifier = container.read(captureControllerProvider.notifier);

      final start = notifier.toggle();
      await pumpEventQueue();
      notifier.reset();
      permission.complete(true);
      await start;

      expect(
        container.read(captureControllerProvider).phase,
        CapturePhase.idle,
      );
      expect(fakeRecorder.disposed, isTrue);
      verify(durableCapture.discard).called(1);
    });

    test('reset drains a PCM stream opened by an obsolete start', () async {
      final stream = Completer<Stream<Uint8List>>();
      fakeRecorder.startStreamFuture = stream.future;
      final container = buildContainer();
      addTearDown(container.dispose);
      final notifier = container.read(captureControllerProvider.notifier);

      final start = notifier.toggle();
      await pumpEventQueue();
      notifier.reset();
      stream.complete(pcmController.stream);
      await start;

      expect(
        container.read(captureControllerProvider).phase,
        CapturePhase.idle,
      );
      expect(fakeRecorder.stopCalls, 1);
      expect(fakeRecorder.disposed, isTrue);
      verify(durableCapture.discard).called(1);
    });

    test(
      'reset retains capture when realtime startup completes late',
      () async {
        final realtimeStart = Completer<void>();
        when(
          () => realtimeService.startRealtimeTranscription(
            capture: any(named: 'capture'),
            pcmStream: any(named: 'pcmStream'),
            onDelta: any(named: 'onDelta'),
            onCaptureFailure: any(named: 'onCaptureFailure'),
            config: any(named: 'config'),
            resolveConfigWhenAbsent: false,
          ),
        ).thenAnswer((_) => realtimeStart.future);
        final container = buildContainer();
        addTearDown(container.dispose);
        final notifier = container.read(captureControllerProvider.notifier);

        final start = notifier.toggle();
        await pumpEventQueue();
        expect(
          container.read(captureControllerProvider).phase,
          CapturePhase.listening,
        );
        notifier.reset();
        realtimeStart.complete();
        await start;
        await pumpEventQueue();

        expect(
          container.read(captureControllerProvider).phase,
          CapturePhase.idle,
        );
        verify(
          () => realtimeService.stopAndRetainForRecovery(
            capture: durableCapture,
            stopRecorder: any(named: 'stopRecorder'),
          ),
        ).called(2);
        expect(fakeRecorder.disposed, isTrue);
      },
    );

    test(
      'audio destination failure discards before microphone start',
      () async {
        final root = Directory.systemTemp.createTempSync(
          'capture-destination-failure-',
        );
        addTearDown(() => root.deleteSync(recursive: true));
        final blocker = File('${root.path}/not-a-directory')
          ..writeAsStringSync('occupied');
        final recorderEvents = <String>[];
        fakeRecorder.onCall = recorderEvents.add;
        final container = _aliveContainer(
          transcriber: transcriber,
          realtimeService: realtimeService,
          persistAudio: persistAudio,
          realtimeRecorderFactory: () => fakeRecorder,
          docDir: () => Directory(blocker.path),
        );
        addTearDown(container.dispose);

        await container.read(captureControllerProvider.notifier).toggle();

        expect(
          container.read(captureControllerProvider),
          isA<CaptureState>()
              .having((value) => value.phase, 'phase', CapturePhase.error)
              .having(
                (value) => value.error,
                'error',
                CaptureError.recordingStartFailed,
              ),
        );
        expect(fakeRecorder.disposed, isTrue);
        verify(durableCapture.discard).called(1);
        expect(recorderEvents, ['permission']);
      },
    );

    test('capture failure immediately stops into retained recovery', () async {
      when(
        () => realtimeService.stop(
          capture: any(named: 'capture'),
          stopRecorder: any(named: 'stopRecorder'),
          outputPath: any(named: 'outputPath'),
        ),
      ).thenAnswer((invocation) async {
        final stopRecorder =
            invocation.namedArguments[#stopRecorder] as Future<void> Function();
        await stopRecorder();
        return RealtimeStopResult(
          transcript: 'recoverable partial',
          recordingSessionId: 'test-session',
          audioFilePath: '/tmp/recoverable.wav',
          captureDisposition: RealtimeCaptureDisposition.savedPartial,
        );
      });
      final container = buildContainer();
      addTearDown(container.dispose);
      await container.read(captureControllerProvider.notifier).toggle();

      capturedOnCaptureFailure!(
        StateError('spool saturated'),
        StackTrace.current,
      );
      await pumpEventQueue();

      final state = container.read(captureControllerProvider);
      expect(state.phase, CapturePhase.error);
      expect(state.error, CaptureError.recordingRetainedForRecovery);
      expect(state.transcript, 'recoverable partial');
      expect(fakeRecorder.stopCalls, 1);
      verify(
        () => realtimeService.stop(
          capture: any(named: 'capture'),
          stopRecorder: any(named: 'stopRecorder'),
          outputPath: any(named: 'outputPath'),
        ),
      ).called(1);
    });

    test(
      'realtime stop failure reports retained audio when PCM was accepted',
      () async {
        when(() => durableCapture.acceptedPcmBytes).thenReturn(128);
        // Re-stub stop to throw (last-wins over the group setUp stub).
        when(
          () => realtimeService.stop(
            capture: any(named: 'capture'),
            stopRecorder: any(named: 'stopRecorder'),
            outputPath: any(named: 'outputPath'),
          ),
        ).thenThrow(StateError('websocket dropped'));

        final container = buildContainer();
        addTearDown(container.dispose);
        final notifier = container.read(captureControllerProvider.notifier);

        await notifier.toggle(); // start realtime
        await notifier.toggle(); // stop -> service throws

        final state = container.read(captureControllerProvider);
        expect(state.phase, CapturePhase.error);
        expect(state.error, CaptureError.recordingRetainedForRecovery);
        // Nothing was persisted for the failed capture.
        expect(persistedNotes, isEmpty);
      },
    );

    test('rejects a stop result from another durable capture', () async {
      when(
        () => realtimeService.stop(
          capture: any(named: 'capture'),
          stopRecorder: any(named: 'stopRecorder'),
          outputPath: any(named: 'outputPath'),
        ),
      ).thenAnswer(
        (_) async => RealtimeStopResult(
          transcript: 'wrong session',
          recordingSessionId: 'another-session',
          captureDisposition: RealtimeCaptureDisposition.complete,
        ),
      );
      final container = buildContainer();
      addTearDown(container.dispose);
      final notifier = container.read(captureControllerProvider.notifier);

      await notifier.toggle();
      await notifier.toggle();

      expect(
        container.read(captureControllerProvider),
        isA<CaptureState>()
            .having((value) => value.phase, 'phase', CapturePhase.error)
            .having(
              (value) => value.error,
              'error',
              CaptureError.noAudioRecorded,
            ),
      );
      expect(persistedNotes, isEmpty);
    });

    test('complete stop without a WAV reports no recorded audio', () async {
      when(
        () => realtimeService.stop(
          capture: any(named: 'capture'),
          stopRecorder: any(named: 'stopRecorder'),
          outputPath: any(named: 'outputPath'),
        ),
      ).thenAnswer(
        (_) async => RealtimeStopResult(
          transcript: 'text without an asset',
          recordingSessionId: 'test-session',
          captureDisposition: RealtimeCaptureDisposition.complete,
        ),
      );
      final container = buildContainer();
      addTearDown(container.dispose);
      final notifier = container.read(captureControllerProvider.notifier);

      await notifier.toggle();
      await notifier.toggle();

      expect(
        container.read(captureControllerProvider).error,
        CaptureError.noAudioRecorded,
      );
      expect(persistedNotes, isEmpty);
    });

    test(
      'finishing without an active realtime session reports '
      'noActiveRealtimeSession (defensive guard)',
      () async {
        final container = buildContainer();
        addTearDown(container.dispose);
        final notifier = container.read(captureControllerProvider.notifier);

        // Never started: the session fields are all null.
        await notifier.debugFinishListeningRealtime();

        final state = container.read(captureControllerProvider);
        expect(state.phase, CapturePhase.error);
        expect(state.error, CaptureError.noActiveRealtimeSession);
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
        expect(persistedNotes.single.audioFile, endsWith('.wav'));
        expect(persistedNotes.single.audioDirectory, startsWith('/audio/'));
        expect(persistedNotes.single.duration, const Duration(seconds: 2));
        verify(
          () => durableCapture.markCommitted(journalAudioId: 'audio_001'),
        ).called(1);
      },
    );

    test(
      'persists day context and completes the durable processing job',
      () async {
        final outboxRoot = Directory.systemTemp.createTempSync(
          'capture-processing-outbox-test-',
        );
        final outbox = DayProcessingOutboxRepository(
          rootDirectory: outboxRoot,
          now: () => _recordingStartedAt,
          tokenFactory: () => 'foreground-claim',
        );
        final persistenceLogic = MockPersistenceLogic();
        await setUpTestGetIt(
          additionalSetup: () {
            getIt.registerSingleton<PersistenceLogic>(persistenceLogic);
          },
        );
        addTearDown(() async {
          await outbox.dispose();
          if (outboxRoot.existsSync()) outboxRoot.deleteSync(recursive: true);
          await tearDownTestGetIt();
        });
        when(
          () => persistenceLogic.updateMetadata(any()),
        ).thenAnswer((invocation) async {
          return invocation.positionalArguments.single as Metadata;
        });
        when(
          () => persistenceLogic.updateDbEntity(any()),
        ).thenAnswer((_) async => true);
        final container = _aliveContainer(
          transcriber: transcriber,
          realtimeService: realtimeService,
          persistAudio: persistAudio,
          realtimeRecorderFactory: () => fakeRecorder,
          processingOutbox: outbox,
        );
        addTearDown(container.dispose);

        await container.read(captureControllerProvider.notifier).toggle();
        await container.read(captureControllerProvider.notifier).toggle();

        final context = persistedNotes.single.dayContext;
        final job = (await outbox.getAll()).single;
        expect(context!.dayId, 'dayplan-2026-05-26');
        expect(context.recordingSessionId, 'test-session');
        expect(context.activityEntryId, 'activity-1');
        expect(context.processingJobId, 'transcribe_test-session');
        expect(job.status, DayProcessingJobStatus.succeeded);
        expect(job.resultTranscript, 'hello realtime');
        expect(job.audioId, 'audio_001');
      },
    );

    test('retains a saved partial source without committing it', () async {
      when(
        () => realtimeService.stop(
          capture: any(named: 'capture'),
          stopRecorder: any(named: 'stopRecorder'),
          outputPath: any(named: 'outputPath'),
        ),
      ).thenAnswer(
        (_) async => RealtimeStopResult(
          transcript: 'partial words',
          recordingSessionId: 'test-session',
          audioFilePath: '/tmp/partial.wav',
          captureDisposition: RealtimeCaptureDisposition.savedPartial,
        ),
      );
      final container = buildContainer();
      addTearDown(container.dispose);

      final notifier = container.read(captureControllerProvider.notifier);
      await notifier.toggle();
      await notifier.toggle();

      final state = container.read(captureControllerProvider);
      expect(state.phase, CapturePhase.error);
      expect(state.error, CaptureError.recordingRetainedForRecovery);
      expect(state.transcript, 'partial words');
      expect(persistedNotes, isEmpty);
      verifyNever(
        () => durableCapture.markCommitted(
          journalAudioId: any(named: 'journalAudioId'),
        ),
      );
    });

    test(
      'reports saved pending when journal ownership binding fails',
      () async {
        when(
          () => durableCapture.markCommitted(
            journalAudioId: any(named: 'journalAudioId'),
          ),
        ).thenThrow(StateError('owner marker unavailable'));
        final container = buildContainer();
        addTearDown(container.dispose);

        final notifier = container.read(captureControllerProvider.notifier);
        await notifier.toggle();
        await notifier.toggle();

        final state = container.read(captureControllerProvider);
        expect(state.phase, CapturePhase.error);
        expect(state.error, CaptureError.recordingSavedPendingTranscription);
        expect(state.audioId, 'audio_001');
        expect(persistedNotes, hasLength(1));
      },
    );

    test(
      'uses full-file transcription when realtime final text is truncated',
      () async {
        when(
          () => realtimeService.stop(
            capture: any(named: 'capture'),
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
            recordingSessionId: 'test-session',
            audioFilePath: '$outputPath.wav',
            captureDisposition: RealtimeCaptureDisposition.complete,
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
            capture: any(named: 'capture'),
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
            recordingSessionId: 'test-session',
            audioFilePath: '$outputPath.wav',
            captureDisposition: RealtimeCaptureDisposition.complete,
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
        expect(state.error, CaptureError.microphonePermissionDenied);
        verifyNever(
          () => realtimeService.startRealtimeTranscription(
            capture: any(named: 'capture'),
            pcmStream: any(named: 'pcmStream'),
            onDelta: any(named: 'onDelta'),
            onCaptureFailure: any(named: 'onCaptureFailure'),
            config: any(named: 'config'),
            resolveConfigWhenAbsent: false,
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
      expect(state.dbfs, CaptureState.defaultDbfs);
      expect(state.audioId, isNull);
      expect(state.error, isNull);
    });

    test('copyWith replaces only the supplied fields', () {
      const base = CaptureState(
        phase: CapturePhase.listening,
        transcript: 'hi',
        amplitudes: <double>[0.1, 0.2],
        dbfs: -32,
        partialTranscript: 'p',
        audioId: 'a-1',
      );

      final next = base.copyWith(
        phase: CapturePhase.captured,
        transcript: 'final',
        partialTranscript: '',
        amplitudes: const <double>[],
        dbfs: -12,
        audioId: 'a-2',
        error: CaptureError.transcriptionFailed,
      );

      expect(next.phase, CapturePhase.captured);
      expect(next.transcript, 'final');
      expect(next.partialTranscript, '');
      expect(next.amplitudes, isEmpty);
      expect(next.dbfs, -12);
      expect(next.audioId, 'a-2');
      expect(next.error, CaptureError.transcriptionFailed);

      final partial = base.copyWith(transcript: 'updated');
      expect(partial.transcript, 'updated');
      expect(partial.phase, base.phase);
      expect(partial.amplitudes, base.amplitudes);
      expect(partial.dbfs, base.dbfs);
      expect(partial.audioId, base.audioId);
    });
  });

  group('CaptureController realtime path — error branches + resolver', () {
    late MockRealtimeTranscriptionService realtimeService;
    late MockAudioTranscriptionService transcriber;
    late MockDurableRealtimeCapture durableCapture;
    late _FakeRealtimeRecorder fakeRecorder;
    late StreamController<double> realtimeAmpController;
    late StreamController<Uint8List> pcmController;

    setUp(() {
      realtimeService = MockRealtimeTranscriptionService();
      transcriber = MockAudioTranscriptionService();
      durableCapture = MockDurableRealtimeCapture();
      when(() => durableCapture.recordingSessionId).thenReturn('test-session');
      when(() => durableCapture.activityEntryId).thenReturn('activity-1');
      when(() => durableCapture.acceptedPcmBytes).thenReturn(0);
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
      when(
        () => realtimeService.prepareDefaultDurableCapture(
          assetRootDirectory: any(named: 'assetRootDirectory'),
          createdAt: any(named: 'createdAt'),
          origin: any(named: 'origin'),
          intent: any(named: 'intent'),
          dayId: any(named: 'dayId'),
          planDate: any(named: 'planDate'),
        ),
      ).thenAnswer((_) async => durableCapture);
      when(durableCapture.discard).thenAnswer((_) async {});
      when(
        () => durableCapture.markCommitted(
          journalAudioId: any(named: 'journalAudioId'),
        ),
      ).thenAnswer((_) async {});
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
      expect(state.error, CaptureError.recordingStartFailed);
      expect(fakeRecorder.disposed, isTrue);
    });

    test(
      'startRealtimeTranscription throwing surfaces error and disposes recorder',
      () async {
        when(
          () => realtimeService.startRealtimeTranscription(
            capture: any(named: 'capture'),
            pcmStream: any(named: 'pcmStream'),
            onDelta: any(named: 'onDelta'),
            onCaptureFailure: any(named: 'onCaptureFailure'),
            config: any(named: 'config'),
            resolveConfigWhenAbsent: false,
          ),
        ).thenThrow(StateError('socket failed'));

        final container = buildContainer();
        addTearDown(container.dispose);

        await container.read(captureControllerProvider.notifier).toggle();

        final state = container.read(captureControllerProvider);
        expect(state.phase, CapturePhase.error);
        expect(state.error, CaptureError.realtimeTranscriptionStartFailed);
      },
    );

    test(
      'realtime stop throwing with no PCM reports no audio and disposes recorder',
      () async {
        when(
          () => realtimeService.startRealtimeTranscription(
            capture: any(named: 'capture'),
            pcmStream: any(named: 'pcmStream'),
            onDelta: any(named: 'onDelta'),
            onCaptureFailure: any(named: 'onCaptureFailure'),
            config: any(named: 'config'),
            resolveConfigWhenAbsent: false,
          ),
        ).thenAnswer((_) async {});
        when(
          () => realtimeService.stop(
            capture: any(named: 'capture'),
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
        expect(state.error, CaptureError.noAudioRecorded);
        expect(fakeRecorder.disposed, isTrue);
      },
    );

    test(
      'falls back to realtime transcript when batch transcriber throws',
      () async {
        when(
          () => realtimeService.startRealtimeTranscription(
            capture: any(named: 'capture'),
            pcmStream: any(named: 'pcmStream'),
            onDelta: any(named: 'onDelta'),
            onCaptureFailure: any(named: 'onCaptureFailure'),
            config: any(named: 'config'),
            resolveConfigWhenAbsent: false,
          ),
        ).thenAnswer((_) async {});
        when(
          () => realtimeService.stop(
            capture: any(named: 'capture'),
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
            recordingSessionId: 'test-session',
            audioFilePath: '$outputPath.wav',
            captureDisposition: RealtimeCaptureDisposition.complete,
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
            capture: any(named: 'capture'),
            pcmStream: any(named: 'pcmStream'),
            onDelta: any(named: 'onDelta'),
            onCaptureFailure: any(named: 'onCaptureFailure'),
            config: any(named: 'config'),
            resolveConfigWhenAbsent: false,
          ),
        ).thenAnswer((_) async {});
        when(
          () => realtimeService.stop(
            capture: any(named: 'capture'),
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
            recordingSessionId: 'test-session',
            audioFilePath: '$outputPath.wav',
            captureDisposition: RealtimeCaptureDisposition.complete,
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
            capture: any(named: 'capture'),
            pcmStream: any(named: 'pcmStream'),
            onDelta: any(named: 'onDelta'),
            onCaptureFailure: any(named: 'onCaptureFailure'),
            config: any(named: 'config'),
            resolveConfigWhenAbsent: false,
          ),
        ).thenAnswer((_) async {});
        when(
          () => realtimeService.stop(
            capture: any(named: 'capture'),
            stopRecorder: any(named: 'stopRecorder'),
            outputPath: any(named: 'outputPath'),
          ),
        ).thenAnswer((invocation) async {
          final stopRecorder =
              invocation.namedArguments[#stopRecorder]
                  as Future<void> Function();
          await stopRecorder();
          return RealtimeStopResult(
            transcript: 'realtime only',
            recordingSessionId: 'test-session',
            captureDisposition: RealtimeCaptureDisposition.recoveryRequired,
          );
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

    /// Stubs a successful realtime session whose stop() writes an audio file
    /// and yields [realtimeTranscript].
    void stubRealtimeSession({required String realtimeTranscript}) {
      when(
        () => realtimeService.startRealtimeTranscription(
          capture: any(named: 'capture'),
          pcmStream: any(named: 'pcmStream'),
          onDelta: any(named: 'onDelta'),
          onCaptureFailure: any(named: 'onCaptureFailure'),
          config: any(named: 'config'),
          resolveConfigWhenAbsent: false,
        ),
      ).thenAnswer((_) async {});
      when(
        () => realtimeService.stop(
          capture: any(named: 'capture'),
          stopRecorder: any(named: 'stopRecorder'),
          outputPath: any(named: 'outputPath'),
        ),
      ).thenAnswer((invocation) async {
        final stopRecorder =
            invocation.namedArguments[#stopRecorder] as Future<void> Function();
        final outputPath = invocation.namedArguments[#outputPath] as String;
        await stopRecorder();
        return RealtimeStopResult(
          transcript: realtimeTranscript,
          recordingSessionId: 'test-session',
          audioFilePath: '$outputPath.wav',
          captureDisposition: RealtimeCaptureDisposition.complete,
        );
      });
    }

    test(
      'skipRealtimeTranscriptVerificationForNextCapture skips the batch '
      'verifier for one capture only',
      () async {
        stubRealtimeSession(realtimeTranscript: 'realtime text');
        when(
          () => transcriber.transcribe(
            any(),
            speechDictionaryTerms: any(named: 'speechDictionaryTerms'),
          ),
        ).thenAnswer((_) async => 'batch text');

        final container = buildContainer();
        addTearDown(container.dispose);

        final notifier = container.read(captureControllerProvider.notifier)
          ..skipRealtimeTranscriptVerificationForNextCapture();
        await notifier.toggle();
        await notifier.toggle();

        // The skipped capture keeps realtime verbatim without transcribing.
        expect(
          container.read(captureControllerProvider).transcript,
          'realtime text',
        );
        verifyNever(
          () => transcriber.transcribe(
            any(),
            speechDictionaryTerms: any(named: 'speechDictionaryTerms'),
          ),
        );

        // The skip is one-shot: the next capture verifies again.
        await notifier.toggle(); // captured -> reset/idle
        await notifier.toggle(); // idle -> listening
        await notifier.toggle(); // listening -> captured
        verify(
          () => transcriber.transcribe(
            any(),
            speechDictionaryTerms: any(named: 'speechDictionaryTerms'),
          ),
        ).called(1);
      },
    );

    test(
      'keeps the realtime transcript when the batch transcript is empty',
      () async {
        stubRealtimeSession(realtimeTranscript: 'realtime text');
        // Whitespace-only batch output trims to empty.
        when(
          () => transcriber.transcribe(
            any(),
            speechDictionaryTerms: any(named: 'speechDictionaryTerms'),
          ),
        ).thenAnswer((_) async => '   ');

        final container = buildContainer();
        addTearDown(container.dispose);

        final notifier = container.read(captureControllerProvider.notifier);
        await notifier.toggle();
        await notifier.toggle();

        expect(
          container.read(captureControllerProvider).transcript,
          'realtime text',
        );
        verify(
          () => transcriber.transcribe(
            any(),
            speechDictionaryTerms: any(named: 'speechDictionaryTerms'),
          ),
        ).called(1);
      },
    );

    test(
      'empty realtime result and failed verifier retain the journal audio',
      () async {
        stubRealtimeSession(realtimeTranscript: '   ');
        when(
          () => transcriber.transcribe(
            any(),
            speechDictionaryTerms: any(named: 'speechDictionaryTerms'),
          ),
        ).thenThrow(StateError('offline'));
        final container = buildContainer();
        addTearDown(container.dispose);

        final notifier = container.read(captureControllerProvider.notifier);
        await notifier.toggle();
        await notifier.toggle();

        final state = container.read(captureControllerProvider);
        expect(state.phase, CapturePhase.error);
        expect(state.error, CaptureError.recordingSavedPendingTranscription);
        expect(state.audioId, 'audio_001');
        verify(
          () => durableCapture.markCommitted(journalAudioId: 'audio_001'),
        ).called(1);
      },
    );
  });

  group(
    'CaptureController realtime path — amplitude clipping and error handlers',
    () {
      late MockRealtimeTranscriptionService realtimeService;
      late MockAudioTranscriptionService transcriber;
      late MockDurableRealtimeCapture durableCapture;
      late _FakeRealtimeRecorder fakeRecorder;
      late StreamController<double> realtimeAmpController;
      late StreamController<Uint8List> pcmController;
      late void Function(String delta)? capturedOnDelta;

      setUp(() {
        realtimeService = MockRealtimeTranscriptionService();
        transcriber = MockAudioTranscriptionService();
        durableCapture = MockDurableRealtimeCapture();
        when(
          () => durableCapture.recordingSessionId,
        ).thenReturn('test-session');
        when(() => durableCapture.activityEntryId).thenReturn('activity-1');
        when(() => durableCapture.acceptedPcmBytes).thenReturn(0);
        fakeRecorder = _FakeRealtimeRecorder();
        realtimeAmpController = StreamController<double>.broadcast();
        pcmController = StreamController<Uint8List>.broadcast();
        capturedOnDelta = null;

        fakeRecorder.pcmStream = pcmController.stream;

        when(
          () => realtimeService.resolveRealtimeConfig(),
        ).thenAnswer(
          (_) async => (provider: _FakeProvider(), model: _FakeModel()),
        );
        when(
          () => realtimeService.prepareDefaultDurableCapture(
            assetRootDirectory: any(named: 'assetRootDirectory'),
            createdAt: any(named: 'createdAt'),
            origin: any(named: 'origin'),
            intent: any(named: 'intent'),
            dayId: any(named: 'dayId'),
            planDate: any(named: 'planDate'),
          ),
        ).thenAnswer((_) async => durableCapture);
        when(durableCapture.discard).thenAnswer((_) async {});
        when(
          () => durableCapture.markCommitted(
            journalAudioId: any(named: 'journalAudioId'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => realtimeService.amplitudeStream,
        ).thenAnswer((_) => realtimeAmpController.stream);
        when(
          () => realtimeService.startRealtimeTranscription(
            capture: any(named: 'capture'),
            pcmStream: any(named: 'pcmStream'),
            onDelta: any(named: 'onDelta'),
            onCaptureFailure: any(named: 'onCaptureFailure'),
            config: any(named: 'config'),
            resolveConfigWhenAbsent: false,
          ),
        ).thenAnswer((invocation) async {
          capturedOnDelta =
              invocation.namedArguments[#onDelta] as void Function(String);
        });
        when(
          () => realtimeService.stop(
            capture: any(named: 'capture'),
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
            transcript: 'hello realtime',
            recordingSessionId: 'test-session',
            audioFilePath: '$outputPath.wav',
            captureDisposition: RealtimeCaptureDisposition.complete,
          );
        });
        when(
          () => transcriber.transcribe(
            any(),
            speechDictionaryTerms: any(named: 'speechDictionaryTerms'),
          ),
        ).thenAnswer((_) async => 'hello realtime');
      });

      tearDown(() async {
        await realtimeAmpController.close();
        await pcmController.close();
      });

      ProviderContainer buildContainer() {
        final container = ProviderContainer(
          overrides: [
            captureControllerProvider.overrideWith(
              () => CaptureController(
                realtimeService: realtimeService,
                transcriber: transcriber,
                realtimeRecorderFactory: () => fakeRecorder,
                persistAudio: (_) async => _persistedAudio(),
                docDir: Directory.systemTemp.createTempSync,
                now: () => _recordingStartedAt,
              ),
            ),
          ],
        )..listen(captureControllerProvider, (_, _) {});
        return container;
      }

      test(
        'realtime amplitudes clip to the rolling window of 80 samples',
        () async {
          final container = buildContainer();
          addTearDown(container.dispose);

          await container.read(captureControllerProvider.notifier).toggle();
          expect(
            container.read(captureControllerProvider).phase,
            CapturePhase.listening,
          );

          // Emit 85 amplitude samples — only the last 80 should be kept.
          for (var i = 0; i < 85; i++) {
            realtimeAmpController.add(-10);
            await pumpEventQueue();
          }

          final amplitudes = container
              .read(captureControllerProvider)
              .amplitudes;
          expect(amplitudes.length, 80);
        },
      );

      test(
        'realtime amplitude stream onError is swallowed and keeps recording',
        () async {
          final container = buildContainer();
          addTearDown(container.dispose);

          await container.read(captureControllerProvider.notifier).toggle();
          expect(
            container.read(captureControllerProvider).phase,
            CapturePhase.listening,
          );

          // Add a valid sample then trigger a stream error.
          realtimeAmpController.add(-10);
          await pumpEventQueue();
          realtimeAmpController.addError(StateError('amp hw error'));
          await pumpEventQueue();

          // The recording continues — phase is still listening and the
          // valid amplitude sample is present.
          final state = container.read(captureControllerProvider);
          expect(state.phase, CapturePhase.listening);
          expect(state.amplitudes, hasLength(1));
        },
      );

      test(
        '_onRealtimeDelta is a no-op when phase is not listening or transcribing',
        () async {
          final container = buildContainer();
          addTearDown(container.dispose);

          final notifier = container.read(captureControllerProvider.notifier);
          await notifier.toggle();
          await notifier.toggle(); // → captured; onDelta still captured

          // Phase is now captured — delta should be silently discarded.
          capturedOnDelta!('should be ignored');
          await pumpEventQueue();

          final state = container.read(captureControllerProvider);
          expect(state.phase, CapturePhase.captured);
          // partialTranscript must remain empty (was cleared when captured).
          expect(state.partialTranscript, '');
          // The final transcript must not be contaminated by the late delta.
          expect(state.transcript, 'hello realtime');
        },
      );
    },
  );
}

class _FakeRealtimeRecorder implements record.AudioRecorder {
  bool permissionGranted = true;
  Future<bool>? permissionFuture;
  Stream<Uint8List>? pcmStream;
  Future<Stream<Uint8List>>? startStreamFuture;
  bool stopped = false;
  int stopCalls = 0;
  bool disposed = false;
  bool throwOnStartStream = false;
  void Function(String event)? onCall;

  @override
  Future<bool> hasPermission({bool request = true}) async {
    onCall?.call('permission');
    return permissionFuture ?? permissionGranted;
  }

  @override
  Future<Stream<Uint8List>> startStream(record.RecordConfig config) async {
    onCall?.call('stream');
    if (throwOnStartStream) {
      throw StateError('mic busy');
    }
    final pending = startStreamFuture;
    if (pending != null) return pending;
    if (pcmStream == null) {
      throw StateError('pcmStream not configured');
    }
    return pcmStream!;
  }

  @override
  Future<String?> stop() async {
    stopCalls += 1;
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
