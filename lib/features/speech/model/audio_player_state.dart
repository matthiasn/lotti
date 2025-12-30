import 'package:flutter/foundation.dart';
import 'package:lotti/classes/journal_entities.dart';

/// Playback status for the audio player
enum AudioPlayerStatus { initializing, playing, paused, stopped }

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

  final AudioPlayerStatus status;
  final Duration totalDuration;
  final Duration progress;
  final Duration pausedAt;
  final double speed;
  final bool showTranscriptsList;
  final Duration buffered;
  final JournalAudio? audioNote;

  AudioPlayerState copyWith({
    AudioPlayerStatus? status,
    Duration? totalDuration,
    Duration? progress,
    Duration? pausedAt,
    double? speed,
    bool? showTranscriptsList,
    Duration? buffered,
    JournalAudio? audioNote,
  }) {
    return AudioPlayerState(
      status: status ?? this.status,
      totalDuration: totalDuration ?? this.totalDuration,
      progress: progress ?? this.progress,
      pausedAt: pausedAt ?? this.pausedAt,
      speed: speed ?? this.speed,
      showTranscriptsList: showTranscriptsList ?? this.showTranscriptsList,
      buffered: buffered ?? this.buffered,
      audioNote: audioNote ?? this.audioNote,
    );
  }
}
