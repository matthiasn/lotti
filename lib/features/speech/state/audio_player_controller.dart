// ignore_for_file: avoid_setters_without_getters

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/speech/model/audio_player_state.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/window_service.dart';
import 'package:lotti/utils/audio_utils.dart';
import 'package:media_kit/media_kit.dart';
import 'package:meta/meta.dart';

/// Tunable timings for [AudioPlayerController] playback handling.
class AudioPlayerConstants {
  const AudioPlayerConstants._();

  /// Delay before updating progress when playback completes
  static const int completionDelayMs = 50;

  /// How long a queued operation waits for the one ahead of it before giving
  /// up on the [Player] they were both going to share.
  ///
  /// mpv can hang: `AudioMetadataExtractor.extractDuration` already bounds
  /// its own `open` for that reason. Without a bound here a single stuck
  /// call would wedge the queue for the rest of the session, taking `pause`,
  /// `seek` and every later `play` down with it. Waiting it out is not an
  /// option either — a Player stuck inside `open` will not play anything for
  /// the next operation either, so running that operation against it would
  /// only let the stuck native call land *after* the newer one and leave the
  /// wrong recording loaded. The timeout therefore abandons the player rather
  /// than sharing it; see [AudioPlayerController._abandonStuckPlayer].
  static const Duration operationQueueTimeout = Duration(seconds: 10);
}

/// Factory function type for creating Player instances.
/// This allows injection of mock players for testing.
typedef PlayerFactory = Player Function();

/// Provider for the player factory, can be overridden in tests.
final playerFactoryProvider = Provider<PlayerFactory>(
  playerFactory,
  name: 'playerFactoryProvider',
);
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
final audioPlayerControllerProvider =
    NotifierProvider<AudioPlayerController, AudioPlayerState>(
      AudioPlayerController.new,
      name: 'audioPlayerControllerProvider',
    );

class AudioPlayerController extends Notifier<AudioPlayerState> {
  /// Tracks the active Player instance so the shutdown path can dispose it
  /// without going through Riverpod (which doesn't run disposal on
  /// `exit()`/`_exit()`).
  static Player? _activePlayer;

  Player? _audioPlayer;
  bool _hasOpenAudio = false;
  DomainLogger? _loggingService;
  Duration _completionDelay = const Duration(
    milliseconds: AudioPlayerConstants.completionDelayMs,
  );

  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _bufferSubscription;
  StreamSubscription<bool>? _completedSubscription;
  Timer? _completionTimer;

  /// Tail of the queue every player-mutating operation runs on.
  ///
  /// The media_kit [Player] is a single shared device: two operations that
  /// interleave across their `await`s issue their `open`/`play` calls in an
  /// order neither of them chose. Chaining them makes each one observe the
  /// finished state of the previous, so `play` can never act on the
  /// half-applied result of a `setAudioNote` that is still in flight.
  Future<void> _operationQueue = Future<void>.value();

  /// Incremented whenever the selected note is replaced or the live [Player]
  /// is torn down.
  ///
  /// An operation captures this on entry and compares it after every `await`
  /// (see [_isSuperseded]): the completion timer and provider disposal both
  /// tear the player down without going through [_operationQueue], so an
  /// in-flight operation can find its player gone — or its note replaced —
  /// halfway through, and must abandon its remaining work rather than issue
  /// it against a disposed player or clobber a newer selection.
  int _generation = 0;

  @visibleForTesting
  StreamSubscription<bool>? get completedSubscription => _completedSubscription;

  /// Runs [operation] once every previously queued operation has settled, or
  /// after [AudioPlayerConstants.operationQueueTimeout] if one of them hangs.
  ///
  /// The returned future carries [operation]'s own outcome. The queue tail is
  /// a separate completer that is always finished normally, so one operation
  /// failing reports to its own caller and cannot wedge every later request
  /// behind an unhandled error.
  ///
  /// **Not re-entrant.** [operation] must call the private `_`-prefixed
  /// bodies ([_setAudioNote], [_play], …), never the public wrappers: a
  /// public method invoked from inside a running operation would wait on a
  /// queue tail that only completes once that same operation returns, and
  /// hang until the timeout above rescues it.
  Future<void> _serialize(Future<void> Function() operation) async {
    final previous = _operationQueue;
    final stuckPlayer = _audioPlayer;
    final finished = Completer<void>();
    _operationQueue = finished.future;
    await previous.timeout(
      AudioPlayerConstants.operationQueueTimeout,
      onTimeout: () => _abandonStuckPlayer(stuckPlayer),
    );
    try {
      await operation();
    } finally {
      finished.complete();
    }
  }

  /// Gives up on [player] after the operation holding it stopped responding.
  ///
  /// Disposing it — rather than handing it to the operation that has been
  /// waiting — is what keeps the timeout from reintroducing the race this
  /// queue exists to prevent: the stuck native call cannot be cancelled, so
  /// sharing the instance would let it land after the newer `open` and leave
  /// the wrong recording loaded. Teardown bumps the generation instead, so
  /// every continuation of the stuck operation is superseded and returns
  /// without touching anything, and the waiting operation builds itself a
  /// fresh [Player] through [_ensurePlayer]. State (the selected note, the
  /// position) survives, so playback resumes on the next tap.
  ///
  /// No-op once [player] is no longer the live instance: with several
  /// operations queued behind one stuck call, each waits on its own timer, and
  /// only the first to fire should act. The rest would otherwise tear down the
  /// healthy player their predecessor just built.
  void _abandonStuckPlayer(Player? player) {
    if (player == null || !identical(_audioPlayer, player)) return;
    _completionTimer?.cancel();
    _completionTimer = null;
    _tearDownActivePlayer();
  }

  /// Whether the work started at [generation] against [player] is still the
  /// current work. Once it is not, the caller must stop touching the player.
  bool _isSuperseded(int generation, Player player) =>
      _generation != generation || !identical(_audioPlayer, player);

  @override
  AudioPlayerState build() {
    ref.onDispose(_cleanup);
    _initLogging();
    return const AudioPlayerState();
  }

  void _initLogging() {
    try {
      _loggingService = getIt<DomainLogger>();
    } catch (_) {
      // No DomainLogger registered — nothing we can log this miss to.
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
      _loggingService?.error(
        LogDomain.speech,
        exception,
        stackTrace: stackTrace,
        subDomain: 'ensurePlayer',
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
    // Any operation currently suspended on an await holds a reference to this
    // player; bumping the generation is what tells it to stop.
    _generation++;
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

  /// Selects [audioNote] and starts playing it.
  ///
  /// Selection and playback are queued as a **single** operation. Calling
  /// `setAudioNote(note)` and `play()` as two separate un-awaited calls is
  /// what used to make a freshly opened note play the previous one: `play`
  /// ran while `setAudioNote` was still suspended on its first `await`, read
  /// the not-yet-replaced `state.audioNote`, and re-opened the old file
  /// *after* `setAudioNote` had opened the new one. Every play-this-note
  /// caller must go through here rather than sequencing the two by hand.
  Future<void> playAudioNote(JournalAudio audioNote) => _serialize(() async {
    await _setAudioNote(audioNote);
    await _play();
  });

  /// Sets the audio note to play and opens the media file.
  Future<void> setAudioNote(JournalAudio audioNote) =>
      _serialize(() => _setAudioNote(audioNote));

  /// Starts or resumes playback.
  Future<void> play() => _serialize(_play);

  Future<void> _setAudioNote(JournalAudio audioNote) async {
    try {
      if (state.audioNote == audioNote && _hasOpenAudio) {
        return;
      }

      // Cancel any pending completion timer from previous audio note
      _completionTimer?.cancel();
      _completionTimer = null;

      final player = _ensurePlayer();
      if (player == null) return;

      final generation = ++_generation;
      final localPath = await AudioUtils.getFullAudioPath(audioNote);
      final newState = AudioPlayerState(
        status: AudioPlayerStatus.stopped,
        totalDuration: audioNote.data.duration,
        audioNote: audioNote,
      );
      state = newState;
      await player.open(Media(localPath), play: false);
      if (_isSuperseded(generation, player)) return;
      _hasOpenAudio = true;
      final totalDuration = player.state.duration;
      state = state.copyWith(totalDuration: totalDuration);
    } catch (exception, stackTrace) {
      _loggingService?.error(
        LogDomain.speech,
        exception,
        stackTrace: stackTrace,
        subDomain: 'setAudioNote',
      );
    }
  }

  Future<void> _play() async {
    try {
      // If a completion-delay timer from the previous run is still pending
      // it would otherwise fire mid-replay, tearing down the freshly
      // resumed player and flipping state back to stopped.
      _completionTimer?.cancel();
      _completionTimer = null;

      final player = _ensurePlayer();
      if (player == null) return;

      final generation = _generation;

      // After a completion-driven teardown the Player will have been
      // recreated above without any media loaded. Reopen the previously
      // selected audio note so the user can transparently replay.
      if (!_hasOpenAudio) {
        final audioNote = state.audioNote;
        if (audioNote != null) {
          final localPath = await AudioUtils.getFullAudioPath(audioNote);
          await player.open(Media(localPath), play: false);
          if (_isSuperseded(generation, player)) return;
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
      if (_isSuperseded(generation, player)) return;
      await player.play();
      state = state.copyWith(status: AudioPlayerStatus.playing);
    } catch (exception, stackTrace) {
      _loggingService?.error(
        LogDomain.speech,
        exception,
        stackTrace: stackTrace,
        subDomain: 'play',
      );
    }
  }

  /// Seeks to the specified position.
  ///
  /// The position bookkeeping needs no [Player], so it lands *before* the
  /// queue: `setAudioNote` publishes the new note (making its card active,
  /// and its waveform scrubbable) before `open` resolves, so a scrub started
  /// in that window would otherwise leave the thumb pinned until the file
  /// finished loading. Only the seek on the player itself is queued.
  Future<void> seek(Duration newPosition) {
    _recordSeekPosition(newPosition);
    return _serialize(() => _seek(newPosition));
  }

  /// Applies a requested [newPosition] to state, and nothing else.
  ///
  /// This is also the only record of a seek that arrived while no file was
  /// loaded: `play`'s reopen branch restores the position from here.
  void _recordSeekPosition(Duration newPosition) {
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
  }

  Future<void> _seek(Duration newPosition) async {
    try {
      final player = _ensurePlayer();
      if (player == null) return;

      // After a completion-driven teardown the Player has no media loaded
      // yet; calling player.seek before player.open is undefined. The
      // requested position is already recorded in state and will be applied
      // when play() reopens the file (see the reopen branch in play).
      if (_hasOpenAudio) {
        await player.seek(newPosition);
      }
    } catch (exception, stackTrace) {
      _loggingService?.error(
        LogDomain.speech,
        exception,
        stackTrace: stackTrace,
        subDomain: 'seek',
      );
    }
  }

  /// Sets the playback speed.
  Future<void> setSpeed(double speed) => _serialize(() => _setSpeed(speed));

  Future<void> _setSpeed(double speed) async {
    try {
      final player = _ensurePlayer();
      if (player == null) return;

      await player.setRate(speed);
      state = state.copyWith(speed: speed);
    } catch (exception, stackTrace) {
      _loggingService?.error(
        LogDomain.speech,
        exception,
        stackTrace: stackTrace,
        subDomain: 'setSpeed',
      );
    }
  }

  /// Pauses playback.
  Future<void> pause() => _serialize(_pause);

  Future<void> _pause() async {
    try {
      final player = _ensurePlayer();
      if (player == null) return;

      await player.pause();
      state = state.copyWith(
        status: AudioPlayerStatus.paused,
        pausedAt: state.progress,
      );
    } catch (exception, stackTrace) {
      _loggingService?.error(
        LogDomain.speech,
        exception,
        stackTrace: stackTrace,
        subDomain: 'pause',
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
