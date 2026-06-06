import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/logging_types.dart';
import 'package:lotti/features/ai/database/ai_config_db.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/realtime_transcription_event.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/mistral_realtime_transcription_repository.dart';
import 'package:lotti/features/ai/util/known_models.dart';
import 'package:lotti/features/ai/util/mlx_audio_channel.dart';
import 'package:lotti/features/ai_chat/services/realtime_transcription_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'realtime_transcription_test_utils.dart';

// ---------------------------------------------------------------------------
// Fakes & Mocks
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeRealtimeDomainLogger fakeLogging;

  setUp(() {
    fakeLogging = FakeRealtimeDomainLogger();
    if (getIt.isRegistered<DomainLogger>()) {
      getIt.unregister<DomainLogger>();
    }
    getIt.registerSingleton<DomainLogger>(fakeLogging);
  });

  tearDown(() {
    if (getIt.isRegistered<DomainLogger>()) {
      getIt.unregister<DomainLogger>();
    }
  });

  group('resolveRealtimeConfig', () {
    test('returns config when realtime model exists', () async {
      final bench = await RealtimeTranscriptionTestBench.create();
      addTearDown(bench.dispose);

      final config = await bench.service.resolveRealtimeConfig();

      expect(config, isNotNull);
      expect(config!.provider.id, kTestProviderId);
      expect(config.model.providerModelId, kTestProviderModelId);
    });

    test(
      'prefers Mistral over MLX when both are configured (cloud-first '
      'default)',
      () async {
        final bench = await RealtimeTranscriptionTestBench.create(
          addMlxConfig: true,
        );
        addTearDown(bench.dispose);

        final config = await bench.service.resolveRealtimeConfig();

        expect(config, isNotNull);
        expect(config!.provider.id, kTestProviderId);
        expect(
          config.provider.inferenceProviderType,
          InferenceProviderType.mistral,
        );
        expect(config.model.providerModelId, kTestProviderModelId);
      },
    );

    test(
      'falls back to MLX when only the local model is configured',
      () async {
        final bench = await RealtimeTranscriptionTestBench.create(
          addConfig: false,
          addMlxConfig: true,
        );
        addTearDown(bench.dispose);

        final config = await bench.service.resolveRealtimeConfig();

        expect(config, isNotNull);
        expect(config!.provider.id, kTestMlxProviderId);
        expect(
          config.provider.inferenceProviderType,
          InferenceProviderType.mlxAudio,
        );
        expect(config.model.providerModelId, mlxAudioQwenAsrModelId);
      },
    );

    test('returns null when no realtime model configured', () async {
      final bench = await RealtimeTranscriptionTestBench.create(
        addConfig: false,
      );
      addTearDown(bench.dispose);

      final config = await bench.service.resolveRealtimeConfig();
      expect(config, isNull);
    });

    test('skips non-audio models', () async {
      final db = AiConfigDb(inMemoryDatabase: true);
      final aiRepo = AiConfigRepository(db);

      await aiRepo.saveConfig(
        AiConfig.inferenceProvider(
          id: kTestProviderId,
          baseUrl: 'https://api.mistral.ai/v1',
          apiKey: 'key',
          name: 'Mistral',
          createdAt: DateTime(2024),
          inferenceProviderType: InferenceProviderType.mistral,
        ),
        fromSync: true,
      );
      // Model has text input only — not audio
      await aiRepo.saveConfig(
        AiConfig.model(
          id: 'text-only',
          name: 'Text Model',
          providerModelId: kTestProviderModelId,
          inferenceProviderId: kTestProviderId,
          createdAt: DateTime(2024),
          inputModalities: const [Modality.text],
          outputModalities: const [Modality.text],
          isReasoningModel: false,
        ),
        fromSync: true,
      );

      final repo = MistralRealtimeTranscriptionRepository();
      final container = ProviderContainer(
        overrides: [
          aiConfigRepositoryProvider.overrideWith((_) => aiRepo),
          realtimeTranscriptionServiceProvider.overrideWith(
            (ref) => RealtimeTranscriptionService(ref, repository: repo),
          ),
        ],
      );
      addTearDown(container.dispose);

      final svc = container.read(realtimeTranscriptionServiceProvider);
      final config = await svc.resolveRealtimeConfig();
      expect(config, isNull);
    });

    test('skips non-Mistral providers', () async {
      final db = AiConfigDb(inMemoryDatabase: true);
      final aiRepo = AiConfigRepository(db);

      // Provider is Gemini, not Mistral
      await aiRepo.saveConfig(
        AiConfig.inferenceProvider(
          id: 'p-gemini',
          baseUrl: 'https://api.example.com',
          apiKey: 'key',
          name: 'Gemini',
          createdAt: DateTime(2024),
          inferenceProviderType: InferenceProviderType.gemini,
        ),
        fromSync: true,
      );
      await aiRepo.saveConfig(
        AiConfig.model(
          id: 'wrong-provider',
          name: 'Realtime',
          providerModelId: kTestProviderModelId,
          inferenceProviderId: 'p-gemini',
          createdAt: DateTime(2024),
          inputModalities: const [Modality.audio],
          outputModalities: const [Modality.text],
          isReasoningModel: false,
        ),
        fromSync: true,
      );

      final repo = MistralRealtimeTranscriptionRepository();
      final container = ProviderContainer(
        overrides: [
          aiConfigRepositoryProvider.overrideWith((_) => aiRepo),
          realtimeTranscriptionServiceProvider.overrideWith(
            (ref) => RealtimeTranscriptionService(ref, repository: repo),
          ),
        ],
      );
      addTearDown(container.dispose);

      final svc = container.read(realtimeTranscriptionServiceProvider);
      final config = await svc.resolveRealtimeConfig();
      expect(config, isNull);
    });
  });

  group('startRealtimeTranscription', () {
    test('throws StateError when no config available', () async {
      final bench = await RealtimeTranscriptionTestBench.create(
        addConfig: false,
      );
      addTearDown(bench.dispose);

      await expectLater(
        () => bench.service.startRealtimeTranscription(
          pcmStream: const Stream<Uint8List>.empty(),
          onDelta: (_) {},
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('connects WebSocket and sets isActive', () async {
      final bench = await RealtimeTranscriptionTestBench.create();
      addTearDown(bench.dispose);

      final pcm = await bench.startTranscription();
      expect(bench.service.isActive, isTrue);
      await pcm.close();
    });

    test('forwards PCM chunks to repository as base64', () async {
      final bench = await RealtimeTranscriptionTestBench.create();
      addTearDown(bench.dispose);

      await bench.startTranscription();
      await bench.sendPcm(pcmSilence(64));

      expect(bench.channel.sentMessages, isNotEmpty);
      final msg =
          jsonDecode(bench.channel.sentMessages.last) as Map<String, dynamic>;
      expect(msg['type'], 'input_audio.append');
      expect(msg['audio'], isNotEmpty);
    });

    test('emits amplitude values from PCM chunks', () async {
      final bench = await RealtimeTranscriptionTestBench.create();
      addTearDown(bench.dispose);

      final amplitudes = <double>[];
      bench.service.amplitudeStream.listen(amplitudes.add);

      await bench.startTranscription();
      await bench.sendPcm(pcmSilence(64));

      expect(amplitudes, isNotEmpty);
    });

    test('calls onDelta callback for each transcription delta', () {
      fakeAsync((async) {
        late RealtimeTranscriptionTestBench bench;
        RealtimeTranscriptionTestBench.create().then((b) => bench = b);
        async.flushMicrotasks();
        addTearDown(bench.dispose);

        final deltas = <String>[];
        bench.startTranscription(onDelta: deltas.add);
        // Flush microtasks for DB/setup, then elapse to fire the
        // zero-duration timer that delivers session.created.
        async
          ..flushMicrotasks()
          ..elapse(Duration.zero)
          ..flushMicrotasks();

        bench.channel.simulateServerMessage({
          'type': 'transcription.text.delta',
          'text': 'Hello ',
        });
        async.flushMicrotasks();

        bench.channel.simulateServerMessage({
          'type': 'transcription.text.delta',
          'text': 'world',
        });
        async.flushMicrotasks();

        expect(deltas, ['Hello ', 'world']);
      });
    });

    test(
      'uses MLX Qwen streaming channel when local model is configured',
      () async {
        final bench = await RealtimeTranscriptionTestBench.create(
          addConfig: false,
          addMlxConfig: true,
        );
        addTearDown(bench.dispose);

        final deltas = <String>[];
        await bench.startTranscription(onDelta: deltas.add);

        expect(bench.mlxAudioChannel.startedModelId, mlxAudioQwenAsrModelId);
        expect(bench.mlxAudioChannel.startedDelayPreset, 'subtitle');

        await bench.sendPcm(pcmSilence(64));
        expect(bench.mlxAudioChannel.appendedPcm, hasLength(1));
        expect(bench.mlxAudioChannel.appendedPcm.single, hasLength(64));

        bench.mlxAudioChannel.emit(
          const MlxAudioRealtimeEvent(
            type: MlxAudioRealtimeEventType.confirmed,
            text: 'Hello ',
          ),
        );
        bench.mlxAudioChannel.emit(
          const MlxAudioRealtimeEvent(
            type: MlxAudioRealtimeEventType.confirmed,
            text: 'Hello world',
          ),
        );
        await Future<void>.delayed(Duration.zero);

        expect(deltas, ['Hello ', 'world']);
      },
    );

    test(
      'deduplicates MLX confirmed text when the backend drops old context',
      () async {
        final bench = await RealtimeTranscriptionTestBench.create(
          addConfig: false,
          addMlxConfig: true,
        );
        addTearDown(bench.dispose);

        final deltas = <String>[];
        await bench.startTranscription(onDelta: deltas.add);

        bench.mlxAudioChannel.emit(
          const MlxAudioRealtimeEvent(
            type: MlxAudioRealtimeEventType.confirmed,
            text: 'Hello world',
          ),
        );
        bench.mlxAudioChannel.emit(
          const MlxAudioRealtimeEvent(
            type: MlxAudioRealtimeEventType.confirmed,
            text: 'world again',
          ),
        );
        await Future<void>.value();
        await Future<void>.value();

        expect(deltas, ['Hello world', ' again']);
      },
    );

    test('ignores MLX provisional display and stats events', () async {
      final bench = await RealtimeTranscriptionTestBench.create(
        addConfig: false,
        addMlxConfig: true,
      );
      addTearDown(bench.dispose);

      final deltas = <String>[];
      await bench.startTranscription(onDelta: deltas.add);

      bench.mlxAudioChannel
        ..emit(
          const MlxAudioRealtimeEvent(
            type: MlxAudioRealtimeEventType.provisional,
            text: 'draft',
          ),
        )
        ..emit(
          const MlxAudioRealtimeEvent(
            type: MlxAudioRealtimeEventType.display,
            text: 'display',
          ),
        )
        ..emit(
          const MlxAudioRealtimeEvent(
            type: MlxAudioRealtimeEventType.stats,
            encodedWindowCount: 2,
            totalAudioSeconds: 2.4,
          ),
        );
      await Future<void>.value();

      expect(deltas, isEmpty);
    });

    test(
      'cleans up the MLX backend when native realtime startup fails',
      () async {
        final bench = await RealtimeTranscriptionTestBench.create(
          addConfig: false,
          addMlxConfig: true,
        );
        addTearDown(bench.dispose);
        bench.mlxAudioChannel.startError = Exception('native start failed');

        await expectLater(
          bench.startTranscription,
          throwsA(
            isA<Exception>().having(
              (error) => error.toString(),
              'message',
              contains('native start failed'),
            ),
          ),
        );

        expect(bench.service.isActive, isFalse);
        expect(bench.mlxAudioChannel.cancelled, isTrue);
      },
    );

    test(
      'logs MLX append failures without dropping the active session',
      () async {
        final bench = await RealtimeTranscriptionTestBench.create(
          addConfig: false,
          addMlxConfig: true,
        );
        addTearDown(bench.dispose);
        bench.mlxAudioChannel.appendError = Exception('append failed');

        final pcm = await bench.startTranscription();
        pcm.add(pcmSilence(64));
        await Future<void>.value();
        await Future<void>.value();

        expect(bench.service.isActive, isTrue);
        expect(bench.mlxAudioChannel.appendedPcm, isEmpty);
        expect(
          fakeLogging.exceptions.map((error) => error.toString()),
          contains(contains('append failed')),
        );
      },
    );

    test(
      'handles MLX confirmed-text truncation and shared-prefix rewrites',
      () async {
        final bench = await RealtimeTranscriptionTestBench.create(
          addConfig: false,
          addMlxConfig: true,
        );
        addTearDown(bench.dispose);

        final deltas = <String>[];
        await bench.startTranscription(onDelta: deltas.add);

        bench.mlxAudioChannel
          ..emit(
            const MlxAudioRealtimeEvent(
              type: MlxAudioRealtimeEventType.confirmed,
              text: 'Hello world',
            ),
          )
          ..emit(
            const MlxAudioRealtimeEvent(
              type: MlxAudioRealtimeEventType.confirmed,
              text: 'Hello',
            ),
          )
          ..emit(
            const MlxAudioRealtimeEvent(
              type: MlxAudioRealtimeEventType.confirmed,
              text: 'Helium',
            ),
          );
        await Future<void>.value();

        expect(deltas, ['Hello world', 'ium']);
      },
    );

    test(
      'records detected language from Mistral transcription.language events',
      () async {
        final bench = await RealtimeTranscriptionTestBench.create();
        addTearDown(bench.dispose);

        await bench.startTranscription();
        bench.channel.simulateServerMessage({
          'type': 'transcription.language',
          'language': 'en',
        });
        final result = await bench.stop(
          afterListening: () => bench.simulateDone('hello'),
        );

        expect(result.detectedLanguage, 'en');
        expect(result.transcript, 'hello');
      },
    );

    test(
      'logs and surfaces MLX error events through the done completer',
      () async {
        final bench = await RealtimeTranscriptionTestBench.create(
          addConfig: false,
          addMlxConfig: true,
          doneTimeout: const Duration(seconds: 5),
        );
        addTearDown(bench.dispose);

        await bench.startTranscription();
        bench.mlxAudioChannel.emit(
          const MlxAudioRealtimeEvent(
            type: MlxAudioRealtimeEventType.confirmed,
            text: 'before crash',
          ),
        );
        final dir = await Directory.systemTemp.createTemp('rt_mlx_err_');
        addTearDown(() async {
          if (dir.existsSync()) await dir.delete(recursive: true);
        });

        // Start stop() and drain the event queue so it is parked on the
        // done completer (error handler attached) before the error is
        // emitted — deterministic, no wall-clock delay (fake-time policy).
        final stopFuture = bench.service.stop(
          stopRecorder: () async {},
          outputPath: '${dir.path}/output',
        );
        await pumpEventQueue();
        bench.mlxAudioChannel.emit(
          const MlxAudioRealtimeEvent(
            type: MlxAudioRealtimeEventType.error,
            message: 'inference crashed',
          ),
        );
        final result = await stopFuture;

        expect(result.usedTranscriptFallback, isTrue);
        expect(result.transcript, 'before crash');
        expect(
          fakeLogging.exceptions
              .map((error) => error.toString())
              .where((message) => message.contains('inference crashed')),
          isNotEmpty,
        );
      },
    );

    test(
      'logs MLX realtime event stream errors via the outer onError handler',
      () async {
        final bench = await RealtimeTranscriptionTestBench.create(
          addConfig: false,
          addMlxConfig: true,
          doneTimeout: const Duration(seconds: 5),
        );
        addTearDown(bench.dispose);

        await bench.startTranscription();
        final dir = await Directory.systemTemp.createTemp('rt_mlx_stream_err_');
        addTearDown(() async {
          if (dir.existsSync()) await dir.delete(recursive: true);
        });
        // Start stop() and drain the event queue so it is parked on the
        // done completer (error handler attached) before the stream error
        // is added — deterministic, no wall-clock delay (fake-time policy).
        final stopFuture = bench.service.stop(
          stopRecorder: () async {},
          outputPath: '${dir.path}/output',
        );
        await pumpEventQueue();
        bench.mlxAudioChannel.eventsController.addError(
          Exception('event stream broken'),
        );
        final result = await stopFuture;

        expect(result.usedTranscriptFallback, isTrue);
        expect(
          fakeLogging.exceptions.map((error) => error.toString()),
          contains(contains('event stream broken')),
        );
      },
    );

    test(
      'logs MLX PCM stream errors and keeps the session active',
      () {
        fakeAsync((async) {
          late RealtimeTranscriptionTestBench bench;
          RealtimeTranscriptionTestBench.create(
            addConfig: false,
            addMlxConfig: true,
          ).then((b) => bench = b);
          async.flushMicrotasks();
          addTearDown(bench.dispose);

          late StreamController<Uint8List> pcm;
          bench.startTranscription().then((c) => pcm = c);
          async
            ..flushMicrotasks()
            ..elapse(Duration.zero)
            ..flushMicrotasks();

          pcm.addError(Exception('mlx microphone disconnected'));
          async.flushMicrotasks();

          expect(
            fakeLogging.exceptions.map((error) => error.toString()),
            contains(contains('mlx microphone disconnected')),
          );
          expect(bench.service.isActive, isTrue);

          bench.service.dispose();
          async.flushMicrotasks();
        });
      },
    );
  });

  group('stop', () {
    test('returns transcript from transcription.done event', () async {
      final bench = await RealtimeTranscriptionTestBench.create();
      addTearDown(bench.dispose);

      await bench.startTranscription();
      await bench.sendPcm(pcmSilence(64));

      final result = await bench.stop(
        afterListening: () => bench.simulateDone(
          'Final transcript',
          extra: {
            'usage': {'audio_seconds': 3.0},
          },
        ),
      );
      expect(result.transcript, 'Final transcript');
      expect(result.usedTranscriptFallback, isFalse);
    });

    test('keeps accumulated deltas when done text is shorter', () async {
      final bench = await RealtimeTranscriptionTestBench.create();
      addTearDown(bench.dispose);

      await bench.startTranscription();
      await bench.sendPcm(pcmSilence(64));
      bench.channel
        ..simulateServerMessage({
          'type': 'transcription.text.delta',
          'text': 'Complete client animation ',
        })
        ..simulateServerMessage({
          'type': 'transcription.text.delta',
          'text': 'and commission work',
        });
      await Future<void>.delayed(Duration.zero);

      final result = await bench.stop(
        afterListening: () => bench.simulateDone('Complete client animation'),
      );
      expect(
        result.transcript,
        'Complete client animation and commission work',
      );
      expect(result.usedTranscriptFallback, isFalse);
    });

    test('falls back to accumulated deltas on timeout', () async {
      final bench = await RealtimeTranscriptionTestBench.create(
        doneTimeout: const Duration(milliseconds: 50),
      );
      addTearDown(bench.dispose);

      await bench.startTranscription();

      // Send deltas that will be accumulated
      bench.channel
        ..simulateServerMessage({
          'type': 'transcription.text.delta',
          'text': 'Hello ',
        })
        ..simulateServerMessage({
          'type': 'transcription.text.delta',
          'text': 'world',
        });
      await Future<void>.delayed(Duration.zero);

      // Don't send transcription.done — let the short 50ms timeout trigger
      // the fallback. Call service.stop directly to avoid file I/O in the
      // test bench helper (Directory.createTemp). No PCM was sent so
      // _saveAudio returns null (no file I/O).
      final result = await bench.service.stop(
        stopRecorder: () async {},
        outputPath: '/tmp/rt_test_fallback/output',
      );

      expect(result.transcript, 'Hello world');
      expect(result.usedTranscriptFallback, isTrue);
    });

    test('sends endAudio to server on stop', () async {
      final bench = await RealtimeTranscriptionTestBench.create();
      addTearDown(bench.dispose);

      await bench.startTranscription();
      await bench.stop(afterListening: () => bench.simulateDone('done'));

      final endMessages = bench.channel.sentMessages
          .map((m) => jsonDecode(m) as Map<String, dynamic>)
          .where((m) => m['type'] == 'input_audio.end');
      expect(endMessages, isNotEmpty);
    });

    test('calls stopRecorder callback', () async {
      final bench = await RealtimeTranscriptionTestBench.create();
      addTearDown(bench.dispose);

      await bench.startTranscription();
      var recorderStopped = false;

      await bench.stop(
        stopRecorder: () async {
          recorderStopped = true;
        },
        afterListening: () => bench.simulateDone('ok'),
      );

      expect(recorderStopped, isTrue);
    });

    test('sets isActive to false after stop', () async {
      final bench = await RealtimeTranscriptionTestBench.create();
      addTearDown(bench.dispose);

      await bench.startTranscription();
      expect(bench.service.isActive, isTrue);

      await bench.stop(afterListening: () => bench.simulateDone('done'));

      expect(bench.service.isActive, isFalse);
    });

    test('returns null audioFilePath when no PCM data', () async {
      final bench = await RealtimeTranscriptionTestBench.create();
      addTearDown(bench.dispose);

      await bench.startTranscription();
      // Don't send any PCM data — buffer remains empty

      final result = await bench.stop(
        afterListening: () => bench.simulateDone(''),
      );

      expect(result.audioFilePath, isNull);
    });

    test(
      'stops MLX Qwen streaming and returns final native transcript',
      () async {
        final bench = await RealtimeTranscriptionTestBench.create(
          addConfig: false,
          addMlxConfig: true,
        );
        addTearDown(bench.dispose);

        await bench.startTranscription();
        await bench.sendPcm(pcmSilence(64));
        bench.mlxAudioChannel.doneTextOnStop = 'Local final transcript';

        final result = await bench.stop();

        expect(result.transcript, 'Local final transcript');
        expect(result.usedTranscriptFallback, isFalse);
        expect(bench.mlxAudioChannel.stopped, isTrue);
        expect(bench.mlxAudioChannel.cancelled, isTrue);
      },
    );

    test(
      'uses accumulated MLX text when done event omits final text',
      () async {
        final bench = await RealtimeTranscriptionTestBench.create(
          addConfig: false,
          addMlxConfig: true,
        );
        addTearDown(bench.dispose);

        final deltas = <String>[];
        await bench.startTranscription(onDelta: deltas.add);
        bench.mlxAudioChannel
          ..emit(
            const MlxAudioRealtimeEvent(
              type: MlxAudioRealtimeEventType.confirmed,
              text: 'partial local transcript',
            ),
          )
          ..emit(
            const MlxAudioRealtimeEvent(
              type: MlxAudioRealtimeEventType.done,
            ),
          );
        await Future<void>.value();

        final result = await bench.stop();

        expect(result.transcript, 'partial local transcript');
        expect(result.usedTranscriptFallback, isFalse);
        expect(deltas, ['partial local transcript']);
      },
    );

    test(
      'falls back to accumulated MLX confirmed text when stop times out',
      () async {
        final bench = await RealtimeTranscriptionTestBench.create(
          addConfig: false,
          addMlxConfig: true,
          doneTimeout: const Duration(milliseconds: 10),
        );
        addTearDown(bench.dispose);

        await bench.startTranscription();
        bench.mlxAudioChannel.emit(
          const MlxAudioRealtimeEvent(
            type: MlxAudioRealtimeEventType.confirmed,
            text: 'timeout fallback transcript',
          ),
        );
        await Future<void>.value();

        final result = await bench.service.stop(
          stopRecorder: () async {},
          outputPath: (await Directory.systemTemp.createTemp(
            'rt_mlx_timeout_',
          )).path,
        );

        expect(result.transcript, 'timeout fallback transcript');
        expect(result.usedTranscriptFallback, isTrue);
        expect(
          fakeLogging.events,
          contains(
            contains('MLX transcription.done timed out'),
          ),
        );
      },
    );

    test('falls back to confirmed MLX text when native stop fails', () async {
      final bench = await RealtimeTranscriptionTestBench.create(
        addConfig: false,
        addMlxConfig: true,
      );
      addTearDown(bench.dispose);

      await bench.startTranscription();
      bench.mlxAudioChannel
        ..emit(
          const MlxAudioRealtimeEvent(
            type: MlxAudioRealtimeEventType.confirmed,
            text: 'partial local transcript',
          ),
        )
        ..stopError = Exception('native stop failed');
      await Future<void>.value();

      final result = await bench.service.stop(
        stopRecorder: () async {},
        outputPath: '/tmp/rt_mlx_error/output',
      );

      expect(result.transcript, 'partial local transcript');
      expect(result.usedTranscriptFallback, isTrue);
      expect(
        fakeLogging.exceptions.map((e) => e.toString()),
        contains(contains('native stop failed')),
      );
    });

    test(
      'propagates a transcription.done stream error out of stop()',
      () async {
        // The real Mistral repo never errors its done stream, so drive the
        // onError branch via a controllable repository subclass. When the done
        // stream errors, the listener completes the done completer with that
        // error; the subsequent `await ...future.timeout(...)` rethrows it.
        // stop() only catches TimeoutException, so a generic error surfaces to
        // the caller (after endAudio + done-subscription cleanup).
        final repo = ControllableRealtimeRepository();
        final container = ProviderContainer(
          overrides: [
            realtimeTranscriptionServiceProvider.overrideWith(
              (ref) => RealtimeTranscriptionService(
                ref,
                repository: repo,
                doneTimeout: const Duration(seconds: 30),
              ),
            ),
          ],
        );
        addTearDown(() async {
          await repo.close();
          container.dispose();
        });

        final service = container.read(realtimeTranscriptionServiceProvider);
        final pcm = StreamController<Uint8List>();
        addTearDown(pcm.close);

        final provider =
            AiConfig.inferenceProvider(
                  id: kTestProviderId,
                  baseUrl: 'https://api.mistral.ai/v1',
                  apiKey: 'test-key',
                  name: 'Mistral',
                  createdAt: DateTime(2024),
                  inferenceProviderType: InferenceProviderType.mistral,
                )
                as AiConfigInferenceProvider;
        final model =
            AiConfig.model(
                  id: kTestModelId,
                  name: 'Voxtral Realtime',
                  providerModelId: kTestProviderModelId,
                  inferenceProviderId: kTestProviderId,
                  createdAt: DateTime(2024),
                  inputModalities: const [Modality.audio],
                  outputModalities: const [Modality.text],
                  isReasoningModel: false,
                )
                as AiConfigModel;

        await service.startRealtimeTranscription(
          pcmStream: pcm.stream,
          onDelta: (_) {},
          config: (provider: provider, model: model),
        );

        // Begin stop(): it cancels the PCM sub, stops the recorder, calls
        // endAudio, then awaits the done completer. Error the done stream a
        // few microtasks in, once the completer future is being awaited, so
        // the listener's onError completes it with the error.
        final stopFuture = service.stop(
          stopRecorder: () async {},
          outputPath: '/tmp/rt_done_error/output',
        );

        await Future<void>.value();
        await Future<void>.value();
        await Future<void>.value();
        repo.doneController.addError(StateError('done stream exploded'));

        await expectLater(
          stopFuture,
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              'done stream exploded',
            ),
          ),
        );

        // endAudio still ran before the error surfaced.
        expect(repo.endAudioCalled, isTrue);
      },
    );
  });

  group('dispose', () {
    test('cancels subscriptions and cleans up', () async {
      final bench = await RealtimeTranscriptionTestBench.create();
      addTearDown(bench.dispose);

      await bench.startTranscription();
      expect(bench.service.isActive, isTrue);

      await bench.service.dispose();
      expect(bench.service.isActive, isFalse);
    });

    test('cleans up even with buffered PCM data', () async {
      final bench = await RealtimeTranscriptionTestBench.create();
      addTearDown(bench.dispose);

      await bench.startTranscription();
      await bench.sendPcm(pcmSilence(64));

      await bench.service.dispose();
      expect(bench.service.isActive, isFalse);
    });
  });

  group('PCM stream error handling', () {
    test('logs exception when PCM stream emits error', () {
      fakeAsync((async) {
        late RealtimeTranscriptionTestBench bench;
        RealtimeTranscriptionTestBench.create().then((b) => bench = b);
        async.flushMicrotasks();
        addTearDown(bench.dispose);

        late StreamController<Uint8List> pcm;
        bench.startTranscription().then((c) => pcm = c);
        async
          ..flushMicrotasks()
          ..elapse(Duration.zero)
          ..flushMicrotasks();

        pcm.addError(Exception('microphone disconnected'));
        async.flushMicrotasks();

        expect(fakeLogging.exceptions, hasLength(1));
        expect(
          fakeLogging.exceptions.first.toString(),
          contains('microphone disconnected'),
        );

        bench.service.dispose();
        async.flushMicrotasks();
      });
    });
  });

  group('WAV file output', () {
    test('writes valid WAV header for PCM data', () async {
      final bench = await RealtimeTranscriptionTestBench.create();
      addTearDown(bench.dispose);

      await bench.startTranscription();

      final pcmData = Uint8List.fromList(List.filled(320, 0));
      await bench.sendPcm(pcmData);

      final result = await bench.stop(
        afterListening: () => bench.simulateDone('test'),
      );

      expect(result.audioFilePath, isNotNull);
      final bytes = await File(result.audioFilePath!).readAsBytes();
      // RIFF header
      expect(bytes[0], 0x52); // 'R'
      expect(bytes[1], 0x49); // 'I'
      expect(bytes[2], 0x46); // 'F'
      expect(bytes[3], 0x46); // 'F'
      // WAVE
      expect(bytes[8], 0x57); // 'W'
      expect(bytes[9], 0x41); // 'A'
      expect(bytes[10], 0x56); // 'V'
      expect(bytes[11], 0x45); // 'E'

      // Verify WAV data size matches PCM data
      final headerDataSize = ByteData.sublistView(bytes, 40, 44);
      expect(headerDataSize.getUint32(0, Endian.little), pcmData.length);
    });

    test(
      'returns the m4a path and removes the temp WAV on successful conversion',
      () async {
        // Mock the native audio converter so convertWavToM4a returns true,
        // exercising the success branch that deletes the temp WAV file.
        const channel = MethodChannel('com.matthiasn.lotti/audio_converter');
        final converterCalls = <Map<Object?, Object?>>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              if (call.method == 'convertWavToM4a') {
                final args = call.arguments as Map<Object?, Object?>;
                converterCalls.add(args);
                // Materialise the output file so the path is real, then report
                // success so the service deletes the temp WAV.
                await File(args['outputPath']! as String).writeAsBytes(
                  const [0],
                );
                return true;
              }
              return null;
            });
        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(channel, null);
        });

        final bench = await RealtimeTranscriptionTestBench.create();
        addTearDown(bench.dispose);

        await bench.startTranscription();
        await bench.sendPcm(pcmSilence(3200));

        final result = await bench.stop(
          afterListening: () => bench.simulateDone('converted ok'),
        );

        expect(result.transcript, 'converted ok');
        expect(result.audioFilePath, isNotNull);
        expect(result.audioFilePath, endsWith('.m4a'));
        // The native converter was invoked with the temp WAV as input.
        expect(converterCalls, hasLength(1));
        final tempWavPath = converterCalls.single['inputPath']! as String;
        expect(tempWavPath, endsWith('.wav'));
        // The temp WAV was deleted after the successful conversion.
        expect(File(tempWavPath).existsSync(), isFalse);
        // The returned m4a file is the materialised output.
        expect(File(result.audioFilePath!).existsSync(), isTrue);
      },
    );

    test('audio file has .wav extension as fallback', () async {
      final bench = await RealtimeTranscriptionTestBench.create();
      addTearDown(bench.dispose);

      await bench.startTranscription();
      await bench.sendPcm(pcmSilence(64));

      final result = await bench.stop(
        afterListening: () => bench.simulateDone('test'),
      );

      // Without native M4A converter, should fall back to .wav
      expect(result.audioFilePath, isNotNull);
      expect(result.audioFilePath, endsWith('.wav'));
    });

    test(
      'falls back to the temp WAV path when the output move fails',
      () async {
        final bench = await RealtimeTranscriptionTestBench.create();
        addTearDown(bench.dispose);

        await bench.startTranscription();
        await bench.sendPcm(pcmSilence(64));

        // Use an invalid path to trigger the catch block in _saveAudio.
        // service.stop subscribes to the done stream synchronously, so the
        // done event fired right after the call cannot be missed.
        final stopFuture = bench.service.stop(
          stopRecorder: () async {},
          outputPath: '/nonexistent/deeply/nested/path/output',
        );
        bench.simulateDone('test');
        final result = await stopFuture;

        // _saveAudio's catch block deliberately keeps the already-written
        // temp WAV rather than losing the recording: the result carries the
        // systemTemp fallback path instead of the unreachable output path.
        expect(result.transcript, 'test');
        expect(result.audioFilePath, isNotNull);
        expect(result.audioFilePath, endsWith('.wav'));
        expect(
          result.audioFilePath,
          startsWith(Directory.systemTemp.path),
        );
        expect(File(result.audioFilePath!).existsSync(), isTrue);
        // Clean up the kept temp WAV.
        File(result.audioFilePath!).deleteSync();
      },
    );
  });

  group('PCM buffer cap', () {
    test('caps buffer to prevent OOM on long recordings', () async {
      final bench = await RealtimeTranscriptionTestBench.create();
      addTearDown(bench.dispose);

      final pcm = await bench.startTranscription();

      // Send chunks that exceed the max buffer size (3,840,000 bytes)
      // Each chunk is 64,000 bytes, so 61 chunks = 3,904,000 bytes > max
      for (var i = 0; i < 61; i++) {
        pcm.add(Uint8List.fromList(List.filled(64000, i)));
        await Future<void>.delayed(Duration.zero);
      }

      final result = await bench.stop(
        afterListening: () => bench.simulateDone('long recording test'),
      );

      expect(result.transcript, 'long recording test');
      expect(result.audioFilePath, isNotNull);
    });

    test('single chunk exceeding max buffer keeps only tail', () async {
      final bench = await RealtimeTranscriptionTestBench.create();
      addTearDown(bench.dispose);

      await bench.startTranscription();

      // Send a single chunk that exceeds the max buffer size (3,840,000 bytes)
      final oversizedChunk = Uint8List.fromList(
        List.generate(4000000, (i) => i % 256),
      );
      await bench.sendPcm(oversizedChunk);

      final result = await bench.stop(
        afterListening: () => bench.simulateDone('oversized chunk test'),
      );

      expect(result.transcript, 'oversized chunk test');
      expect(result.audioFilePath, isNotNull);
    });
  });

  group('_saveAudio error handling', () {
    test(
      'returns temp WAV path when conversion throws but WAV exists',
      () async {
        final bench = await RealtimeTranscriptionTestBench.create();
        addTearDown(bench.dispose);

        await bench.startTranscription();
        await bench.sendPcm(pcmSilence(3200));

        final result = await bench.stop(
          afterListening: () => bench.simulateDone('save error test'),
        );

        expect(result.transcript, 'save error test');
        // The audio file should still be present (WAV fallback on test env)
        expect(result.audioFilePath, isNotNull);
      },
    );
  });
}
