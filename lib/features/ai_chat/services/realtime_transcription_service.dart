import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/realtime_transcription_event.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/mistral_realtime_transcription_repository.dart';
import 'package:lotti/features/ai/util/known_models.dart';
import 'package:lotti/features/ai/util/mlx_audio_channel.dart';
import 'package:lotti/features/ai_chat/services/realtime_audio_buffer.dart';
import 'package:lotti/features/ai_chat/services/realtime_audio_writer.dart';
import 'package:lotti/features/ai_chat/services/realtime_transcript_merge.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';

enum _RealtimeBackendKind { mistral, mlxAudio }

/// UI gate for live transcription.
///
/// Keep the realtime pipeline available behind the service/controller APIs, but
/// hide it from product surfaces until local realtime transcription can use the
/// same dictionary/context biasing as the batch path.
const realtimeTranscriptionUiEnabled = false;

/// Orchestrates real-time transcription: connects WebSocket, streams PCM
/// audio, accumulates audio for WAV/M4A file output, and computes amplitude.
///
/// This service bypasses `CloudInferenceRepository` entirely — real-time
/// WebSocket streaming is a different paradigm from the HTTP batch flow.
class RealtimeTranscriptionService {
  RealtimeTranscriptionService(
    this._ref, {
    MistralRealtimeTranscriptionRepository? repository,
    MlxAudioChannel? mlxAudioChannel,
    RealtimeAudioBuffer? audioBuffer,
    RealtimeAudioWriter? audioWriter,
    this._doneTimeout = const Duration(seconds: 10),
  }) : _repository = repository ?? MistralRealtimeTranscriptionRepository(),
       _mlxAudioChannel = mlxAudioChannel ?? MlxAudioChannel(),
       _audioBuffer = audioBuffer ?? RealtimeAudioBuffer(),
       _audioWriter = audioWriter ?? RealtimeAudioWriter();

  final Ref _ref;
  final MistralRealtimeTranscriptionRepository _repository;
  final MlxAudioChannel _mlxAudioChannel;
  final Duration _doneTimeout;
  final RealtimeAudioBuffer _audioBuffer;
  final RealtimeAudioWriter _audioWriter;
  final _deltaBuffer = StringBuffer();

  StreamSubscription<Uint8List>? _pcmSubscription;
  StreamSubscription<String>? _deltaSubscription;
  StreamSubscription<String>? _languageSubscription;
  StreamSubscription<MlxAudioRealtimeEvent>? _mlxEventSubscription;
  Completer<RealtimeTranscriptionDone>? _mlxDoneCompleter;
  String? _detectedLanguage;
  String _lastMlxConfirmedText = '';
  _RealtimeBackendKind? _activeBackend;
  bool _isActive = false;

  /// Stream of amplitude values (dBFS) computed from PCM chunks.
  Stream<double> get amplitudeStream => _audioBuffer.amplitudeStream;

  /// Whether a real-time transcription session is active.
  bool get isActive => _isActive;

  /// Resolves a configured real-time model.
  ///
  /// Mistral realtime is preferred by default — interactive latency on the
  /// cloud endpoint is currently better than the local MLX Qwen3-ASR path, so
  /// every caller (Daily OS Next capture/refine, chat input, the speech
  /// recorder) gets cloud realtime when it is configured. MLX is the fallback
  /// for users who have only the local model wired up.
  Future<({AiConfigInferenceProvider provider, AiConfigModel model})?>
  resolveRealtimeConfig() async {
    final aiRepo = _ref.read(aiConfigRepositoryProvider);
    final modelsFuture = aiRepo.getConfigsByType(AiConfigType.model);
    final providersFuture = aiRepo.getConfigsByType(
      AiConfigType.inferenceProvider,
    );
    final models = await modelsFuture;
    final providers = await providersFuture;

    final allProviders = providers
        .whereType<AiConfigInferenceProvider>()
        .toList();

    final mistralConfig = _findRealtimeConfig(
      models: models,
      providers: allProviders,
      isModel: MistralRealtimeTranscriptionRepository.isRealtimeModel,
      providerType: InferenceProviderType.mistral,
    );
    if (mistralConfig != null) return mistralConfig;

    return _findRealtimeConfig(
      models: models,
      providers: allProviders,
      isModel: _isMlxRealtimeModel,
      providerType: InferenceProviderType.mlxAudio,
    );
  }

  static ({AiConfigInferenceProvider provider, AiConfigModel model})?
  _findRealtimeConfig({
    required List<AiConfig> models,
    required List<AiConfigInferenceProvider> providers,
    required bool Function(String providerModelId) isModel,
    required InferenceProviderType providerType,
  }) {
    for (final model in models.whereType<AiConfigModel>()) {
      if (!model.inputModalities.contains(Modality.audio)) continue;
      if (!isModel(model.providerModelId)) continue;
      final provider = providers
          .where(
            (p) =>
                p.id == model.inferenceProviderId &&
                p.inferenceProviderType == providerType,
          )
          .firstOrNull;
      if (provider != null) {
        return (provider: provider, model: model);
      }
    }
    return null;
  }

  /// Starts a real-time transcription session.
  ///
  /// Connects to the Mistral WebSocket and subscribes to the [pcmStream].
  /// [onDelta] is called for each text delta received from the server.
  /// Also subscribe to [amplitudeStream] for dBFS values.
  Future<void> startRealtimeTranscription({
    required Stream<Uint8List> pcmStream,
    required void Function(String delta) onDelta,
    ({AiConfigInferenceProvider provider, AiConfigModel model})? config,
  }) async {
    final resolvedConfig = config ?? await resolveRealtimeConfig();
    if (resolvedConfig == null) {
      throw StateError('No realtime transcription model configured');
    }

    _isActive = true;
    _audioBuffer.clear();
    _deltaBuffer.clear();
    _detectedLanguage = null;
    _lastMlxConfirmedText = '';

    if (resolvedConfig.provider.inferenceProviderType ==
        InferenceProviderType.mlxAudio) {
      await _startMlxRealtimeTranscription(
        config: resolvedConfig,
        pcmStream: pcmStream,
        onDelta: onDelta,
      );
      return;
    }

    await _repository.connect(
      apiKey: resolvedConfig.provider.apiKey,
      baseUrl: resolvedConfig.provider.baseUrl,
      model: resolvedConfig.model.providerModelId,
    );

    // Subscribe to PCM stream: send to WebSocket + accumulate + compute dBFS
    _pcmSubscription = pcmStream.listen(
      (chunk) {
        _repository.sendAudioChunk(chunk);
        _audioBuffer.addChunk(chunk);
      },
      onError: (Object error) {
        getIt<DomainLogger>().error(
          LogDomain.speech,
          error,
          subDomain: 'pcmStream.error',
        );
      },
    );

    // Single subscription: accumulate for final transcript + notify controller
    _deltaSubscription = _repository.transcriptionDeltas.listen(
      (delta) {
        _deltaBuffer.write(delta);
        onDelta(delta);
      },
    );

    // Track detected language for transcript metadata
    _languageSubscription = _repository.detectedLanguage.listen(
      (language) {
        _detectedLanguage = language;
      },
    );
    _activeBackend = _RealtimeBackendKind.mistral;
  }

  /// Stops the real-time transcription session.
  ///
  /// 1. Cancels PCM stream subscription (stops forwarding audio)
  /// 2. Calls [stopRecorder] — mic off immediately
  /// 3. Sends `input_audio.end` to the server
  /// 4. Awaits `transcription.done` (with 10s timeout)
  /// 5. Writes accumulated PCM to temp WAV, converts to M4A
  /// 6. Disconnects WebSocket
  /// 7. Returns [RealtimeStopResult]
  Future<RealtimeStopResult> stop({
    required Future<void> Function() stopRecorder,
    required String outputPath,
  }) async {
    if (_activeBackend == _RealtimeBackendKind.mlxAudio) {
      return _stopMlxRealtimeTranscription(
        stopRecorder: stopRecorder,
        outputPath: outputPath,
      );
    }

    // Subscribe to the broadcast stream BEFORE cleanup so we don't miss
    // a transcription.done event that arrives while we're cancelling
    // subscriptions and signalling end-of-audio. Use a Completer +
    // explicit subscription so the listener is properly cancelled on
    // timeout (Stream.first.timeout leaves an orphaned listener).
    final doneCompleter = Completer<RealtimeTranscriptionDone>();
    final doneSubscription = _repository.transcriptionDone.listen(
      (done) {
        if (!doneCompleter.isCompleted) {
          doneCompleter.complete(done);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!doneCompleter.isCompleted) {
          doneCompleter.completeError(error, stackTrace);
        }
      },
    );

    String transcript;
    var usedFallback = false;

    try {
      // 1. Stop forwarding audio
      await _pcmSubscription?.cancel();
      _pcmSubscription = null;

      // 2. Stop the recorder (mic off)
      await stopRecorder();

      // 3. Signal end of audio
      await _repository.endAudio();

      // 4. Wait for transcription.done — timeout starts here so the full
      //    budget applies to waiting for the server, not recorder shutdown.
      final done = await doneCompleter.future.timeout(_doneTimeout);
      transcript = moreCompleteTranscript(
        finalText: done.text,
        accumulatedText: _deltaBuffer.toString(),
      );
    } on TimeoutException {
      // Read delta buffer *after* the timeout so any late-arriving deltas
      // (from audio already in-flight when we cancelled the PCM subscription)
      // are captured in the fallback transcript.
      transcript = _deltaBuffer.toString();
      usedFallback = true;
      getIt<DomainLogger>().log(
        LogDomain.speech,
        'transcription.done timed out, using accumulated deltas '
        '(${transcript.length} chars)',
        subDomain: 'stop.timeout',
      );
    } finally {
      await doneSubscription.cancel();
    }

    final detectedLanguage = _detectedLanguage;

    // 5. Write temp WAV and convert to M4A
    final audioFilePath = await _audioWriter.saveAudio(
      pcm: _audioBuffer.toBytes(),
      outputPath: outputPath,
    );

    // 6. Disconnect
    await _cleanup();

    return RealtimeStopResult(
      transcript: transcript,
      audioFilePath: audioFilePath,
      usedTranscriptFallback: usedFallback,
      detectedLanguage: detectedLanguage,
    );
  }

  /// Tears down resources without saving (used by cancel).
  Future<void> dispose() async {
    await _pcmSubscription?.cancel();
    _pcmSubscription = null;
    await _deltaSubscription?.cancel();
    _deltaSubscription = null;
    await _languageSubscription?.cancel();
    _languageSubscription = null;
    await _mlxEventSubscription?.cancel();
    _mlxEventSubscription = null;

    await _cleanup();
  }

  Future<void> _startMlxRealtimeTranscription({
    required ({AiConfigInferenceProvider provider, AiConfigModel model}) config,
    required Stream<Uint8List> pcmStream,
    required void Function(String delta) onDelta,
  }) async {
    _activeBackend = _RealtimeBackendKind.mlxAudio;
    _mlxDoneCompleter = Completer<RealtimeTranscriptionDone>();

    _mlxEventSubscription = _mlxAudioChannel.realtimeTranscriptionEvents.listen(
      (event) {
        switch (event.type) {
          case MlxAudioRealtimeEventType.confirmed:
            _appendMlxConfirmedText(event.text ?? '', onDelta);
          case MlxAudioRealtimeEventType.done:
            final text = event.text ?? _deltaBuffer.toString();
            _appendMlxConfirmedText(text, onDelta);
            final completer = _mlxDoneCompleter;
            if (completer != null && !completer.isCompleted) {
              completer.complete(RealtimeTranscriptionDone(text: text));
            }
          case MlxAudioRealtimeEventType.error:
            final completer = _mlxDoneCompleter;
            final error = StateError(
              event.message ?? 'MLX realtime transcription failed',
            );
            if (completer != null && !completer.isCompleted) {
              completer.completeError(error);
            }
            getIt<DomainLogger>().error(
              LogDomain.speech,
              error,
              subDomain: 'mlxAudio.error',
            );
          case MlxAudioRealtimeEventType.provisional:
          case MlxAudioRealtimeEventType.display:
          case MlxAudioRealtimeEventType.stats:
            break;
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        final completer = _mlxDoneCompleter;
        if (completer != null && !completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
      },
    );

    try {
      await _mlxAudioChannel.startRealtimeTranscription(
        modelId: config.model.providerModelId,
      );
    } catch (_) {
      await _cleanup();
      rethrow;
    }

    _pcmSubscription = pcmStream.listen(
      (chunk) {
        unawaited(
          _mlxAudioChannel.appendRealtimePcm(chunk).catchError((
            Object error,
            StackTrace stackTrace,
          ) {
            getIt<DomainLogger>().error(
              LogDomain.speech,
              error,
              stackTrace: stackTrace,
              subDomain: 'mlxAudio.appendPcm',
            );
          }),
        );
        _audioBuffer.addChunk(chunk);
      },
      onError: (Object error) {
        getIt<DomainLogger>().error(
          LogDomain.speech,
          error,
          subDomain: 'pcmStream.error',
        );
      },
    );
  }

  Future<RealtimeStopResult> _stopMlxRealtimeTranscription({
    required Future<void> Function() stopRecorder,
    required String outputPath,
  }) async {
    final doneCompleter =
        _mlxDoneCompleter ?? Completer<RealtimeTranscriptionDone>();

    String transcript;
    var usedFallback = false;

    try {
      await _pcmSubscription?.cancel();
      _pcmSubscription = null;

      await stopRecorder();
      await _mlxAudioChannel.stopRealtimeTranscription();

      final done = await doneCompleter.future.timeout(_doneTimeout);
      transcript = moreCompleteTranscript(
        finalText: done.text,
        accumulatedText: _deltaBuffer.toString(),
      );
    } on TimeoutException {
      transcript = _deltaBuffer.toString();
      usedFallback = true;
      getIt<DomainLogger>().log(
        LogDomain.speech,
        'MLX transcription.done timed out, using accumulated confirmed text '
        '(${transcript.length} chars)',
        subDomain: 'mlxAudio.stop.timeout',
      );
    } catch (error, stackTrace) {
      transcript = _deltaBuffer.toString();
      usedFallback = true;
      getIt<DomainLogger>().error(
        LogDomain.speech,
        error,
        stackTrace: stackTrace,
        subDomain: 'mlxAudio.stop',
      );
    }

    final audioFilePath = await _audioWriter.saveAudio(
      pcm: _audioBuffer.toBytes(),
      outputPath: outputPath,
    );
    await _cleanup();

    return RealtimeStopResult(
      transcript: transcript,
      audioFilePath: audioFilePath,
      usedTranscriptFallback: usedFallback,
      detectedLanguage: _detectedLanguage,
    );
  }

  void _appendMlxConfirmedText(
    String text,
    void Function(String delta) onDelta,
  ) {
    if (text.isEmpty || text == _lastMlxConfirmedText) {
      return;
    }

    final delta = confirmedTextDelta(
      previous: _lastMlxConfirmedText,
      next: text,
    );
    _lastMlxConfirmedText = text;
    if (delta.isEmpty) return;
    _deltaBuffer.write(delta);
    onDelta(delta);
  }

  /// Cancels backend subscriptions, resets per-session state, and
  /// disconnects the active backend. The audio buffer is left intact —
  /// `stop` reads it just before calling this, and the next
  /// [startRealtimeTranscription] clears it.
  Future<void> _cleanup() async {
    _isActive = false;
    await _deltaSubscription?.cancel();
    _deltaSubscription = null;
    await _languageSubscription?.cancel();
    _languageSubscription = null;
    await _mlxEventSubscription?.cancel();
    _mlxEventSubscription = null;
    _mlxDoneCompleter = null;
    _lastMlxConfirmedText = '';
    _detectedLanguage = null;
    _deltaBuffer.clear();
    if (_activeBackend == _RealtimeBackendKind.mlxAudio) {
      await _mlxAudioChannel.cancelRealtimeTranscription();
    } else {
      await _repository.disconnect();
    }
    _activeBackend = null;
  }
}

bool _isMlxRealtimeModel(String providerModelId) =>
    isMlxAudioQwenAsrModelId(providerModelId);

final Provider<RealtimeTranscriptionService>
realtimeTranscriptionServiceProvider = Provider<RealtimeTranscriptionService>((
  ref,
) {
  return RealtimeTranscriptionService(ref);
});

/// Whether a real-time transcription model is configured and available.
///
/// Used by UI components (chat input area, audio recording modal) to decide
/// whether to show the realtime mode toggle.
// ignore: specify_nonobvious_property_types
final realtimeAvailableProvider = FutureProvider.autoDispose<bool>((ref) async {
  if (!realtimeTranscriptionUiEnabled) {
    return false;
  }

  final service = ref.watch(realtimeTranscriptionServiceProvider);
  final config = await service.resolveRealtimeConfig();
  return config != null;
});
