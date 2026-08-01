/// Lifecycle of the shared voice recorder used by AI-assisted input surfaces.
///
/// `recording` captures audio to a file; `processing` covers post-stop batch
/// transcription.
enum ChatRecorderStatus { idle, recording, processing }

/// Classifies a recorder failure so the UI can map it to a localized message
/// or recovery action. `concurrentOperation` flags a start attempt while
/// another start/stop is mid-flight (see [ChatRecorderState.error]).
enum ChatRecorderErrorType {
  permissionDenied,
  startFailed,
  noAudioFile,
  transcriptionFailed,
  concurrentOperation,
}

/// Immutable snapshot of the shared voice recorder for the UI.
///
/// Carries the [status], the rolling dBFS [amplitudeHistory] for the waveform,
/// and at most one of [transcript] (finished, awaiting consumption) /
/// [partialTranscript] (in-progress streaming text) / [error]. Produced by
/// `ChatRecorderController`.
class ChatRecorderState {
  // Constructors first per lint
  const ChatRecorderState({
    required this.status,
    required this.amplitudeHistory,
    this.transcript,
    this.partialTranscript,
    this.error,
    this.errorType,
  });

  const ChatRecorderState.initial()
    : status = ChatRecorderStatus.idle,
      amplitudeHistory = const <double>[],
      transcript = null,
      partialTranscript = null,
      error = null,
      errorType = null;

  // Fields
  final ChatRecorderStatus status;
  final List<double> amplitudeHistory; // dBFS history
  final String? transcript; // last finished transcript waiting to be consumed
  final String? partialTranscript; // in-progress transcript during streaming
  final String? error;
  final ChatRecorderErrorType? errorType;

  // Methods
  /// Footgun: [transcript], [partialTranscript], [error], and [errorType] are
  /// NOT preserved when omitted — passing nothing resets them to null. This is
  /// deliberate (each new status implies a fresh result), so callers that want
  /// to keep a value must pass it explicitly (e.g. re-passing
  /// `partialTranscript: state.partialTranscript`). [status] and
  /// [amplitudeHistory] use the usual keep-on-omit semantics.
  ChatRecorderState copyWith({
    ChatRecorderStatus? status,
    List<double>? amplitudeHistory,
    String? transcript,
    String? partialTranscript,
    String? error,
    ChatRecorderErrorType? errorType,
  }) {
    return ChatRecorderState(
      status: status ?? this.status,
      amplitudeHistory: amplitudeHistory ?? this.amplitudeHistory,
      transcript: transcript,
      partialTranscript: partialTranscript,
      error: error,
      errorType: errorType,
    );
  }
}

/// Tuning for the batch (file-based) recording path.
///
/// [maxSeconds] is a safety cap after which `ChatRecorderController` auto-stops
/// and transcribes; [amplitudeIntervalMs] throttles waveform sampling.
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

/// Observes app lifecycle to stop realtime recording when app is backgrounded.
///
