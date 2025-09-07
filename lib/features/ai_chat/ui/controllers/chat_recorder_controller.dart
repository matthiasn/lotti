import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart' as record;

enum ChatRecorderStatus { idle, recording, processing }

enum ChatRecorderErrorType {
  permissionDenied,
  startFailed,
  noAudioFile,
  transcriptionFailed,
  cleanupFailed,
  concurrentOperation,
  storageFull,
  fileCorruption,
}

class ChatRecorderState {
  // Constructors first per lint
  const ChatRecorderState({
    required this.status,
    required this.amplitudeHistory,
    this.transcript,
    this.error,
    this.errorType,
  });

  const ChatRecorderState.initial()
      : status = ChatRecorderStatus.idle,
        amplitudeHistory = const <double>[],
        transcript = null,
        error = null,
        errorType = null;

  // Fields
  final ChatRecorderStatus status;
  final List<double> amplitudeHistory; // dBFS history
  final String? transcript; // last finished transcript waiting to be consumed
  final String? error;
  final ChatRecorderErrorType? errorType;

  // Methods
  ChatRecorderState copyWith({
    ChatRecorderStatus? status,
    List<double>? amplitudeHistory,
    String? transcript,
    String? error,
    ChatRecorderErrorType? errorType,
  }) {
    return ChatRecorderState(
      status: status ?? this.status,
      amplitudeHistory: amplitudeHistory ?? this.amplitudeHistory,
      transcript: transcript,
      error: error,
      errorType: errorType,
    );
  }
}

class ChatRecorderController extends StateNotifier<ChatRecorderState> {
  ChatRecorderController(
    this.ref, {
    record.AudioRecorder Function()? recorderFactory,
    int Function()? nowMillisProvider,
    Future<Directory> Function()? tempDirectoryProvider,
    ChatRecorderConfig? config,
  })  : _recorderFactory = recorderFactory ?? record.AudioRecorder.new,
        _nowMillisProvider =
            nowMillisProvider ?? (() => DateTime.now().millisecondsSinceEpoch),
        _tempDirectoryProvider =
            tempDirectoryProvider ?? (() async => getTemporaryDirectory()),
        _config = config ?? const ChatRecorderConfig(),
        super(const ChatRecorderState.initial());

  final Ref ref;
  final record.AudioRecorder Function() _recorderFactory;
  final int Function() _nowMillisProvider;
  final Future<Directory> Function() _tempDirectoryProvider;
  final ChatRecorderConfig _config;

  record.AudioRecorder? _recorder;
  StreamSubscription<record.Amplitude>? _ampSub;
  Timer? _maxTimer;
  Directory? _tempDir;
  String? _filePath;
  bool _isStarting = false;
  DateTime? _lastAmpUpdate;

  static const int _historyMax = 200; // ~10s at 50ms; UI will sample to fit
  static const int _cleanupTimeoutSeconds = 2;
  static const int _fileDeleteTimeoutSeconds = 2;

  Future<void> start() async {
    if (_isStarting) {
      state = state.copyWith(
        error: 'Another operation is in progress',
        errorType: ChatRecorderErrorType.concurrentOperation,
      );
      return;
    }
    if (state.status != ChatRecorderStatus.idle) return;

    _isStarting = true;
    final recorder = _recorderFactory();
    try {
      final hasPerm = await recorder.hasPermission();
      if (!hasPerm) {
        state = state.copyWith(
          error: 'Microphone permission denied. Please enable it in Settings.',
          errorType: ChatRecorderErrorType.permissionDenied,
        );
        await recorder.dispose();
        return;
      }

      // Use app-scoped temporary directory for better privacy
      final baseTemp = await _tempDirectoryProvider();
      _tempDir = await Directory('${baseTemp.path}/lotti_chat_rec')
          .create(recursive: true);
      final fileName = 'chat_${_nowMillisProvider()}.m4a';
      _filePath = '${_tempDir!.path}/$fileName';

      await recorder.start(
        record.RecordConfig(
          sampleRate: _config.sampleRate,
          autoGain: true,
        ),
        path: _filePath!,
      );

      _recorder = recorder;

      // Amplitude stream (throttled)
      _lastAmpUpdate = DateTime.now();
      _ampSub = recorder
          .onAmplitudeChanged(
              Duration(milliseconds: _config.amplitudeIntervalMs))
          .listen((event) {
        final now = DateTime.now();
        final last = _lastAmpUpdate;
        if (last != null &&
            now.difference(last).inMilliseconds < _config.amplitudeIntervalMs) {
          return;
        }
        _lastAmpUpdate = now;
        final dBFS = event.current;
        final history = List<double>.from(state.amplitudeHistory)..add(dBFS);
        if (history.length > _historyMax) history.removeAt(0);
        state = state.copyWith(
          status: ChatRecorderStatus.recording,
          amplitudeHistory: history,
        );
      });

      // Safety stop after configured max duration
      _maxTimer?.cancel();
      _maxTimer = Timer(Duration(seconds: _config.maxSeconds), () {
        unawaited(stopAndTranscribe());
      });

      // Log start
      getIt<LoggingService>().captureEvent(
        'chat_recording_started',
        domain: 'ChatRecorderController',
        subDomain: 'start',
      );
    } catch (e) {
      state = state.copyWith(
        error: 'Failed to start recording: $e',
        errorType: ChatRecorderErrorType.startFailed,
      );
      await _cleanupInternal();
    } finally {
      _isStarting = false;
    }
  }

  Future<void> stopAndTranscribe() async {
    if (_recorder == null) return;
    state = state.copyWith(status: ChatRecorderStatus.processing);
    _maxTimer?.cancel();

    try {
      await _ampSub?.cancel();
      await _recorder!.stop();
    } catch (_) {
      // ignore
    }

    final filePath = _filePath;
    if (filePath == null) {
      await _cleanupInternal();
      state = state.copyWith(
        status: ChatRecorderStatus.idle,
        error: 'No audio file available',
        errorType: ChatRecorderErrorType.noAudioFile,
      );
      return;
    }

    try {
      final transcript = await _transcribe(filePath);
      state = state.copyWith(
          status: ChatRecorderStatus.idle, transcript: transcript);
    } catch (e) {
      state = state.copyWith(
        status: ChatRecorderStatus.idle,
        error: 'Transcription failed: $e',
        errorType: ChatRecorderErrorType.transcriptionFailed,
      );
    } finally {
      await _cleanupInternal();
    }
  }

  /// Cancel current recording and discard audio without transcription.
  Future<void> cancel() async {
    if (state.status != ChatRecorderStatus.recording &&
        state.status != ChatRecorderStatus.processing) {
      return;
    }
    _maxTimer?.cancel();
    try {
      await _ampSub?.cancel();
    } catch (_) {}
    try {
      await _recorder?.stop();
    } catch (_) {}
    await _cleanupInternal();
    state = state.copyWith(status: ChatRecorderStatus.idle);
  }

  // Always Gemini Flash for v1 per requirements
  Future<String> _transcribe(String filePath) async {
    final aiRepo = ref.read(aiConfigRepositoryProvider);
    final providers =
        await aiRepo.getConfigsByType(AiConfigType.inferenceProvider);
    final provider = providers
        .whereType<AiConfigInferenceProvider>()
        .firstWhere(
            (p) => p.inferenceProviderType == InferenceProviderType.gemini,
            orElse: () => throw Exception('No Gemini provider configured'));

    final models = await aiRepo.getConfigsByType(AiConfigType.model);
    final geminiModels = models.whereType<AiConfigModel>().where(
          (m) =>
              m.inferenceProviderId == provider.id &&
              m.inputModalities.contains(Modality.audio),
        );
    final model = geminiModels.firstWhere(
      (m) => m.providerModelId.contains('gemini-2.5-flash'),
      orElse: () => geminiModels.isNotEmpty
          ? geminiModels.first
          : throw Exception('No Gemini audio-capable model configured'),
    );

    // NOTE: For now we must base64 encode the entire file due to API
    // requirements. Keep duration capped to avoid OOM.
    final bytes = await File(filePath).readAsBytes();
    final audioBase64 = base64Encode(bytes);

    final cloud = ref.read(cloudInferenceRepositoryProvider);
    final buffer = StringBuffer();
    final stream = cloud.generateWithAudio(
      'Transcribe the audio to natural text.',
      model: model.providerModelId,
      audioBase64: audioBase64,
      baseUrl: provider.baseUrl,
      apiKey: provider.apiKey,
      provider: provider,
      maxCompletionTokens: model.maxCompletionTokens,
    );

    await for (final chunk in stream) {
      final content = chunk.choices?.firstOrNull?.delta?.content ?? '';
      if (content.isNotEmpty) buffer.write(content);
    }
    getIt<LoggingService>().captureEvent(
      'chat_transcription_completed',
      domain: 'ChatRecorderController',
      subDomain: 'transcribe',
    );
    return buffer.toString();
  }

  // Normalize dBFS history to 0.05..1.0 range for UI
  List<double> getNormalizedAmplitudeHistory() {
    return state.amplitudeHistory.map((dBFS) {
      if (dBFS <= -80) return 0.05;
      if (dBFS >= -10) return 1.0;
      final normalized = (dBFS + 80) / 70; // -80..-10 -> 0..1
      final scaled = normalized * 0.95 + 0.05;
      return scaled.clamp(0.05, 1.0);
    }).toList();
  }

  Future<void> _cleanupInternal() async {
    try {
      await _ampSub?.cancel();
      _ampSub = null;
    } catch (_) {}
    try {
      await _recorder?.dispose();
    } catch (_) {}
    _recorder = null;
    _maxTimer?.cancel();
    _maxTimer = null;
    try {
      if (_filePath != null) {
        final f = File(_filePath!);
        // ignore: avoid_slow_async_io
        final exists = await f.exists();
        if (exists) {
          await f.delete().timeout(
                const Duration(seconds: _fileDeleteTimeoutSeconds),
              );
        }
      }
    } catch (e) {
      // Surface cleanup errors in a non-intrusive way
      state = state.copyWith(
        error: 'Cleanup failed: $e',
        errorType: ChatRecorderErrorType.cleanupFailed,
      );
    }
    try {
      if (_tempDir != null) {
        // ignore: avoid_slow_async_io
        final exists = await _tempDir!.exists();
        if (exists) {
          await _tempDir!
              .delete(recursive: true)
              .timeout(const Duration(seconds: _cleanupTimeoutSeconds));
        }
      }
    } catch (_) {}
    _tempDir = null;
    _filePath = null;
    // Keep amplitude history so UI shows a bit of trailing bars until next start
  }

  void clearResult() {
    if (state.transcript != null || state.error != null) {
      state = ChatRecorderState(
        status: state.status,
        amplitudeHistory: state.amplitudeHistory,
      );
    }
  }

  @override
  void dispose() {
    // Best-effort async cleanup, don't await in dispose
    unawaited(_cleanupInternal());
    super.dispose();
  }
}

final AutoDisposeStateNotifierProvider<ChatRecorderController,
        ChatRecorderState> chatRecorderControllerProvider =
    StateNotifierProvider.autoDispose<ChatRecorderController,
        ChatRecorderState>((ref) {
  return ChatRecorderController(ref);
});

class ChatRecorderConfig {
  const ChatRecorderConfig({
    this.sampleRate = 48000,
    this.maxSeconds = 120,
    this.amplitudeIntervalMs = 100,
  });

  final int sampleRate;
  final int maxSeconds;
  final int amplitudeIntervalMs;
}
