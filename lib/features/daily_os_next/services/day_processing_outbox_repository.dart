import 'dart:async';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:lotti/features/daily_os_next/database/day_processing_db.dart';
import 'package:lotti/features/daily_os_next/database/day_processing_job_row.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_job.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

/// How long a terminal job stays in the Activity ledger (ADR 0044 decision 5).
///
/// Chosen to comfortably outlive Activity's practical scroll-back and to
/// survive a long offline gap. It is a number to revisit if Activity grows a
/// longer history surface, not a load-bearing constant: the partial index
/// already keeps the ledger off the drain path, so this bounds disk footprint
/// rather than query cost.
const Duration dayProcessingLedgerRetention = Duration(days: 90);

/// How long a job may wait behind higher-priority days before it outranks
/// them (ADR 0044 follow-up: head-of-line blocking).
///
/// Short enough that a backlog cannot park a job indefinitely, long enough
/// that ordinary interactive work still wins while the user is looking at it.
const Duration dayProcessingPriorityAging = Duration(minutes: 15);

/// Ordering hint for [DayProcessingOutboxRepository.claimNext].
///
/// Priority is *viewer-relative*, so it cannot be a stored column — the answer
/// changes as the user navigates. It is applied as a query-time expression
/// over the candidate set the pending partial index already bounds.
@immutable
class DayProcessingClaimPriority {
  const DayProcessingClaimPriority({
    required this.dayIds,
    required this.agingCutoff,
  });

  /// Day ids in descending priority — typically viewed day, today, tomorrow.
  final List<String> dayIds;

  /// Jobs enqueued at or before this instant outrank every day tier, so a
  /// day nobody is looking at cannot be starved by a busy foreground.
  final DateTime agingCutoff;
}

class DayProcessingClaim {
  const DayProcessingClaim({required this.job, required this.token});

  final DayProcessingJob job;
  final String token;
}

class DayProcessingIntentConflict implements Exception {
  const DayProcessingIntentConflict(this.jobId);

  final String jobId;

  @override
  String toString() =>
      'DayProcessingIntentConflict: immutable fields differ for $jobId';
}

/// Thrown when a claimed job was terminalized by another actor — reviewed
/// text satisfied it, or its recording was deleted and the job cancelled —
/// before the claim holder reported back. The durable terminal state wins.
class DayProcessingClaimRevokedException implements Exception {
  const DayProcessingClaimRevokedException(this.jobId);

  final String jobId;

  @override
  String toString() => 'Processing claim no longer owns $jobId';
}

/// Device-local processing outbox for Daily OS derived work (ADR 0044).
///
/// One row per job in [DayProcessingDb]. Jobs remain after success as the
/// local processing ledger consumed by Activity and startup repair; the
/// partial index over non-terminal rows keeps that ledger off the drain path,
/// so claim cost tracks outstanding work rather than install age.
///
/// Every read-modify-write runs in a transaction and every claimed mutation is
/// fenced by `claim_token`, which together replace the mutex and atomic-rename
/// machinery of the pre-0044 file store.
class DayProcessingOutboxRepository {
  DayProcessingOutboxRepository({
    required this.db,
    DateTime Function()? now,
    String Function()? tokenFactory,
  }) : _now = now ?? DateTime.now,
       _tokenFactory = tokenFactory ?? (() => const Uuid().v4());

  final DayProcessingDb db;
  final DateTime Function() _now;
  final String Function() _tokenFactory;
  final StreamController<void> _changes = StreamController<void>.broadcast();

  Stream<void> get changes => _changes.stream;

  /// Backstop cap for [recordRunKey].
  static const int maxRecordedRunKeys = 16;

  static const String _columns = dayProcessingJobColumns;

  /// Statuses a job can be claimed or scheduled from.
  static const String _drainableStatuses =
      "('queued', 'running', 'waitingForNetwork')";

  /// Repeats the pending partial index predicate verbatim so SQLite can prove
  /// that due/schedulable reads are covered by that index. The narrower
  /// drainable-status predicate is logically sufficient but SQLite does not
  /// infer that implication when selecting a partial index.
  static const String _nonTerminalClause =
      "status NOT IN ('succeeded', 'cancelled')";

  /// Due-job predicate, with `?1` bound to now.
  ///
  /// A `running` row is due only once its lease has expired (crash recovery);
  /// everything else is due at `next_attempt_at`. A hard provider boundary
  /// vetoes both.
  static const String _dueClause =
      '$_nonTerminalClause AND status IN $_drainableStatuses '
      'AND (retry_not_before IS NULL OR retry_not_before <= ?1) '
      "AND ((status = 'running' AND lease_until IS NOT NULL "
      'AND lease_until <= ?1) '
      "OR (status <> 'running' AND next_attempt_at <= ?1))";

  static String transcriptionJobId(String recordingSessionId) =>
      'transcribe_$recordingSessionId';

  /// Deterministic parse-job id: one durable parse intent per capture,
  /// mirroring the accumulate-per-capture wake semantics (`supersede: false`).
  static String parseJobId(String captureId) => 'parse_$captureId';

  /// Deterministic draft-job id: one durable draft intent per day. Repeated
  /// "draft my day" requests coalesce onto (or re-arm) this job.
  static String draftJobId(String dayId) => 'draft_$dayId';

  Future<DayProcessingJob> enqueueTranscription({
    required String dayId,
    required String activityEntryId,
    required String recordingSessionId,
    required String audioId,
    required String audioPath,
    required DateTime capturedAt,
  }) async {
    var published = false;
    final job = await db.transaction(() async {
      final now = _now();
      final requested = _newTranscriptionJob(
        dayId: dayId,
        activityEntryId: activityEntryId,
        recordingSessionId: recordingSessionId,
        audioId: audioId,
        audioPath: audioPath,
        capturedAt: capturedAt,
        now: now,
      );
      final existing = await _readJobOrNull(requested.id);
      if (existing != null) {
        _validateImmutableIntent(existing, requested);
        return existing;
      }
      await _write(requested);
      published = true;
      return requested;
    });
    if (published) _notify();
    return job;
  }

  /// Repairs the journal-created/outbox-not-yet-published crash boundary.
  Future<bool> restoreTranscriptionIntent({
    required String dayId,
    required String activityEntryId,
    required String recordingSessionId,
    required String audioId,
    required String audioPath,
    required DateTime capturedAt,
    String? completedTranscript,
  }) async {
    final restored = await db.transaction(() async {
      final now = _now();
      final transcript = completedTranscript?.trim();
      var requested = _newTranscriptionJob(
        dayId: dayId,
        activityEntryId: activityEntryId,
        recordingSessionId: recordingSessionId,
        audioId: audioId,
        audioPath: audioPath,
        capturedAt: capturedAt,
        now: now,
      );
      final existing = await _readJobOrNull(requested.id);
      if (existing != null) {
        _validateImmutableIntent(existing, requested);
        if (transcript == null ||
            transcript.isEmpty ||
            existing.status == DayProcessingJobStatus.succeeded) {
          return false;
        }
        requested = existing.copyWith(
          status: DayProcessingJobStatus.succeeded,
          updatedAt: now,
          generation: existing.generation + 1,
          resultTranscript: transcript,
          completedAt: now,
          clearClaimToken: true,
          clearLeaseUntil: true,
          clearLastError: true,
          clearLastFailureClass: true,
        );
      }
      if (existing == null && transcript != null && transcript.isNotEmpty) {
        requested = requested.copyWith(
          status: DayProcessingJobStatus.succeeded,
          updatedAt: now,
          generation: 1,
          resultTranscript: transcript,
          completedAt: now,
        );
      }
      await _write(requested);
      return true;
    });
    if (restored) _notify();
    return restored;
  }

  /// Atomically publishes and claims a new interactive transcription job,
  /// preventing the background runner from racing the capture screen.
  Future<DayProcessingClaim?> enqueueAndClaimTranscription({
    required String dayId,
    required String activityEntryId,
    required String recordingSessionId,
    required String audioId,
    required String audioPath,
    required DateTime capturedAt,
    Duration lease = const Duration(minutes: 3),
  }) async {
    final claim = await db.transaction(() async {
      final now = _now();
      final requested = _newTranscriptionJob(
        dayId: dayId,
        activityEntryId: activityEntryId,
        recordingSessionId: recordingSessionId,
        audioId: audioId,
        audioPath: audioPath,
        capturedAt: capturedAt,
        now: now,
      );
      final existing = await _readJobOrNull(requested.id);
      if (existing != null) _validateImmutableIntent(existing, requested);
      final job = existing ?? requested;
      if (existing == null) await _write(job);
      return _claim(now: now, lease: lease, jobId: job.id);
    });
    if (claim != null) _notify();
    return claim;
  }

  /// Enqueues (or coalesces onto) the day's durable draft-plan intent.
  ///
  /// One deterministic job per day: a fresh request re-arms a terminal or
  /// pending job with the newest selections in [payload] and a fresh
  /// `requestedAt` baseline; a currently `running` job is returned as-is so
  /// the caller attaches to the in-flight attempt instead of restarting it.
  Future<DayProcessingJob> enqueueDraftPlan({
    required String dayId,
    required DraftPlanPayload payload,
  }) async {
    var mutated = false;
    final job = await db.transaction(() async {
      final id = draftJobId(dayId);
      final now = _now();
      final existing = await _readJobOrNull(id);
      if (existing == null) {
        final job = DayProcessingJob(
          id: id,
          status: DayProcessingJobStatus.queued,
          dayId: dayId,
          payload: payload,
          createdAt: now,
          updatedAt: now,
          requestedAt: now,
          nextAttemptAt: now,
          attempts: 0,
          generation: 0,
        );
        await _write(job);
        mutated = true;
        return job;
      }
      if (existing.status == DayProcessingJobStatus.running) {
        final leaseUntil = existing.leaseUntil;
        if (leaseUntil != null && now.isBefore(leaseUntil)) {
          // The in-flight attempt keeps its payload; injecting newer
          // selections mid-wake is not possible, and the caller's await
          // attaches to this job's terminal state either way.
          return existing;
        }
        // `running` with an expired (or missing) lease is a zombie left by a
        // killed process — nothing is executing. Absorbing the new payload
        // into it would run the OLD selections at the eventual lease-expiry
        // re-claim, silently dropping what the user just decided. Fall
        // through to re-arm with the fresh payload instead.
      }
      final rearmed = _rearm(existing, payload: payload, now: now);
      await _write(rearmed);
      mutated = true;
      return rearmed;
    });
    if (mutated) _notify();
    return job;
  }

  /// Enqueues the durable parse intent for one submitted capture.
  ///
  /// Deterministic per capture: a queued or running job attaches (repeat
  /// submissions of the same capture id return the existing job). A job in
  /// any other state — stuck (`failed`, `waitingForUser`,
  /// `waitingForNetwork`) or terminal (`succeeded`, `cancelled`) — is
  /// re-armed with fresh attempts, which is what `retryCapture` relies on:
  /// the capture is the durable user intent, and asking again means "parse
  /// it (again)".
  Future<DayProcessingJob> enqueueParseCapture({
    required String dayId,
    required String captureId,
  }) async {
    var mutated = false;
    final job = await db.transaction(() async {
      final id = parseJobId(captureId);
      final now = _now();
      final requested = DayProcessingJob(
        id: id,
        status: DayProcessingJobStatus.queued,
        dayId: dayId,
        payload: ParseCapturePayload(captureId: captureId),
        createdAt: now,
        updatedAt: now,
        requestedAt: now,
        nextAttemptAt: now,
        attempts: 0,
        generation: 0,
      );
      final existing = await _readJobOrNull(id);
      if (existing == null) {
        await _write(requested);
        mutated = true;
        return requested;
      }
      _validateImmutableIntent(existing, requested);
      if (existing.status == DayProcessingJobStatus.queued ||
          existing.status == DayProcessingJobStatus.running) {
        return existing;
      }
      final rearmed = _rearm(existing, now: now);
      await _write(rearmed);
      mutated = true;
      return rearmed;
    });
    if (mutated) _notify();
    return job;
  }

  /// Enqueues a durable refine intent for the day.
  ///
  /// Never coalesced: each refine carries distinct user input (its own
  /// transcript capture) and produces its own ChangeSet, so every call
  /// creates a new uniquely-suffixed job.
  Future<DayProcessingJob> enqueueRefinePlan({
    required String dayId,
    String? transcriptCaptureId,
  }) async {
    final job = await db.transaction(() async {
      final now = _now();
      final raw = _tokenFactory().replaceAll('-', '');
      final suffix = raw.length > 8 ? raw.substring(0, 8) : raw;
      final job = DayProcessingJob(
        id: 'refine_${dayId}_$suffix',
        status: DayProcessingJobStatus.queued,
        dayId: dayId,
        payload: RefinePlanPayload(transcriptCaptureId: transcriptCaptureId),
        createdAt: now,
        updatedAt: now,
        requestedAt: now,
        nextAttemptAt: now,
        attempts: 0,
        generation: 0,
      );
      await _write(job);
      return job;
    });
    _notify();
    return job;
  }

  /// Re-arms a job onto fresh intent: new baseline, cleared retry/error state,
  /// and no inherited run keys (artifacts of the old intent's wakes must not
  /// satisfy the new one).
  DayProcessingJob _rearm(
    DayProcessingJob existing, {
    required DateTime now,
    DayProcessingPayload? payload,
  }) => existing.copyWith(
    status: DayProcessingJobStatus.queued,
    payload: payload,
    updatedAt: now,
    requestedAt: now,
    nextAttemptAt: now,
    attempts: 0,
    runKeys: const [],
    generation: existing.generation + 1,
    clearClaimToken: true,
    clearLeaseUntil: true,
    clearRetryNotBefore: true,
    clearLastError: true,
    clearLastFailureClass: true,
    clearResultEntityId: true,
    clearCompletedAt: true,
  );

  void _validateImmutableIntent(
    DayProcessingJob existing,
    DayProcessingJob requested,
  ) {
    if (existing.kind != requested.kind || existing.dayId != requested.dayId) {
      throw DayProcessingIntentConflict(existing.id);
    }
    switch (existing.payload) {
      case TranscribeAudioPayload():
        // Transcription intent is fully immutable, including its capture
        // time (createdAt = capturedAt, derived from durable provenance).
        if (existing.payload != requested.payload ||
            existing.createdAt != requested.createdAt) {
          throw DayProcessingIntentConflict(existing.id);
        }
      case ParseCapturePayload() || RefinePlanPayload():
        // ParseCapturePayload equality is fully determined by captureId,
        // which is itself embedded in the job id this method is always
        // looked up by — so for the one caller that reaches this arm
        // ([enqueueParseCapture]), existing/requested payloads can never
        // actually differ. RefinePlanPayload never reaches this arm at all
        // (enqueueRefinePlan never re-validates — see its doc comment).
        // Kept for exhaustiveness and as a guard if a future caller reuses
        // this validation with looser id semantics.
        if (existing.payload != requested.payload) {
          // coverage:ignore-start
          throw DayProcessingIntentConflict(existing.id);
          // coverage:ignore-end
        }
      // coverage:ignore-start
      case DraftPlanPayload():
        // No caller ever looks up an existing job by `draftJobId` before
        // calling this method (enqueueDraftPlan intentionally never
        // validates — see its doc comment), so this arm is unreachable.
        // Kept for exhaustiveness over the sealed DayProcessingPayload
        // union.
        break;
      // coverage:ignore-end
    }
  }

  DayProcessingJob _newTranscriptionJob({
    required String dayId,
    required String activityEntryId,
    required String recordingSessionId,
    required String audioId,
    required String audioPath,
    required DateTime capturedAt,
    required DateTime now,
  }) => DayProcessingJob(
    id: transcriptionJobId(recordingSessionId),
    status: DayProcessingJobStatus.queued,
    dayId: dayId,
    payload: TranscribeAudioPayload(
      activityEntryId: activityEntryId,
      recordingSessionId: recordingSessionId,
      audioId: audioId,
      audioPath: path.normalize(File(audioPath).absolute.path),
    ),
    createdAt: capturedAt,
    updatedAt: now,
    requestedAt: capturedAt,
    nextAttemptAt: now,
    attempts: 0,
    generation: 0,
  );

  Future<DayProcessingJob?> getById(String id) => _readJobOrNull(id);

  /// Every job recorded for [dayId], oldest first.
  ///
  /// Day-scoped so Activity's cost tracks one day rather than the whole
  /// ledger; served by `idx_day_processing_jobs_day`.
  Future<List<DayProcessingJob>> getForDay(
    String dayId, {
    Set<DayProcessingJobKind>? kinds,
  }) async {
    final variables = <Variable<Object>>[Variable<String>(dayId)];
    var sql = 'SELECT $_columns FROM day_processing_jobs WHERE day_id = ?1';
    if (kinds != null) {
      if (kinds.isEmpty) return const [];
      sql += ' AND ${_kindFilter(kinds, variables)}';
    }
    sql += ' ORDER BY created_at, id';
    return _readAll(sql, variables);
  }

  /// Non-terminal jobs of [kind], oldest first.
  ///
  /// Served by the pending partial index, so the review fence's sweep tracks
  /// outstanding work instead of every recording ever made.
  Future<List<DayProcessingJob>> getPendingByKind(
    DayProcessingJobKind kind,
  ) => _readAll(
    'SELECT $_columns FROM day_processing_jobs '
    "WHERE status NOT IN ('succeeded', 'cancelled') AND kind = ?1 "
    'ORDER BY created_at, id',
    [Variable<String>(kind.name)],
  );

  /// Jobs the runtime can still schedule a wake-up for, oldest first.
  ///
  /// Bounded by outstanding work rather than install age. The effective
  /// due-time ordering stays in the runtime (it depends on the runtime's own
  /// network-probe interval) so that rule has exactly one implementation.
  Future<List<DayProcessingJob>> getSchedulable() => _readAll(
    'SELECT $_columns FROM day_processing_jobs '
    'WHERE $_nonTerminalClause AND status IN $_drainableStatuses '
    'ORDER BY created_at, id',
    const [],
  );

  /// Claims the next due job, optionally restricted to [kinds] so callers
  /// can drain kind families independently (a slow agent wake must not block
  /// the transcription lane and vice versa).
  Future<DayProcessingClaim?> claimNext({
    Duration lease = const Duration(minutes: 3),
    Set<DayProcessingJobKind>? kinds,
    DayProcessingClaimPriority? priority,
  }) async {
    if (kinds != null && kinds.isEmpty) return null;
    final claim = await _claim(
      now: _now(),
      lease: lease,
      kinds: kinds,
      priority: priority,
    );
    if (claim != null) _notify();
    return claim;
  }

  /// Claims one known job for an interactive foreground attempt.
  Future<DayProcessingClaim?> claimById(
    String jobId, {
    Duration lease = const Duration(minutes: 3),
  }) async {
    final claim = await _claim(now: _now(), lease: lease, jobId: jobId);
    if (claim != null) _notify();
    return claim;
  }

  /// Selects and stamps a claim in one statement.
  ///
  /// The due predicate, the ordering and the claim write are a single
  /// `UPDATE … WHERE id = (SELECT …) RETURNING`, so there is no window in
  /// which a second claimer can take the row between choosing it and owning
  /// it — the question of what a "lost" claim should do never arises, rather
  /// than being answered with a retry loop. An empty result means nothing was
  /// due, which is the only reason a caller sees no claim.
  ///
  /// Returns the row as written, so the caller's job reflects exactly what is
  /// durable rather than a locally reconstructed copy.
  ///
  /// The token is minted before the statement runs and is therefore consumed
  /// even when nothing matches. Tokens are opaque and unbounded, so gaps carry
  /// no meaning.
  Future<DayProcessingClaim?> _claim({
    required DateTime now,
    required Duration lease,
    String? jobId,
    Set<DayProcessingJobKind>? kinds,
    DayProcessingClaimPriority? priority,
  }) async {
    final token = _tokenFactory();
    final variables = <Variable<Object>>[
      Variable<int>(_ms(now)),
      Variable<String>(token),
      Variable<int>(_ms(now.add(lease))),
    ];
    var selector = 'SELECT id FROM day_processing_jobs WHERE $_dueClause';
    if (jobId != null) {
      variables.add(Variable<String>(jobId));
      selector += ' AND id = ?${variables.length}';
    }
    if (kinds != null) selector += ' AND ${_kindFilter(kinds, variables)}';
    selector +=
        ' ORDER BY ${_priorityOrder(priority, variables)}created_at, id '
        'LIMIT 1';

    final rows = await db.customWriteReturning(
      'UPDATE day_processing_jobs SET '
      "status = 'running', updated_at = ?1, generation = generation + 1, "
      'claim_token = ?2, lease_until = ?3 '
      'WHERE id = ($selector) '
      'RETURNING $_columns',
      variables: variables,
    );
    if (rows.isEmpty) return null;
    return DayProcessingClaim(job: _fromRow(rows.single), token: token);
  }

  Future<DayProcessingJob> markSucceeded({
    required String jobId,
    required String claimToken,
    String? resultEntityId,
  }) => _updateClaimed(jobId, claimToken, (job, now) {
    return job.copyWith(
      status: DayProcessingJobStatus.succeeded,
      updatedAt: now,
      generation: job.generation + 1,
      completedAt: now,
      resultEntityId: resultEntityId,
      clearClaimToken: true,
      clearLeaseUntil: true,
    );
  });

  /// Persists provider output before attempting the journal side effect, so a
  /// local database failure can retry without repeating remote inference.
  Future<DayProcessingJob> markTranscriptReady({
    required String jobId,
    required String claimToken,
    required String transcript,
  }) => _updateClaimed(jobId, claimToken, (job, now) {
    final trimmed = transcript.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(transcript, 'transcript');
    }
    return job.copyWith(
      updatedAt: now,
      generation: job.generation + 1,
      attempts: job.attempts + 1,
      resultTranscript: trimmed,
    );
  });

  Future<DayProcessingJob> markFailure({
    required String jobId,
    required String claimToken,
    required DayProcessingFailureClass failureClass,
    required String error,
    Duration? retryAfter,
    Duration retryDelay = const Duration(seconds: 5),
  }) => _updateClaimed(jobId, claimToken, (job, now) {
    final requestAttempted =
        failureClass != DayProcessingFailureClass.network &&
        failureClass != DayProcessingFailureClass.missingAsset &&
        failureClass != DayProcessingFailureClass.local;
    final nextAttempts = job.attempts + (requestAttempted ? 1 : 0);
    final retryNotBefore = retryAfter == null ? null : now.add(retryAfter);
    final nextAttemptAt = retryNotBefore ?? now.add(retryDelay);
    final status = switch (failureClass) {
      DayProcessingFailureClass.network =>
        DayProcessingJobStatus.waitingForNetwork,
      DayProcessingFailureClass.setupRequired =>
        DayProcessingJobStatus.waitingForUser,
      DayProcessingFailureClass.missingAsset => DayProcessingJobStatus.queued,
      DayProcessingFailureClass.deterministic => DayProcessingJobStatus.failed,
      _ => DayProcessingJobStatus.queued,
    };
    return job.copyWith(
      status: status,
      updatedAt: now,
      nextAttemptAt: nextAttemptAt,
      attempts: nextAttempts,
      generation: job.generation + 1,
      retryNotBefore: retryNotBefore,
      clearRetryNotBefore: retryNotBefore == null,
      lastFailureClass: failureClass,
      lastError: error,
      clearClaimToken: true,
      clearLeaseUntil: true,
    );
  });

  /// Terminalizes a job the user no longer wants — e.g. its recording was
  /// deleted. A concurrently running worker's next claimed mutation fails
  /// its stale-claim check and is absorbed by the runtime's retry handling.
  Future<DayProcessingJob?> cancel(String jobId) =>
      _mutateUnclaimed(jobId, (job, now) {
        if (job.isTerminal) return null;
        return job.copyWith(
          status: DayProcessingJobStatus.cancelled,
          updatedAt: now,
          completedAt: now,
          generation: job.generation + 1,
          clearClaimToken: true,
          clearLeaseUntil: true,
        );
      });

  /// Records the run key of a wake enqueued for [jobId] (agent jobs).
  ///
  /// Deliberately claim-less: the stamp is provenance metadata, not intent —
  /// a stale writer appending its run key is harmless (the key belongs to a
  /// wake that really was enqueued for this job), so fencing would only add
  /// failure modes. Keys are capped to the newest [maxRecordedRunKeys] —
  /// far above `maxAttempts` — purely as a size backstop.
  Future<DayProcessingJob?> recordRunKey({
    required String jobId,
    required String runKey,
  }) => _mutateUnclaimed(jobId, (job, now) {
    if (job.isTerminal || job.runKeys.contains(runKey)) return null;
    final keys = [...job.runKeys, runKey];
    return job.copyWith(
      updatedAt: now,
      runKeys: keys.length > maxRecordedRunKeys
          ? keys.sublist(keys.length - maxRecordedRunKeys)
          : keys,
    );
  });

  Future<DayProcessingJob?> retryNow(String jobId) =>
      _mutateUnclaimed(jobId, (job, now) {
        if (job.isTerminal) return null;
        final hardBoundary = job.retryNotBefore;
        final due = hardBoundary != null && now.isBefore(hardBoundary)
            ? hardBoundary
            : now;
        return job.copyWith(
          status: DayProcessingJobStatus.queued,
          updatedAt: now,
          nextAttemptAt: due,
          generation: job.generation + 1,
          clearClaimToken: true,
          clearLeaseUntil: true,
          clearLastError: true,
          clearLastFailureClass: true,
        );
      });

  /// Marks transcription as satisfied by canonical user-reviewed text.
  /// Pending provider work is fenced and will not later overwrite the user's
  /// decision or spend inference tokens unnecessarily.
  Future<DayProcessingJob?> satisfyWithReviewedText(
    String jobId,
    String transcript,
  ) => _mutateUnclaimed(jobId, (job, now) {
    if (job.isTerminal) return null;
    final trimmed = transcript.trim();
    if (trimmed.isEmpty) return null;
    return job.copyWith(
      status: DayProcessingJobStatus.succeeded,
      updatedAt: now,
      generation: job.generation + 1,
      resultTranscript: trimmed,
      completedAt: now,
      clearClaimToken: true,
      clearLeaseUntil: true,
      clearRetryNotBefore: true,
      clearLastError: true,
      clearLastFailureClass: true,
    );
  });

  Future<void> signalConnectivityRestored() async {
    final now = _ms(_now());
    await db.customUpdate(
      'UPDATE day_processing_jobs SET '
      "status = 'queued', updated_at = ?1, next_attempt_at = ?1, "
      'generation = generation + 1 '
      "WHERE status = 'waitingForNetwork'",
      variables: [Variable<int>(now)],
    );
    _notify();
  }

  /// Deletes ledger rows completed before [cutoff] (ADR 0044 decision 5).
  ///
  /// Only terminal rows are eligible: a job parked in `failed`,
  /// `waitingForUser` or `waitingForNetwork` is outstanding user intent that
  /// [retryNow] and re-enqueue can still resurrect, so age alone must never
  /// remove it. Returns the number of rows pruned.
  Future<int> pruneTerminalBefore(DateTime cutoff) async {
    final pruned = await db.customUpdate(
      'DELETE FROM day_processing_jobs '
      "WHERE status IN ('succeeded', 'cancelled') "
      'AND completed_at IS NOT NULL AND completed_at < ?1',
      variables: [Variable<int>(_ms(cutoff))],
      updateKind: UpdateKind.delete,
    );
    if (pruned > 0) _notify();
    return pruned;
  }

  /// Read-modify-write for the claim-less mutators.
  ///
  /// [update] returns null when the job should be left untouched, which keeps
  /// each caller's no-op guards (terminal, duplicate run key, blank text)
  /// beside the mutation they guard.
  Future<DayProcessingJob?> _mutateUnclaimed(
    String jobId,
    DayProcessingJob? Function(DayProcessingJob job, DateTime now) update,
  ) async {
    var mutated = false;
    final job = await db.transaction(() async {
      final job = await _readJobOrNull(jobId);
      if (job == null) return null;
      final updated = update(job, _now());
      if (updated == null) return job;
      await _write(updated);
      mutated = true;
      return updated;
    });
    if (mutated) _notify();
    return job;
  }

  Future<DayProcessingJob> _updateClaimed(
    String jobId,
    String claimToken,
    DayProcessingJob Function(DayProcessingJob job, DateTime now) update,
  ) async {
    final updated = await db.transaction(() async {
      final job = await _readJobOrNull(jobId);
      if (job == null) throw StateError('Unknown processing job $jobId');
      if (job.status != DayProcessingJobStatus.running ||
          job.claimToken != claimToken) {
        throw DayProcessingClaimRevokedException(jobId);
      }
      final updated = update(job, _now());
      await _write(updated);
      return updated;
    });
    _notify();
    return updated;
  }

  Future<DayProcessingJob?> _readJobOrNull(String id) async {
    final rows = await db
        .customSelect(
          'SELECT $_columns FROM day_processing_jobs WHERE id = ?1',
          variables: [Variable<String>(id)],
        )
        .get();
    return rows.isEmpty ? null : _fromRow(rows.single);
  }

  Future<List<DayProcessingJob>> _readAll(
    String sql,
    List<Variable<Object>> variables,
  ) async {
    final rows = await db.customSelect(sql, variables: variables).get();
    return List<DayProcessingJob>.unmodifiable(rows.map(_fromRow));
  }

  /// Leading `ORDER BY` term that puts the days the user cares about first,
  /// or an empty string for plain FIFO.
  ///
  /// Tiers, in order: anything that has already waited past the aging cutoff,
  /// then each day in [DayProcessingClaimPriority.dayIds], then everything
  /// else. Ties fall through to the caller's `created_at, id`, so ordering
  /// *within* a day — a capture's parse before that day's draft — is
  /// unchanged.
  static String _priorityOrder(
    DayProcessingClaimPriority? priority,
    List<Variable<Object>> variables,
  ) {
    if (priority == null || priority.dayIds.isEmpty) return '';
    variables.add(
      Variable<int>(priority.agingCutoff.millisecondsSinceEpoch),
    );
    final buffer = StringBuffer('CASE WHEN created_at <= ?')
      ..write(variables.length)
      ..write(' THEN 0');
    var tier = 0;
    for (final dayId in priority.dayIds) {
      variables.add(Variable<String>(dayId));
      buffer
        ..write(' WHEN day_id = ?')
        ..write(variables.length)
        ..write(' THEN ')
        ..write(++tier);
    }
    buffer
      ..write(' ELSE ')
      ..write(tier + 1)
      ..write(' END, ');
    return buffer.toString();
  }

  /// Appends `kind IN (…)` to a query, extending [variables] in place so the
  /// placeholder numbering stays aligned with the caller's existing bindings.
  static String _kindFilter(
    Set<DayProcessingJobKind> kinds,
    List<Variable<Object>> variables,
  ) {
    final placeholders = <String>[];
    for (final kind in kinds) {
      variables.add(Variable<String>(kind.name));
      placeholders.add('?${variables.length}');
    }
    return 'kind IN (${placeholders.join(', ')})';
  }

  Future<void> _write(DayProcessingJob job) async {
    const assignments =
        'status = excluded.status, kind = excluded.kind, '
        'day_id = excluded.day_id, payload = excluded.payload, '
        'run_keys = excluded.run_keys, created_at = excluded.created_at, '
        'updated_at = excluded.updated_at, '
        'requested_at = excluded.requested_at, '
        'next_attempt_at = excluded.next_attempt_at, '
        'attempts = excluded.attempts, generation = excluded.generation, '
        'claim_token = excluded.claim_token, '
        'lease_until = excluded.lease_until, '
        'retry_not_before = excluded.retry_not_before, '
        'last_failure_class = excluded.last_failure_class, '
        'last_error = excluded.last_error, '
        'result_transcript = excluded.result_transcript, '
        'result_entity_id = excluded.result_entity_id, '
        'completed_at = excluded.completed_at';
    await db.customInsert(
      'INSERT INTO day_processing_jobs ($_columns) VALUES '
      '($dayProcessingJobPlaceholders) '
      'ON CONFLICT(id) DO UPDATE SET $assignments',
      variables: dayProcessingJobVariables(job),
    );
  }

  static DayProcessingJob _fromRow(QueryRow row) =>
      dayProcessingJobFromRow(row);

  static int _ms(DateTime value) => value.millisecondsSinceEpoch;

  void _notify() {
    if (!_changes.isClosed) _changes.add(null);
  }

  Future<void> dispose() => _changes.close();
}
