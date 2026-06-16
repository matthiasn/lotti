import 'package:flutter/foundation.dart';

/// Lifecycle of a single TTS utterance, from request to playback end.
///
/// ```text
/// idle ─▶ downloadingModel ─▶ synthesizing ─▶ playing ─▶ stopped ─▶ idle
///   └────────────────────────▶ synthesizing (model already present)
/// any ─▶ error ─▶ idle
/// ```
enum TtsPlaybackStatus {
  /// Nothing is playing or being prepared.
  idle,

  /// Fetching the ONNX model from Hugging Face on first use.
  downloadingModel,

  /// Running ONNX inference to produce the WAV.
  synthesizing,

  /// Audio is playing back.
  playing,

  /// Playback finished or was stopped by the user.
  stopped,

  /// Something failed; [TtsPlaybackState.errorMessage] carries the detail.
  error,
}

/// Sentinel distinguishing "leave unchanged" from "set to null" in
/// [TtsPlaybackState.copyWith] for the nullable fields.
const Object _undefined = Object();

/// Immutable snapshot of the app-wide TTS player.
///
/// [sourceId] identifies what is being spoken (e.g. a task id) so a header
/// only renders the busy/playing affordance when *its own* content is active —
/// otherwise every visible card would react to a single utterance.
@immutable
class TtsPlaybackState {
  const TtsPlaybackState({
    this.status = TtsPlaybackStatus.idle,
    this.sourceId,
    this.downloadProgress = 0,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.errorMessage,
  });

  final TtsPlaybackStatus status;

  /// Id of the content currently being prepared/played, or `null` when idle.
  final String? sourceId;

  /// Model download progress in `[0, 1]`, meaningful only while
  /// [status] is [TtsPlaybackStatus.downloadingModel].
  final double downloadProgress;

  /// Current playhead position, updated from the player while
  /// [status] is [TtsPlaybackStatus.playing]; reset to zero on stop.
  final Duration position;

  /// Total length of the synthesized clip, reported by the player once the
  /// WAV is opened.
  final Duration duration;

  /// Human-readable error detail, set only when [status] is
  /// [TtsPlaybackStatus.error].
  final String? errorMessage;

  /// True while the player is doing work for some source — used to disable
  /// re-entrant play taps and to show a busy affordance.
  bool get isBusy =>
      status == TtsPlaybackStatus.downloadingModel ||
      status == TtsPlaybackStatus.synthesizing ||
      status == TtsPlaybackStatus.playing;

  /// Whether [candidateSourceId] is the source this state is currently
  /// busy with.
  bool isActiveFor(String candidateSourceId) =>
      isBusy && sourceId == candidateSourceId;

  TtsPlaybackState copyWith({
    TtsPlaybackStatus? status,
    Object? sourceId = _undefined,
    double? downloadProgress,
    Duration? position,
    Duration? duration,
    Object? errorMessage = _undefined,
  }) {
    return TtsPlaybackState(
      status: status ?? this.status,
      sourceId: sourceId == _undefined ? this.sourceId : sourceId as String?,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      errorMessage: errorMessage == _undefined
          ? this.errorMessage
          : errorMessage as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TtsPlaybackState &&
      other.status == status &&
      other.sourceId == sourceId &&
      other.downloadProgress == downloadProgress &&
      other.position == position &&
      other.duration == duration &&
      other.errorMessage == errorMessage;

  @override
  int get hashCode => Object.hash(
    status,
    sourceId,
    downloadProgress,
    position,
    duration,
    errorMessage,
  );
}
