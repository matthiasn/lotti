import 'dart:async';
import 'dart:io';

import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_job.dart';

/// Outcome of one [DayAgentJobExecutor] attempt.
sealed class DayAgentJobOutcome {
  const DayAgentJobOutcome();
}

class DayAgentJobSucceeded extends DayAgentJobOutcome {
  const DayAgentJobSucceeded({this.resultEntityId});

  final String? resultEntityId;
}

class DayAgentJobFailed extends DayAgentJobOutcome {
  const DayAgentJobFailed({
    required this.failureClass,
    required this.error,
    this.retryAfter,
  });

  final DayProcessingFailureClass failureClass;
  final String error;
  final Duration? retryAfter;
}

/// Request to enqueue the wake that will execute the given job.
typedef DayAgentJobWakeRequest = ({
  String agentId,
  String dayId,
  DayProcessingJob job,
});

/// Runs the agent wake behind a durable `parseCapture`/`draftPlan`/
/// `refinePlan` job (ADR 0032 phase 1) and reports back a terminal outcome
/// the outbox processor can persist.
///
/// Every collaborator is injected as a function so this file stays decoupled
/// from the agents layer — the closures are supplied by the Riverpod wiring
/// in `day_processing_runtime_provider.dart`.
class DayAgentJobExecutor {
  DayAgentJobExecutor({
    required this.resolveAgentId,
    required this.enqueueWake,
    required this.runCompletions,
    required this.draftPlanUpdatedAt,
    required this.pendingDiffCreatedSince,
    required this.hasParsedItems,
    this.wakeTimeout = const Duration(minutes: 3),
    this.maxAttempts = 5,
  });

  /// Resolves (and, for draft/parse, lazily creates) the agent that should
  /// execute the given day's work. Called fresh on every attempt — never
  /// cached — so a job enqueued under one ownership model still resolves
  /// correctly if ownership changes before it executes (ADR 0032).
  final Future<String> Function(String dayId) resolveAgentId;

  /// Builds trigger tokens for the request's job and enqueues the wake via
  /// the orchestrator, returning its run key.
  final String Function(DayAgentJobWakeRequest request) enqueueWake;

  /// Wake completion event stream (`WakeOrchestrator.runCompletions`).
  final Stream<WakeRunCompletion> runCompletions;

  /// Reads the current `updatedAt` of the day's drafted plan, or `null` when
  /// none exists yet.
  final Future<DateTime?> Function(String agentId, String dayId)
  draftPlanUpdatedAt;

  /// Reads the id of a pending ChangeSet for the day created at or after the
  /// given instant, or `null` when none exists.
  final Future<String?> Function(String agentId, String dayId, DateTime since)
  pendingDiffCreatedSince;

  /// Whether the given capture already has parsed items.
  final Future<bool> Function(String captureId) hasParsedItems;

  /// Upper bound on how long one attempt waits for its wake to finish.
  final Duration wakeTimeout;

  /// Retryable failures stop retrying once a job has been attempted this
  /// many times — every retry spends model tokens, unlike transcription's
  /// free backoff.
  final int maxAttempts;

  Future<DayAgentJobOutcome> execute(DayProcessingJob job) async {
    final preCheck = await _artifactOutcome(job);
    if (preCheck != null) return preCheck;

    if (job.payload case RefinePlanPayload()) {
      final draftPending = await draftPlanUpdatedAt(
        await _safeResolve(job.dayId),
        job.dayId,
      );
      if (draftPending == null) {
        // No plan to refine yet — most likely a draft job for this day is
        // still in flight. Defer briefly rather than spending a wake on a
        // refine that has nothing to act on.
        return const DayAgentJobFailed(
          failureClass: DayProcessingFailureClass.local,
          error: 'No plan to refine yet',
          retryAfter: Duration(seconds: 5),
        );
      }
    }

    final String agentId;
    try {
      agentId = await resolveAgentId(job.dayId);
    } on Object catch (e) {
      return DayAgentJobFailed(
        failureClass: DayProcessingFailureClass.setupRequired,
        error: e.toString(),
      );
    }

    final runKey = enqueueWake((agentId: agentId, dayId: job.dayId, job: job));

    final WakeRunCompletion completion;
    try {
      completion = await runCompletions
          .firstWhere((event) => event.runKey == runKey)
          .timeout(wakeTimeout);
    } on TimeoutException {
      return const DayAgentJobFailed(
        failureClass: DayProcessingFailureClass.timeout,
        error: 'Wake did not complete in time',
      );
    }

    if (completion.status == WakeRunStatus.completed) {
      final settled = await _artifactOutcome(job, agentId: agentId);
      if (settled != null) return settled;
      // The wake reported success but the expected artifact is missing —
      // the workflow's forced-tool retry already exhausted itself producing
      // a Missing*Exception in this case, so this is unexpected; treat it
      // like any other transient miss and let the outbox retry.
      return const DayAgentJobFailed(
        failureClass: DayProcessingFailureClass.local,
        error: 'Wake completed without producing the expected artifact',
      );
    }

    return _classifyFailure(job, completion.error);
  }

  Future<String> _safeResolve(String dayId) async {
    try {
      return await resolveAgentId(dayId);
    } on Object {
      return dayId;
    }
  }

  /// Checks whether the job's artifact already satisfies its `requestedAt`
  /// baseline — the idempotency guard that makes re-claims after a crash,
  /// and the post-completion re-check, safe without re-running inference.
  Future<DayAgentJobOutcome?> _artifactOutcome(
    DayProcessingJob job, {
    String? agentId,
  }) async {
    switch (job.payload) {
      case ParseCapturePayload(:final captureId):
        if (await hasParsedItems(captureId)) {
          return const DayAgentJobSucceeded();
        }
        return null;
      case DraftPlanPayload():
        final resolvedAgentId = agentId ?? await _safeResolve(job.dayId);
        final updatedAt = await draftPlanUpdatedAt(resolvedAgentId, job.dayId);
        if (updatedAt != null && !updatedAt.isBefore(job.requestedAt)) {
          return const DayAgentJobSucceeded();
        }
        return null;
      case RefinePlanPayload():
        final resolvedAgentId = agentId ?? await _safeResolve(job.dayId);
        final diffId = await pendingDiffCreatedSince(
          resolvedAgentId,
          job.dayId,
          job.requestedAt,
        );
        if (diffId != null) {
          return DayAgentJobSucceeded(resultEntityId: diffId);
        }
        return null;
      case TranscribeAudioPayload():
        return null;
    }
  }

  DayAgentJobOutcome _classifyFailure(DayProcessingJob job, Object? error) {
    final failureClass = classifyDayAgentJobFailure(error);
    if (_isRetryable(failureClass) && job.attempts + 1 >= maxAttempts) {
      return DayAgentJobFailed(
        failureClass: DayProcessingFailureClass.deterministic,
        error: 'Gave up after ${job.attempts + 1} attempts: $error',
      );
    }
    return DayAgentJobFailed(
      failureClass: failureClass,
      error: error?.toString() ?? 'Wake failed',
    );
  }

  bool _isRetryable(DayProcessingFailureClass failureClass) =>
      failureClass != DayProcessingFailureClass.deterministic &&
      failureClass != DayProcessingFailureClass.setupRequired;
}

/// Classifies an agent-wake failure into a [DayProcessingFailureClass].
///
/// Distinct from `classifyDayProcessingFailure` (transcription-flavored):
/// the workflow's own forced-tool-retry exceptions map to `providerBusy` (the
/// model didn't call the required tool — worth one more attempt), not to a
/// deterministic dead end.
DayProcessingFailureClass classifyDayAgentJobFailure(Object? error) {
  if (error == null) return DayProcessingFailureClass.local;
  if (error is SocketException) return DayProcessingFailureClass.network;
  if (error is TimeoutException) return DayProcessingFailureClass.timeout;
  final typeName = error.runtimeType.toString();
  if (typeName == 'MissingCaptureParseException' ||
      typeName == 'MissingDraftDayPlanException') {
    return DayProcessingFailureClass.providerBusy;
  }
  final lower = error.toString().toLowerCase();
  if (lower.contains('ambiguous') || lower.contains('deleted')) {
    return DayProcessingFailureClass.deterministic;
  }
  if (lower.contains('no audio-capable model') ||
      lower.contains('provider not found') ||
      lower.contains('not configured') ||
      lower.contains('credential') ||
      lower.contains('template') ||
      lower.contains('profile')) {
    return DayProcessingFailureClass.setupRequired;
  }
  return DayProcessingFailureClass.timeout;
}
