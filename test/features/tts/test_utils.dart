import 'dart:async';
import 'dart:io';

import 'package:lotti/features/tts/engine/tts_engine.dart';
import 'package:lotti/features/tts/state/tts_audio_player.dart';
import 'package:lotti/features/tts/state/tts_model_repository.dart';

/// Records of a synthesis request, for asserting what the engine was asked to
/// speak.
typedef SynthesisCall = ({
  String text,
  String voiceId,
  String modelDirectory,
  String language,
});

/// In-memory [TtsEngine] for tests: configurable support flag, returns a fixed
/// file, and records every request.
class FakeTtsEngine implements TtsEngine {
  FakeTtsEngine({this.supported = true, File? output})
    : _output = output ?? File('/tmp/fake_tts_output.wav');

  final bool supported;
  final File _output;
  final List<SynthesisCall> calls = <SynthesisCall>[];

  @override
  bool get isSupported => supported;

  @override
  Future<File> synthesizeToFile({
    required String text,
    required String voiceId,
    required String modelDirectory,
    required String language,
  }) async {
    calls.add((
      text: text,
      voiceId: voiceId,
      modelDirectory: modelDirectory,
      language: language,
    ));
    return _output;
  }

  @override
  Future<void> dispose() async {}
}

/// [TtsAudioPlayer] with manually-driven streams so tests control playback
/// position and completion timing.
class FakeTtsAudioPlayer implements TtsAudioPlayer {
  final StreamController<Duration> _position =
      StreamController<Duration>.broadcast();
  final StreamController<Duration> _duration =
      StreamController<Duration>.broadcast();
  final StreamController<void> _completed = StreamController<void>.broadcast();

  int playCount = 0;
  int stopCount = 0;
  double? lastSpeed;

  @override
  Future<void> play(File file, {required double speed}) async {
    playCount++;
    lastSpeed = speed;
  }

  @override
  Future<void> stop() async {
    stopCount++;
  }

  @override
  Stream<Duration> get positionStream => _position.stream;

  @override
  Stream<Duration> get durationStream => _duration.stream;

  @override
  Stream<void> get completedStream => _completed.stream;

  void emitPosition(Duration position) => _position.add(position);
  void emitDuration(Duration duration) => _duration.add(duration);
  void complete() => _completed.add(null);

  @override
  Future<void> dispose() async {
    await _position.close();
    await _duration.close();
    await _completed.close();
  }
}

/// [TtsModelRepository] that reports a fixed install state and emits a fixed
/// progress sequence from [ensureInstalled].
class FakeTtsModelRepository implements TtsModelRepository {
  FakeTtsModelRepository({
    this.installed = true,
    this.directory = '/tmp/tts_model',
    this.progressSteps = const [0.5, 1],
  });

  bool installed;
  final String directory;
  final List<double> progressSteps;
  int ensureCount = 0;

  @override
  Future<bool> isInstalled(String modelId) async => installed;

  @override
  Future<String> modelDirectory(String modelId) async => directory;

  @override
  Future<String> ensureInstalled(
    String modelId, {
    void Function(double progress)? onProgress,
  }) async {
    ensureCount++;
    for (final step in progressSteps) {
      // Yield to a fresh microtask between steps so each progress update is a
      // separate state change the controller's listeners observe (no real
      // delay involved).
      await Future<void>.value();
      onProgress?.call(step);
    }
    return directory;
  }
}
