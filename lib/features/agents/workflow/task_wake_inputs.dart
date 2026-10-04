import 'dart:convert';

import 'package:lotti/classes/agents/agent_constants.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/classes/agents/agent_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/vector_clock.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/projection/content_digest.dart';
import 'package:lotti/features/agents/wake/agent_wake_coordinator.dart';
import 'package:lotti/features/agents/workflow/task_agent_workflow.dart';

/// The rows a wake of task agent [agentId] reads as input, with their vector
/// clocks, which `AgentWakeCoordinator` checks against a peer's watermark: a
/// peer that holds every write these clocks rest on has read everything this
/// wake would.
///
/// The journal rows are the task's neighbourhood, removed rows included:
///
/// - the task, every link from or to it and the entity at the other end —
///   log entries, images, linked tasks, its project;
/// - its checklists and their items;
/// - for each linked image and linked task, every link from or to it and the
///   entity at the other end — the image's AI analyses, the entries a linked
///   task's time spent is summed from.
///
/// The agent rows are the other agents' outputs and the user's choices the
/// context draws on:
///
/// - for each linked task and the parent project, the agent link and that
///   agent's current report and report head, which the linked-task and
///   parent-project context summarise;
/// - the user's decisions on this agent's proposals for the task, across the
///   window the proposal ledger reads, which stop a rejected proposal coming
///   back;
/// - the agent's template assignment, the template's head and active version,
///   and its soul assignment, head and active version — the system prompt;
/// - attention requests other agents raised on the task.
///
/// Rows this agent's own wakes write — its report, observations, messages,
/// change sets and its own attention requests — are outputs, not inputs: a
/// peer that ran wrote its own, and counting them would make every peer's run
/// look uncovering to the next. Its state and identity choose the task, the
/// model and the turn budget, not what the run reads, and the throttle writes
/// the state on every waiting device.
///
/// Label and category definitions carry no host counters, so no watermark can
/// cover them: [WakeInputs.definitions] digests the ones the context reads, and
/// only a peer that read the same ones covers this wake.
///
/// Removed links — journal and agent links alike — and deleted entities stay
/// in: a removal is a write like any other, and only a row that is read has
/// its clock checked. The reads are
/// deliberately wider than the context builders' — a row that is read but
/// never rendered can only cost a run, never drop one — so keep every input
/// the context builders add inside these rows.
///
/// Returns `null` when [taskId] is not a task.
Future<WakeInputs?> taskWakeInputs({
  required JournalDb journalDb,
  required AgentRepository agentRepository,
  required String agentId,
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

  void agentRows(String kind, Iterable<AgentDomainEntity?> entities) {
    for (final entity in entities.nonNulls) {
      clocks['$kind:${entity.id}'] = entity.vectorClock;
    }
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

  // Agent links are read with their tombstones: an unassignment is a write
  // the peer's run must have seen.
  Future<List<AgentLink>> links(Iterable<String> ids, String type) async {
    if (ids.isEmpty) return const [];
    final found = await agentRepository.getLinksTouchingIncludingDeleted(
      ids,
      type: type,
    );
    for (final link in found) {
      clocks['agentLink:${link.id}'] = link.vectorClock;
    }
    return found;
  }

  // Other agents' reports: the linked tasks' task agents, the parent
  // project's project agent. A report is selected through its head, which
  // moves separately, so both are inputs.
  final reportingAgentIds = {
    for (final link in [
      ...await links(linkedTaskIds, AgentLinkTypes.agentTask),
      ...await links(
        {
          for (final project in neighbours.values.whereType<ProjectEntry>())
            project.meta.id,
        },
        AgentLinkTypes.agentProject,
      ),
    ])
      link.fromId,
  };
  if (reportingAgentIds.isNotEmpty) {
    agentRows('reportHead', [
      for (final reportingAgentId in reportingAgentIds)
        await agentRepository.getReportHead(
          reportingAgentId,
          AgentReportScopes.current,
        ),
    ]);
    agentRows(
      'report',
      (await agentRepository.getLatestReportsByAgentIds(
        reportingAgentIds.toList(),
        AgentReportScopes.current,
      )).values,
    );
  }

  agentRows('decision', [
    for (final decision in await agentRepository.getChangeDecisions(
      agentId,
      taskId: taskId,
      limit: TaskAgentWorkflow.resolvedDecisionWindow,
    ))
      if (decision.actor == DecisionActor.user) decision,
  ]);

  for (final templateLink in await links({
    agentId,
  }, AgentLinkTypes.templateAssignment)) {
    final templateId = templateLink.fromId;
    agentRows('template', [
      await agentRepository.getEntity(templateId),
      await agentRepository.getTemplateHead(templateId),
      await agentRepository.getActiveTemplateVersion(templateId),
    ]);
    for (final soulLink in await links({
      templateId,
    }, AgentLinkTypes.soulAssignment)) {
      agentRows('soul', [
        await agentRepository.getSoulDocumentHead(soulLink.toId),
        await agentRepository.getActiveSoulDocumentVersion(soulLink.toId),
      ]);
    }
  }

  agentRows('attention', [
    for (final request in await agentRepository.getAttentionClaimsForTarget(
      targetKind: 'task',
      targetId: taskId,
    ))
      if (request.agentId != agentId) request,
  ]);

  final categoryId = task.meta.categoryId;
  final category = categoryId == null
      ? null
      : await journalDb.getCategoryByIdForIntegrity(categoryId);
  return WakeInputs(
    clocks: clocks,
    readsPrivate: await journalDb.getConfigFlag('private'),
    definitions: ContentDigest.of({
      'labels': {
        for (final label
            in await journalDb.getAllLabelDefinitionsIncludingPrivate())
          label.id: _plain(label),
      },
      'category': category == null ? null : _plain(category),
    }),
  );
}

/// A definition as plain JSON data: `toJson` leaves nested objects, such as
/// its vector clock, as objects.
Object? _plain(Object definition) => jsonDecode(jsonEncode(definition));
