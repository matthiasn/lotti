import 'dart:async';
import 'dart:collection';

import 'package:clock/clock.dart';

/// Ownership token for one [WakeRunner] acquisition.
///
/// Lease-aware release and abort operations ignore tokens that no longer own
/// the agent lock. This prevents a superseded wake from affecting a newer run
/// for the same agent when its asynchronous cleanup resumes late.
class WakeRunnerLease {
  const WakeRunnerLease._({
    required this.agentId,
    required this._id,
    required this.abortFuture,
  });

  /// Agent whose single-flight lock this lease owns.
  final String agentId;

  final int _id;

  /// Completes when this specific run is aborted or released.
  final Future<void> abortFuture;
}

/// Single-flight execution engine for agent wake runs.
///
/// Ensures that at most one wake executes per agent at a time.  Each
/// in-progress run is represented by a [Completer] stored under the agent's
/// ID, while the orchestrator observes [abortFuture] to coordinate shutdown.
class WakeRunner {
  final _activeLocks = <String, Completer<void>>{};
  final _activeStartedAt = <String, DateTime>{};
  final _activeWorkspaceKey = <String, String?>{};
  final _abortSignals = <String, Completer<void>>{};
  final _activeLeaseIds = <String, int>{};
  var _nextLeaseId = 0;
  late final UnmodifiableMapView<String, DateTime> _activeStartedAtView =
      UnmodifiableMapView(_activeStartedAt);
  final _runningController = StreamController<Set<String>>.broadcast();

  /// Stream that emits the current set of active agent IDs whenever it changes.
  ///
  /// Consumers can filter for a specific agent ID using
  /// `.map((ids) => ids.contains(agentId))`.
  Stream<Set<String>> get runningAgentIds => _runningController.stream;

  /// Attempt to acquire the single-flight lock for [agentId].
  ///
  /// Returns `true` and installs the lock when no run is active.  Returns
  /// `false` immediately when the agent is already running. [workspaceKey]
  /// records which workspace this run is executing in (e.g. `day:<dayId>`
  /// for the Daily OS coordinator, ADR 0022) so callers can scope
  /// "is this agent running" checks to a specific workspace via
  /// [workspaceKeyFor] instead of treating any run of a shared agent as
  /// relevant to every workspace it might touch.
  Future<bool> tryAcquire(String agentId, {String? workspaceKey}) async {
    return (await tryAcquireLease(agentId, workspaceKey: workspaceKey)) != null;
  }

  /// Attempt to acquire [agentId] and return its ownership token.
  ///
  /// Unlike [tryAcquire], the returned lease lets asynchronous owners release
  /// or abort only the run they acquired, even after stale recovery has
  /// installed a replacement run for the same agent.
  Future<WakeRunnerLease?> tryAcquireLease(
    String agentId, {
    String? workspaceKey,
  }) async {
    if (_activeLocks.containsKey(agentId)) return null;
    _activeLocks[agentId] = Completer<void>();
    final abortSignal = Completer<void>();
    _abortSignals[agentId] = abortSignal;
    final leaseId = _nextLeaseId++;
    _activeLeaseIds[agentId] = leaseId;
    _activeStartedAt[agentId] = clock.now();
    _activeWorkspaceKey[agentId] = workspaceKey;
    _runningController.add(activeAgentIds);
    return WakeRunnerLease._(
      agentId: agentId,
      id: leaseId,
      abortFuture: abortSignal.future,
    );
  }

  /// Release the lock for [agentId] and complete any waiters.
  ///
  /// Must be called in a `finally` block after the run finishes (or fails)
  /// to prevent the lock from leaking.
  void release(String agentId) {
    final lock = _activeLocks.remove(agentId);
    if (lock == null) return;

    lock.complete();
    _activeStartedAt.remove(agentId);
    _activeWorkspaceKey.remove(agentId);
    _activeLeaseIds.remove(agentId);
    final abort = _abortSignals.remove(agentId);
    if (abort != null && !abort.isCompleted) abort.complete();
    _runningController.add(activeAgentIds);
  }

  /// Release [lease] only while it still owns its agent lock.
  void releaseLease(WakeRunnerLease lease) {
    if (_activeLeaseIds[lease.agentId] != lease._id) return;
    release(lease.agentId);
  }

  /// Signal an abort for the in-flight run for [agentId].
  ///
  /// Returns `true` when an active run was signalled, `false` when the agent
  /// is not currently running (or was already aborted). The actual lock is
  /// released by the orchestrator after it observes the abort signal and
  /// finalises the wake-run status.
  bool abort(String agentId) {
    final abort = _abortSignals[agentId];
    if (abort == null || abort.isCompleted) return false;
    abort.complete();
    return true;
  }

  /// Abort [lease] only while it still owns its agent lock.
  bool abortLease(WakeRunnerLease lease) {
    if (_activeLeaseIds[lease.agentId] != lease._id) return false;
    return abort(lease.agentId);
  }

  /// Future that completes when [agentId]'s in-flight run ends — either
  /// because [abort] was signalled or because [release] finalised the run
  /// without an abort. Both paths complete the same completer so a caller
  /// awaiting this future never deadlocks on a quiet release.
  ///
  /// Consumers that need to distinguish the two outcomes (e.g. the
  /// orchestrator deciding whether to mark the run `aborted` vs
  /// `completed`) must use a separate signal — the orchestrator races this
  /// against the executor future and tags the abort branch with a sentinel
  /// so a normal release-on-success doesn't misclassify the run.
  ///
  /// Returns `null` when the agent is not currently running.
  Future<void>? abortFuture(String agentId) => _abortSignals[agentId]?.future;

  /// Whether [agentId] has an active wake run.
  bool isRunning(String agentId) => _activeLocks.containsKey(agentId);

  /// Snapshot of the IDs of all agents that are currently running.
  Set<String> get activeAgentIds => Set.unmodifiable(_activeLocks.keys.toSet());

  /// The workspace key passed to [tryAcquire] for [agentId]'s currently
  /// active run, or `null` when [agentId] is not running (or is running
  /// without a workspace key). Callers that need to distinguish those two
  /// cases must check [isRunning] first.
  String? workspaceKeyFor(String agentId) => _activeWorkspaceKey[agentId];

  /// Live read-only view of agent IDs to their wake start timestamps.
  /// Reflects subsequent acquire/release calls without allocating —
  /// callers that need a frozen snapshot should copy the result.
  Map<String, DateTime> get activeStartedAtById => _activeStartedAtView;

  /// Close the running-state stream controller.
  ///
  /// Call when the runner is no longer needed to prevent resource leaks.
  void dispose() {
    _runningController.close();
  }
}
