import 'dart:async';
import 'dart:io';

import 'package:media_kit/media_kit.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'tts_audio_player.g.dart';

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

  Future<void> dispose();
}

/// `media_kit`-backed [TtsAudioPlayer], mirroring the recordings player's use
/// of the same `Player` API.
class MediaKitTtsAudioPlayer implements TtsAudioPlayer {
  MediaKitTtsAudioPlayer([Player? player]) : _player = player ?? Player();

  final Player _player;

  @override
  Future<void> play(File file, {required double speed}) async {
    await _player.open(Media(file.path), play: false);
    await _player.setRate(speed);
    await _player.play();
  }

  @override
  Future<void> stop() => _player.stop();

  @override
  Stream<Duration> get positionStream => _player.stream.position;

  @override
  Stream<Duration> get durationStream => _player.stream.duration;

  @override
  Stream<void> get completedStream =>
      _player.stream.completed.where((done) => done).map((_) {});

  @override
  Future<void> dispose() => _player.dispose();
}

/// App-wide [TtsAudioPlayer]. Overridden with a fake in tests.
//
// Constructs the real media_kit Player, so it is exercised at runtime rather
// than in unit tests (MediaKitTtsAudioPlayer itself is tested with a mock
// Player).
// coverage:ignore-start
@Riverpod(keepAlive: true)
TtsAudioPlayer ttsAudioPlayer(Ref ref) {
  final player = MediaKitTtsAudioPlayer();
  ref.onDispose(() => unawaited(player.dispose()));
  return player;
}

// coverage:ignore-end
