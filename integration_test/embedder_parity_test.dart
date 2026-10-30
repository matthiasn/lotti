// Runs the app's EmbeddingGemma embedder on the real ONNX Runtime and checks
// its vectors against the ones `embedder_parity.py` wrote, and how long the
// app stops answering while it embeds. Not part of the test suite, since it
// needs the model's 200 MB — run it on purpose, on a desktop (see README.md);
// without the two defines it is skipped:
//
//   fvm flutter test integration_test/embedder_parity_test.dart -d linux \
//     --dart-define=EMBEDDING_MODELS_DIR=/tmp/models \
//     --dart-define=EMBEDDING_EVAL_VECTORS=$PWD/build/embedding_eval/vectors.json
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lotti/features/ai/on_device_embedding/gemma_embedder.dart';

const _modelsDir = String.fromEnvironment('EMBEDDING_MODELS_DIR');
const _vectors = String.fromEnvironment('EMBEDDING_EVAL_VECTORS');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Skipped unless both are passed, so `make integration_test` runs without
  // the model.
  testWidgets(
    'the app embeds as ONNX Runtime in Python does',
    skip: _modelsDir.isEmpty || _vectors.isEmpty,
    (_) async {
      final cases = jsonDecode(File(_vectors).readAsStringSync()) as List;

      final load = Stopwatch()..start();
      final embedder = await GemmaEmbedder.load(
        '$_modelsDir/embeddinggemma-300m-ONNX',
      );
      load.stop();

      // A timer that should fire every 5 ms: the longest gap between two
      // ticks is how long the app's isolate could not run while embedding.
      var longestStall = Duration.zero;
      final sinceTick = Stopwatch()..start();
      final ticker = Timer.periodic(const Duration(milliseconds: 5), (_) {
        if (sinceTick.elapsed > longestStall) longestStall = sinceTick.elapsed;
        sinceTick.reset();
      });

      final embed = Stopwatch()..start();
      var worst = 1.0;
      try {
        for (final entry in cases) {
          final text = (entry as Map<String, dynamic>)['text'] as String;
          final expected = (entry['vector'] as List).cast<num>();
          final actual = entry['kind'] == 'query'
              ? await embedder.embedQuery(text)
              : await embedder.embedDocument(text);
          var dot = 0.0;
          for (var i = 0; i < actual.length; i++) {
            dot += actual[i] * expected[i];
          }
          worst = min(worst, dot);
        }
        embed.stop();
        // The gap since the last tick counts too.
        if (sinceTick.elapsed > longestStall) longestStall = sinceTick.elapsed;
      } finally {
        ticker.cancel();
        await embedder.dispose();
      }

      // ignore: avoid_print
      print(
        '${cases.length} vectors: loaded in ${load.elapsedMilliseconds} ms, '
        '${(embed.elapsedMilliseconds / cases.length).toStringAsFixed(1)} ms '
        'each, lowest cosine ${worst.toStringAsFixed(6)}, longest stall '
        '${longestStall.inMilliseconds} ms',
      );
      expect(worst, greaterThan(0.999));
    },
  );
}
