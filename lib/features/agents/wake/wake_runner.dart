import 'dart:async';

/// Single-flight execution engine for agent wake runs.
///
/// Ensures that at most one wake executes per agent at a time.  Each
/// in-progress run is represented by a [Completer] stored under the agent's
/// ID; callers that cannot acquire a lock can wait for completion via
/// [waitForCompletion] and re-try.
class WakeRunner {
  final _activeLocks = <String, Completer<void>>{};
  final _runningController = StreamController<Set<String>>.broadcast();

  /// Stream that emits the current set of active agent IDs whenever it changes.
  ///
  /// Emits after every [tryAcquire] and [release] call. Consumers can filter
  /// for a specific agent ID using `.map((ids) => ids.contains(agentId))`.
  Stream<Set<String>> get runningAgentIds => _runningController.stream;

  /// Attempt to acquire the single-flight lock for [agentId].
  ///
  /// Returns `true` and installs the lock when no run is active.  Returns
  /// `false` immediately when the agent is already running.
  Future<bool> tryAcquire(String agentId) async {
    if (_activeLocks.containsKey(agentId)) return false;
    _activeLocks[agentId] = Completer<void>();
    _runningController.add(activeAgentIds);
    return true;
  }

  /// Release the lock for [agentId] and complete any waiters.
  ///
  /// Must be called in a `finally` block after the run finishes (or fails)
  /// to prevent the lock from leaking.
  void release(String agentId) {
    _activeLocks.remove(agentId)?.complete();
    _runningController.add(activeAgentIds);
  }

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

  /// Close the running-state stream controller.
  ///
  /// Call when the runner is no longer needed to prevent resource leaks.
  void dispose() {
    _runningController.close();
  }
}
