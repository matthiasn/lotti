// Shared test infrastructure for realtime_transcription_service_test.dart:
// fake WebSocket plumbing, a controllable Mistral repository, a scripted
// MLX channel, and the RealtimeTranscriptionTestBench that wires them up.
//
// Helper file - no test cases of its own. `main()` below satisfies
// `flutter test` when the path is passed directly.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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
import 'package:lotti/services/domain_logging.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {}

/// Deliberately file-local instead of the central `MockDomainLogger`: this
/// file asserts on *accumulated* log/error content across whole flows
/// (e.g. "any exception message contains X"), which list collection
/// expresses more directly than per-call mocktail `verify` matching.
class FakeRealtimeDomainLogger extends Fake implements DomainLogger {
  final events = <String>[];
  final exceptions = <Object>[];

  @override
  void log(
    LogDomain domain,
    String message, {
    String? subDomain,
    InsightLevel level = InsightLevel.info,
  }) {
    events.add('${domain.name}/$subDomain: $message');
  }

  @override
  void error(
    LogDomain domain,
    Object error, {
    StackTrace? stackTrace,
    String? subDomain,
    String? message,
  }) {
    exceptions.add(error);
  }
}

class FakeWebSocketChannel extends StreamChannelMixin<dynamic>
    implements WebSocketChannel {
  FakeWebSocketChannel() : _readyCompleter = Completer<void>() {
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
  WebSocketSink get sink => FakeWebSocketSink(this);

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

class FakeWebSocketSink implements WebSocketSink {
  FakeWebSocketSink(this._channel);
  final FakeWebSocketChannel _channel;

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

/// Controllable [MistralRealtimeTranscriptionRepository] subclass used to drive
/// the service's stream handlers directly — in particular the `onError`
/// callback wired onto [transcriptionDone] inside `stop()`, which the real
/// repository never triggers (it only ever calls `.add` on its done
/// controller).
class ControllableRealtimeRepository
    extends MistralRealtimeTranscriptionRepository {
  final deltaController = StreamController<String>.broadcast();
  final languageController = StreamController<String>.broadcast();
  final doneController =
      StreamController<RealtimeTranscriptionDone>.broadcast();
  final sentChunks = <Uint8List>[];
  bool connected = false;
  bool endAudioCalled = false;
  bool disconnected = false;

  @override
  Future<void> connect({
    required String apiKey,
    required String baseUrl,
    String? model,
  }) async {
    connected = true;
  }

  @override
  void sendAudioChunk(Uint8List pcmBytes) {
    sentChunks.add(Uint8List.fromList(pcmBytes));
  }

  @override
  Future<void> endAudio() async {
    endAudioCalled = true;
  }

  @override
  Future<void> disconnect() async {
    disconnected = true;
  }

  @override
  Stream<String> get transcriptionDeltas => deltaController.stream;

  @override
  Stream<String> get detectedLanguage => languageController.stream;

  @override
  Stream<RealtimeTranscriptionDone> get transcriptionDone =>
      doneController.stream;

  Future<void> close() async {
    await deltaController.close();
    await languageController.close();
    await doneController.close();
  }
}

// ---------------------------------------------------------------------------
// Test bench
// ---------------------------------------------------------------------------

const kTestProviderId = 'p-rt-svc';
const kTestModelId = 'm-rt-svc';
const kTestProviderModelId = 'voxtral-mini-transcribe-realtime-2602';
const kTestMlxProviderId = 'p-mlx-rt-svc';
const kTestMlxModelId = 'm-mlx-rt-svc';

/// Builds an inference-provider config for the realtime bench's `configs`
/// override, so filter/negative tests can seed bespoke rows without
/// hand-wiring an `AiConfigRepository` + container.
AiConfig realtimeProviderConfig({
  required String id,
  InferenceProviderType type = InferenceProviderType.mistral,
  String name = 'Mistral',
  String baseUrl = 'https://api.mistral.ai/v1',
  String apiKey = 'key',
}) => AiConfig.inferenceProvider(
  id: id,
  baseUrl: baseUrl,
  apiKey: apiKey,
  name: name,
  createdAt: DateTime(2024),
  inferenceProviderType: type,
);

/// Builds a model config for the realtime bench's `configs` override.
/// Defaults to an audio-input realtime model; pass `audio: false` for a
/// text-only model to exercise the audio-modality filter.
AiConfig realtimeModelConfig({
  required String id,
  required String providerId,
  String name = 'Realtime',
  String providerModelId = kTestProviderModelId,
  bool audio = true,
}) => AiConfig.model(
  id: id,
  name: name,
  providerModelId: providerModelId,
  inferenceProviderId: providerId,
  createdAt: DateTime(2024),
  inputModalities: audio ? const [Modality.audio] : const [Modality.text],
  outputModalities: const [Modality.text],
  isReasoningModel: false,
);

class FakeMlxAudioChannel extends MlxAudioChannel {
  final eventsController = StreamController<MlxAudioRealtimeEvent>.broadcast(
    sync: true,
  );
  final appendedPcm = <Uint8List>[];
  String? startedModelId;
  String? startedDelayPreset;
  String? doneTextOnStop;
  Exception? startError;
  Exception? appendError;
  Exception? stopError;
  bool stopped = false;
  bool cancelled = false;

  @override
  Stream<MlxAudioRealtimeEvent> get realtimeTranscriptionEvents =>
      eventsController.stream;

  @override
  Future<void> startRealtimeTranscription({
    required String modelId,
    String? language,
    String delayPreset = 'subtitle',
  }) async {
    final error = startError;
    if (error != null) {
      throw error;
    }
    startedModelId = modelId;
    startedDelayPreset = delayPreset;
  }

  @override
  Future<void> appendRealtimePcm(Uint8List pcm16) async {
    final error = appendError;
    if (error != null) {
      throw error;
    }
    appendedPcm.add(Uint8List.fromList(pcm16));
  }

  @override
  Future<void> stopRealtimeTranscription() async {
    stopped = true;
    final error = stopError;
    if (error != null) {
      throw error;
    }
    final text = doneTextOnStop;
    if (text != null) {
      scheduleMicrotask(() {
        emit(
          MlxAudioRealtimeEvent(
            type: MlxAudioRealtimeEventType.done,
            text: text,
          ),
        );
      });
    }
  }

  @override
  Future<void> cancelRealtimeTranscription() async {
    cancelled = true;
  }

  void emit(MlxAudioRealtimeEvent event) {
    eventsController.add(event);
  }

  Future<void> close() => eventsController.close();
}

/// Encapsulates all the shared state and helpers for realtime transcription
/// service tests.
class RealtimeTranscriptionTestBench {
  RealtimeTranscriptionTestBench._({
    required this.container,
    required this.channel,
    required this.service,
    required this.mlxAudioChannel,
  });

  final ProviderContainer container;
  final FakeWebSocketChannel channel;
  final RealtimeTranscriptionService service;
  final FakeMlxAudioChannel mlxAudioChannel;

  /// PCM controller for feeding audio data — created lazily per
  /// [startTranscription] call so each test gets a fresh one.
  StreamController<Uint8List>? _pcmController;

  /// Creates a fully wired test bench with config in the DB.
  ///
  /// When [configs] is provided, exactly those rows are seeded and the
  /// [addConfig]/[addMlxConfig] default fixtures are skipped — use this for
  /// filter/negative cases (e.g. a non-audio model, or a realtime model behind
  /// a non-Mistral provider) instead of hand-wiring a container.
  static Future<RealtimeTranscriptionTestBench> create({
    bool addConfig = true,
    bool addMlxConfig = false,
    List<AiConfig>? configs,
    Duration doneTimeout = const Duration(seconds: 10),
  }) async {
    final db = AiConfigDb(inMemoryDatabase: true);
    final aiRepo = AiConfigRepository(db);

    if (configs != null) {
      for (final config in configs) {
        await aiRepo.saveConfig(config, fromSync: true);
      }
    } else if (addConfig) {
      await aiRepo.saveConfig(
        AiConfig.inferenceProvider(
          id: kTestProviderId,
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
          id: kTestModelId,
          name: 'Voxtral Realtime',
          providerModelId: kTestProviderModelId,
          inferenceProviderId: kTestProviderId,
          createdAt: DateTime(2024),
          inputModalities: const [Modality.audio],
          outputModalities: const [Modality.text],
          isReasoningModel: false,
        ),
        fromSync: true,
      );
    }
    if (configs == null && addMlxConfig) {
      await aiRepo.saveConfig(
        AiConfig.inferenceProvider(
          id: kTestMlxProviderId,
          baseUrl: '',
          apiKey: '',
          name: 'MLX Audio',
          createdAt: DateTime(2024),
          inferenceProviderType: InferenceProviderType.mlxAudio,
        ),
        fromSync: true,
      );
      await aiRepo.saveConfig(
        AiConfig.model(
          id: kTestMlxModelId,
          name: 'Qwen3 ASR',
          providerModelId: mlxAudioQwenAsrModelId,
          inferenceProviderId: kTestMlxProviderId,
          createdAt: DateTime(2024),
          inputModalities: const [Modality.audio],
          outputModalities: const [Modality.text],
          isReasoningModel: false,
        ),
        fromSync: true,
      );
    }

    final fakeChannel = FakeWebSocketChannel();
    final fakeMlxAudioChannel = FakeMlxAudioChannel();

    final repo = MistralRealtimeTranscriptionRepository(
      channelFactory: (_, _) {
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
            mlxAudioChannel: fakeMlxAudioChannel,
            doneTimeout: doneTimeout,
          ),
        ),
      ],
    );

    final service = container.read(realtimeTranscriptionServiceProvider);

    return RealtimeTranscriptionTestBench._(
      container: container,
      channel: fakeChannel,
      service: service,
      mlxAudioChannel: fakeMlxAudioChannel,
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

  /// Sends PCM data synchronously — use inside `fakeAsync` blocks.
  /// Call `async.flushMicrotasks()` after to process.
  void sendPcmSync(Uint8List data) {
    _pcmController!.add(data);
  }

  /// Sends a `transcription.done` event immediately — use inside `fakeAsync`
  /// blocks after elapsing time past the scheduled delay, or via
  /// [stop]'s `afterListening` hook once the done listener is active.
  void simulateDone(String text, {Map<String, dynamic>? extra}) {
    channel.simulateServerMessage({
      'type': 'transcription.done',
      'text': text,
      ...?extra,
    });
  }

  /// Calls `service.stop` with a temp output directory.
  /// Returns the stop result and cleans up the temp dir.
  ///
  /// [afterListening] runs synchronously right after `service.stop` is
  /// invoked. The service subscribes to the `transcription.done` broadcast
  /// stream synchronously before its first await, so a done event fired
  /// here is guaranteed to be observed — no wall-clock delay needed
  /// (fake-time policy).
  Future<RealtimeStopResult> stop({
    Future<void> Function()? stopRecorder,
    String? outputPath,
    void Function()? afterListening,
  }) async {
    final dir =
        outputPath ?? (await Directory.systemTemp.createTemp('rt_test_')).path;
    addTearDown(() async {
      final d = Directory(dir);
      if (d.existsSync()) await d.delete(recursive: true);
    });

    final result = service.stop(
      stopRecorder: stopRecorder ?? () async {},
      outputPath: '$dir/output',
    );
    afterListening?.call();
    return result;
  }

  void dispose() {
    _pcmController?.close();
    unawaited(mlxAudioChannel.close());
    container.dispose();
  }
}

Uint8List pcmSilence(int bytes) => Uint8List(bytes);
