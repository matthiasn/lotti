import 'dart:async';

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/speech/model/audio_player_state.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/audio_utils.dart';
import 'package:media_kit/media_kit.dart';
import 'package:meta/meta.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'audio_player_controller.g.dart';

/// Constants for audio player configuration
class AudioPlayerConstants {
  const AudioPlayerConstants._();

  /// Delay before updating progress when playback completes
  static const int completionDelayMs = 50;
}

/// Factory function type for creating Player instances.
/// This allows injection of mock players for testing.
typedef PlayerFactory = Player Function();

/// Provider for the player factory, can be overridden in tests.
@Riverpod(keepAlive: true)
PlayerFactory playerFactory(PlayerFactoryRef ref) {
  return Player.new;
}

/// Notifier managing audio player state.
/// Marked as keepAlive since audio state should persist for the entire app
/// lifecycle.
@Riverpod(keepAlive: true)
class AudioPlayerController extends _$AudioPlayerController {
  Player? _audioPlayer;
  LoggingService? _loggingService;
  Duration _completionDelay =
      const Duration(milliseconds: AudioPlayerConstants.completionDelayMs);

  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _bufferSubscription;
  StreamSubscription<bool>? _completedSubscription;
  Timer? _completionTimer;

  @visibleForTesting
  StreamSubscription<bool>? get completedSubscription => _completedSubscription;

  @override
  AudioPlayerState build() {
    ref.onDispose(_cleanup);
    _init();
    return const AudioPlayerState();
  }

  void _init() {
    try {
      final factory = ref.read(playerFactoryProvider);
      _audioPlayer = factory();
      _loggingService = getIt<LoggingService>();
      _setupSubscriptions();
    } catch (exception, stackTrace) {
      _loggingService?.captureException(
        exception,
        domain: 'audio_player_controller',
        subDomain: 'init',
        stackTrace: stackTrace,
      );
    }
  }

  void _setupSubscriptions() {
    final player = _audioPlayer;
    if (player == null) return;

    _positionSubscription = player.stream.position.listen(updateProgress);
    _bufferSubscription = player.stream.buffer.listen(_updateBuffered);
    _completedSubscription = player.stream.completed.listen(
      (isCompleted) => _handleCompleted(isCompleted: isCompleted),
    );
  }

  void _cleanup() {
    _completionTimer?.cancel();
    _completionTimer = null;
    _positionSubscription?.cancel();
    _bufferSubscription?.cancel();
    _completedSubscription?.cancel();
    _audioPlayer?.dispose();
  }

  /// Updates the progress from the player's position stream.
  void updateProgress(Duration duration) {
    final clamped =
        duration > state.totalDuration && state.totalDuration > Duration.zero
            ? state.totalDuration
            : duration;

    if (clamped == state.progress) {
      return;
    }

    state = state.copyWith(progress: clamped);
  }

  void _updateBuffered(Duration buffered) {
    final total = state.totalDuration;
    final clamped =
        total > Duration.zero && buffered > total ? total : buffered;

    if (clamped == state.buffered) {
      return;
    }

    state = state.copyWith(buffered: clamped);
  }

  /// Sets the audio note to play and opens the media file.
  Future<void> setAudioNote(JournalAudio audioNote) async {
    try {
      if (state.audioNote == audioNote) {
        return;
      }

      final player = _audioPlayer;
      if (player == null) return;

      final localPath = await AudioUtils.getFullAudioPath(audioNote);
      final newState = AudioPlayerState(
        status: AudioPlayerStatus.stopped,
        totalDuration: audioNote.data.duration,
        audioNote: audioNote,
      );
      state = newState;
      await player.open(Media(localPath), play: false);
      final totalDuration = player.state.duration;
      state = state.copyWith(totalDuration: totalDuration);
    } catch (exception, stackTrace) {
      _loggingService?.captureException(
        exception,
        domain: 'audio_player_controller',
        subDomain: 'setAudioNote',
        stackTrace: stackTrace,
      );
    }
  }

  /// Starts or resumes playback.
  Future<void> play() async {
    try {
      final player = _audioPlayer;
      if (player == null) return;

      await player.setRate(state.speed);
      await player.play();
      state = state.copyWith(status: AudioPlayerStatus.playing);
    } catch (exception, stackTrace) {
      _loggingService?.captureException(
        exception,
        domain: 'audio_player_controller',
        subDomain: 'play',
        stackTrace: stackTrace,
      );
    }
  }

  /// Seeks to the specified position.
  Future<void> seek(Duration newPosition) async {
    try {
      final player = _audioPlayer;
      if (player == null) return;

      await player.seek(newPosition);
      final newBuffered =
          newPosition > state.buffered ? newPosition : state.buffered;

      if (newPosition == state.progress &&
          newPosition == state.pausedAt &&
          newBuffered == state.buffered) {
        return;
      }
      state = state.copyWith(
        progress: newPosition,
        pausedAt: newPosition,
        buffered: newBuffered,
      );
    } catch (exception, stackTrace) {
      _loggingService?.captureException(
        exception,
        domain: 'audio_player_controller',
        subDomain: 'seek',
        stackTrace: stackTrace,
      );
    }
  }

  /// Sets the playback speed.
  Future<void> setSpeed(double speed) async {
    try {
      final player = _audioPlayer;
      if (player == null) return;

      await player.setRate(speed);
      state = state.copyWith(speed: speed);
    } catch (exception, stackTrace) {
      _loggingService?.captureException(
        exception,
        domain: 'audio_player_controller',
        subDomain: 'setSpeed',
        stackTrace: stackTrace,
      );
    }
  }

  /// Pauses playback.
  Future<void> pause() async {
    try {
      final player = _audioPlayer;
      if (player == null) return;

      await player.pause();
      state = state.copyWith(
        status: AudioPlayerStatus.paused,
        pausedAt: state.progress,
      );
    } catch (exception, stackTrace) {
      _loggingService?.captureException(
        exception,
        domain: 'audio_player_controller',
        subDomain: 'pause',
        stackTrace: stackTrace,
      );
    }
  }

  void _handleCompleted({required bool isCompleted}) {
    if (!isCompleted) {
      return;
    }
    if (_completionTimer?.isActive ?? false) {
      return;
    }
    final duration = state.audioNote?.data.duration;
    if (duration == null) {
      return;
    }

    _completionTimer = Timer(
      _completionDelay,
      () {
        _completionTimer = null;
        state = state.copyWith(progress: duration);
      },
    );
  }

  /// Exposes completion handling for testing.
  @visibleForTesting
  void handleCompletedForTest({required bool isCompleted}) =>
      _handleCompleted(isCompleted: isCompleted);

  /// Gets the current completion delay (for testing).
  @visibleForTesting
  Duration get completionDelayForTest => _completionDelay;

  /// Sets a custom completion delay for testing.
  @visibleForTesting
  set completionDelayForTest(Duration delay) {
    _completionDelay = delay;
  }
}
