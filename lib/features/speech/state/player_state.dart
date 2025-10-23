import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/classes/journal_entities.dart';

part 'player_state.freezed.dart';

enum AudioPlayerStatus { initializing, initialized, playing, paused, stopped }

enum AudioWaveformStatus { initial, loading, ready, unavailable }

@freezed
abstract class AudioPlayerState with _$AudioPlayerState {
  factory AudioPlayerState({
    required AudioPlayerStatus status,
    required Duration totalDuration,
    required Duration progress,
    required Duration pausedAt,
    required double speed,
    required bool showTranscriptsList,
    @Default(Duration.zero) Duration buffered,
    @Default(AudioWaveformStatus.initial) AudioWaveformStatus waveformStatus,
    @Default(<double>[]) List<double> waveform,
    @Default(Duration.zero) Duration waveformBucketDuration,
    JournalAudio? audioNote,
  }) = _AudioPlayerState;
}
