import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/tts/engine/text_chunker.dart';

void main() {
  group('chunkText', () {
    test('returns a single chunk for one short sentence', () {
      expect(chunkText('Hello there.'), ['Hello there.']);
    });

    test('splits on blank-line paragraph boundaries', () {
      final chunks = chunkText('First para.\n\nSecond para.');
      expect(chunks, ['First para.', 'Second para.']);
    });

    test('packs sentences up to maxLen, breaking on sentence boundaries', () {
      final chunks = chunkText(
        'One sentence here. Two sentence here. Three sentence here.',
        maxLen: 25,
      );
      expect(chunks.length, greaterThan(1));
      // Each chunk ends at a sentence terminator (no mid-sentence cut).
      for (final c in chunks) {
        expect(c.trim(), endsWith('.'));
      }
    });

    test('does not split on common abbreviations', () {
      final chunks = chunkText('Dr. Smith arrived. He sat down.');
      expect(chunks.single, 'Dr. Smith arrived. He sat down.');
    });

    test('drops empty paragraphs and trims', () {
      expect(chunkText('  \n\n  A.  \n\n  '), ['A.']);
    });
  });

  group('maxChunkLenForLang', () {
    test('uses a shorter window for Korean and Japanese', () {
      expect(maxChunkLenForLang('ko'), 120);
      expect(maxChunkLenForLang('ja'), 120);
    });

    test('uses the wider window for other languages', () {
      expect(maxChunkLenForLang('en'), 300);
      expect(maxChunkLenForLang('na'), 300);
    });
  });
}
