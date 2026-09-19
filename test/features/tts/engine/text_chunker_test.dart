import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
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

  group('properties', () {
    final word = glados.any.choose([
      'Hello',
      'world.',
      'Dr.',
      'Smith',
      'ok!',
      'why?',
      'A.',
      'penguins',
      'x' * 40,
    ]);
    final separator = glados.any.choose([' ', '  ', '\n', '\n\n', ' \n \n ']);
    final text = glados.any.listWithLengthInRange(
      0,
      40,
      glados.any.combine2(word, separator, (String w, String s) => '$w$s'),
    );

    List<String> words(String s) =>
        s.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

    glados.Glados2(
      text,
      glados.any.intInRange(10, 120),
      glados.ExploreConfig(numRuns: 200),
    ).test(
      'chunks keep every word in order and respect maxLen per sentence',
      (pieces, maxLen) {
        final input = pieces.join();
        final chunks = chunkText(input, maxLen: maxLen);

        expect(chunks.every((c) => c.isNotEmpty), isTrue);
        expect(chunks.every((c) => c == c.trim()), isTrue);
        expect(words(chunks.join(' ')), words(input));
        for (final chunk in chunks.where((c) => c.length > maxLen)) {
          // Only a single sentence that is already too long may overflow.
          expect(chunkText(chunk, maxLen: 1), [chunk], reason: chunk);
        }
      },
      tags: 'glados',
    );
  });
}
