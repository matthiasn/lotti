import 'dart:async';
import 'dart:collection';

import 'package:clock/clock.dart';

/// Single-flight execution engine for agent wake runs.
///
/// Ensures that at most one wake executes per agent at a time.  Each
/// in-progress run is represented by a [Completer] stored under the agent's
/// ID; callers that cannot acquire a lock can wait for completion via
/// [waitForCompletion] and re-try.
class WakeRunner {
  final _activeLocks = <String, Completer<void>>{};
  final _activeStartedAt = <String, DateTime>{};
  final _abortSignals = <String, Completer<void>>{};
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
  /// `false` immediately when the agent is already running.
  Future<bool> tryAcquire(String agentId) async {
    if (_activeLocks.containsKey(agentId)) return false;
    _activeLocks[agentId] = Completer<void>();
    _abortSignals[agentId] = Completer<void>();
    _activeStartedAt[agentId] = clock.now();
    _runningController.add(activeAgentIds);
    return true;
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
    final abort = _abortSignals.remove(agentId);
    if (abort != null && !abort.isCompleted) abort.complete();
    _runningController.add(activeAgentIds);
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

  /// Suspend until the currently active run for [agentId] finishes.
  ///
  /// Returns immediately when no run is active.
  Future<void> waitForCompletion(String agentId) async {
    final completer = _activeLocks[agentId];
    if (completer != null) await completer.future;
  }

  /// Whether [agentId] has an active wake run.
  bool isRunning(String agentId) => _activeLocks.containsKey(agentId);

  /// Snapshot of the IDs of all agents that are currently running.
  Set<String> get activeAgentIds => Set.unmodifiable(_activeLocks.keys.toSet());

  /// When did the currently-active wake for [agentId] start? Returns
  /// `null` when [agentId] is not running. The wall-clock used here is
  /// `clock.now()`, so tests that override `clock` see deterministic
  /// values.
  DateTime? startedAt(String agentId) => _activeStartedAt[agentId];

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
