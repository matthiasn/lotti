import 'package:bloc/bloc.dart';
import 'package:lotti/blocs/audio/player_state.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/asr_service.dart';
import 'package:lotti/utils/audio_utils.dart';
import 'package:lotti/widgets/journal/entry_tools.dart';
import 'package:media_kit/media_kit.dart';

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
    _audioPlayer.streams.position.listen(updateProgress);
  }

  final Player _audioPlayer = Player();
  final LoggingDb _loggingDb = getIt<LoggingDb>();
  final AsrService _asrService = getIt<AsrService>();

  void updateProgress(Duration duration) {
    emit(state.copyWith(progress: duration));
  }

  Future<void> setAudioNote(JournalAudio audioNote) async {
    try {
      if (state.audioNote == audioNote) {
        return;
      }

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
      await _audioPlayer.open(Media(localPath), play: false);
      final totalDuration = _audioPlayer.state.duration;
      emit(newState.copyWith(totalDuration: totalDuration));
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
      await _audioPlayer.setRate(state.speed);
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

  Future<void> transcribe() async {
    if (state.audioNote == null) {
      return;
    }

    await _asrService.transcribe(entry: state.audioNote!);
  }

  Future<void> stopPlay() async {
    try {
      await _audioPlayer.pause();
      await _audioPlayer.seek(Duration.zero);
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
      await _audioPlayer.setRate(speed);
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
