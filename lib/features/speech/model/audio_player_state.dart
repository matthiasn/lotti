import 'package:flutter/foundation.dart';
import 'package:lotti/classes/journal_entities.dart';

/// Playback status for the audio player.
enum AudioPlayerStatus {
  /// Initial status before any media is opened (also the default state).
  initializing,

  /// Audio is actively playing.
  playing,

  /// Playback is paused; [AudioPlayerState.pausedAt] holds the resume point.
  paused,

  /// Playback has stopped (e.g. completed) and progress sits at the end.
  stopped,
}

/// Sentinel value to distinguish between "not provided" and "explicitly null"
const Object _undefined = Object();

/// Immutable state representing audio playback configuration.
@immutable
class AudioPlayerState {
  const AudioPlayerState({
    this.status = AudioPlayerStatus.initializing,
    this.totalDuration = Duration.zero,
    this.progress = Duration.zero,
    this.pausedAt = Duration.zero,
    this.speed = 1.0,
    this.showTranscriptsList = false,
    this.buffered = Duration.zero,
    this.audioNote,
  });

  /// Current playback status.
  final AudioPlayerStatus status;

  /// Full length of the loaded media, synced from the player once opened.
  final Duration totalDuration;

  /// Current playback position, driven by the player's position stream.
  final Duration progress;

  /// Position captured when pausing, used to resume from the right spot.
  final Duration pausedAt;

  /// Playback rate multiplier (1.0 = normal speed).
  final double speed;

  /// Whether the transcripts list section is expanded in the UI.
  final bool showTranscriptsList;

  /// How much of the media has buffered, clamped to [totalDuration].
  final Duration buffered;

  /// The audio entry currently loaded, or `null` when none is selected.
  final JournalAudio? audioNote;

  /// Creates a copy of this state with the given fields replaced.
  ///
  /// Note: [audioNote] uses a sentinel pattern to allow explicitly setting
  /// it to null. Pass `audioNote: null` to clear the audio note.
  AudioPlayerState copyWith({
    AudioPlayerStatus? status,
    Duration? totalDuration,
    Duration? progress,
    Duration? pausedAt,
    double? speed,
    bool? showTranscriptsList,
    Duration? buffered,
    Object? audioNote = _undefined,
  }) {
    return AudioPlayerState(
      status: status ?? this.status,
      totalDuration: totalDuration ?? this.totalDuration,
      progress: progress ?? this.progress,
      pausedAt: pausedAt ?? this.pausedAt,
      speed: speed ?? this.speed,
      showTranscriptsList: showTranscriptsList ?? this.showTranscriptsList,
      buffered: buffered ?? this.buffered,
      audioNote: audioNote == _undefined
          ? this.audioNote
          : audioNote as JournalAudio?,
    );
  }
}
