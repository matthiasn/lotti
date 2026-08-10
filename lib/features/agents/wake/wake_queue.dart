import 'package:lotti/features/agents/model/agent_enums.dart';

/// A single pending wake request for an agent.
class WakeJob {
  WakeJob({
    required this.runKey,
    required this.agentId,
    required this.reason,
    required Set<String> triggerTokens,
    required this.createdAt,
    this.reasonId,
    this.workspaceKey,
    this.hasDirectMatch = true,
    this.drainImmediately = false,
    WakeInitiator? initiator,
  }) : initiator =
           initiator ??
           (reason == WakeReason.reanalysis.name
               ? WakeInitiator.user
               : WakeInitiator.automation),
       triggerTokens = Set<String>.of(triggerTokens);

  /// Deterministic key derived by `RunKeyFactory`; used for deduplication.
  final String runKey;

  /// The agent that should be woken.
  final String agentId;

  /// Optional workspace partition within the agent (ADR 0022).
  ///
  /// `null` for single-workspace agents (task, project, improver). The Daily
  /// OS planner owns many day workspaces under one identity and tags each job
  /// with `day:<dayId>` so that superseding, dedupe, and token-merge partition
  /// per day instead of per agent. `null` partitions only with `null`, so
  /// non-workspace agents are never affected by a planner job and vice versa.
  final String? workspaceKey;

  /// Wake trigger category: currently `'subscription'`, `'creation'`,
  /// or `'reanalysis'`.
  final String reason;

  /// User-requested wakes remain allowed while automatic updates are off.
  final WakeInitiator initiator;

  /// The DB-notification tokens that triggered this wake.
  ///
  /// This is a defensive copy of the set passed to the constructor.
  /// [WakeQueue.mergeTokens] may mutate it to coalesce rapid-fire
  /// notifications.
  final Set<String> triggerTokens;

  /// Optional identifier for the subscription that fired.
  final String? reasonId;

  /// Wall-clock time the job was created (not persisted; in-memory only).
  final DateTime createdAt;

  /// `true` when at least one trigger that contributed to this job should use
  /// the fast throttle path: either a direct edit (the agent's own entity
  /// changed) or a subscription that explicitly treats propagated child
  /// updates as fast enough for the normal coalescing window. `false` when
  /// every contributing trigger was a propagated fan-out that opted into the
  /// daily-digest deferral policy.
  ///
  /// Manual / creation / reanalysis wakes are direct by definition and
  /// keep the default `true`. Subscription wakes carry the orchestrator's
  /// classification, and [WakeQueue.mergeTokens] upgrades this to `true`
  /// when a later direct match coalesces into the same queued job — so a
  /// pending propagated-only job that picks up a fresh direct edit no
  /// longer fires at next 06:00 as if it were still propagated-only.
  bool hasDirectMatch;

  /// `true` when a match from an immediate-drain subscription
  /// (`AgentSubscription.drainImmediately`) contributed to this job. The
  /// throttle is per-agent, so an agent holding both a deferred and an
  /// immediate subscription needs the policy ON THE JOB: the drain engine
  /// dispatches an immediate job past the agent's deadline while a deferred
  /// job queued alongside it keeps waiting. [WakeQueue.mergeTokens] upgrades
  /// this monotonically, mirroring [hasDirectMatch].
  bool drainImmediately;
}

/// In-memory FIFO queue with run-key deduplication.
///
/// The [_seenRunKeys] set prevents the same logical wake from being enqueued
/// twice even when multiple notification batches arrive in quick succession.
/// Call [clearHistory] periodically (e.g., after each orchestrator cycle) to
/// prevent unbounded growth.
class WakeQueue {
  final _queue = <WakeJob>[];
  final _seenRunKeys = <String>{};

  /// Enqueue a wake job.
  ///
  /// Returns `false` and discards the job if its [WakeJob.runKey] has already
  /// been seen; returns `true` when the job was added.
  bool enqueue(WakeJob job) {
    if (_seenRunKeys.contains(job.runKey)) return false;
    _seenRunKeys.add(job.runKey);
    _queue.add(job);
    return true;
  }

  /// Remove and return the first queued job accepted by [predicate].
  ///
  /// Jobs skipped by [predicate] keep their relative FIFO order. The bounded
  /// wake dispatcher uses this to leave same-agent follow-ups visible in the
  /// queue while that agent is active, preserving post-run throttle decisions.
  WakeJob? dequeueFirstWhere(bool Function(WakeJob job) predicate) {
    final index = _queue.indexWhere(predicate);
    if (index < 0) return null;
    return _queue.removeAt(index);
  }

  /// Merge [tokens] into the `triggerTokens` of the first queued job that
  /// matches [agentId] **and** [workspaceKey].
  ///
  /// Partitioning by workspace is what keeps one planner's day-A and day-B
  /// jobs from coalescing once a single identity owns many days (ADR 0022).
  /// `workspaceKey` defaults to `null`, which matches only `null`-workspace
  /// jobs — so task/project agents merge exactly as before.
  ///
  /// When [isDirect] is `true`, also upgrades the job's
  /// [WakeJob.hasDirectMatch] to `true` — a direct match coalescing onto a
  /// previously daily-deferred job must not stay deferred to the next morning.
  /// The upgrade is monotonic: a subsequent digest-deferred merge cannot
  /// downgrade a fast-drain job back to propagated-only.
  ///
  /// Returns `true` when a matching job was found and updated, `false`
  /// otherwise.
  /// When [markImmediate] is `true`, also upgrades the job's
  /// [WakeJob.drainImmediately] — an immediate-drain match coalescing onto a
  /// deferred job must not wait out that job's window. Monotonic, like the
  /// [isDirect] upgrade.
  bool mergeTokens(
    String agentId,
    Set<String> tokens, {
    String? workspaceKey,
    bool isDirect = false,
    bool markImmediate = false,
  }) {
    for (final job in _queue) {
      if (job.agentId == agentId && job.workspaceKey == workspaceKey) {
        job.triggerTokens.addAll(tokens);
        if (isDirect) job.hasDirectMatch = true;
        if (markImmediate) job.drainImmediately = true;
        return true;
      }
    }
    return false;
  }

  /// Whether any queued job for [agentId] in [workspaceKey] carries at least
  /// one direct fast-throttle match. The orchestrator uses this when queued
  /// follow-up work remains after a wake: digest-deferred propagated-only
  /// queues wait until the next 06:00, while a fast-bearing queue keeps the
  /// 120 s drain so the user sees task edits reflected promptly.
  bool hasDirectQueuedJobFor(String agentId, {String? workspaceKey}) =>
      _queue.any(
        (job) =>
            job.agentId == agentId &&
            job.workspaceKey == workspaceKey &&
            job.hasDirectMatch,
      );

  /// Whether any queued job exists for [agentId] in [workspaceKey], regardless
  /// of provenance.
  bool hasQueuedJobFor(String agentId, {String? workspaceKey}) => _queue.any(
    (job) => job.agentId == agentId && job.workspaceKey == workspaceKey,
  );

  /// Whether a queued job for [agentId] in [workspaceKey] carries the
  /// immediate-drain policy — the post-run path dispatches these at once
  /// instead of arming a follow-up deadline.
  bool hasImmediateQueuedJobFor(String agentId, {String? workspaceKey}) =>
      _queue.any(
        (job) =>
            job.agentId == agentId &&
            job.workspaceKey == workspaceKey &&
            job.drainImmediately,
      );

  /// Whether a queued job for [agentId] in [workspaceKey] does NOT carry the
  /// immediate-drain policy — such a job still deserves its follow-up
  /// deadline even when an immediate job sits beside it in the queue.
  bool hasDeferredQueuedJobFor(String agentId, {String? workspaceKey}) =>
      _queue.any(
        (job) =>
            job.agentId == agentId &&
            job.workspaceKey == workspaceKey &&
            !job.drainImmediately,
      );

  /// Remove queued jobs for [agentId] and return them.
  ///
  /// By default removes only jobs matching [workspaceKey] (a manual wake
  /// supersedes pending work in its own workspace). Set [allWorkspaces] to
  /// drop every job for the agent regardless of workspace — used by an
  /// explicit cancel-all (e.g. `AgentService.cancelPendingWake`). For
  /// single-workspace agents the two are equivalent because all their jobs
  /// carry a `null` workspace.
  List<WakeJob> removeByAgent(
    String agentId, {
    String? workspaceKey,
    bool allWorkspaces = false,
  }) {
    final removed = <WakeJob>[];
    _queue.removeWhere((job) {
      if (job.agentId != agentId) return false;
      if (!allWorkspaces && job.workspaceKey != workspaceKey) return false;
      removed.add(job);
      return true;
    });
    return removed;
  }

  /// Remove and return jobs for [agentId] that satisfy [predicate].
  ///
  /// Used when automatic updates are disabled: subscription jobs are dropped
  /// while explicit manual wakes remain queued.
  List<WakeJob> removeByAgentWhere(
    String agentId,
    bool Function(WakeJob job) predicate,
  ) {
    final removed = <WakeJob>[];
    _queue.removeWhere((job) {
      if (job.agentId != agentId || !predicate(job)) return false;
      removed.add(job);
      return true;
    });
    return removed;
  }

  /// Re-enqueue a previously dequeued job without deduplication.
  ///
  /// Used by the orchestrator to put back jobs whose agent is currently busy.
  /// The run key remains in [_seenRunKeys] so that external duplicates are
  /// still rejected.
  void requeue(WakeJob job) => _queue.add(job);

  /// Whether the queue has no pending jobs.
  bool get isEmpty => _queue.isEmpty;

  /// Number of pending jobs.
  int get length => _queue.length;

  /// Clear the seen-run-keys history.
  ///
  /// Call periodically (e.g., after an orchestrator cycle completes) to prevent
  /// unbounded memory growth.  Note that clearing history allows previously
  /// seen run keys to be enqueued again; only call this when you are confident
  /// the corresponding runs have been committed to the DB.
  ///
  /// Must only be called when the queue is empty — clearing while jobs are
  /// pending would break deduplication for their run keys.
  void clearHistory() {
    assert(
      _queue.isEmpty,
      'clearHistory() called with ${_queue.length} pending jobs — '
      'this breaks run-key deduplication',
    );
    _seenRunKeys.clear();
  }
}
