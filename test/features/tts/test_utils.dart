import 'dart:async';
import 'dart:io';

import 'package:lotti/features/tts/cloud/cloud_speech_synthesizer.dart';
import 'package:lotti/features/tts/cloud/tts_cloud_route.dart';
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
  FakeTtsEngine({
    this.supported = true,
    this.throwOnSynthesize = false,
    this.pendingSynthesis,
    this.onSynthesize,
    File? output,
  }) : output = output ?? File('/tmp/fake_tts_output.wav');

  final bool supported;
  final bool throwOnSynthesize;
  final Future<File>? pendingSynthesis;
  final void Function()? onSynthesize;

  /// What the next synthesis answers with; a test may swap it.
  File output;
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
    if (throwOnSynthesize) {
      throw Exception('synthesis failed');
    }
    calls.add((
      text: text,
      voiceId: voiceId,
      modelDirectory: modelDirectory,
      language: language,
    ));
    onSynthesize?.call();
    return pendingSynthesis ?? output;
  }

  @override
  Future<void> dispose() async {}
}

/// [TtsAudioPlayer] with manually-driven streams so tests control playback
/// position and completion timing.
class FakeTtsAudioPlayer implements TtsAudioPlayer {
  FakeTtsAudioPlayer({this.stopError, this.playError});

  final Error? stopError;

  /// Thrown by [play] after it is counted, like a player that cannot open
  /// the clip.
  final Error? playError;
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
    if (playError != null) throw playError!;
  }

  @override
  Future<void> stop() async {
    stopCount++;
    if (stopError != null) throw stopError!;
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

/// One cloud synthesis request: the route, the text, the per-language voice
/// choices it was given, and whether its `canSend` check let it upload.
typedef CloudSynthesisCall = ({
  TtsCloudRoute route,
  String text,
  Map<String, String> voices,
  bool sent,
});

/// Records every cloud synthesis and answers with [output], or throws
/// [error] — a [StateError] when neither is given, so a test that only
/// observes routing never reaches playback.
class FakeCloudSpeechSynthesizer implements CloudSpeechSynthesizer {
  FakeCloudSpeechSynthesizer({this.output, this.error, this.catalogLoaded});

  /// What a sent synthesis answers with; a test may set it later.
  File? output;
  final Exception? error;

  /// Awaited before `canSend` is asked, standing in for a voice catalog that
  /// is still loading over the network.
  final Future<void>? catalogLoaded;
  final List<CloudSynthesisCall> calls = <CloudSynthesisCall>[];

  @override
  Future<File?> synthesizeToFile({
    required TtsCloudRoute route,
    required String text,
    required Map<String, String> voiceByLanguage,
    required Future<bool> Function() canSend,
  }) async {
    await catalogLoaded;
    final sent = await canSend();
    calls.add((route: route, text: text, voices: voiceByLanguage, sent: sent));
    if (!sent) return null;
    if (error case final error?) throw error;
    return output ?? (throw StateError('no cloud output configured'));
  }
}
