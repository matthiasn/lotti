// Unicode tokenizer for the Supertonic TTS engine.
//
// Ported from Supertone's open-source Supertonic Flutter example
// (github.com/supertone-inc/supertonic — MIT-licensed sample code). Maps the
// code points of preprocessed, language-tagged text to model token ids using
// the `unicode_indexer.json` table shipped with the model, and builds the
// padding mask the ONNX graph expects.

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/services.dart' show rootBundle;
import 'package:lotti/features/tts/engine/text_preprocessing.dart';

/// Tokenized batch: padded token ids and the matching padding mask.
class TokenizedText {
  const TokenizedText({required this.textIds, required this.textMask});

  /// `[batch][maxLen]` token ids, zero-padded.
  final List<List<int>> textIds;

  /// `[batch][1][maxLen]` mask, `1.0` for real tokens and `0.0` for padding.
  final List<List<List<double>>> textMask;
}

/// Maps Unicode code points to model token ids.
class UnicodeProcessor {
  const UnicodeProcessor.fromIndexer(this.indexer);

  /// code point → token id.
  final Map<int, int> indexer;

  /// Loads the indexer from `unicode_indexer.json` at [path]. Paths starting
  /// with `assets/` are read from the bundle; otherwise from the filesystem
  /// (e.g. a downloaded model directory).
  static Future<UnicodeProcessor> load(String path) async {
    final raw = path.startsWith('assets/')
        ? await rootBundle.loadString(path)
        : await File(path).readAsString();
    final json = jsonDecode(raw);

    final indexer = json is List
        ? <int, int>{
            for (var i = 0; i < json.length; i++)
              if (json[i] is int && (json[i] as int) >= 0) i: json[i] as int,
          }
        : (json as Map<String, dynamic>).map(
            (k, v) => MapEntry(int.parse(k), v as int),
          );

    return UnicodeProcessor.fromIndexer(indexer);
  }

  /// Preprocesses and tokenizes a batch of [textList] in [langList].
  TokenizedText call(List<String> textList, List<String> langList) {
    final processed = <String>[
      for (var i = 0; i < textList.length; i++)
        preprocessText(textList[i], langList[i]),
    ];

    final lengths = processed.map((t) => t.runes.length).toList();
    final maxLen = lengths.reduce(math.max);

    final textIds = processed.map((text) {
      final row = List<int>.filled(maxLen, 0);
      final runes = text.runes.toList();
      for (var i = 0; i < runes.length; i++) {
        row[i] = indexer[runes[i]] ?? 0;
      }
      return row;
    }).toList();

    return TokenizedText(
      textIds: textIds,
      textMask: _lengthToMask(lengths, maxLen),
    );
  }

  List<List<List<double>>> _lengthToMask(List<int> lengths, int maxLen) {
    return lengths
        .map(
          (len) => [
            List.generate(maxLen, (i) => i < len ? 1.0 : 0.0),
          ],
        )
        .toList();
  }
}
