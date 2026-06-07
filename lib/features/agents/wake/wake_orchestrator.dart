import 'dart:async';
import 'dart:developer' as developer;

import 'package:clock/clock.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_time_utils.dart';
import 'package:lotti/features/agents/wake/run_key_factory.dart';
import 'package:lotti/features/agents/wake/wake_queue.dart';
import 'package:lotti/features/agents/wake/wake_runner.dart';
import 'package:lotti/features/agents/wake/wake_suppression_tracker.dart';
import 'package:lotti/features/agents/wake/wake_throttle_coordinator.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';

part 'wake_batch_router.dart';
part 'wake_drain_engine.dart';

/// A registered interest that wakes [agentId] when tokens arrive matching
/// [matchEntityIds].
class AgentSubscription {
  AgentSubscription({
    required this.id,
    required this.agentId,
    required this.matchEntityIds,
    this.predicate,
    this.deferPropagatedMatches = true,
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

  /// Whether a match made only through [propagatedNotification] should use the
  /// conservative daily-digest deferral instead of the normal short throttle.
  ///
  /// Project-agent subscriptions keep this enabled so linked-task churn marks
  /// a project stale without spending tokens immediately. Task-agent
  /// subscriptions disable it: child-entry/task-context changes should update
  /// the task agent on the normal coalesced wake path.
  final bool deferPropagatedMatches;
}

/// Checks whether a task (by ID) has meaningful content (at least one linked
/// entry with non-empty text). Used by the content-gating logic for agents
/// auto-created from category defaults.
typedef TaskContentChecker = Future<bool> Function(String taskId);

/// Sync-aware entity writer that stamps the vector clock and enqueues
/// an outbox message. Used when the orchestrator needs to persist a
/// state mutation that must propagate to other devices.
typedef SyncEntityWriter = Future<void> Function(AgentDomainEntity entity);

/// Optional hook run **once per wake, just before the executor**. Used by fork
/// healing (ADR 0018 rule 8): collapse a surviving multi-head `messagePrev` fork
/// into one continuation node before the wake acts, so context and the
/// on-device prefix stay bounded. Best-effort — a failure is logged and the wake
/// proceeds (healing is an optimization, never a correctness mechanism).
typedef WakeStartHook =
    Future<void> Function(String agentId, String runKey, String threadId);

/// Signature for the callback that executes a wake cycle.
///
/// [agentId] is the target agent's ID.
/// [runKey] is the deterministic run key.
/// [triggers] is the set of entity IDs that triggered the wake.
/// [threadId] scopes the conversation for this wake.
///
/// Returns a map of mutated entity IDs → vector clocks for self-notification
/// suppression. An empty map or `null` indicates no mutations occurred.
typedef WakeExecutor =
    Future<Map<String, VectorClock>?> Function(
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
    this.domainLogger,
    this.wakeExecutor,
    this.onPersistedStateChanged,
    this.taskContentChecker,
    this.syncEntityWriter,
    this.onWakeStart,
  }) {
    _throttle = WakeThrottleCoordinator(
      repository: repository,
      throttleWindow: throttleWindow,
      onPersistedStateChanged: onPersistedStateChanged,
      onDrainRequested: processNext,
      domainLogger: domainLogger,
    );
  }

  final AgentRepository repository;
  final WakeQueue queue;
  final WakeRunner runner;

  /// Optional domain logger for structured, PII-safe logging.
  final DomainLogger? domainLogger;

  /// Optional callback that performs the actual agent execution during
  /// [processNext]. When set, the orchestrator delegates to this function
  /// after acquiring the run lock and persisting the wake-run entry.
  WakeExecutor? wakeExecutor;

  /// Optional callback that checks whether a task has meaningful content.
  /// Used to gate auto-assigned agents (awaitingContent flag) so they don't
  /// run until the task actually has text content to analyze.
  TaskContentChecker? taskContentChecker;

  /// Optional sync-aware entity writer for state mutations that must
  /// propagate across devices (e.g. clearing the `awaitingContent` flag).
  /// When null, falls back to the raw [repository] write.
  SyncEntityWriter? syncEntityWriter;

  /// Optional pre-wake hook (fork healing, ADR 0018 rule 8) run just before the
  /// executor for each wake. When null (the default), wakes run exactly as
  /// before — this is the off state of the join-healing flag.
  WakeStartHook? onWakeStart;

  /// Optional callback fired when persisted throttle state changes for an
  /// agent (set/clear `nextWakeAt`).
  final void Function(String agentId)? onPersistedStateChanged;

  final _subscriptions = <AgentSubscription>[];
  final _suppression = WakeSuppressionTracker();
  late final WakeThrottleCoordinator _throttle;

  /// In-memory mirror of the persisted `awaitingContent` flag for each agent.
  ///
  /// Populated by the task-agent service when agents are created or their
  /// subscriptions are restored, and cleared by [_shouldSkipForAwaitingContent]
  /// once meaningful task content arrives. Used in [_onBatch] to suppress the
  /// 2-minute throttle countdown for blank tasks — there is no point surfacing
  /// a "wake in 2:00" timer when the content gate is going to skip the run
  /// anyway.
  final _agentsAwaitingContent = <String>{};

  // ── Throttle state ──────────────────────────────────────────────────────

  /// The minimum interval between subscription-triggered wakes for the
  /// same agent. Manual wakes bypass this gate.
  ///
  /// Also used as the initial deferral window: the first subscription
  /// notification does not dispatch immediately but schedules a deferred
  /// drain after this duration, allowing bursty edits to coalesce.
  static const throttleWindow = Duration(seconds: 120);

  /// Hard upper bound for a single wake cycle. If the executor has not
  /// returned within this window the run is signalled to abort, the
  /// wake-run row is marked `aborted`, and the runner lock is released so
  /// the agent can be re-triggered. The executor future may still complete
  /// in the background (Dart cannot cancel arbitrary futures), but its
  /// result is ignored and its mutations are treated like any other DB
  /// write — i.e. they may surface as new notifications.
  static const wakeRunMaxDuration = Duration(minutes: 2);

  /// Hard cap for the pre-wake [onWakeStart] hook (fork healing). The hook runs
  /// before the executor's [wakeRunMaxDuration] race is armed, so it gets its
  /// own bound — a pathological full-log load must not stall the wake. A timeout
  /// is treated like any other hook failure: logged, then the wake proceeds
  /// (healing is an optimization, never required).
  static const wakeStartHookTimeout = Duration(seconds: 30);

  // Follow-up drains are handled by [WakeThrottleCoordinator]'s deferred
  // drain timer. After a subscription wake completes, a new drain is scheduled
  // only when signals arrived during execution and left work in [queue].

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

  /// Timestamp when the current drain started, for stale-drain detection.
  DateTime? _drainStartedAt;

  /// Generation counter for drain cancellation. Incremented when a stale
  /// drain is force-reset so the old drain's loop can detect it was
  /// superseded and bail out.
  int _drainGeneration = 0;

  /// Maximum duration for a drain before it is considered stale and the
  /// guard is force-reset.
  static const _drainTimeout = Duration(minutes: 5);

  /// Safety-net periodic timer that catches any scenario where a deferred
  /// drain timer fails to fire (macOS App Nap, race conditions, etc.).
  Timer? _safetyNetTimer;

  static const _restoredPendingWakeSubscriptionId = 'restored_pending_wake';

  /// Interval for the safety-net timer. Shorter than [throttleWindow] so
  /// stuck jobs are recovered within a reasonable time.
  static const safetyNetInterval = Duration(seconds: 60);

  StreamSubscription<Set<String>>? _notificationSub;

  void _log(String message, {String? subDomain}) {
    domainLogger?.log(LogDomain.agentRuntime, message, subDomain: subDomain);
  }

  void _logError(String message, {Object? error, StackTrace? stackTrace}) {
    if (domainLogger != null) {
      domainLogger!.error(
        LogDomain.agentRuntime,
        error ?? message,
        message: error != null ? message : null,
        stackTrace: stackTrace,
      );
    } else {
      developer.log(
        '$message${error != null ? ' (errorType=${error.runtimeType})' : ''}',
        name: 'WakeOrchestrator',
        error: error?.runtimeType,
        stackTrace: stackTrace,
      );
    }
  }

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
    _suppression.clearAgent(agentId);
    _wakeCounters.remove(agentId);
    _agentsAwaitingContent.remove(agentId);
    clearThrottle(agentId);
  }

  /// Remove a single subscription by id. Used when a remote `AgentTaskLink`
  /// delete syncs in: the per-link subscription needs to go, but the agent's
  /// other subscriptions and per-agent runtime state (suppression, throttle,
  /// wake counters) must stay intact.
  void removeSubscription(String subscriptionId) {
    _subscriptions.removeWhere((s) => s.id == subscriptionId);
  }

  /// Mark [agentId] as awaiting-content (or not).
  ///
  /// While the flag is set, [_onBatch] will not call [_setThrottleDeadline]
  /// for this agent — so subscription notifications coming in for a blank
  /// task do not surface a 2-minute countdown timer in the UI. The job is
  /// still enqueued and will be picked up by the safety-net drain or a
  /// later notification once content arrives.
  void setAwaitingContent(String agentId, {required bool awaiting}) {
    if (awaiting) {
      _agentsAwaitingContent.add(agentId);
    } else {
      _agentsAwaitingContent.remove(agentId);
    }
  }

  /// Returns `true` when [agentId] is currently awaiting content.
  bool isAwaitingContent(String agentId) =>
      _agentsAwaitingContent.contains(agentId);

  // ── Self-notification suppression ──────────────────────────────────────────

  /// Record which entities were mutated by [agentId] during a tool call.
  ///
  /// [entries] maps entityId → VectorClock that was written.  On the next
  /// notification batch these entries will be compared against the incoming
  /// tokens; if the record is still within `_suppressionTtl` the notification
  /// is suppressed so the agent does not wake on its own writes.
  void recordMutatedEntities(
    String agentId,
    Map<String, VectorClock> entries,
  ) {
    _suppression.recordMutatedEntities(agentId, entries);
  }

  /// Pre-register suppression for [agentId] before execution starts.
  ///
  /// Uses only the [triggerTokens] that caused this wake.  Any notification
  /// matching these IDs that arrives while the executor is running will be
  /// suppressed, closing the window between DB writes and
  /// [recordMutatedEntities].  After execution, the actual mutation set
  /// replaces this pre-registered data.
  void _preRegisterSuppression(String agentId, Set<String> triggerTokens) {
    _suppression.preRegisterSuppression(agentId, triggerTokens);
  }

  // ── Throttle management ────────────────────────────────────────────────────

  /// Returns `true` when [agentId] is within its throttle cooldown window.
  bool _isThrottled(String agentId) {
    return _throttle.isThrottled(agentId);
  }

  /// Set the throttle deadline for [agentId] and persist it to the agent's
  /// state entity via `nextWakeAt`.
  ///
  /// [customDeadline], when provided, overrides the default
  /// `now + throttleWindow`. Used by the propagated-match path in
  /// [_onBatch] to defer to the next 06:00 instead of the standard
  /// 120-second cooldown.
  Future<void> _setThrottleDeadline(
    String agentId, {
    DateTime? customDeadline,
  }) async {
    await _throttle.setDeadline(agentId, customDeadline: customDeadline);
  }

  /// Set a throttle deadline from an external source (e.g. startup hydration).
  ///
  /// If [deadline] is in the past, it is ignored.
  void setThrottleDeadline(String agentId, DateTime deadline) {
    _throttle.setDeadlineFromHydration(agentId, deadline);
  }

  /// Restore a persisted deferred subscription wake after an app restart.
  ///
  /// `nextWakeAt` is durable, but [WakeQueue] is intentionally in-memory.
  /// Startup hydration must therefore reconstruct a queue job as well as the
  /// throttle deadline; otherwise an overdue row can remain visible in the
  /// sidebar forever with nothing left to execute it.
  void restorePendingWake({
    required String agentId,
    required DateTime dueAt,
  }) {
    final now = clock.now();
    final runKey = RunKeyFactory.forSubscription(
      agentId: agentId,
      subscriptionId: _restoredPendingWakeSubscriptionId,
      batchTokens: const <String>{},
      wakeCounter: 0,
      timestamp: dueAt,
    );

    // Overdue jobs use [dueAt] as createdAt so they sort ahead of any wakes
    // enqueued post-startup; future jobs use [now] so FIFO ordering doesn't
    // promote them above real signals that arrive before the deadline.
    final createdAt = dueAt.isBefore(now) ? dueAt : now;

    queue.enqueue(
      WakeJob(
        runKey: runKey,
        agentId: agentId,
        reason: WakeReason.subscription.name,
        triggerTokens: const <String>{},
        reasonId: _restoredPendingWakeSubscriptionId,
        createdAt: createdAt,
      ),
    );

    if (dueAt.isAfter(now)) {
      setThrottleDeadline(agentId, dueAt);
    } else {
      clearThrottle(agentId);
      unawaited(processNext());
    }
  }

  /// Clear the throttle for [agentId], allowing an immediate wake.
  ///
  /// Also persists `nextWakeAt = null` so the cleared state survives
  /// app restarts.
  void clearThrottle(String agentId) {
    _throttle.clearThrottle(agentId);
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
    _throttle.dispose();
    await _notificationSub?.cancel();
    _notificationSub = null;
  }

  /// Starts a periodic safety-net timer that ensures the queue is eventually
  /// drained even if a deferred drain timer fails to fire.
  ///
  /// Only triggers [processNext] when the queue has pending jobs AND no
  /// drain is currently in progress. We intentionally do NOT check
  /// `_deferredDrainTimers.isEmpty` because a stale or cancelled timer
  /// entry lingering in the map would permanently disable the safety net —
  /// exactly the failure mode this mechanism is meant to recover from.
  void _startSafetyNet() {
    _safetyNetTimer?.cancel();
    _safetyNetTimer = Timer.periodic(safetyNetInterval, (_) {
      if (!queue.isEmpty && !_isDraining) {
        _log('safety-net drain: queue=${queue.length}');
        unawaited(processNext());
      }
    });
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
    String? workspaceKey,
  }) {
    // Manual wakes bypass and clear the throttle gate so the user's action
    // takes effect immediately.
    clearThrottle(agentId);

    // Remove pending jobs the manual wake supersedes — scoped to its own
    // workspace so a day-A manual wake under one planner does not cancel
    // queued day-B work (ADR 0022). For single-workspace agents the workspace
    // is null and this is the same agent-wide superseding as before.
    queue.removeByAgent(agentId, workspaceKey: workspaceKey);

    final now = clock.now();
    final runKey = RunKeyFactory.forManual(
      agentId: agentId,
      reason: reason,
      workspaceKey: workspaceKey,
      timestamp: now,
    );

    final job = WakeJob(
      runKey: runKey,
      agentId: agentId,
      reason: reason,
      triggerTokens: triggerTokens,
      workspaceKey: workspaceKey,
      createdAt: now,
    );

    queue.enqueue(job);
    unawaited(processNext());
  }

  // ── Internal notification handling ─────────────────────────────────────────

  /// Process the next pending job; see [WakeDrainEngine].
  Future<void> processNext() => processNextImpl();

  /// Abort the in-flight wake for [agentId], if any.
  ///
  /// Used by the user-initiated cancel button on the ongoing wake row.
  /// Returns `true` when an active run was signalled, `false` when the
  /// agent is not currently running.
  bool abortRunningWake(String agentId) => runner.abort(agentId);
}
