import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/wake/agent_wake_coordinator.dart';
import 'package:lotti/features/sync/vector_clock.dart';

/// The rows a task agent's wake reads, with their vector clocks, which
/// `AgentWakeCoordinator` checks against a peer's watermark: a peer that holds
/// every write these clocks rest on has read everything this wake would.
///
/// The rows are the task's neighbourhood, removed rows included:
///
/// - the task, every link from or to it and the entity at the other end —
///   log entries, images, linked tasks, its project;
/// - its checklists and their items;
/// - for each linked image and linked task, every link from or to it and the
///   entity at the other end — the image's AI analyses, the entries a linked
///   task's time spent is summed from;
/// - for each linked task, its task agent's link and current report, which the
///   linked-task context summarises.
///
/// Removed links and deleted entities stay in: a removal is a write like any
/// other, and only a row that is read has its clock checked. A peer that has
/// not seen the removal then does not cover this wake. The reads are
/// deliberately wider than the context builders' — a row that is read but
/// never rendered can only cost a run, never drop one — so keep every input
/// the context builders add inside this neighbourhood.
///
/// Returns `null` when [taskId] is not a task.
Future<WakeInputs?> taskWakeInputs({
  required JournalDb journalDb,
  required AgentRepository agentRepository,
  required String taskId,
}) async {
  final task = await journalDb.journalEntityById(taskId);
  if (task is! Task) return null;

  final clocks = <String, VectorClock?>{'entry:$taskId': task.meta.vectorClock};

  Future<Map<String, JournalEntity>> ring(Set<String> ids) async {
    final links = await journalDb.linksForEntryIdsBidirectionalIncludingRemoved(
      ids,
    );
    for (final link in links) {
      clocks['link:${link.id}'] = link.vectorClock;
    }
    final entities = await journalDb.journalEntityMapForIdsIncludingDeleted(
      {
        for (final link in links) ...[link.fromId, link.toId],
      }..removeAll(ids),
    );
    for (final entity in entities.values) {
      clocks['entry:${entity.meta.id}'] = entity.meta.vectorClock;
    }
    return entities;
  }

  final neighbours = await ring({taskId});

  final checklists = await journalDb.journalEntityMapForIdsIncludingDeleted(
    task.data.checklistIds ?? const <String>[],
  );
  final items = await journalDb.journalEntityMapForIdsIncludingDeleted({
    for (final checklist in checklists.values.whereType<Checklist>())
      ...checklist.data.linkedChecklistItems,
  });
  for (final entity in [...checklists.values, ...items.values]) {
    clocks['entry:${entity.meta.id}'] = entity.meta.vectorClock;
  }

  final linkedTaskIds = {
    for (final entity in neighbours.values)
      if (entity is Task) entity.meta.id,
  };
  await ring({
    ...linkedTaskIds,
    for (final entity in neighbours.values)
      if (entity is JournalImage) entity.meta.id,
  });

  if (linkedTaskIds.isNotEmpty) {
    final agentLinks = await agentRepository.getLinksToMultiple(
      linkedTaskIds.toList(),
      type: AgentLinkTypes.agentTask,
    );
    final agentIds = <String>{};
    for (final link in agentLinks.values.expand((links) => links)) {
      clocks['agentLink:${link.id}'] = link.vectorClock;
      agentIds.add(link.fromId);
    }
    if (agentIds.isNotEmpty) {
      final reports = await agentRepository.getLatestReportsByAgentIds(
        agentIds.toList(),
        AgentReportScopes.current,
      );
      for (final report in reports.values) {
        clocks['report:${report.id}'] = report.vectorClock;
      }
    }
  }

  return WakeInputs(
    clocks: clocks,
    readsPrivate: await journalDb.getConfigFlag('private'),
  );
}
