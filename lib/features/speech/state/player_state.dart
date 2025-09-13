import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/classes/journal_entities.dart';

part 'player_state.freezed.dart';

enum AudioPlayerStatus { initializing, initialized, playing, paused, stopped }

@freezed
abstract class AudioPlayerState with _$AudioPlayerState {
  factory AudioPlayerState({
    required AudioPlayerStatus status,
    required Duration totalDuration,
    required Duration progress,
    required Duration pausedAt,
    required double speed,
    required bool showTranscriptsList,
    JournalAudio? audioNote,
  }) = _AudioPlayerState;
}
