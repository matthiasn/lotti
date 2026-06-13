import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart'
    show Any, AnyUtils, CombinableAny, Generator, IntAnys, ListAnys;
import 'package:lotti/features/ai/service/text_chunker.dart';

// ---------------------------------------------------------------------------
// Generators for estimateTokens mutual-exclusivity property.
// ---------------------------------------------------------------------------
enum EstimateTokensInputKind {
  /// Multiple whitespace-delimited ASCII words → word-count path.
  multiWord,

  /// Single CJK-only token → rune-count path.
  cjkSingleToken,

  /// Single long non-CJK whitespace-free token (≥ 1024 chars) → char/4 path.
  longNonCjkToken,
}

extension AnyEstimateTokens on Any {
  Generator<String> get estimateTokensInput => CombinableAny(this).combine2(
    AnyUtils(this).choose(EstimateTokensInputKind.values),
    intInRange(2, 30), // word count or token count
    (kind, countFactor) {
      switch (kind) {
        case EstimateTokensInputKind.multiWord:
          // Generate 2–30 ASCII words separated by spaces.
          return List.generate(
            countFactor,
            (i) => 'word$i',
          ).join(' ');
        case EstimateTokensInputKind.cjkSingleToken:
          // 2–30 CJK characters with no spaces.
          return List.generate(countFactor, (i) => '漢').join();
        case EstimateTokensInputKind.longNonCjkToken:
          // Single ASCII token of length ≥ 1024.
          final length = kChunkTargetTokens * 4 + countFactor * 10;
          return 'a' * length;
      }
    },
  );
}

/// Input families paired with the formula their path must produce. Covers
/// all three `estimateTokens` paths plus the two exclusivity edges (a short
/// single ASCII token, and CJK content that is multi-word and therefore must
/// NOT take the rune-count path).
enum EstimateTokensOracleKind {
  multiWord,
  cjkSingleToken,
  cjkMultiWord,
  shortSingleToken,
  longNonCjkToken,
}

extension AnyEstimateTokensOracle on Any {
  Generator<(String, int)> get estimateTokensCase =>
      CombinableAny(this).combine2(
        AnyUtils(this).choose(EstimateTokensOracleKind.values),
        intInRange(2, 30),
        (kind, countFactor) {
          switch (kind) {
            case EstimateTokensOracleKind.multiWord:
              final input = List.generate(
                countFactor,
                (i) => 'word$i',
              ).join(' ');
              return (input, (countFactor * kTokensPerWord).ceil());
            case EstimateTokensOracleKind.cjkSingleToken:
              // Whitespace-free CJK → rune count.
              return ('漢' * countFactor, countFactor);
            case EstimateTokensOracleKind.cjkMultiWord:
              // CJK content WITH spaces is multi-word → word path, not
              // rune count (path exclusivity).
              final input = List.generate(
                countFactor,
                (_) => '漢字',
              ).join(' ');
              return (input, (countFactor * kTokensPerWord).ceil());
            case EstimateTokensOracleKind.shortSingleToken:
              // Single ASCII token below the long-token threshold → word
              // path with one word.
              return ('a' * countFactor, (1 * kTokensPerWord).ceil());
            case EstimateTokensOracleKind.longNonCjkToken:
              final length = kChunkTargetTokens * 4 + countFactor * 10;
              return ('a' * length, (length / 4).ceil());
          }
        },
      );
}

class GeneratedChunkText {
  const GeneratedChunkText({
    required this.wordCounts,
    required this.separator,
    required this.leadingWhitespace,
    required this.trailingWhitespace,
  });

  final List<int> wordCounts;
  final String separator;
  final String leadingWhitespace;
  final String trailingWhitespace;

  String get text {
    if (wordCounts.isEmpty) {
      return '$leadingWhitespace$trailingWhitespace';
    }

    final sentences = [
      for (final (sentenceIndex, wordCount) in wordCounts.indexed)
        hSentence(sentenceIndex, wordCount),
    ];
    return '$leadingWhitespace${sentences.join(separator)}$trailingWhitespace';
  }

  List<String> get markers => [
    for (final (sentenceIndex, wordCount) in wordCounts.indexed)
      for (var wordIndex = 0; wordIndex < wordCount; wordIndex++)
        hMarker(sentenceIndex, wordIndex),
  ];

  @override
  String toString() {
    return 'GeneratedChunkText('
        'wordCounts: $wordCounts, '
        'separator: ${separator.replaceAll('\n', r'\n')}, '
        'leadingWhitespace: ${leadingWhitespace.replaceAll('\n', r'\n')}, '
        'trailingWhitespace: ${trailingWhitespace.replaceAll('\n', r'\n')})';
  }
}

class GeneratedLongToken {
  const GeneratedLongToken({
    required this.length,
    required this.character,
    required this.leadingWhitespace,
    required this.trailingWhitespace,
  });

  final int length;
  final String character;
  final String leadingWhitespace;
  final String trailingWhitespace;

  String get token => character * length;
  String get text => '$leadingWhitespace$token$trailingWhitespace';

  @override
  String toString() {
    return 'GeneratedLongToken('
        'length: $length, '
        'character: $character, '
        'leadingWhitespace: ${leadingWhitespace.replaceAll('\n', r'\n')}, '
        'trailingWhitespace: ${trailingWhitespace.replaceAll('\n', r'\n')})';
  }
}

extension AnyTextChunkerScenarios on Any {
  Generator<GeneratedChunkText> get chunkText => combine4(
    listWithLengthInRange(0, 90, intInRange(1, 24)),
    choose(['. ', '! ', '? ', '\n\n']),
    choose(['', ' ', '\n\t']),
    choose(['', ' ', '\n']),
    (
      List<int> wordCounts,
      String separator,
      String leadingWhitespace,
      String trailingWhitespace,
    ) => GeneratedChunkText(
      wordCounts: wordCounts,
      separator: separator,
      leadingWhitespace: leadingWhitespace,
      trailingWhitespace: trailingWhitespace,
    ),
  );

  Generator<GeneratedLongToken> get longToken => combine4(
    intInRange(kChunkTargetTokens * 4, kChunkTargetTokens * 16),
    choose(['a', 'Z', '7', '_']),
    choose(['', ' ', '\n']),
    choose(['', ' ', '\n']),
    (
      int length,
      String character,
      String leadingWhitespace,
      String trailingWhitespace,
    ) => GeneratedLongToken(
      length: length,
      character: character,
      leadingWhitespace: leadingWhitespace,
      trailingWhitespace: trailingWhitespace,
    ),
  );
}

String hMarker(int sentenceIndex, int wordIndex) =>
    's${sentenceIndex.toString().padLeft(3, '0')}'
    'w${wordIndex.toString().padLeft(3, '0')}';

String hSentence(int sentenceIndex, int wordCount) {
  final words = [
    for (var wordIndex = 0; wordIndex < wordCount; wordIndex++)
      hMarker(sentenceIndex, wordIndex),
  ];
  return '${words.join(' ')}.';
}

/// Asserts that every chunk's estimated token count is at most [limit].
void hExpectAllChunksWithinTokenLimit(List<String> chunks, int limit) {
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

List<String> hMarkersInChunk(String chunk, List<String> markers) {
  return [
    for (final marker in markers)
      if (chunk.contains(marker)) marker,
  ];
}
