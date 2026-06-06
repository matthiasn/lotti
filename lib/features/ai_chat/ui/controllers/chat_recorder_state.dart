part of 'chat_recorder_controller.dart';

enum ChatRecorderStatus { idle, recording, realtimeRecording, processing }

enum ChatRecorderErrorType {
  permissionDenied,
  startFailed,
  noAudioFile,
  transcriptionFailed,
  concurrentOperation,
}

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
