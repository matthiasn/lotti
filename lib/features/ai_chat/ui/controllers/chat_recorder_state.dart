/// Lifecycle of the shared voice recorder used by AI-assisted input surfaces.
///
/// `recording` captures audio to a file; `processing` covers post-stop batch
/// transcription.
enum ChatRecorderStatus { idle, recording, processing }

/// Why a voice capture ended in [ChatRecorderState.error].
///
/// The message beside it is diagnostic English written for the log; the kind
/// is what the UI localizes. A toast that says only "Recording failed" leaves
/// the user no way to tell a denied microphone from a missing transcription
/// model, so every failure path names its kind.
enum ChatRecorderErrorKind {
  /// The OS refused microphone access.
  permissionDenied,

  /// Another start/stop is already running.
  busy,

  /// The recorder itself could not start.
  startFailed,

  /// Recording stopped with no audio file to transcribe.
  noAudioFile,

  /// No audio-capable model is configured to transcribe with.
  noAudioModel,

  /// The transcription request itself failed or came back empty.
  transcriptionFailed,
}

/// Immutable snapshot of the shared voice recorder for the UI.
///
/// Carries the [status], the rolling dBFS [amplitudeHistory] for the waveform,
/// and at most one of [transcript] (finished, awaiting consumption) /
/// [partialTranscript] (in-progress streaming text) / [error] plus its
/// [errorKind]. Produced by `ChatRecorderController`.
class ChatRecorderState {
  // Constructors first per lint
  const ChatRecorderState({
    required this.status,
    required this.amplitudeHistory,
    this.transcript,
    this.partialTranscript,
    this.error,
    this.errorKind,
  });

  const ChatRecorderState.initial()
    : status = ChatRecorderStatus.idle,
      amplitudeHistory = const <double>[],
      transcript = null,
      partialTranscript = null,
      error = null,
      errorKind = null;

  // Fields
  final ChatRecorderStatus status;
  final List<double> amplitudeHistory; // dBFS history
  final String? transcript; // last finished transcript waiting to be consumed
  final String? partialTranscript; // in-progress transcript during streaming
  final String? error;

  /// The localizable reason behind [error]; null whenever [error] is null.
  final ChatRecorderErrorKind? errorKind;

  // Methods
  /// Footgun: [transcript], [partialTranscript], and [error] are
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
    ChatRecorderErrorKind? errorKind,
  }) {
    return ChatRecorderState(
      status: status ?? this.status,
      amplitudeHistory: amplitudeHistory ?? this.amplitudeHistory,
      transcript: transcript,
      partialTranscript: partialTranscript,
      error: error,
      errorKind: errorKind,
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
