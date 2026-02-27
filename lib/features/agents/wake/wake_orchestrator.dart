import 'dart:async';
import 'dart:developer' as developer;

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
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

  // ── Throttle state ──────────────────────────────────────────────────────

  /// In-memory cache of the next allowed run time per agent.
  ///
  /// When a subscription-triggered wake completes, a deadline is set at
  /// `clock.now() + throttleWindow`. Subsequent subscription notifications
  /// for the same agent are dropped until the deadline expires.
  /// Manual wakes (creation, reanalysis) bypass and clear the throttle.
  final _throttleDeadlines = <String, DateTime>{};

  /// Deferred drain timers that fire when the throttle window expires,
  /// triggering [processNext] to pick up any work that arrived during
  /// the cooldown period.
  final _deferredDrainTimers = <String, Timer>{};

  /// The minimum interval between subscription-triggered wakes for the
  /// same agent. Manual wakes bypass this gate.
  ///
  /// Also used as the initial deferral window: the first subscription
  /// notification does not dispatch immediately but schedules a deferred
  /// drain after this duration, allowing bursty edits to coalesce.
  static const throttleWindow = Duration(seconds: 120);

  // Post-execution drain is handled by the throttle's deferred drain timer
  // (`_scheduleDeferredDrain`). After a subscription wake completes,
  // `_setThrottleDeadline` schedules a drain at `now + throttleWindow`,
  // which picks up any signals that arrived during execution.

  /// Monotonic wake counter per agent.
  ///
  /// Incremented each time a subscription-driven wake is enqueued, ensuring
  /// that identical token sets produce distinct run keys even when the same
  /// notification arrives twice while the agent is busy.  The counter is
  /// kept in-memory (reset on app restart) since persistence is not required
  /// — the counter only needs to be unique within a single orchestrator
  /// lifecycle.
  final _wakeCounters = <String, int>{};

  /// Single-flight guard for [processNext].
  ///
  /// Prevents overlapping drain loops that could clear queue history while
  /// another drain still holds deferred jobs in its local list.  When a drain
  /// is already in progress, new [_onBatch] / [enqueueManualWake] callers
  /// set [_drainRequested] so the active drain re-checks after finishing.
  bool _isDraining = false;

  /// Set when a drain is requested while one is already in progress.
  bool _drainRequested = false;

  /// Safety-net periodic timer that catches any scenario where a deferred
  /// drain timer fails to fire (macOS App Nap, race conditions, etc.).
  Timer? _safetyNetTimer;

  /// Interval for the safety-net timer. Shorter than [throttleWindow] so
  /// stuck jobs are recovered within a reasonable time.
  static const safetyNetInterval = Duration(seconds: 60);

  /// Self-notification suppression state.
  ///
  /// Maps agentId → [_MutationRecord] (entity IDs + timestamp). When a
  /// notification batch arrives, tokens that match entities the agent itself
  /// mutated are suppressed — but only if the mutation record is recent
  /// (within [_suppressionTtl]). Stale records are ignored so that external
  /// edits to the same entity are not incorrectly suppressed.
  ///
  /// This map stores only **confirmed** mutations from completed executions.
  /// Pre-execution suppression (a broader approximation) is stored separately
  /// in [_preRegisteredSuppression] and only checked during the drain re-check
  /// (not during `_onBatch`), so that genuine external signals arriving during
  /// execution are not incorrectly dropped.
  final _recentlyMutatedEntries = <String, _MutationRecord>{};

  /// Pre-execution suppression data.
  ///
  /// Set before execution starts using the agent's subscribed entity IDs as a
  /// conservative over-approximation. Only checked during the drain re-check
  /// (line `_drain`) to catch self-notifications that slipped through between
  /// DB writes and `recordMutatedEntities`. NOT checked during `_onBatch`,
  /// where it would incorrectly suppress genuine external signals.
  final _preRegisteredSuppression = <String, _MutationRecord>{};

  /// Duration after which self-mutation records expire and no longer suppress
  /// notifications. Must be long enough to cover the `UpdateNotifications`
  /// debounce window (100ms local, 1s sync) plus scheduling jitter.
  static const _suppressionTtl = Duration(seconds: 5);

  StreamSubscription<Set<String>>? _notificationSub;

  // ── Subscription management ────────────────────────────────────────────────

  /// Register a subscription so that the agent is woken when matching tokens
  /// arrive.
  ///
  /// If a subscription with the same [AgentSubscription.id] already exists it
  /// is replaced, preventing duplicate wake jobs when `restoreSubscriptions`
  /// runs more than once (e.g. on hot restart).
  void addSubscription(AgentSubscription sub) {
    final idx = _subscriptions.indexWhere((s) => s.id == sub.id);
    if (idx >= 0) {
      _subscriptions[idx] = sub;
    } else {
      _subscriptions.add(sub);
    }
  }

  /// Remove all subscriptions for [agentId] and clean up internal state.
  void removeSubscriptions(String agentId) {
    _subscriptions.removeWhere((s) => s.agentId == agentId);
    _recentlyMutatedEntries.remove(agentId);
    _preRegisteredSuppression.remove(agentId);
    _wakeCounters.remove(agentId);
    clearThrottle(agentId);
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

  /// Pre-register suppression for [agentId] before execution starts.
  ///
  /// Uses the union of all subscribed entity IDs for this agent as a
  /// conservative over-approximation.  Any notification matching these IDs
  /// that arrives while the executor is running will be suppressed, closing
  /// the window between DB writes and [recordMutatedEntities].  After
  /// execution, the actual mutation set replaces this pre-registered data.
  void _preRegisterSuppression(String agentId) {
    final subscribedIds = <String>{};
    for (final sub in _subscriptions) {
      if (sub.agentId == agentId) {
        subscribedIds.addAll(sub.matchEntityIds);
      }
    }
    if (subscribedIds.isNotEmpty) {
      _preRegisteredSuppression[agentId] = _MutationRecord(
        entityIds: subscribedIds,
        recordedAt: clock.now(),
      );
    }
  }

  // ── Throttle management ────────────────────────────────────────────────────

  /// Returns `true` when [agentId] is within its throttle cooldown window.
  bool _isThrottled(String agentId) {
    final deadline = _throttleDeadlines[agentId];
    if (deadline == null) return false;
    if (clock.now().isBefore(deadline)) return true;
    // Expired — clean up.
    _throttleDeadlines.remove(agentId);
    return false;
  }

  /// Set the throttle deadline for [agentId] and persist it to the agent's
  /// state entity via `nextWakeAt`.
  Future<void> _setThrottleDeadline(String agentId) async {
    final deadline = clock.now().add(throttleWindow);
    _throttleDeadlines[agentId] = deadline;

    // Persist to AgentStateEntity.nextWakeAt so the deadline survives
    // app backgrounding / restart.
    try {
      final state = await repository.getAgentState(agentId);
      if (state != null) {
        await repository.upsertEntity(
          state.copyWith(nextWakeAt: deadline, updatedAt: clock.now()),
        );
      }
    } catch (e) {
      developer.log(
        'Failed to persist throttle deadline for $agentId: $e',
        name: 'WakeOrchestrator',
      );
    }

    _scheduleDeferredDrain(agentId, deadline);
  }

  /// Set a throttle deadline from an external source (e.g. startup hydration).
  ///
  /// If [deadline] is in the past, it is ignored.
  void setThrottleDeadline(String agentId, DateTime deadline) {
    if (deadline.isBefore(clock.now())) return;
    _throttleDeadlines[agentId] = deadline;
    _scheduleDeferredDrain(agentId, deadline);
  }

  /// Clear the throttle for [agentId], allowing an immediate wake.
  ///
  /// Also persists `nextWakeAt = null` so the cleared state survives
  /// app restarts.
  void clearThrottle(String agentId) {
    _throttleDeadlines.remove(agentId);
    _deferredDrainTimers[agentId]?.cancel();
    _deferredDrainTimers.remove(agentId);
    unawaited(_clearPersistedThrottle(agentId));
  }

  /// Persist `nextWakeAt = null` so that a cleared throttle is not
  /// re-hydrated after an app restart.
  ///
  /// Guards against write races: if a new in-memory deadline has been set
  /// between the `clearThrottle` call and this async write, the clear is
  /// skipped to avoid overwriting the newer deadline.
  Future<void> _clearPersistedThrottle(String agentId) async {
    try {
      // If a new deadline was set after clearThrottle but before this
      // async continuation runs, skip the write to avoid clobbering it.
      if (_throttleDeadlines.containsKey(agentId)) return;

      final state = await repository.getAgentState(agentId);

      // Re-check after the await: a new throttle may have been set while
      // we were reading the state from the database.
      if (_throttleDeadlines.containsKey(agentId)) return;

      if (state != null && state.nextWakeAt != null) {
        await repository.upsertEntity(
          state.copyWith(nextWakeAt: null, updatedAt: clock.now()),
        );
      }
    } catch (e) {
      developer.log(
        'Failed to clear persisted throttle for $agentId: $e',
        name: 'WakeOrchestrator',
      );
    }
  }

  /// Schedule a [Timer] that fires [processNext] when the throttle window
  /// for [agentId] expires.
  ///
  /// When [deadline] has already passed (`remaining <= Duration.zero`), the
  /// throttle is cleared immediately and [processNext] is scheduled on the
  /// next microtask to avoid reentrancy issues. This prevents a scenario
  /// where the caller set `_throttleDeadlines[agentId]` but no timer fires
  /// to clear it, leaving the agent permanently throttled.
  void _scheduleDeferredDrain(String agentId, DateTime deadline) {
    _deferredDrainTimers[agentId]?.cancel();
    final remaining = deadline.difference(clock.now());
    if (remaining <= Duration.zero) {
      // Deadline already passed — clear throttle and drain immediately.
      _deferredDrainTimers.remove(agentId);
      _throttleDeadlines.remove(agentId);
      unawaited(_clearPersistedThrottle(agentId));
      scheduleMicrotask(() => unawaited(processNext()));
      return;
    }
    _deferredDrainTimers[agentId] = Timer(remaining, () {
      _deferredDrainTimers.remove(agentId);
      _throttleDeadlines.remove(agentId);
      // Clear the persisted nextWakeAt so the agent detail page and
      // startup hydration don't see a stale past deadline.
      unawaited(_clearPersistedThrottle(agentId));
      unawaited(processNext());
    });
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  /// Start listening to [notificationStream].
  ///
  /// Each batch is a `Set<String>` of affected entity IDs / notification
  /// tokens as emitted by `UpdateNotifications.updateStream`.
  ///
  /// If a previous subscription exists it is fully cancelled before the new
  /// one is attached, preventing stale event delivery.
  ///
  /// Also starts a periodic safety-net timer that catches scenarios where
  /// the deferred drain timer fails to fire (e.g. macOS App Nap, race
  /// conditions).
  Future<void> start(Stream<Set<String>> notificationStream) async {
    final oldSub = _notificationSub;
    if (oldSub != null) {
      _notificationSub = null;
      await oldSub.cancel();
    }
    _notificationSub = notificationStream.listen(_onBatch);
    _startSafetyNet();
  }

  /// Stop listening, cancel the subscription, and clean up timers.
  Future<void> stop() async {
    _safetyNetTimer?.cancel();
    _safetyNetTimer = null;
    for (final timer in _deferredDrainTimers.values) {
      timer.cancel();
    }
    _deferredDrainTimers.clear();
    await _notificationSub?.cancel();
    _notificationSub = null;
  }

  /// Starts a periodic safety-net timer that ensures the queue is eventually
  /// drained even if a deferred drain timer fails to fire.
  ///
  /// Only triggers [processNext] when the queue has pending jobs AND no
  /// deferred drain timer is active AND no drain is currently in progress.
  void _startSafetyNet() {
    _safetyNetTimer?.cancel();
    _safetyNetTimer = Timer.periodic(safetyNetInterval, (_) {
      if (!queue.isEmpty && _deferredDrainTimers.isEmpty && !_isDraining) {
        developer.log(
          'Safety-net drain: queue has ${queue.length} pending jobs '
          'with no deferred timers',
          name: 'WakeOrchestrator',
        );
        unawaited(processNext());
      }
    });
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
    // Manual wakes bypass and clear the throttle gate so the user's action
    // takes effect immediately.
    clearThrottle(agentId);

    final now = clock.now();
    final runKey = RunKeyFactory.forManual(
      agentId: agentId,
      reason: reason,
      timestamp: now,
    );

    final job = WakeJob(
      runKey: runKey,
      agentId: agentId,
      reason: reason,
      triggerTokens: triggerTokens,
      createdAt: now,
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

      // 3. Throttle gate: when the agent is already throttled, attempt to
      //    merge the new tokens into the queued job so they are processed
      //    when the deferred drain fires. If no job exists yet (e.g. the
      //    previous one was already dequeued), enqueue a fresh one.
      if (_isThrottled(sub.agentId)) {
        if (!queue.mergeTokens(sub.agentId, matched)) {
          final counter = _wakeCounters[sub.agentId] ?? 0;
          _wakeCounters[sub.agentId] = counter + 1;
          final now = clock.now();
          queue.enqueue(
            WakeJob(
              runKey: RunKeyFactory.forSubscription(
                agentId: sub.agentId,
                subscriptionId: sub.id,
                batchTokens: matched,
                wakeCounter: counter,
                timestamp: now,
              ),
              agentId: sub.agentId,
              reason: WakeReason.subscription.name,
              triggerTokens: Set<String>.from(matched),
              reasonId: sub.id,
              createdAt: now,
            ),
          );
        }
        continue;
      }

      // 4. Apply optional fine-grained predicate.
      final predicate = sub.predicate;
      if (predicate != null && !predicate(matched)) continue;

      // 5. Derive a deterministic run key and enqueue.
      final counter = _wakeCounters[sub.agentId] ?? 0;
      _wakeCounters[sub.agentId] = counter + 1;

      final now = clock.now();
      final runKey = RunKeyFactory.forSubscription(
        agentId: sub.agentId,
        subscriptionId: sub.id,
        batchTokens: matched,
        wakeCounter: counter,
        timestamp: now,
      );

      final job = WakeJob(
        runKey: runKey,
        agentId: sub.agentId,
        reason: WakeReason.subscription.name,
        triggerTokens: Set<String>.from(matched),
        reasonId: sub.id,
        createdAt: clock.now(),
      );

      // Attempt to merge tokens into an existing queued job for this agent
      // before enqueuing a new one; this coalesces rapid-fire notifications.
      if (!queue.mergeTokens(sub.agentId, matched)) {
        queue.enqueue(job);
      }

      // Defer-first: instead of dispatching immediately, set a throttle
      // deadline and schedule a deferred drain. This allows bursty edits
      // to coalesce into a single wake cycle.
      final deadline = now.add(throttleWindow);
      _throttleDeadlines[sub.agentId] = deadline;
      _scheduleDeferredDrain(sub.agentId, deadline);

      if (kDebugMode) {
        developer.log(
          'Deferred wake for ${sub.agentId}: '
          'drain scheduled in ${throttleWindow.inSeconds}s',
          name: 'WakeOrchestrator',
        );
      }
    }
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

  /// Returns `true` when all [matchedTokens] are covered by the agent's
  /// pre-registered suppression (conservative over-approximation set before
  /// execution starts).
  ///
  /// Only used during the drain re-check, NOT during `_onBatch`.
  bool _isPreRegisteredSuppressed(
    String agentId,
    Set<String> matchedTokens,
  ) {
    final record = _preRegisteredSuppression[agentId];
    if (record == null || record.entityIds.isEmpty) return false;

    final elapsed = clock.now().difference(record.recordedAt);
    if (elapsed > _suppressionTtl) {
      _preRegisteredSuppression.remove(agentId);
      return false;
    }

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
    if (_isDraining) {
      _drainRequested = true;
      return;
    }

    _isDraining = true;
    try {
      // Re-enter the drain loop when new work arrived while we were busy.
      do {
        _drainRequested = false;
        await _drain();
      } while (_drainRequested);
    } finally {
      _isDraining = false;
    }
  }

  /// Single pass: dequeue and execute all ready jobs.
  Future<void> _drain() async {
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

        // Re-check suppression and throttle for subscription jobs that were
        // enqueued during an agent's execution — before the throttle deadline
        // or recordMutatedEntities was set.
        if (job.reason == WakeReason.subscription.name) {
          // Self-notification: drop the job entirely.
          if (_isSuppressed(job.agentId, job.triggerTokens) ||
              _isPreRegisteredSuppressed(
                job.agentId,
                job.triggerTokens,
              )) {
            runner.release(job.agentId);
            continue;
          }

          // Throttled: defer the job so the deferred drain timer can pick
          // it up after the throttle window expires.
          if (_isThrottled(job.agentId)) {
            runner.release(job.agentId);
            deferred.add(job);
            continue;
          }
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
  ///
  /// All exceptions are caught and logged so that a single failing job does
  /// not abort the drain loop and starve other queued jobs.
  Future<void> _executeJob(WakeJob job) async {
    final threadId = job.runKey;

    try {
      final entry = WakeRunLogData(
        runKey: job.runKey,
        agentId: job.agentId,
        reason: job.reason,
        reasonId: job.reasonId,
        threadId: threadId,
        status: WakeRunStatus.running.name,
        createdAt: job.createdAt,
        startedAt: clock.now(),
      );

      try {
        await repository.insertWakeRun(entry: entry);
      } catch (e) {
        developer.log(
          'Failed to persist wake run ${job.runKey}: $e',
          name: 'WakeOrchestrator',
        );
        return;
      }

      final executor = wakeExecutor;
      if (executor == null) {
        developer.log(
          'No wakeExecutor set — marking run ${job.runKey} as failed',
          name: 'WakeOrchestrator',
        );
        await _safeUpdateStatus(
          job.runKey,
          WakeRunStatus.failed.name,
          errorMessage: 'No wake executor registered',
        );
        return;
      }

      try {
        // Pre-register suppression data BEFORE executing, using the agent's
        // subscribed entity IDs as a conservative over-approximation.  This
        // prevents a race where the executor writes to the DB, the stream
        // emits a notification, and _onBatch enqueues a self-wake before
        // the executor returns and recordMutatedEntities is called.
        _preRegisterSuppression(job.agentId);

        final mutated = await executor(
          job.agentId,
          job.runKey,
          job.triggerTokens,
          threadId,
        );

        // Clear the pre-registered suppression and record actual mutations
        // so that only genuinely self-written entities are suppressed.
        _preRegisteredSuppression.remove(job.agentId);
        if (mutated != null && mutated.isNotEmpty) {
          recordMutatedEntities(job.agentId, mutated);
        } else {
          // No mutations this cycle — clear confirmed suppression so
          // external edits are not incorrectly blocked.
          _recentlyMutatedEntries.remove(job.agentId);
        }

        await _safeUpdateStatus(
          job.runKey,
          WakeRunStatus.completed.name,
          completedAt: clock.now(),
        );

        // Set the throttle deadline for subscription-triggered wakes so
        // that rapid-fire mutations don't cause excessive LLM calls.
        if (job.reason == WakeReason.subscription.name) {
          await _setThrottleDeadline(job.agentId);
        }
      } catch (e) {
        _preRegisteredSuppression.remove(job.agentId);
        developer.log(
          'Wake executor failed for run ${job.runKey}: $e',
          name: 'WakeOrchestrator',
        );
        await _safeUpdateStatus(
          job.runKey,
          WakeRunStatus.failed.name,
          errorMessage: e.toString(),
        );
      }
    } finally {
      runner.release(job.agentId);
    }
  }

  /// Update wake run status, swallowing any DB errors so they don't escape
  /// `_executeJob` / `_drain` / `processNext`.
  Future<void> _safeUpdateStatus(
    String runKey,
    String status, {
    DateTime? completedAt,
    String? errorMessage,
  }) async {
    try {
      await repository.updateWakeRunStatus(
        runKey,
        status,
        completedAt: completedAt,
        errorMessage: errorMessage,
      );
    } catch (e) {
      developer.log(
        'Failed to update wake run status for $runKey to $status: $e',
        name: 'WakeOrchestrator',
      );
    }
  }
}

/// Internal record of which entities an agent mutated and when.
class _MutationRecord {
  _MutationRecord({required this.entityIds, required this.recordedAt});

  final Set<String> entityIds;
  final DateTime recordedAt;
}
