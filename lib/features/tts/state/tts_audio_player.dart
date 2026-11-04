import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/tts/state/tts_audio_focus.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:media_kit/media_kit.dart';

/// Plays a synthesized WAV file and exposes position / duration / completion
/// so the playback controller can drive progress and transition to stopped.
///
/// Behind an interface so the playback orchestration is fully testable with a
/// fake — the real `media_kit` player needs native bindings and can't run in
/// unit tests.
abstract interface class TtsAudioPlayer {
  /// Opens [file] and starts playback at [speed]× (1.0 = natural).
  Future<void> play(File file, {required double speed});

  /// Halts playback; the controller treats this as the end of the utterance.
  Future<void> stop();

  /// Current playhead position, emitted continuously during playback.
  Stream<Duration> get positionStream;

  /// Total clip length, emitted once the file is opened.
  Stream<Duration> get durationStream;

  /// Emits once each time playback reaches the end.
  Stream<void> get completedStream;

  /// Completes once the player has let go of the phone's audio session — a
  /// release at the end of a clip may still be under way — so the recorder
  /// can take the session after it.
  Future<void> get settled;

  Future<void> dispose();
}

/// `media_kit`-backed [TtsAudioPlayer], mirroring the recordings player's use
/// of the same `Player` API.
///
/// It holds the phone's audio focus ([TtsAudioFocus]) from the moment it
/// starts playing until it stops, finishes or is disposed, so the voice
/// keeps speaking while its listener is in another app.
class MediaKitTtsAudioPlayer implements TtsAudioPlayer {
  MediaKitTtsAudioPlayer([Player? player, TtsAudioFocus? focus])
    // The native player needs media_kit's bindings, which a unit test has
    // not; tests hand in a mock.
    : _player = player ?? Player(), // coverage:ignore-line
      _focus = focus ?? platformTtsAudioFocus() {
    _finished = _player.stream.completed
        .where((done) => done)
        .listen((_) => _focus.release());
  }

  final Player _player;
  final TtsAudioFocus _focus;
  late final StreamSubscription<bool> _finished;
  int _generation = 0;

  @override
  Future<void> play(File file, {required double speed}) async {
    final generation = ++_generation;
    await _player.open(Media(file.path), play: false);
    if (generation != _generation) return;
    await _player.setRate(speed);
    if (generation != _generation) return;
    // A stop while the focus is being taken releases it after this claim —
    // the focus runs claims and releases in turn — so a cancelled play never
    // releases on its own: by then a newer play may hold the focus.
    await _focus.acquire();
    if (generation != _generation) return;
    await _player.play();
  }

  @override
  Future<void> stop() async {
    _generation++;
    await _player.stop();
    await _focus.release();
  }

  @override
  Stream<Duration> get positionStream => _player.stream.position;

  @override
  Stream<Duration> get durationStream => _player.stream.duration;

  @override
  Future<void> get settled => _focus.settled;

  @override
  Stream<void> get completedStream =>
      _player.stream.completed.where((done) => done).map((_) {});

  @override
  Future<void> dispose() async {
    _generation++;
    await _finished.cancel();
    await _player.dispose();
    await _focus.release();
  }
}

// Constructs the real media_kit Player, so it is exercised at runtime rather
// than in unit tests (MediaKitTtsAudioPlayer itself is tested with a mock
// Player). The blank line below the directive is deliberate: it keeps the
// coverage directive out of the doc comment the riverpod generator copies onto
// the generated provider — otherwise an unmatched directive lands in the
// .g.dart and crashes coverage collection.
// coverage:ignore-start

/// App-wide [TtsAudioPlayer]. Overridden with a fake in tests.
final ttsAudioPlayerProvider = Provider<TtsAudioPlayer>(
  ttsAudioPlayer,
  name: 'ttsAudioPlayerProvider',
);
TtsAudioPlayer ttsAudioPlayer(Ref ref) {
  final player = MediaKitTtsAudioPlayer(
    null,
    platformTtsAudioFocus(logger: ref.read(domainLoggerProvider)),
  );
  ref.onDispose(() => unawaited(player.dispose()));
  return player;
}

// coverage:ignore-end
