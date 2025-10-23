import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/speech/services/audio_waveform_service.dart';
import 'package:lotti/features/speech/state/player_state.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/audio_utils.dart';
import 'package:media_kit/media_kit.dart';

/// Constants for audio player configuration
class PlayerConstants {
  const PlayerConstants._();

  /// Delay before updating progress when playback completes
  static const int completionDelayMs = 50;
}

class AudioPlayerCubit extends Cubit<AudioPlayerState> {
  AudioPlayerCubit({AudioWaveformService? waveformService})
      : _waveformService = waveformService ?? getIt<AudioWaveformService>(),
        super(
          AudioPlayerState(
            status: AudioPlayerStatus.initializing,
            totalDuration: Duration.zero,
            progress: Duration.zero,
            pausedAt: Duration.zero,
            showTranscriptsList: false,
            speed: 1,
          ),
        ) {
    _positionSubscription = _audioPlayer.stream.position.listen(updateProgress);
    _bufferSubscription = _audioPlayer.stream.buffer.listen(_updateBuffered);
  }

  final Player _audioPlayer = Player();
  final LoggingService _loggingService = getIt<LoggingService>();
  final AudioWaveformService _waveformService;
  late final StreamSubscription<Duration> _positionSubscription;
  late final StreamSubscription<Duration> _bufferSubscription;
  int _waveformLoadToken = 0;

  void updateProgress(Duration duration) {
    final clamped =
        duration > state.totalDuration && state.totalDuration > Duration.zero
            ? state.totalDuration
            : duration;

    if (clamped == state.progress) {
      return;
    }

    emit(state.copyWith(progress: clamped));
  }

  void _updateBuffered(Duration buffered) {
    final total = state.totalDuration;
    final clamped =
        total > Duration.zero && buffered > total ? total : buffered;

    if (clamped == state.buffered) {
      return;
    }

    emit(
      state.copyWith(
        buffered: clamped,
      ),
    );
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
        totalDuration: audioNote.data.duration,
        showTranscriptsList: false,
        speed: 1,
        waveformStatus: AudioWaveformStatus.loading,
        audioNote: audioNote,
      );
      emit(newState);
      await _audioPlayer.open(Media(localPath), play: false);
      final totalDuration = _audioPlayer.state.duration;
      emit(newState.copyWith(totalDuration: totalDuration));
      _loadWaveform(audioNote);
    } catch (exception, stackTrace) {
      _loggingService.captureException(
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
      emit(state.copyWith(status: AudioPlayerStatus.playing));

      _audioPlayer.stream.completed.listen((completed) {
        final duration = state.audioNote?.data.duration;
        if (completed && duration != null) {
          Timer(const Duration(milliseconds: PlayerConstants.completionDelayMs),
              () {
            emit(state.copyWith(progress: duration));
          });
        }
      });
    } catch (exception, stackTrace) {
      _loggingService.captureException(
        exception,
        domain: 'player_cubit',
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> seek(Duration newPosition) async {
    try {
      await _audioPlayer.seek(newPosition);
      final newBuffered =
          newPosition > state.buffered ? newPosition : state.buffered;

      if (newPosition == state.progress &&
          newPosition == state.pausedAt &&
          newBuffered == state.buffered) {
        return;
      }
      emit(
        state.copyWith(
          progress: newPosition,
          pausedAt: newPosition,
          buffered: newBuffered,
        ),
      );
    } catch (exception, stackTrace) {
      _loggingService.captureException(
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
      _loggingService.captureException(
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
      _loggingService.captureException(
        exception,
        domain: 'player_cubit',
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<void> close() async {
    await _positionSubscription.cancel();
    await _bufferSubscription.cancel();
    await _audioPlayer.dispose();
    await super.close();
  }

  void _loadWaveform(JournalAudio audioNote) {
    final loadToken = ++_waveformLoadToken;
    unawaited(() async {
      try {
        final waveform = await _waveformService.loadWaveform(audioNote);
        if (_waveformLoadToken != loadToken) {
          return;
        }
        if (waveform == null) {
          emit(
            state.copyWith(
              waveformStatus: AudioWaveformStatus.unavailable,
              waveform: const <double>[],
              waveformBucketDuration: Duration.zero,
            ),
          );
          return;
        }
        if (state.audioNote?.meta.id != audioNote.meta.id) {
          return;
        }
        emit(
          state.copyWith(
            waveformStatus: AudioWaveformStatus.ready,
            waveform: waveform.amplitudes,
            waveformBucketDuration: waveform.bucketDuration,
          ),
        );
      } catch (error, stackTrace) {
        if (_waveformLoadToken != loadToken) {
          return;
        }
        _loggingService.captureException(
          error,
          domain: 'player_cubit',
          subDomain: 'waveform_load',
          stackTrace: stackTrace,
        );
        emit(
          state.copyWith(
            waveformStatus: AudioWaveformStatus.unavailable,
            waveform: const <double>[],
            waveformBucketDuration: Duration.zero,
          ),
        );
      }
    }());
  }
}
