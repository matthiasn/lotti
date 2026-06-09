part of 'chat_recorder_controller.dart';

/// Realtime (streaming) transcription methods of [ChatRecorderController].
/// Split into a part-file mixin to keep the controller under the file-size
/// limit; shared mutable state is reached through abstract accessors that the
/// concrete controller satisfies with its own fields.
mixin _ChatRecorderRealtime on Notifier<ChatRecorderState> {
  bool get _isStarting;
  set _isStarting(bool value);
  int get _operationId;
  set _operationId(int value);
  record.AudioRecorder Function() get _recorderFactory;
  record.AudioRecorder? get _recorder;
  set _recorder(record.AudioRecorder? value);
  StreamSubscription<double>? get _realtimeAmpSub;
  set _realtimeAmpSub(StreamSubscription<double>? value);
  RealtimeTranscriptionService get _realtimeService;
  Timer? get _maxTimer;
  set _maxTimer(Timer? value);
  ChatRecorderConfig get _config;
  Future<Directory> Function() get _tempDirectoryProvider;
  Directory? get _tempDir;
  set _tempDir(Directory? value);
  int Function() get _nowMillisProvider;
  Future<void> _cleanupInternal();

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

        final history = List<double>.from(state.amplitudeHistory)..add(dbfs);
        if (history.length > _historyMax) history.removeAt(0);
        state = state.copyWith(
          status: ChatRecorderStatus.realtimeRecording,
          amplitudeHistory: history,
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

/// Max number of amplitude samples retained for the live waveform
/// (~10s at 50ms; the UI samples this down to fit).
const int _historyMax = 200;
