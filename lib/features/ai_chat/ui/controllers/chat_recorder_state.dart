/// Lifecycle of the voice recorder driving the chat input mic.
///
/// `recording` is the batch path (record to file, then transcribe on stop);
/// `realtimeRecording` is the streaming WebSocket path; `processing` covers
/// post-stop transcription for the batch path. Drives which input affordance
/// `InputArea` renders.
enum ChatRecorderStatus { idle, recording, realtimeRecording, processing }

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

/// Immutable snapshot of the chat voice recorder for the UI.
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
    this.useRealtimeMode = false,
  });

  const ChatRecorderState.initial()
    : status = ChatRecorderStatus.idle,
      amplitudeHistory = const <double>[],
      transcript = null,
      partialTranscript = null,
      error = null,
      errorType = null,
      useRealtimeMode = false;

  // Fields
  final ChatRecorderStatus status;
  final List<double> amplitudeHistory; // dBFS history
  final String? transcript; // last finished transcript waiting to be consumed
  final String? partialTranscript; // in-progress transcript during streaming
  final String? error;
  final ChatRecorderErrorType? errorType;

  /// Whether the user has selected realtime transcription mode.
  /// Persists across widget rebuilds within the controller's lifetime.
  final bool useRealtimeMode;

  // Methods
  /// Footgun: [transcript], [partialTranscript], [error], and [errorType] are
  /// NOT preserved when omitted — passing nothing resets them to null. This is
  /// deliberate (each new status implies a fresh result), so callers that want
  /// to keep a value must pass it explicitly (e.g. re-passing
  /// `partialTranscript: state.partialTranscript`). [status],
  /// [amplitudeHistory], and [useRealtimeMode] use the usual keep-on-omit
  /// semantics.
  ChatRecorderState copyWith({
    ChatRecorderStatus? status,
    List<double>? amplitudeHistory,
    String? transcript,
    String? partialTranscript,
    String? error,
    ChatRecorderErrorType? errorType,
    bool? useRealtimeMode,
  }) {
    return ChatRecorderState(
      status: status ?? this.status,
      amplitudeHistory: amplitudeHistory ?? this.amplitudeHistory,
      transcript: transcript,
      partialTranscript: partialTranscript,
      error: error,
      errorType: errorType,
      useRealtimeMode: useRealtimeMode ?? this.useRealtimeMode,
    );
  }
}

/// Tuning for the batch (file-based) recording path.
///
/// [maxSeconds] is a safety cap after which `ChatRecorderController` auto-stops
/// and transcribes; [amplitudeIntervalMs] throttles waveform sampling. The
/// realtime path ignores [sampleRate] (it forces 16kHz mono PCM as the Mistral
/// API requires) but still honors [maxSeconds].
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
