import 'dart:async';
import 'dart:io';

import 'package:lotti/features/ai/repository/transcription_exception.dart';
import 'package:lotti/features/ai_chat/services/audio_transcription_service.dart'
    show AttributedTranscriptionException;
import 'package:lotti/features/daily_os_next/services/day_agent_job_executor.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_job.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_outbox_repository.dart';

enum DayProcessingRunResult { idle, succeeded, deferred, failed }

typedef DayAudioTranscribe = Future<String> Function(String audioPath);
typedef DayTranscriptAttach =
    Future<bool> Function(DayProcessingJob job, String transcript);

/// The three durable agent-wake job kinds (ADR 0032 phase 1), as distinct
/// from [DayProcessingJobKind.transcribeAudio]. Exposed so callers composing
/// a two-lane drain (agent jobs vs. transcription) don't have to repeat the
/// kind set.
const Set<DayProcessingJobKind> dayAgentJobKinds = {
  DayProcessingJobKind.parseCapture,
  DayProcessingJobKind.draftPlan,
  DayProcessingJobKind.refinePlan,
};

/// Claims and executes device-local Daily OS derived work.
class DayProcessingOutboxProcessor {
  DayProcessingOutboxProcessor({
    required this.repository,
    required this.transcribe,
    required this.attachTranscript,
    this.agentJobExecutor,
    this.onJobOutcome,
    this.priority,
    Future<bool> Function()? isOnline,
    double Function()? randomUnit,
  }) : _isOnline = isOnline ?? (() async => true),
       _randomUnit = randomUnit ?? (() => 0.5);

  final DayProcessingOutboxRepository repository;
  final DayAudioTranscribe transcribe;
  final DayTranscriptAttach attachTranscript;

  /// Executes `parseCapture`/`draftPlan`/`refinePlan` jobs (ADR 0032 phase
  /// 1). Left `null` in contexts (e.g. isolated transcription tests) that
  /// never claim an agent-kind job.
  final Future<DayAgentJobOutcome> Function(DayProcessingJob job)?
  agentJobExecutor;

  /// Fired for **every outcome** of a claimed attempt — succeeded, failed,
  /// re-queued for retry, or parked waiting for the network — carrying the job
  /// in the status that attempt produced.
  ///
  /// Deliberately not restricted to terminal statuses. `failed` is not
  /// terminal (a retry can resurrect it), so a terminal-only contract silently
  /// withheld exactly the outcome the plan-failure notification exists to
  /// report. Filtering is the listener's job: see `DayPlanReadyNotifier`,
  /// which reacts to succeeded/failed plan jobs and ignores the rest.
  final void Function(DayProcessingJob job)? onJobOutcome;

  /// Supplies the current day-ordering preference, re-evaluated per claim so
  /// navigating to another day takes effect on the very next job rather than
  /// after the drain finishes.
  final DayProcessingClaimPriority Function()? priority;

  final Future<bool> Function() _isOnline;
  final double Function() _randomUnit;

  /// Claims and executes the next due job, optionally restricted to [kinds]
  /// so a caller can drain one kind family independently of another (a slow
  /// agent wake must not block the transcription lane, or vice versa).
  Future<DayProcessingRunResult> processNext({
    Set<DayProcessingJobKind>? kinds,
  }) async {
    final claim = await repository.claimNext(
      kinds: kinds,
      priority: priority?.call(),
    );
    if (claim == null) return DayProcessingRunResult.idle;
    return switch (claim.job.kind) {
      DayProcessingJobKind.transcribeAudio => _processTranscription(claim),
      _ => _processAgentJob(claim),
    };
  }

  Future<DayProcessingRunResult> _processTranscription(
    DayProcessingClaim claim,
  ) async {
    var job = claim.job;
    try {
      final audioPath = job.audioPath;
      if (audioPath == null || !File(audioPath).existsSync()) {
        await repository.markFailure(
          jobId: job.id,
          claimToken: claim.token,
          failureClass: DayProcessingFailureClass.missingAsset,
          error: 'Saved audio is not available locally yet',
        );
        _onOutcome(job.copyWith(status: DayProcessingJobStatus.queued));
        return DayProcessingRunResult.deferred;
      }
      if (!await _isOnline()) {
        await repository.markFailure(
          jobId: job.id,
          claimToken: claim.token,
          failureClass: DayProcessingFailureClass.network,
          error: 'Offline',
        );
        _onOutcome(
          job.copyWith(status: DayProcessingJobStatus.waitingForNetwork),
        );
        return DayProcessingRunResult.deferred;
      }

      var transcript = job.resultTranscript;
      if (transcript == null || transcript.trim().isEmpty) {
        transcript = (await transcribe(audioPath)).trim();
        if (transcript.isEmpty) {
          throw const FormatException('Transcription returned no text');
        }
        job = await repository.markTranscriptReady(
          jobId: job.id,
          claimToken: claim.token,
          transcript: transcript,
        );
      }

      final attached = await attachTranscript(job, transcript);
      if (!attached) {
        await repository.markFailure(
          jobId: job.id,
          claimToken: claim.token,
          failureClass: DayProcessingFailureClass.local,
          error: 'Journal transcript commit was not accepted',
          retryDelay: const Duration(seconds: 1),
        );
        _onOutcome(job.copyWith(status: DayProcessingJobStatus.queued));
        return DayProcessingRunResult.deferred;
      }
      final succeeded = await repository.markSucceeded(
        jobId: job.id,
        claimToken: claim.token,
      );
      _onOutcome(succeeded);
      return DayProcessingRunResult.succeeded;
    } catch (error) {
      final failure = classifyDayProcessingFailure(error);
      try {
        final failed = await repository.markFailure(
          jobId: job.id,
          claimToken: claim.token,
          failureClass: failure.failureClass,
          error: error.toString(),
          retryAfter: failure.retryAfter,
          retryDelay: _retryDelay(job.attempts),
        );
        _onOutcome(failed);
      } on DayProcessingClaimRevokedException {
        // User-reviewed text satisfied the job, or the recording was deleted
        // and the job cancelled, while this attempt ran. The durable terminal
        // state wins over this attempt's outcome.
        return DayProcessingRunResult.deferred;
      }
      return failure.failureClass == DayProcessingFailureClass.deterministic ||
              failure.failureClass == DayProcessingFailureClass.setupRequired ||
              failure.failureClass == DayProcessingFailureClass.missingAsset
          ? DayProcessingRunResult.failed
          : DayProcessingRunResult.deferred;
    }
  }

  Future<DayProcessingRunResult> _processAgentJob(
    DayProcessingClaim claim,
  ) async {
    final job = claim.job;
    final executor = agentJobExecutor;
    if (executor == null) {
      await repository.markFailure(
        jobId: job.id,
        claimToken: claim.token,
        failureClass: DayProcessingFailureClass.local,
        error: 'No agent-job executor registered',
      );
      return DayProcessingRunResult.failed;
    }
    if (!await _isOnline()) {
      // Same cheap preflight as the transcription lane: without it, every
      // offline probe cycle ran a FULL wake attempt (state fold + prompt
      // assembly) per waiting job just to hit a SocketException.
      await repository.markFailure(
        jobId: job.id,
        claimToken: claim.token,
        failureClass: DayProcessingFailureClass.network,
        error: 'Offline',
      );
      _onOutcome(
        job.copyWith(status: DayProcessingJobStatus.waitingForNetwork),
      );
      return DayProcessingRunResult.deferred;
    }
    try {
      final outcome = await executor(job);
      switch (outcome) {
        case DayAgentJobSucceeded(:final resultEntityId):
          final succeeded = await repository.markSucceeded(
            jobId: job.id,
            claimToken: claim.token,
            resultEntityId: resultEntityId,
          );
          _onOutcome(succeeded);
          return DayProcessingRunResult.succeeded;
        case DayAgentJobFailed(
          :final failureClass,
          :final error,
          :final retryAfter,
        ):
          final failed = await repository.markFailure(
            jobId: job.id,
            claimToken: claim.token,
            failureClass: failureClass,
            error: error,
            retryAfter: retryAfter,
            retryDelay: _retryDelay(job.attempts),
          );
          _onOutcome(failed);
          return failureClass == DayProcessingFailureClass.deterministic ||
                  failureClass == DayProcessingFailureClass.setupRequired
              ? DayProcessingRunResult.failed
              : DayProcessingRunResult.deferred;
      }
    } on DayProcessingClaimRevokedException {
      return DayProcessingRunResult.deferred;
    } catch (error) {
      final failureClass = classifyDayAgentJobFailure(error);
      try {
        final failed = await repository.markFailure(
          jobId: job.id,
          claimToken: claim.token,
          failureClass: failureClass,
          error: error.toString(),
          retryDelay: _retryDelay(job.attempts),
        );
        _onOutcome(failed);
      } on DayProcessingClaimRevokedException {
        return DayProcessingRunResult.deferred;
      }
      return failureClass == DayProcessingFailureClass.deterministic ||
              failureClass == DayProcessingFailureClass.setupRequired
          ? DayProcessingRunResult.failed
          : DayProcessingRunResult.deferred;
    }
  }

  void _onOutcome(DayProcessingJob job) {
    // Every observed state, not only the terminal ones. `failed` is not
    // terminal — a retry can still resurrect it — so gating on `isTerminal`
    // meant the plan-failure notification added for lotti3-hkb.10 could never
    // fire, which is exactly the silence it was written to end. The listener
    // decides what is worth saying; this is only the delivery point.
    onJobOutcome?.call(job);
  }

  /// Drains due jobs of [kinds] (or every kind when omitted) up to
  /// [maxJobs].
  Future<int> drain({
    int maxJobs = 32,
    Set<DayProcessingJobKind>? kinds,
  }) async {
    var processed = 0;
    while (processed < maxJobs) {
      final result = await processNext(kinds: kinds);
      if (result == DayProcessingRunResult.idle) break;
      processed += 1;
    }
    return processed;
  }

  Duration _retryDelay(int attempts) {
    const baseMilliseconds = 5000;
    const capMilliseconds = 15 * 60 * 1000;
    final exponent = attempts.clamp(0, 20);
    final maximum = (baseMilliseconds * (1 << exponent)).clamp(
      baseMilliseconds,
      capMilliseconds,
    );
    final unit = _randomUnit().clamp(0.0, 1.0);
    return Duration(milliseconds: (maximum * unit).round());
  }
}

typedef DayProcessingFailure = ({
  DayProcessingFailureClass failureClass,
  Duration? retryAfter,
});

DayProcessingFailure classifyDayProcessingFailure(Object error) {
  // Attribution wraps the real provider failure; classify the cause.
  if (error is AttributedTranscriptionException) {
    return classifyDayProcessingFailure(error.cause);
  }
  if (error is SocketException) {
    return (
      failureClass: DayProcessingFailureClass.network,
      retryAfter: null,
    );
  }
  if (error is TimeoutException) {
    return (
      failureClass: DayProcessingFailureClass.timeout,
      retryAfter: null,
    );
  }
  if (error is FormatException) {
    return (
      failureClass: DayProcessingFailureClass.deterministic,
      retryAfter: null,
    );
  }
  if (error is TranscriptionException) {
    if (error.originalError case final SocketException _) {
      return (
        failureClass: DayProcessingFailureClass.network,
        retryAfter: null,
      );
    }
    final status = error.statusCode;
    if (status == 401 || status == 403) {
      return (
        failureClass: DayProcessingFailureClass.setupRequired,
        retryAfter: null,
      );
    }
    if (status == 429) {
      return (
        failureClass: DayProcessingFailureClass.providerBusy,
        retryAfter: null,
      );
    }
    if (status == 408 ||
        status == 409 ||
        status == 425 ||
        (status != null && status >= 500)) {
      return (
        failureClass: DayProcessingFailureClass.timeout,
        retryAfter: null,
      );
    }
    if (status != null && status >= 400) {
      return (
        failureClass: DayProcessingFailureClass.deterministic,
        retryAfter: null,
      );
    }
  }
  // Model/provider configuration gaps surface as plain exceptions from
  // model resolution, before any HTTP status exists — waiting for the
  // network cannot fix them, only Settings can.
  final lower = error.toString().toLowerCase();
  if (lower.contains('no audio-capable model') ||
      lower.contains('provider not found') ||
      lower.contains('not configured') ||
      lower.contains('credential')) {
    return (
      failureClass: DayProcessingFailureClass.setupRequired,
      retryAfter: null,
    );
  }
  return (
    failureClass: DayProcessingFailureClass.timeout,
    retryAfter: null,
  );
}
