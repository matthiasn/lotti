import 'dart:async';
import 'dart:developer' as developer;

import 'package:clock/clock.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/wake/run_key_factory.dart';
import 'package:lotti/features/agents/wake/wake_queue.dart';
import 'package:lotti/features/agents/wake/wake_runner.dart';
import 'package:lotti/features/sync/vector_clock.dart';

/// A registered interest that wakes [agentId] when tokens arrive matching
/// [matchEntityIds].
class AgentSubscription {
  AgentSubscription({
    required this.id,
    required this.agentId,
    required this.matchEntityIds,
    this.predicate,
  });

  /// Unique subscription identifier (stable across restarts).
  final String id;

  /// The agent that owns this subscription.
  final String agentId;

  /// Set of entity IDs (or notification token strings) that trigger a wake.
  final Set<String> matchEntityIds;

  /// Optional fine-grained filter applied after the initial token match.
  /// Receives the full batch of matched tokens; return `true` to proceed.
  final bool Function(Set<String> tokens)? predicate;
}

/// Notification-driven wake orchestrator.
///
/// Responsibilities:
/// - Listens to the `UpdateNotifications` stream (a `Stream<Set<String>>`).
/// - Matches incoming notification batches against registered
///   [AgentSubscription]s.
/// - Suppresses self-notifications (writes made by the agent itself) using
///   token-presence tracking via `recordMutatedEntities`. When all matched
///   tokens correspond to entities that the agent itself mutated in its last
///   wake cycle, the notification is suppressed.
/// - Enqueues [WakeJob]s into [WakeQueue] with deterministic run keys.
/// - Dispatches queued jobs through [WakeRunner] (single-flight per agent).
/// - Persists every wake attempt to the [AgentRepository] wake-run log.
/// Signature for the callback that executes a wake cycle.
///
/// [agentId] is the target agent's ID.
/// [runKey] is the deterministic run key.
/// [triggers] is the set of entity IDs that triggered the wake.
/// [threadId] scopes the conversation for this wake.
///
/// Returns a map of mutated entity IDs → vector clocks for self-notification
/// suppression. An empty map or `null` indicates no mutations occurred.
typedef WakeExecutor = Future<Map<String, VectorClock>?> Function(
  String agentId,
  String runKey,
  Set<String> triggers,
  String threadId,
);

class WakeOrchestrator {
  WakeOrchestrator({
    required this.repository,
    required this.queue,
    required this.runner,
    this.wakeExecutor,
  });

  final AgentRepository repository;
  final WakeQueue queue;
  final WakeRunner runner;

  /// Optional callback that performs the actual agent execution during
  /// [processNext]. When set, the orchestrator delegates to this function
  /// after acquiring the run lock and persisting the wake-run entry.
  WakeExecutor? wakeExecutor;

  final _subscriptions = <AgentSubscription>[];

  /// Monotonic wake counter per agent.
  ///
  /// Incremented each time a subscription-driven wake is enqueued, ensuring
  /// that identical token sets produce distinct run keys even when the same
  /// notification arrives twice while the agent is busy.  The counter is
  /// kept in-memory (reset on app restart) since persistence is not required
  /// — the counter only needs to be unique within a single orchestrator
  /// lifecycle.
  final _wakeCounters = <String, int>{};

  /// Self-notification suppression state.
  ///
  /// Maps agentId → [_MutationRecord] (entity IDs + timestamp). When a
  /// notification batch arrives, tokens that match entities the agent itself
  /// mutated are suppressed — but only if the mutation record is recent
  /// (within [_suppressionTtl]). Stale records are ignored so that external
  /// edits to the same entity are not incorrectly suppressed.
  final _recentlyMutatedEntries = <String, _MutationRecord>{};

  /// Duration after which self-mutation records expire and no longer suppress
  /// notifications. Must be long enough to cover the `UpdateNotifications`
  /// debounce window (100ms local, 1s sync) plus scheduling jitter.
  static const _suppressionTtl = Duration(seconds: 5);

  StreamSubscription<Set<String>>? _notificationSub;

  // ── Subscription management ────────────────────────────────────────────────

  /// Register a subscription so that the agent is woken when matching tokens
  /// arrive.
  void addSubscription(AgentSubscription sub) => _subscriptions.add(sub);

  /// Remove all subscriptions for [agentId] and clean up internal state.
  void removeSubscriptions(String agentId) {
    _subscriptions.removeWhere((s) => s.agentId == agentId);
    _recentlyMutatedEntries.remove(agentId);
    _wakeCounters.remove(agentId);
  }

  // ── Self-notification suppression ──────────────────────────────────────────

  /// Record which entities were mutated by [agentId] during a tool call.
  ///
  /// [entries] maps entityId → VectorClock that was written.  On the next
  /// notification batch these entries will be compared against the incoming
  /// tokens; if the record is still within [_suppressionTtl] the notification
  /// is suppressed so the agent does not wake on its own writes.
  void recordMutatedEntities(
    String agentId,
    Map<String, VectorClock> entries,
  ) {
    _recentlyMutatedEntries[agentId] = _MutationRecord(
      entityIds: entries.keys.toSet(),
      recordedAt: clock.now(),
    );
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  /// Start listening to [notificationStream].
  ///
  /// Each batch is a `Set<String>` of affected entity IDs / notification
  /// tokens as emitted by `UpdateNotifications.updateStream`.
  void start(Stream<Set<String>> notificationStream) {
    _notificationSub?.cancel();
    _notificationSub = notificationStream.listen(_onBatch);
  }

  /// Stop listening and cancel the subscription.
  Future<void> stop() async {
    await _notificationSub?.cancel();
    _notificationSub = null;
  }

  /// Rebuild in-memory subscriptions from persisted agent state on app startup.
  ///
  /// Fetches all active (non-destroyed) agents from the repository and
  /// restores their subscriptions.  The actual subscription definitions are
  /// agent-kind–specific and will be populated by each agent's own
  /// initialisation logic; this hook exists so the orchestrator can be primed
  /// before the first notification batch arrives.
  ///
  /// Concrete agent services should call [addSubscription] during their own
  /// startup after this method returns.
  Future<void> reconstructSubscriptions() async {
    // The workflow layer is responsible for registering subscriptions per
    // agent kind.  This method is a no-op at the infrastructure level and is
    // provided as an extension point called by the owning service on startup.
  }

  // ── Manual wake enqueue ──────────────────────────────────────────────────

  /// Enqueue a user- or system-initiated wake for [agentId].
  ///
  /// Unlike notification-driven wakes, this bypasses subscription matching and
  /// self-notification suppression.  Used for initial creation wakes and
  /// manual re-analysis triggers.
  void enqueueManualWake({
    required String agentId,
    required String reason,
    Set<String> triggerTokens = const {},
  }) {
    final runKey = RunKeyFactory.forManual(
      agentId: agentId,
      reason: reason,
      timestamp: clock.now(),
    );

    final job = WakeJob(
      runKey: runKey,
      agentId: agentId,
      reason: reason,
      triggerTokens: triggerTokens,
      createdAt: clock.now(),
    );

    queue.enqueue(job);
    unawaited(processNext());
  }

  // ── Internal notification handling ─────────────────────────────────────────

  void _onBatch(Set<String> tokens) {
    for (final sub in _subscriptions) {
      // 1. Check whether any token matches the subscription's entity IDs.
      final matched = tokens.intersection(sub.matchEntityIds);
      if (matched.isEmpty) continue;

      // 2. Apply self-notification suppression.
      final suppressed = _isSuppressed(sub.agentId, matched);
      if (suppressed) continue;

      // 3. Apply optional fine-grained predicate.
      final predicate = sub.predicate;
      if (predicate != null && !predicate(matched)) continue;

      // 4. Derive a deterministic run key and enqueue.
      final counter = _wakeCounters[sub.agentId] ?? 0;
      _wakeCounters[sub.agentId] = counter + 1;

      final runKey = RunKeyFactory.forSubscription(
        agentId: sub.agentId,
        subscriptionId: sub.id,
        batchTokens: matched,
        wakeCounter: counter,
      );

      final job = WakeJob(
        runKey: runKey,
        agentId: sub.agentId,
        reason: 'subscription',
        triggerTokens: Set<String>.from(matched),
        reasonId: sub.id,
        createdAt: clock.now(),
      );

      // Attempt to merge tokens into an existing queued job for this agent
      // before enqueuing a new one; this coalesces rapid-fire notifications.
      if (!queue.mergeTokens(sub.agentId, matched)) {
        queue.enqueue(job);
      }
    }

    // Dispatch queued jobs after processing the batch.
    unawaited(processNext());
  }

  /// Returns `true` when all [matchedTokens] are covered by the agent's
  /// recently mutated entries (i.e., the agent wrote those entities itself)
  /// and the mutation record has not expired.
  bool _isSuppressed(String agentId, Set<String> matchedTokens) {
    final record = _recentlyMutatedEntries[agentId];
    if (record == null || record.entityIds.isEmpty) return false;

    // Expire stale records so external edits are not incorrectly suppressed.
    final elapsed = clock.now().difference(record.recordedAt);
    if (elapsed > _suppressionTtl) {
      _recentlyMutatedEntries.remove(agentId);
      return false;
    }

    // Suppress only when every matched token corresponds to an entity that the
    // agent itself mutated.  A single external token is enough to allow the
    // wake through.
    return matchedTokens.every(record.entityIds.contains);
  }

  // ── Dispatch ───────────────────────────────────────────────────────────────

  /// Dequeue and execute pending wake jobs.
  ///
  /// Loops through the queue processing jobs until it is empty or all
  /// remaining jobs belong to agents that are currently running (busy).
  /// Busy agents' jobs are re-enqueued for the next cycle.
  ///
  /// The wake run is persisted to [AgentRepository] with status `'running'`
  /// before execution. When a [wakeExecutor] is set, it is called to perform
  /// the actual agent work; the final status is updated to `'completed'` or
  /// `'failed'` accordingly.
  ///
  /// When the queue becomes empty after processing, the seen-run-key history
  /// is cleared so that future notification batches can create new run keys.
  Future<void> processNext() async {
    final deferred = <WakeJob>[];

    try {
      while (true) {
        final job = queue.dequeue();
        if (job == null) break;

        final acquired = await runner.tryAcquire(job.agentId);
        if (!acquired) {
          // Agent is already running; defer for re-enqueue after loop.
          deferred.add(job);
          continue;
        }

        await _executeJob(job);
      }
    } finally {
      // Re-enqueue deferred jobs (busy agents) without dedup checks.
      deferred.forEach(queue.requeue);

      // Clear run-key history only when the queue is fully drained (no
      // deferred jobs left). This prevents stale keys from blocking future
      // wakes while avoiding premature clearing that could allow duplicates.
      if (queue.isEmpty) {
        queue.clearHistory();
      }
    }
  }

  /// Execute a single wake job: persist → run executor → update status.
  Future<void> _executeJob(WakeJob job) async {
    final threadId = job.runKey;

    try {
      final entry = WakeRunLogData(
        runKey: job.runKey,
        agentId: job.agentId,
        reason: job.reason,
        reasonId: job.reasonId,
        threadId: threadId,
        status: 'running',
        createdAt: job.createdAt,
        startedAt: clock.now(),
      );

      await repository.insertWakeRun(entry: entry);

      final executor = wakeExecutor;
      if (executor == null) {
        developer.log(
          'No wakeExecutor set — marking run ${job.runKey} as failed',
          name: 'WakeOrchestrator',
        );
        await repository.updateWakeRunStatus(
          job.runKey,
          'failed',
          errorMessage: 'No wake executor registered',
        );
        return;
      }

      try {
        final mutated = await executor(
          job.agentId,
          job.runKey,
          job.triggerTokens,
          threadId,
        );

        // Record mutated entries for self-notification suppression,
        // replacing the previous cycle's entries for this agent.
        if (mutated != null && mutated.isNotEmpty) {
          recordMutatedEntities(job.agentId, mutated);
        } else {
          // No mutations this cycle — clear stale suppression data so
          // external edits to previously-mutated entities are not blocked.
          _recentlyMutatedEntries.remove(job.agentId);
        }

        await repository.updateWakeRunStatus(
          job.runKey,
          'completed',
          completedAt: clock.now(),
        );
      } catch (e) {
        await repository.updateWakeRunStatus(
          job.runKey,
          'failed',
          errorMessage: e.toString(),
        );
      }
    } finally {
      runner.release(job.agentId);
    }
  }
}

/// Internal record of which entities an agent mutated and when.
class _MutationRecord {
  _MutationRecord({required this.entityIds, required this.recordedAt});

  final Set<String> entityIds;
  final DateTime recordedAt;
}
