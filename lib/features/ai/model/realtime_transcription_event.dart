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

/// Result returned by `RealtimeTranscriptionService.stop()`.
class RealtimeStopResult {
  const RealtimeStopResult({
    required this.transcript,
    this.audioFilePath,
    this.usedTranscriptFallback = false,
  });

  /// Final transcript from `transcription.done`, or accumulated deltas
  /// if the done event timed out.
  final String transcript;

  /// Path to the saved audio file (M4A normally, WAV if conversion failed).
  final String? audioFilePath;

  /// True if `transcription.done` timed out and accumulated deltas were used
  /// as a best-effort fallback.
  final bool usedTranscriptFallback;
}
