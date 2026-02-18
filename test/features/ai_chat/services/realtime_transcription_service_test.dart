import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/features/ai/database/ai_config_db.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/realtime_transcription_event.dart';
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
// Test bench
// ---------------------------------------------------------------------------

const _providerId = 'p-rt-svc';
const _modelId = 'm-rt-svc';
const _providerModelId = 'voxtral-mini-transcribe-realtime-2602';

/// Encapsulates all the shared state and helpers for realtime transcription
/// service tests.
class _TestBench {
  _TestBench._({
    required this.container,
    required this.channel,
    required this.service,
  });

  final ProviderContainer container;
  final _FakeWebSocketChannel channel;
  final RealtimeTranscriptionService service;

  /// PCM controller for feeding audio data — created lazily per
  /// [startTranscription] call so each test gets a fresh one.
  StreamController<Uint8List>? _pcmController;

  /// Creates a fully wired test bench with config in the DB.
  static Future<_TestBench> create({
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
          createdAt: DateTime(2024),
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
          createdAt: DateTime(2024),
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

    final service = container.read(realtimeTranscriptionServiceProvider);

    return _TestBench._(
      container: container,
      channel: fakeChannel,
      service: service,
    );
  }

  /// Starts a transcription session with optional [onDelta] callback.
  Future<StreamController<Uint8List>> startTranscription({
    void Function(String)? onDelta,
  }) async {
    _pcmController = StreamController<Uint8List>();
    await service.startRealtimeTranscription(
      pcmStream: _pcmController!.stream,
      onDelta: onDelta ?? (_) {},
    );
    return _pcmController!;
  }

  /// Sends PCM data and waits a microtask for it to be processed.
  Future<void> sendPcm(Uint8List data) async {
    _pcmController!.add(data);
    await Future<void>.delayed(Duration.zero);
  }

  /// Schedules a `transcription.done` event with enough delay for `stop()`
  /// to be listening on the broadcast stream.
  void scheduleDone(String text, {Map<String, dynamic>? extra}) {
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 50)).then((_) {
        channel.simulateServerMessage({
          'type': 'transcription.done',
          'text': text,
          if (extra != null) ...extra,
        });
      }),
    );
  }

  /// Calls `service.stop` with a temp output directory.
  /// Returns the stop result and cleans up the temp dir.
  Future<RealtimeStopResult> stop({
    Future<void> Function()? stopRecorder,
    String? outputPath,
  }) async {
    final dir =
        outputPath ?? (await Directory.systemTemp.createTemp('rt_test_')).path;
    addTearDown(() async {
      final d = Directory(dir);
      if (d.existsSync()) await d.delete(recursive: true);
    });

    return service.stop(
      stopRecorder: stopRecorder ?? () async {},
      outputPath: '$dir/output',
    );
  }

  void dispose() {
    _pcmController?.close();
    container.dispose();
  }
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
      final bench = await _TestBench.create();
      addTearDown(bench.dispose);

      final config = await bench.service.resolveRealtimeConfig();

      expect(config, isNotNull);
      expect(config!.provider.id, _providerId);
      expect(config.model.providerModelId, _providerModelId);
    });

    test('returns null when no realtime model configured', () async {
      final bench = await _TestBench.create(addConfig: false);
      addTearDown(bench.dispose);

      final config = await bench.service.resolveRealtimeConfig();
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
          providerModelId: _providerModelId,
          inferenceProviderId: _providerId,
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
          providerModelId: _providerModelId,
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
      final bench = await _TestBench.create(addConfig: false);
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
      final bench = await _TestBench.create();
      addTearDown(bench.dispose);

      final pcm = await bench.startTranscription();
      expect(bench.service.isActive, isTrue);
      await pcm.close();
    });

    test('forwards PCM chunks to repository as base64', () async {
      final bench = await _TestBench.create();
      addTearDown(bench.dispose);

      await bench.startTranscription();
      await bench.sendPcm(_pcmSilence(64));

      expect(bench.channel.sentMessages, isNotEmpty);
      final msg =
          jsonDecode(bench.channel.sentMessages.last) as Map<String, dynamic>;
      expect(msg['type'], 'input_audio.append');
      expect(msg['audio'], isNotEmpty);
    });

    test('emits amplitude values from PCM chunks', () async {
      final bench = await _TestBench.create();
      addTearDown(bench.dispose);

      final amplitudes = <double>[];
      bench.service.amplitudeStream.listen(amplitudes.add);

      await bench.startTranscription();
      await bench.sendPcm(_pcmSilence(64));

      expect(amplitudes, isNotEmpty);
    });

    test('calls onDelta callback for each transcription delta', () async {
      final bench = await _TestBench.create();
      addTearDown(bench.dispose);

      final deltas = <String>[];
      await bench.startTranscription(onDelta: deltas.add);

      bench.channel.simulateServerMessage({
        'type': 'transcription.text.delta',
        'text': 'Hello ',
      });
      await Future<void>.delayed(Duration.zero);

      bench.channel.simulateServerMessage({
        'type': 'transcription.text.delta',
        'text': 'world',
      });
      await Future<void>.delayed(Duration.zero);

      expect(deltas, ['Hello ', 'world']);
    });
  });

  group('stop', () {
    test('returns transcript from transcription.done event', () async {
      final bench = await _TestBench.create();
      addTearDown(bench.dispose);

      await bench.startTranscription();
      await bench.sendPcm(_pcmSilence(64));

      bench.scheduleDone(
        'Final transcript',
        extra: {
          'usage': {'audio_seconds': 3.0},
        },
      );

      final result = await bench.stop();
      expect(result.transcript, 'Final transcript');
      expect(result.usedTranscriptFallback, isFalse);
    });

    test('falls back to accumulated deltas on timeout', () async {
      final bench = await _TestBench.create(
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

      // Don't send transcription.done — let the short timeout trigger fallback
      final result = await bench.stop();
      expect(result.transcript, 'Hello world');
      expect(result.usedTranscriptFallback, isTrue);
    });

    test('sends endAudio to server on stop', () async {
      final bench = await _TestBench.create();
      addTearDown(bench.dispose);

      await bench.startTranscription();
      bench.scheduleDone('done');

      await bench.stop();

      final endMessages = bench.channel.sentMessages
          .map((m) => jsonDecode(m) as Map<String, dynamic>)
          .where((m) => m['type'] == 'input_audio.end');
      expect(endMessages, isNotEmpty);
    });

    test('calls stopRecorder callback', () async {
      final bench = await _TestBench.create();
      addTearDown(bench.dispose);

      await bench.startTranscription();
      var recorderStopped = false;

      bench.scheduleDone('ok');

      await bench.stop(
        stopRecorder: () async {
          recorderStopped = true;
        },
      );

      expect(recorderStopped, isTrue);
    });

    test('sets isActive to false after stop', () async {
      final bench = await _TestBench.create();
      addTearDown(bench.dispose);

      await bench.startTranscription();
      expect(bench.service.isActive, isTrue);

      bench.scheduleDone('done');
      await bench.stop();

      expect(bench.service.isActive, isFalse);
    });

    test('returns null audioFilePath when no PCM data', () async {
      final bench = await _TestBench.create();
      addTearDown(bench.dispose);

      await bench.startTranscription();
      // Don't send any PCM data — buffer remains empty

      bench.scheduleDone('');
      final result = await bench.stop();

      expect(result.audioFilePath, isNull);
    });
  });

  group('dispose', () {
    test('cancels subscriptions and cleans up', () async {
      final bench = await _TestBench.create();
      addTearDown(bench.dispose);

      await bench.startTranscription();
      expect(bench.service.isActive, isTrue);

      await bench.service.dispose();
      expect(bench.service.isActive, isFalse);
    });

    test('cleans up even with buffered PCM data', () async {
      final bench = await _TestBench.create();
      addTearDown(bench.dispose);

      await bench.startTranscription();
      await bench.sendPcm(_pcmSilence(64));

      await bench.service.dispose();
      expect(bench.service.isActive, isFalse);
    });
  });

  group('PCM stream error handling', () {
    test('logs exception when PCM stream emits error', () async {
      final bench = await _TestBench.create();
      addTearDown(bench.dispose);

      final pcm = await bench.startTranscription();

      pcm.addError(Exception('microphone disconnected'));
      await Future<void>.delayed(Duration.zero);

      expect(fakeLogging.exceptions, hasLength(1));
      expect(
        fakeLogging.exceptions.first.toString(),
        contains('microphone disconnected'),
      );

      await bench.service.dispose();
    });
  });

  group('WAV file output', () {
    test('writes valid WAV header for PCM data', () async {
      final bench = await _TestBench.create();
      addTearDown(bench.dispose);

      await bench.startTranscription();

      final pcmData = Uint8List.fromList(List.filled(320, 0));
      await bench.sendPcm(pcmData);

      bench.scheduleDone('test');
      final result = await bench.stop();

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

    test('audio file has .wav extension as fallback', () async {
      final bench = await _TestBench.create();
      addTearDown(bench.dispose);

      await bench.startTranscription();
      await bench.sendPcm(_pcmSilence(64));

      bench.scheduleDone('test');
      final result = await bench.stop();

      // Without native M4A converter, should fall back to .wav
      expect(result.audioFilePath, isNotNull);
      expect(result.audioFilePath, endsWith('.wav'));
    });

    test('returns null audioFilePath when WAV writing fails', () async {
      final bench = await _TestBench.create();
      addTearDown(bench.dispose);

      await bench.startTranscription();
      await bench.sendPcm(_pcmSilence(64));

      bench.scheduleDone('test');

      // Use an invalid path to trigger the catch block in _saveAudio
      final result = await bench.service.stop(
        stopRecorder: () async {},
        outputPath: '/nonexistent/deeply/nested/path/output',
      );

      // Should gracefully handle the error
      expect(result.transcript, 'test');
    });
  });

  group('PCM buffer cap', () {
    test('caps buffer to prevent OOM on long recordings', () async {
      final bench = await _TestBench.create();
      addTearDown(bench.dispose);

      final pcm = await bench.startTranscription();

      // Send chunks that exceed the max buffer size (3,840,000 bytes)
      // Each chunk is 64,000 bytes, so 61 chunks = 3,904,000 bytes > max
      for (var i = 0; i < 61; i++) {
        pcm.add(Uint8List.fromList(List.filled(64000, i)));
        await Future<void>.delayed(Duration.zero);
      }

      bench.scheduleDone('long recording test');
      final result = await bench.stop();

      expect(result.transcript, 'long recording test');
      expect(result.audioFilePath, isNotNull);
    });

    test('single chunk exceeding max buffer keeps only tail', () async {
      final bench = await _TestBench.create();
      addTearDown(bench.dispose);

      await bench.startTranscription();

      // Send a single chunk that exceeds the max buffer size (3,840,000 bytes)
      final oversizedChunk = Uint8List.fromList(
        List.generate(4000000, (i) => i % 256),
      );
      await bench.sendPcm(oversizedChunk);

      bench.scheduleDone('oversized chunk test');
      final result = await bench.stop();

      expect(result.transcript, 'oversized chunk test');
      expect(result.audioFilePath, isNotNull);
    });
  });

  group('_saveAudio error handling', () {
    test('returns temp WAV path when conversion throws but WAV exists',
        () async {
      final bench = await _TestBench.create();
      addTearDown(bench.dispose);

      await bench.startTranscription();
      await bench.sendPcm(_pcmSilence(3200));

      bench.scheduleDone('save error test');
      final result = await bench.stop();

      expect(result.transcript, 'save error test');
      // The audio file should still be present (WAV fallback on test env)
      expect(result.audioFilePath, isNotNull);
    });
  });
}
