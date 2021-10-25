import 'package:bloc/bloc.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:just_audio/just_audio.dart';
import 'package:wisely/blocs/audio/player_state.dart';
import 'package:wisely/classes/journal_entities.dart';
import 'package:wisely/utils/audio_utils.dart';

class AudioPlayerCubit extends Cubit<AudioPlayerState> {
  final AudioPlayer _audioPlayer = AudioPlayer();

  AudioPlayerCubit()
      : super(AudioPlayerState(
          status: AudioPlayerStatus.initializing,
          totalDuration: const Duration(minutes: 0),
          progress: const Duration(minutes: 0),
          pausedAt: const Duration(minutes: 0),
        )) {
    _audioPlayer.positionStream.listen((event) {
      updateProgress(event);
    });
    _audioPlayer.playbackEventStream.listen((event) {
      print(event);
      if (event.processingState == ProcessingState.completed) {
        stopPlay();
      }
    });
  }

  void updateProgress(Duration duration) {
    emit(state.copyWith(progress: duration));
  }

  void setAudioNote(AudioNote audioNote) async {
    String localPath = await AudioUtils.getFullAudioPath(audioNote);
    print(localPath);

    AudioPlayerState newState = AudioPlayerState(
      status: AudioPlayerStatus.stopped,
      progress: const Duration(minutes: 0),
      pausedAt: const Duration(minutes: 0),
      totalDuration: const Duration(minutes: 0),
      audioNote: audioNote,
    );
    emit(newState);

    Duration? totalDuration = await _audioPlayer.setFilePath(localPath);
    if (totalDuration != null) {
      emit(newState.copyWith(totalDuration: totalDuration));
    }
  }

  void play() async {
    await _audioPlayer.setSpeed(1.2);
    _audioPlayer.play();
    await _audioPlayer.seek(state.pausedAt);
    emit(state.copyWith(status: AudioPlayerStatus.playing));
  }

  void stopPlay() async {
    await _audioPlayer.stop();
    emit(state.copyWith(
      status: AudioPlayerStatus.stopped,
      progress: const Duration(minutes: 0),
    ));
  }

  void seek(Duration newPosition) async {
    await _audioPlayer.seek(newPosition);
    emit(state.copyWith(
      progress: newPosition,
      pausedAt: newPosition,
    ));
  }

  void pause() async {
    await _audioPlayer.pause();
    emit(state.copyWith(
      status: AudioPlayerStatus.paused,
      pausedAt: state.progress,
    ));
  }

  void fwd() async {
    Duration newPosition =
        Duration(milliseconds: state.progress.inMilliseconds + 15000);
    await _audioPlayer.seek(newPosition);
    emit(state.copyWith(
      progress: newPosition,
      pausedAt: newPosition,
    ));
  }

  void rew() async {
    Duration newPosition =
        Duration(milliseconds: state.progress.inMilliseconds - 15000);
    await _audioPlayer.seek(newPosition);
    emit(state.copyWith(
      progress: newPosition,
      pausedAt: newPosition,
    ));
  }

  @override
  Future<void> close() async {
    super.close();
    _audioPlayer.dispose();
  }
}
