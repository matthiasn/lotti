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
    required this.pendingDiffForRuns,
    required this.recordRunKey,
    required this.hasParsedItems,
    required this.hasPendingDraftWork,
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
  /// given instant, or `null` when none exists. Legacy fallback used only
  /// for jobs persisted before run-key provenance existed (`runKeys` empty).
  final Future<String?> Function(String agentId, String dayId, DateTime since)
  pendingDiffCreatedSince;

  /// Reads the id of a pending ChangeSet for the day whose `runKey` is in
  /// the given set, or `null` when none exists. This is the provenance-exact
  /// refine artifact check: a sibling refine's diff — created in the same
  /// time window but by a different wake — never matches.
  final Future<String?> Function(
    String agentId,
    String dayId,
    Set<String> runKeys,
  )
  pendingDiffForRuns;

  /// Persists the run key of a wake this executor just enqueued for the job,
  /// so a post-crash re-claim can still recognize the wake's artifact.
  final Future<void> Function(String jobId, String runKey) recordRunKey;

  /// Whether the given capture already has parsed items.
  final Future<bool> Function(String captureId) hasParsedItems;

  /// Whether the day still has a draft job in the outbox that can produce a
  /// plan (queued, running, or waiting for network). Used by refine jobs
  /// with no plan to decide between a short defer (a draft is on the way)
  /// and failing fast (nothing will ever produce one — a `local` defer never
  /// counts an attempt, so deferring unconditionally would loop forever).
  final Future<bool> Function(String dayId) hasPendingDraftWork;

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
        if (await hasPendingDraftWork(job.dayId)) {
          // No plan to refine yet, but a draft job for this day is still in
          // flight. Defer briefly rather than spending a wake on a refine
          // that has nothing to act on.
          return const DayAgentJobFailed(
            failureClass: DayProcessingFailureClass.local,
            error: 'No plan to refine yet',
            retryAfter: Duration(seconds: 5),
          );
        }
        // No plan exists and nothing will produce one: the day's draft job
        // is absent, terminally failed, or waiting on the user. Fail
        // deterministically instead of deferring forever.
        return const DayAgentJobFailed(
          failureClass: DayProcessingFailureClass.deterministic,
          error:
              'No plan to refine — the day has no drafted plan and no '
              'pending draft job',
        );
      }
    }

    final String agentId;
    try {
      agentId = await resolveAgentId(job.dayId);
    } on Object catch (e) {
      // Routed through the same classifier as a wake failure rather than a
      // blanket `setupRequired`: a transient lookup/I/O failure here should
      // still get the outbox's retry behavior instead of being treated as a
      // terminal setup problem.
      return _classifyFailure(job, e);
    }

    // Subscribe BEFORE enqueueing (the orchestrator's documented contract):
    // a fast wake can complete while provenance is being persisted below,
    // and a completion emitted before `firstWhere` subscribes would be lost
    // on the broadcast stream. The plain controller buffers events until
    // the waiter attaches.
    final buffered = StreamController<WakeRunCompletion>();
    final completionEvents = runCompletions.listen(
      buffered.add,
      onError: buffered.addError,
    );

    try {
      final runKey = enqueueWake((
        agentId: agentId,
        dayId: job.dayId,
        job: job,
      ));
      // Persist provenance before awaiting: if the process dies mid-wake,
      // the re-claim's artifact pre-check can still attribute the wake's
      // output.
      await recordRunKey(job.id, runKey);

      final WakeRunCompletion completion;
      try {
        completion = await buffered.stream
            .firstWhere((event) => event.runKey == runKey)
            .timeout(wakeTimeout);
      } on TimeoutException {
        return const DayAgentJobFailed(
          failureClass: DayProcessingFailureClass.timeout,
          error: 'Wake did not complete in time',
        );
      }

      if (completion.status == WakeRunStatus.completed) {
        final settled = await _artifactOutcome(
          job,
          agentId: agentId,
          extraRunKey: runKey,
        );
        if (settled != null) return settled;
        // The wake reported success but the expected artifact is missing —
        // the workflow's forced-tool retry should have surfaced this as a
        // Missing*Exception, so it is unexpected. A full inference was still
        // spent, so the failure must count as an attempt and respect
        // [maxAttempts]: `providerBusy` increments the attempt counter,
        // whereas `local` would retry forever without ever counting one.
        return _cappedRetryableFailure(
          job,
          DayProcessingFailureClass.providerBusy,
          'Wake completed without producing the expected artifact',
        );
      }

      return _classifyFailure(job, completion.error);
    } finally {
      await completionEvents.cancel();
      unawaited(buffered.close());
    }
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
    String? extraRunKey,
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
        final knownRunKeys = {...job.runKeys, ?extraRunKey};
        final String? diffId;
        if (knownRunKeys.isNotEmpty) {
          // Provenance-exact: only a diff written by one of THIS job's
          // wakes satisfies it. Matching by time window alone let a sibling
          // refine's diff mark this job succeeded and silently drop its
          // instruction.
          diffId = await pendingDiffForRuns(
            resolvedAgentId,
            job.dayId,
            knownRunKeys,
          );
        } else if (job.attempts > 0 || job.lastFailureClass != null) {
          // Legacy fallback: the job was attempted before run-key
          // provenance existed, so its wake's artifact is only findable by
          // time window.
          diffId = await pendingDiffCreatedSince(
            resolvedAgentId,
            job.dayId,
            job.requestedAt,
          );
        } else {
          // Never attempted: no wake has run for this intent, so no
          // artifact can belong to it.
          diffId = null;
        }
        if (diffId != null) {
          return DayAgentJobSucceeded(resultEntityId: diffId);
        }
        return null;
      case TranscribeAudioPayload():
        return null;
    }
  }

  DayAgentJobOutcome _classifyFailure(DayProcessingJob job, Object? error) =>
      _cappedRetryableFailure(
        job,
        classifyDayAgentJobFailure(error),
        error?.toString() ?? 'Wake failed',
      );

  /// Applies the [maxAttempts] cap to a retryable failure: once this attempt
  /// is counted the job will have been tried `attempts + 1` times, and
  /// further retries are cut off by downgrading to `deterministic`.
  DayAgentJobOutcome _cappedRetryableFailure(
    DayProcessingJob job,
    DayProcessingFailureClass failureClass,
    String error,
  ) {
    if (_isRetryable(failureClass) && job.attempts + 1 >= maxAttempts) {
      return DayAgentJobFailed(
        failureClass: DayProcessingFailureClass.deterministic,
        error: 'Gave up after ${job.attempts + 1} attempts: $error',
      );
    }
    return DayAgentJobFailed(failureClass: failureClass, error: error);
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
