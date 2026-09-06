import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:lotti/features/ai/speech/sherpa_model_catalog.dart';
import 'package:path/path.dart' as p;
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

/// Builds the native configuration from the same pinned manifest downloaded
/// by settings. Tokenizer directories and external ONNX data remain siblings
/// of their model files, as required by the upstream exports.
sherpa.OfflineRecognizerConfig sherpaRecognizerConfig(
  SherpaModel model,
  String directory,
) {
  final architecture = model.architecture;
  final options = <String, dynamic>{
    for (final entry in model.recognizerFiles.entries)
      entry.key: p.join(directory, entry.value),
    if (architecture == SherpaModelArchitecture.whisper) 'task': 'transcribe',
    if (architecture == SherpaModelArchitecture.senseVoice) 'language': 'auto',
    if (architecture == SherpaModelArchitecture.qwen3Asr) ...{
      'maxNewTokens': 512,
      'maxTotalLen': 1024,
    },
  };
  return sherpa.OfflineRecognizerConfig(
    model: sherpa.OfflineModelConfig.fromJson({
      architecture.configurationKey: options,
      'tokens': model.recognizerFiles.containsKey('tokenizer')
          ? ''
          : p.join(directory, model.tokensFile),
      if (architecture == SherpaModelArchitecture.whisper)
        'modelType': 'whisper',
      if (architecture == SherpaModelArchitecture.nemoTransducer)
        'modelType': 'nemo_transducer',
      'numThreads': 2,
      'debug': false,
    }),
  );
}

/// File-only input sent to the worker; model pointers never cross isolates.
class SherpaWorkerRequest {
  const SherpaWorkerRequest({
    required this.wavPath,
    required this.modelDirectory,
    required this.modelId,
  });

  final String wavPath;
  final String modelDirectory;
  final String modelId;
}

typedef SherpaWorkerEntry =
    Future<void> Function((SendPort, SherpaWorkerRequest));

/// Runs native decoding outside Flutter's UI isolate. The worker decodes one
/// segment per request, so cancellation frees native resources after the active
/// segment instead of starting the remainder of a long recording.
Stream<String> runSherpaWorker(
  SherpaWorkerRequest request, {
  SherpaWorkerEntry entry = sherpaWorkerEntry,
}) async* {
  final messages = ReceivePort();
  final exited = ReceivePort();
  SendPort? commands;
  Isolate? isolate;
  try {
    isolate = await Isolate.spawn(
      entry,
      (messages.sendPort, request),
      onExit: exited.sendPort,
      onError: messages.sendPort,
    );
    await for (final message in messages) {
      if (message is SendPort) {
        commands = message..send(true);
      } else if (message is String) {
        if (message.isNotEmpty) yield message;
        commands?.send(true);
      } else if (message == null) {
        break;
      } else if (message is List) {
        throw StateError('Embedded transcription failed: ${message.first}');
      }
    }
  } finally {
    commands?.send(false);
    // Allow the native decode to finish and release its recognizer before the
    // caller deletes the WAV file. Killing an isolate would leak FFI pointers.
    if (isolate != null) await exited.first;
    messages.close();
    exited.close();
  }
}

/// Worker entry point. Every isolate initializes its own native bindings.
Future<void> sherpaWorkerEntry((SendPort, SherpaWorkerRequest) input) async {
  await decodeSherpaSegments(input);
}

/// Owns the recognizer and streams for one recording. Binding factories are
/// injectable so error and cancellation cleanup can be exercised without
/// downloading a model in unit tests.
Future<void> decodeSherpaSegments(
  (SendPort, SherpaWorkerRequest) input, {
  void Function() initialize = sherpa.initBindings,
  sherpa.OfflineRecognizer Function(sherpa.OfflineRecognizerConfig)
      createRecognizer =
      sherpa.OfflineRecognizer.new,
  sherpa.WaveData Function(String) readWave = sherpa.readWave,
}) async {
  final (output, request) = input;
  final commands = ReceivePort();
  sherpa.OfflineRecognizer? recognizer;
  try {
    initialize();
    final model = sherpaModels.firstWhere(
      (model) => model.id == request.modelId,
    );
    recognizer = createRecognizer(
      sherpaRecognizerConfig(model, request.modelDirectory),
    );
    final wave = readWave(request.wavPath);
    if (wave.sampleRate <= 0 || wave.samples.isEmpty) {
      throw const FormatException('Audio contains no decodable samples');
    }
    final segments = sherpaSpeechSegments(
      wave.samples,
      wave.sampleRate,
    ).iterator;
    output.send(commands.sendPort);
    await for (final next in commands) {
      if (next != true || !segments.moveNext()) break;
      final (start, end) = segments.current;
      final stream = recognizer.createStream();
      try {
        stream.acceptWaveform(
          samples: Float32List.sublistView(wave.samples, start, end),
          sampleRate: wave.sampleRate,
        );
        recognizer.decode(stream);
        output.send(recognizer.getResult(stream).text.trim());
      } finally {
        stream.free();
      }
    }
  } catch (error) {
    output.send([error.toString()]);
  } finally {
    recognizer?.free();
    commands.close();
    output.send(null);
  }
}

/// Covers the entire recording in windows below Whisper's 30-second limit.
/// For long windows, prefer the quietest 100ms boundary in the final five
/// seconds, reducing cuts through speech without omitting or duplicating audio.
Iterable<(int, int)> sherpaSpeechSegments(
  Float32List samples,
  int sampleRate,
) sync* {
  if (sampleRate <= 0) throw ArgumentError.value(sampleRate, 'sampleRate');
  final maximum = sampleRate * 28;
  final search = sampleRate * 5;
  final window = math.max(1, sampleRate ~/ 10);
  var start = 0;
  while (start < samples.length) {
    var end = math.min(start + maximum, samples.length);
    if (end < samples.length) {
      final limit = end;
      var quietest = double.infinity;
      for (
        var candidate = limit - search;
        candidate + window <= limit;
        candidate += window
      ) {
        var energy = 0.0;
        for (var i = candidate; i < candidate + window; i++) {
          energy += samples[i] * samples[i];
        }
        if (energy < quietest) {
          quietest = energy;
          end = candidate + window;
        }
      }
    }
    yield (start, end);
    start = end;
  }
}
