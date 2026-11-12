import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:lotti/features/tts/cloud/cloud_speech_synthesizer.dart';
import 'package:lotti/features/tts/cloud/growing_speech_clip.dart';
import 'package:lotti/features/tts/cloud/tts_cloud_route.dart';
import 'package:lotti/features/tts/engine/tts_engine.dart';
import 'package:lotti/features/tts/model/tts_playback_state.dart';
import 'package:lotti/features/tts/state/tts_audio_player.dart';
import 'package:lotti/features/tts/state/tts_model_repository.dart';
import 'package:lotti/features/tts/state/tts_playback_controller.dart';

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

  /// Where each [play] was asked to start, in order.
  final List<Duration> startedFrom = <Duration>[];

  /// Held open, the player is still letting go of the audio session.
  Completer<void>? settling;

  @override
  Future<void> get settled => settling?.future ?? Future<void>.value();

  /// Held open, [play] is still opening the clip; it sets its rate once this
  /// completes, as the media_kit player does.
  Completer<void>? opening;

  /// The rate the clip plays at: set by [play] once open, and by [setSpeed].
  double? rate;

  @override
  Future<void> play(
    File file, {
    required double speed,
    Duration from = Duration.zero,
  }) async {
    playCount++;
    startedFrom.add(from);
    lastSpeed = speed;
    if (playError != null) throw playError!;
    await opening?.future;
    rate = speed;
  }

  /// Speeds set on the clip while it plays, in order.
  final List<double> speedChanges = <double>[];

  @override
  Future<void> setSpeed(double speed) async {
    speedChanges.add(speed);
    rate = speed;
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
  FakeCloudSpeechSynthesizer({
    this.output,
    this.error,
    this.catalogLoaded,
    this.streamed,
    this.streamDirectory,
    this.handingOver,
  });

  /// Awaited between making a growing clip and handing it to the caller,
  /// standing in for the moment a stop can land in.
  final Future<void>? handingOver;

  /// When set, the voice can send its speech while it makes it: the WAV
  /// bytes it sends for a text, written to a file in [streamDirectory].
  final Stream<Uint8List> Function(String text)? streamed;
  final Directory? streamDirectory;

  /// Every clip handed out by [synthesizeToGrowingFile], in order.
  final List<GrowingSpeechClip> growing = <GrowingSpeechClip>[];

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
    required Map<String, String> chosenVoices,
    required Future<bool> Function() canSend,
  }) async {
    await catalogLoaded;
    final sent = await canSend();
    calls.add((route: route, text: text, voices: chosenVoices, sent: sent));
    if (!sent) return null;
    if (error case final error?) throw error;
    return output ?? (throw StateError('no cloud output configured'));
  }

  @override
  bool canStream(TtsCloudRoute route) => streamed != null;

  @override
  Future<GrowingSpeechClip?> synthesizeToGrowingFile({
    required TtsCloudRoute route,
    required String text,
    required Map<String, String> chosenVoices,
    required Future<bool> Function() canSend,
  }) async {
    await catalogLoaded;
    final sent = await canSend();
    calls.add((route: route, text: text, voices: chosenVoices, sent: sent));
    if (!sent) return null;
    final clip = await GrowingSpeechClip.start(
      File('${streamDirectory!.path}/clip_${growing.length}.wav'),
      streamed!(text),
    );
    growing.add(clip);
    await handingOver;
    return clip;
  }
}

/// The app-wide voice held at [initial], for a test about what *another*
/// feature does to it. Each [stop] is appended to [events] as `'tts.stop'`,
/// so a test can order it against its own events, then runs [onStop] and
/// throws [stopError] when given.
class FixedTtsPlayback extends TtsPlaybackController {
  FixedTtsPlayback(
    this.initial, {
    List<String>? events,
    this.stopError,
    this.onStop,
  }) : events = events ?? <String>[];

  final TtsPlaybackState initial;
  final List<String> events;
  final Error? stopError;
  final void Function()? onStop;

  @override
  TtsPlaybackState build() => initial;

  @override
  Future<void> stop({String? sourceId}) async {
    events.add('tts.stop');
    onStop?.call();
    if (stopError != null) throw stopError!;
  }
}
