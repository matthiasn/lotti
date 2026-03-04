import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/service/text_chunker.dart';

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
        // ~295 words = ~384 tokens (the target)
        final words = List.generate(290, (i) => 'word$i');
        final text = words.join(' ');
        final chunks = TextChunker.chunk(text);
        // Should be 1 chunk since estimateTokens(290 words) = ceil(290*1.3) = 377 < 384
        expect(chunks, hasLength(1));
      });

      test('produces multiple chunks for long text', () {
        // Build text with ~600 words (well above 384 token threshold)
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

        expect(chunks.length, greaterThan(1),
            reason: 'Need multiple chunks to test overlap');

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
            reason: 'Chunks $i and ${i + 1} should overlap. '
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

        for (var i = 0; i < chunks.length; i++) {
          final tokens = TextChunker.estimateTokens(chunks[i]);
          // Allow some overshoot for sentence-boundary alignment,
          // but not more than 2× the target
          expect(
            tokens,
            lessThan(kChunkTargetTokens * 2),
            reason: 'Chunk $i has $tokens estimated tokens, '
                'which exceeds 2× target of $kChunkTargetTokens',
          );
        }
      });

      test('handles single very long sentence by splitting on word boundaries',
          () {
        // One sentence with 500 words (no sentence boundaries to split on)
        final longSentence = List.generate(500, (i) => 'word$i').join(' ');
        final chunks = TextChunker.chunk(longSentence);
        // Should produce multiple chunks via word-boundary fallback
        expect(chunks.length, greaterThan(1));
        // Every word should appear in at least one chunk
        for (var i = 0; i < 500; i++) {
          final marker = 'word$i';
          expect(
            chunks.any((chunk) => chunk.contains(marker)),
            isTrue,
            reason: 'Word "$marker" not found in any chunk',
          );
        }
      });

      test('handles paragraph breaks as sentence boundaries', () {
        final paragraphs = List.generate(
          20,
          (i) => 'Paragraph $i has multiple words discussing topic $i '
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

        // Every sentence marker should appear in at least one chunk
        for (var i = 0; i < sentences.length; i++) {
          final marker = 'Sentence_$i';
          final found = chunks.any((chunk) => chunk.contains(marker));
          expect(
            found,
            isTrue,
            reason: 'Sentence marker "$marker" not found in any chunk',
          );
        }
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
