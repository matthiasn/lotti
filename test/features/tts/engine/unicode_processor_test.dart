import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/tts/engine/text_preprocessing.dart';
import 'package:lotti/features/tts/engine/unicode_processor.dart';

void main() {
  // Identity-ish indexer: every ASCII code point maps to itself, so token ids
  // are easy to reason about. Code points absent from the map tokenize to 0.
  final identityIndexer = <int, int>{for (var c = 0; c < 128; c++) c: c};

  group('UnicodeProcessor.call', () {
    test('tokenizes one text with a full-length mask', () {
      final processor = UnicodeProcessor.fromIndexer(identityIndexer);
      final tokenized = processor.call(['hi'], ['na']);

      // preprocessText('hi','na') == '<na>hi.</na>'.
      final expected = preprocessText('hi', 'na').runes.toList();
      expect(tokenized.textIds.single, expected); // identity map → code points
      final mask = tokenized.textMask.single.single;
      expect(mask.length, expected.length);
      expect(mask.every((m) => m == 1.0), isTrue);
    });

    test('maps unknown code points to 0', () {
      // Only 'h' is known; every other code point tokenizes to 0.
      final processor = UnicodeProcessor.fromIndexer({'h'.codeUnitAt(0): 99});
      final tokenized = processor.call(['h'], ['na']);
      final ids = tokenized.textIds.single;

      expect(ids, contains(99)); // the single 'h'
      expect(ids.where((id) => id == 99).length, 1);
      expect(ids, contains(0)); // the tags/period are unmapped
    });

    test('pads the shorter row and zeros its mask tail in a batch', () {
      final processor = UnicodeProcessor.fromIndexer(identityIndexer);
      final tokenized = processor.call(['a', 'abcd'], ['na', 'na']);

      final maxLen = preprocessText('abcd', 'na').runes.length;
      // Both rows padded to the same width.
      expect(tokenized.textIds[0].length, maxLen);
      expect(tokenized.textIds[1].length, maxLen);

      // The longer text fills its mask; the shorter has trailing zeros.
      final shortMask = tokenized.textMask[0].single;
      final longMask = tokenized.textMask[1].single;
      expect(longMask.every((m) => m == 1.0), isTrue);
      expect(shortMask.last, 0.0);
      expect(shortMask.where((m) => m == 1.0).length, lessThan(maxLen));
      // Padding ids are zero.
      expect(tokenized.textIds[0].last, 0);
    });
  });
}
