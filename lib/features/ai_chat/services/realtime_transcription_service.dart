import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/realtime_transcription_event.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/mistral_realtime_transcription_repository.dart';
import 'package:lotti/features/ai/util/known_models.dart';
import 'package:lotti/features/ai/util/mlx_audio_channel.dart';
import 'package:lotti/features/ai_chat/services/realtime_audio_buffer.dart';
import 'package:lotti/features/ai_chat/services/realtime_transcript_merge.dart';
import 'package:lotti/features/speech/services/durable_audio_spool.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

/// Stable UUIDv5 namespace name for capture-to-Activity identity.
const dailyOsAudioActivityNamespaceName =
    'https://lotti.app/namespaces/day-audio-activity';

final String _dailyOsAudioActivityNamespace = const Uuid().v5(
  Namespace.url.value,
  dailyOsAudioActivityNamespaceName,
);

/// Deterministic Activity identity shared by spool, journal, and Day timeline.
String audioActivityEntryIdForSession(String recordingSessionId) =>
    const Uuid().v5(_dailyOsAudioActivityNamespace, recordingSessionId);

enum _RealtimeBackendKind { mistral, mlxAudio }

/// Reports a terminal local-capture failure while the microphone is live.
///
/// The callback runs after the failure is latched. Callers should begin their
/// normal stop flow so the recorder closes promptly and the already-accepted
/// PCM remains recoverable from the durable spool.
typedef RealtimeCaptureFailureCallback =
    void Function(Object error, StackTrace stackTrace);

/// UI gate for live transcription.
///
/// Keep the realtime pipeline available behind the service/controller APIs, but
/// hide it from product surfaces until local realtime transcription can use the
/// same dictionary/context biasing as the batch path.
const realtimeTranscriptionUiEnabled = false;

/// A prepared local-first recording owned independently of the realtime
/// backend. Callers allocate it before requesting microphone permission.
class DurableRealtimeCapture {
  const DurableRealtimeCapture._(this.spool);

  final DurableAudioSpool spool;

  String get recordingSessionId => spool.manifest.context.recordingSessionId;
  String get activityEntryId => spool.manifest.context.activityEntryId;
  DateTime get createdAt => spool.manifest.context.createdAt;
  String? get dayId => spool.manifest.context.dayId;
  DateTime? get planDate => spool.manifest.context.planDate;
  AudioCaptureIntent? get intent => spool.manifest.context.intent;
  String? get originHostId => spool.manifest.context.originHostId;
  String? get continuationOperationId =>
      spool.manifest.context.continuationOperationId;
  String? get baselineRevisionId => spool.manifest.context.baselineRevisionId;
  Directory get sessionDirectory => spool.sessionDirectory;
  int get acceptedPcmBytes => spool.manifest.acceptedPcmBytes;

  Future<void> markCommitted({required String journalAudioId}) =>
      spool.markCommitted(journalAudioId: journalAudioId);

  Future<void> discard() => spool.discard();

  Future<void> consumeTransient() => spool.consumeTransient();
}

/// Orchestrates real-time transcription: connects WebSocket, streams PCM
/// audio, durably spools PCM for WAV output, and computes amplitude.
///
/// This service bypasses `CloudInferenceRepository` entirely — real-time
/// WebSocket streaming is a different paradigm from the HTTP batch flow.
class RealtimeTranscriptionService {
  RealtimeTranscriptionService(
    this._ref, {
    MistralRealtimeTranscriptionRepository? repository,
    MlxAudioChannel? mlxAudioChannel,
    RealtimeAudioBuffer? audioBuffer,
    this._doneTimeout = const Duration(seconds: 10),
    this.pcmDrainTimeout = const Duration(seconds: 2),
    String Function()? durableIdFactory,
    Future<String?> Function()? originHostIdProvider,
  }) : _repository = repository ?? MistralRealtimeTranscriptionRepository(),
       _mlxAudioChannel = mlxAudioChannel ?? MlxAudioChannel(),
       _audioBuffer = audioBuffer ?? RealtimeAudioBuffer(),
       _durableIdFactory = durableIdFactory ?? (() => const Uuid().v4()),
       _originHostIdProvider =
           originHostIdProvider ??
           (() => getIt<VectorClockService>().getHost());

  final Ref _ref;
  final MistralRealtimeTranscriptionRepository _repository;
  final MlxAudioChannel _mlxAudioChannel;
  final Duration _doneTimeout;

  /// Maximum wait for the recorder's PCM stream to close during stop.
  final Duration pcmDrainTimeout;
  final RealtimeAudioBuffer _audioBuffer;
  final String Function() _durableIdFactory;
  final Future<String?> Function() _originHostIdProvider;
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
  DurableRealtimeCapture? _activeCapture;
  Completer<void>? _pcmDoneCompleter;
  Object? _pcmFailure;
  Object? _backendFailure;
  Future<RealtimeStopResult>? _stopFuture;
  String? _stopOutputPath;
  DurableRealtimeCapture? _stopCapture;
  Future<void>? _retentionFuture;
  DurableRealtimeCapture? _retentionCapture;
  Future<void> _pcmProcessingTail = Future<void>.value();
  Future<void> _backendForwardTail = Future<void>.value();
  Future<void> _backendSetupTail = Future<void>.value();
  int _pendingBackendBytes = 0;
  int _sessionEpoch = 0;

  /// Stream of amplitude values (dBFS) computed from PCM chunks.
  Stream<double> get amplitudeStream => _audioBuffer.amplitudeStream;

  /// Whether a real-time transcription session is active.
  bool get isActive => _isActive;

  /// Completes when the most recently observed PCM frame has either been
  /// persisted and forwarded or failed. Primarily useful for deterministic
  /// coordination; normal stop drains the complete recorder stream.
  Future<void> flushPendingPcm() async {
    await _pcmProcessingTail;
    await _backendForwardTail;
  }

  /// Publishes the initial durable manifest before microphone capture starts.
  Future<DurableRealtimeCapture> prepareDurableCapture({
    required Directory rootDirectory,
    required DurableAudioSpoolContext context,
    int maxPendingBytes = defaultSpoolPendingBytes,
    AudioSpoolDurability durability = const AudioSpoolDurability(),
  }) async {
    final spool = await DurableAudioSpool.start(
      rootDirectory: rootDirectory,
      context: context,
      maxPendingBytes: maxPendingBytes,
      durability: durability,
    );
    return DurableRealtimeCapture._(spool);
  }

  /// Allocates stable source identity and a private spool beneath an existing
  /// app-owned asset root. This remains local-only until a caller commits the
  /// finalized WAV to its owning journal row.
  Future<DurableRealtimeCapture> prepareDefaultDurableCapture({
    required Directory assetRootDirectory,
    required DateTime createdAt,
    required AudioCaptureOrigin origin,
    required AudioCaptureIntent intent,
    String? dayId,
    DateTime? planDate,
    String? continuationOperationId,
    String? baselineRevisionId,
    Map<String, String> metadata = const <String, String>{},
  }) async {
    final assetRoot = assetRootDirectory.absolute;
    final sessionId = _durableIdFactory();
    String? originHostId;
    try {
      originHostId = await _originHostIdProvider();
    } catch (_) {}
    return prepareDurableCapture(
      rootDirectory: Directory(path.join(assetRoot.path, '.audio_spool')),
      context: DurableAudioSpoolContext(
        recordingSessionId: sessionId,
        activityEntryId: audioActivityEntryIdForSession(sessionId),
        createdAt: createdAt,
        assetRootPath: path.normalize(assetRoot.path),
        origin: origin,
        intent: intent,
        dayId: dayId,
        planDate: planDate == null
            ? null
            : DateTime(planDate.year, planDate.month, planDate.day),
        timeZoneOffsetMinutes: createdAt.timeZoneOffset.inMinutes,
        originHostId: originHostId,
        continuationOperationId: continuationOperationId,
        baselineRevisionId: baselineRevisionId,
        metadata: metadata,
      ),
    );
  }

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
    required DurableRealtimeCapture capture,
    required Stream<Uint8List> pcmStream,
    required void Function(String delta) onDelta,
    RealtimeCaptureFailureCallback? onCaptureFailure,
    ({AiConfigInferenceProvider provider, AiConfigModel model})? config,
    bool resolveConfigWhenAbsent = true,
  }) async {
    if (_isActive || _stopFuture != null || _retentionFuture != null) {
      throw StateError('A realtime capture is already active');
    }
    final sessionEpoch = ++_sessionEpoch;
    _isActive = true;
    _activeCapture = capture;
    _pcmFailure = null;
    _backendFailure = null;
    _audioBuffer.clear();
    _deltaBuffer.clear();
    _detectedLanguage = null;
    _lastMlxConfirmedText = '';
    _backendForwardTail = Future<void>.value();
    _pendingBackendBytes = 0;
    _subscribeToDurablePcm(
      pcmStream,
      capture,
      onCaptureFailure: onCaptureFailure,
    );

    ({AiConfigInferenceProvider provider, AiConfigModel model})? resolvedConfig;
    try {
      resolvedConfig = config;
      if (resolvedConfig == null && resolveConfigWhenAbsent) {
        resolvedConfig = await resolveRealtimeConfig();
      }
    } catch (error, stackTrace) {
      if (!_isCurrentSession(sessionEpoch, capture)) return;
      _logBackendFailure(
        error,
        stackTrace,
        subDomain: 'start.resolveConfig',
      );
      return;
    }
    if (!_isCurrentSession(sessionEpoch, capture)) return;
    if (resolvedConfig == null) {
      getIt<DomainLogger>().log(
        LogDomain.speech,
        'No realtime transcription model configured; retaining local audio',
        subDomain: 'start.noBackend',
      );
      return;
    }

    if (resolvedConfig.provider.inferenceProviderType ==
        InferenceProviderType.mlxAudio) {
      await _serializeBackendSetup(
        () => _startMlxRealtimeTranscription(
          config: resolvedConfig!,
          onDelta: onDelta,
          sessionEpoch: sessionEpoch,
          capture: capture,
        ),
      );
      return;
    }
    await _serializeBackendSetup(
      () => _startMistralRealtimeTranscription(
        config: resolvedConfig!,
        onDelta: onDelta,
        sessionEpoch: sessionEpoch,
        capture: capture,
      ),
    );
  }

  /// Stops the real-time transcription session.
  ///
  /// 1. Calls [stopRecorder], causing the source stream to close after its
  ///    buffered tail has been delivered
  /// 2. Drains the durable PCM subscription
  /// 3. Signals end-of-audio to the active backend
  /// 4. Awaits the terminal transcript with a bounded timeout
  /// 5. Finalizes the durable PCM spool as a WAV asset
  /// 6. Disconnects the backend
  /// 7. Returns [RealtimeStopResult]
  Future<RealtimeStopResult> stop({
    required DurableRealtimeCapture capture,
    required Future<void> Function() stopRecorder,
    required String outputPath,
  }) {
    final retention = _retentionFuture;
    if (retention != null) {
      return Future<RealtimeStopResult>.error(
        StateError(
          identical(_retentionCapture, capture)
              ? 'Realtime capture is already being retained for recovery'
              : 'Another realtime capture is being retained for recovery',
        ),
      );
    }
    final existing = _stopFuture;
    if (existing != null) {
      if (!identical(_stopCapture, capture) || _stopOutputPath != outputPath) {
        return Future<RealtimeStopResult>.error(
          StateError('Realtime stop already targets $_stopOutputPath'),
        );
      }
      return existing;
    }
    _requireActiveCapture(capture);
    final operation = _runStop(
      capture: capture,
      stopRecorder: stopRecorder,
      outputPath: outputPath,
    );
    _stopFuture = operation;
    _stopOutputPath = outputPath;
    _stopCapture = capture;
    operation.then<void>(
      (_) => _clearStopOperation(operation),
      onError: (Object _, StackTrace _) => _clearStopOperation(operation),
    );
    return operation;
  }

  Future<RealtimeStopResult> _runStop({
    required DurableRealtimeCapture capture,
    required Future<void> Function() stopRecorder,
    required String outputPath,
  }) async {
    if (!_isActive || _activeCapture == null) {
      // stop() validates the capture synchronously before entering this method.
      throw StateError(
        'No durable realtime capture is active',
      ); // coverage:ignore-line
    }
    if (_activeBackend == _RealtimeBackendKind.mlxAudio) {
      return _stopMlxRealtimeTranscription(
        capture: capture,
        stopRecorder: stopRecorder,
        outputPath: outputPath,
      );
    }
    if (_activeBackend == null) {
      return _stopLocalCapture(
        capture: capture,
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
    Object? doneError;
    StackTrace? doneErrorStackTrace;
    final doneSubscription = _repository.transcriptionDone.listen(
      (done) {
        if (!doneCompleter.isCompleted) {
          doneCompleter.complete(done);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!doneCompleter.isCompleted) {
          doneError = error;
          doneErrorStackTrace = stackTrace;
          doneCompleter.complete(
            RealtimeTranscriptionDone(text: _deltaBuffer.toString()),
          );
        }
      },
    );

    try {
      String transcript;
      var usedFallback = false;
      try {
        // The record package closes its PCM stream only after delivering the
        // final frames. Stopping before draining prevents tail truncation.
        await _stopRecorderAndDrain(stopRecorder);
        await _drainBackendForwarding();

        // Signal end only after every locally accepted frame was forwarded.
        await _repository.endAudio();

        final done = await doneCompleter.future.timeout(_doneTimeout);
        final terminalError = doneError;
        if (terminalError != null) {
          Error.throwWithStackTrace(
            terminalError,
            // Dart stream errors carry a stack; retain a fallback for custom
            // stream implementations that violate that convention.
            doneErrorStackTrace ?? StackTrace.current, // coverage:ignore-line
          );
        }
        transcript = moreCompleteTranscript(
          finalText: done.text,
          accumulatedText: _deltaBuffer.toString(),
        );
        usedFallback = usedFallback || _backendFailure != null;
      } on TimeoutException {
        transcript = _deltaBuffer.toString();
        usedFallback = true;
        getIt<DomainLogger>().log(
          LogDomain.speech,
          'transcription.done timed out, using accumulated deltas '
          '(${transcript.length} chars)',
          subDomain: 'stop.timeout',
        );
      } catch (error, stackTrace) {
        transcript = _deltaBuffer.toString();
        usedFallback = true;
        _logBackendFailure(
          error,
          stackTrace,
          subDomain: 'stop.backend',
        );
      }

      return await _finalizeStopResult(
        transcript: transcript,
        usedTranscriptFallback: usedFallback,
        detectedLanguage: _detectedLanguage,
        outputPath: outputPath,
      );
    } finally {
      await _runCleanupStep(
        doneSubscription.cancel,
        subDomain: 'cleanup.done',
      );
      await _cleanup(capture);
    }
  }

  /// Safely tears down a caller-owned live capture without finalizing it.
  ///
  /// The recorder callback is mandatory so disposal cannot cancel the source
  /// subscription ahead of buffered microphone frames.
  Future<void> dispose({
    required DurableRealtimeCapture capture,
    required Future<void> Function() stopRecorder,
  }) => stopAndRetainForRecovery(
    capture: capture,
    stopRecorder: stopRecorder,
  );

  /// Stops the recorder, drains every source frame that can still be
  /// delivered, and leaves the durable spool for startup recovery.
  ///
  /// Call this instead of [dispose] when a live recorder is being torn down
  /// without normal WAV finalization (provider disposal, start failure, or
  /// explicit cancellation before [DurableRealtimeCapture.discard]).
  Future<void> stopAndRetainForRecovery({
    required DurableRealtimeCapture capture,
    required Future<void> Function() stopRecorder,
  }) async {
    final stopOperation = _stopFuture;
    if (stopOperation != null) {
      if (!identical(_stopCapture, capture)) {
        await _stopCallerRecorder(stopRecorder);
        return;
      }
      try {
        await stopOperation;
      } catch (_) {}
      return;
    }
    final retentionOperation = _retentionFuture;
    if (retentionOperation != null) {
      if (!identical(_retentionCapture, capture)) {
        await _stopCallerRecorder(stopRecorder);
        return;
      }
      await retentionOperation;
      return;
    }
    if (_isActive && identical(_activeCapture, capture)) {
      final operation = _retainActiveCapture(capture, stopRecorder);
      _retentionCapture = capture;
      _retentionFuture = operation;
      try {
        await operation;
      } finally {
        if (identical(_retentionFuture, operation)) {
          _retentionFuture = null;
          _retentionCapture = null;
        }
      }
      return;
    }
    await _stopCallerRecorder(stopRecorder);
  }

  Future<void> _retainActiveCapture(
    DurableRealtimeCapture capture,
    Future<void> Function() stopRecorder,
  ) async {
    await _stopRecorderAndDrain(stopRecorder);
    await _drainBackendForwarding();
    await _cleanup(capture);
  }

  Future<void> _stopCallerRecorder(
    Future<void> Function() stopRecorder,
  ) async {
    try {
      await stopRecorder();
    } catch (_) {}
  }

  void _clearStopOperation(Future<RealtimeStopResult> operation) {
    if (identical(_stopFuture, operation)) {
      _stopFuture = null;
      _stopOutputPath = null;
      _stopCapture = null;
    }
  }

  bool _isCurrentSession(
    int sessionEpoch,
    DurableRealtimeCapture capture,
  ) =>
      _isActive &&
      _sessionEpoch == sessionEpoch &&
      identical(_activeCapture, capture);

  void _requireActiveCapture(DurableRealtimeCapture capture) {
    if (!_isActive || !identical(_activeCapture, capture)) {
      throw StateError('The durable realtime capture is not active');
    }
  }

  Future<void> _serializeBackendSetup(Future<void> Function() setup) async {
    final previous = _backendSetupTail;
    final operation = () async {
      try {
        await previous;
      } catch (_) {}
      await setup();
    }();
    _backendSetupTail = operation;
    await operation;
  }

  Future<void> _startMistralRealtimeTranscription({
    required ({AiConfigInferenceProvider provider, AiConfigModel model}) config,
    required void Function(String delta) onDelta,
    required int sessionEpoch,
    required DurableRealtimeCapture capture,
  }) async {
    if (!_isCurrentSession(sessionEpoch, capture)) return;

    _deltaSubscription = _repository.transcriptionDeltas.listen((delta) {
      if (!_isCurrentSession(sessionEpoch, capture)) return;
      _deltaBuffer.write(delta);
      onDelta(delta);
    });
    _languageSubscription = _repository.detectedLanguage.listen((language) {
      if (_isCurrentSession(sessionEpoch, capture)) {
        _detectedLanguage = language;
      }
    });
    try {
      await _repository.connect(
        apiKey: config.provider.apiKey,
        baseUrl: config.provider.baseUrl,
        model: config.model.providerModelId,
      );
      if (!_isCurrentSession(sessionEpoch, capture)) {
        await _cancelMistralSubscriptions();
        await _repository.disconnect();
        return;
      }
      _activeBackend = _RealtimeBackendKind.mistral;
    } catch (error, stackTrace) {
      if (_isCurrentSession(sessionEpoch, capture)) {
        _logBackendFailure(
          error,
          stackTrace,
          subDomain: 'start.mistral',
        );
      }
      await _cancelMistralSubscriptions();
      await _repository.disconnect();
    }
  }

  Future<void> _startMlxRealtimeTranscription({
    required ({AiConfigInferenceProvider provider, AiConfigModel model}) config,
    required void Function(String delta) onDelta,
    required int sessionEpoch,
    required DurableRealtimeCapture capture,
  }) async {
    if (!_isCurrentSession(sessionEpoch, capture)) return;
    _mlxDoneCompleter = Completer<RealtimeTranscriptionDone>();

    _mlxEventSubscription = _mlxAudioChannel.realtimeTranscriptionEvents.listen(
      (event) {
        if (!_isCurrentSession(sessionEpoch, capture)) return;
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
              completer.complete(
                RealtimeTranscriptionDone(text: _deltaBuffer.toString()),
              );
            }
            _backendFailure = error;
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
        if (!_isCurrentSession(sessionEpoch, capture)) return;
        final completer = _mlxDoneCompleter;
        if (completer != null && !completer.isCompleted) {
          completer.complete(
            RealtimeTranscriptionDone(text: _deltaBuffer.toString()),
          );
        }
        _backendFailure = error;
        _logBackendFailure(
          error,
          stackTrace,
          subDomain: 'mlxAudio.eventStream',
        );
      },
    );

    try {
      await _mlxAudioChannel.startRealtimeTranscription(
        modelId: config.model.providerModelId,
      );
      if (!_isCurrentSession(sessionEpoch, capture)) {
        await _mlxEventSubscription?.cancel();
        _mlxEventSubscription = null;
        _mlxDoneCompleter = null;
        await _mlxAudioChannel.cancelRealtimeTranscription();
        return;
      }
      _activeBackend = _RealtimeBackendKind.mlxAudio;
    } catch (error, stackTrace) {
      if (_isCurrentSession(sessionEpoch, capture)) {
        _logBackendFailure(
          error,
          stackTrace,
          subDomain: 'start.mlxAudio',
        );
      }
      await _mlxEventSubscription?.cancel();
      _mlxEventSubscription = null;
      _mlxDoneCompleter = null;
      await _mlxAudioChannel.cancelRealtimeTranscription();
    }
  }

  void _subscribeToDurablePcm(
    Stream<Uint8List> pcmStream,
    DurableRealtimeCapture capture, {
    RealtimeCaptureFailureCallback? onCaptureFailure,
  }) {
    final done = _pcmDoneCompleter = Completer<void>();
    var pendingOperations = 0;
    var sourceClosed = false;
    late final StreamSubscription<Uint8List> subscription;

    void completeWhenDrained() {
      if (sourceClosed && pendingOperations == 0 && !done.isCompleted) {
        done.complete();
      }
    }

    void reportFailure(Object error, StackTrace stackTrace) {
      final isFirstFailure = _pcmFailure == null;
      _pcmFailure ??= error;
      getIt<DomainLogger>().error(
        LogDomain.speech,
        error,
        stackTrace: stackTrace,
        subDomain: 'pcmStream.persist',
      );
      if (isFirstFailure && onCaptureFailure != null) {
        try {
          onCaptureFailure(error, stackTrace);
        } catch (callbackError, callbackStackTrace) {
          getIt<DomainLogger>().error(
            LogDomain.speech,
            callbackError,
            stackTrace: callbackStackTrace,
            subDomain: 'pcmStream.captureFailureCallback',
          );
        }
      }
      if (isFirstFailure) {
        unawaited(
          () async {
            try {
              await subscription.cancel();
            } catch (cancelError, cancelStackTrace) {
              getIt<DomainLogger>().error(
                LogDomain.speech,
                cancelError,
                stackTrace: cancelStackTrace,
                subDomain: 'pcmStream.failureCancel',
              );
            } finally {
              sourceClosed = true;
              completeWhenDrained();
            }
          }(),
        );
      }
    }

    subscription = pcmStream.listen(
      (chunk) {
        if (_pcmFailure != null) return;
        pendingOperations += 1;
        final operation = _persistAndForward(
          capture,
          chunk,
        ).catchError(reportFailure);
        _pcmProcessingTail = Future.wait<void>([
          _pcmProcessingTail,
          operation,
        ]);
        unawaited(
          operation.whenComplete(() {
            pendingOperations -= 1;
            completeWhenDrained();
          }),
        );
      },
      onError: (Object error, StackTrace stackTrace) {
        sourceClosed = true;
        reportFailure(error, stackTrace);
        completeWhenDrained();
      },
      onDone: () {
        sourceClosed = true;
        completeWhenDrained();
      },
      cancelOnError: true,
    );
    _pcmSubscription = subscription;
  }

  Future<void> _persistAndForward(
    DurableRealtimeCapture capture,
    Uint8List chunk,
  ) async {
    final appendResult = await capture.spool.append(chunk);
    if (appendResult == SpoolAppendResult.saturated) {
      throw DurableAudioSpoolRecoveryRequiredException(
        acceptedPcmBytes: capture.spool.manifest.acceptedPcmBytes,
        cause: StateError('Durable audio spool is saturated'),
      );
    }
    _audioBuffer.addChunk(chunk);
    _enqueueBackendForward(chunk);
  }

  void _enqueueBackendForward(Uint8List chunk) {
    final backend = _activeBackend;
    if (backend == null) return;
    if (_pendingBackendBytes + chunk.length > defaultSpoolPendingBytes) {
      final error = StateError('Realtime backend forwarding queue saturated');
      _logBackendFailure(
        error,
        StackTrace.current,
        subDomain: 'pcmStream.forwardSaturated',
      );
      unawaited(_disableActiveBackend(backend));
      return;
    }
    final ownedChunk = Uint8List.fromList(chunk);
    _pendingBackendBytes += ownedChunk.length;
    final previous = _backendForwardTail;
    _backendForwardTail = () async {
      try {
        await previous;
        if (_activeBackend != backend) return;
        switch (backend) {
          case _RealtimeBackendKind.mistral:
            _repository.sendAudioChunk(ownedChunk);
          case _RealtimeBackendKind.mlxAudio:
            await _mlxAudioChannel.appendRealtimePcm(ownedChunk);
        }
      } catch (error, stackTrace) {
        _logBackendFailure(
          error,
          stackTrace,
          subDomain: 'pcmStream.forward',
        );
        await _disableActiveBackend(backend);
      } finally {
        _pendingBackendBytes -= ownedChunk.length;
      }
    }();
  }

  Future<void> _disableActiveBackend(_RealtimeBackendKind? backend) async {
    if (_activeBackend != backend) return;
    _activeBackend = null;
    switch (backend) {
      case _RealtimeBackendKind.mistral:
        await _cancelMistralSubscriptions();
        await _repository.disconnect();
      case _RealtimeBackendKind.mlxAudio:
        await _mlxEventSubscription?.cancel();
        _mlxEventSubscription = null;
        _mlxDoneCompleter = null;
        await _mlxAudioChannel.cancelRealtimeTranscription();
      case null: // coverage:ignore-line
        break;
    }
  }

  Future<void> _drainPcmStream() async {
    final done = _pcmDoneCompleter;
    if (done != null && !done.isCompleted) {
      try {
        await done.future.timeout(pcmDrainTimeout);
      } on TimeoutException {
        _pcmFailure ??= TimeoutException(
          'PCM stream did not close after recorder stop',
          pcmDrainTimeout,
        );
        getIt<DomainLogger>().log(
          LogDomain.speech,
          'PCM stream did not close after recorder stop; preserving durable '
          'prefix',
          subDomain: 'pcmStream.drainTimeout',
        );
      }
    }
    try {
      await _pcmSubscription?.cancel();
    } catch (error, stackTrace) {
      _pcmFailure ??= error;
      getIt<DomainLogger>().error(
        LogDomain.speech,
        error,
        stackTrace: stackTrace,
        subDomain: 'pcmStream.cancel',
      );
    }
    _pcmSubscription = null;
  }

  Future<void> _drainBackendForwarding() async {
    try {
      await _backendForwardTail.timeout(_doneTimeout);
    } on TimeoutException catch (error, stackTrace) {
      _logBackendFailure(
        error,
        stackTrace,
        subDomain: 'pcmStream.forwardDrainTimeout',
      );
      await _disableActiveBackend(_activeBackend);
    }
  }

  Future<void> _stopRecorderAndDrain(
    Future<void> Function() stopRecorder,
  ) async {
    try {
      await stopRecorder();
    } catch (error, stackTrace) {
      _pcmFailure ??= error;
      getIt<DomainLogger>().error(
        LogDomain.speech,
        error,
        stackTrace: stackTrace,
        subDomain: 'pcmStream.stopRecorder',
      );
    }
    await _drainPcmStream();
  }

  Future<DurableAudioSpoolFinalization?> _finalizeDurableCapture(
    String outputPath,
  ) async {
    final capture = _activeCapture;
    if (capture == null) {
      throw StateError(
        'No durable realtime capture is active',
      ); // coverage:ignore-line
    }
    final destination = File(
      outputPath.toLowerCase().endsWith('.wav')
          ? outputPath
          : '$outputPath.wav',
    );
    try {
      final finalized = await capture.spool.finalize(
        destinationFile: destination,
      );
      return finalized;
    } on DurableAudioSpoolNoAudioException {
      await capture.discard();
      return null;
    }
  }

  Future<RealtimeStopResult> _finalizeStopResult({
    required String transcript,
    required bool usedTranscriptFallback,
    required String? detectedLanguage,
    required String outputPath,
  }) async {
    final recordingSessionId = _activeCapture?.recordingSessionId;
    if (recordingSessionId == null) {
      throw StateError(
        'No durable realtime capture is active',
      ); // coverage:ignore-line
    }
    try {
      final finalized = await _finalizeDurableCapture(outputPath);
      return RealtimeStopResult(
        transcript: transcript,
        recordingSessionId: recordingSessionId,
        audioFilePath: finalized?.wavPath,
        usedTranscriptFallback: usedTranscriptFallback,
        detectedLanguage: detectedLanguage,
        captureDisposition: finalized == null
            ? RealtimeCaptureDisposition.noAudio
            : _pcmFailure == null
            ? RealtimeCaptureDisposition.complete
            : RealtimeCaptureDisposition.savedPartial,
        audioDuration: finalized?.duration,
      );
    } catch (error, stackTrace) {
      getIt<DomainLogger>().error(
        LogDomain.speech,
        error,
        stackTrace: stackTrace,
        subDomain: 'pcmStream.finalize',
      );
      return RealtimeStopResult(
        transcript: transcript,
        recordingSessionId: recordingSessionId,
        usedTranscriptFallback: true,
        detectedLanguage: detectedLanguage,
        captureDisposition: RealtimeCaptureDisposition.recoveryRequired,
      );
    }
  }

  Future<RealtimeStopResult> _stopLocalCapture({
    required DurableRealtimeCapture capture,
    required Future<void> Function() stopRecorder,
    required String outputPath,
  }) async {
    try {
      await _stopRecorderAndDrain(stopRecorder);
      return await _finalizeStopResult(
        transcript: _deltaBuffer.toString(),
        usedTranscriptFallback: true,
        detectedLanguage: _detectedLanguage,
        outputPath: outputPath,
      );
    } finally {
      await _cleanup(capture);
    }
  }

  Future<void> _cancelMistralSubscriptions() async {
    await _deltaSubscription?.cancel();
    _deltaSubscription = null;
    await _languageSubscription?.cancel();
    _languageSubscription = null;
  }

  void _logBackendFailure(
    Object error,
    StackTrace stackTrace, {
    required String subDomain,
  }) {
    _backendFailure ??= error;
    getIt<DomainLogger>().error(
      LogDomain.speech,
      error,
      stackTrace: stackTrace,
      subDomain: subDomain,
    );
  }

  Future<RealtimeStopResult> _stopMlxRealtimeTranscription({
    required DurableRealtimeCapture capture,
    required Future<void> Function() stopRecorder,
    required String outputPath,
  }) async {
    final doneCompleter =
        _mlxDoneCompleter ?? Completer<RealtimeTranscriptionDone>();

    try {
      String transcript;
      var usedFallback = _backendFailure != null;
      try {
        await _stopRecorderAndDrain(stopRecorder);
        await _drainBackendForwarding();
        await _mlxAudioChannel.stopRealtimeTranscription();

        final done = await doneCompleter.future.timeout(_doneTimeout);
        transcript = moreCompleteTranscript(
          finalText: done.text,
          accumulatedText: _deltaBuffer.toString(),
        );
        usedFallback = usedFallback || _backendFailure != null;
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

      return await _finalizeStopResult(
        transcript: transcript,
        usedTranscriptFallback: usedFallback,
        detectedLanguage: _detectedLanguage,
        outputPath: outputPath,
      );
    } finally {
      await _cleanup(capture);
    }
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
  Future<void> _cleanup(DurableRealtimeCapture capture) async {
    if (!identical(_activeCapture, capture)) return;
    _sessionEpoch += 1;
    _isActive = false;
    final deltaSubscription = _deltaSubscription;
    final languageSubscription = _languageSubscription;
    final mlxEventSubscription = _mlxEventSubscription;
    final activeBackend = _activeBackend;
    _deltaSubscription = null;
    _languageSubscription = null;
    _mlxEventSubscription = null;
    _activeBackend = null;
    _activeCapture = null;
    _pcmDoneCompleter = null;
    await _runCleanupStep(
      () => deltaSubscription?.cancel(),
      subDomain: 'cleanup.delta',
    );
    await _runCleanupStep(
      () => languageSubscription?.cancel(),
      subDomain: 'cleanup.language',
    );
    await _runCleanupStep(
      () => mlxEventSubscription?.cancel(),
      subDomain: 'cleanup.mlxEvents',
    );
    _mlxDoneCompleter = null;
    _lastMlxConfirmedText = '';
    _detectedLanguage = null;
    _deltaBuffer.clear();
    if (activeBackend == _RealtimeBackendKind.mlxAudio) {
      await _runCleanupStep(
        _mlxAudioChannel.cancelRealtimeTranscription,
        subDomain: 'cleanup.mlxBackend',
      );
    } else {
      await _runCleanupStep(
        _repository.disconnect,
        subDomain: 'cleanup.mistralBackend',
      );
    }
    _pcmFailure = null;
    _backendFailure = null;
    _pcmProcessingTail = Future<void>.value();
    _backendForwardTail = Future<void>.value();
    _pendingBackendBytes = 0;
  }

  Future<void> _runCleanupStep(
    Future<void>? Function() operation, {
    required String subDomain,
  }) async {
    try {
      await operation();
    } catch (error, stackTrace) {
      getIt<DomainLogger>().error(
        LogDomain.speech,
        error,
        stackTrace: stackTrace,
        subDomain: subDomain,
      );
    }
  }
}

bool _isMlxRealtimeModel(String providerModelId) =>
    isMlxAudioQwenAsrModelId(providerModelId);

/// Provides the long-lived [RealtimeTranscriptionService]. Not `autoDispose`:
/// the service is a singleton whose audio buffer is reused across sessions (it
/// deliberately never closes its amplitude stream — see [RealtimeAudioBuffer]).
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
