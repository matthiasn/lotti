import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/projection/input_capture.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/widgets/charts/utils.dart';

/// Renders a task's linked journal **log entries** into [RenderedSource]s for
/// input capture (ADR 0020) — the per-source equivalent of the `logEntries`
/// that `AiInputRepository.generate` folds into the prompt's task context.
///
/// This mirrors that walk (text / image / audio, with edited text taking
/// precedence over a raw transcript) but keeps each entry's id as provenance
/// and snapshots the rendered **text** only — an audio entry contributes its
/// transcript, never the raw audio — so capture stays bounded by distinct
/// content. Keep in sync with `AiInputRepository.generate`.
///
/// Non-log linked entities (the task itself, checklists, quantitative entries,
/// …) are skipped: they are not part of the verbatim task log the agent reads.
///
/// [runningEntryId] names the entry whose timer is currently running, if any.
/// Its `loggedDuration` is still ticking, so it is omitted from the captured
/// content until the timer stops: capturing a moving duration would mint a new
/// content version (and mutate the entry's rendered line mid-log, voiding the
/// provider prefix cache) on every wake of a work session. The duration is
/// captured once, when it is final.
List<RenderedSource> renderTaskSources(
  Iterable<JournalEntity> linkedEntities, {
  String? runningEntryId,
}) {
  final sources = <RenderedSource>[];
  for (final linked in linkedEntities) {
    if (linked is! JournalEntry &&
        linked is! JournalImage &&
        linked is! JournalAudio) {
      continue;
    }

    // An explicit edit (even to empty string) takes precedence over a
    // transcript, matching how `generate` renders the entry text.
    final editedText = linked.entryText?.plainText;
    final hasEditedText = editedText != null;

    final String entryType;
    String? audioTranscript;
    String? transcriptLanguage;
    if (linked is JournalAudio) {
      entryType = 'audio';
      if (!hasEditedText) {
        final transcripts = linked.data.transcripts;
        if (transcripts != null && transcripts.isNotEmpty) {
          final latest = transcripts.last;
          audioTranscript = latest.transcript;
          transcriptLanguage = latest.detectedLanguage;
        }
      }
    } else if (linked is JournalImage) {
      entryType = 'image';
    } else {
      entryType = 'text';
    }

    sources.add(
      RenderedSource(
        contentEntryId: linked.meta.id,
        sourceCreatedAt: linked.meta.dateFrom,
        content: <String, Object?>{
          'entryType': entryType,
          // Preserve the per-entry logged duration that `generate`'s logEntries
          // carry, so the compacted read-flip keeps the same time evidence —
          // except while this entry's timer is still running (see doc comment).
          if (linked.meta.id != runningEntryId)
            'loggedDuration': formatHhMm(entryDuration(linked)),
          'text': editedText ?? '',
          'audioTranscript': ?audioTranscript,
          'transcriptLanguage': ?transcriptLanguage,
        },
      ),
    );
  }
  return sources;
}
