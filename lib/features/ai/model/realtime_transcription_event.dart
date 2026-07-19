/// Final transcript returned by the `transcription.done` server event.
class RealtimeTranscriptionDone {
  const RealtimeTranscriptionDone({required this.text, this.usage});

  /// The authoritative final transcript text.
  final String text;

  /// Token/audio usage statistics from the server, if provided.
  final Map<String, dynamic>? usage;
}

/// Error event from the real-time transcription WebSocket.
class RealtimeTranscriptionError {
  const RealtimeTranscriptionError({
    required this.message,
    this.code,
    this.type,
  });

  final String message;
  final String? code;
  final String? type;
}

/// Local durability outcome returned with a stopped realtime capture.
enum RealtimeCaptureDisposition {
  /// Every source frame was durably accepted and the WAV was finalized.
  complete,

  /// A playable WAV contains the durably accepted prefix, but source capture
  /// ended with an error or could not be fully drained.
  savedPartial,

  /// The spool remains on disk, but a playable WAV could not be finalized.
  recoveryRequired,

  /// The recorder produced no complete PCM sample.
  noAudio,
}

/// Result returned by `RealtimeTranscriptionService.stop()`.
class RealtimeStopResult {
  factory RealtimeStopResult({
    required String transcript,
    required String recordingSessionId,
    required RealtimeCaptureDisposition captureDisposition,
    String? audioFilePath,
    bool usedTranscriptFallback = false,
    String? detectedLanguage,
    Duration? audioDuration,
  }) {
    if (recordingSessionId.trim().isEmpty) {
      throw ArgumentError.value(
        recordingSessionId,
        'recordingSessionId',
        'A realtime stop result requires a durable recording identity',
      );
    }
    final pathIsValid = switch (captureDisposition) {
      RealtimeCaptureDisposition.complete ||
      RealtimeCaptureDisposition.savedPartial => audioFilePath != null,
      RealtimeCaptureDisposition.noAudio => audioFilePath == null,
      RealtimeCaptureDisposition.recoveryRequired => true,
    };
    if (!pathIsValid) {
      throw ArgumentError.value(
        audioFilePath,
        'audioFilePath',
        'Complete and partial captures require an audio path; no-audio '
            'captures must not expose one',
      );
    }
    return RealtimeStopResult._(
      transcript: transcript,
      recordingSessionId: recordingSessionId,
      captureDisposition: captureDisposition,
      audioFilePath: audioFilePath,
      usedTranscriptFallback: usedTranscriptFallback,
      detectedLanguage: detectedLanguage,
      audioDuration: audioDuration,
    );
  }

  const RealtimeStopResult._({
    required this.transcript,
    required this.recordingSessionId,
    required this.captureDisposition,
    required this.audioFilePath,
    required this.usedTranscriptFallback,
    required this.detectedLanguage,
    required this.audioDuration,
  });

  /// Final transcript from the backend, or the most complete accumulated
  /// deltas available when the backend failed or timed out.
  final String transcript;

  /// Stable identity of the durable source capture that produced this result.
  /// Callers use this to correlate a UI outcome with later recovery work.
  final String recordingSessionId;

  /// Path to the canonical saved WAV, when local finalization succeeded.
  final String? audioFilePath;

  /// True when backend setup, streaming, terminal signalling, or completion
  /// failed and accumulated text was used as a best-effort fallback.
  final bool usedTranscriptFallback;

  /// Language detected by the real-time transcription server, if reported.
  final String? detectedLanguage;

  /// Whether the local source is complete, partial, awaiting recovery, or
  /// empty. Callers must not present partial/recovery output as a normal save.
  final RealtimeCaptureDisposition captureDisposition;

  /// Sample-derived duration of the finalized WAV.
  final Duration? audioDuration;
}
