// Sentence-aware text chunking for the Supertonic TTS engine.
//
// Faithfully ported from Supertone's open-source Supertonic Flutter example
// (github.com/supertone-inc/supertonic — MIT-licensed sample code). The model
// synthesizes one chunk at a time and the caller concatenates the audio with
// short silences between chunks, so chunk boundaries should fall on sentence
// breaks, never mid-word.

/// Splits [text] into chunks no longer than [maxLen] characters, breaking on
/// paragraph and sentence boundaries (and never inside a sentence unless a
/// single sentence already exceeds [maxLen]).
///
/// Korean and Japanese use a shorter [maxLen] (120) than Latin-script
/// languages (300) upstream; callers pass the appropriate value.
List<String> chunkText(String text, {int maxLen = 300}) {
  final paragraphs = text
      .trim()
      .split(RegExp(r'\n\s*\n+'))
      .where((p) => p.trim().isNotEmpty)
      .toList();

  final chunks = <String>[];
  for (var paragraph in paragraphs) {
    paragraph = paragraph.trim();
    if (paragraph.isEmpty) continue;

    final sentences = paragraph.split(
      RegExp(r'(?<!Mr\.|Mrs\.|Ms\.|Dr\.|Prof\.)(?<!\b[A-Z]\.)(?<=[.!?])\s+'),
    );

    var currentChunk = '';
    for (final sentence in sentences) {
      if (currentChunk.length + sentence.length + 1 <= maxLen) {
        currentChunk += (currentChunk.isNotEmpty ? ' ' : '') + sentence;
      } else {
        if (currentChunk.isNotEmpty) chunks.add(currentChunk.trim());
        currentChunk = sentence;
      }
    }
    if (currentChunk.isNotEmpty) chunks.add(currentChunk.trim());
  }

  return chunks;
}

/// Max chunk length for [lang]; KO/JA pack fewer characters per chunk.
int maxChunkLenForLang(String lang) =>
    (lang == 'ko' || lang == 'ja') ? 120 : 300;
