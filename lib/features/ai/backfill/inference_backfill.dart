import 'package:flutter/foundation.dart';
import 'package:lotti/classes/ai/skill_type.dart';
import 'package:lotti/classes/ai_response_type.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/services/skill_inference_runner.dart'
    show hasSummarizableContent;

/// One kind of inference a task entry can be missing.
///
/// [toolName] is the identifier a backfill suggestion carries in the task's
/// suggestion list. It is not an agent tool: no model ever sees or calls it,
/// and it never reaches a persisted change set.
enum InferenceBackfillKind {
  imageAnalysis(
    toolName: 'backfill_image_analysis',
    skillType: SkillType.imageAnalysis,
  ),
  transcription(
    toolName: 'backfill_transcription',
    skillType: SkillType.transcription,
  ),
  audioSummary(
    toolName: 'backfill_audio_summary',
    skillType: SkillType.audioSummary,
  );

  const InferenceBackfillKind({
    required this.toolName,
    required this.skillType,
  });

  final String toolName;
  final SkillType skillType;

  /// The inference statuses that mean this entry is already being worked on.
  ///
  /// An audio entry counts as busy for either of its kinds while the other is
  /// running: an automated transcription runs the summary straight after it,
  /// so offering a summary mid-transcription would summarize it twice.
  Set<AiResponseType> get busyResponseTypes => switch (this) {
    imageAnalysis => const {AiResponseType.imageAnalysis},
    transcription || audioSummary => const {
      AiResponseType.audioTranscription,
      AiResponseType.audioSummary,
    },
  };

  static InferenceBackfillKind? fromToolName(String toolName) =>
      values.where((kind) => kind.toolName == toolName).firstOrNull;
}

/// A task entry that is missing one kind of inference.
@immutable
class InferenceBackfillCandidate {
  const InferenceBackfillCandidate({
    required this.entryId,
    required this.kind,
    required this.capturedAt,
  });

  final String entryId;
  final InferenceBackfillKind kind;

  /// When the image was taken or the recording started — what tells two
  /// otherwise identical suggestions apart.
  final DateTime capturedAt;

  /// Identity of the suggestion: one per entry and kind.
  String get key => '${kind.name}:$entryId';

  @override
  bool operator ==(Object other) =>
      other is InferenceBackfillCandidate &&
      other.entryId == entryId &&
      other.kind == kind &&
      other.capturedAt == capturedAt;

  @override
  int get hashCode => Object.hash(entryId, kind, capturedAt);

  @override
  String toString() => 'InferenceBackfillCandidate($key)';
}

/// The inference [entry] is missing, given the AI [responses] linked from it,
/// or null when it is missing none — or is not media at all.
///
/// - **Image:** missing analysis when no `imageAnalysis` response hangs off
///   it. An image that carries its own text counts as analysed: the legacy
///   analysis path appended its result to the image's text instead of
///   linking a response, and analysing it again would only pay twice.
/// - **Audio:** missing transcription when it has neither a transcript nor
///   text. Text without a transcript is the user's own, and a transcription
///   run would overwrite it. Once there is content, missing a summary when no
///   `audioSummary` response exists and the content is long enough for the
///   summary run to accept it ([hasSummarizableContent]).
///
/// At most one kind per entry: a recording without a transcript gets its
/// summary from the transcription run itself.
InferenceBackfillKind? missingInferenceFor(
  JournalEntity entry,
  Iterable<AiResponseEntry> responses,
) {
  if (entry.meta.deletedAt != null) return null;
  bool hasResponse(AiResponseType type) => responses.any(
    (response) => response.meta.deletedAt == null && response.data.type == type,
  );
  final hasText = entry.entryText?.plainText.trim().isNotEmpty ?? false;

  switch (entry) {
    case JournalImage():
      if (hasText || hasResponse(AiResponseType.imageAnalysis)) return null;
      return InferenceBackfillKind.imageAnalysis;
    case JournalAudio(:final data):
      final hasTranscript = data.transcripts?.isNotEmpty ?? false;
      if (!hasTranscript && !hasText) {
        return InferenceBackfillKind.transcription;
      }
      if (hasResponse(AiResponseType.audioSummary) ||
          !hasSummarizableContent(entry)) {
        return null;
      }
      return InferenceBackfillKind.audioSummary;
    default:
      return null;
  }
}

/// Every candidate among [linkedEntries], newest first, using the responses
/// in [responsesByEntryId] (keyed by the entry they are linked from).
List<InferenceBackfillCandidate> findMissingInference(
  Iterable<JournalEntity> linkedEntries,
  Map<String, List<AiResponseEntry>> responsesByEntryId,
) {
  final candidates = <InferenceBackfillCandidate>[];
  for (final entry in linkedEntries) {
    final kind = missingInferenceFor(
      entry,
      responsesByEntryId[entry.meta.id] ?? const [],
    );
    if (kind == null) continue;
    candidates.add(
      InferenceBackfillCandidate(
        entryId: entry.meta.id,
        kind: kind,
        capturedAt: entry.meta.dateFrom,
      ),
    );
  }
  candidates.sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
  return candidates;
}
