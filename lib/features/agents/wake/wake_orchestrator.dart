import 'dart:async';
import 'dart:collection';

import 'package:clock/clock.dart';
import 'package:lotti/classes/agent_wake_cadence.dart';
import 'package:lotti/classes/agents/agent_constants.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/classes/day_agent_trigger_tokens.dart';
import 'package:lotti/classes/vector_clock.dart';
import 'package:lotti/database/agents/agent_database.dart';
import 'package:lotti/database/agents/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_automation_policy.dart';
import 'package:lotti/features/agents/model/agent_time_utils.dart';
import 'package:lotti/features/agents/util/agent_error_logging.dart';
import 'package:lotti/features/agents/wake/agent_wake_coordinator.dart';
import 'package:lotti/features/agents/wake/project_update_slots.dart';
import 'package:lotti/features/agents/wake/run_key_factory.dart';
import 'package:lotti/features/agents/wake/wake_audit.dart';
import 'package:lotti/features/agents/wake/wake_budget.dart';
import 'package:lotti/features/agents/wake/wake_intent_store.dart';
import 'package:lotti/features/agents/wake/wake_queue.dart';
import 'package:lotti/features/agents/wake/wake_runner.dart';
import 'package:lotti/features/agents/wake/wake_suppression_tracker.dart';
import 'package:lotti/features/agents/wake/wake_throttle_coordinator.dart';
import 'package:lotti/features/agents/workflow/wake_result.dart';
import 'package:lotti/features/ai/model/ai_runtime_settings.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';

part 'wake_batch_router.dart';
part 'wake_drain_engine.dart';
part 'wake_drain_policy.dart';
part 'wake_orchestrator_wake_run_completion_part.dart';
part 'wake_orchestrator_bookkeeping.dart';

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
class WakeOrchestrator with AgentErrorLogging {
  WakeOrchestrator({
    required this.repository,
    required this.queue,
    required this.runner,
    required this.domainLogger,
    this.wakeExecutor,
    this.onPersistedStateChanged,
    this.taskContentChecker,
    this.eventContentChecker,
    this.syncEntityWriter,
    this.syncAgentStateUpdater,
    this.onWakeStart,
    this.localHostId,
    this.maxConcurrentWakes = _defaultMaxConcurrentWakes,
    this.intentStore,
    this.taskWakeCadenceResolver,
  }) {
    queue
      ..onEnqueued = (job) {
        _auditQueued(job);
        _recordIntent(job);
      }
      ..onMerged = (job, _) => _recordIntent(job);
    _throttle = WakeThrottleCoordinator(
      repository: repository,
      throttleWindowFor: _coalescingWindowFor,
      onPersistedStateChanged: onPersistedStateChanged,
      onDrainRequested: processNext,
      domainLogger: domainLogger,
    );
  }

  final AgentRepository repository;
  final WakeQueue queue;
  final WakeRunner runner;

  /// Durable record of the wakes still owed, restored after a process death.
  /// Absent in tests and worlds that do not persist wakes.
  final WakeIntentStore? intentStore;

  /// Reads the current global concurrency limit whenever the dispatcher has
  /// capacity. This makes a persisted settings change effective without
  /// rebuilding the orchestrator or restarting the app.
  final MaxConcurrentWakes maxConcurrentWakes;

  /// Resolves a task agent's wake cadence from its own choice and its
  /// category, falling back to the app default (see
  /// [resolveAgentWakeCadence]). Consulted on every match, so a changed
  /// category or default applies without re-registering anything. Without a
  /// resolver every agent keeps the standard two-minute window.
  final TaskWakeCadenceResolver? taskWakeCadenceResolver;

  /// Domain logger for structured, PII-safe logging.
  @override
  final DomainLogger domainLogger;

  @override
  LogDomain get errorLogDomain => LogDomain.agentRuntime;

  /// Optional callback that performs the actual agent execution during
  /// [processNext]. When set, the orchestrator delegates to this function
  /// after acquiring the run lock and persisting the wake-run entry.
  WakeExecutor? wakeExecutor;

  /// Optional callback that checks whether a content-gated task has meaningful
  /// content (text). Used to gate auto-assigned task agents (awaitingContent
  /// flag) so they don't run until the task has content.
  AgentContentChecker? taskContentChecker;

  /// Optional callback that checks whether a content-gated event has content
  /// (a linked photo or note). Used to gate auto-assigned event agents the same
  /// way. Each slot routes only to its own checker — never a cross-slot
  /// fallback — so an event id can never reach the task checker.
  AgentContentChecker? eventContentChecker;

  /// Optional sync-aware entity writer for state mutations that must
  /// propagate across devices (e.g. clearing the `awaitingContent` flag).
  /// When null, falls back to the raw [repository] write.
  SyncEntityWriter? syncEntityWriter;

  /// Optional transactional state updater for partial state mutations.
  SyncAgentStateUpdater? syncAgentStateUpdater;

  /// This device's sync host id, the key its daily-budget claims are
  /// counted under. Null before the vector clock service is wired; claims
  /// then count under a shared placeholder key rather than not at all.
  Future<String?> Function()? localHostId;

  /// Run keys whose daily-budget claim has been persisted, so a run a
  /// superseded drain hands back is not counted a second time. Released
  /// when the run completes.
  final _budgetClaimedRunKeys = <String>{};

  /// Optional cross-device coordination: of several devices about to wake the
  /// same agent over the same state, one runs and the others stand down (see
  /// [AgentWakeCoordinator]). When null, every wake runs uncoordinated.
  AgentWakeCoordinator? coordinator;

  /// Agents whose queued wakes the next drain checks against peers' runs even
  /// while their throttle countdown runs, set by [onPeerWakeStateChanged].
  final _peerCoverageChecks = <String>{};

  /// Agents whose wake was dropped for a peer's running wake that has not
  /// completed yet; see [WakeDrainEngine.settleHandOver].
  final _handedToPeer = <String>{};

  /// Optional pre-wake hook (fork healing, ADR 0018 rule 8) run just before the
  /// executor for each wake. When null (the default), wakes run exactly as
  /// before — this is the off state of the join-healing flag.
  WakeStartHook? onWakeStart;

  /// Optional callback fired when persisted throttle state changes for an
  /// agent (set/clear `nextWakeAt`).
  final void Function(String agentId)? onPersistedStateChanged;

  final _subscriptions = <AgentSubscription>[];
  final _suppression = WakeSuppressionTracker();
  final _activeExecutors =
      <
        String,
        ({
          String agentId,
          String? workspaceKey,
          Set<String> triggerTokens,
          Future<void> settled,
          DateTime startedAt,
        })
      >{};

  /// Executors already reported as hung, so the report is made once.
  final _reportedHungExecutors = <String>{};
  late final WakeThrottleCoordinator _throttle;

  final _runCompletions = StreamController<WakeRunCompletion>.broadcast();

  /// Broadcast stream of terminal wake outcomes, one event per executed run.
  ///
  /// Emitted after the wake-run row reaches its terminal status. Subscribe
  /// **before** calling [enqueueManualWake] and filter on the returned run
  /// key to await a specific wake without polling.
  Stream<WakeRunCompletion> get runCompletions => _runCompletions.stream;

  /// Whether matching work is queued, held by a drain pass, owns the runner
  /// lock, or is still executing after an abort released that lock.
  ///
  /// The last state matters because Dart futures cannot be cancelled. A timed
  /// out executor may continue mutating data after its wake-run row becomes
  /// terminal, so recovery code must not start replacement work until the
  /// underlying future has actually settled. A job a drain pass has taken out
  /// of the queue is just as live: a probe that missed it let the digest
  /// recovery re-arm a digest whose run was about to start.
  bool hasPendingOrActiveWake(
    String agentId, {
    String? workspaceKey,
  }) {
    bool matches(WakeJob job) =>
        job.agentId == agentId && job.workspaceKey == workspaceKey;
    if (queue.hasJobWhere(matches) || _jobsInDrain.any(matches)) return true;
    if (runner.isRunning(agentId) &&
        runner.workspaceKeyFor(agentId) == workspaceKey) {
      return true;
    }
    return _activeExecutors.values.any(
      (execution) =>
          execution.agentId == agentId &&
          execution.workspaceKey == workspaceKey,
    );
  }

  /// Records that the job [runKey] fires scheduled-wake [window], so
  /// [owesWake] can recognize it — across a process death too. A no-op for a
  /// job without an intent, or without an [intentStore].
  void markScheduledWindow(String runKey, String window) =>
      intentStore?.markWindow(runKey, window);

  /// Whether the wake firing scheduled-wake [window] is already owed —
  /// queued, running, completed before consumption, or left unsettled for
  /// [restoreWakeIntents]. Always false without an [intentStore].
  ///
  /// A scheduled-wake record that is still pending although its wake is owed
  /// was fired by a process that died before consuming it; firing it again
  /// would run the window twice on this device
  /// (`specs/tla/ScheduledWakeLease.tla`, `NoDeviceRunsTwice`).
  Future<bool> owesWake(String window) async =>
      await intentStore?.owes(window) ?? false;

  /// Releases the window's completion receipt after its scheduled record
  /// was consumed or advanced, while leaving any running wake restorable.
  void acknowledgeScheduledWindow(String window) =>
      intentStore?.acknowledgeWindow(window);

  /// Completes once every wake intent recorded so far has been written, so a
  /// caller can make a later write depend on the wake being durable. Throws
  /// if persistence fails; a later call retries the latest intent snapshot.
  Future<void> flushWakeIntents() async => intentStore?.flush();

  /// The run key of a wake carrying [token] that has not settled: queued,
  /// held by a drain pass, or executing — including an executor an abort
  /// detached from its lease, until it runs past [hungExecutorAfter].
  ///
  /// Daily OS processing jobs ask this before enqueueing a wake for their
  /// request (`specs/tla/DayProcessingJob.tla`): the wake of an attempt that
  /// timed out, or whose claim lapsed, is still that request's inference.
  String? liveRunKeyWithToken(String token) {
    bool carries(WakeJob job) => job.triggerTokens.contains(token);
    final waiting =
        queue.firstJobWhere(carries) ?? _jobsInDrain.where(carries).firstOrNull;
    if (waiting != null) return waiting.runKey;
    final now = clock.now();
    for (final MapEntry(key: runKey, value: execution)
        in _activeExecutors.entries) {
      if (execution.triggerTokens.contains(token) &&
          now.difference(execution.startedAt) < hungExecutorAfter) {
        return runKey;
      }
    }
    return null;
  }

  /// Jobs a drain pass holds outside [queue]: taken for dispatch but not yet
  /// executing, or held back until the pass requeues them.
  Iterable<WakeJob> get _jobsInDrain =>
      _drainOwnedJobs.values.followedBy(_heldBackJobs.values);

  /// Wakes whose durable record owns their recovery, so they are never wake
  /// intents.
  ///
  /// Daily OS processing jobs have an outbox that owns retry, cancellation,
  /// job boundaries and artifact run-key provenance; replaying them here would
  /// bypass that owner and could merge incompatible job IDs. The coordinator
  /// digest has its scheduled-wake record, which `DayAgentService` retries
  /// when a crash interrupted the run. A second recovery path beside it
  /// digested the day twice: the record's retry and the restored intent both
  /// ran, and an intent whose settle had not reached disk re-ran a digest that
  /// had already completed (`specs/tla/DigestRecovery.tla`).
  static bool _ownsItsRecovery(Set<String> tokens) => tokens.any(
    (token) =>
        token.startsWith(dayAgentProcessingJobPrefix) ||
        token.startsWith(dayAgentDigestPrefix),
  );

  /// Startup, after subscriptions are restored: re-queues every wake intent a
  /// previous process left unsettled — jobs it lost and runs it interrupted.
  /// The intents of one agent and workspace become one job, which merges
  /// into a job already queued for them if there is one. Returns how many
  /// intents were restored. Legacy copies of outbox-owned processing jobs
  /// and of coordinator digests are discarded: their outbox, or the digest
  /// record, is the sole recovery authority.
  Future<int> restoreWakeIntents() => _restoreWakeIntents();

  /// In-memory mirror of the persisted `awaitingContent` flag for each agent.
  ///
  /// Populated by the task-agent service when agents are created or their
  /// subscriptions are restored, and cleared by [_shouldSkipForAwaitingContent]
  /// once meaningful task content arrives. Used in [_onBatch] to suppress the
  /// 2-minute throttle countdown for blank tasks — there is no point surfacing
  /// a "wake in 2:00" timer when the content gate is going to skip the run
  /// anyway.
  final _agentsAwaitingContent = <String>{};
  final _automaticUpdatesDisabledAgents = <String>{};

  /// What [taskWakeCadenceResolver] needs per task agent: the task's own
  /// cadence and its category. Agents absent here (every non-task agent) have
  /// no cadence.
  final _taskWakeCadenceInputs =
      <String, ({AgentWakeCadence? override, String? categoryId})>{};

  /// Latest unpersisted stale signal per agent. Writes are serialized per
  /// agent so bursts coalesce without allowing an older async write to land
  /// after a newer one.
  final _pendingReportStaleAt = <String, DateTime>{};
  final _reportStaleWritesInProgress = <String>{};
  final _freshnessWriteChains = <String, Future<void>>{};

  // ── Throttle state ──────────────────────────────────────────────────────

  /// The minimum interval between subscription-triggered wakes for the
  /// same agent. Manual wakes bypass this gate.
  ///
  /// Also used as the initial deferral window: the first subscription
  /// notification does not dispatch immediately but schedules a deferred
  /// drain after this duration, allowing bursty edits to coalesce.
  static const Duration throttleWindow = liveCoalescingWindow;

  /// Hard upper bound for a single wake cycle. If the executor has not
  /// returned within this window the run is signalled to abort, the
  /// wake-run row is marked `aborted`, and the runner lock is released so
  /// the agent can be re-triggered. The executor future may still complete
  /// in the background (Dart cannot cancel arbitrary futures), but its
  /// result is ignored and its mutations are treated like any other DB
  /// write — i.e. they may surface as new notifications.
  static const wakeRunMaxDuration = Duration(minutes: 10);

  /// How long an executor may run before it stops blocking new runs of its
  /// agent — three run caps, far past anything a healthy wake takes.
  static const hungExecutorAfter = Duration(minutes: 30);

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

  /// Single-scheduler guard for [processNext].
  ///
  /// The scheduler itself may dispatch several wake cycles concurrently, but
  /// only one scheduler may mutate [queue] and clear its run-key history. New
  /// drain requests wake that scheduler so it can fill any free slot.
  bool _isDraining = false;

  /// Set when a drain is requested while one is already in progress.
  bool _drainRequested = false;

  /// Completes when new work arrives while the scheduler is waiting for an
  /// active wake to finish. This lets newly queued work use idle capacity
  /// immediately instead of waiting behind an unrelated long inference.
  Completer<void>? _drainWakeSignal;

  /// Timestamp of the latest scheduler progress, for stale-drain detection.
  /// Updated whenever a wake is dispatched or completes so a healthy drain
  /// processing several slow wakes is not judged by its total lifetime.
  DateTime? _drainLastProgressAt;

  /// Generation counter for drain cancellation. Incremented when a stale
  /// drain is force-reset so the old drain's loop can detect it was
  /// superseded and bail out.
  int _drainGeneration = 0;

  /// Runner leases owned by each drain generation.
  ///
  /// Stale recovery releases only individually stale slots from the
  /// superseded generation. Healthy slots retain ownership until completion,
  /// and lease identity ensures late cleanup cannot release or abort a
  /// replacement run for the same agent.
  final _drainLeasesByGeneration = <int, Set<WakeRunnerLease>>{};

  /// Latest meaningful progress for each active lease. Generation-wide
  /// progress cannot let unrelated healthy wakes hide one stalled slot.
  final _drainLeaseProgressAt = <WakeRunnerLease, DateTime>{};

  /// Jobs temporarily owned by the drain while they are outside [queue] but
  /// have not started executor work yet.
  final _drainOwnedJobs = <String, WakeJob>{};

  /// Jobs a drain pass took out of [queue] and holds back — their agent's
  /// runner was taken, or their agent is throttled — until the pass requeues
  /// them. Tracked only so pending-work probes can see them.
  final _heldBackJobs = <String, WakeJob>{};

  /// Cancellation reason for drain-owned jobs removed by a newer request or
  /// explicit cancellation while an asynchronous pre-dispatch step was active.
  final _cancelledDrainOwnedRunReasons = <String, String>{};

  /// Run keys whose `wake_run_log` row already exists when stale recovery
  /// returns their job to the queue.
  final _persistedWakeRunKeys = <String>{};

  /// Maximum interval without scheduler progress before a drain is considered
  /// stale and the guard is force-reset. This must remain longer than
  /// [wakeRunMaxDuration], with headroom for the bounded pre-wake hook and
  /// terminal status persistence, so a valid slow wake is never superseded.
  static const _drainTimeout = Duration(minutes: 12);

  /// Safety-net periodic timer that catches any scenario where a deferred
  /// drain timer fails to fire or an active drain stops making progress.
  Timer? _safetyNetTimer;

  static const _restoredPendingWakeSubscriptionId = 'restored_pending_wake';

  /// Interval for the safety-net timer. Shorter than [throttleWindow] so
  /// stuck jobs are recovered within a reasonable time.
  static const safetyNetInterval = Duration(seconds: 60);

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
    // An immediate-drain agent must never sit behind a countdown, including
    // a `nextWakeAt` persisted before the policy existed (or before this
    // subscription switched to it). Registration is the reliable moment to
    // retire it: startup hydration may never load the deadline into the
    // coordinator, leaving a stale countdown row in the pending-wakes UI
    // that no in-memory check would ever clear.
    if (sub.drainImmediately) clearThrottle(sub.agentId);
  }

  /// Remove all subscriptions for [agentId] and clean up internal state.
  void removeSubscriptions(String agentId) {
    _subscriptions.removeWhere((s) => s.agentId == agentId);
    _suppression.clearAgent(agentId);
    _wakeCounters.remove(agentId);
    _agentsAwaitingContent.remove(agentId);
    _taskWakeCadenceInputs.remove(agentId);
    clearThrottle(agentId);
  }

  /// Records what resolves [agentId]'s wake cadence: the task's own choice
  /// ([override], null to follow the category) and the task's category.
  void setTaskWakeCadenceRuntime(
    String agentId, {
    required AgentWakeCadence? override,
    required String? categoryId,
  }) {
    _taskWakeCadenceInputs[agentId] = (
      override: override,
      categoryId: categoryId,
    );
  }

  /// Mirrors what resolves [identity]'s wake cadence — its own choice and its
  /// task's category — into the runtime. Other agent kinds have no cadence
  /// and are left alone.
  ///
  /// The category is the identity's single allowed category, which task
  /// agents are created with; an agent scoped to none or several follows the
  /// app default.
  void mirrorTaskWakeCadence(AgentIdentityEntity identity) {
    if (identity.kind != AgentKinds.taskAgent) return;
    final categories = identity.allowedCategoryIds;
    setTaskWakeCadenceRuntime(
      identity.agentId,
      override: identity.config.wakeCadence,
      categoryId: categories.length == 1 ? categories.single : null,
    );
  }

  /// The wake cadence that applies to [agentId] now, or `null` for an agent
  /// without one — any non-task agent, or every agent when no resolver is
  /// wired.
  AgentWakeCadence? wakeCadenceFor(String agentId) {
    final resolver = taskWakeCadenceResolver;
    final inputs = _taskWakeCadenceInputs[agentId];
    if (resolver == null || inputs == null) return null;
    return resolver(override: inputs.override, categoryId: inputs.categoryId);
  }

  /// How long a change to [agentId]'s inputs waits before it runs: its
  /// cadence's window, or [throttleWindow] for an agent without a cadence. A
  /// cadence that never wakes on changes alone never arms a window, so its
  /// value here is only a fallback.
  Duration _coalescingWindowFor(String agentId) =>
      wakeCadenceFor(agentId)?.coalescingWindow ?? throttleWindow;

  /// Stops every wake of [agentId] on this device, now: subscriptions and
  /// throttle go, queued work in every workspace is cancelled, and a running
  /// wake is aborted — which also stops its conversation before the next
  /// model turn (see `isAgentWakeAborted`).
  ///
  /// The kill-switch behind Pause, locally and when a pause arrives by sync.
  /// Returns whether a running wake was signalled.
  bool haltAgent(String agentId) {
    removeSubscriptions(agentId);
    cancelPendingWakes(agentId, allWorkspaces: true);
    return abortRunningWake(agentId);
  }

  /// Disable automatic inference while retaining change observation.
  ///
  /// Matching subscriptions remain registered so relevant changes can mark
  /// the report stale. Existing automation jobs and countdowns are removed;
  /// user-initiated wakes remain available.
  void disableAutomaticUpdatesRuntime(String agentId) {
    _automaticUpdatesDisabledAgents.add(agentId);
    _cancelPendingAutomaticWakes(
      agentId,
      reason: 'automatic wake removed because updates were disabled',
    );
  }

  /// Clears this device's automatic countdown and queued automation jobs.
  ///
  /// Unlike [disableAutomaticUpdatesRuntime], this does not change the
  /// automation policy. Sync uses it when a peer has already consumed the
  /// pending project activity represented by a local subscription wake.
  void cancelPendingAutomaticWakes(String agentId) {
    _cancelPendingAutomaticWakes(
      agentId,
      reason: 'automatic wake removed because project work was consumed',
    );
  }

  /// Allow matching changes to schedule automatic inference again.
  ///
  /// This does not enqueue work or restore an old countdown.
  void enableAutomaticUpdatesRuntime(String agentId) {
    _automaticUpdatesDisabledAgents.remove(agentId);
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

  // ── Throttle management ────────────────────────────────────────────────────

  /// Set a throttle deadline from an external source (e.g. startup hydration).
  ///
  /// If [deadline] is in the past, it is ignored.
  void setThrottleDeadline(String agentId, DateTime deadline) {
    _throttle.setDeadlineFromHydration(agentId, deadline);
  }

  /// Queue one automatic wake behind the standard coalescing countdown.
  ///
  /// Callers that perform cheap deterministic work immediately can use this
  /// second-stage wake for the expensive follow-up. Repeated requests in the
  /// same [workspaceKey] merge into the first job and keep its original
  /// deadline, so a steady stream of evidence cannot postpone the run forever.
  Future<String?> enqueueDeferredAutomaticWake({
    required String agentId,
    required String reason,
    required Set<String> triggerTokens,
    String? workspaceKey,
  }) async {
    if (_automaticUpdatesDisabledAgents.contains(agentId)) return null;
    if (queue.mergeTokens(
      agentId,
      triggerTokens,
      workspaceKey: workspaceKey,
      isDirect: true,
    )) {
      return null;
    }

    final now = clock.now();
    final runKey = RunKeyFactory.forManual(
      agentId: agentId,
      reason: reason,
      workspaceKey: workspaceKey,
      timestamp: now,
    );
    queue.enqueue(
      WakeJob(
        runKey: runKey,
        agentId: agentId,
        reason: reason,
        triggerTokens: triggerTokens,
        workspaceKey: workspaceKey,
        createdAt: now,
        initiator: WakeInitiator.automation,
      ),
    );
    await _setThrottleDeadline(agentId);
    return runKey;
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
    Set<String> triggerTokens = const <String>{},
    String? workspaceKey,
    String reasonId = _restoredPendingWakeSubscriptionId,
  }) {
    final now = clock.now();
    final runKey = RunKeyFactory.forSubscription(
      agentId: agentId,
      subscriptionId: reasonId,
      batchTokens: triggerTokens,
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
        triggerTokens: triggerTokens,
        reasonId: reasonId,
        workspaceKey: workspaceKey,
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
  ///
  /// Terminal: also closes [runCompletions] (like the throttle coordinator,
  /// the orchestrator is not restartable after [stop]). The close is
  /// fire-and-forget — a broadcast controller's `close()` future only
  /// settles once every active listener's cancellation round-trips, which
  /// callers stopping the orchestrator have no reason to wait on.
  Future<void> stop() async {
    _safetyNetTimer?.cancel();
    _safetyNetTimer = null;
    _throttle.dispose();
    await _notificationSub?.cancel();
    _notificationSub = null;
    unawaited(_runCompletions.close());
  }

  // ── Manual wake enqueue ──────────────────────────────────────────────────

  /// Enqueue a user- or system-initiated wake for [agentId].
  ///
  /// Unlike notification-driven wakes, this bypasses subscription matching and
  /// self-notification suppression.  Used for initial creation wakes and
  /// manual re-analysis triggers. Scheduled work defaults to an automation
  /// initiator so current policy is rechecked at drain time; other callers
  /// default to a user initiator unless they explicitly say otherwise.
  ///
  /// Returns the wake's deterministic run key so callers can correlate the
  /// enqueued job with its [runCompletions] event.
  String enqueueManualWake({
    required String agentId,
    required String reason,
    Set<String> triggerTokens = const {},
    String? workspaceKey,
    bool supersede = true,
    WakeInitiator? initiator,
  }) {
    // Manual wakes bypass and clear the throttle gate so the user's action
    // takes effect immediately.
    clearThrottle(agentId);

    // Remove pending jobs the manual wake supersedes — scoped to its own
    // workspace so a day-A manual wake under one planner does not cancel
    // queued day-B work (ADR 0022). For single-workspace agents the workspace
    // is null and this is the same agent-wide superseding as before.
    //
    // [supersede] = false makes the wake *accumulate* instead: callers whose
    // wakes each carry distinct, non-re-derivable work (e.g. one capture parse
    // per submission) opt out so a second submission in the same workspace
    // cannot drop the first's still-queued parse before it drains.
    if (supersede) {
      const supersededReason = 'wake superseded by a newer manual request';
      final removed = queue.removeByAgent(
        agentId,
        workspaceKey: workspaceKey,
      );
      final owned = _cancelDrainOwnedJobsWhere(
        (job) => job.agentId == agentId && job.workspaceKey == workspaceKey,
        reason: supersededReason,
      );
      _emitRemovedRunCompletions(
        [...removed, ...owned],
        reason: supersededReason,
      );
    }

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
      initiator:
          initiator ??
          (reason == WakeReason.scheduled.name
              ? WakeInitiator.automation
              : WakeInitiator.user),
    );

    queue.enqueue(job);
    unawaited(processNext());
    return runKey;
  }

  /// Removes queued work and emits an aborted completion for every removed
  /// run so in-process waiters cannot hang after an explicit cancellation.
  List<WakeJob> cancelPendingWakes(
    String agentId, {
    String? workspaceKey,
    bool allWorkspaces = false,
  }) {
    const cancellationReason = 'wake cancelled before execution';
    final removed = queue.removeByAgent(
      agentId,
      workspaceKey: workspaceKey,
      allWorkspaces: allWorkspaces,
    );
    final owned = _cancelDrainOwnedJobsWhere(
      (job) =>
          job.agentId == agentId &&
          (allWorkspaces || job.workspaceKey == workspaceKey),
      reason: cancellationReason,
    );
    _emitRemovedRunCompletions(
      [...removed, ...owned],
      reason: cancellationReason,
    );
    return [...removed, ...owned];
  }

  /// Wake [agentId] for externally produced content (e.g. a completed audio
  /// transcription) while honoring the automatic-updates opt-in.
  ///
  /// When automatic updates are enabled this enqueues an immediate wake that
  /// bypasses the subscription throttle, so freshly transcribed content is
  /// processed right away. When the user has switched automatic updates off,
  /// the change only persists the stale watermark — the card surfaces the
  /// manual "Wake agent" CTA and no inference is enqueued.
  ///
  /// The wake carries [WakeInitiator.automation] so a later toggle-off sweeps
  /// it out of the queue along with other automation jobs.
  ///
  /// Returns `true` when a wake was enqueued, `false` when the report was
  /// only marked stale.
  bool requestContentWake({
    required String agentId,
    required String reason,
    Set<String> triggerTokens = const {},
  }) {
    if (_automaticUpdatesDisabledAgents.contains(agentId)) {
      _scheduleReportStale(agentId, clock.now());
      _log(
        'automatic updates disabled — marked report stale instead of waking '
        '${DomainLogger.sanitizeId(agentId)} (reason=$reason)',
        subDomain: 'stale',
      );
      return false;
    }
    enqueueManualWake(
      agentId: agentId,
      reason: reason,
      triggerTokens: triggerTokens,
      initiator: WakeInitiator.automation,
    );
    return true;
  }

  /// Persists a report-stale watermark without queueing a wake.
  ///
  /// Sync-side signal dispatchers use this when high-frequency evidence
  /// arrives after a prior refresh. The write shares the same per-agent
  /// serialization as notification-driven stale/fresh updates.
  Future<void> markReportStale(
    String agentId, {
    DateTime? occurredAt,
  }) => _serializeFreshnessWrite(
    agentId,
    () => _persistReportStale(agentId, occurredAt ?? clock.now()),
  );

  // ── Internal notification handling ─────────────────────────────────────────

  /// Process the next pending job; see [WakeDrainEngine].
  Future<void> processNext() => processNextImpl();

  /// A peer's wake of [agentId] started, ended, lapsed or changed — the
  /// coordinator's [AgentWakeCoordinator.onPeerStateChanged]. A queued wake of
  /// the agent that a peer's completed or running wake covers is dropped now,
  /// its countdown with it, rather than when the countdown runs out; a wake
  /// handed to a peer's run earlier is settled; the drain re-evaluates
  /// everything else as usual.
  void onPeerWakeStateChanged(String agentId) {
    if (queue.hasQueuedJobForAgent(agentId)) _peerCoverageChecks.add(agentId);
    unawaited(settleHandOver(agentId));
    unawaited(processNext());
  }

  /// Abort the in-flight wake for [agentId], if any.
  ///
  /// Used by the user-initiated cancel button on the ongoing wake row.
  /// Returns `true` when an active run was signalled, `false` when the
  /// agent is not currently running.
  bool abortRunningWake(String agentId) => runner.abort(agentId);

  /// Waits for uncancellable executor work after retirement and cancellation.
  ///
  /// Covers every workspace, including executions detached by an earlier abort.
  /// Callers must first prevent new wakes and cancel queued/drain-owned jobs.
  /// Executor failures are already observed by the drain; this is a settlement
  /// barrier, not a second delivery of those failures.
  Future<void> waitForAgentExecutors(String agentId) async {
    await Future.wait(
      _activeExecutors.values
          .where((execution) => execution.agentId == agentId)
          .map((execution) => execution.settled),
    );
  }
}
