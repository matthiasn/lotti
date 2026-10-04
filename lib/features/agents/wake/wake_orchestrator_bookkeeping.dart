part of 'wake_orchestrator.dart';

/// The orchestrator's bookkeeping: wake intents, executor tracking, run-completion events, throttle deadlines, audit logging and the safety-net timer.
extension _WakeOrchestratorBookkeeping on WakeOrchestrator {
  void _recordIntent(WakeJob job) {
    if (WakeOrchestrator._ownsItsRecovery(job.triggerTokens)) {
      _settleIntent(job);
      return;
    }
    intentStore?.record(
      runKey: job.runKey,
      agentId: job.agentId,
      workspaceKey: job.workspaceKey,
      reason: job.reason,
      initiator: job.initiator,
      tokens: job.triggerTokens,
    );
  }

  /// Settles [job]'s wake intent: its run settled, or the job was dropped
  /// for good.
  void _settleIntent(WakeJob job) => intentStore?.settle(job.runKey);

  /// Whether an executor of [agentId] still blocks a new run of it: any
  /// executor still running — including one an abort, the run timeout or a
  /// stuck-drain reset detached from its lease — until it has run for
  /// [WakeOrchestrator.hungExecutorAfter]. A future that never settles would otherwise wedge
  /// its agent until the next launch; past that point it is reported as hung
  /// and stops blocking (`specs/tla/WakeRuntime.tla`, `DeclareHung`).
  bool _hasLiveExecutor(String agentId) {
    final now = clock.now();
    var blocking = false;
    for (final entry in _activeExecutors.entries) {
      final execution = entry.value;
      if (execution.agentId != agentId) continue;
      if (now.difference(execution.startedAt) <
          WakeOrchestrator.hungExecutorAfter) {
        blocking = true;
      } else if (_reportedHungExecutors.add(entry.key)) {
        logError(
          'wake executor still running after '
          '${WakeOrchestrator.hungExecutorAfter.inMinutes} min; no longer blocking '
          '${DomainLogger.sanitizeId(agentId)}',
          error: StateError('hung wake executor'),
          stackTrace: StackTrace.current,
        );
      }
    }
    return blocking;
  }

  void _trackExecutor(WakeJob job, Future<Map<String, VectorClock>?> future) {
    final settled = Completer<void>();
    _activeExecutors[job.runKey] = (
      agentId: job.agentId,
      workspaceKey: job.workspaceKey,
      triggerTokens: job.triggerTokens,
      settled: settled.future,
      startedAt: clock.now(),
    );
    void complete() {
      _activeExecutors.remove(job.runKey);
      _reportedHungExecutors.remove(job.runKey);
      settled.complete();
      _settleIntent(job);
      // A job held back because this executor was still live can run now.
      if (queue.hasQueuedJobForAgent(job.agentId)) unawaited(processNext());
    }

    unawaited(
      future.then(
        (_) => complete(),
        onError: (Object _, StackTrace _) {
          complete();
        },
      ),
    );
  }

  void _emitRunCompletion(
    WakeJob job,
    WakeRunStatus status, {
    Object? error,
    DateTime? startedAt,
    bool? reportUpdated,
  }) {
    _budgetClaimedRunKeys.remove(job.runKey);
    if (_runCompletions.isClosed) return;
    _runCompletions.add(
      WakeRunCompletion(
        runKey: job.runKey,
        agentId: job.agentId,
        reason: job.reason,
        triggerTokens: job.triggerTokens,
        finishedAt: clock.now(),
        startedAt: startedAt,
        reportUpdated: reportUpdated,
        status: status,
        error: error,
      ),
    );
  }

  List<WakeJob> _cancelDrainOwnedJobsWhere(
    bool Function(WakeJob job) predicate, {
    required String reason,
  }) {
    final cancelled = <WakeJob>[];
    for (final job in _drainOwnedJobs.values) {
      if (!predicate(job) ||
          _cancelledDrainOwnedRunReasons.containsKey(job.runKey)) {
        continue;
      }
      _cancelledDrainOwnedRunReasons[job.runKey] = reason;
      cancelled.add(job);
    }
    return cancelled;
  }

  void _emitRemovedRunCompletions(
    Iterable<WakeJob> jobs, {
    required String reason,
  }) {
    for (final job in jobs) {
      // Cancelled or superseded on purpose: the next launch must not bring
      // it back.
      _settleIntent(job);
      if (_persistedWakeRunKeys.remove(job.runKey)) {
        unawaited(
          _safeUpdateStatus(
            job.runKey,
            WakeRunStatus.aborted.name,
            completedAt: clock.now(),
            errorMessage: reason,
          ).then(
            (_) => _emitRunCompletion(
              job,
              WakeRunStatus.aborted,
              error: StateError(reason),
            ),
          ),
        );
        continue;
      }
      _emitRunCompletion(
        job,
        WakeRunStatus.aborted,
        error: StateError(reason),
      );
    }
  }

  /// Update wake run status without letting persistence failures escape the
  /// orchestrator's execution or cancellation paths.
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
    } catch (error, stackTrace) {
      logError(
        'failed to update wake run status '
        'for ${DomainLogger.sanitizeId(runKey)} to $status',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Serialize stale and fresh watermark mutations per agent.
  ///
  /// Stale notifications can land while a wake is completing. Keeping both
  /// mutations on one chain prevents a fresh write based on an older state
  /// snapshot from overwriting a newer stale watermark.
  Future<void> _serializeFreshnessWrite(
    String agentId,
    Future<void> Function() write,
  ) {
    final previous = _freshnessWriteChains[agentId] ?? Future<void>.value();
    late final Future<void> current;
    current = previous.then((_) => write()).whenComplete(() {
      if (identical(_freshnessWriteChains[agentId], current)) {
        _freshnessWriteChains.remove(agentId);
      }
    });
    _freshnessWriteChains[agentId] = current;
    return current;
  }

  void _log(String message, {String? subDomain}) {
    domainLogger?.log(LogDomain.agentRuntime, message, subDomain: subDomain);
  }

  /// Every job enters the queue through here, whatever asked for it — a
  /// subscription match, a scheduled or restored wake, a content wake, the
  /// user — so this one line records the source of every wake that follows.
  void _auditQueued(WakeJob job) {
    _log(
      formatWakeAudit(
        stage: 'enqueue',
        agentId: job.agentId,
        cause: WakeDecisionCause.allowed,
        reason: job.reason,
        initiator: job.initiator,
        reasonId: job.reasonId,
        tokenCount: job.triggerTokens.length,
      ),
      subDomain: 'wakeAudit',
    );
  }

  /// Records a wake the router declined to queue, and why.
  void _auditRouted(
    AgentSubscription sub,
    Set<String> matched,
    WakeDecisionCause cause,
  ) {
    _log(
      formatWakeAudit(
        stage: 'route',
        agentId: sub.agentId,
        cause: cause,
        reason: WakeReason.subscription.name,
        initiator: WakeInitiator.automation,
        reasonId: sub.id,
        tokenCount: matched.length,
      ),
      subDomain: 'wakeAudit',
    );
  }

  void _cancelPendingAutomaticWakes(
    String agentId, {
    required String reason,
  }) {
    clearThrottle(agentId);
    final removed = queue.removeByAgentWhere(
      agentId,
      (job) => job.initiator == WakeInitiator.automation,
    );
    final owned = _cancelDrainOwnedJobsWhere(
      (job) =>
          job.agentId == agentId && job.initiator == WakeInitiator.automation,
      reason: reason,
    );
    _emitRemovedRunCompletions(
      [...removed, ...owned],
      reason: reason,
    );
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

  /// Starts a periodic safety-net timer that ensures the queue is eventually
  /// drained even if a deferred drain timer fails to fire.
  ///
  /// Triggers [processNext] for due/immediate jobs, or an active drain.
  /// A future-only idle queue waits for its deadline. Re-entering
  /// an active drain is intentional: it either wakes the healthy scheduler or
  /// force-resets one whose last progress exceeded [_drainTimeout]. We do not
  /// check `_deferredDrainTimers.isEmpty` because a stale or cancelled timer
  /// entry lingering in the map would permanently disable the safety net.
  void _startSafetyNet() {
    _safetyNetTimer?.cancel();
    _safetyNetTimer = Timer.periodic(WakeOrchestrator.safetyNetInterval, (_) {
      // Active drains always retain watchdog recovery. An idle queue whose
      // only work is deferred has its own deadline timers; the safety net
      // resumes attempts when the wall-clock deadline is due, even if one of
      // those timers was lost.
      final needsDrain =
          _isDraining ||
          queue.hasJobWhere(
            (job) =>
                job.reason != WakeReason.subscription.name ||
                job.drainImmediately ||
                !_isThrottled(job.agentId),
          );
      if (!queue.isEmpty && needsDrain) {
        _log('safety-net drain: queue=${queue.length}');
        unawaited(processNext());
      }
    });
  }

  /// Implementation of [WakeOrchestrator.restoreWakeIntents].
  Future<int> _restoreWakeIntents() async {
    final store = intentStore;
    if (store == null) return 0;
    await store.load();
    final intents = <WakeIntent>[];
    for (final intent in store.takeRestorable()) {
      if (WakeOrchestrator._ownsItsRecovery(intent.tokens)) {
        store.settle(intent.runKey);
      } else {
        intents.add(intent);
      }
    }
    // One job per agent and workspace: two manual wakes enqueued in the same
    // tick would share a run key, and the queue would drop the second.
    final groups = <(String, String?), List<WakeIntent>>{};
    for (final intent in intents) {
      (groups[(intent.agentId, intent.workspaceKey)] ??= []).add(intent);
    }
    for (final MapEntry(key: (agentId, workspaceKey), value: group)
        in groups.entries) {
      final tokens = {for (final intent in group) ...intent.tokens};
      // A user's wake must not become automation that disabling automatic
      // updates would drop — neither as a new job nor by merging into a
      // queued automation job, such as one restorePendingWake rebuilt.
      final initiator =
          group.any((intent) => intent.initiator == WakeInitiator.user)
          ? WakeInitiator.user
          : WakeInitiator.automation;
      final queued = queue.queuedJobFor(agentId, workspaceKey: workspaceKey);
      final String runKey;
      if (queued != null &&
          !WakeOrchestrator._ownsItsRecovery(queued.triggerTokens) &&
          (initiator == WakeInitiator.automation ||
              queued.initiator == WakeInitiator.user)) {
        queue.mergeTokens(agentId, tokens, workspaceKey: workspaceKey);
        runKey = queued.runKey;
      } else {
        runKey = enqueueManualWake(
          agentId: agentId,
          reason: group.first.reason,
          triggerTokens: tokens,
          workspaceKey: workspaceKey,
          supersede: false,
          initiator: initiator,
        );
      }
      for (final intent in group) {
        store.adopt(intent, runKey: runKey);
      }
    }
    if (intents.isNotEmpty) {
      _log(
        'restored ${intents.length} unsettled wake intent(s)',
        subDomain: 'intents',
      );
    }
    return intents.length;
  }
}
