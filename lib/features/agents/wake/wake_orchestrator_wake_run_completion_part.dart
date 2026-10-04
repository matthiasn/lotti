part of 'wake_orchestrator.dart';

/// A registered interest that wakes [agentId] when tokens arrive matching
/// [matchEntityIds].
class AgentSubscription {
  AgentSubscription({
    required this.id,
    required this.agentId,
    required this.matchEntityIds,
    this.predicate,
    this.deferPropagatedMatches = true,
    this.drainImmediately = false,
    this.reportStaleOnly = false,
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

  /// Whether matches dispatch immediately instead of defer-first behind the
  /// 120-second coalescing window.
  ///
  /// The window exists for wakes that cost real inference money on evidence
  /// that arrives in incomplete bursts (a task being edited). Goal-agent
  /// signal subscriptions set this: their evidence is atomic (a habit
  /// check-off IS the complete fact) and the triggered work is the
  /// deterministic €0 Phase A tier, so deferral protects nothing and delays
  /// the user-visible acknowledgment of their own action by two minutes.
  /// Bursts stay safe without the window — the runner single-flights per
  /// agent and queued jobs merge tokens, so N rapid check-offs collapse into
  /// at most one follow-up run.
  final bool drainImmediately;

  /// Whether matching evidence should only mark the persisted report stale.
  ///
  /// This keeps high-frequency observational signals visible to the user
  /// without turning every mutation into agent work. The agent's scheduled
  /// cadence or an explicit manual refresh consumes the accumulated changes.
  final bool reportStaleOnly;
}

/// Checks whether a content-gated entity (by ID) has the content the agent is
/// waiting for before its first run — a task with text, or an event with a
/// linked photo/note. Used by the content-gating logic for agents auto-created
/// from category defaults.
typedef AgentContentChecker = Future<bool> Function(String entityId);

/// Sync-aware entity writer that stamps the vector clock and enqueues
/// an outbox message. Used when the orchestrator needs to persist a
/// state mutation that must propagate to other devices.
typedef SyncEntityWriter = Future<void> Function(AgentDomainEntity entity);

/// Transactional, sync-aware agent-state transformer.
///
/// The callback receives the latest persisted state inside the write
/// transaction, preventing independent state writers from overwriting fields
/// they did not own.
typedef SyncAgentStateUpdater =
    Future<bool> Function(
      String agentId,
      FutureOr<AgentStateEntity?> Function(AgentStateEntity current) update,
    );

/// Optional hook run **once per wake, just before the executor**. Used by fork
/// healing (ADR 0018 rule 8): collapse a surviving multi-head `messagePrev` fork
/// into one continuation node before the wake acts, so context and the
/// on-device prefix stay bounded. Best-effort — a failure is logged and the wake
/// proceeds (healing is an optimization, never a correctness mechanism).
typedef WakeStartHook =
    Future<void> Function(String agentId, String runKey, String threadId);

/// Resolves a task agent's wake cadence from its own `override` and its
/// `categoryId`.
typedef TaskWakeCadenceResolver =
    AgentWakeCadence Function({
      required AgentWakeCadence? override,
      required String? categoryId,
    });

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

/// Backward-compatible executor payload with report-refresh metadata.
///
/// The suppression contract historically returned only mutated entity clocks.
/// Keeping this as a map preserves that contract while allowing owning agent
/// features to say that a successful maintenance wake did not replace their
/// standing report.
class WakeExecutorResult extends UnmodifiableMapView<String, VectorClock> {
  WakeExecutorResult(
    super.map, {
    required this.reportUpdated,
  });

  final bool reportUpdated;
}

/// Returns the current global limit for simultaneously executing wake cycles.
typedef MaxConcurrentWakes = int Function();

/// Terminal outcome of one wake run, emitted on
/// [WakeOrchestrator.runCompletions].
///
/// In-process only (never persisted): precise completion signal for callers
/// that enqueued a wake and need to react to its outcome without polling —
/// e.g. the durable day-processing job executor (ADR 0032 phase 1). The
/// durable record of the same outcome is the `wake_run_log` row keyed by
/// [runKey].
class WakeRunCompletion {
  const WakeRunCompletion({
    required this.runKey,
    required this.status,
    this.agentId,
    this.reason,
    this.triggerTokens = const {},
    this.finishedAt,
    this.startedAt,
    this.reportUpdated,
    this.error,
  });

  /// Deterministic run key of the finished wake (matches the value returned
  /// by [WakeOrchestrator.enqueueManualWake]).
  final String runKey;

  /// The agent the finished wake belonged to. Run keys are opaque hashes, so
  /// agent-scoped listeners (e.g. a card surfacing the last update failure)
  /// need the id carried on the event itself. Always set by the
  /// orchestrator; nullable only for hand-built fixtures.
  final String? agentId;

  /// The wake's reason (see [WakeReason]) as enqueued. Always set by the
  /// orchestrator; nullable only for hand-built fixtures.
  final String? reason;

  /// The job's trigger tokens, so listeners can scope outcomes to a wake
  /// PURPOSE — a goal's report-refresh runs versus its chat runs — without
  /// guessing from the reason string.
  final Set<String> triggerTokens;

  /// When the run reached its terminal status. Always set by the
  /// orchestrator; nullable only for fixtures.
  final DateTime? finishedAt;

  /// When the executor actually started running, for terminal statuses that
  /// had one. Freshness watermarks record a REFRESH START time
  /// (`reportFreshAt` = the successful run's start), so a listener
  /// reconciling an in-process failure against durable state that synced in
  /// later must compare start-to-start — a remote success that began after
  /// this run began supersedes it, even when its watermark predates this
  /// run's finish.
  final DateTime? startedAt;

  /// Whether the wake actually advanced the agent's standing report, when
  /// the executor said (goal wakes report it via `WakeExecutorResult`).
  /// Null when unknown — treat as "assume yes" for compatibility. A
  /// completed report wake that did NOT update the report (e.g. inference
  /// finished without publishing) must not clear a surfaced failure whose
  /// staleness is still true.
  final bool? reportUpdated;

  /// Whether this outcome is a decision an agent-scoped surface should act
  /// on. Completed and failed runs decide; of the aborted runs only the
  /// executor TIMEOUT does — a superseded or cancelled wake is bookkeeping
  /// for a run that was replaced, and must neither surface as an error nor
  /// clear one that is showing.
  bool get isDecisive => switch (status) {
    WakeRunStatus.completed || WakeRunStatus.failed => true,
    _ =>
      error is TimeoutException &&
          (error! as TimeoutException).message == 'timeout',
  };

  /// Terminal status: [WakeRunStatus.completed], [WakeRunStatus.failed], or
  /// [WakeRunStatus.aborted].
  final WakeRunStatus status;

  /// The error object for failed runs, when one was caught. Carried so
  /// listeners can classify the failure without re-parsing log strings.
  final Object? error;
}

int _defaultMaxConcurrentWakes() => defaultAgentWakeConcurrency;

/// The budget key of claims made before this device's host id is known.
const _unknownBudgetHost = 'unknown-host';
