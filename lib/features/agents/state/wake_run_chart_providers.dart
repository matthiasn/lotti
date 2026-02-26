import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/database/agent_database.dart'
    show WakeRunLogData;
import 'package:lotti/features/agents/database/agent_repository.dart'
    show AgentRepository;
import 'package:lotti/features/agents/model/task_resolution_time_series.dart';
import 'package:lotti/features/agents/model/task_resolution_time_series_utils.dart';
import 'package:lotti/features/agents/model/wake_run_time_series.dart';
import 'package:lotti/features/agents/model/wake_run_time_series_utils.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/providers/service_providers.dart' show journalDbProvider;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'wake_run_chart_providers.g.dart';

/// Computes time-series chart data for a template's wake runs.
///
/// Fetches raw [WakeRunLogData] via the [AgentRepository] and transforms
/// them into daily and per-version buckets suitable for mini chart rendering.
@riverpod
Future<WakeRunTimeSeries> templateWakeRunTimeSeries(
  Ref ref,
  String templateId,
) async {
  final repository = ref.watch(agentRepositoryProvider);
  final runs = await repository.getWakeRunsForTemplate(templateId);
  return computeTimeSeries(runs);
}

/// Computes task resolution time-series (true MTTR) for a template.
///
/// Bridges the agent database and journal database:
/// 1. Fetches all agents assigned to the template.
/// 2. For each agent, fetches `agent_task` links to find linked tasks.
/// 3. For each linked task, looks up the [JournalEntity] in the journal DB.
/// 4. Extracts the first DONE/REJECTED status from the task's status history.
/// 5. Computes MTTR as `status.createdAt - agent.createdAt`.
@riverpod
Future<TaskResolutionTimeSeries> templateTaskResolutionTimeSeries(
  Ref ref,
  String templateId,
) async {
  final templateService = ref.watch(agentTemplateServiceProvider);
  final repository = ref.watch(agentRepositoryProvider);
  final journalDb = ref.watch(journalDbProvider);

  final agents = await templateService.getAgentsForTemplate(templateId);
  final entries = <TaskResolutionEntry>[];

  for (final agent in agents) {
    final links = await repository.getLinksFrom(
      agent.agentId,
      type: 'agent_task',
    );

    for (final link in links) {
      final taskEntity = await journalDb.journalEntityById(link.toId);
      if (taskEntity is! Task) continue;

      final resolution = _findResolution(taskEntity.data.statusHistory);
      entries.add(
        TaskResolutionEntry(
          agentId: agent.agentId,
          taskId: link.toId,
          agentCreatedAt: agent.createdAt,
          resolvedAt: resolution?.createdAt,
          resolution: resolution != null
              ? (resolution is TaskDone ? 'done' : 'rejected')
              : null,
        ),
      );
    }
  }

  return computeResolutionTimeSeries(entries);
}

/// Finds the first DONE or REJECTED status in a task's status history.
TaskStatus? _findResolution(List<TaskStatus> statusHistory) {
  for (final status in statusHistory) {
    if (status is TaskDone || status is TaskRejected) {
      return status;
    }
  }
  return null;
}
