import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/service/text_chunker.dart';

/// Asserts that every chunk's estimated token count is at most [limit].
void _expectAllChunksWithinTokenLimit(List<String> chunks, int limit) {
  for (var i = 0; i < chunks.length; i++) {
    final tokens = TextChunker.estimateTokens(chunks[i]);
    expect(
      tokens,
      lessThanOrEqualTo(limit),
      reason:
          'Chunk $i has $tokens estimated tokens, '
          'which exceeds target of $limit',
    );
  }
}

void main() {
  group('TextChunker', () {
    group('estimateTokens', () {
      test('returns 0 for empty string', () {
        expect(TextChunker.estimateTokens(''), 0);
      });

      test('returns 0 for whitespace-only string', () {
        expect(TextChunker.estimateTokens('   \n\t  '), 0);
      });

      test('estimates tokens from word count', () {
        // 10 words × 1.3 = 13 tokens (ceil)
        final text = List.generate(10, (i) => 'word$i').join(' ');
        expect(TextChunker.estimateTokens(text), 13);
      });

      test('single word returns at least 1 token', () {
        expect(TextChunker.estimateTokens('hello'), greaterThanOrEqualTo(1));
      });

      test('handles multiple spaces between words', () {
        // "a  b  c" still has 3 words after splitting on \s+
        expect(TextChunker.estimateTokens('a  b  c'), 4); // ceil(3 * 1.3)
      });

      test(
        'estimates long whitespace-free non-CJK token by character count',
        () {
          // A 2000-character URL-like string (no whitespace, no CJK)
          final longUrl = 'https://example.com/${'a' * 1980}';
          final tokens = TextChunker.estimateTokens(longUrl);
          // Should use ~4 chars/token → 2000/4 = 500, not 1 word × 1.3 = 2
          expect(tokens, 500);
        },
      );
    });

    group('chunk', () {
      test('returns empty list for empty string', () {
        expect(TextChunker.chunk(''), isEmpty);
      });

      test('returns empty list for whitespace-only string', () {
        expect(TextChunker.chunk('   \n  '), isEmpty);
      });

      test('returns single chunk for short text', () {
        const shortText = 'This is a short task description.';
        final chunks = TextChunker.chunk(shortText);
        expect(chunks, hasLength(1));
        expect(chunks.first, shortText);
      });

      test('returns single chunk for text at exactly the token limit', () {
        // ~196 words = ~255 tokens (just under the 256 target)
        final words = List.generate(196, (i) => 'word$i');
        final text = words.join(' ');
        final chunks = TextChunker.chunk(text);
        // Should be 1 chunk since estimateTokens(196 words) = ceil(196*1.3) = 255 < 256
        expect(chunks, hasLength(1));
      });

      test('produces multiple chunks for long text', () {
        // Build text with ~600 words (well above 256 token threshold)
        final sentences = List.generate(
          60,
          (i) => 'This is sentence number $i with some extra words.',
        );
        final text = sentences.join(' ');
        final chunks = TextChunker.chunk(text);
        expect(chunks.length, greaterThan(1));
      });

      test('all chunks are non-empty', () {
        final sentences = List.generate(
          80,
          (i) => 'Sentence $i discusses topic ${i % 5} in detail.',
        );
        final text = sentences.join(' ');
        final chunks = TextChunker.chunk(text);
        for (final chunk in chunks) {
          expect(chunk.trim(), isNotEmpty);
        }
      });

      test('consecutive chunks have overlapping content', () {
        // Build text with clear, distinct sentences
        final sentences = List.generate(
          60,
          (i) => 'Unique sentence alpha$i about beta$i.',
        );
        final text = sentences.join(' ');
        final chunks = TextChunker.chunk(text);

        expect(
          chunks.length,
          greaterThan(1),
          reason: 'Need multiple chunks to test overlap',
        );

        // Check that consecutive chunks share some words
        for (var i = 0; i < chunks.length - 1; i++) {
          final currentWords = chunks[i].split(RegExp(r'\s+'));
          final nextWords = chunks[i + 1].split(RegExp(r'\s+'));

          // The start of the next chunk should contain words from the
          // end of the current chunk (the overlap)
          final currentEnd = currentWords.sublist(
            (currentWords.length * 0.7).floor(),
          );
          final nextStart = nextWords.sublist(
            0,
            (nextWords.length * 0.4).floor().clamp(1, nextWords.length),
          );

          final currentEndSet = currentEnd.toSet();
          final nextStartSet = nextStart.toSet();
          final overlap = currentEndSet.intersection(nextStartSet);

          expect(
            overlap,
            isNotEmpty,
            reason:
                'Chunks $i and ${i + 1} should overlap. '
                'End of chunk $i: "${currentEnd.take(10).join(' ')}..." '
                'Start of chunk ${i + 1}: "${nextStart.take(10).join(' ')}..."',
          );
        }
      });

      test('no chunk exceeds estimated token target by too much', () {
        final sentences = List.generate(
          80,
          (i) => 'Sentence $i covers the topic of item $i thoroughly.',
        );
        final text = sentences.join(' ');
        final chunks = TextChunker.chunk(text);
        _expectAllChunksWithinTokenLimit(chunks, kChunkTargetTokens);
      });

      test(
        'handles single very long sentence by splitting on word boundaries',
        () {
          // One sentence with 500 words (no sentence boundaries to split on)
          final longSentence = List.generate(500, (i) => 'word$i').join(' ');
          final chunks = TextChunker.chunk(longSentence);
          // Should produce multiple chunks via word-boundary fallback
          expect(chunks.length, greaterThan(1));
          // Every word should appear in at least one chunk (use word-boundary
          // matching to avoid false positives like 'word1' matching 'word10').
          for (var i = 0; i < 500; i++) {
            final marker = 'word$i';
            final pattern = RegExp('(^|\\s)${RegExp.escape(marker)}(\\s|\$)');
            expect(
              chunks.any(pattern.hasMatch),
              isTrue,
              reason: 'Word "$marker" not found in any chunk',
            );
          }
        },
      );

      test('splits oversized sentence within multi-sentence text', () {
        const normalSentence = 'This is a normal sentence.';
        final longSentence = List.generate(400, (i) => 'longword$i').join(' ');
        const anotherNormal = 'Another normal sentence at the end.';
        final text = '$normalSentence $longSentence $anotherNormal';
        final chunks = TextChunker.chunk(text);

        expect(chunks.length, greaterThan(1));
        _expectAllChunksWithinTokenLimit(chunks, kChunkTargetTokens);
      });

      test('handles paragraph breaks as sentence boundaries', () {
        final paragraphs = List.generate(
          20,
          (i) =>
              'Paragraph $i has multiple words discussing topic $i '
              'with enough content to be meaningful and substantial.',
        );
        final text = paragraphs.join('\n\n');
        final chunks = TextChunker.chunk(text);
        // Should produce chunks (text is long enough)
        expect(chunks, isNotEmpty);
      });

      test('handles unicode text correctly', () {
        final sentences = List.generate(
          60,
          (i) => 'Satz Nummer $i bespricht Thema $i mit Ümlauten äöü.',
        );
        final text = sentences.join(' ');
        final chunks = TextChunker.chunk(text);
        expect(chunks.length, greaterThan(1));
        // Verify no corrupted characters
        for (final chunk in chunks) {
          expect(chunk.contains('ä'), isTrue);
          expect(chunk.contains('ö'), isTrue);
          expect(chunk.contains('ü'), isTrue);
        }
      });

      test('entire text is covered by chunks', () {
        final sentences = List.generate(
          50,
          (i) => 'Sentence_$i is unique.',
        );
        final text = sentences.join(' ');
        final chunks = TextChunker.chunk(text);

        // Every sentence marker should appear in at least one chunk (use
        // word-boundary matching to avoid false positives like
        // 'Sentence_1' matching 'Sentence_10').
        for (var i = 0; i < sentences.length; i++) {
          final marker = 'Sentence_$i';
          final pattern = RegExp('(^|\\s)${RegExp.escape(marker)}(\\s|\$)');
          final found = chunks.any(pattern.hasMatch);
          expect(
            found,
            isTrue,
            reason: 'Sentence marker "$marker" not found in any chunk',
          );
        }
      });

      test('handles CJK text without whitespace', () {
        // Build a long string of CJK characters (no word-separating spaces).
        // 500 characters exceeds kChunkTargetTokens (256) when estimated as
        // 1 token per character.
        final cjkText = List.generate(500, (i) => '字').join();
        final chunks = TextChunker.chunk(cjkText);
        expect(
          chunks.length,
          greaterThan(1),
          reason: 'CJK text should be chunked by character count',
        );

        // All characters should be covered
        final rejoined = chunks.join();
        expect(rejoined.runes.length, greaterThanOrEqualTo(500));
      });

      test('estimates CJK tokens by character count', () {
        // A single "word" of 100 CJK characters
        final cjk = List.generate(100, (i) => '漢').join();
        final tokens = TextChunker.estimateTokens(cjk);
        // Should use character count (100), not word count (1 × 1.3 = 2)
        expect(tokens, 100);
      });

      test('splits long sentence among shorter ones', () {
        final shortBefore = List.generate(
          5,
          (i) => 'Short sentence before number $i.',
        );
        final longSentence = List.generate(500, (i) => 'word$i').join(' ');
        final shortAfter = List.generate(
          5,
          (i) => 'Short sentence after number $i.',
        );
        final text = [...shortBefore, longSentence, ...shortAfter].join(' ');
        final chunks = TextChunker.chunk(text);

        expect(chunks.length, greaterThan(1));
        _expectAllChunksWithinTokenLimit(chunks, kChunkTargetTokens);
      });

      test('splits multiple consecutive long sentences', () {
        final longSentences = List.generate(
          3,
          (j) => List.generate(400, (i) => 'seg${j}w$i').join(' '),
        );
        // Join with period + space so sentence splitter sees boundaries
        final text = longSentences.join('. ');
        final chunks = TextChunker.chunk(text);

        expect(chunks.length, greaterThan(3));
        _expectAllChunksWithinTokenLimit(chunks, kChunkTargetTokens);
      });

      test('no chunk exceeds target tokens after sentence expansion', () {
        final sentences = <String>[
          'This is a normal length sentence about testing.',
          List.generate(350, (i) => 'alpha$i').join(' '),
          'Another perfectly normal sentence here.',
          List.generate(400, (i) => 'beta$i').join(' '),
          'Final short sentence.',
        ];
        final text = sentences.join('. ');
        final chunks = TextChunker.chunk(text);
        _expectAllChunksWithinTokenLimit(chunks, kChunkTargetTokens);
      });

      test('splits long whitespace-free non-CJK text (URL/minified)', () {
        // A 3000-character URL-like string with no whitespace or CJK.
        // Previously this would be estimated as ~2 tokens and returned
        // as a single chunk, exceeding the model's context window.
        final longUrl = 'https://example.com/path?q=${'x' * 2970}';
        final chunks = TextChunker.chunk(longUrl);

        // Should produce multiple chunks
        expect(
          chunks.length,
          greaterThan(1),
          reason: 'A 3000-char URL must be split into multiple chunks',
        );

        // No chunk should exceed the character-based limit
        for (var i = 0; i < chunks.length; i++) {
          final tokens = TextChunker.estimateTokens(chunks[i]);
          expect(
            tokens,
            lessThanOrEqualTo(kChunkTargetTokens),
            reason: 'Chunk $i has $tokens estimated tokens',
          );
        }

        // All content must be preserved
        final rejoined = chunks.join();
        expect(rejoined.length, greaterThanOrEqualTo(longUrl.length));
      });

      test('trims leading and trailing whitespace', () {
        const text = '  Short text with spaces.  ';
        final chunks = TextChunker.chunk(text);
        expect(chunks, hasLength(1));
        expect(chunks.first, 'Short text with spaces.');
      });
    });
  });
}
