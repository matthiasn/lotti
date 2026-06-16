// ignore_for_file: specify_nonobvious_property_types

import 'dart:async';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai_chat/services/audio_transcription_service.dart';
import 'package:lotti/features/ai_chat/services/realtime_transcription_service.dart';
import 'package:lotti/features/ai_chat/ui/controllers/chat_amplitude_history.dart';
import 'package:lotti/features/ai_chat/ui/controllers/chat_recorder_state.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart' as record;

export 'package:lotti/features/ai_chat/ui/controllers/chat_recorder_state.dart';

/// Drives the chat-input voice recorder across both the batch
/// (record-to-file then transcribe) and realtime (streaming WebSocket) paths,
/// exposing a single [ChatRecorderState] to the UI.
///
/// Race model: every recording session captures a monotonically increasing
/// `_operationId` (see [start]/[startRealtime]). Async callbacks (amplitude
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
    RealtimeTranscriptionService? realtimeTranscriptionService,
  }) : _recorderFactory = recorderFactory ?? record.AudioRecorder.new,
       _nowMillisProvider =
           nowMillisProvider ?? (() => DateTime.now().millisecondsSinceEpoch),
       _tempDirectoryProvider =
           tempDirectoryProvider ?? (() async => getTemporaryDirectory()),
       _config = config ?? const ChatRecorderConfig(),
       _transcriptionServiceOverride = transcriptionService,
       _realtimeServiceOverride = realtimeTranscriptionService;

  final record.AudioRecorder Function() _recorderFactory;
  final int Function() _nowMillisProvider;
  final Future<Directory> Function() _tempDirectoryProvider;
  final ChatRecorderConfig _config;
  final AudioTranscriptionService? _transcriptionServiceOverride;
  final RealtimeTranscriptionService? _realtimeServiceOverride;
  late final AudioTranscriptionService _transcriptionService;
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

  record.AudioRecorder? _recorder;
  StreamSubscription<record.Amplitude>? _ampSub;
  StreamSubscription<double>? _realtimeAmpSub;
  Timer? _maxTimer;
  Directory? _tempDir;
  String? _filePath;
  bool _isStarting = false;
  int _operationId = 0; // Incremented for each new operation to prevent races

  static const int _cleanupTimeoutSeconds = 2;
  static const int _fileDeleteTimeoutSeconds = 2;

  /// Begins a batch recording: checks mic permission, records to a temp `.m4a`
  /// file, streams throttled amplitude into [ChatRecorderState.amplitudeHistory],
  /// and arms a [ChatRecorderConfig.maxSeconds] safety timer that auto-calls
  /// [stopAndTranscribe]. No-op unless idle; sets a `concurrentOperation` error
  /// if a start is already in flight. On any failure the partial recording is
  /// cleaned up.
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
            state = state.copyWith(
              status: ChatRecorderStatus.recording,
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

  /// Stops the batch recording and transcribes the captured file, streaming
  /// progress into [ChatRecorderState.partialTranscript] and landing the final
  /// text in [ChatRecorderState.transcript]. Always cleans up the recorder and
  /// temp file via `_cleanupInternal`, even on failure. No-op if no recording
  /// is active.
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

  /// Maps the raw dBFS [ChatRecorderState.amplitudeHistory] to the 0.05..1.0
  /// bar heights the waveform widget expects. See `chat_amplitude_history.dart`.
  List<double> getNormalizedAmplitudeHistory() =>
      normalizeAmplitudeHistory(state.amplitudeHistory);

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

  /// Clears a consumed [ChatRecorderState.transcript] / [ChatRecorderState.error]
  /// while keeping the current status, amplitude history, and mode. Called by
  /// `InputArea` after it has read a finished transcript so the same value is
  /// not re-consumed on the next rebuild.
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

  // ---------------------------------------------------------------
  // Realtime (streaming) transcription
  // ---------------------------------------------------------------

  /// Begins a realtime transcription session: streams 16kHz mono PCM to
  /// [RealtimeTranscriptionService], which forwards it over the WebSocket and
  /// emits live deltas. Each delta is appended to
  /// [ChatRecorderState.partialTranscript]; amplitude readings come from the
  /// service's `amplitudeStream`. Arms the same [ChatRecorderConfig.maxSeconds]
  /// safety timer (auto-calling [stopRealtime]) and is also stopped
  /// automatically when the app is backgrounded. No-op unless idle.
  Future<void> startRealtime() async {
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

      // Start PCM stream at 16kHz mono (required by Mistral realtime API)
      final pcmStream = await recorder.startStream(
        const record.RecordConfig(
          encoder: record.AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
        ),
      );

      if (!ref.mounted) {
        await recorder.stop();
        await recorder.dispose();
        return;
      }

      _recorder = recorder;

      final currentOpId = ++_operationId;

      state = state.copyWith(
        status: ChatRecorderStatus.realtimeRecording,
        amplitudeHistory: [],
      );

      // Subscribe to amplitude values from the service for waveform display
      _realtimeAmpSub = _realtimeService.amplitudeStream.listen((dbfs) {
        if (currentOpId != _operationId || !ref.mounted) return;

        state = state.copyWith(
          status: ChatRecorderStatus.realtimeRecording,
          amplitudeHistory: appendAmplitudeSample(
            state.amplitudeHistory,
            dbfs,
          ),
          partialTranscript: state.partialTranscript,
        );
      });

      // Connect WebSocket and start streaming audio.
      // The onDelta callback updates the UI with live transcript text.
      await _realtimeService.startRealtimeTranscription(
        pcmStream: pcmStream,
        onDelta: (delta) {
          if (currentOpId != _operationId || !ref.mounted) return;
          final current = state.partialTranscript ?? '';
          state = state.copyWith(
            status: ChatRecorderStatus.realtimeRecording,
            partialTranscript: '$current$delta',
          );
        },
      );

      // Safety timer — stops after configured max duration
      _maxTimer?.cancel();
      _maxTimer = Timer(Duration(seconds: _config.maxSeconds), () {
        if (currentOpId == _operationId && ref.mounted) {
          unawaited(stopRealtime());
        }
      });

      getIt<DomainLogger>().log(
        LogDomain.chat,
        'chat_realtime_recording_started',
        subDomain: 'startRealtime',
      );
    } catch (e) {
      // Cancel realtime-specific subscriptions that may have been set up
      // before the failure (e.g. amplitude subscription started before
      // startRealtimeTranscription threw).
      try {
        await _realtimeAmpSub?.cancel();
        _realtimeAmpSub = null;
      } catch (_) {}

      if (ref.mounted) {
        state = state.copyWith(
          status: ChatRecorderStatus.idle,
          error: 'Failed to start realtime recording: $e',
          errorType: ChatRecorderErrorType.startFailed,
        );
      }
      await _cleanupInternal();
    } finally {
      _isStarting = false;
    }
  }

  /// Stops a real-time transcription session and produces the final transcript.
  ///
  /// The stop sequence:
  /// 1. Cancel delta subscription
  /// 2. Cancel amplitude subscription
  /// 3. Service stops (cancels PCM stream, stops recorder, sends endAudio,
  ///    waits for `transcription.done`, writes WAV→M4A)
  /// 4. Controller disposes the recorder
  Future<void> stopRealtime() async {
    if (!ref.mounted) return;
    if (_recorder == null) return;

    final currentOpId = _operationId;

    _maxTimer?.cancel();

    try {
      await _realtimeAmpSub?.cancel();
      _realtimeAmpSub = null;
    } catch (e, s) {
      getIt<DomainLogger>().error(
        LogDomain.chat,
        e,
        stackTrace: s,
        subDomain: 'stopRealtime.cancelSubs',
      );
    }

    // Set up an output path for the audio file
    final baseTemp = await _tempDirectoryProvider();
    if (!ref.mounted) return;
    _tempDir = await Directory(
      '${baseTemp.path}/lotti_chat_rec',
    ).create(recursive: true);
    if (!ref.mounted) return;
    final outputPath = '${_tempDir!.path}/chat_rt_${_nowMillisProvider()}';

    try {
      final recorder = _recorder;
      final result = await _realtimeService.stop(
        stopRecorder: () async {
          await recorder?.stop();
        },
        outputPath: outputPath,
      );

      if (currentOpId == _operationId && ref.mounted) {
        state = state.copyWith(
          status: ChatRecorderStatus.idle,
          transcript: result.transcript,
        );
      }

      getIt<DomainLogger>().log(
        LogDomain.chat,
        'chat_realtime_recording_stopped: '
        'transcriptLen=${result.transcript.length}, '
        'audioFile=${result.audioFilePath}, '
        'usedFallback=${result.usedTranscriptFallback}',
        subDomain: 'stopRealtime',
      );
    } catch (e) {
      // Tear down the WebSocket and service subscriptions that
      // service.stop() would have cleaned up on success.
      try {
        await _realtimeService.dispose();
      } catch (_) {}
      if (currentOpId == _operationId && ref.mounted) {
        state = state.copyWith(
          status: ChatRecorderStatus.idle,
          error: 'Realtime transcription failed: $e',
          errorType: ChatRecorderErrorType.transcriptionFailed,
        );
      }
    } finally {
      await _cleanupInternal();
    }
  }

  /// Toggles between batch and realtime transcription mode.
  void toggleRealtimeMode() {
    if (!ref.mounted) return;
    state = state.copyWith(useRealtimeMode: !state.useRealtimeMode);
  }
}

/// App-wide recorder for the chat input mic. `autoDispose` so the recorder,
/// subscriptions, and temp files are torn down when the chat modal closes (see
/// the `ref.onDispose` chain in [ChatRecorderController.build]).
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
