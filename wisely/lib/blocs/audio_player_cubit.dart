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

  AudioPlayerState.playing(AudioPlayerState other, Duration totalDuration) {
    status = AudioPlayerStatus.playing;
    totalDuration = totalDuration;
    progress = other.progress;
  }

  AudioPlayerState.stopped(AudioPlayerState other) {
    status = AudioPlayerStatus.stopped;
  }

  AudioPlayerState.paused(AudioPlayerState other, Duration pausedAt) {
    status = AudioPlayerStatus.paused;
    totalDuration = other.totalDuration;
    progress = other.progress;
    pausedAt = progress;
  }

  AudioPlayerState.progress(AudioPlayerState other, Duration duration) {
    status = other.status;
    progress = duration;
    totalDuration = other.totalDuration;
  }

  @override
  // TODO: implement props
  List<Object?> get props => [status, totalDuration, progress];
}

class AudioPlayerCubit extends Cubit<AudioPlayerState> {
  final AudioPlayer _audioPlayer = AudioPlayer();

  AudioPlayerCubit() : super(AudioPlayerState()) {
    _audioPlayer.positionStream.listen((event) {
      updateProgress(event);
    });
    _audioPlayer.playbackEventStream.listen((event) {
      print(event);
    });
  }

  void updateProgress(Duration duration) {
    emit(AudioPlayerState.progress(state, duration));
  }

  void play() async {
    var docDir = await getApplicationDocumentsDirectory();
    String localPath = '${docDir.path}/flutter_sound.aac';
    Duration? duration = await _audioPlayer.setFilePath(localPath);

    if (duration != null) {
      await _audioPlayer.setSpeed(1.2);
      _audioPlayer.play();
      await _audioPlayer.seek(state.pausedAt);
      emit(AudioPlayerState.playing(state, duration));
    }
  }

  void stopPlay() async {
    await _audioPlayer.stop();
    emit(AudioPlayerState.stopped(state));
  }

  void seek(Duration newPosition) async {
    await _audioPlayer.seek(newPosition);
  }

  void pause() async {
    await _audioPlayer.pause();
    emit(AudioPlayerState.paused(state, state.progress));
  }

  void fwd() async {
    await _audioPlayer
        .seek(Duration(milliseconds: state.progress.inMilliseconds + 15000));
  }

  void rew() async {
    await _audioPlayer
        .seek(Duration(milliseconds: state.progress.inMilliseconds - 15000));
  }

  @override
  Future<void> close() async {
    super.close();
    _audioPlayer.dispose();
  }
}
