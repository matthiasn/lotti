import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai_chat/services/audio_transcription_service.dart';
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
        _transcriptionService = ref.read(audioTranscriptionServiceProvider),
        super(const ChatRecorderState.initial());

  final Ref ref;
  final record.AudioRecorder Function() _recorderFactory;
  final int Function() _nowMillisProvider;
  final Future<Directory> Function() _tempDirectoryProvider;
  final ChatRecorderConfig _config;
  final AudioTranscriptionService _transcriptionService;

  record.AudioRecorder? _recorder;
  StreamSubscription<record.Amplitude>? _ampSub;
  Timer? _maxTimer;
  Directory? _tempDir;
  String? _filePath;
  bool _isStarting = false;
  int _operationId = 0; // Incremented for each new operation to prevent races

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

      // Increment operation ID for this recording session
      final currentOpId = ++_operationId;

      // Set recording status immediately after successful start
      state = state.copyWith(
        status: ChatRecorderStatus.recording,
        amplitudeHistory: [], // Clear old history
      );

      // Amplitude stream (throttled)
      _ampSub = recorder
          .onAmplitudeChanged(
              Duration(milliseconds: _config.amplitudeIntervalMs))
          .listen((event) {
        // Check if this operation is still current
        if (currentOpId != _operationId) return;

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
        // Check if this operation is still current
        if (currentOpId == _operationId) {
          unawaited(stopAndTranscribe());
        }
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

    // Capture current operation ID
    final currentOpId = _operationId;

    state = state.copyWith(status: ChatRecorderStatus.processing);
    _maxTimer?.cancel();

    try {
      await _ampSub?.cancel();
      await _recorder!.stop();
    } catch (e, s) {
      getIt<LoggingService>().captureException(
        e,
        stackTrace: s,
        domain: 'ChatRecorderController',
        subDomain: 'stopAndTranscribe.stop',
      );
    }

    final filePath = _filePath;
    if (filePath == null) {
      await _cleanupInternal();
      // Only update state if this operation is still current
      if (currentOpId == _operationId) {
        state = state.copyWith(
          status: ChatRecorderStatus.idle,
          error: 'No audio file available',
          errorType: ChatRecorderErrorType.noAudioFile,
        );
      }
      return;
    }

    try {
      final transcript = await _transcribe(filePath);
      // Only update state if this operation is still current
      if (currentOpId == _operationId) {
        state = state.copyWith(
            status: ChatRecorderStatus.idle, transcript: transcript);
      }
    } catch (e) {
      // Only update state if this operation is still current
      if (currentOpId == _operationId) {
        state = state.copyWith(
          status: ChatRecorderStatus.idle,
          error: 'Transcription failed: $e',
          errorType: ChatRecorderErrorType.transcriptionFailed,
        );
      }
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

    // Invalidate current operation to prevent any in-flight async work from updating state
    _operationId++;

    _maxTimer?.cancel();
    try {
      await _ampSub?.cancel();
    } catch (e, s) {
      getIt<LoggingService>().captureException(
        e,
        stackTrace: s,
        domain: 'ChatRecorderController',
        subDomain: 'cancel.ampSub',
      );
    }
    try {
      await _recorder?.stop();
    } catch (e, s) {
      getIt<LoggingService>().captureException(
        e,
        stackTrace: s,
        domain: 'ChatRecorderController',
        subDomain: 'cancel.recorder',
      );
    }
    await _cleanupInternal();
    state = state.copyWith(status: ChatRecorderStatus.idle);
  }

  // Always Gemini Flash for v1 per requirements
  Future<String> _transcribe(String filePath) async {
    final result = await _transcriptionService.transcribe(filePath);
    getIt<LoggingService>().captureEvent(
      'chat_transcription_completed',
      domain: 'ChatRecorderController',
      subDomain: 'transcribe',
    );
    return result;
  }

  // Normalize dBFS history to 0.05..1.0 range for UI
  List<double> getNormalizedAmplitudeHistory() {
    const minDBFS = -80;
    const maxDBFS = -10;
    const rangeDBFS = maxDBFS - minDBFS; // 70
    const minNormalized = 0.05;
    const maxNormalized = 1;
    const rangeNormalized = maxNormalized - minNormalized; // 0.95

    return state.amplitudeHistory.map((dBFS) {
      if (dBFS <= minDBFS) return minNormalized; // double
      if (dBFS >= maxDBFS) return maxNormalized.toDouble();
      final normalized = (dBFS - minDBFS) / rangeDBFS; // -80..-10 -> 0..1
      final scaled = normalized * rangeNormalized + minNormalized;
      return scaled.clamp(minNormalized, maxNormalized).toDouble();
    }).toList();
  }

  Future<void> _cleanupInternal() async {
    try {
      await _ampSub?.cancel();
      _ampSub = null;
    } catch (e, s) {
      getIt<LoggingService>().captureException(
        e,
        stackTrace: s,
        domain: 'ChatRecorderController',
        subDomain: 'cleanup.ampSub',
      );
    }
    try {
      await _recorder?.dispose();
    } catch (e, s) {
      getIt<LoggingService>().captureException(
        e,
        stackTrace: s,
        domain: 'ChatRecorderController',
        subDomain: 'cleanup.recorder',
      );
    }
    _recorder = null;
    _maxTimer?.cancel();
    _maxTimer = null;
    try {
      if (_filePath != null) {
        final f = File(_filePath!);
        try {
          await f.delete().timeout(
                const Duration(seconds: _fileDeleteTimeoutSeconds),
              );
        } on PathNotFoundException {
          // File doesn't exist, nothing to delete
        }
      }
    } catch (e) {
      // Log cleanup errors instead of surfacing to user state
      getIt<LoggingService>().captureException(
        e,
        domain: 'ChatRecorderController',
        subDomain: 'cleanup',
      );
    }
    try {
      if (_tempDir != null) {
        try {
          await _tempDir!
              .delete(recursive: true)
              .timeout(const Duration(seconds: _cleanupTimeoutSeconds));
        } on PathNotFoundException {
          // Directory doesn't exist, nothing to delete
        }
      }
    } catch (e, s) {
      getIt<LoggingService>().captureException(
        e,
        stackTrace: s,
        domain: 'ChatRecorderController',
        subDomain: 'cleanup.tempDir',
      );
    }
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
