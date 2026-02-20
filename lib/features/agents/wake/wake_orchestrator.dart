import 'dart:async';

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
///   vector-clock tracking via [recordMutatedEntities].
/// - Enqueues [WakeJob]s into [WakeQueue] with deterministic run keys.
/// - Dispatches queued jobs through [WakeRunner] (single-flight per agent).
/// - Persists every wake attempt to the [AgentRepository] wake-run log.
class WakeOrchestrator {
  WakeOrchestrator({
    required this.repository,
    required this.queue,
    required this.runner,
  });

  final AgentRepository repository;
  final WakeQueue queue;
  final WakeRunner runner;

  final _subscriptions = <AgentSubscription>[];

  /// Self-notification suppression state.
  ///
  /// Maps agentId → (entityId → VectorClock that was current after the
  /// agent's last mutation).  When a notification batch arrives, any token
  /// that maps to an entity whose stored clock still dominates the incoming
  /// batch is suppressed.
  final _recentlyMutatedEntries = <String, Map<String, VectorClock>>{};

  StreamSubscription<Set<String>>? _notificationSub;

  // ── Subscription management ────────────────────────────────────────────────

  /// Register a subscription so that the agent is woken when matching tokens
  /// arrive.
  void addSubscription(AgentSubscription sub) => _subscriptions.add(sub);

  /// Remove all subscriptions for [agentId].
  void removeSubscriptions(String agentId) {
    _subscriptions.removeWhere((s) => s.agentId == agentId);
  }

  // ── Self-notification suppression ──────────────────────────────────────────

  /// Record which entities were mutated by [agentId] during a tool call.
  ///
  /// [entries] maps entityId → VectorClock that was written.  On the next
  /// notification batch these entries will be compared against the incoming
  /// tokens; if the agent's clock still dominates the notification is
  /// suppressed so the agent does not wake on its own writes.
  void recordMutatedEntities(
    String agentId,
    Map<String, VectorClock> entries,
  ) {
    _recentlyMutatedEntries[agentId] = entries;
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  /// Start listening to [notificationStream].
  ///
  /// Each batch is a `Set<String>` of affected entity IDs / notification
  /// tokens as emitted by `UpdateNotifications.updateStream`.
  void start(Stream<Set<String>> notificationStream) {
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
      //    The wakeCounter is fetched asynchronously; for MVP we use 0 as a
      //    placeholder — the workflow layer will inject the real counter when
      //    it builds the final run key before persisting.
      final runKey = RunKeyFactory.forSubscription(
        agentId: sub.agentId,
        subscriptionId: sub.id,
        batchTokens: matched,
        wakeCounter: 0,
      );

      final job = WakeJob(
        runKey: runKey,
        agentId: sub.agentId,
        reason: 'subscription',
        triggerTokens: Set<String>.from(matched),
        reasonId: sub.id,
        createdAt: DateTime.now(),
      );

      // Attempt to merge tokens into an existing queued job for this agent
      // before enqueuing a new one; this coalesces rapid-fire notifications.
      if (!queue.mergeTokens(sub.agentId, matched)) {
        queue.enqueue(job);
      }
    }
  }

  /// Returns `true` when all [matchedTokens] are covered by the agent's
  /// recently mutated entries (i.e., the agent wrote those entities itself).
  bool _isSuppressed(String agentId, Set<String> matchedTokens) {
    final mutated = _recentlyMutatedEntries[agentId];
    if (mutated == null || mutated.isEmpty) return false;
    // Suppress only when every matched token corresponds to an entity that the
    // agent itself mutated.  A single external token is enough to allow the
    // wake through.
    return matchedTokens.every(mutated.containsKey);
  }

  // ── Dispatch ───────────────────────────────────────────────────────────────

  /// Dequeue and execute the next pending wake job.
  ///
  /// If the target agent is already running the job is re-enqueued (it will
  /// be processed in the next [processNext] call).  The wake run is persisted
  /// to [AgentRepository] with status `'queued'` before execution, then
  /// updated to `'running'`.  The workflow layer is responsible for updating
  /// the final status to `'completed'` or `'failed'`.
  Future<void> processNext() async {
    final job = queue.dequeue();
    if (job == null) return;

    final acquired = await runner.tryAcquire(job.agentId);
    if (!acquired) {
      // Agent is already running; put the job back for the next cycle.
      queue.enqueue(job);
      return;
    }

    try {
      final entry = WakeRunLogData(
        runKey: job.runKey,
        agentId: job.agentId,
        reason: job.reason,
        reasonId: job.reasonId,
        // A thread ID scopes the message log for this wake; the workflow layer
        // may override this with a richer value.  Use the run key as a stable
        // default so the thread is always uniquely addressable.
        threadId: job.runKey,
        status: 'running',
        createdAt: job.createdAt,
        startedAt: DateTime.now(),
      );

      await repository.insertWakeRun(entry: entry);

      // The workflow layer hooks in here to perform the actual agent
      // execution.  Infrastructure is complete once the run is logged.
    } finally {
      runner.release(job.agentId);
    }
  }
}
