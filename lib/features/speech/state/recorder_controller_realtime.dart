part of 'recorder_controller.dart';

/// Realtime PCM-streaming transcription flow for [AudioRecorderController].
/// Shared controller state is exposed via abstract members below.
mixin _AudioRecorderRealtime on _$AudioRecorderController {
  // Shared controller state, satisfied by AudioRecorderController fields.
  DomainLogger get _loggingService;
  String? get _categoryId;
  bool get _disposed;
  Queue<double> get _dbfsBuffer;
  String? get _linkedId;
  set _linkedId(String? value);
  rec.AudioRecorder? get _realtimeRecorder;
  set _realtimeRecorder(rec.AudioRecorder? value);
  StreamSubscription<double>? get _realtimeAmplitudeSub;
  set _realtimeAmplitudeSub(StreamSubscription<double>? value);
  DateTime? get _realtimeStartTime;
  set _realtimeStartTime(DateTime? value);
  String? get _realtimeModelName;
  set _realtimeModelName(String? value);
  String? get _realtimeProviderName;
  set _realtimeProviderName(String? value);
  double _calculateVu(double dBFS);

  /// Starts a realtime recording session using PCM streaming + WebSocket
  /// transcription via [RealtimeTranscriptionService].
  ///
  /// This bypasses [AudioRecorderRepository] — instead it creates a raw
  /// `AudioRecorder` and calls `startStream`
  /// at 16kHz PCM mono, the format required by the Mistral Voxtral API.
  Future<void> recordRealtime({String? linkedId}) async {
    _linkedId = linkedId;

    try {
      // Pause any playing audio first
      await _pauseAudioPlayer();

      final recorderFactory = ref.read(realtimeRecorderFactoryProvider);
      final recorder = recorderFactory();
      // Assign immediately so _cleanupRealtime() can dispose it if
      // any subsequent await (hasPermission, startStream) throws.
      _realtimeRecorder = recorder;

      final hasPerm = await recorder.hasPermission();
      if (!hasPerm) {
        await recorder.dispose();
        _realtimeRecorder = null;
        _loggingService.log(
          LogDomain.speech,
          'No audio recording permission for realtime',
          subDomain: 'recordRealtime_permission_denied',
        );
        return;
      }

      // Start PCM stream at 16kHz mono (required by Mistral realtime API)
      final pcmStream = await recorder.startStream(
        const rec.RecordConfig(
          encoder: rec.AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
        ),
      );
      _realtimeStartTime = DateTime.now();

      final service = ref.read(realtimeTranscriptionServiceProvider);

      // Resolve config to store model/provider names for transcript metadata
      final config = await service.resolveRealtimeConfig();
      _realtimeModelName = config?.model.providerModelId;
      _realtimeProviderName = config?.provider.name;

      // Subscribe to amplitude stream for VU meter
      _realtimeAmplitudeSub = service.amplitudeStream.listen((dbfs) {
        if (_disposed) return;
        final startTime = _realtimeStartTime;
        if (startTime == null) return;
        final vu = _calculateVu(dbfs);
        state = state.copyWith(
          progress: DateTime.now().difference(startTime),
          dBFS: dbfs,
          vu: vu,
        );
      });

      state = state.copyWith(
        status: AudioRecorderStatus.recording,
        isRealtimeMode: true,
        linkedId: linkedId,
        partialTranscript: null,
      );

      // Start realtime transcription — onDelta accumulates into partialTranscript
      await service.startRealtimeTranscription(
        pcmStream: pcmStream,
        onDelta: (delta) {
          if (_disposed) return;
          final current = state.partialTranscript ?? '';
          state = state.copyWith(partialTranscript: '$current$delta');
        },
      );

      _loggingService.log(
        LogDomain.speech,
        'Realtime recording started',
        subDomain: 'recordRealtime',
      );
    } catch (exception, stackTrace) {
      // Clean up on failure
      await _cleanupRealtime();
      state = state.copyWith(
        status: AudioRecorderStatus.stopped,
        isRealtimeMode: false,
        partialTranscript: null,
      );
      _loggingService.error(
        LogDomain.speech,
        exception,
        stackTrace: stackTrace,
        subDomain: 'recordRealtime',
      );
    }
  }

  /// Stops the realtime recording session, creates a journal audio entry
  /// with the transcript, and triggers remaining automatic prompts.
  ///
  /// Returns the ID of the created journal entry, or null on error.
  Future<String?> stopRealtime() async {
    // Capture metadata in locals before any cleanup nulls them (#6).
    final modelName = _realtimeModelName;
    final providerName = _realtimeProviderName;

    try {
      // Cancel amplitude subscription
      await _realtimeAmplitudeSub?.cancel();
      _realtimeAmplitudeSub = null;

      final duration = _realtimeStartTime != null
          ? DateTime.now().difference(_realtimeStartTime!)
          : state.progress;

      // Build output path using the same directory structure as standard recording
      final created = _realtimeStartTime ?? DateTime.now();
      final fileName = DateFormat('yyyy-MM-dd_HH-mm-ss-S').format(created);
      final day = DateFormat('yyyy-MM-dd').format(created);
      final relativePath = '/audio/$day/';
      final directory = await createAssetDirectory(relativePath);
      final outputPath = '$directory$fileName';

      // Stop the service — this stops the recorder, sends endAudio,
      // waits for transcription.done, writes WAV, converts to M4A
      final service = ref.read(realtimeTranscriptionServiceProvider);
      final recorder = _realtimeRecorder;
      final result = await service.stop(
        stopRecorder: () async {
          await recorder?.stop();
        },
        outputPath: outputPath,
      );

      // Dispose the recorder
      await recorder?.dispose();
      _realtimeRecorder = null;
      _realtimeStartTime = null;

      // Only create an AudioNote when an actual audio file was produced.
      // audioFilePath is null when no PCM data was captured (e.g. very short
      // recording), and using a fabricated path would create a broken reference.
      final audioFilePath = result.audioFilePath;
      final audioNote = audioFilePath != null
          ? AudioNote(
              createdAt: created,
              audioFile: audioFilePath.split('/').last,
              audioDirectory: relativePath,
              duration: duration,
            )
          : null;

      // Preserve inference preferences before resetting state
      final enableSpeechRecognition = state.enableSpeechRecognition;

      _dbfsBuffer.clear();
      state = AudioRecorderState(
        status: AudioRecorderStatus.stopped,
        dBFS: -160,
        vu: -20,
        progress: Duration.zero,
        showIndicator: false,
        modalVisible: false,
        enableSpeechRecognition: enableSpeechRecognition,
      );

      // Create the journal audio entry (only when we have an actual audio file)
      final journalAudio = audioNote != null
          ? await SpeechRepository.createAudioEntry(
              audioNote,
              linkedId: _linkedId,
              categoryId: _categoryId,
            )
          : null;

      final linkedTaskId = _linkedId;
      _linkedId = null;
      final entryId = journalAudio?.meta.id;

      // Save the realtime transcript on the audio entry
      if (entryId != null &&
          result.transcript.isNotEmpty &&
          journalAudio != null) {
        await _saveRealtimeTranscript(
          journalAudio: journalAudio,
          transcript: result.transcript,
          providerName: providerName ?? 'Mistral',
          modelId: modelName ?? 'voxtral-mini',
          detectedLanguage: result.detectedLanguage,
        );
      }

      // Trigger automatic prompts, but skip batch transcription
      if (entryId != null && linkedTaskId != null) {
        unawaited(
          _triggerAutomaticPrompts(
            entryId,
            linkedTaskId: linkedTaskId,
            realtimeTranscriptProvided: true,
          ),
        );
      }

      _realtimeModelName = null;
      _realtimeProviderName = null;

      _loggingService.log(
        LogDomain.speech,
        'Realtime recording stopped: '
        'transcriptLen=${result.transcript.length}, '
        'audioFile=${result.audioFilePath}, '
        'usedFallback=${result.usedTranscriptFallback}',
        subDomain: 'stopRealtime',
      );

      return entryId;
    } catch (exception, stackTrace) {
      _loggingService.error(
        LogDomain.speech,
        exception,
        stackTrace: stackTrace,
        subDomain: 'stopRealtime',
      );
      _dbfsBuffer.clear();
      await _cleanupRealtime();
      try {
        await ref.read(realtimeTranscriptionServiceProvider).dispose();
      } catch (_) {}
      ref.invalidate(realtimeTranscriptionServiceProvider);
      state = state.copyWith(
        status: AudioRecorderStatus.stopped,
        progress: Duration.zero,
        dBFS: -160,
        vu: -20,
        isRealtimeMode: false,
        partialTranscript: null,
      );
    }
    return null;
  }

  /// Cancels the realtime recording session without saving.
  Future<void> cancelRealtime() async {
    try {
      await _cleanupRealtime();

      // Dispose the service to tear down WebSocket and subscriptions,
      // then invalidate the provider so the next recordRealtime() gets
      // a fresh instance.
      await ref.read(realtimeTranscriptionServiceProvider).dispose();
      ref.invalidate(realtimeTranscriptionServiceProvider);

      _dbfsBuffer.clear();
      state = state.copyWith(
        status: AudioRecorderStatus.stopped,
        progress: Duration.zero,
        dBFS: -160,
        vu: -20,
        isRealtimeMode: false,
        partialTranscript: null,
      );

      _loggingService.log(
        LogDomain.speech,
        'Realtime recording cancelled',
        subDomain: 'cancelRealtime',
      );
    } catch (exception, stackTrace) {
      _loggingService.error(
        LogDomain.speech,
        exception,
        stackTrace: stackTrace,
        subDomain: 'cancelRealtime',
      );
    }
  }

  /// Saves the realtime transcript as an [AudioTranscript] on the
  /// [JournalAudio] entry, making it searchable and visible.
  Future<void> _saveRealtimeTranscript({
    required JournalAudio journalAudio,
    required String transcript,
    required String providerName,
    required String modelId,
    String? detectedLanguage,
  }) async {
    final persistenceLogic = getIt<PersistenceLogic>();
    final audioTranscript = AudioTranscript(
      created: DateTime.now(),
      library: providerName,
      model: modelId,
      detectedLanguage: detectedLanguage ?? '-',
      transcript: transcript,
    );

    final existingTranscripts = journalAudio.data.transcripts ?? [];
    final updated = journalAudio.copyWith(
      meta: await persistenceLogic.updateMetadata(journalAudio.meta),
      data: journalAudio.data.copyWith(
        transcripts: [...existingTranscripts, audioTranscript],
      ),
      entryText: EntryText(
        plainText: transcript,
        markdown: transcript,
      ),
    );
    // Look up parent link so the parent task (if any) is notified.
    // This ensures agents subscribed to the task ID wake when ASR
    // adds or updates the transcript on a child audio entry.
    String? parentId;
    try {
      final db = getIt<JournalDb>();
      final links = await db.linksForEntryIds({journalAudio.meta.id});
      if (links.isNotEmpty) {
        parentId = links.first.fromId;
      }
    } catch (_) {
      // Non-fatal: notification will still include the audio entry's own ID.
    }

    await persistenceLogic.updateDbEntity(updated, linkedId: parentId);
  }

  /// Cleans up realtime recording resources.
  Future<void> _cleanupRealtime() async {
    try {
      await _realtimeAmplitudeSub?.cancel();
    } catch (_) {}
    _realtimeAmplitudeSub = null;
    try {
      await _realtimeRecorder?.stop();
    } catch (_) {}
    try {
      await _realtimeRecorder?.dispose();
    } catch (_) {}
    _realtimeRecorder = null;
    _realtimeStartTime = null;
    _realtimeModelName = null;
    _realtimeProviderName = null;
  }

  /// Pauses any currently playing audio. Shared between `record` and
  /// [recordRealtime].
  ///
  /// Skips reading the provider if it hasn't been initialized yet — reading it
  /// would eagerly construct a media_kit `Player` (and its native mpv core
  /// thread) just to observe that nothing is playing. That makes every
  /// subsequent hot restart crash on macOS, since mpv's core thread outlives
  /// the Dart isolate teardown.
  Future<void> _pauseAudioPlayer() async {
    if (!ref.exists(audioPlayerControllerProvider)) {
      return;
    }
    try {
      final playerState = ref.read(audioPlayerControllerProvider);
      if (playerState.status == AudioPlayerStatus.playing) {
        await ref.read(audioPlayerControllerProvider.notifier).pause();
      }
    } catch (e) {
      _loggingService.log(
        LogDomain.speech,
        'Audio player not available, continuing without audio pause: $e',
        subDomain: 'pauseAudioPlayer',
      );
    }
  }

  /// Triggers automatic prompts based on category settings and user preferences
  Future<void> _triggerAutomaticPrompts(
    String entryId, {
    String? linkedTaskId,
    bool realtimeTranscriptProvided = false,
  }) async {
    final trigger = ref.read(automaticPromptTriggerProvider);
    await trigger.triggerAutomaticPrompts(
      entryId,
      state,
      linkedTaskId: linkedTaskId,
      realtimeTranscriptProvided: realtimeTranscriptProvided,
    );
  }
}
