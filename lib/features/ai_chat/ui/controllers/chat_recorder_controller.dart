// ignore_for_file: specify_nonobvious_property_types

import 'dart:async';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai_chat/services/audio_transcription_service.dart';
import 'package:lotti/features/ai_chat/services/realtime_transcription_service.dart';
import 'package:lotti/features/ai_chat/ui/controllers/chat_recorder_state.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart' as record;

export 'package:lotti/features/ai_chat/ui/controllers/chat_recorder_state.dart';

part 'chat_recorder_controller_realtime.dart';

class ChatRecorderController extends Notifier<ChatRecorderState>
    with _ChatRecorderRealtime {
  ChatRecorderController({
    record.AudioRecorder Function()? recorderFactory,
    int Function()? nowMillisProvider,
    Future<Directory> Function()? tempDirectoryProvider,
    ChatRecorderConfig? config,
    AudioTranscriptionService? transcriptionService,
    RealtimeTranscriptionService? realtimeTranscriptionService,
  }) : _recorderFactory = recorderFactory ?? record.AudioRecorder.new,
       _nowMillisProvider =
           nowMillisProvider ?? (() => DateTime.now().millisecondsSinceEpoch),
       _tempDirectoryProvider =
           tempDirectoryProvider ?? (() async => getTemporaryDirectory()),
       _config = config ?? const ChatRecorderConfig(),
       _transcriptionServiceOverride = transcriptionService,
       _realtimeServiceOverride = realtimeTranscriptionService;

  @override
  final record.AudioRecorder Function() _recorderFactory;
  @override
  final int Function() _nowMillisProvider;
  @override
  final Future<Directory> Function() _tempDirectoryProvider;
  @override
  final ChatRecorderConfig _config;
  final AudioTranscriptionService? _transcriptionServiceOverride;
  final RealtimeTranscriptionService? _realtimeServiceOverride;
  late final AudioTranscriptionService _transcriptionService;
  @override
  late final RealtimeTranscriptionService _realtimeService;
  _AppLifecycleObserver? _lifecycleObserver;

  @override
  ChatRecorderState build() {
    _transcriptionService =
        _transcriptionServiceOverride ??
        ref.read(audioTranscriptionServiceProvider);
    _realtimeService =
        _realtimeServiceOverride ??
        ref.read(realtimeTranscriptionServiceProvider);

    // Register lifecycle observer for backgrounding during realtime recording.
    // Guard against duplicate registration if build() is called again.
    if (_lifecycleObserver != null) {
      WidgetsBinding.instance.removeObserver(_lifecycleObserver!);
    }
    final observer = _AppLifecycleObserver(onPaused: _onAppPaused);
    _lifecycleObserver = observer;
    WidgetsBinding.instance.addObserver(observer);

    // Clean up resources when the provider is disposed
    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(observer);
      _lifecycleObserver = null;
      _maxTimer?.cancel();
      // Capture references before async cleanup
      final ampSub = _ampSub;
      final realtimeAmpSub = _realtimeAmpSub;
      final recorder = _recorder;
      final filePath = _filePath;
      final tempDir = _tempDir;

      // Chain cleanup operations sequentially to avoid race conditions
      Future<void> cleanup() async {
        try {
          await ampSub?.cancel();
        } catch (_) {}
        try {
          await realtimeAmpSub?.cancel();
        } catch (_) {}
        try {
          await recorder?.dispose();
        } catch (_) {}
        try {
          if (filePath != null) {
            await File(filePath).delete();
          }
        } catch (_) {}
        try {
          if (tempDir != null) {
            await tempDir.delete(recursive: true);
          }
        } catch (_) {}
      }

      // Deliberately not awaited — onDispose callbacks are synchronous. The
      // future is stored so tests can await the full chain deterministically.
      disposeCleanupFuture = cleanup();
    });

    return const ChatRecorderState.initial();
  }

  /// Completes when the `ref.onDispose` cleanup chain (subscription cancels,
  /// recorder dispose, file/temp-dir deletion) has finished. Only set once the
  /// provider has been disposed; exposed so tests can await the otherwise
  /// unawaited teardown instead of polling the event queue.
  @visibleForTesting
  Future<void>? disposeCleanupFuture;

  @override
  record.AudioRecorder? _recorder;
  StreamSubscription<record.Amplitude>? _ampSub;
  @override
  StreamSubscription<double>? _realtimeAmpSub;
  @override
  Timer? _maxTimer;
  @override
  Directory? _tempDir;
  String? _filePath;
  @override
  bool _isStarting = false;
  @override
  int _operationId = 0; // Incremented for each new operation to prevent races

  static const int _cleanupTimeoutSeconds = 2;
  static const int _fileDeleteTimeoutSeconds = 2;

  Future<void> start() async {
    if (!ref.mounted) return;
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
      if (!ref.mounted) {
        await recorder.dispose();
        return;
      }
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
      if (!ref.mounted) {
        await recorder.dispose();
        return;
      }
      _tempDir = await Directory(
        '${baseTemp.path}/lotti_chat_rec',
      ).create(recursive: true);
      if (!ref.mounted) {
        await recorder.dispose();
        return;
      }
      final fileName = 'chat_${_nowMillisProvider()}.m4a';
      _filePath = '${_tempDir!.path}/$fileName';

      await recorder.start(
        record.RecordConfig(
          sampleRate: _config.sampleRate,
          autoGain: true,
        ),
        path: _filePath!,
      );
      if (!ref.mounted) {
        await recorder.stop();
        await recorder.dispose();
        return;
      }

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
            Duration(milliseconds: _config.amplitudeIntervalMs),
          )
          .listen((event) {
            // Check if this operation is still current and ref is still valid
            if (currentOpId != _operationId) return;
            if (!ref.mounted) return;

            final dBFS = event.current;
            final history = List<double>.from(state.amplitudeHistory)
              ..add(dBFS);
            if (history.length > _historyMax) history.removeAt(0);
            state = state.copyWith(
              status: ChatRecorderStatus.recording,
              amplitudeHistory: history,
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
      if (ref.mounted) {
        state = state.copyWith(
          error: 'Failed to start recording: $e',
          errorType: ChatRecorderErrorType.startFailed,
        );
      }
      await _cleanupInternal();
    } finally {
      _isStarting = false;
    }
  }

  Future<void> stopAndTranscribe() async {
    if (!ref.mounted) return;
    if (_recorder == null) return;

    // Capture current operation ID
    final currentOpId = _operationId;

    state = state.copyWith(status: ChatRecorderStatus.processing);
    _maxTimer?.cancel();

    try {
      await _ampSub?.cancel();
      await _recorder!.stop();
    } catch (e, s) {
      getIt<DomainLogger>().error(
        LogDomain.chat,
        e,
        stackTrace: s,
        subDomain: 'stopAndTranscribe.stop',
      );
    }

    final filePath = _filePath;
    if (filePath == null) {
      await _cleanupInternal();
      // Only update state if this operation is still current and ref is valid
      if (currentOpId == _operationId && ref.mounted) {
        state = state.copyWith(
          status: ChatRecorderStatus.idle,
          error: 'No audio file available',
          errorType: ChatRecorderErrorType.noAudioFile,
        );
      }
      return;
    }

    try {
      final transcript = await _transcribe(filePath, currentOpId);
      // Only update state if this operation is still current and ref is valid
      if (currentOpId == _operationId && ref.mounted) {
        // partialTranscript cleared automatically (defaults to null)
        state = state.copyWith(
          status: ChatRecorderStatus.idle,
          transcript: transcript,
        );
      }
    } catch (e) {
      // Only update state if this operation is still current and ref is valid
      if (currentOpId == _operationId && ref.mounted) {
        // partialTranscript cleared automatically (defaults to null)
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
    if (!ref.mounted) return;
    if (state.status != ChatRecorderStatus.recording &&
        state.status != ChatRecorderStatus.realtimeRecording &&
        state.status != ChatRecorderStatus.processing) {
      return;
    }

    final wasRealtime = state.status == ChatRecorderStatus.realtimeRecording;

    // Invalidate current operation to prevent any in-flight async work from updating state
    _operationId++;

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

    if (wasRealtime) {
      // Cancel realtime-specific subscriptions
      try {
        await _realtimeAmpSub?.cancel();
        _realtimeAmpSub = null;
      } catch (e, s) {
        getIt<DomainLogger>().error(
          LogDomain.chat,
          e,
          stackTrace: s,
          subDomain: 'cancel.realtimeAmpSub',
        );
      }
    }

    try {
      await _recorder?.stop();
    } catch (e, s) {
      getIt<DomainLogger>().error(
        LogDomain.chat,
        e,
        stackTrace: s,
        subDomain: 'cancel.recorder',
      );
    }

    if (wasRealtime) {
      // Discard: tear down WebSocket and PCM stream without saving audio
      await _realtimeService.dispose();
    }

    await _cleanupInternal();
    if (ref.mounted) {
      state = state.copyWith(status: ChatRecorderStatus.idle);
    }
  }

  /// Starts a real-time transcription session using the Mistral WebSocket API.
  ///
  /// The recorder streams PCM audio to the service, which forwards it to the
  /// WebSocket. Transcription deltas update `partialTranscript` live.

  void _onAppPaused() {
    if (state.status == ChatRecorderStatus.realtimeRecording) {
      unawaited(stopRealtime());
    }
  }

  // Transcribes audio with streaming updates to partialTranscript
  Future<String> _transcribe(String filePath, int operationId) async {
    final buffer = StringBuffer();
    var chunkCount = 0;

    await for (final chunk in _transcriptionService.transcribeStream(
      filePath,
    )) {
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

  @override
  Future<void> _cleanupInternal() async {
    try {
      await _ampSub?.cancel();
      _ampSub = null;
    } catch (e, s) {
      getIt<DomainLogger>().error(
        LogDomain.chat,
        e,
        stackTrace: s,
        subDomain: 'cleanup.ampSub',
      );
    }
    try {
      await _recorder?.dispose();
    } catch (e, s) {
      getIt<DomainLogger>().error(
        LogDomain.chat,
        e,
        stackTrace: s,
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
      if (_tempDir != null) {
        try {
          await _tempDir!
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
    _tempDir = null;
    _filePath = null;
    // Keep amplitude history so UI shows a bit of trailing bars until next start
  }

  void clearResult() {
    if (!ref.mounted) return;
    if (state.transcript != null || state.error != null) {
      state = ChatRecorderState(
        status: state.status,
        amplitudeHistory: state.amplitudeHistory,
        useRealtimeMode: state.useRealtimeMode,
      );
    }
  }
}

final chatRecorderControllerProvider =
    NotifierProvider.autoDispose<ChatRecorderController, ChatRecorderState>(
      ChatRecorderController.new,
    );

/// Only triggers on [AppLifecycleState.paused] (actual backgrounding), not on
/// [AppLifecycleState.inactive], which fires for transient events like
/// notification center pulls or incoming calls on iOS.
class _AppLifecycleObserver extends WidgetsBindingObserver {
  _AppLifecycleObserver({required this.onPaused});

  final VoidCallback onPaused;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      onPaused();
    }
  }
}
