import 'dart:async';
import 'dart:io';

import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart';
import 'package:lotti/features/daily_os_next/agents/workflow/day_agent_workflow_models.dart';
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

/// Shares an in-flight attempt for the same durable request across executors.
///
/// Kept above the rebuildable processing runtime. Claim holders still report
/// through the outbox's claim-token fence, but overlapping holders await one
/// preparation and wake rather than racing their artifact checks and enqueue.
class DayAgentJobExecutions {
  final _active = <(String, DateTime), Future<DayAgentJobOutcome>>{};

  Future<DayAgentJobOutcome> run(
    DayProcessingJob job,
    Future<DayAgentJobOutcome> Function() execute,
  ) {
    final key = (job.id, job.requestedAt.toUtc());
    return _active.putIfAbsent(
      key,
      () => Future<DayAgentJobOutcome>.microtask(execute).whenComplete(() {
        _active.remove(key);
      }),
    );
  }
}

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
    required this.hasCompletedCaptureParse,
    required this.hasPendingDraftWork,
    required this.liveWakeRunKey,
    DayAgentJobExecutions? executions,
    this.wakeTimeout = const Duration(minutes: 3),
    this.maxAttempts = 5,
  }) : _executions = executions ?? DayAgentJobExecutions();

  final DayAgentJobExecutions _executions;

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

  /// Reads the day's drafted plan provenance — when it was last written and
  /// which wake wrote it — or `null` when no plan exists yet.
  final Future<({DateTime updatedAt, String? runKey})?> Function(
    String agentId,
    String dayId,
  )
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

  /// Whether the given capture has a successful persisted parse, including an
  /// explicit empty result.
  final Future<bool> Function(String captureId) hasCompletedCaptureParse;

  /// Whether the day still has a draft job in the outbox that can produce a
  /// plan (queued, running, or waiting for network). Used by refine jobs
  /// with no plan to decide between a short defer (a draft is on the way)
  /// and failing fast (nothing will ever produce one — a `local` defer never
  /// counts an attempt, so deferring unconditionally would loop forever).
  final Future<bool> Function(String dayId) hasPendingDraftWork;

  /// The run key of a wake already enqueued for the job's request that has
  /// not settled — queued, running, or running on after an abort — or `null`.
  ///
  /// An attempt that finds one awaits it instead of enqueueing another. The
  /// claim's lease and the wait are both three minutes and the lease is never
  /// renewed, while a wake can sit behind its agent's single flight, or run
  /// on after the ten-minute cap, for far longer: a timed-out retry, a lapsed
  /// claim taken over, or a retry tap would otherwise bill a second inference
  /// for one request (`specs/tla/DayProcessingJob.tla`).
  final String? Function(DayProcessingJob job) liveWakeRunKey;

  /// Upper bound on how long one attempt waits for its wake to finish.
  final Duration wakeTimeout;

  /// Retryable failures stop retrying once a job has been attempted this
  /// many times — every retry spends model tokens, unlike transcription's
  /// free backoff.
  final int maxAttempts;

  Future<DayAgentJobOutcome> execute(DayProcessingJob job) =>
      _executions.run(job, () => _execute(job));

  Future<DayAgentJobOutcome> _execute(DayProcessingJob job) async {
    // Subscribe BEFORE looking for a live wake or enqueueing one (the
    // orchestrator's documented contract): a wake can complete while this
    // attempt reads the store or persists provenance, and a completion
    // emitted before `firstWhere` subscribes would be lost on the broadcast
    // stream. The plain controller buffers events until the waiter attaches.
    final buffered = StreamController<WakeRunCompletion>();
    final completionEvents = runCompletions.listen(
      buffered.add,
      onError: buffered.addError,
    );

    try {
      // Asked before the artifact pre-check: a wake no longer live has
      // settled, so whatever it committed is visible to the pre-check.
      final attached = liveWakeRunKey(job);
      final preCheck = await _artifactOutcome(job, extraRunKey: attached);
      if (preCheck != null) return preCheck;

      String? agentId;
      final String runKey;
      if (attached != null) {
        // This request's inference is already under way — the wake of an
        // attempt that timed out, or of a claim that lapsed. Await it rather
        // than paying for a second one beside it.
        runKey = attached;
      } else {
        final noPlan = await _refineWithoutPlan(job);
        if (noPlan != null) return noPlan;
        try {
          agentId = await resolveAgentId(job.dayId);
        } on Object catch (e) {
          // Routed through the same classifier as a wake failure rather than
          // a blanket `setupRequired`: a transient lookup/I/O failure here
          // should still get the outbox's retry behavior instead of being
          // treated as a terminal setup problem.
          return _classifyFailure(job, e);
        }
        // Asked again with nothing awaited between the answer and the
        // enqueue, which makes the pair atomic: a second attempt for the
        // request (a retry tap revoked this claim, or a lapsed claim was
        // taken over) may have enqueued its wake while this one awaited the
        // reads above, and must be awaited, not joined by a second wake.
        final enqueuedMeanwhile = liveWakeRunKey(job);
        if (enqueuedMeanwhile != null) {
          runKey = enqueuedMeanwhile;
        } else {
          runKey = enqueueWake((
            agentId: agentId,
            dayId: job.dayId,
            job: job,
          ));
          // Persist provenance before awaiting: if the process dies
          // mid-wake, the re-claim's artifact pre-check can still attribute
          // the wake's output.
          await recordRunKey(job.id, runKey);
        }
      }

      final WakeRunCompletion completion;
      try {
        completion = await buffered.stream
            .firstWhere((event) => event.runKey == runKey)
            .timeout(wakeTimeout);
      } on TimeoutException {
        if (liveWakeRunKey(job) != null) {
          // Still queued behind the agent's single flight, or running on
          // after an abort. Come back without counting an attempt: no new
          // inference was spent, and the next attempt attaches to it again.
          return const DayAgentJobFailed(
            failureClass: DayProcessingFailureClass.local,
            error: 'Wake still running',
          );
        }
        return _cappedRetryableFailure(
          job,
          DayProcessingFailureClass.timeout,
          'Wake did not complete in time',
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
      // Not awaited: nothing depends on the cancel settling, and awaiting it
      // costs a hop through the root zone's microtask queue.
      unawaited(completionEvents.cancel());
      unawaited(buffered.close());
    }
  }

  /// A refine job's answer when the day has no plan to refine, or `null`
  /// when there is one.
  Future<DayAgentJobOutcome?> _refineWithoutPlan(DayProcessingJob job) async {
    if (job.payload is! RefinePlanPayload) return null;
    final draft = await draftPlanUpdatedAt(
      await _safeResolve(job.dayId),
      job.dayId,
    );
    if (draft != null) return null;
    if (await hasPendingDraftWork(job.dayId)) {
      // No plan to refine yet, but a draft job for this day is still in
      // flight. Defer briefly rather than spending a wake on a refine that
      // has nothing to act on.
      return const DayAgentJobFailed(
        failureClass: DayProcessingFailureClass.local,
        error: 'No plan to refine yet',
        retryAfter: Duration(seconds: 5),
      );
    }
    // No plan exists and nothing will produce one: the day's draft job is
    // absent, terminally failed, or waiting on the user. Fail
    // deterministically instead of deferring forever.
    return const DayAgentJobFailed(
      failureClass: DayProcessingFailureClass.deterministic,
      error:
          'No plan to refine — the day has no drafted plan and no '
          'pending draft job',
    );
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
        if (await hasCompletedCaptureParse(captureId)) {
          return const DayAgentJobSucceeded();
        }
        return null;
      case DraftPlanPayload():
        final resolvedAgentId = agentId ?? await _safeResolve(job.dayId);
        final plan = await draftPlanUpdatedAt(resolvedAgentId, job.dayId);
        if (plan == null) return null;
        final knownRunKeys = {...job.runKeys, ?extraRunKey};
        final planRunKey = plan.runKey;
        if (knownRunKeys.isNotEmpty && planRunKey != null) {
          // Provenance-exact, same rule as refine: only a plan written by one
          // of THIS job's wakes satisfies it. Timestamps alone cannot tell
          // this job's plan from one a concurrent wake wrote in the same
          // window, which would mark the job succeeded and drop its intent.
          return knownRunKeys.contains(planRunKey)
              ? const DayAgentJobSucceeded()
              : null;
        }
        // No provenance on one side or the other: a plan written before the
        // field existed, or a job with no recorded wake. Fall back to the
        // window this check has always used. Removable once no pre-field
        // plans remain in circulation.
        return !plan.updatedAt.isBefore(job.requestedAt)
            ? const DayAgentJobSucceeded()
            : null;
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
  if (error is DayAgentOutputLimitExceededException) {
    return DayProcessingFailureClass.providerBusy;
  }
  final typeName = error.runtimeType.toString();
  if (typeName == 'MissingCaptureParseException' ||
      typeName == 'MissingDraftDayPlanException') {
    return DayProcessingFailureClass.providerBusy;
  }
  final lower = error.toString().toLowerCase();
  if (lower.contains(
    '$DayAgentOutputLimitExceededException'.toLowerCase(),
  )) {
    return DayProcessingFailureClass.providerBusy;
  }
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
