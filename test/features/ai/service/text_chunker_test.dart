import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' show ExploreConfig, Glados, any;
import 'package:lotti/features/ai/service/text_chunker.dart';
import 'text_chunker_test_helpers.dart';

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
        // Each sentence starts with a unique marker (alpha$i) so the first
        // word of a chunk pins exactly which sentence it begins with.
        final sentences = List.generate(
          60,
          (i) => 'alpha$i is a unique sentence about beta$i.',
        );
        final text = sentences.join(' ');
        final chunks = TextChunker.chunk(text);

        expect(
          chunks.length,
          greaterThan(1),
          reason: 'Need multiple chunks to test overlap',
        );

        // The chunk builder rewinds by whole sentences to create overlap, so
        // the (unique) first word of each chunk must reappear inside the
        // previous chunk. This is a direct consequence of the production
        // overlap logic and avoids the fragile fractional-window heuristic
        // that could pick a single-word slice and yield a false negative on
        // short content.
        for (var i = 0; i < chunks.length - 1; i++) {
          final nextFirstWord = chunks[i + 1].split(RegExp(r'\s+')).first;
          expect(
            nextFirstWord,
            startsWith('alpha'),
            reason: 'Each chunk should begin at a sentence marker',
          );
          expect(
            chunks[i].split(RegExp(r'\s+')),
            contains(nextFirstWord),
            reason:
                'The first word of chunk ${i + 1} ("$nextFirstWord") must '
                'reappear in chunk $i to prove the overlap.',
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
        hExpectAllChunksWithinTokenLimit(chunks, kChunkTargetTokens);
      });

      test(
        'handles single very long sentence by splitting on word boundaries',
        () {
          // One sentence with 500 words (no sentence boundaries to split on)
          final longSentence = List.generate(500, (i) => 'word$i').join(' ');
          final chunks = TextChunker.chunk(longSentence);
          // Should produce multiple chunks via word-boundary fallback
          expect(chunks.length, greaterThan(1));
          // Every word should appear in at least one chunk. Collect all chunk
          // tokens into a single set once (O(words)) instead of scanning every
          // chunk per word (O(words × chunks)). Splitting on whitespace yields
          // exact tokens, so 'word1' cannot be confused with 'word10'.
          final coveredWords = {
            for (final chunk in chunks) ...chunk.split(RegExp(r'\s+')),
          };
          for (var i = 0; i < 500; i++) {
            final marker = 'word$i';
            expect(
              coveredWords,
              contains(marker),
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
        hExpectAllChunksWithinTokenLimit(chunks, kChunkTargetTokens);
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

      test(
        'splits a long CJK-only sentence into overlapping rune-bounded chunks',
        () {
          // 600 distinct CJK characters with no whitespace exercises the
          // rune-stride branch of _splitOnWordBoundaries (window 256, stride
          // 208). Use a 600-character window of the CJK Unified Ideographs
          // block so every position is a unique, recoverable marker.
          const cjkBlockStart = 0x4e00; // 一
          final runes = List.generate(600, (i) => cjkBlockStart + i);
          final cjkText = String.fromCharCodes(runes);

          final chunks = TextChunker.chunk(cjkText);

          // Stride logic must produce more than one chunk.
          expect(chunks.length, greaterThan(1));

          // Every chunk must stay within the rune-based token budget and be a
          // contiguous, non-empty CJK slice of the source.
          for (final chunk in chunks) {
            expect(chunk.runes, isNotEmpty);
            expect(
              TextChunker.estimateTokens(chunk),
              lessThanOrEqualTo(kChunkTargetTokens),
            );
            expect(cjkText.contains(chunk), isTrue);
          }

          // Every source rune survives somewhere in the output.
          final coveredRunes = {
            for (final chunk in chunks) ...chunk.runes,
          };
          for (final rune in runes) {
            expect(
              coveredRunes,
              contains(rune),
              reason: 'CJK rune ${String.fromCharCode(rune)} was lost',
            );
          }

          // Consecutive chunks overlap: the first rune of chunk[i+1] reappears
          // in chunk[i] (the stride window is smaller than the chunk window).
          for (var i = 0; i < chunks.length - 1; i++) {
            final nextFirstRune = chunks[i + 1].runes.first;
            expect(
              chunks[i].runes,
              contains(nextFirstRune),
              reason: 'Chunks $i and ${i + 1} should overlap for CJK input',
            );
          }
        },
      );

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
        hExpectAllChunksWithinTokenLimit(chunks, kChunkTargetTokens);
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
        hExpectAllChunksWithinTokenLimit(chunks, kChunkTargetTokens);
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
        hExpectAllChunksWithinTokenLimit(chunks, kChunkTargetTokens);
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

      Glados(any.chunkText, ExploreConfig(numRuns: 160)).test(
        'preserves generated marker text while bounding chunk size',
        (scenario) {
          final chunks = TextChunker.chunk(scenario.text);
          final markers = scenario.markers;

          if (markers.isEmpty) {
            expect(chunks, isEmpty);
            return;
          }

          expect(chunks, isNotEmpty);
          hExpectAllChunksWithinTokenLimit(chunks, kChunkTargetTokens);

          for (final chunk in chunks) {
            expect(chunk, chunk.trim());
            expect(chunk, isNotEmpty);
          }

          for (final marker in markers) {
            expect(
              chunks.any((chunk) => chunk.contains(marker)),
              isTrue,
              reason: 'Marker $marker was lost for $scenario',
            );
          }

          expect(chunks.first, contains(markers.first));
          expect(chunks.last, contains(markers.last));

          for (var i = 0; i < chunks.length - 1; i++) {
            final currentMarkers = hMarkersInChunk(chunks[i], markers);
            final nextMarkers = hMarkersInChunk(chunks[i + 1], markers);

            expect(currentMarkers, isNotEmpty);
            expect(nextMarkers, isNotEmpty);
            expect(
              currentMarkers.toSet().intersection(nextMarkers.toSet()),
              isNotEmpty,
              reason: 'Chunks $i and ${i + 1} should overlap for $scenario',
            );
            expect(
              markers.indexOf(nextMarkers.first),
              lessThanOrEqualTo(markers.indexOf(currentMarkers.last)),
              reason: 'Chunk order moved forward without overlap for $scenario',
            );
          }
        },
        tags: 'glados',
      );

      // NOTE: a previous version of this file also asserted that long single
      // sentences split into exactly the chunks that the production word-
      // stride formula predicts, and that long whitespace-free tokens split
      // into exactly the chunks the production char-stride formula predicts.
      // Both properties re-derived the stride from production constants, so
      // a benign change to the stride policy would break them without
      // surfacing a real bug. The marker-preserving invariant above (and the
      // bounded-length invariant below) already protect the contract that
      // matters: every input fragment survives, every chunk is non-empty
      // and trimmed, and no chunk exceeds the token target.
      Glados(any.longToken, ExploreConfig(numRuns: 120)).test(
        'splits generated long whitespace-free tokens into bounded, '
        'character-pure chunks that fully cover the input',
        (scenario) {
          final chunks = TextChunker.chunk(scenario.text);

          expect(chunks, isNotEmpty, reason: '$scenario');
          hExpectAllChunksWithinTokenLimit(chunks, kChunkTargetTokens);
          for (final chunk in chunks) {
            expect(chunk, chunk.trim(), reason: '$scenario');
            expect(chunk, isNotEmpty, reason: '$scenario');
            expect(
              chunk.length,
              lessThanOrEqualTo(kChunkTargetTokens * 4),
              reason: '$scenario',
            );
            // The input is a single character repeated; chunks must contain
            // only that character (no separator leakage, no truncation
            // artefacts).
            expect(
              chunk.runes.every((r) => r == scenario.character.runes.single),
              isTrue,
              reason: '$scenario',
            );
          }
          // Concatenating the chunks covers the entire input (with overlap,
          // so length is greater-than-or-equal).
          expect(
            chunks.join().length,
            greaterThanOrEqualTo(scenario.token.length),
            reason: '$scenario',
          );
        },
        tags: 'glados',
      );
    });

    // -------------------------------------------------------------------------
    // Glados properties for estimateTokens path invariants.
    // -------------------------------------------------------------------------
    group('estimateTokens — Glados path invariants', () {
      Glados(
        any.estimateTokensInput,
        ExploreConfig(numRuns: 120),
      ).test(
        'non-empty input always yields a positive token count',
        (input) {
          // All generated inputs are non-empty by construction.
          expect(input, isNotEmpty);
          final result = TextChunker.estimateTokens(input);
          expect(
            result,
            greaterThan(0),
            reason: 'estimateTokens("$input") must be > 0 for non-empty input',
          );
        },
        tags: 'glados',
      );

      Glados(
        any.estimateTokensCase,
        ExploreConfig(numRuns: 150),
      ).test(
        'each input family is scored by exactly its own path formula '
        '(paths are mutually exclusive and collectively exhaustive)',
        (testCase) {
          final (input, expected) = testCase;
          expect(
            TextChunker.estimateTokens(input),
            expected,
            reason:
                'estimateTokens for ${input.length}-char input must follow '
                'the family formula',
          );
        },
        tags: 'glados',
      );

      Glados(
        any.estimateTokensInput,
        ExploreConfig(numRuns: 120),
      ).test(
        'result is consistent across two calls with identical input',
        (input) {
          expect(
            TextChunker.estimateTokens(input),
            TextChunker.estimateTokens(input),
            reason: 'estimateTokens must be deterministic',
          );
        },
        tags: 'glados',
      );
    });
  });
}
