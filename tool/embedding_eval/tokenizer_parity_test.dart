// Checks the app's EmbeddingGemma tokenizer against Hugging Face `tokenizers`
// on every text `tokenizer_parity.py` wrote ids for. Not part of the test
// suite, since it needs the model's 20 MB tokenizer.json — run it on purpose,
// after the corpus export and the Python side (see README.md):
//
//   EMBEDDING_MODELS_DIR=/tmp/models \
//     fvm flutter test tool/embedding_eval/tokenizer_parity_test.dart
//
// Reads `build/embedding_eval/token_ids.json` (or `EMBEDDING_EVAL_TOKEN_IDS`).
import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/on_device_embedding/gemma_tokenizer.dart';

void main() {
  test('the Dart tokenizer gives the ids tokenizers gives', () {
    final modelsDir = Platform.environment['EMBEDDING_MODELS_DIR'];
    if (modelsDir == null) {
      fail('set EMBEDDING_MODELS_DIR to the directory of the models');
    }
    final tokenizerJson = File(
      '$modelsDir/embeddinggemma-300m-ONNX/tokenizer.json',
    ).readAsStringSync();
    final cases =
        jsonDecode(
              File(
                Platform.environment['EMBEDDING_EVAL_TOKEN_IDS'] ??
                    'build/embedding_eval/token_ids.json',
              ).readAsStringSync(),
            )
            as List<dynamic>;

    final decode = Stopwatch()..start();
    final decoded = jsonDecode(tokenizerJson) as Map<String, dynamic>;
    decode.stop();
    final load = Stopwatch()..start();
    final tokenizer = GemmaTokenizer.fromTokenizerJson(decoded);
    load.stop();

    final encode = Stopwatch()..start();
    final mismatches = <String>[];
    var tokens = 0;
    for (final entry in cases) {
      final text = (entry as Map<String, dynamic>)['text'] as String;
      final expected = (entry['ids'] as List<dynamic>).cast<int>();
      final actual = tokenizer.encode(text);
      tokens += actual.length;
      if (!const ListEquality<int>().equals(actual, expected)) {
        mismatches.add('${jsonEncode(text)}\n  want $expected\n  got  $actual');
      }
    }
    encode.stop();

    // ignore: avoid_print
    print(
      '${cases.length} texts, $tokens tokens: JSON decoded in '
      '${decode.elapsedMilliseconds} ms, tokenizer built in '
      '${load.elapsedMilliseconds} ms, encoded in '
      '${encode.elapsedMilliseconds} ms',
    );
    expect(mismatches, isEmpty, reason: mismatches.take(5).join('\n'));
  });
}
