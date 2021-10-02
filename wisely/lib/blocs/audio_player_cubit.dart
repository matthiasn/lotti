import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

enum AudioPlayerStatus { initializing, initialized, playing, paused, stopped }

class AudioPlayerState extends Equatable {
  AudioPlayerStatus status = AudioPlayerStatus.initializing;
  Duration totalDuration = Duration(minutes: 0);
  Duration progress = Duration(minutes: 0);
  Duration pausedAt = Duration(minutes: 0);

  AudioPlayerState() {}

  AudioPlayerState.playing(AudioPlayerState other, Duration duration) {
    status = AudioPlayerStatus.playing;
    totalDuration = duration;
    progress = other.progress;
  }

  AudioPlayerState.stopped(AudioPlayerState other) {
    status = AudioPlayerStatus.stopped;
    totalDuration = other.totalDuration;
    progress = Duration(minutes: 0);
  }

  AudioPlayerState.paused(AudioPlayerState other, Duration duration) {
    status = AudioPlayerStatus.paused;
    totalDuration = other.totalDuration;
    progress = other.progress;
    pausedAt = duration;
  }

  AudioPlayerState.seek(AudioPlayerState other, Duration duration) {
    status = other.status;
    totalDuration = other.totalDuration;
    progress = duration;
    pausedAt = duration;
  }

  AudioPlayerState.progress(AudioPlayerState other, Duration duration) {
    status = other.status;
    progress = duration;
    totalDuration = other.totalDuration;
    pausedAt = other.pausedAt;
  }

  @override
  List<Object?> get props => [status, totalDuration, progress, pausedAt];
}

class AudioPlayerCubit extends Cubit<AudioPlayerState> {
  final AudioPlayer _audioPlayer = AudioPlayer();

  AudioPlayerCubit() : super(AudioPlayerState()) {
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
    emit(AudioPlayerState.progress(state, duration));
  }

  void play() async {
    var docDir = await getApplicationDocumentsDirectory();
    String localPath = '${docDir.path}/flutter_sound.aac';
    Duration? totalDuration = await _audioPlayer.setFilePath(localPath);

    if (totalDuration != null) {
      await _audioPlayer.setSpeed(1.2);
      _audioPlayer.play();
      await _audioPlayer.seek(state.pausedAt);
      emit(AudioPlayerState.playing(state, totalDuration));
    }
  }

  void stopPlay() async {
    await _audioPlayer.stop();
    emit(AudioPlayerState.stopped(state));
  }

  void seek(Duration newPosition) async {
    await _audioPlayer.seek(newPosition);
    emit(AudioPlayerState.seek(state, newPosition));
  }

  void pause() async {
    await _audioPlayer.pause();
    emit(AudioPlayerState.paused(state, state.progress));
  }

  void fwd() async {
    Duration newPosition =
        Duration(milliseconds: state.progress.inMilliseconds + 15000);
    await _audioPlayer.seek(newPosition);
    emit(AudioPlayerState.seek(state, newPosition));
  }

  void rew() async {
    Duration newPosition =
        Duration(milliseconds: state.progress.inMilliseconds - 15000);
    await _audioPlayer.seek(newPosition);
    emit(AudioPlayerState.seek(state, newPosition));
  }

  @override
  Future<void> close() async {
    super.close();
    _audioPlayer.dispose();
  }
}
