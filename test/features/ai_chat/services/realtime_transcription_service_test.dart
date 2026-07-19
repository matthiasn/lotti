import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/realtime_transcription_event.dart';
import 'package:lotti/features/ai/util/known_models.dart';
import 'package:lotti/features/ai/util/mlx_audio_channel.dart';
import 'package:lotti/features/ai_chat/services/realtime_transcription_service.dart';
import 'package:lotti/features/speech/services/durable_audio_spool.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

import 'realtime_transcription_test_utils.dart';

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
      // A Mistral provider whose only model is text-only: the audio-modality
      // filter rejects it, so no realtime config resolves.
      final bench = await RealtimeTranscriptionTestBench.create(
        configs: [
          realtimeProviderConfig(id: kTestProviderId),
          realtimeModelConfig(
            id: 'text-only',
            providerId: kTestProviderId,
            name: 'Text Model',
            audio: false,
          ),
        ],
      );
      addTearDown(bench.dispose);

      expect(await bench.service.resolveRealtimeConfig(), isNull);
    });

    test('skips non-Mistral providers', () async {
      // The realtime audio model sits behind a Gemini provider, so the
      // Mistral provider-type filter rejects it and the MLX fallback finds
      // nothing either.
      final bench = await RealtimeTranscriptionTestBench.create(
        configs: [
          realtimeProviderConfig(
            id: 'p-gemini',
            type: InferenceProviderType.gemini,
            name: 'Gemini',
            baseUrl: 'https://api.example.com',
          ),
          realtimeModelConfig(id: 'wrong-provider', providerId: 'p-gemini'),
        ],
      );
      addTearDown(bench.dispose);

      expect(await bench.service.resolveRealtimeConfig(), isNull);
    });
  });

  group('startRealtimeTranscription', () {
    test(
      'publishes stable day identity before a Daily OS microphone starts',
      () async {
        final ids = <String>['daily-session'].iterator;
        final bench = await RealtimeTranscriptionTestBench.create(
          addConfig: false,
          durableIdFactory: () {
            ids.moveNext();
            return ids.current;
          },
        );
        addTearDown(bench.dispose);
        final assetRoot = await Directory(
          path.join(bench.rootDirectory.path, 'daily-assets'),
        ).create();

        final capture = await bench.service.prepareDefaultDurableCapture(
          assetRootDirectory: assetRoot,
          createdAt: DateTime.utc(2026, 7, 18, 8, 15),
          origin: AudioCaptureOrigin.dailyOs,
          intent: AudioCaptureIntent.dayPlan,
          dayId: 'dayplan-2026-07-18',
          planDate: DateTime(2026, 7, 18),
        );

        expect(capture.recordingSessionId, 'daily-session');
        expect(
          capture.activityEntryId,
          const Uuid().v5(
            const Uuid().v5(
              Namespace.url.value,
              dailyOsAudioActivityNamespaceName,
            ),
            'daily-session',
          ),
        );
        expect(
          capture.spool.manifest.context.dayId,
          'dayplan-2026-07-18',
        );
        final context = capture.spool.manifest.context;
        expect(context.origin, AudioCaptureOrigin.dailyOs);
        expect(context.intent, AudioCaptureIntent.dayPlan);
        expect(context.planDate, DateTime(2026, 7, 18));
        expect(context.timeZoneOffsetMinutes, 0);
        expect(capture.createdAt, DateTime.utc(2026, 7, 18, 8, 15));
        expect(capture.dayId, 'dayplan-2026-07-18');
        expect(capture.planDate, DateTime(2026, 7, 18));
        expect(capture.intent, AudioCaptureIntent.dayPlan);
        expect(capture.originHostId, isNull);
        expect(capture.continuationOperationId, isNull);
        expect(capture.baselineRevisionId, isNull);
        expect(capture.acceptedPcmBytes, 0);
        expect(
          capture.sessionDirectory.path,
          path.join(assetRoot.path, '.audio_spool', 'daily-session'),
        );
        expect(
          capture.sessionDirectory.listSync().whereType<File>().map(
            (file) => path.basename(file.path),
          ),
          contains('manifest-00000001.json'),
        );
        await capture.discard();
      },
    );

    test(
      'allocates a UUID when no durable identity factory is supplied',
      () async {
        final bench = await RealtimeTranscriptionTestBench.create(
          addConfig: false,
        );
        addTearDown(bench.dispose);
        final assetRoot = await Directory(
          path.join(bench.rootDirectory.path, 'default-id-assets'),
        ).create();

        final capture = await bench.service.prepareDefaultDurableCapture(
          assetRootDirectory: assetRoot,
          createdAt: DateTime.utc(2026, 7, 18, 8, 30),
          origin: AudioCaptureOrigin.dailyOs,
          intent: AudioCaptureIntent.dayPlan,
        );

        expect(
          Uuid.isValidUUID(fromString: capture.recordingSessionId),
          isTrue,
        );
        expect(capture.activityEntryId, isNotEmpty);
        await capture.discard();
      },
    );

    test('keeps local capture active when no backend is configured', () async {
      final bench = await RealtimeTranscriptionTestBench.create(
        addConfig: false,
      );
      addTearDown(bench.dispose);
      final capture = await bench.prepareCapture();

      await bench.service.startRealtimeTranscription(
        capture: capture,
        pcmStream: const Stream<Uint8List>.empty(),
        onDelta: (_) {},
      );

      expect(bench.service.isActive, isTrue);
      expect(capture.spool.manifest.state, DurableAudioSpoolState.recording);
    });

    test(
      'connects WebSocket, sets isActive, and forwards PCM as base64',
      () async {
        final bench = await RealtimeTranscriptionTestBench.create();
        addTearDown(bench.dispose);

        await bench.startTranscription();
        expect(bench.service.isActive, isTrue);

        // State alone proves little — the appended audio on the wire shows
        // the session is actually live.
        await bench.sendPcm(pcmSilence(64));

        expect(bench.channel.sentMessages, isNotEmpty);
        final msg =
            jsonDecode(bench.channel.sentMessages.last) as Map<String, dynamic>;
        expect(msg['type'], 'input_audio.append');
        expect(msg['audio'], isNotEmpty);
      },
    );

    test('flushes each PCM frame before forwarding it', () async {
      final repository = ControllableRealtimeRepository();
      final bench = await RealtimeTranscriptionTestBench.create(
        repository: repository,
      );
      addTearDown(() async {
        await repository.close();
        bench.dispose();
      });
      late Uint8List bytesAtSend;
      repository.onSendAudioChunk = (_) {
        bytesAtSend = File(
          '${bench.activeCapture!.sessionDirectory.path}/'
          'active-00000000.part',
        ).readAsBytesSync();
      };
      await bench.startTranscription();
      final pcm = Uint8List.fromList(<int>[1, 2, 3, 4]);

      await bench.sendPcm(pcm);

      expect(bytesAtSend, pcm);
      expect(repository.sentChunks.single, pcm);
    });

    test(
      'retains local audio when the realtime backend cannot connect',
      () async {
        final repository = ControllableRealtimeRepository()
          ..connectError = Exception('offline');
        final bench = await RealtimeTranscriptionTestBench.create(
          repository: repository,
        );
        addTearDown(() async {
          await repository.close();
          bench.dispose();
        });
        await bench.startTranscription();
        final pcm = Uint8List.fromList(<int>[5, 6, 7, 8]);
        await bench.sendPcm(pcm);

        final result = await bench.stop();

        expect(result.usedTranscriptFallback, isTrue);
        expect(result.audioFilePath, isNotNull);
        expect(File(result.audioFilePath!).readAsBytesSync().sublist(44), pcm);
        expect(repository.sentChunks, isEmpty);
      },
    );

    test(
      'rejects a second durable capture while the first remains active',
      () async {
        final bench = await RealtimeTranscriptionTestBench.create();
        addTearDown(bench.dispose);

        final pcm1 = await bench.startTranscription();
        final firstCapture = bench.activeCapture!;
        expect(bench.service.isActive, isTrue);

        await expectLater(
          bench.startTranscription,
          throwsA(isA<StateError>()),
        );
        final rejectedCapture = bench.activeCapture!;
        var rejectedRecorderStops = 0;
        await bench.service.stopAndRetainForRecovery(
          capture: rejectedCapture,
          stopRecorder: () async {
            rejectedRecorderStops += 1;
          },
        );

        // The original session survives the failed restart: its PCM stream
        // still reaches the wire and the rejected caller only stops its own
        // recorder.
        expect(bench.service.isActive, isTrue);
        expect(rejectedRecorderStops, 1);
        expect(
          firstCapture.spool.manifest.state,
          DurableAudioSpoolState.recording,
        );
        pcm1.add(pcmSilence(64));
        await bench.service.flushPendingPcm();
        final msg =
            jsonDecode(bench.channel.sentMessages.last) as Map<String, dynamic>;
        expect(msg['type'], 'input_audio.append');
        await rejectedCapture.discard();
      },
    );

    test('slow backend setup cannot resurrect a stopped capture', () async {
      final repository = ControllableRealtimeRepository()
        ..connectGate = Completer<void>();
      final bench = await RealtimeTranscriptionTestBench.create(
        repository: repository,
      );
      addTearDown(() async {
        await repository.close();
        bench.dispose();
      });
      final capture = await bench.prepareCapture();
      final pcm = StreamController<Uint8List>(sync: true);
      final recoveryStopStarted = Completer<Future<void>>();
      final start = bench.service.startRealtimeTranscription(
        capture: capture,
        pcmStream: pcm.stream,
        onDelta: (_) {},
        onCaptureFailure: (_, _) {
          recoveryStopStarted.complete(
            bench.service.stopAndRetainForRecovery(
              capture: capture,
              stopRecorder: pcm.close,
            ),
          );
        },
      );
      await repository.connectStarted.future;

      pcm.addError(StateError('microphone disconnected'));
      await (await recoveryStopStarted.future);
      expect(bench.service.isActive, isFalse);

      repository.connectGate!.complete();
      await start;

      expect(bench.service.isActive, isFalse);
      expect(repository.disconnected, isTrue);
      expect(repository.sentChunks, isEmpty);
    });

    test('slow MLX setup is cancelled after recovery teardown', () async {
      final bench = await RealtimeTranscriptionTestBench.create(
        addConfig: false,
        addMlxConfig: true,
      );
      addTearDown(bench.dispose);
      final gate = Completer<void>();
      bench.mlxAudioChannel.startGate = gate;
      final capture = await bench.prepareCapture();
      final pcm = StreamController<Uint8List>();

      final start = bench.service.startRealtimeTranscription(
        capture: capture,
        pcmStream: pcm.stream,
        onDelta: (_) {},
      );
      await bench.mlxAudioChannel.startEntered.future;
      await bench.service.stopAndRetainForRecovery(
        capture: capture,
        stopRecorder: pcm.close,
      );
      gate.complete();
      await start;

      expect(bench.service.isActive, isFalse);
      expect(bench.mlxAudioChannel.cancelled, isTrue);
    });

    test('emits amplitude values from PCM chunks', () async {
      final bench = await RealtimeTranscriptionTestBench.create();
      addTearDown(bench.dispose);

      final amplitudes = <double>[];
      bench.service.amplitudeStream.listen(amplitudes.add);

      await bench.startTranscription();
      await bench.sendPcm(pcmSilence(64));
      await Future<void>.value();

      expect(amplitudes, isNotEmpty);
    });

    test('calls onDelta callback for each transcription delta', () async {
      final bench = await RealtimeTranscriptionTestBench.create();
      addTearDown(bench.dispose);

      final deltas = <String>[];
      final received = Completer<void>();
      await bench.startTranscription(
        onDelta: (delta) {
          deltas.add(delta);
          if (deltas.length == 2 && !received.isCompleted) {
            received.complete();
          }
        },
      );
      bench.channel.simulateServerMessage({
        'type': 'transcription.text.delta',
        'text': 'Hello ',
      });
      bench.channel.simulateServerMessage({
        'type': 'transcription.text.delta',
        'text': 'world',
      });
      await received.future;

      expect(deltas, ['Hello ', 'world']);
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
      'keeps durable local capture active when MLX startup fails',
      () async {
        final bench = await RealtimeTranscriptionTestBench.create(
          addConfig: false,
          addMlxConfig: true,
        );
        addTearDown(bench.dispose);
        bench.mlxAudioChannel.startError = Exception('native start failed');

        await bench.startTranscription();
        await bench.sendPcm(pcmSilence(64));

        expect(bench.service.isActive, isTrue);
        expect(bench.mlxAudioChannel.cancelled, isTrue);
        final result = await bench.stop();
        expect(result.audioFilePath, isNotNull);
        expect(result.usedTranscriptFallback, isTrue);
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

        await bench.startTranscription();
        await bench.sendPcm(pcmSilence(64));

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
        final result = await bench.stop(
          afterListening: () => bench.mlxAudioChannel.emit(
            const MlxAudioRealtimeEvent(
              type: MlxAudioRealtimeEventType.error,
              message: 'inference crashed',
            ),
          ),
        );

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
        final result = await bench.stop(
          afterListening: () => bench.mlxAudioChannel.eventsController.addError(
            Exception('event stream broken'),
          ),
        );

        expect(result.usedTranscriptFallback, isTrue);
        expect(
          fakeLogging.exceptions.map((error) => error.toString()),
          contains(contains('event stream broken')),
        );
      },
    );

    test('logs MLX PCM stream errors and retains the durable source', () async {
      final bench = await RealtimeTranscriptionTestBench.create(
        addConfig: false,
        addMlxConfig: true,
      );
      addTearDown(bench.dispose);
      final pcm = await bench.startTranscription();

      pcm.addError(Exception('mlx microphone disconnected'));
      await pumpEventQueue();

      expect(
        fakeLogging.exceptions.map((error) => error.toString()),
        contains(contains('mlx microphone disconnected')),
      );
      expect(bench.service.isActive, isTrue);
      expect(bench.activeCapture!.sessionDirectory.existsSync(), isTrue);
    });
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
      await Future<void>.value();

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
      await pumpEventQueue();

      // Don't send transcription.done — let the short timeout trigger the
      // accumulated-delta fallback. The recorder callback closes the source
      // stream before stop returns.
      final result = await bench.stop();

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

    test('finalizes local audio when endAudio fails', () async {
      final repo = ControllableRealtimeRepository()
        ..endAudioError = Exception('network dropped at endAudio');
      final bench = await RealtimeTranscriptionTestBench.create(
        repository: repo,
      );
      addTearDown(() async {
        await repo.close();
        bench.dispose();
      });
      await bench.startTranscription();
      await bench.sendPcm(pcmSilence(64));

      final result = await bench.stop();

      expect(repo.endAudioCalled, isTrue);
      expect(result.audioFilePath, isNotNull);
      expect(result.usedTranscriptFallback, isTrue);
      expect(result.captureDisposition, RealtimeCaptureDisposition.complete);
    });

    test('cleanup failure cannot override a finalized local result', () async {
      final repo = ControllableRealtimeRepository()
        ..disconnectError = Exception('disconnect failed');
      final bench = await RealtimeTranscriptionTestBench.create(
        repository: repo,
      );
      addTearDown(() async {
        await repo.close();
        bench.dispose();
      });
      await bench.startTranscription();
      await bench.sendPcm(pcmSilence(64));

      final result = await bench.stop(
        afterListening: () => repo.doneController.add(
          const RealtimeTranscriptionDone(text: 'done'),
        ),
      );

      expect(result.audioFilePath, isNotNull);
      expect(result.captureDisposition, RealtimeCaptureDisposition.complete);
      expect(
        fakeLogging.exceptions.map((error) => error.toString()),
        contains(contains('disconnect failed')),
      );
    });

    test(
      'terminal listener cancellation cannot override a finalized result',
      () async {
        final repo = ControllableRealtimeRepository(
          throwOnDoneCancel: true,
        );
        final bench = await RealtimeTranscriptionTestBench.create(
          repository: repo,
        );
        addTearDown(() async {
          await repo.close();
          bench.dispose();
        });
        await bench.startTranscription();
        await bench.sendPcm(pcmSilence(64));

        final result = await bench.stop(
          afterListening: () => repo.doneController.add(
            const RealtimeTranscriptionDone(text: 'done'),
          ),
        );

        expect(result.audioFilePath, isNotNull);
        expect(result.captureDisposition, RealtimeCaptureDisposition.complete);
        expect(bench.service.isActive, isFalse);
        expect(
          fakeLogging.exceptions.map((error) => error.toString()),
          contains(contains('done cancellation failed')),
        );
      },
    );

    test('concurrent stop calls share one terminal operation', () async {
      final bench = await RealtimeTranscriptionTestBench.create();
      addTearDown(bench.dispose);
      await bench.startTranscription();
      await bench.sendPcm(pcmSilence(64));
      final outputPath = path.join(
        bench.rootDirectory.path,
        'assets',
        'shared-stop',
      );
      var recorderStops = 0;

      final first = bench.stop(
        outputPath: outputPath,
        stopRecorder: () async {
          recorderStops += 1;
        },
        afterListening: () => bench.simulateDone('done'),
      );
      final second = bench.service.stop(
        capture: bench.activeCapture!,
        stopRecorder: () async {
          recorderStops += 1;
        },
        outputPath: outputPath,
      );

      final results = await Future.wait([first, second]);
      expect(recorderStops, 1);
      expect(results[0].audioFilePath, results[1].audioFilePath);
    });

    test('rejects a concurrent stop targeting another output', () async {
      final bench = await RealtimeTranscriptionTestBench.create();
      addTearDown(bench.dispose);
      await bench.startTranscription();
      await bench.sendPcm(pcmSilence(64));
      final firstOutput = path.join(
        bench.rootDirectory.path,
        'assets',
        'first-stop',
      );
      final first = bench.stop(
        outputPath: firstOutput,
        afterListening: () => bench.simulateDone('done'),
      );

      await expectLater(
        bench.service.stop(
          capture: bench.activeCapture!,
          stopRecorder: () async {},
          outputPath: path.join(
            bench.rootDirectory.path,
            'assets',
            'different-stop',
          ),
        ),
        throwsStateError,
      );
      final result = await first;

      expect(result.audioFilePath, '$firstOutput.wav');
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

    test('saves a partial WAV when recorder stop fails', () async {
      final bench = await RealtimeTranscriptionTestBench.create();
      addTearDown(bench.dispose);

      await bench.startTranscription();
      await bench.sendPcm(pcmSilence(64));

      final result = await bench.stop(
        stopRecorder: () => Future<void>.error(
          StateError('recorder stop failed'),
        ),
        afterListening: () => bench.simulateDone('accepted prefix'),
      );

      expect(result.audioFilePath, isNotNull);
      expect(
        result.captureDisposition,
        RealtimeCaptureDisposition.savedPartial,
      );
      expect(
        fakeLogging.exceptions.map((error) => error.toString()),
        contains(contains('recorder stop failed')),
      );
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

        final result = await bench.stop();

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

      final result = await bench.stop();

      expect(result.transcript, 'partial local transcript');
      expect(result.usedTranscriptFallback, isTrue);
      expect(
        fakeLogging.exceptions.map((e) => e.toString()),
        contains(contains('native stop failed')),
      );
    });

    test(
      'finalizes local audio when the transcription.done stream errors',
      () async {
        final repo = ControllableRealtimeRepository();
        final bench = await RealtimeTranscriptionTestBench.create(
          repository: repo,
          doneTimeout: const Duration(seconds: 30),
        );
        addTearDown(() async {
          await repo.close();
          bench.dispose();
        });
        await bench.startTranscription();
        await bench.sendPcm(pcmSilence(64));

        final stopFuture = bench.stop(
          afterListening: () =>
              repo.doneController.addError(StateError('done stream exploded')),
        );

        final result = await stopFuture;

        expect(repo.endAudioCalled, isTrue);
        expect(result.audioFilePath, isNotNull);
        expect(result.usedTranscriptFallback, isTrue);
        expect(
          result.captureDisposition,
          RealtimeCaptureDisposition.complete,
        );
        expect(bench.service.isActive, isFalse);
      },
    );
  });

  group('dispose', () {
    test('cancels subscriptions and cleans up', () async {
      final bench = await RealtimeTranscriptionTestBench.create();
      addTearDown(bench.dispose);

      await bench.startTranscription();
      expect(bench.service.isActive, isTrue);

      await bench.service.dispose(
        capture: bench.activeCapture!,
        stopRecorder: bench.closePcm,
      );
      expect(bench.service.isActive, isFalse);
    });

    test('cleans up even with buffered PCM data', () async {
      final bench = await RealtimeTranscriptionTestBench.create();
      addTearDown(bench.dispose);

      await bench.startTranscription();
      await bench.sendPcm(pcmSilence(64));

      await bench.service.dispose(
        capture: bench.activeCapture!,
        stopRecorder: bench.closePcm,
      );
      expect(bench.service.isActive, isFalse);
    });

    test('waits for an in-flight stop instead of racing its cleanup', () async {
      final repository = ControllableRealtimeRepository();
      final bench = await RealtimeTranscriptionTestBench.create(
        repository: repository,
      );
      addTearDown(() async {
        await repository.close();
        bench.dispose();
      });
      await bench.startTranscription();
      await bench.sendPcm(pcmSilence(64));

      final stopFuture = bench.stop();
      final disposeFuture = bench.service.dispose(
        capture: bench.activeCapture!,
        stopRecorder: bench.closePcm,
      );
      final otherCapture = await bench.prepareCapture();
      var otherRecorderStops = 0;
      await bench.service.stopAndRetainForRecovery(
        capture: otherCapture,
        stopRecorder: () async => otherRecorderStops += 1,
      );
      repository.doneController.add(
        const RealtimeTranscriptionDone(text: 'terminal transcript'),
      );

      final result = await stopFuture;
      await disposeFuture;

      expect(result.transcript, 'terminal transcript');
      expect(result.audioFilePath, isNotNull);
      expect(bench.service.isActive, isFalse);
      expect(otherRecorderStops, 1);
      await otherCapture.discard();
    });

    test(
      'recovery teardown drains buffered frames before cancellation',
      () async {
        final bench = await RealtimeTranscriptionTestBench.create(
          addConfig: false,
        );
        addTearDown(bench.dispose);
        final enteredFlush = Completer<void>();
        final releaseFlush = Completer<void>();
        var blocked = false;
        final capture = await bench.service.prepareDurableCapture(
          rootDirectory: Directory(
            path.join(bench.rootDirectory.path, 'buffered-spool'),
          ),
          context: DurableAudioSpoolContext(
            recordingSessionId: 'buffered-teardown',
            activityEntryId: 'activity-buffered-teardown',
            createdAt: DateTime.utc(2026, 7, 18, 7, 30),
            assetRootPath: path.join(bench.rootDirectory.path, 'assets'),
          ),
          durability: AudioSpoolDurability(
            onBoundary: (boundary) async {
              if (!blocked &&
                  boundary == AudioSpoolDurabilityBoundary.activeFileFlushed) {
                blocked = true;
                enteredFlush.complete();
                await releaseFlush.future;
              }
            },
          ),
        );
        final pcm = StreamController<Uint8List>();
        await bench.service.startRealtimeTranscription(
          capture: capture,
          pcmStream: pcm.stream,
          onDelta: (_) {},
        );
        pcm
          ..add(pcmSilence(64))
          ..add(pcmSilence(64));
        await enteredFlush.future;

        var teardownCompleted = false;
        final teardown = bench.service
            .stopAndRetainForRecovery(
              capture: capture,
              stopRecorder: pcm.close,
            )
            .then((_) => teardownCompleted = true);
        await pumpEventQueue();
        expect(teardownCompleted, isFalse);

        releaseFlush.complete();
        await teardown;
        final recovery = await DurableAudioSpool.recover(
          sessionDirectory: capture.sessionDirectory,
        );
        expect(recovery.manifest.acceptedPcmBytes, 128);
        expect(recovery.isQuarantined, isFalse);
      },
    );

    test(
      'blocks a new session until recovery teardown fully completes',
      () async {
        final repository = ControllableRealtimeRepository()
          ..disconnectGate = Completer<void>();
        final bench = await RealtimeTranscriptionTestBench.create(
          repository: repository,
        );
        addTearDown(() async {
          final disconnectGate = repository.disconnectGate;
          if (disconnectGate != null && !disconnectGate.isCompleted) {
            disconnectGate.complete();
          }
          bench.dispose();
        });
        final firstCapture = await bench.prepareCapture();
        final firstPcm = StreamController<Uint8List>();
        await bench.service.startRealtimeTranscription(
          capture: firstCapture,
          pcmStream: firstPcm.stream,
          onDelta: (_) {},
        );

        final teardown = bench.service.stopAndRetainForRecovery(
          capture: firstCapture,
          stopRecorder: firstPcm.close,
        );
        await repository.disconnectStarted.future;
        final secondCapture = await bench.prepareCapture();
        final rejectedPcm = StreamController<Uint8List>.broadcast();
        var secondRecorderStops = 0;
        await bench.service.stopAndRetainForRecovery(
          capture: secondCapture,
          stopRecorder: () async => secondRecorderStops += 1,
        );
        expect(secondRecorderStops, 1);

        await expectLater(
          bench.service.startRealtimeTranscription(
            capture: secondCapture,
            pcmStream: rejectedPcm.stream,
            onDelta: (_) {},
          ),
          throwsStateError,
        );
        await rejectedPcm.close();

        repository.disconnectGate!.complete();
        await teardown;
        final secondPcm = StreamController<Uint8List>();
        await bench.service.startRealtimeTranscription(
          capture: secondCapture,
          pcmStream: secondPcm.stream,
          onDelta: (_) {},
        );
        expect(bench.service.isActive, isTrue);
        await bench.service.stopAndRetainForRecovery(
          capture: secondCapture,
          stopRecorder: secondPcm.close,
        );
        expect(bench.service.isActive, isFalse);
        await repository.close();
      },
    );

    test('rejects normal stop while recovery retention is in flight', () async {
      final repository = ControllableRealtimeRepository()
        ..disconnectGate = Completer<void>();
      final bench = await RealtimeTranscriptionTestBench.create(
        repository: repository,
      );
      addTearDown(() async {
        final gate = repository.disconnectGate;
        if (gate != null && !gate.isCompleted) gate.complete();
        bench.dispose();
      });
      final capture = await bench.prepareCapture();
      final pcm = StreamController<Uint8List>();
      await bench.service.startRealtimeTranscription(
        capture: capture,
        pcmStream: pcm.stream,
        onDelta: (_) {},
      );

      final retention = bench.service.stopAndRetainForRecovery(
        capture: capture,
        stopRecorder: pcm.close,
      );
      await repository.disconnectStarted.future;

      await expectLater(
        bench.service.stop(
          capture: capture,
          stopRecorder: () async {},
          outputPath: path.join(bench.rootDirectory.path, 'must-not-finalize'),
        ),
        throwsStateError,
      );

      repository.disconnectGate!.complete();
      await retention;
      expect(bench.service.isActive, isFalse);
      await repository.close();
    });
  });

  group('PCM stream error handling', () {
    test(
      'retains a durable prefix when recorder shutdown never closes PCM',
      () async {
        final bench = await RealtimeTranscriptionTestBench.create(
          addConfig: false,
          pcmDrainTimeout: Duration.zero,
        );
        addTearDown(bench.dispose);
        final pcm = await bench.startTranscription();
        await bench.sendPcm(pcmSilence(64));

        final result = await bench.service.stop(
          capture: bench.activeCapture!,
          stopRecorder: () async {},
          outputPath: path.join(
            bench.rootDirectory.path,
            'assets',
            'pcm-drain-timeout',
          ),
        );
        await pcm.close();

        expect(
          result.captureDisposition,
          RealtimeCaptureDisposition.savedPartial,
        );
        expect(File(result.audioFilePath!).lengthSync(), 44 + 64);
        expect(
          fakeLogging.events,
          contains(contains('PCM stream did not close')),
        );
      },
    );

    test(
      'signals spool saturation once so the caller can stop the recorder',
      () async {
        final bench = await RealtimeTranscriptionTestBench.create(
          addConfig: false,
        );
        addTearDown(bench.dispose);
        final enteredFlush = Completer<void>();
        final releaseFlush = Completer<void>();
        var blocked = false;
        final capture = await bench.service.prepareDurableCapture(
          rootDirectory: Directory(
            path.join(bench.rootDirectory.path, 'saturated-spool'),
          ),
          context: DurableAudioSpoolContext(
            recordingSessionId: 'saturated-session',
            activityEntryId: 'activity-saturated-session',
            createdAt: DateTime.utc(2026, 7, 18, 7, 30),
            assetRootPath: path.join(bench.rootDirectory.path, 'assets'),
          ),
          maxPendingBytes: 4,
          durability: AudioSpoolDurability(
            onBoundary: (boundary) async {
              if (!blocked &&
                  boundary == AudioSpoolDurabilityBoundary.activeFileFlushed) {
                blocked = true;
                enteredFlush.complete();
                await releaseFlush.future;
              }
            },
          ),
        );
        final pcm = StreamController<Uint8List>(sync: true);
        final failures = <Object>[];
        final signalled = Completer<void>();
        await bench.service.startRealtimeTranscription(
          capture: capture,
          pcmStream: pcm.stream,
          onDelta: (_) {},
          onCaptureFailure: (error, _) {
            failures.add(error);
            if (!signalled.isCompleted) signalled.complete();
          },
        );
        pcm
          ..add(Uint8List.fromList(<int>[1, 2]))
          ..add(Uint8List.fromList(<int>[3, 4]));
        await enteredFlush.future;
        pcm.add(Uint8List.fromList(<int>[5, 6]));

        await signalled.future;

        expect(failures, hasLength(1));
        expect(
          failures.single,
          isA<DurableAudioSpoolRecoveryRequiredException>(),
        );
        releaseFlush.complete();
        final result = await bench.service.stop(
          capture: capture,
          stopRecorder: pcm.close,
          outputPath: path.join(
            bench.rootDirectory.path,
            'assets',
            'saturated-output',
          ),
        );
        expect(
          result.captureDisposition,
          RealtimeCaptureDisposition.savedPartial,
        );
        expect(File(result.audioFilePath!).readAsBytesSync().sublist(44), [
          1,
          2,
          3,
          4,
        ]);
      },
    );

    test(
      'returns a saved-partial result when PCM stream emits error',
      () async {
        final bench = await RealtimeTranscriptionTestBench.create();
        addTearDown(bench.dispose);
        final pcm = await bench.startTranscription();
        await bench.sendPcm(pcmSilence(64));

        pcm.addError(Exception('microphone disconnected'));
        await pumpEventQueue();
        final result = await bench.stop(
          afterListening: () => bench.simulateDone('partial'),
        );

        expect(fakeLogging.exceptions, isNotEmpty);
        expect(
          fakeLogging.exceptions.first.toString(),
          contains('microphone disconnected'),
        );
        expect(result.audioFilePath, isNotNull);
        expect(
          result.captureDisposition,
          RealtimeCaptureDisposition.savedPartial,
        );
      },
    );
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
      'keeps the durable WAV without invoking lossy conversion',
      () async {
        const channel = MethodChannel('com.matthiasn.lotti/audio_converter');
        var converterCalls = 0;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              if (call.method == 'convertWavToM4a') {
                converterCalls += 1;
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
        expect(result.audioFilePath, endsWith('.wav'));
        expect(converterCalls, 0);
        expect(File(result.audioFilePath!).existsSync(), isTrue);
        await bench.activeCapture!.markCommitted(
          journalAudioId: 'journal-audio-1',
        );
        expect(
          bench.activeCapture!.spool.manifest.journalAudioId,
          'journal-audio-1',
        );
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
      await bench.activeCapture!.consumeTransient();
      expect(
        bench.activeCapture!.spool.manifest.state,
        DurableAudioSpoolState.discarded,
      );
      expect(File(result.audioFilePath!).existsSync(), isFalse);
    });

    test(
      'rejects publication outside the asset root and retains recovery',
      () async {
        final bench = await RealtimeTranscriptionTestBench.create();
        addTearDown(bench.dispose);

        await bench.startTranscription();
        await bench.sendPcm(pcmSilence(64));

        final result = await bench.stop(
          outputPath: '/nonexistent/deeply/nested/path/output',
          afterListening: () => bench.simulateDone('test'),
        );
        expect(
          result.captureDisposition,
          RealtimeCaptureDisposition.recoveryRequired,
        );
        expect(result.audioFilePath, isNull);

        final recovery = await DurableAudioSpool.recover(
          sessionDirectory: bench.activeCapture!.sessionDirectory,
        );
        expect(recovery.isQuarantined, isFalse);
        expect(recovery.manifest.acceptedPcmBytes, 64);
      },
    );
  });

  group('durable PCM capacity', () {
    test('persists a long recording beyond the amplitude buffer cap', () async {
      final bench = await RealtimeTranscriptionTestBench.create();
      addTearDown(bench.dispose);

      await bench.startTranscription();

      // Send chunks that exceed the max buffer size (3,840,000 bytes)
      // Each chunk is 64,000 bytes, so 61 chunks = 3,904,000 bytes > max
      for (var i = 0; i < 61; i++) {
        await bench.sendPcm(Uint8List.fromList(List.filled(64000, i)));
      }

      final result = await bench.stop(
        afterListening: () => bench.simulateDone('long recording test'),
      );

      expect(result.transcript, 'long recording test');
      expect(result.audioFilePath, isNotNull);
      expect(
        File(result.audioFilePath!).lengthSync(),
        44 + (61 * 64000),
      );
    });

    test('rejects a single frame larger than bounded spool capacity', () async {
      final bench = await RealtimeTranscriptionTestBench.create();
      addTearDown(bench.dispose);

      final failure = Completer<Object>();
      await bench.startTranscription(
        onCaptureFailure: (error, _) => failure.complete(error),
      );

      // Send a single chunk that exceeds the max buffer size (3,840,000 bytes)
      final oversizedChunk = Uint8List.fromList(
        List.generate(4000000, (i) => i % 256),
      );
      await bench.sendPcm(oversizedChunk);
      expect(
        await failure.future,
        isA<DurableAudioSpoolRecoveryRequiredException>(),
      );

      expect(bench.activeCapture!.spool.manifest.acceptedPcmBytes, 0);
    });
  });
}
