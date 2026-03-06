/// Chunking constants for the mxbai-embed-large embedding model.
///
/// The model has a 512-token context window. We target 256 tokens per chunk
/// to leave generous headroom for content where the word-based heuristic
/// undercounts (code, URLs, technical jargon can be 2–3× the estimate).
/// Overlap is 48 tokens between consecutive chunks.
/// Token counts are estimated using a word-based heuristic (~1.3 tokens
/// per whitespace-delimited word for WordPiece tokenization).
const kChunkTargetTokens = 256;
const kChunkOverlapTokens = 48;
const int kChunkStrideTokens = kChunkTargetTokens - kChunkOverlapTokens; // 208
const kTokensPerWord = 1.3;
final int kChunkTargetWords = (kChunkTargetTokens / kTokensPerWord).floor();
final int kChunkOverlapWords = (kChunkOverlapTokens / kTokensPerWord).floor();
final int kChunkStrideWords = kChunkTargetWords - kChunkOverlapWords;

/// Pure utility for splitting long text into overlapping chunks suitable
/// for embedding models with limited context windows.
///
/// Uses sentence-boundary-aware splitting to avoid cutting mid-sentence.
/// Short texts (≤ [kChunkTargetTokens] estimated tokens) are returned
/// as a single chunk.
class TextChunker {
  TextChunker._();

  /// Splits [text] into overlapping chunks for embedding.
  ///
  /// Returns:
  /// - Empty list if [text] is null, empty, or whitespace-only
  /// - Single-element list if text fits within one chunk
  /// - Multiple overlapping chunks for longer text
  static List<String> chunk(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return [];

    if (estimateTokens(trimmed) <= kChunkTargetTokens) {
      return [trimmed];
    }

    var sentences = _splitIntoSentences(trimmed);
    if (sentences.isEmpty) return [];

    // Expand any sentence that exceeds the target token count into
    // word-boundary segments. This handles both single-segment texts
    // (e.g. markdown lists) and long sentences among shorter ones.
    sentences = sentences.expand((s) {
      if (estimateTokens(s) > kChunkTargetTokens) {
        return _splitOnWordBoundaries(s);
      }
      return [s];
    }).toList();

    return _buildOverlappingChunks(sentences);
  }

  /// Regex matching CJK Unified Ideographs, Hiragana, Katakana, and
  /// Korean Hangul syllables — scripts that use no word-separating spaces.
  static final _cjkPattern =
      RegExp(r'[\u3040-\u30ff\u3400-\u9fff\uac00-\ud7af]');

  /// Maximum character length before a single whitespace-free token is
  /// considered long enough to need character-based estimation. Derived
  /// from the chunk target assuming ~4 characters per token (conservative
  /// for URLs, minified code, base64, etc.).
  static const int _longTokenCharThreshold = kChunkTargetTokens * 4; // 1024

  /// Estimates the token count for [text] using a word-based heuristic.
  ///
  /// Assumes ~1.3 tokens per whitespace-delimited word, which is a
  /// reasonable approximation for English text with WordPiece tokenization.
  ///
  /// Falls back to character-based counting for:
  /// - CJK and other whitespace-free scripts (1 token per character)
  /// - Long whitespace-free non-CJK tokens such as URLs or minified code
  ///   (~4 characters per token)
  static int estimateTokens(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 0;

    final words = trimmed.split(RegExp(r'\s+'));

    if (words.length <= 1) {
      // CJK: use rune count (≈1 token per character).
      if (_cjkPattern.hasMatch(trimmed)) {
        return trimmed.runes.length;
      }

      // Long whitespace-free non-CJK token (URL, minified blob, base64):
      // estimate ~4 chars per token to avoid drastic undercount.
      if (trimmed.length >= _longTokenCharThreshold) {
        return (trimmed.length / 4).ceil();
      }
    }

    return (words.length * kTokensPerWord).ceil();
  }

  /// Splits text into sentences, preserving sentence-ending punctuation.
  ///
  /// Handles common sentence boundaries: `.`, `!`, `?` followed by
  /// whitespace, and paragraph breaks (`\n\n`).
  static List<String> _splitIntoSentences(String text) {
    // Split on sentence-ending punctuation followed by whitespace,
    // or on paragraph breaks. Keep the delimiter with the preceding sentence.
    final parts = <String>[];
    final pattern = RegExp(r'(?<=[.!?。！？])\s+|\n\n+');
    var lastEnd = 0;

    for (final match in pattern.allMatches(text)) {
      final sentence = text.substring(lastEnd, match.start).trim();
      if (sentence.isNotEmpty) {
        parts.add(sentence);
      }
      lastEnd = match.end;
    }

    // Remaining text after last match
    final remainder = text.substring(lastEnd).trim();
    if (remainder.isNotEmpty) {
      parts.add(remainder);
    }

    return parts;
  }

  /// Splits a long text with no sentence boundaries into word-level segments
  /// of approximately [kChunkTargetWords] words each.
  ///
  /// This is a fallback for content like markdown lists or code blocks that
  /// lack sentence-ending punctuation. Each segment becomes a "sentence" for
  /// the overlapping chunk builder.
  ///
  /// For CJK text with no whitespace, falls back to character-based splitting
  /// using [kChunkTargetTokens] as the character window.
  /// Maximum characters per segment when splitting long whitespace-free
  /// non-CJK text. Matches the token estimate of ~4 chars/token.
  static const int _maxCharsPerSegment = kChunkTargetTokens * 4; // 1024

  static List<String> _splitOnWordBoundaries(String text) {
    final words = text.split(RegExp(r'\s+'));

    // Whitespace-free text: split by character windows.
    if (words.length <= 1) {
      // CJK: 1 token per character.
      if (_cjkPattern.hasMatch(text)) {
        final runes = text.runes.toList();
        if (runes.length <= kChunkTargetTokens) return [text];
        final segments = <String>[];
        for (var i = 0; i < runes.length; i += kChunkStrideTokens) {
          final end = (i + kChunkTargetTokens).clamp(0, runes.length);
          segments.add(String.fromCharCodes(runes.sublist(i, end)));
        }
        return segments;
      }

      // Long non-CJK token (URL, minified code, base64):
      // split by character windows using _maxCharsPerSegment.
      if (text.length >= _maxCharsPerSegment) {
        const stride = _maxCharsPerSegment - (kChunkOverlapTokens * 4);
        final segments = <String>[];
        for (var i = 0; i < text.length; i += stride) {
          final end = (i + _maxCharsPerSegment).clamp(0, text.length);
          segments.add(text.substring(i, end));
        }
        return segments;
      }
    }

    if (words.length <= kChunkTargetWords) return [text];

    final segments = <String>[];
    for (var i = 0; i < words.length; i += kChunkStrideWords) {
      final end = (i + kChunkTargetWords).clamp(0, words.length);
      segments.add(words.sublist(i, end).join(' '));
    }
    return segments;
  }

  /// Builds overlapping chunks from a list of sentences.
  ///
  /// Greedily fills each chunk up to [kChunkTargetTokens], then starts
  /// the next chunk by rewinding to include [kChunkOverlapTokens] worth
  /// of sentences from the end of the previous chunk.
  static List<String> _buildOverlappingChunks(List<String> sentences) {
    final chunks = <String>[];
    var sentenceIndex = 0;

    while (sentenceIndex < sentences.length) {
      final chunkSentences = <String>[];
      var chunkTokens = 0;
      var i = sentenceIndex;

      // Fill the chunk with sentences up to the target token count
      while (i < sentences.length) {
        final sentenceTokens = estimateTokens(sentences[i]);

        // If adding this sentence would exceed the target and we already
        // have content, stop here
        if (chunkTokens + sentenceTokens > kChunkTargetTokens &&
            chunkSentences.isNotEmpty) {
          break;
        }

        // Always include at least one segment per chunk
        chunkSentences.add(sentences[i]);
        chunkTokens += sentenceTokens;
        i++;
      }

      chunks.add(chunkSentences.join(' '));

      // If we've consumed all segments, we're done
      if (i >= sentences.length) break;

      // Find the rewind point for overlap: walk backwards from the end
      // of the current chunk's sentences to accumulate ~kChunkOverlapTokens
      var overlapTokens = 0;
      var overlapStart = chunkSentences.length;
      while (overlapStart > 0) {
        final prevTokens = estimateTokens(chunkSentences[overlapStart - 1]);
        if (overlapTokens + prevTokens > kChunkOverlapTokens &&
            overlapStart < chunkSentences.length) {
          break;
        }
        overlapTokens += prevTokens;
        overlapStart--;
      }

      // The next chunk starts from (sentenceIndex + overlapStart) in the
      // original sentences list, so we re-include the overlap sentences
      final nextIndex = sentenceIndex + overlapStart;

      // Safety: ensure we always make forward progress (at least 1 sentence)
      sentenceIndex = nextIndex > sentenceIndex ? nextIndex : sentenceIndex + 1;
    }

    return chunks;
  }
}
