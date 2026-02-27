/// A single pending wake request for an agent.
class WakeJob {
  WakeJob({
    required this.runKey,
    required this.agentId,
    required this.reason,
    required Set<String> triggerTokens,
    required this.createdAt,
    this.reasonId,
  }) : triggerTokens = Set<String>.of(triggerTokens);

  /// Deterministic key derived by `RunKeyFactory`; used for deduplication.
  final String runKey;

  /// The agent that should be woken.
  final String agentId;

  /// Wake trigger category: currently `'subscription'`, `'creation'`,
  /// or `'reanalysis'`.
  final String reason;

  /// The DB-notification tokens that triggered this wake.
  ///
  /// This is a defensive copy of the set passed to the constructor.
  /// [WakeQueue.mergeTokens] may mutate it to coalesce rapid-fire
  /// notifications.
  final Set<String> triggerTokens;

  /// Optional identifier for the subscription that fired.
  final String? reasonId;

  /// Wall-clock time the job was created (not persisted; in-memory only).
  final DateTime createdAt;
}

/// In-memory FIFO queue with run-key deduplication.
///
/// The [_seenRunKeys] set prevents the same logical wake from being enqueued
/// twice even when multiple notification batches arrive in quick succession.
/// Call [clearHistory] periodically (e.g., after each orchestrator cycle) to
/// prevent unbounded growth.
class WakeQueue {
  final _queue = <WakeJob>[];
  final _seenRunKeys = <String>{};

  /// Enqueue a wake job.
  ///
  /// Returns `false` and discards the job if its [WakeJob.runKey] has already
  /// been seen; returns `true` when the job was added.
  bool enqueue(WakeJob job) {
    if (_seenRunKeys.contains(job.runKey)) return false;
    _seenRunKeys.add(job.runKey);
    _queue.add(job);
    return true;
  }

  /// Remove and return the next job (FIFO).
  ///
  /// Returns `null` when the queue is empty.
  WakeJob? dequeue() {
    if (_queue.isEmpty) return null;
    return _queue.removeAt(0);
  }

  /// Merge [tokens] into the `triggerTokens` of the first queued job whose
  /// `agentId` matches [agentId].
  ///
  /// Returns `true` when a matching job was found and updated, `false`
  /// otherwise.
  bool mergeTokens(String agentId, Set<String> tokens) {
    for (final job in _queue) {
      if (job.agentId == agentId) {
        job.triggerTokens.addAll(tokens);
        return true;
      }
    }
    return false;
  }

  /// Remove all queued jobs for [agentId] and return them.
  ///
  /// Used when a manual wake supersedes pending subscription wakes — the
  /// manual run replaces any queued work for the same agent.
  List<WakeJob> removeByAgent(String agentId) {
    final removed = <WakeJob>[];
    _queue.removeWhere((job) {
      if (job.agentId == agentId) {
        removed.add(job);
        return true;
      }
      return false;
    });
    return removed;
  }

  /// Re-enqueue a previously dequeued job without deduplication.
  ///
  /// Used by the orchestrator to put back jobs whose agent is currently busy.
  /// The run key remains in [_seenRunKeys] so that external duplicates are
  /// still rejected.
  void requeue(WakeJob job) => _queue.add(job);

  /// Whether the queue has no pending jobs.
  bool get isEmpty => _queue.isEmpty;

  /// Number of pending jobs.
  int get length => _queue.length;

  /// Clear the seen-run-keys history.
  ///
  /// Call periodically (e.g., after an orchestrator cycle completes) to prevent
  /// unbounded memory growth.  Note that clearing history allows previously
  /// seen run keys to be enqueued again; only call this when you are confident
  /// the corresponding runs have been committed to the DB.
  ///
  /// Must only be called when the queue is empty — clearing while jobs are
  /// pending would break deduplication for their run keys.
  void clearHistory() {
    assert(
      _queue.isEmpty,
      'clearHistory() called with ${_queue.length} pending jobs — '
      'this breaks run-key deduplication',
    );
    _seenRunKeys.clear();
  }
}
