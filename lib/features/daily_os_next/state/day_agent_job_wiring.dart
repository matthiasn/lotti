import 'package:lotti/features/agents/wake/wake_orchestrator.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_trigger_tokens.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_capture_service.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_plan_service.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_service.dart';
import 'package:lotti/features/daily_os_next/services/day_agent_job_executor.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_job.dart';

/// `YYYY-MM-DD` day id → the local calendar date it names.
///
/// Inverse of `dayPlanId`/`dayAgentIdForDate`; day ids are always of the
/// form `dayplan-YYYY-MM-DD`, so this is a straight substring parse rather
/// than a shared helper import (several exist across the workflow layer with
/// overlapping names — trivial enough to keep local to this wiring seam).
DateTime dateFromDayAgentId(String dayId) {
  const prefix = 'dayplan-';
  final iso = dayId.startsWith(prefix) ? dayId.substring(prefix.length) : dayId;
  return DateTime.parse(iso);
}

/// Builds the [DayAgentJobExecutor] that runs durable `parseCapture`/
/// `draftPlan`/`refinePlan` jobs (ADR 0032 phase 1) against the day-agent
/// layer, wiring its injected collaborators to the concrete services.
DayAgentJobExecutor buildDayAgentJobExecutor({
  required DayAgentService dayAgentService,
  required DayAgentPlanService planService,
  required DayAgentCaptureService captureService,
  required WakeOrchestrator orchestrator,
}) {
  return DayAgentJobExecutor(
    resolveAgentId: (dayId) async {
      final identity = await dayAgentService.getOrCreateDayAgentForDate(
        dateFromDayAgentId(dayId),
      );
      return identity.agentId;
    },
    enqueueWake: (request) {
      final job = request.job;
      final dayId = request.dayId;
      final (reason, tokens) = switch (job.payload) {
        ParseCapturePayload(:final captureId) => (
          dayAgentCaptureSubmittedReason,
          {dayAgentCaptureSubmittedToken(captureId)},
        ),
        DraftPlanPayload(
          :final captureId,
          :final decidedTaskIds,
          :final decidedCaptureItemIds,
        ) =>
          (
            dayAgentDraftingReason,
            {
              dayAgentPlanningDayToken(dayId),
              dayAgentDraftingToken(dayId),
              if (captureId != null && captureId.trim().isNotEmpty)
                dayAgentCaptureSubmittedToken(captureId.trim()),
              for (final id in decidedTaskIds)
                if (id.trim().isNotEmpty) dayAgentDecidedTaskToken(id.trim()),
              for (final id in decidedCaptureItemIds)
                if (id.trim().isNotEmpty)
                  dayAgentDecidedCaptureItemToken(id.trim()),
            },
          ),
        RefinePlanPayload(:final transcriptCaptureId) => (
          dayAgentRefineReason,
          {
            dayAgentPlanningDayToken(dayId),
            dayAgentRefineToken(dayId),
            if (transcriptCaptureId != null &&
                transcriptCaptureId.trim().isNotEmpty)
              dayAgentCaptureSubmittedToken(transcriptCaptureId.trim()),
          },
        ),
        TranscribeAudioPayload() => throw StateError(
          'DayAgentJobExecutor never claims transcribeAudio jobs',
        ),
      };
      return orchestrator.enqueueManualWake(
        agentId: request.agentId,
        reason: reason,
        triggerTokens: tokens,
        workspaceKey: dayAgentWorkspaceKey(dayId),
        // Each durable job is exactly one wake's worth of work; the outbox
        // — not the wake queue — owns coalescing (draft re-arm) and
        // accumulation (parse, refine), so the wake itself must never
        // supersede a sibling job's still-queued wake in the same workspace.
        supersede: false,
      );
    },
    runCompletions: orchestrator.runCompletions,
    draftPlanUpdatedAt: (agentId, dayId) async {
      final plan = await planService.draftPlanForDay(
        agentId: agentId,
        dayId: dayId,
      );
      return plan?.updatedAt;
    },
    pendingDiffCreatedSince: (agentId, dayId, since) async {
      final diffs = await planService.pendingPlanDiffsForDay(
        agentId: agentId,
        dayId: dayId,
      );
      for (final diff in diffs) {
        if (!diff.createdAt.isBefore(since)) return diff.id;
      }
      return null;
    },
    hasParsedItems: (captureId) async {
      final items = await captureService.parsedItemsForCapture(captureId);
      return items.isNotEmpty;
    },
  );
}
