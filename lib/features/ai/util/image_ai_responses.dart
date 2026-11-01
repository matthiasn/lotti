import 'package:lotti/classes/journal_entities.dart';

/// One bulk read of the entities linked *from* each id, keyed by that id —
/// `JournalDb.getBulkLinkedEntities`, or `JournalRepository`'s pass-through
/// of it for a caller that only holds the repository.
typedef BulkLinkedEntitiesFetch =
    Future<Map<String, List<JournalEntity>>> Function(Set<String> fromIds);

/// Bulk-fetches the AI analysis responses (summary, OCR, …) linked from each
/// image entry in [linkedEntities].
///
/// Analyses are stored as [AiResponseEntry] entities linked *from* their image
/// (`fromId = imageId`), one entry per analysis run — the same shape the
/// nested-AI-responses UI reads. This helper resolves them for every image in
/// one [getBulkLinkedEntities] call so callers assembling task or event
/// context (prompt JSON, agent input capture, the event agent's photo digest)
/// stay free of N+1 queries.
///
/// Returns a map keyed by image entry id. Only non-deleted [AiResponseEntry]
/// rows are included, sorted oldest-first so consumers read them in
/// chronological order. Images without analyses are absent from the map.
Future<Map<String, List<AiResponseEntry>>> fetchAiResponsesForImages({
  required BulkLinkedEntitiesFetch getBulkLinkedEntities,
  required Iterable<JournalEntity> linkedEntities,
}) async {
  final imageIds = linkedEntities
      .whereType<JournalImage>()
      .map((image) => image.meta.id)
      .toSet();
  if (imageIds.isEmpty) {
    return const <String, List<AiResponseEntry>>{};
  }

  final linkedByImageId = await getBulkLinkedEntities(imageIds);

  final result = <String, List<AiResponseEntry>>{};
  for (final entry in linkedByImageId.entries) {
    final responses =
        entry.value
            .whereType<AiResponseEntry>()
            .where((response) => response.meta.deletedAt == null)
            .toList()
          ..sort((a, b) => a.meta.dateFrom.compareTo(b.meta.dateFrom));
    if (responses.isNotEmpty) {
      result[entry.key] = responses;
    }
  }
  return result;
}
