// ignore_for_file: avoid_setters_without_getters

import 'dart:async';

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/speech/model/audio_player_state.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/window_service.dart';
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
PlayerFactory playerFactory(Ref ref) {
  return Player.new;
}

/// Notifier managing audio player state.
/// Marked as keepAlive since audio state should persist for the entire app
/// lifecycle.
///
/// The underlying media_kit [Player] is created lazily on the first
/// `setAudioNote`/`play` call and torn down again when playback completes.
/// Keeping the native mpv core thread out of memory between active sessions
/// makes Flutter hot restart safe whenever audio is not actively playing.
/// (mpv's `core_thread` invokes FFI callbacks asynchronously; if the Dart
/// VM is torn down by hot restart while the thread is alive, the trampolines
/// it calls into are gone and the process aborts with
/// "Callback invoked after it has been deleted".)
@Riverpod(keepAlive: true)
class AudioPlayerController extends _$AudioPlayerController {
  /// Tracks the active Player instance so the shutdown path can dispose it
  /// without going through Riverpod (which doesn't run disposal on
  /// `exit()`/`_exit()`).
  static Player? _activePlayer;

  Player? _audioPlayer;
  bool _hasOpenAudio = false;
  LoggingService? _loggingService;
  Duration _completionDelay = const Duration(
    milliseconds: AudioPlayerConstants.completionDelayMs,
  );

  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _bufferSubscription;
  StreamSubscription<bool>? _completedSubscription;
  Timer? _completionTimer;

  @visibleForTesting
  StreamSubscription<bool>? get completedSubscription => _completedSubscription;

  @override
  AudioPlayerState build() {
    ref.onDispose(_cleanup);
    _initLogging();
    return const AudioPlayerState();
  }

  void _initLogging() {
    try {
      _loggingService = getIt<LoggingService>();
    } catch (_) {
      // No LoggingService registered — nothing we can log this miss to.
      // Production startup always registers it, so this catch is purely
      // defensive against test/dev edge cases where the controller is
      // constructed before service wiring.
    }
  }

  /// Lazily constructs the underlying media_kit [Player] and wires its event
  /// streams. Returns the existing instance if one is already alive.
  ///
  /// Player construction spins up mpv's native `core_thread`. Deferring it
  /// until the user actually triggers playback keeps Flutter hot restart
  /// safe in any session where audio is never opened.
  ///
  /// Subscriptions are wired *before* caching the instance so a failure
  /// midway through never leaves a half-initialized player visible to later
  /// callers; on failure the partially-constructed player is disposed.
  Player? _ensurePlayer() {
    final existing = _audioPlayer;
    if (existing != null) return existing;
    Player? createdPlayer;
    try {
      final factory = ref.read(playerFactoryProvider);
      final player = createdPlayer = factory();
      _setupSubscriptions(player);
      _audioPlayer = player;
      _activePlayer = player;
      return player;
    } catch (exception, stackTrace) {
      if (createdPlayer != null) {
        unawaited(createdPlayer.dispose());
      }
      _loggingService?.captureException(
        exception,
        domain: 'audio_player_controller',
        subDomain: 'ensurePlayer',
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Test hook for triggering lazy player construction without having to
  /// invoke a stateful action method (which would emit additional states).
  @visibleForTesting
  void ensurePlayerForTest() {
    _ensurePlayer();
  }

  void _setupSubscriptions(Player player) {
    _positionSubscription = player.stream.position.listen(updateProgress);
    _bufferSubscription = player.stream.buffer.listen(_updateBuffered);
    _completedSubscription = player.stream.completed.listen(
      (isCompleted) => _handleCompleted(isCompleted: isCompleted),
    );
  }

  void _cleanup() {
    _completionTimer?.cancel();
    _completionTimer = null;
    _tearDownActivePlayer();
  }

  /// Tears down the live [Player] and its stream subscriptions. State (such
  /// as the currently selected [AudioPlayerState.audioNote]) is preserved
  /// so callers can transparently re-open the file on the next play.
  ///
  /// Stays synchronous so callers (Riverpod's `onDispose`, the completion
  /// timer) can rely on the [Player.dispose] call being issued before they
  /// return — only the resulting `Future` is unawaited.
  void _tearDownActivePlayer() {
    final player = _audioPlayer;
    if (player == null) return;
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _bufferSubscription?.cancel();
    _bufferSubscription = null;
    _completedSubscription?.cancel();
    _completedSubscription = null;
    // Only clear the static pointer if we own it — a newer controller may
    // have already replaced it, and nulling would break the shutdown path.
    if (identical(_activePlayer, player)) {
      _activePlayer = null;
    }
    _audioPlayer = null;
    _hasOpenAudio = false;
    unawaited(player.dispose());
  }

  /// Disposes the active media_kit Player for graceful shutdown.
  ///
  /// Called by [WindowService] before process exit to stop mpv's native
  /// core thread while the Dart VM is still alive. This prevents mpv from
  /// invoking FFI callbacks during VM teardown (which causes SIGABRT).
  ///
  /// Idempotent: safe to call even if no Player is active or already disposed.
  static Future<void> disposeActivePlayer() async {
    final player = _activePlayer;
    _activePlayer = null;
    await player?.dispose();
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
    final clamped = total > Duration.zero && buffered > total
        ? total
        : buffered;

    if (clamped == state.buffered) {
      return;
    }

    state = state.copyWith(buffered: clamped);
  }

  /// Sets the audio note to play and opens the media file.
  Future<void> setAudioNote(JournalAudio audioNote) async {
    try {
      if (state.audioNote == audioNote && _hasOpenAudio) {
        return;
      }

      // Cancel any pending completion timer from previous audio note
      _completionTimer?.cancel();
      _completionTimer = null;

      final player = _ensurePlayer();
      if (player == null) return;

      final localPath = await AudioUtils.getFullAudioPath(audioNote);
      final newState = AudioPlayerState(
        status: AudioPlayerStatus.stopped,
        totalDuration: audioNote.data.duration,
        audioNote: audioNote,
      );
      state = newState;
      await player.open(Media(localPath), play: false);
      _hasOpenAudio = true;
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
      // If a completion-delay timer from the previous run is still pending
      // it would otherwise fire mid-replay, tearing down the freshly
      // resumed player and flipping state back to stopped.
      _completionTimer?.cancel();
      _completionTimer = null;

      final player = _ensurePlayer();
      if (player == null) return;

      // After a completion-driven teardown the Player will have been
      // recreated above without any media loaded. Reopen the previously
      // selected audio note so the user can transparently replay.
      if (!_hasOpenAudio) {
        final audioNote = state.audioNote;
        if (audioNote != null) {
          final localPath = await AudioUtils.getFullAudioPath(audioNote);
          await player.open(Media(localPath), play: false);
          _hasOpenAudio = true;

          // Sync total duration from the actual media file in case it
          // diverges from the metadata stored on the audio note.
          final totalDuration = player.state.duration;
          state = state.copyWith(totalDuration: totalDuration);

          // Restore mid-track progress so a seek performed while the
          // player was torn down (or a partial-listen pause) is preserved
          // on replay. Progress at the very end of the track is treated
          // as a request to restart from the beginning.
          final progress = state.progress;
          if (progress > Duration.zero && progress < state.totalDuration) {
            await player.seek(progress);
          }
        }
      }

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
      final player = _ensurePlayer();
      if (player == null) return;

      // After a completion-driven teardown the Player has no media loaded
      // yet; calling player.seek before player.open is undefined. The
      // requested position is still recorded in state and will be applied
      // when play() reopens the file (see the reopen branch in play).
      if (_hasOpenAudio) {
        await player.seek(newPosition);
      }
      final newBuffered = newPosition > state.buffered
          ? newPosition
          : state.buffered;

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
      final player = _ensurePlayer();
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
      final player = _ensurePlayer();
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
    final audioNote = state.audioNote;
    final duration = audioNote?.data.duration;
    if (duration == null || audioNote == null) {
      return;
    }

    // Capture the audio note id to verify it hasn't changed when timer fires
    final capturedId = audioNote.meta.id;

    _completionTimer = Timer(
      _completionDelay,
      () {
        _completionTimer = null;
        // Verify the audio note hasn't been replaced before updating progress
        if (state.audioNote?.meta.id == capturedId) {
          state = state.copyWith(
            progress: duration,
            status: AudioPlayerStatus.stopped,
          );
        }
        // Tear down the live Player after playback completes so mpv's
        // core thread shuts down. State (audioNote/totalDuration) is
        // preserved so the next play() transparently reopens the file.
        _tearDownActivePlayer();
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

  /// Sets the state directly for testing purposes.
  @visibleForTesting
  set stateForTest(AudioPlayerState newState) {
    state = newState;
  }

  /// Pretends an audio file is already opened on the underlying Player so
  /// methods that gate on [_hasOpenAudio] (e.g. [seek]) exercise their
  /// file-loaded path without going through [setAudioNote] (which requires
  /// a real path resolvable by [AudioUtils.getFullAudioPath]).
  @visibleForTesting
  set hasOpenAudioForTest(bool value) {
    _hasOpenAudio = value;
  }
}
