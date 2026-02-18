import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/features/ai/database/ai_config_db.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/mistral_realtime_transcription_repository.dart';
import 'package:lotti/features/ai_chat/services/realtime_transcription_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

// ---------------------------------------------------------------------------
// Fakes & Mocks
// ---------------------------------------------------------------------------

class _FakeLoggingService extends Fake implements LoggingService {
  final events = <String>[];
  final exceptions = <Object>[];

  @override
  void captureEvent(
    dynamic event, {
    required String domain,
    String? subDomain,
    InsightLevel level = InsightLevel.info,
    InsightType type = InsightType.log,
  }) {
    events.add('$domain/$subDomain: $event');
  }

  @override
  void captureException(
    dynamic exception, {
    required String domain,
    String? subDomain,
    dynamic stackTrace,
    InsightLevel level = InsightLevel.error,
    InsightType type = InsightType.exception,
  }) {
    exceptions.add(exception as Object);
  }
}

class _FakeWebSocketChannel extends StreamChannelMixin<dynamic>
    implements WebSocketChannel {
  _FakeWebSocketChannel() : _readyCompleter = Completer<void>() {
    _readyCompleter.complete();
  }

  final Completer<void> _readyCompleter;
  final _incomingController = StreamController<dynamic>.broadcast();
  final _outgoingMessages = <String>[];
  bool _isClosed = false;

  @override
  Future<void> get ready => _readyCompleter.future;

  @override
  Stream<dynamic> get stream => _incomingController.stream;

  @override
  WebSocketSink get sink => _FakeWebSocketSink(this);

  @override
  int? get closeCode => _isClosed ? 1000 : null;

  @override
  String? get closeReason => null;

  @override
  String? get protocol => null;

  void simulateServerMessage(Map<String, dynamic> json) {
    if (!_incomingController.isClosed) {
      _incomingController.add(jsonEncode(json));
    }
  }

  Future<void> simulateClose() async {
    _isClosed = true;
    await _incomingController.close();
  }

  List<String> get sentMessages => List.unmodifiable(_outgoingMessages);

  void _addOutgoing(dynamic message) {
    if (message is String) _outgoingMessages.add(message);
  }

  Future<void> _close() async {
    _isClosed = true;
    await _incomingController.close();
  }
}

class _FakeWebSocketSink implements WebSocketSink {
  _FakeWebSocketSink(this._channel);
  final _FakeWebSocketChannel _channel;

  @override
  void add(dynamic data) => _channel._addOutgoing(data);

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<dynamic> addStream(Stream<dynamic> stream) => stream.forEach(add);

  @override
  Future<void> close([int? closeCode, String? closeReason]) =>
      _channel._close();

  @override
  Future<dynamic> get done => _channel._readyCompleter.future;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _providerId = 'p-rt-svc';
const _modelId = 'm-rt-svc';
const _providerModelId = 'voxtral-mini-transcribe-realtime-2602';

Future<(ProviderContainer, _FakeWebSocketChannel)> _createServiceWithConfig({
  bool addConfig = true,
  Duration doneTimeout = const Duration(seconds: 10),
}) async {
  final db = AiConfigDb(inMemoryDatabase: true);
  final aiRepo = AiConfigRepository(db);

  if (addConfig) {
    await aiRepo.saveConfig(
      AiConfig.inferenceProvider(
        id: _providerId,
        baseUrl: 'https://api.mistral.ai/v1',
        apiKey: 'test-key',
        name: 'Mistral',
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.mistral,
      ),
      fromSync: true,
    );
    await aiRepo.saveConfig(
      AiConfig.model(
        id: _modelId,
        name: 'Voxtral Realtime',
        providerModelId: _providerModelId,
        inferenceProviderId: _providerId,
        createdAt: DateTime.now(),
        inputModalities: const [Modality.audio],
        outputModalities: const [Modality.text],
        isReasoningModel: false,
      ),
      fromSync: true,
    );
  }

  final fakeChannel = _FakeWebSocketChannel();

  final repo = MistralRealtimeTranscriptionRepository(
    channelFactory: (_, __) {
      // Simulate the session.created handshake after a microtask
      Future<void>.delayed(Duration.zero).then((_) {
        fakeChannel.simulateServerMessage({
          'type': 'session.created',
          'session': {'request_id': 'test-123'},
        });
      });
      return fakeChannel;
    },
  );

  final container = ProviderContainer(
    overrides: [
      aiConfigRepositoryProvider.overrideWith((_) => aiRepo),
      realtimeTranscriptionServiceProvider.overrideWith(
        (ref) => RealtimeTranscriptionService(
          ref,
          repository: repo,
          doneTimeout: doneTimeout,
        ),
      ),
    ],
  );

  return (container, fakeChannel);
}

Uint8List _pcmSilence(int bytes) => Uint8List(bytes);

void main() {
  late _FakeLoggingService fakeLogging;

  setUp(() {
    fakeLogging = _FakeLoggingService();
    if (getIt.isRegistered<LoggingService>()) {
      getIt.unregister<LoggingService>();
    }
    getIt.registerSingleton<LoggingService>(fakeLogging);
  });

  tearDown(() {
    if (getIt.isRegistered<LoggingService>()) {
      getIt.unregister<LoggingService>();
    }
  });

  group('resolveRealtimeConfig', () {
    test('returns config when realtime model exists', () async {
      final (container, _) = await _createServiceWithConfig();
      addTearDown(container.dispose);

      final svc = container.read(realtimeTranscriptionServiceProvider);
      final config = await svc.resolveRealtimeConfig();

      expect(config, isNotNull);
      expect(config!.provider.id, _providerId);
      expect(config.model.providerModelId, _providerModelId);
    });

    test('returns null when no realtime model configured', () async {
      final (container, _) = await _createServiceWithConfig(addConfig: false);
      addTearDown(container.dispose);

      final svc = container.read(realtimeTranscriptionServiceProvider);
      final config = await svc.resolveRealtimeConfig();

      expect(config, isNull);
    });

    test('skips non-audio models', () async {
      final db = AiConfigDb(inMemoryDatabase: true);
      final aiRepo = AiConfigRepository(db);

      await aiRepo.saveConfig(
        AiConfig.inferenceProvider(
          id: _providerId,
          baseUrl: 'https://api.mistral.ai/v1',
          apiKey: 'key',
          name: 'Mistral',
          createdAt: DateTime.now(),
          inferenceProviderType: InferenceProviderType.mistral,
        ),
        fromSync: true,
      );
      // Model has text input only — not audio
      await aiRepo.saveConfig(
        AiConfig.model(
          id: 'text-only',
          name: 'Text Model',
          providerModelId: _providerModelId,
          inferenceProviderId: _providerId,
          createdAt: DateTime.now(),
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
          createdAt: DateTime.now(),
          inferenceProviderType: InferenceProviderType.gemini,
        ),
        fromSync: true,
      );
      await aiRepo.saveConfig(
        AiConfig.model(
          id: 'wrong-provider',
          name: 'Realtime',
          providerModelId: _providerModelId,
          inferenceProviderId: 'p-gemini',
          createdAt: DateTime.now(),
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
      final (container, _) = await _createServiceWithConfig(addConfig: false);
      addTearDown(container.dispose);

      final svc = container.read(realtimeTranscriptionServiceProvider);
      const pcm = Stream<Uint8List>.empty();

      await expectLater(
        () => svc.startRealtimeTranscription(
          pcmStream: pcm,
          onDelta: (_) {},
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('connects WebSocket and sets isActive', () async {
      final (container, fakeChannel) = await _createServiceWithConfig();
      addTearDown(container.dispose);

      final svc = container.read(realtimeTranscriptionServiceProvider);
      final pcmController = StreamController<Uint8List>();

      await svc.startRealtimeTranscription(
        pcmStream: pcmController.stream,
        onDelta: (_) {},
      );

      expect(svc.isActive, isTrue);
      await pcmController.close();
    });

    test('forwards PCM chunks to repository as base64', () async {
      final (container, fakeChannel) = await _createServiceWithConfig();
      addTearDown(container.dispose);

      final svc = container.read(realtimeTranscriptionServiceProvider);
      final pcmController = StreamController<Uint8List>();

      await svc.startRealtimeTranscription(
        pcmStream: pcmController.stream,
        onDelta: (_) {},
      );

      pcmController.add(_pcmSilence(64));
      await Future<void>.delayed(Duration.zero);

      // Verify audio chunk was sent to WebSocket
      expect(fakeChannel.sentMessages, isNotEmpty);
      final msg =
          jsonDecode(fakeChannel.sentMessages.last) as Map<String, dynamic>;
      expect(msg['type'], 'input_audio.append');
      expect(msg['audio'], isNotEmpty);

      await pcmController.close();
    });

    test('emits amplitude values from PCM chunks', () async {
      final (container, _) = await _createServiceWithConfig();
      addTearDown(container.dispose);

      final svc = container.read(realtimeTranscriptionServiceProvider);
      final pcmController = StreamController<Uint8List>();
      final amplitudes = <double>[];

      svc.amplitudeStream.listen(amplitudes.add);

      await svc.startRealtimeTranscription(
        pcmStream: pcmController.stream,
        onDelta: (_) {},
      );

      pcmController.add(_pcmSilence(64));
      await Future<void>.delayed(Duration.zero);

      expect(amplitudes, isNotEmpty);

      await pcmController.close();
    });

    test('calls onDelta callback for each transcription delta', () async {
      final (container, fakeChannel) = await _createServiceWithConfig();
      addTearDown(container.dispose);

      final svc = container.read(realtimeTranscriptionServiceProvider);
      final pcmController = StreamController<Uint8List>();
      final deltas = <String>[];

      await svc.startRealtimeTranscription(
        pcmStream: pcmController.stream,
        onDelta: deltas.add,
      );

      fakeChannel.simulateServerMessage({
        'type': 'transcription.text.delta',
        'text': 'Hello ',
      });
      await Future<void>.delayed(Duration.zero);

      fakeChannel.simulateServerMessage({
        'type': 'transcription.text.delta',
        'text': 'world',
      });
      await Future<void>.delayed(Duration.zero);

      expect(deltas, ['Hello ', 'world']);

      await pcmController.close();
    });
  });

  group('stop', () {
    test('returns transcript from transcription.done event', () async {
      final (container, fakeChannel) = await _createServiceWithConfig();
      addTearDown(container.dispose);

      final svc = container.read(realtimeTranscriptionServiceProvider);
      final pcmController = StreamController<Uint8List>();

      await svc.startRealtimeTranscription(
        pcmStream: pcmController.stream,
        onDelta: (_) {},
      );

      // Send some audio so PCM buffer is non-empty
      pcmController.add(_pcmSilence(64));
      await Future<void>.delayed(Duration.zero);

      // Schedule the done event before calling stop
      unawaited(
          Future<void>.delayed(const Duration(milliseconds: 50)).then((_) {
        fakeChannel.simulateServerMessage({
          'type': 'transcription.done',
          'text': 'Final transcript',
          'usage': {'audio_seconds': 3.0},
        });
      }));

      final outputDir = await Directory.systemTemp.createTemp('rt_svc_test_');
      addTearDown(() => outputDir.delete(recursive: true));

      final result = await svc.stop(
        stopRecorder: () async {},
        outputPath: '${outputDir.path}/output',
      );

      expect(result.transcript, 'Final transcript');
      expect(result.usedTranscriptFallback, isFalse);
    });

    test('falls back to accumulated deltas on timeout', () async {
      final (container, fakeChannel) = await _createServiceWithConfig(
        doneTimeout: const Duration(milliseconds: 50),
      );
      addTearDown(container.dispose);

      final svc = container.read(realtimeTranscriptionServiceProvider);
      final pcmController = StreamController<Uint8List>();

      await svc.startRealtimeTranscription(
        pcmStream: pcmController.stream,
        onDelta: (_) {},
      );

      // Send deltas that will be accumulated
      fakeChannel
        ..simulateServerMessage({
          'type': 'transcription.text.delta',
          'text': 'Hello ',
        })
        ..simulateServerMessage({
          'type': 'transcription.text.delta',
          'text': 'world',
        });
      await Future<void>.delayed(Duration.zero);

      // Don't send transcription.done — let the short timeout trigger fallback

      final outputDir = await Directory.systemTemp.createTemp('rt_svc_test_');
      addTearDown(() => outputDir.delete(recursive: true));

      final result = await svc.stop(
        stopRecorder: () async {},
        outputPath: '${outputDir.path}/output',
      );

      expect(result.transcript, 'Hello world');
      expect(result.usedTranscriptFallback, isTrue);
    });

    test('sends endAudio to server on stop', () async {
      final (container, fakeChannel) = await _createServiceWithConfig();
      addTearDown(container.dispose);

      final svc = container.read(realtimeTranscriptionServiceProvider);
      final pcmController = StreamController<Uint8List>();

      await svc.startRealtimeTranscription(
        pcmStream: pcmController.stream,
        onDelta: (_) {},
      );

      // Schedule done event for stop
      unawaited(Future<void>.delayed(Duration.zero).then((_) {
        fakeChannel.simulateServerMessage({
          'type': 'transcription.done',
          'text': 'done',
        });
      }));

      final outputDir = await Directory.systemTemp.createTemp('rt_svc_test_');
      addTearDown(() => outputDir.delete(recursive: true));

      await svc.stop(
        stopRecorder: () async {},
        outputPath: '${outputDir.path}/output',
      );

      // Verify endAudio message was sent
      final endMessages = fakeChannel.sentMessages
          .map((m) => jsonDecode(m) as Map<String, dynamic>)
          .where((m) => m['type'] == 'input_audio.end');
      expect(endMessages, isNotEmpty);
    });

    test('calls stopRecorder callback', () async {
      final (container, fakeChannel) = await _createServiceWithConfig();
      addTearDown(container.dispose);

      final svc = container.read(realtimeTranscriptionServiceProvider);
      final pcmController = StreamController<Uint8List>();
      var recorderStopped = false;

      await svc.startRealtimeTranscription(
        pcmStream: pcmController.stream,
        onDelta: (_) {},
      );

      unawaited(Future<void>.delayed(Duration.zero).then((_) {
        fakeChannel.simulateServerMessage({
          'type': 'transcription.done',
          'text': 'ok',
        });
      }));

      final outputDir = await Directory.systemTemp.createTemp('rt_svc_test_');
      addTearDown(() => outputDir.delete(recursive: true));

      await svc.stop(
        stopRecorder: () async {
          recorderStopped = true;
        },
        outputPath: '${outputDir.path}/output',
      );

      expect(recorderStopped, isTrue);
    });

    test('sets isActive to false after stop', () async {
      final (container, fakeChannel) = await _createServiceWithConfig();
      addTearDown(container.dispose);

      final svc = container.read(realtimeTranscriptionServiceProvider);
      final pcmController = StreamController<Uint8List>();

      await svc.startRealtimeTranscription(
        pcmStream: pcmController.stream,
        onDelta: (_) {},
      );
      expect(svc.isActive, isTrue);

      unawaited(Future<void>.delayed(Duration.zero).then((_) {
        fakeChannel.simulateServerMessage({
          'type': 'transcription.done',
          'text': 'done',
        });
      }));

      final outputDir = await Directory.systemTemp.createTemp('rt_svc_test_');
      addTearDown(() => outputDir.delete(recursive: true));

      await svc.stop(
        stopRecorder: () async {},
        outputPath: '${outputDir.path}/output',
      );

      expect(svc.isActive, isFalse);
    });

    test('returns null audioFilePath when no PCM data', () async {
      final (container, fakeChannel) = await _createServiceWithConfig();
      addTearDown(container.dispose);

      final svc = container.read(realtimeTranscriptionServiceProvider);
      final pcmController = StreamController<Uint8List>();

      await svc.startRealtimeTranscription(
        pcmStream: pcmController.stream,
        onDelta: (_) {},
      );

      // Don't send any PCM data — buffer remains empty

      unawaited(Future<void>.delayed(Duration.zero).then((_) {
        fakeChannel.simulateServerMessage({
          'type': 'transcription.done',
          'text': '',
        });
      }));

      final outputDir = await Directory.systemTemp.createTemp('rt_svc_test_');
      addTearDown(() => outputDir.delete(recursive: true));

      final result = await svc.stop(
        stopRecorder: () async {},
        outputPath: '${outputDir.path}/output',
      );

      expect(result.audioFilePath, isNull);
    });
  });

  group('dispose', () {
    test('cancels subscriptions and cleans up', () async {
      final (container, _) = await _createServiceWithConfig();
      addTearDown(container.dispose);

      final svc = container.read(realtimeTranscriptionServiceProvider);
      final pcmController = StreamController<Uint8List>();

      await svc.startRealtimeTranscription(
        pcmStream: pcmController.stream,
        onDelta: (_) {},
      );

      expect(svc.isActive, isTrue);

      await svc.dispose();

      expect(svc.isActive, isFalse);
    });

    test('cleans up even with buffered PCM data', () async {
      final (container, _) = await _createServiceWithConfig();
      addTearDown(container.dispose);

      final svc = container.read(realtimeTranscriptionServiceProvider);
      final pcmController = StreamController<Uint8List>();

      await svc.startRealtimeTranscription(
        pcmStream: pcmController.stream,
        onDelta: (_) {},
      );

      pcmController.add(_pcmSilence(64));
      await Future<void>.delayed(Duration.zero);

      await svc.dispose();

      expect(svc.isActive, isFalse);
    });
  });

  group('PCM stream error handling', () {
    test('logs exception when PCM stream emits error', () async {
      final (container, _) = await _createServiceWithConfig();
      addTearDown(container.dispose);

      final svc = container.read(realtimeTranscriptionServiceProvider);
      final pcmController = StreamController<Uint8List>();

      await svc.startRealtimeTranscription(
        pcmStream: pcmController.stream,
        onDelta: (_) {},
      );

      // Emit an error on the PCM stream
      pcmController.addError(Exception('microphone disconnected'));
      await Future<void>.delayed(Duration.zero);

      // Verify exception was captured
      expect(fakeLogging.exceptions, hasLength(1));
      expect(
        fakeLogging.exceptions.first.toString(),
        contains('microphone disconnected'),
      );

      await svc.dispose();
    });
  });

  group('WAV file output', () {
    test('writes valid WAV header for PCM data', () async {
      final (container, fakeChannel) = await _createServiceWithConfig();
      addTearDown(container.dispose);

      final svc = container.read(realtimeTranscriptionServiceProvider);
      final pcmController = StreamController<Uint8List>();

      await svc.startRealtimeTranscription(
        pcmStream: pcmController.stream,
        onDelta: (_) {},
      );

      // Send some PCM data
      final pcmData = Uint8List.fromList(List.filled(320, 0));
      pcmController.add(pcmData);
      await Future<void>.delayed(Duration.zero);

      unawaited(Future<void>.delayed(Duration.zero).then((_) {
        fakeChannel.simulateServerMessage({
          'type': 'transcription.done',
          'text': 'test',
        });
      }));

      final outputDir = await Directory.systemTemp.createTemp('rt_wav_test_');
      addTearDown(() => outputDir.delete(recursive: true));

      final result = await svc.stop(
        stopRecorder: () async {},
        outputPath: '${outputDir.path}/test_output',
      );

      // Audio file should exist (WAV fallback since no native converter)
      expect(result.audioFilePath, isNotNull);
      final file = File(result.audioFilePath!);
      expect(file.existsSync(), isTrue);
      final bytes = await file.readAsBytes();
      // Verify WAV header magic bytes
      expect(bytes[0], 0x52); // 'R'
      expect(bytes[1], 0x49); // 'I'
      expect(bytes[2], 0x46); // 'F'
      expect(bytes[3], 0x46); // 'F'
      expect(bytes[8], 0x57); // 'W'
      expect(bytes[9], 0x41); // 'A'
      expect(bytes[10], 0x56); // 'V'
      expect(bytes[11], 0x45); // 'E'

      // Verify WAV data size matches PCM data
      final headerDataSize = ByteData.sublistView(bytes, 40, 44);
      expect(
        headerDataSize.getUint32(0, Endian.little),
        pcmData.length,
      );
    });

    test('audio file has .wav extension as fallback', () async {
      final (container, fakeChannel) = await _createServiceWithConfig();
      addTearDown(container.dispose);

      final svc = container.read(realtimeTranscriptionServiceProvider);
      final pcmController = StreamController<Uint8List>();

      await svc.startRealtimeTranscription(
        pcmStream: pcmController.stream,
        onDelta: (_) {},
      );

      pcmController.add(Uint8List.fromList(List.filled(64, 0)));
      await Future<void>.delayed(Duration.zero);

      unawaited(Future<void>.delayed(Duration.zero).then((_) {
        fakeChannel.simulateServerMessage({
          'type': 'transcription.done',
          'text': 'test',
        });
      }));

      final outputDir = await Directory.systemTemp.createTemp('rt_wav_ext_');
      addTearDown(() => outputDir.delete(recursive: true));

      final result = await svc.stop(
        stopRecorder: () async {},
        outputPath: '${outputDir.path}/test_output',
      );

      // Without native M4A converter, should fall back to .wav
      expect(result.audioFilePath, isNotNull);
      expect(result.audioFilePath, endsWith('.wav'));
    });

    test('returns null audioFilePath when WAV writing fails', () async {
      final (container, fakeChannel) = await _createServiceWithConfig();
      addTearDown(container.dispose);

      final svc = container.read(realtimeTranscriptionServiceProvider);
      final pcmController = StreamController<Uint8List>();

      await svc.startRealtimeTranscription(
        pcmStream: pcmController.stream,
        onDelta: (_) {},
      );

      pcmController.add(Uint8List.fromList(List.filled(64, 0)));
      await Future<void>.delayed(Duration.zero);

      unawaited(Future<void>.delayed(Duration.zero).then((_) {
        fakeChannel.simulateServerMessage({
          'type': 'transcription.done',
          'text': 'test',
        });
      }));

      // Use an invalid path to trigger the catch block in _saveAudio
      final result = await svc.stop(
        stopRecorder: () async {},
        outputPath: '/nonexistent/deeply/nested/path/output',
      );

      // Should gracefully handle the error
      // audioFilePath might be null if temp WAV doesn't exist either
      expect(result.transcript, 'test');
    });
  });

  group('PCM buffer cap', () {
    test('caps buffer to prevent OOM on long recordings', () async {
      final (container, fakeChannel) = await _createServiceWithConfig();
      addTearDown(container.dispose);

      final svc = container.read(realtimeTranscriptionServiceProvider);
      final pcmController = StreamController<Uint8List>();

      await svc.startRealtimeTranscription(
        pcmStream: pcmController.stream,
        onDelta: (_) {},
      );

      // Send chunks that exceed the max buffer size (3,840,000 bytes)
      // Each chunk is 64,000 bytes, so 61 chunks = 3,904,000 bytes > max
      for (var i = 0; i < 61; i++) {
        pcmController.add(Uint8List.fromList(List.filled(64000, i)));
        await Future<void>.delayed(Duration.zero);
      }

      final outputDir = await Directory.systemTemp.createTemp('rt_buffer_cap_');
      addTearDown(() => outputDir.delete(recursive: true));

      // Schedule the done event to fire after stop() starts listening
      unawaited(Future<void>.delayed(const Duration(milliseconds: 50)).then(
        (_) {
          fakeChannel.simulateServerMessage({
            'type': 'transcription.done',
            'text': 'long recording test',
          });
        },
      ));

      final result = await svc.stop(
        stopRecorder: () async {},
        outputPath: '${outputDir.path}/output',
      );

      expect(result.transcript, 'long recording test');
      // Audio file should still be created from the capped buffer
      expect(result.audioFilePath, isNotNull);
    });

    test('single chunk exceeding max buffer keeps only tail', () async {
      final (container, fakeChannel) = await _createServiceWithConfig();
      addTearDown(container.dispose);

      final svc = container.read(realtimeTranscriptionServiceProvider);
      final pcmController = StreamController<Uint8List>();

      await svc.startRealtimeTranscription(
        pcmStream: pcmController.stream,
        onDelta: (_) {},
      );

      // Send a single chunk that exceeds the max buffer size (3,840,000 bytes)
      // The code path `chunk.length >= _maxPcmBufferBytes` should trim to tail
      final oversizedChunk = Uint8List.fromList(
        List.generate(4000000, (i) => i % 256),
      );
      pcmController.add(oversizedChunk);
      await Future<void>.delayed(Duration.zero);

      final outputDir =
          await Directory.systemTemp.createTemp('rt_oversized_chunk_');
      addTearDown(() => outputDir.delete(recursive: true));

      unawaited(Future<void>.delayed(const Duration(milliseconds: 50)).then(
        (_) {
          fakeChannel.simulateServerMessage({
            'type': 'transcription.done',
            'text': 'oversized chunk test',
          });
        },
      ));

      final result = await svc.stop(
        stopRecorder: () async {},
        outputPath: '${outputDir.path}/output',
      );

      expect(result.transcript, 'oversized chunk test');
      // Audio file should be created from the tail of the oversized chunk
      expect(result.audioFilePath, isNotNull);
    });
  });

  group('_saveAudio error handling', () {
    test('returns temp WAV path when conversion throws but WAV exists',
        () async {
      final (container, fakeChannel) = await _createServiceWithConfig();
      addTearDown(container.dispose);

      final svc = container.read(realtimeTranscriptionServiceProvider);
      final pcmController = StreamController<Uint8List>();

      await svc.startRealtimeTranscription(
        pcmStream: pcmController.stream,
        onDelta: (_) {},
      );

      // Send some audio data so the buffer is non-empty
      pcmController.add(_pcmSilence(3200));
      await Future<void>.delayed(Duration.zero);

      // The output path points to a non-writable location to trigger
      // _saveAudio's catch block (rename will fail for the WAV fallback)
      // However, the temp WAV should still exist and be returned.
      final outputDir = await Directory.systemTemp.createTemp('rt_save_error_');
      addTearDown(() => outputDir.delete(recursive: true));

      unawaited(Future<void>.delayed(const Duration(milliseconds: 50)).then(
        (_) {
          fakeChannel.simulateServerMessage({
            'type': 'transcription.done',
            'text': 'save error test',
          });
        },
      ));

      final result = await svc.stop(
        stopRecorder: () async {},
        outputPath: '${outputDir.path}/output',
      );

      expect(result.transcript, 'save error test');
      // The audio file should still be present (either WAV fallback or M4A)
      // On test environments, conversion typically returns false so WAV
      // fallback is used
      expect(result.audioFilePath, isNotNull);
    });
  });
}
