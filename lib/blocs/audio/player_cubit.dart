import 'package:bloc/bloc.dart';
import 'package:just_audio/just_audio.dart';
import 'package:lotti/blocs/audio/player_state.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/utils/audio_utils.dart';
import 'package:lotti/widgets/journal/entry_tools.dart';

class AudioPlayerCubit extends Cubit<AudioPlayerState> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final LoggingDb _loggingDb = getIt<LoggingDb>();

  AudioPlayerCubit()
      : super(AudioPlayerState(
          status: AudioPlayerStatus.initializing,
          totalDuration: const Duration(minutes: 0),
          progress: const Duration(minutes: 0),
          pausedAt: const Duration(minutes: 0),
          speed: 1.0,
        )) {
    _audioPlayer.positionStream.listen((event) {
      updateProgress(event);
    });
    _audioPlayer.playbackEventStream.listen((event) {
      if (event.processingState == ProcessingState.completed) {
        stopPlay();
      }
    });
  }

  void updateProgress(Duration duration) {
    emit(state.copyWith(progress: duration));
  }

  void setAudioNote(JournalAudio audioNote) async {
    try {
      String localPath = await AudioUtils.getFullAudioPath(audioNote);
      AudioPlayerState newState = AudioPlayerState(
        status: AudioPlayerStatus.stopped,
        progress: const Duration(minutes: 0),
        pausedAt: const Duration(minutes: 0),
        totalDuration: entryDuration(audioNote),
        speed: 1.0,
        audioNote: audioNote,
      );
      emit(newState);

      Duration? totalDuration = await _audioPlayer.setFilePath(localPath);
      if (totalDuration != null) {
        emit(newState.copyWith(totalDuration: totalDuration));
      }
    } catch (exception, stackTrace) {
      await _loggingDb.captureException(
        exception,
        domain: 'player_cubit',
        stackTrace: stackTrace,
      );
    }
  }

  void play() async {
    try {
      await _audioPlayer.setSpeed(state.speed);
      _audioPlayer.play();
      await _audioPlayer.seek(state.pausedAt);
      emit(state.copyWith(status: AudioPlayerStatus.playing));
    } catch (exception, stackTrace) {
      await _loggingDb.captureException(
        exception,
        domain: 'player_cubit',
        stackTrace: stackTrace,
      );
    }
  }

  void stopPlay() async {
    try {
      await _audioPlayer.stop();
      emit(state.copyWith(
        status: AudioPlayerStatus.stopped,
        progress: const Duration(minutes: 0),
      ));
    } catch (exception, stackTrace) {
      await _loggingDb.captureException(
        exception,
        domain: 'player_cubit',
        stackTrace: stackTrace,
      );
    }
  }

  void seek(Duration newPosition) async {
    try {
      await _audioPlayer.seek(newPosition);
      emit(state.copyWith(
        progress: newPosition,
        pausedAt: newPosition,
      ));
    } catch (exception, stackTrace) {
      await _loggingDb.captureException(
        exception,
        domain: 'player_cubit',
        stackTrace: stackTrace,
      );
    }
  }

  void setSpeed(double speed) async {
    try {
      await _audioPlayer.setSpeed(speed);
      emit(state.copyWith(speed: speed));
    } catch (exception, stackTrace) {
      await _loggingDb.captureException(
        exception,
        domain: 'player_cubit',
        stackTrace: stackTrace,
      );
    }
  }

  void pause() async {
    try {
      await _audioPlayer.pause();
      emit(state.copyWith(
        status: AudioPlayerStatus.paused,
        pausedAt: state.progress,
      ));
    } catch (exception, stackTrace) {
      await _loggingDb.captureException(
        exception,
        domain: 'player_cubit',
        stackTrace: stackTrace,
      );
    }
  }

  void fwd() async {
    try {
      Duration newPosition =
          Duration(milliseconds: state.progress.inMilliseconds + 15000);
      await _audioPlayer.seek(newPosition);
      emit(state.copyWith(
        progress: newPosition,
        pausedAt: newPosition,
      ));
    } catch (exception, stackTrace) {
      await _loggingDb.captureException(
        exception,
        domain: 'player_cubit',
        stackTrace: stackTrace,
      );
    }
  }

  void rew() async {
    try {
      Duration newPosition =
          Duration(milliseconds: state.progress.inMilliseconds - 15000);
      await _audioPlayer.seek(newPosition);
      emit(state.copyWith(
        progress: newPosition,
        pausedAt: newPosition,
      ));
    } catch (exception, stackTrace) {
      await _loggingDb.captureException(
        exception,
        domain: 'player_cubit',
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<void> close() async {
    super.close();
    _audioPlayer.dispose();
  }
}
