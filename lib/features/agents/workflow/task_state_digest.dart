import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/projection/content_digest.dart';
import 'package:lotti/features/ai/util/image_ai_responses.dart';

/// The digest of the state a task agent's wake reads, which
/// `AgentWakeCoordinator` compares across devices: equal digests mean a wake
/// on either device would read the same inputs.
///
/// It covers the version — the vector clock, or `updatedAt` for an entity
/// without one — of every entity the task context is built from:
///
/// - the task, the entities linked from it (log entries, linked tasks) and to
///   it (its project, tasks linking to it), its checklists and their items,
///   and the AI analyses of its images;
/// - for each linked task, the entities linked from it (the entries its time
///   spent is summed from) and the current report of its task agent, which
///   the linked-task context summarises.
///
/// Replicas that hold the same versions compute the same digest without
/// coordinating, and any edit to one of those entities changes it. A peer's
/// `done` for this digest cancels a wake, so an input the context reads but
/// the digest missed could be dropped unprocessed; keep this in step with the
/// context builders. Versions rather than rendered content keep the digest
/// cheap, and a spurious mismatch only costs a run that would have happened
/// without coordination.
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
  required AgentRepository agentRepository,
  required String taskId,
}) async {
  final task = await journalDb.journalEntityById(taskId);
  if (task is! Task) return null;

  final linkedFrom = await journalDb.getLinkedEntities(taskId);
  final linkedTo = (await journalDb.getLinkedToEntities(
    taskId,
  )).map(fromDbEntity).toList();
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

  final linkedTaskIds = {
    for (final linked in [...linkedFrom, ...linkedTo])
      if (linked is Task) linked.meta.id,
  };
  final linkedTaskInputs = linkedTaskIds.isEmpty
      ? const <String, List<JournalEntity>>{}
      : await journalDb.getBulkLinkedEntities(linkedTaskIds);
  final linkedTaskAgentLinks = linkedTaskIds.isEmpty
      ? const <String, List<AgentLink>>{}
      : await agentRepository.getLinksToMultiple(
          linkedTaskIds.toList(),
          type: AgentLinkTypes.agentTask,
        );
  final linkedAgentIds = {
    for (final links in linkedTaskAgentLinks.values)
      for (final link in links) link.fromId,
  };
  final linkedReports = linkedAgentIds.isEmpty
      ? const <String, AgentReportEntity>{}
      : await agentRepository.getLatestReportsByAgentIds(
          linkedAgentIds.toList(),
          AgentReportScopes.current,
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
    // Keyed by their linked task: moving an entry from one linked task to
    // another changes each one's summed time without changing the entry.
    for (final MapEntry(key: linkedTaskId, value: inputs)
        in linkedTaskInputs.entries)
      for (final input in inputs)
        'linked:$linkedTaskId>${input.meta.id}': _version(input.meta),
    for (final MapEntry(key: linkedTaskId, value: links)
        in linkedTaskAgentLinks.entries)
      for (final link in links)
        if (linkedReports[link.fromId] case final report?)
          'report:$linkedTaskId>${link.fromId}': {
            'id': report.id,
            'version':
                report.vectorClock?.vclock ??
                report.createdAt.toUtc().toIso8601String(),
          },
  });
}

Object _version(Metadata meta) =>
    meta.vectorClock?.vclock ?? meta.updatedAt.toUtc().toIso8601String();
