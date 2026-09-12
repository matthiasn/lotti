// ignore_for_file: specify_nonobvious_property_types

import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/ui/chat/chat_amplitude_history.dart';
import 'package:lotti/features/agents/ui/chat/chat_recorder_state.dart';
import 'package:lotti/features/agents/util/inference_provider_resolver.dart';
import 'package:lotti/features/ai/repository/transcription_exception.dart';
import 'package:lotti/features/ai/services/audio_transcription_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart' as record;

export 'package:lotti/features/agents/ui/chat/chat_recorder_state.dart';

/// Resolves an explicit transcription route immediately before submission.
/// A failing resolver never falls back to automatic model discovery.
typedef ChatTranscriptionTargetResolver =
    Future<ResolvedInferenceProvider> Function();

/// Drives the shared AI voice-input recorder — record to a temp `.m4a` file,
/// then batch-transcribe — exposing a single [ChatRecorderState] to the UI.
///
/// Race model: every recording session captures a monotonically increasing
/// `_operationId` before its first startup await (see [start]). Async callbacks (amplitude
/// ticks, transcription deltas, the safety timer) only mutate state while their
/// captured id still equals `_operationId`. [cancel] bumps the id to orphan any
/// in-flight work, so a stale callback from an aborted session can never write
/// over the next one. Every state mutation also checks `ref.mounted` because
/// the provider is `autoDispose`.
///
/// Constructor parameters are injection seams for tests (recorder factory,
/// clock, temp-dir provider, transcription services); production reads the real
/// services from Riverpod in [build].
class ChatRecorderController extends Notifier<ChatRecorderState> {
  ChatRecorderController({
    record.AudioRecorder Function()? recorderFactory,
    int Function()? nowMillisProvider,
    Future<Directory> Function()? tempDirectoryProvider,
    ChatRecorderConfig? config,
    AudioTranscriptionService? transcriptionService,
  }) : _recorderFactory = recorderFactory ?? record.AudioRecorder.new,
       _nowMillisProvider =
           nowMillisProvider ?? (() => DateTime.now().millisecondsSinceEpoch),
       _tempDirectoryProvider =
           tempDirectoryProvider ?? (() async => getTemporaryDirectory()),
       _config = config ?? const ChatRecorderConfig(),
       _transcriptionServiceOverride = transcriptionService;

  final record.AudioRecorder Function() _recorderFactory;
  final int Function() _nowMillisProvider;
  final Future<Directory> Function() _tempDirectoryProvider;
  final ChatRecorderConfig _config;
  final AudioTranscriptionService? _transcriptionServiceOverride;
  late final AudioTranscriptionService _transcriptionService;

  @override
  ChatRecorderState build() {
    _transcriptionService =
        _transcriptionServiceOverride ??
        ref.read(audioTranscriptionServiceProvider);

    // Riverpod dispose callbacks are synchronous, so start the idempotent
    // asynchronous cleanup and let callers that need determinism await
    // [dispose] explicitly.
    ref.onDispose(() => unawaited(dispose()));

    return const ChatRecorderState.initial();
  }

  record.AudioRecorder? _recorder;
  StreamSubscription<record.Amplitude>? _ampSub;
  Timer? _maxTimer;
  Directory? _tempDir;
  String? _filePath;
  bool _isStarting = false;
  Future<void>? _startFuture;
  ChatTranscriptionTargetResolver? _resolveTranscriptionTarget;
  int _operationId = 0; // Incremented for each new operation to prevent races
  Future<void>? _disposeFuture;
  Future<void>? _cleanupFuture;
  Future<void>? _cancelFuture;

  static const int _cleanupTimeoutSeconds = 2;
  static const int _fileDeleteTimeoutSeconds = 2;

  /// Releases recorder resources and temporary files exactly once.
  Future<void> dispose() => _disposeFuture ??= _disposeResources();

  Future<void> _disposeResources() async {
    _operationId++;
    await _startFuture;
    if (_cleanupFuture case final cleanup?) {
      await cleanup;
      return;
    }
    _maxTimer?.cancel();
    final ampSub = _ampSub;
    final recorder = _recorder;
    final filePath = _filePath;
    final tempDir = _tempDir;
    _ampSub = null;
    _recorder = null;
    _filePath = null;
    _tempDir = null;
    _maxTimer = null;

    try {
      await ampSub?.cancel();
    } catch (_) {}
    try {
      await recorder?.dispose();
    } catch (_) {}
    try {
      if (filePath != null) {
        await File(filePath).delete();
      }
    } catch (_) {}
    await _deleteDirectoryQuietly(tempDir);
  }

  Future<void> _deleteDirectoryQuietly(Directory? directory) async {
    try {
      await directory?.delete(recursive: true);
    } catch (_) {}
  }

  /// Begins a batch recording: checks mic permission, records to a temp `.m4a`
  /// file, streams throttled amplitude into [ChatRecorderState.amplitudeHistory],
  /// and arms a [ChatRecorderConfig.maxSeconds] safety timer that auto-calls
  /// [stopAndTranscribe]. No-op unless idle; records an error message if a
  /// start is already in flight. On any failure the partial recording is
  /// cleaned up. An optional [resolveTranscriptionTarget] belongs to this
  /// recording and resolves the caller's current route when recording stops.
  /// Startup retains local resources until all awaits pass the operation gate;
  /// cancellation/disposal wait for an abandoned startup to release them.
  Future<void> start({
    ChatTranscriptionTargetResolver? resolveTranscriptionTarget,
  }) async {
    if (!ref.mounted ||
        _disposeFuture != null ||
        _cleanupFuture != null ||
        _cancelFuture != null) {
      return;
    }
    if (_isStarting) {
      state = state.copyWith(
        error: 'Another operation is in progress',
        errorKind: ChatRecorderErrorKind.busy,
      );
      return;
    }
    if (state.status != ChatRecorderStatus.idle) return;

    _isStarting = true;
    final started = Completer<void>();
    _startFuture = started.future;
    final currentOpId = ++_operationId;
    final recorder = _recorderFactory();
    Directory? tempDir;
    var nativeStartAttempted = false;
    var transferred = false;
    try {
      final hasPerm = await recorder.hasPermission();
      if (!ref.mounted || currentOpId != _operationId) return;
      if (!hasPerm) {
        state = state.copyWith(
          error: 'Microphone permission denied. Please enable it in Settings.',
          errorKind: ChatRecorderErrorKind.permissionDenied,
        );
        return;
      }

      // Use app-scoped temporary directory for better privacy
      final baseTemp = await _tempDirectoryProvider();
      if (!ref.mounted || currentOpId != _operationId) return;
      tempDir = await Directory(
        '${baseTemp.path}/lotti_chat_rec',
      ).create(recursive: true);
      if (!ref.mounted || currentOpId != _operationId) return;
      final fileName = 'chat_${_nowMillisProvider()}.m4a';
      final filePath = '${tempDir.path}/$fileName';

      nativeStartAttempted = true;
      await recorder.start(
        record.RecordConfig(
          sampleRate: _config.sampleRate,
          autoGain: true,
        ),
        path: filePath,
      );
      if (!ref.mounted || currentOpId != _operationId) return;

      _recorder = recorder;
      _tempDir = tempDir;
      _filePath = filePath;
      _resolveTranscriptionTarget = resolveTranscriptionTarget;
      transferred = true;

      final startedAt = _nowMillisProvider();

      // Set recording status immediately after successful start
      state = state.copyWith(
        status: ChatRecorderStatus.recording,
        elapsed: Duration.zero,
        amplitudeHistory: [], // Clear old history
      );

      // Amplitude stream (throttled)
      _ampSub = recorder
          .onAmplitudeChanged(
            Duration(milliseconds: _config.amplitudeIntervalMs),
          )
          .listen((event) {
            // Check if this operation is still current and ref is still valid
            if (currentOpId != _operationId) return;
            if (!ref.mounted) return;

            final dBFS = event.current;
            state = state.copyWith(
              status: ChatRecorderStatus.recording,
              elapsed: Duration(
                milliseconds: (_nowMillisProvider() - startedAt).clamp(
                  0,
                  _config.maxSeconds * 1000,
                ),
              ),
              amplitudeHistory: appendAmplitudeSample(
                state.amplitudeHistory,
                dBFS,
              ),
            );
          });

      // Safety stop after configured max duration
      _maxTimer?.cancel();
      _maxTimer = Timer(Duration(seconds: _config.maxSeconds), () {
        // Check if this operation is still current and ref is valid
        if (currentOpId == _operationId && ref.mounted) {
          unawaited(stopAndTranscribe());
        }
      });

      // Log start
      getIt<DomainLogger>().log(
        LogDomain.chat,
        'chat_recording_started',
        subDomain: 'start',
      );
    } catch (e) {
      if (ref.mounted && currentOpId == _operationId) {
        state = state.copyWith(
          error: 'Failed to start recording: $e',
          errorKind: ChatRecorderErrorKind.startFailed,
        );
      }
      if (transferred && currentOpId == _operationId) {
        await _cleanupInternal();
      }
    } finally {
      if (!transferred) {
        if (nativeStartAttempted) {
          try {
            await recorder.stop();
          } catch (_) {}
        }
        try {
          await recorder.dispose();
        } catch (_) {}
        await _deleteDirectoryQuietly(tempDir);
      }
      _isStarting = false;
      _startFuture = null;
      started.complete();
    }
  }

  /// Stops and transcribes this recording, keeping its recorder, path and
  /// route bound to the captured operation. Cleanup finishes before publishing
  /// idle; a cancelled operation never cleans up a later recording's resources.
  Future<void> stopAndTranscribe() async {
    if (!ref.mounted || state.status != ChatRecorderStatus.recording) return;
    final recorder = _recorder;
    if (recorder == null) return;
    final currentOpId = _operationId;
    final filePath = _filePath;
    final resolveTarget = _resolveTranscriptionTarget;
    final ampSub = _ampSub;
    ChatRecorderState? completed;

    state = state.copyWith(status: ChatRecorderStatus.processing);
    _maxTimer?.cancel();
    try {
      try {
        await ampSub?.cancel();
        if (!ref.mounted || currentOpId != _operationId) return;
        await recorder.stop();
      } catch (e, s) {
        getIt<DomainLogger>().error(
          LogDomain.chat,
          e,
          stackTrace: s,
          subDomain: 'stopAndTranscribe.stop',
        );
      }
      if (!ref.mounted || currentOpId != _operationId) return;
      if (filePath == null) {
        completed = state.copyWith(
          status: ChatRecorderStatus.idle,
          error: 'No audio file available',
          errorKind: ChatRecorderErrorKind.noAudioFile,
        );
        return;
      }
      final transcript = await _transcribe(
        filePath,
        currentOpId,
        resolveTarget,
      );
      if (currentOpId == _operationId && ref.mounted) {
        completed = state.copyWith(
          status: ChatRecorderStatus.idle,
          transcript: transcript,
        );
      }
    } catch (e, stackTrace) {
      if (currentOpId != _operationId || !ref.mounted) return;
      getIt<DomainLogger>().error(
        LogDomain.chat,
        e,
        stackTrace: stackTrace,
        subDomain: 'stopAndTranscribe.transcription',
        message: 'Voice transcription failed',
      );
      completed = state.copyWith(
        status: ChatRecorderStatus.idle,
        error: switch (e) {
          TranscriptionException(:final message) => message,
          _ => e.toString(),
        },
        errorKind: e.toString().contains('No audio-capable models')
            ? ChatRecorderErrorKind.noAudioModel
            : ChatRecorderErrorKind.transcriptionFailed,
      );
    } finally {
      if (currentOpId == _operationId) {
        await _cleanupInternal();
        if (currentOpId == _operationId && ref.mounted && completed != null) {
          state = completed;
        }
      }
    }
  }

  /// Cancels the current operation and joins any cancellation already running.
  /// Idle is published only after its resources have been released.
  Future<void> cancel() => _cancelFuture ??= _cancelCurrent().whenComplete(() {
    _cancelFuture = null;
  });

  Future<void> _cancelCurrent() async {
    if (!ref.mounted) return;
    if (!_isStarting &&
        state.status != ChatRecorderStatus.recording &&
        state.status != ChatRecorderStatus.processing) {
      return;
    }

    // Invalidate current operation to prevent any in-flight async work from updating state
    final cancelledOpId = ++_operationId;
    await _startFuture;
    final recorder = _recorder;

    _maxTimer?.cancel();
    try {
      await _ampSub?.cancel();
    } catch (e, s) {
      getIt<DomainLogger>().error(
        LogDomain.chat,
        e,
        stackTrace: s,
        subDomain: 'cancel.ampSub',
      );
    }

    try {
      await recorder?.stop();
    } catch (e, s) {
      getIt<DomainLogger>().error(
        LogDomain.chat,
        e,
        stackTrace: s,
        subDomain: 'cancel.recorder',
      );
    }

    await _cleanupInternal();
    if (ref.mounted && cancelledOpId == _operationId) {
      state = state.copyWith(status: ChatRecorderStatus.idle);
    }
  }

  // Transcribes audio with streaming updates to partialTranscript
  Future<String> _transcribe(
    String filePath,
    int operationId,
    ChatTranscriptionTargetResolver? resolveTarget,
  ) async {
    final buffer = StringBuffer();
    var chunkCount = 0;

    final target = resolveTarget == null ? null : await resolveTarget();
    if (!ref.mounted || operationId != _operationId) return '';
    final stream = target == null
        ? _transcriptionService.transcribeStream(filePath)
        : _transcriptionService.transcribeStream(filePath, target: target);
    await for (final chunk in stream) {
      chunkCount++;
      buffer.write(chunk);

      getIt<DomainLogger>().log(
        LogDomain.chat,
        'chat_transcription_chunk_received: chunk=$chunkCount, '
        'chunkLen=${chunk.length}, totalLen=${buffer.length}',
        subDomain: 'transcribe',
      );

      // Update partialTranscript for progressive UI feedback
      // Only if this operation is still current and ref is valid
      if (operationId == _operationId && ref.mounted) {
        state = state.copyWith(
          status: ChatRecorderStatus.processing,
          partialTranscript: buffer.toString(),
        );
      }
    }

    getIt<DomainLogger>().log(
      LogDomain.chat,
      'chat_transcription_completed: totalChunks=$chunkCount, '
      'totalLen=${buffer.length}',
      subDomain: 'transcribe',
    );
    return buffer.toString();
  }

  /// Maps the raw dBFS [ChatRecorderState.amplitudeHistory] to the 0.05..1.0
  /// bar heights the waveform widget expects. See `chat_amplitude_history.dart`.
  List<double> getNormalizedAmplitudeHistory() =>
      normalizeAmplitudeHistory(state.amplitudeHistory);

  Future<void> _cleanupInternal() =>
      _cleanupFuture ??= _cleanupResources().whenComplete(() {
        _cleanupFuture = null;
      });

  Future<void> _cleanupResources() async {
    final ampSub = _ampSub;
    final recorder = _recorder;
    final filePath = _filePath;
    final tempDir = _tempDir;
    _ampSub = null;
    _recorder = null;
    _filePath = null;
    _tempDir = null;
    _maxTimer?.cancel();
    _maxTimer = null;
    try {
      await ampSub?.cancel();
    } catch (e, s) {
      getIt<DomainLogger>().error(
        LogDomain.chat,
        e,
        stackTrace: s,
        subDomain: 'cleanup.ampSub',
      );
    }
    try {
      await recorder?.dispose();
    } catch (e, s) {
      getIt<DomainLogger>().error(
        LogDomain.chat,
        e,
        stackTrace: s,
        subDomain: 'cleanup.recorder',
      );
    }
    try {
      if (filePath != null) {
        final f = File(filePath);
        try {
          await f.delete().timeout(
            const Duration(seconds: _fileDeleteTimeoutSeconds),
          );
        } on PathNotFoundException catch (e, s) {
          // Log and continue; file already gone
          getIt<DomainLogger>().error(
            LogDomain.chat,
            e,
            stackTrace: s,
            subDomain: 'cleanup.fileNotFound',
          );
        }
      }
    } catch (e) {
      // Log cleanup errors instead of surfacing to user state
      getIt<DomainLogger>().error(
        LogDomain.chat,
        e,
        subDomain: 'cleanup',
      );
    }
    try {
      if (tempDir != null) {
        try {
          await tempDir
              .delete(recursive: true)
              .timeout(const Duration(seconds: _cleanupTimeoutSeconds));
        } on PathNotFoundException catch (e, s) {
          // Log and continue; directory already gone
          getIt<DomainLogger>().error(
            LogDomain.chat,
            e,
            stackTrace: s,
            subDomain: 'cleanup.tempDirNotFound',
          );
        }
      }
    } catch (e, s) {
      getIt<DomainLogger>().error(
        LogDomain.chat,
        e,
        stackTrace: s,
        subDomain: 'cleanup.tempDir',
      );
    }
    // Keep amplitude history so UI shows a bit of trailing bars until next start
  }

  /// Clears a consumed [ChatRecorderState.transcript] / [ChatRecorderState.error]
  /// while keeping the current status and amplitude history. Called by
  /// `InputArea` after it has read a finished transcript so the same value is
  /// not re-consumed on the next rebuild.
  void clearResult() {
    if (!ref.mounted) return;
    if (state.transcript != null || state.error != null) {
      state = ChatRecorderState(
        status: state.status,
        amplitudeHistory: state.amplitudeHistory,
      );
    }
  }
}

/// App-wide recorder for the chat input mic. `autoDispose` so the recorder,
/// subscriptions, and temp files are torn down when the chat modal closes (see
/// the `ref.onDispose` chain in [ChatRecorderController.build]).
final chatRecorderControllerProvider =
    NotifierProvider.autoDispose<ChatRecorderController, ChatRecorderState>(
      ChatRecorderController.new,
    );
