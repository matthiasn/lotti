import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';

/// Pure placeholder-formatting helpers used by `PromptBuilderHelper` to turn
/// already-fetched data (entry text, dictionary terms, correction examples)
/// into prompt fragments. These functions perform no I/O and hold no state, so
/// they live as standalone top-level functions and are independently testable.

/// Maximum number of correction examples to inject into prompts.
/// Examples beyond this limit are not injected (but remain stored for future
/// use).
const int kMaxCorrectionExamples = 500;

/// Template for the correction examples prompt injection.
/// The `{examples}` placeholder is replaced with the formatted examples.
const String kCorrectionExamplesPromptTemplate = '''
USER-PROVIDED CORRECTION EXAMPLES:
The user has manually corrected these checklist item titles in the past.
When creating or updating items, apply these corrections when you see matching patterns.

{examples}
''';

/// Template for the speech dictionary prompt injection.
/// The `{terms}` placeholder is replaced with the formatted dictionary terms.
const String kSpeechDictionaryPromptTemplate = '''
IMPORTANT - SPEECH DICTIONARY (MUST USE):
The following terms are domain-specific and MUST be spelled exactly as shown when they appear in the audio.
Speech recognition often misinterprets these terms. When you hear anything that sounds like these terms,
you MUST use the exact spelling and casing provided below - do NOT use alternative spellings.

Required spellings: {terms}

Examples of what to correct:
- "mac OS" or "Mac OS" → use the dictionary spelling if "macOS" is listed
- "i phone" or "I Phone" → use the dictionary spelling if "iPhone" is listed
- Any phonetically similar word → use the exact dictionary term''';

/// Escapes a string for safe embedding inside a JSON-style quoted token:
/// backslashes, double quotes, and newlines.
String escapeForJsonToken(String s) =>
    s.replaceAll(r'\', r'\\').replaceAll('"', r'\"').replaceAll('\n', r'\n');

/// Resolves the best textual content for an entry.
///
/// Prefers user-edited text. For [JournalAudio] without edited text, falls
/// back to the most recently created transcript. Returns an empty string when
/// nothing usable is present.
String resolveEntryText(JournalEntity entry) {
  final editedText = entry.entryText?.plainText.trim();
  if (editedText != null && editedText.isNotEmpty) {
    return editedText;
  }

  if (entry is JournalAudio) {
    final transcripts = entry.data.transcripts;
    if (transcripts != null && transcripts.isNotEmpty) {
      final latestTranscript = transcripts.reduce(
        (current, candidate) =>
            candidate.created.isAfter(current.created) ? candidate : current,
      );
      final transcriptText = latestTranscript.transcript.trim();
      if (transcriptText.isNotEmpty) {
        return transcriptText;
      }
    }
  }

  return '';
}

/// Resolves the audio transcript for [entity].
///
/// Prioritises user-edited text over the original transcript (via
/// [resolveEntryText]). Returns a fallback message if [entity] is not a
/// [JournalAudio] or no transcript is available.
String resolveAudioTranscript(JournalEntity entity) {
  if (entity is! JournalAudio) {
    return '[Audio entry expected but received ${entity.runtimeType}]';
  }

  final text = resolveEntryText(entity);
  if (text.isNotEmpty) {
    return text;
  }

  return '[No transcription available]';
}

/// Formats speech dictionary [terms] into the speech-dictionary prompt
/// fragment. Returns an empty string when [terms] is empty.
String formatSpeechDictionaryPrompt(List<String> terms) {
  if (terms.isEmpty) return '';

  final termsJson = terms.map((t) => '"${escapeForJsonToken(t)}"').join(', ');

  return kSpeechDictionaryPromptTemplate.replaceAll('{terms}', '[$termsJson]');
}

/// Formats correction [examples] into the correction-examples prompt fragment.
///
/// Examples are sorted by `capturedAt` descending (most recent first) and
/// capped at [kMaxCorrectionExamples]. Returns an empty string when [examples]
/// is empty.
String formatCorrectionExamplesPrompt(
  List<ChecklistCorrectionExample> examples,
) {
  if (examples.isEmpty) return '';

  final sortedExamples = [...examples]
    ..sort((a, b) {
      final aTime = a.capturedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.capturedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime); // Descending (most recent first)
    });
  final cappedExamples = sortedExamples.take(kMaxCorrectionExamples).toList();

  final formattedExamples = cappedExamples
      .map((e) {
        final escapedBefore = e.before.replaceAll('"', r'\"');
        final escapedAfter = e.after.replaceAll('"', r'\"');
        return '- "$escapedBefore" → "$escapedAfter"';
      })
      .join('\n');

  return kCorrectionExamplesPromptTemplate.replaceAll(
    '{examples}',
    formattedExamples,
  );
}
