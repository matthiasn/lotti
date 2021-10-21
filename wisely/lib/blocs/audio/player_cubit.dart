import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:just_audio/just_audio.dart';
import 'package:wisely/db/audio_note.dart';
import 'package:wisely/utils/audio_utils.dart';

enum AudioPlayerStatus { initializing, initialized, playing, paused, stopped }

class AudioPlayerState extends Equatable {
  AudioPlayerStatus status = AudioPlayerStatus.initializing;
  Duration totalDuration = Duration(minutes: 0);
  Duration progress = Duration(minutes: 0);
  Duration pausedAt = Duration(minutes: 0);
  AudioNote? audioNote;

  AudioPlayerState() {}

  AudioPlayerState.playing(AudioPlayerState other) {
    status = AudioPlayerStatus.playing;
    totalDuration = other.totalDuration;
    progress = other.progress;
    audioNote = other.audioNote;
  }

  AudioPlayerState.stopped(AudioPlayerState other) {
    status = AudioPlayerStatus.stopped;
    totalDuration = other.totalDuration;
    progress = Duration(minutes: 0);
    audioNote = other.audioNote;
  }

  AudioPlayerState.setAudioNote(
      AudioPlayerState other, AudioNote newAudioNote, Duration duration) {
    status = AudioPlayerStatus.stopped;
    totalDuration = duration;
    progress = Duration(minutes: 0);
    pausedAt = Duration(minutes: 0);
    audioNote = newAudioNote;
  }

  AudioPlayerState.paused(AudioPlayerState other, Duration duration) {
    status = AudioPlayerStatus.paused;
    totalDuration = other.totalDuration;
    progress = other.progress;
    pausedAt = duration;
    audioNote = other.audioNote;
  }

  AudioPlayerState.seek(AudioPlayerState other, Duration duration) {
    status = other.status;
    totalDuration = other.totalDuration;
    progress = duration;
    pausedAt = duration;
    audioNote = other.audioNote;
  }

  AudioPlayerState.progress(AudioPlayerState other, Duration duration) {
    status = other.status;
    progress = duration;
    totalDuration = other.totalDuration;
    pausedAt = other.pausedAt;
    audioNote = other.audioNote;
  }

  @override
  List<Object?> get props =>
      [status, totalDuration, progress, pausedAt, audioNote];
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

  void setAudioNote(AudioNote audioNote) async {
    String localPath = await AudioUtils.getFullAudioPath(audioNote);
    print(localPath);

    emit(AudioPlayerState.setAudioNote(state, audioNote, Duration(minutes: 0)));

    Duration? totalDuration = await _audioPlayer.setFilePath(localPath);
    if (totalDuration != null) {
      emit(AudioPlayerState.setAudioNote(state, audioNote, totalDuration));
    }
  }

  void play() async {
    await _audioPlayer.setSpeed(1.2);
    _audioPlayer.play();
    await _audioPlayer.seek(state.pausedAt);
    emit(AudioPlayerState.playing(state));
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
