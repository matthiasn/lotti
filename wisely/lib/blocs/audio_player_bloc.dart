import 'package:bloc/bloc.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

abstract class AudioPlayerEvent {}

class PlayEvent extends AudioPlayerEvent {}

class StopPlayEvent extends AudioPlayerEvent {}

class PausePlayEvent extends AudioPlayerEvent {}

class FwdPlayEvent extends AudioPlayerEvent {}

class RewPlayEvent extends AudioPlayerEvent {}

class AudioPlayerState {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool isPlaying = false;

  Duration totalDuration = Duration(minutes: 0);
  Duration progress = Duration(minutes: 0);
  Duration pausedAt = Duration(minutes: 0);

  AudioPlayerState() {
    _audioPlayer.positionStream.listen((event) {
      progress = event;
    });
    _audioPlayer.playbackEventStream.listen((event) {
      print(event);
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
  }

  Future<void> playLocal() async {
    var docDir = await getApplicationDocumentsDirectory();
    String localPath = '${docDir.path}/flutter_sound.aac';
    Duration? duration = await _audioPlayer.setFilePath(localPath);
    if (duration != null) {
      totalDuration = duration;
    }
    print('Player PLAY duration: ${totalDuration}');
    await _audioPlayer.setSpeed(1.2);

    _audioPlayer.play();
    await _audioPlayer.seek(pausedAt);
    print('PLAY from progress: $progress');

    isPlaying = true;
  }

  Future<void> stopPlayer() async {
    await _audioPlayer.stop();
    isPlaying = false;
    progress = Duration(minutes: 0);
    print('Player STOP');
  }

  void pause() async {
    await _audioPlayer.pause();
    pausedAt = progress;
    print('Player PAUSE');
  }

  void forward() async {
    await _audioPlayer
        .seek(Duration(milliseconds: progress.inMilliseconds + 15000));
    print('Player FORWARD 15s');
  }

  void rewind() async {
    await _audioPlayer
        .seek(Duration(milliseconds: progress.inMilliseconds - 15000));
    print('Player REWIND 15s');
  }
}

class AudioPlayerBloc extends Bloc<AudioPlayerEvent, AudioPlayerState> {
  AudioPlayerBloc() : super(AudioPlayerState()) {
    on<PlayEvent>((event, emit) {
      emit(state);
    });
    on<StopPlayEvent>((event, emit) => emit(state));
    on<PausePlayEvent>((event, emit) => emit(state));
    on<FwdPlayEvent>((event, emit) => emit(state));
    on<RewPlayEvent>((event, emit) => emit(state));
  }
}
