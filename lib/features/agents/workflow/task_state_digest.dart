import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/projection/content_digest.dart';
import 'package:lotti/features/ai/util/image_ai_responses.dart';

/// The digest of the journal state a task agent's wake reads, which
/// `AgentWakeCoordinator` compares across devices: equal digests mean a wake
/// on either device would read the same inputs.
///
/// It covers the version — the vector clock, or `updatedAt` for an entity
/// without one — of every journal entity the task context is built from: the
/// task, the entities linked from it (log entries, linked tasks) and to it
/// (its project, tasks linking to it), its checklists and their items, and
/// the AI analyses of its images. Replicas that hold the same versions
/// compute the same digest without coordinating, and any edit to one of
/// those entities changes it. Versions rather than rendered content keep the
/// digest cheap, and a spurious mismatch only costs a run that would have
/// happened without coordination.
///
/// A wake's own journal writes are almost all change-set proposals, which
/// live in the agent database and leave this digest alone, so a peer holding
/// the synced result of a completed wake still matches the digest that wake
/// announced. The exception is the initial title or language a wake sets on
/// a task that has none; the peer then runs once more.
///
/// Returns `null` when [taskId] is not a task.
Future<String?> taskStateDigest({
  required JournalDb journalDb,
  required String taskId,
}) async {
  final task = await journalDb.journalEntityById(taskId);
  if (task is! Task) return null;

  final linkedFrom = await journalDb.getLinkedEntities(taskId);
  final linkedTo = (await journalDb.getLinkedToEntities(
    taskId,
  )).map(fromDbEntity);
  final checklists = await journalDb.getJournalEntitiesForIdsUnordered(
    (task.data.checklistIds ?? const <String>[]).toSet(),
  );
  final items = await journalDb.getJournalEntitiesForIdsUnordered({
    for (final checklist in checklists.whereType<Checklist>())
      ...checklist.data.linkedChecklistItems,
  });
  final analyses = await fetchAiResponsesForImages(
    db: journalDb,
    linkedEntities: linkedFrom,
  );

  return ContentDigest.of(<String, Object?>{
    for (final entity in [
      task,
      ...linkedFrom,
      ...linkedTo,
      ...checklists,
      ...items,
      for (final responses in analyses.values) ...responses,
    ])
      entity.meta.id: _version(entity.meta),
  });
}

Object _version(Metadata meta) =>
    meta.vectorClock?.vclock ?? meta.updatedAt.toUtc().toIso8601String();
