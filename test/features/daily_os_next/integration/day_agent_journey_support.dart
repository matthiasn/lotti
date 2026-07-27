import 'dart:async';

import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_trigger_tokens.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_job.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_outbox_repository.dart';

import 'day_agent_pipeline_harness.dart';

/// Runs one coordinator digest and fails with the completion's full error when
/// the wake does not finish successfully.
Future<void> runPlannerDigest({
  required DayAgentPipelineHarness harness,
  required AgentIdentityEntity coordinator,
  required String dayId,
}) async {
  final completions = StreamIterator<WakeRunCompletion>(
    harness.orchestrator.runCompletions,
  );
  try {
    final runKey = harness.orchestrator.enqueueManualWake(
      agentId: coordinator.agentId,
      reason: dayAgentDigestReason,
      triggerTokens: {dayAgentDigestToken(dayId)},
      workspaceKey: coordinatorDigestWorkspaceKey,
    );
    while (await completions.moveNext()) {
      final completion = completions.current;
      if (completion.runKey != runKey) continue;
      if (completion.status != WakeRunStatus.completed) {
        throw StateError(
          'Planner digest $runKey ended as ${completion.status.name}: '
          '${completion.error}',
        );
      }
      return;
    }
    throw StateError('Planner completion stream closed before $runKey.');
  } finally {
    await completions.cancel();
  }
}

/// Waits for one durable job to settle automatically or require intervention.
///
/// The observation cap deterministically stops a pathological update loop
/// without introducing a real timer into tests. The owning test timeout
/// remains the backstop for a completely silent processor.
Future<DayProcessingJob> waitForTerminalDayProcessingJob(
  DayProcessingOutboxRepository outbox,
  String jobId, {
  int maxObservedChanges = 100,
}) async {
  if (maxObservedChanges < 1) {
    throw ArgumentError.value(
      maxObservedChanges,
      'maxObservedChanges',
      'must be positive',
    );
  }
  final changes = StreamIterator<void>(outbox.changes);
  var observedChanges = 0;
  try {
    while (true) {
      final changed = changes.moveNext();
      final job = await outbox.getById(jobId);
      if (job != null &&
          (job.isTerminal ||
              job.status == DayProcessingJobStatus.failed ||
              job.status == DayProcessingJobStatus.waitingForUser)) {
        return job;
      }
      if (!await changed) {
        throw StateError('Outbox closed before $jobId settled.');
      }
      observedChanges += 1;
      if (observedChanges >= maxObservedChanges) {
        throw StateError(
          '$jobId did not settle after $observedChanges '
          'outbox changes.',
        );
      }
    }
  } finally {
    await changes.cancel();
  }
}

/// Throws when a settled durable job did not complete successfully.
void requireSuccessfulDayProcessingJob(
  DayProcessingJob job, {
  required String stage,
}) {
  if (job.status == DayProcessingJobStatus.succeeded) return;
  final detail = job.lastError;
  throw StateError(
    '$stage job ${job.id} settled as ${job.status.name}'
    '${detail == null || detail.isEmpty ? '.' : ': $detail'}',
  );
}
