import 'dart:developer' as developer;

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/ai/state/consts.dart';

/// Resolves the best available summary for a task by checking multiple sources
/// in priority order:
///
/// 1. **Agent report** (new system) — looked up via [AgentRepository] by
///    following the `agent_task` link to find the assigned agent, then
///    fetching its latest report. Prefers the short `tldr` field when
///    available, falling back to the full `content`.
/// 2. **Legacy AI response** — filters pre-fetched [JournalEntity] lists for
///    `taskSummary`-typed AI response entries (kept for backwards-compatibility
///    with tasks that predate the agent system).
///
/// This class exists so that every consumer of task summaries shares the same
/// fallback logic. Once all tasks are migrated to agents and the legacy enum
/// values are removed, this class can be simplified to agent-report-only.
class TaskSummaryResolver {
  TaskSummaryResolver(this._agentRepository);

  final AgentRepository? _agentRepository;

  /// Returns the best available summary for [taskId], or `null` if none
  /// exists from either source.
  ///
  /// When [linkedEntities] are provided (e.g. from a bulk pre-fetch), legacy
  /// summaries are extracted from that list without an extra DB call.
  Future<String?> resolve(
    String taskId, {
    List<JournalEntity> linkedEntities = const [],
  }) async {
    // 1. Try agent report first (the new, preferred source)
    final agentReport = await _getAgentReportForTask(taskId);
    if (agentReport != null) return agentReport;

    // 2. Fall back to legacy AiResponseType.taskSummary entries
    return _getLegacySummary(linkedEntities);
  }

  /// Look up the agent assigned to [taskId] and return its latest report
  /// content, or `null` if no agent or report exists.
  Future<String?> _getAgentReportForTask(String taskId) async {
    final repo = _agentRepository;
    if (repo == null) return null;

    try {
      final links = await repo.getLinksTo(
        taskId,
        type: AgentLinkTypes.agentTask,
      );
      if (links.isEmpty) return null;

      final agentId = links.first.fromId;
      final report = await repo.getLatestReport(
        agentId,
        AgentReportScopes.current,
      );
      if (report == null || report.content.isEmpty) return null;

      developer.log(
        'Found agent report for task $taskId '
        '(${(report.tldr ?? report.content).length} chars)',
        name: 'TaskSummaryResolver',
      );

      return report.tldr ?? report.content;
    } catch (e) {
      developer.log(
        'Error fetching agent report for task $taskId: $e',
        name: 'TaskSummaryResolver',
      );
      return null;
    }
  }

  /// Extract the latest legacy task summary from a list of journal entities.
  String? _getLegacySummary(List<JournalEntity> entities) {
    final summaries =
        entities
            .whereType<AiResponseEntry>()
            // ignore: deprecated_member_use_from_same_package
            .where((e) => e.data.type == AiResponseType.taskSummary)
            .toList()
          ..sort((a, b) => b.meta.dateFrom.compareTo(a.meta.dateFrom));

    if (summaries.isEmpty) return null;
    return summaries.first.data.response;
  }
}
