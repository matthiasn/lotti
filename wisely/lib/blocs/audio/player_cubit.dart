import 'package:bloc/bloc.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:just_audio/just_audio.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
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
        totalDuration: const Duration(minutes: 0),
        audioNote: audioNote,
      );
      emit(newState);

      Duration? totalDuration = await _audioPlayer.setFilePath(localPath);
      if (totalDuration != null) {
        emit(newState.copyWith(totalDuration: totalDuration));
      }
    } catch (exception, stackTrace) {
      await Sentry.captureException(exception, stackTrace: stackTrace);
    }
  }

  void play() async {
    try {
      await _audioPlayer.setSpeed(1.2);
      _audioPlayer.play();
      await _audioPlayer.seek(state.pausedAt);
      emit(state.copyWith(status: AudioPlayerStatus.playing));
    } catch (exception, stackTrace) {
      await Sentry.captureException(exception, stackTrace: stackTrace);
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
      await Sentry.captureException(exception, stackTrace: stackTrace);
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
      await Sentry.captureException(exception, stackTrace: stackTrace);
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
      await Sentry.captureException(exception, stackTrace: stackTrace);
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
      await Sentry.captureException(exception, stackTrace: stackTrace);
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
      await Sentry.captureException(exception, stackTrace: stackTrace);
    }
  }

  @override
  Future<void> close() async {
    super.close();
    _audioPlayer.dispose();
  }
}
