import 'package:clock/clock.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/agents/agent_repository.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/workflow/task_agent_report_policy.dart';
import 'package:lotti/services/domain_logging.dart';

/// Arms [agentId]'s device-local `scheduledWakeAt` at its task's next due-date
/// boundary ([TaskAgentReportPolicy.nextDueBoundary]) when automatic updates
/// are switched on.
///
/// A wake arms it on commit only while automation is on, so a report written
/// with automation off left none, and switching on owes no catch-up wake over
/// a fresh report. Without this, an untouched task would keep a "due today"
/// report past its date with automation on. Written without a new version,
/// like every device-local schedule, so it cannot win a merge.
Future<void> armTaskDueDateWake(
  String agentId, {
  required AgentRepository repository,
  required JournalDb journalDb,
  required DomainLogger domainLogger,
}) async {
  try {
    final observed = await repository.getAgentState(agentId);
    final taskId = observed?.slots.activeTaskId;
    if (observed == null || taskId == null) return;
    final task = await journalDb.journalEntityById(taskId);
    final boundary = TaskAgentReportPolicy.nextDueBoundary(
      task is Task ? task.data : null,
      clock.now(),
    );
    if (boundary == null) return;
    // Over the row as it is now, and only if its schedule is still the one
    // seen before the lookup: a wake that committed meanwhile armed its own
    // boundary from fresher task data, and the rest of its row stands too.
    await repository.runInTransaction(() async {
      final current = await repository.getAgentState(agentId);
      if (current == null ||
          current.scheduledWakeAt != observed.scheduledWakeAt ||
          current.scheduledWakeAt == boundary) {
        return;
      }
      await repository.upsertEntity(
        current.copyWith(scheduledWakeAt: boundary),
      );
    });
  } catch (error, stackTrace) {
    // A missed boundary only delays the correction to the agent's next wake.
    domainLogger.error(
      LogDomain.agentRuntime,
      error,
      message:
          'failed to arm due-date wake for '
          '${DomainLogger.sanitizeId(agentId)}',
      stackTrace: stackTrace,
    );
  }
}
