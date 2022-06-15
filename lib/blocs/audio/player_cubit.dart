import 'package:bloc/bloc.dart';
import 'package:just_audio/just_audio.dart';
import 'package:lotti/blocs/audio/player_state.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/utils/audio_utils.dart';
import 'package:lotti/widgets/journal/entry_tools.dart';

class AudioPlayerCubit extends Cubit<AudioPlayerState> {
  AudioPlayerCubit()
      : super(
          AudioPlayerState(
            status: AudioPlayerStatus.initializing,
            totalDuration: Duration.zero,
            progress: Duration.zero,
            pausedAt: Duration.zero,
            speed: 1,
          ),
        ) {
    _audioPlayer.positionStream.listen(updateProgress);
    _audioPlayer.playbackEventStream.listen((event) {
      if (event.processingState == ProcessingState.completed) {
        stopPlay();
      }
    });
  }

  final AudioPlayer _audioPlayer = AudioPlayer();
  final LoggingDb _loggingDb = getIt<LoggingDb>();

  void updateProgress(Duration duration) {
    emit(state.copyWith(progress: duration));
  }

  Future<void> setAudioNote(JournalAudio audioNote) async {
    try {
      final localPath = await AudioUtils.getFullAudioPath(audioNote);
      final newState = AudioPlayerState(
        status: AudioPlayerStatus.stopped,
        progress: Duration.zero,
        pausedAt: Duration.zero,
        totalDuration: entryDuration(audioNote),
        speed: 1,
        audioNote: audioNote,
      );
      emit(newState);

      final totalDuration = await _audioPlayer.setFilePath(localPath);
      if (totalDuration != null) {
        emit(newState.copyWith(totalDuration: totalDuration));
      }
    } catch (exception, stackTrace) {
      _loggingDb.captureException(
        exception,
        domain: 'player_cubit',
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> play() async {
    try {
      await _audioPlayer.setSpeed(state.speed);
      await _audioPlayer.play();
      await _audioPlayer.seek(state.pausedAt);
      emit(state.copyWith(status: AudioPlayerStatus.playing));
    } catch (exception, stackTrace) {
      _loggingDb.captureException(
        exception,
        domain: 'player_cubit',
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> stopPlay() async {
    try {
      await _audioPlayer.stop();
      emit(
        state.copyWith(
          status: AudioPlayerStatus.stopped,
          progress: Duration.zero,
        ),
      );
    } catch (exception, stackTrace) {
      _loggingDb.captureException(
        exception,
        domain: 'player_cubit',
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> seek(Duration newPosition) async {
    try {
      await _audioPlayer.seek(newPosition);
      emit(
        state.copyWith(
          progress: newPosition,
          pausedAt: newPosition,
        ),
      );
    } catch (exception, stackTrace) {
      _loggingDb.captureException(
        exception,
        domain: 'player_cubit',
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> setSpeed(double speed) async {
    try {
      await _audioPlayer.setSpeed(speed);
      emit(state.copyWith(speed: speed));
    } catch (exception, stackTrace) {
      _loggingDb.captureException(
        exception,
        domain: 'player_cubit',
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> pause() async {
    try {
      await _audioPlayer.pause();
      emit(
        state.copyWith(
          status: AudioPlayerStatus.paused,
          pausedAt: state.progress,
        ),
      );
    } catch (exception, stackTrace) {
      _loggingDb.captureException(
        exception,
        domain: 'player_cubit',
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> fwd() async {
    try {
      final newPosition =
          Duration(milliseconds: state.progress.inMilliseconds + 15000);
      await _audioPlayer.seek(newPosition);
      emit(
        state.copyWith(
          progress: newPosition,
          pausedAt: newPosition,
        ),
      );
    } catch (exception, stackTrace) {
      _loggingDb.captureException(
        exception,
        domain: 'player_cubit',
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> rew() async {
    try {
      final newPosition =
          Duration(milliseconds: state.progress.inMilliseconds - 15000);
      await _audioPlayer.seek(newPosition);
      emit(
        state.copyWith(
          progress: newPosition,
          pausedAt: newPosition,
        ),
      );
    } catch (exception, stackTrace) {
      _loggingDb.captureException(
        exception,
        domain: 'player_cubit',
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<void> close() async {
    await super.close();
    await _audioPlayer.dispose();
  }
}
