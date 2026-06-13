import 'package:flutter/foundation.dart';

/// Phases of the Capture screen.
enum CapturePhase {
  /// Nothing being recorded — soft hints visible.
  idle,

  /// Mic is open. Amplitudes stream into [CaptureState.amplitudes] and
  /// drive the live waveform. Realtime mode also streams transcript
  /// deltas into [CaptureState.partialTranscript].
  listening,

  /// Recording stopped. Awaiting the final transcript + audio
  /// persistence. Realtime mode usually sits here briefly while
  /// `transcription.done` is awaited; the batch fallback path stays
  /// longer while the post-recording transcribe call runs.
  transcribing,

  /// Final transcript ready and audio persisted. The "Reconcile →" CTA
  /// is enabled.
  captured,

  /// Microphone, recording, or transcription failed. The user can tap
  /// the voice button again to retry.
  error,
}

/// Localizable capture failures surfaced by the UI.
enum CaptureError {
  microphonePermissionDenied,
  recordingStartFailed,
  realtimeTranscriptionStartFailed,
  noActiveRealtimeSession,
  realtimeTranscriptionFailed,
  noAudioRecorded,
  transcriptionFailed,
}

/// State held by `CaptureController`.
@immutable
class CaptureState {
  const CaptureState({
    required this.phase,
    required this.transcript,
    required this.amplitudes,
    this.dbfs = defaultDbfs,
    this.partialTranscript = '',
    this.audioId,
    this.error,
  });

  const CaptureState.idle()
    : phase = CapturePhase.idle,
      transcript = '',
      partialTranscript = '',
      amplitudes = const <double>[],
      dbfs = defaultDbfs,
      audioId = null,
      error = null;

  static const defaultDbfs = -80.0;

  final CapturePhase phase;

  /// The final transcript. Empty until [CapturePhase.captured].
  final String transcript;

  /// Live transcript text from realtime mode. Updated word-by-word as
  /// the model emits deltas. Cleared once the final [transcript] is
  /// available. Always empty in the batch-fallback path.
  final String partialTranscript;

  /// Rolling window of normalised amplitude values (0..1). The
  /// live-waveform widget renders these as bar heights.
  final List<double> amplitudes;

  /// Latest recorder amplitude in dBFS. The waveform keeps normalised
  /// samples; shader-based voice affordances use this raw dBFS value so
  /// their response matches recorder/VU-meter semantics.
  final double dbfs;

  /// `JournalAudio.meta.id` of the persisted recording, or `null` when
  /// no audio is available yet (e.g. in [CapturePhase.idle]).
  final String? audioId;

  /// Localizable failure code surfaced under the voice button in
  /// [CapturePhase.error].
  final CaptureError? error;

  CaptureState copyWith({
    CapturePhase? phase,
    String? transcript,
    String? partialTranscript,
    List<double>? amplitudes,
    double? dbfs,
    String? audioId,
    CaptureError? error,
  }) {
    return CaptureState(
      phase: phase ?? this.phase,
      transcript: transcript ?? this.transcript,
      partialTranscript: partialTranscript ?? this.partialTranscript,
      amplitudes: amplitudes ?? this.amplitudes,
      dbfs: dbfs ?? this.dbfs,
      audioId: audioId ?? this.audioId,
      error: error ?? this.error,
    );
  }

  /// This state minus the audio-meter fields ([amplitudes], [dbfs]).
  ///
  /// The meter streams many updates per second while listening; widgets
  /// that don't render the waveform/orb should watch this projection
  /// (`provider.select((s) => s.withoutMeter)`) so those ticks don't
  /// rebuild whole pages. Only the orb/waveform consumers watch the
  /// meter fields themselves.
  CaptureState get withoutMeter =>
      copyWith(amplitudes: const [], dbfs: defaultDbfs);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CaptureState &&
          other.phase == phase &&
          other.transcript == transcript &&
          other.partialTranscript == partialTranscript &&
          listEquals(other.amplitudes, amplitudes) &&
          other.dbfs == dbfs &&
          other.audioId == audioId &&
          other.error == error;

  @override
  int get hashCode => Object.hash(
    phase,
    transcript,
    partialTranscript,
    Object.hashAll(amplitudes),
    dbfs,
    audioId,
    error,
  );
}
