part of 'capture_controller.dart';

mixin _CaptureRealtimeCleanup on Notifier<CaptureState> {
  DateTime Function() get _now;
  RealtimeTranscriptionService get _realtimeService;
  set _activeIsRealtime(bool? value);
  StreamSubscription<record.Amplitude>? get _ampSub;
  set _ampSub(StreamSubscription<record.Amplitude>? value);
  StreamSubscription<double>? get _realtimeAmpSub;
  set _realtimeAmpSub(StreamSubscription<double>? value);
  set _realtimeAudioDirectory(String? value);
  set _realtimeAudioFile(String? value);
  set _realtimeOutputBasePath(String? value);
  record.AudioRecorder? get _realtimeRecorder;
  set _realtimeRecorder(record.AudioRecorder? value);
  set _recordingNote(AudioNote? value);
  set _recordingStartedAt(DateTime? value);
  bool get _verifyRealtimeTranscript;
  AudioTranscriptionService get _transcriber;

  /// Persists [transcript] as an [AudioTranscript] on [journalAudio]
  /// and mirrors the text into [JournalAudio.entryText] so the audio
  /// entry shows up with searchable content in the journal.
  Future<void> _attachTranscriptToJournalAudio({
    required JournalAudio journalAudio,
    required String transcript,
    required String library,
    required String model,
    required String detectedLanguage,
  }) async {
    try {
      final persistenceLogic = getIt<PersistenceLogic>();
      final audioTranscript = AudioTranscript(
        created: _now(),
        library: library,
        model: model,
        detectedLanguage: detectedLanguage,
        transcript: transcript,
      );
      final existing = journalAudio.data.transcripts ?? <AudioTranscript>[];
      final updated = journalAudio.copyWith(
        meta: await persistenceLogic.updateMetadata(journalAudio.meta),
        data: journalAudio.data.copyWith(
          transcripts: [...existing, audioTranscript],
        ),
        entryText: EntryText(plainText: transcript, markdown: transcript),
      );
      await persistenceLogic.updateDbEntity(updated);
    } catch (_) {
      // Attaching the transcript is best-effort — the capture flow
      // still proceeds with the in-memory transcript even if the
      // journal mutation fails.
    }
  }

  Future<void> _cleanupRealtime({required bool disposeRecorder}) async {
    final ampSub = _realtimeAmpSub;
    _realtimeAmpSub = null;
    if (ampSub != null) {
      unawaited(ampSub.cancel());
    }
    if (disposeRecorder) {
      final recorder = _realtimeRecorder;
      _realtimeRecorder = null;
      if (recorder != null) {
        try {
          await recorder.dispose();
        } catch (_) {}
      }
    }
    unawaited(_realtimeService.dispose());
    _realtimeOutputBasePath = null;
    _realtimeAudioDirectory = null;
    _realtimeAudioFile = null;
    _recordingStartedAt = null;
    _activeIsRealtime = null;
  }

  void _cleanupSync() {
    final ampSub = _ampSub;
    _ampSub = null;
    if (ampSub != null) {
      unawaited(ampSub.cancel());
    }
    final realtimeAmpSub = _realtimeAmpSub;
    _realtimeAmpSub = null;
    if (realtimeAmpSub != null) {
      unawaited(realtimeAmpSub.cancel());
    }
    final recorder = _realtimeRecorder;
    _realtimeRecorder = null;
    if (recorder != null) {
      unawaited(
        () async {
          try {
            await recorder.stop();
          } catch (_) {}
          try {
            await recorder.dispose();
          } catch (_) {}
        }(),
      );
    }
    // Mirror `_cleanupRealtime`: tear down the active WebSocket / MLX
    // session so route disposal and `reset()` don't leak the running
    // transcription. The provider itself is keep-alive, so the service
    // instance survives — only the in-flight session is torn down.
    unawaited(_realtimeService.dispose());
    _recordingNote = null;
    _recordingStartedAt = null;
    _realtimeOutputBasePath = null;
    _realtimeAudioDirectory = null;
    _realtimeAudioFile = null;
    _activeIsRealtime = null;
  }

  Future<String> _resolveRealtimeFinalTranscript({
    required RealtimeStopResult result,
    required String realtimeTranscript,
  }) async {
    if (!_verifyRealtimeTranscript) return realtimeTranscript;

    final audioFilePath = result.audioFilePath;
    if (audioFilePath == null || audioFilePath.isEmpty) {
      return realtimeTranscript;
    }

    try {
      final batchTranscript = (await _transcriber.transcribe(
        audioFilePath,
      )).trim();
      if (batchTranscript.isEmpty) return realtimeTranscript;
      if (realtimeTranscript.isEmpty || result.usedTranscriptFallback) {
        return batchTranscript;
      }

      // Realtime `done` can occasionally be shorter than the spoken capture.
      // Keep realtime when it agrees, but let full-file transcription repair
      // obvious truncation before the user reaches the editable transcript.
      if (batchTranscript.length >
          realtimeTranscript.length + _batchTranscriptOvertakeMargin) {
        return batchTranscript;
      }
    } catch (_) {
      // Final verification is best-effort. Realtime still gives the user an
      // editable transcript if the batch transcriber is unavailable.
    }

    return realtimeTranscript;
  }
}

/// Margin (chars) the full-file batch transcript must beat realtime by
/// before it replaces the realtime transcript.
const _batchTranscriptOvertakeMargin = 8;

double _normaliseDbfs(double dbfs) {
  if (dbfs.isNaN || dbfs.isInfinite) return 0;
  final clamped = dbfs.clamp(_minDbfs, 0.0);
  return (clamped - _minDbfs) / -_minDbfs;
}

double _sanitizeVisualDbfs(double dbfs) {
  if (dbfs.isNaN || dbfs.isInfinite) return _minVisualDbfs;
  return dbfs.clamp(_minVisualDbfs, 0.0);
}
