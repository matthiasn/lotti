import 'package:lotti/classes/journal_entities.dart';

/// One-line preview for a collapsed audio log entry.
///
/// Prefers the entry's own `entryText` (where transcription writes — and
/// where an edited/cleaned transcript lives) and falls back to the latest
/// raw transcript (`transcripts.last`, the convention every other consumer
/// uses). All whitespace runs — including newlines — collapse to single
/// spaces so the preview reads as one line; the caller truncates visually
/// with an ellipsis rather than by character count.
///
/// Returns null when there is nothing to preview (not yet transcribed).
String? audioEntryOneLiner(JournalAudio audio) {
  final entryText = audio.entryText?.plainText.trim();
  final transcript = audio.data.transcripts?.isNotEmpty ?? false
      ? audio.data.transcripts!.last.transcript.trim()
      : null;
  final source = (entryText != null && entryText.isNotEmpty)
      ? entryText
      : transcript;
  if (source == null || source.isEmpty) return null;
  return source.replaceAll(RegExp(r'\s+'), ' ');
}
