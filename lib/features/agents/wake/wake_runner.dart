import 'dart:async';

/// Single-flight execution engine for agent wake runs.
///
/// Ensures that at most one wake executes per agent at a time.  Each
/// in-progress run is represented by a [Completer] stored under the agent's
/// ID; callers that cannot acquire a lock can wait for completion via
/// [waitForCompletion] and re-try.
class WakeRunner {
  final _activeLocks = <String, Completer<void>>{};

  /// Attempt to acquire the single-flight lock for [agentId].
  ///
  /// Returns `true` and installs the lock when no run is active.  Returns
  /// `false` immediately when the agent is already running.
  Future<bool> tryAcquire(String agentId) async {
    if (_activeLocks.containsKey(agentId)) return false;
    _activeLocks[agentId] = Completer<void>();
    return true;
  }

  /// Release the lock for [agentId] and complete any waiters.
  ///
  /// Must be called in a `finally` block after the run finishes (or fails)
  /// to prevent the lock from leaking.
  void release(String agentId) {
    _activeLocks.remove(agentId)?.complete();
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
}
