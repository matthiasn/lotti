import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/realtime_transcription_event.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/mistral_realtime_transcription_repository.dart';
import 'package:lotti/features/ai/util/audio_converter_channel.dart';
import 'package:lotti/features/ai/util/known_models.dart';
import 'package:lotti/features/ai/util/mlx_audio_channel.dart';
import 'package:lotti/features/ai/util/pcm_amplitude.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';

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
    this._doneTimeout = const Duration(seconds: 10),
  }) : _repository = repository ?? MistralRealtimeTranscriptionRepository(),
       _mlxAudioChannel = mlxAudioChannel ?? MlxAudioChannel();

  final Ref _ref;
  final MistralRealtimeTranscriptionRepository _repository;
  final MlxAudioChannel _mlxAudioChannel;
  final Duration _doneTimeout;
  final _pcmBuffer = BytesBuilder(copy: false);
  final _amplitudeController = StreamController<double>.broadcast();
  final _deltaBuffer = StringBuffer();

  /// Maximum PCM buffer size: ~2 minutes at 16kHz × 16-bit × mono = ~3.84 MB.
  /// Beyond this, older audio is discarded (transcription still works via
  /// WebSocket streaming — the buffer is only for the saved audio file).
  static const _maxPcmBufferBytes = 3840000;

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
  Stream<double> get amplitudeStream => _amplitudeController.stream;

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
    _pcmBuffer.clear();
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
        _bufferPcmAndAmplitude(chunk);
      },
      onError: (Object error) {
        getIt<LoggingService>().captureException(
          error,
          domain: 'RealtimeTranscriptionService',
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
      transcript = _moreCompleteTranscript(done.text, _deltaBuffer.toString());
    } on TimeoutException {
      // Read delta buffer *after* the timeout so any late-arriving deltas
      // (from audio already in-flight when we cancelled the PCM subscription)
      // are captured in the fallback transcript.
      transcript = _deltaBuffer.toString();
      usedFallback = true;
      getIt<LoggingService>().captureEvent(
        'transcription.done timed out, using accumulated deltas '
        '(${transcript.length} chars)',
        domain: 'RealtimeTranscriptionService',
        subDomain: 'stop.timeout',
      );
    } finally {
      await doneSubscription.cancel();
    }

    final detectedLanguage = _detectedLanguage;

    // 5. Write temp WAV and convert to M4A
    final audioFilePath = await _saveAudio(outputPath);

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
            getIt<LoggingService>().captureException(
              error,
              domain: 'RealtimeTranscriptionService',
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
            getIt<LoggingService>().captureException(
              error,
              domain: 'RealtimeTranscriptionService',
              subDomain: 'mlxAudio.appendPcm',
              stackTrace: stackTrace,
            );
          }),
        );
        _bufferPcmAndAmplitude(chunk);
      },
      onError: (Object error) {
        getIt<LoggingService>().captureException(
          error,
          domain: 'RealtimeTranscriptionService',
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
      transcript = _moreCompleteTranscript(done.text, _deltaBuffer.toString());
    } on TimeoutException {
      transcript = _deltaBuffer.toString();
      usedFallback = true;
      getIt<LoggingService>().captureEvent(
        'MLX transcription.done timed out, using accumulated confirmed text '
        '(${transcript.length} chars)',
        domain: 'RealtimeTranscriptionService',
        subDomain: 'mlxAudio.stop.timeout',
      );
    } catch (error, stackTrace) {
      transcript = _deltaBuffer.toString();
      usedFallback = true;
      getIt<LoggingService>().captureException(
        error,
        domain: 'RealtimeTranscriptionService',
        subDomain: 'mlxAudio.stop',
        stackTrace: stackTrace,
      );
    }

    final audioFilePath = await _saveAudio(outputPath);
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

    final delta = _confirmedTextDelta(
      previous: _lastMlxConfirmedText,
      next: text,
    );
    _lastMlxConfirmedText = text;
    if (delta.isEmpty) return;
    _deltaBuffer.write(delta);
    onDelta(delta);
  }

  String _moreCompleteTranscript(String finalText, String accumulatedText) {
    final trimmedFinal = finalText.trim();
    final trimmedAccumulated = accumulatedText.trim();
    if (trimmedAccumulated.length > trimmedFinal.length) {
      return accumulatedText;
    }
    return finalText;
  }

  String _confirmedTextDelta({
    required String previous,
    required String next,
  }) {
    if (previous.isEmpty || next.startsWith(previous)) {
      return next.substring(previous.length);
    }
    if (previous.startsWith(next)) {
      return '';
    }

    final overlapLength = _suffixPrefixOverlapLength(previous, next);
    if (overlapLength > 0) {
      return next.substring(overlapLength);
    }

    return next.substring(_commonPrefixLength(previous, next));
  }

  int _suffixPrefixOverlapLength(String previous, String next) {
    final maxLength = previous.length < next.length
        ? previous.length
        : next.length;
    for (var length = maxLength; length > 0; length--) {
      if (previous.endsWith(next.substring(0, length))) {
        return length;
      }
    }
    return 0;
  }

  int _commonPrefixLength(String a, String b) {
    final maxLength = a.length < b.length ? a.length : b.length;
    for (var i = 0; i < maxLength; i++) {
      if (a.codeUnitAt(i) != b.codeUnitAt(i)) {
        return i;
      }
    }
    return maxLength;
  }

  void _bufferPcmAndAmplitude(Uint8List chunk) {
    final newTotal = _pcmBuffer.length + chunk.length;
    if (newTotal > _maxPcmBufferBytes) {
      final existing = _pcmBuffer.takeBytes();
      if (chunk.length >= _maxPcmBufferBytes) {
        _pcmBuffer.add(
          chunk.sublist(chunk.length - _maxPcmBufferBytes),
        );
      } else {
        final excess = newTotal - _maxPcmBufferBytes;
        final kept = existing.length - excess;
        final merged = Uint8List(kept + chunk.length)
          ..setRange(0, kept, existing, excess)
          ..setRange(kept, kept + chunk.length, chunk);
        _pcmBuffer.add(merged);
      }
    } else {
      _pcmBuffer.add(chunk);
    }

    if (!_amplitudeController.isClosed) {
      final dbfs = computeDbfsFromPcm16(chunk);
      _amplitudeController.add(dbfs);
    }
  }

  Future<String?> _saveAudio(String outputPath) async {
    if (_pcmBuffer.length == 0) return null;

    final tempWavPath =
        '${Directory.systemTemp.path}/lotti_rt_'
        '${DateTime.now().millisecondsSinceEpoch}.wav';

    try {
      await _writeTempWav(tempWavPath);

      // Attempt M4A conversion
      final m4aPath = outputPath.endsWith('.m4a')
          ? outputPath
          : '$outputPath.m4a';

      final converted = await AudioConverterChannel.convertWavToM4a(
        inputPath: tempWavPath,
        outputPath: m4aPath,
      );

      if (converted) {
        // Delete temp WAV on successful conversion
        try {
          await File(tempWavPath).delete();
        } catch (_) {}
        return m4aPath;
      } else {
        // Move WAV to final location as fallback
        final wavOutputPath = outputPath.endsWith('.wav')
            ? outputPath
            : '$outputPath.wav';
        await File(tempWavPath).rename(wavOutputPath);
        return wavOutputPath;
      }
    } catch (e) {
      getIt<LoggingService>().captureException(
        e,
        domain: 'RealtimeTranscriptionService',
        subDomain: 'saveAudio',
      );
      // Try to keep the WAV if it exists
      if (File(tempWavPath).existsSync()) {
        return tempWavPath;
      }
      return null;
    }
  }

  Future<void> _writeTempWav(String path) async {
    final pcmData = _pcmBuffer.toBytes();
    final dataSize = pcmData.length;

    // WAV header: 44 bytes
    // PCM 16-bit signed LE, 16kHz, mono
    const sampleRate = 16000;
    const channels = 1;
    const bitsPerSample = 16;
    const byteRate = sampleRate * channels * bitsPerSample ~/ 8;
    const blockAlign = channels * bitsPerSample ~/ 8;

    final header = ByteData(44)
      // RIFF header
      ..setUint32(0, 0x52494646) // 'RIFF'
      ..setUint32(4, 36 + dataSize, Endian.little) // file size - 8
      ..setUint32(8, 0x57415645) // 'WAVE'
      // fmt chunk
      ..setUint32(12, 0x666D7420) // 'fmt '
      ..setUint32(16, 16, Endian.little) // chunk size
      ..setUint16(20, 1, Endian.little) // PCM format
      ..setUint16(22, channels, Endian.little)
      ..setUint32(24, sampleRate, Endian.little)
      ..setUint32(28, byteRate, Endian.little)
      ..setUint16(32, blockAlign, Endian.little)
      ..setUint16(34, bitsPerSample, Endian.little)
      // data chunk
      ..setUint32(36, 0x64617461) // 'data'
      ..setUint32(40, dataSize, Endian.little);

    final file = File(path);
    final sink = file.openWrite()
      ..add(header.buffer.asUint8List())
      ..add(pcmData);
    await sink.flush();
    await sink.close();
  }

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
