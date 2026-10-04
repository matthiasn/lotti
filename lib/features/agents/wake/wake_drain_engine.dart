part of 'wake_orchestrator.dart';

/// Dispatch kernel of [WakeOrchestrator]: queue draining and job
/// execution. The class keeps a thin [WakeOrchestrator.processNext]
/// delegator so mocks still intercept the public API.
extension WakeDrainEngine on WakeOrchestrator {
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
  ///
  /// Fix B: If a drain has made no progress for longer than
  /// [WakeOrchestrator._drainTimeout], force-reset the guard to recover from
  /// a stuck drain while preserving healthy concurrent runner leases.
  Future<void> processNextImpl() async {
    final now = clock.now();
    _releaseStaleSupersededDrainLeases(now);
    if (_isDraining) {
      var oldestProgressAt = _drainLastProgressAt;
      final activeGenerationLeases =
          _drainLeasesByGeneration[_drainGeneration] ?? const {};
      for (final lease in activeGenerationLeases) {
        final progressAt = _drainLeaseProgressAt[lease];
        if (progressAt == null) continue;
        if (oldestProgressAt == null || progressAt.isBefore(oldestProgressAt)) {
          oldestProgressAt = progressAt;
        }
      }
      // Fix B: force-reset stale drain lock after timeout.
      if (oldestProgressAt != null &&
          now.difference(oldestProgressAt) > WakeOrchestrator._drainTimeout) {
        final stalledFor = now.difference(oldestProgressAt);
        _log(
          'force-resetting stale drain lock '
          '(last progress ${stalledFor.inSeconds}s ago)',
          subDomain: 'drain',
        );
        // Increment generation so the old drain's loop bails out, then free
        // only individually stale runner slots. Healthy concurrent executions
        // keep their agent locks until their own futures settle.
        final staleGeneration = _drainGeneration;
        _drainGeneration++;
        _releaseStaleDrainLeases(staleGeneration, now);
        final wakeSignal = _drainWakeSignal;
        if (wakeSignal != null && !wakeSignal.isCompleted) {
          wakeSignal.complete();
        }
        _isDraining = false;
        _drainLastProgressAt = null;
      } else {
        _drainRequested = true;
        final wakeSignal = _drainWakeSignal;
        if (wakeSignal != null && !wakeSignal.isCompleted) {
          wakeSignal.complete();
        }
        return;
      }
    }

    _isDraining = true;
    _drainLastProgressAt = clock.now();
    final myGeneration = _drainGeneration;
    _log(
      'drain started, queue.length=${queue.length}',
      subDomain: 'drain',
    );
    try {
      // Re-enter the drain loop when new work arrived while we were busy.
      do {
        _drainRequested = false;
        await _drain(myGeneration);
        // Bail out if a newer drain superseded us via force-reset.
        if (_drainGeneration != myGeneration) {
          _log('drain superseded, bailing out', subDomain: 'drain');
          return;
        }
      } while (_drainRequested);
    } finally {
      // Only clear the guard if we are still the active drain generation.
      if (_drainGeneration == myGeneration) {
        _isDraining = false;
        _drainLastProgressAt = null;
      }
    }
  }

  void _trackDrainLease(int generation, WakeRunnerLease lease) {
    (_drainLeasesByGeneration[generation] ??= <WakeRunnerLease>{}).add(lease);
    _drainLeaseProgressAt[lease] = clock.now();
  }

  void _releaseDrainLease(int generation, WakeRunnerLease lease) {
    _drainLeaseProgressAt.remove(lease);
    final leases = _drainLeasesByGeneration[generation];
    leases?.remove(lease);
    if (leases != null && leases.isEmpty) {
      _drainLeasesByGeneration.remove(generation);
    }
    runner.releaseLease(lease);
  }

  void _releaseStaleDrainLeases(int generation, DateTime now) {
    final leases = _drainLeasesByGeneration[generation];
    if (leases == null) return;
    final staleLeases = leases
        .where((lease) {
          final progressAt = _drainLeaseProgressAt[lease];
          return progressAt != null &&
              now.difference(progressAt) > WakeOrchestrator._drainTimeout;
        })
        .toList(growable: false);
    for (final lease in staleLeases) {
      _releaseDrainLease(generation, lease);
    }
  }

  void _releaseStaleSupersededDrainLeases(DateTime now) {
    final supersededGenerations = _drainLeasesByGeneration.keys
        .where((generation) => generation != _drainGeneration)
        .toList(growable: false);
    for (final generation in supersededGenerations) {
      _releaseStaleDrainLeases(generation, now);
    }
  }

  void _trackDrainOwnedJob(WakeJob job) {
    _drainOwnedJobs[job.runKey] = job;
  }

  /// Holds [job] back in this pass's [heldBack] list, visible to the
  /// pending-work probes until [_requeueHeldBack] returns it to the queue.
  void _holdBack(List<WakeJob> heldBack, WakeJob job) {
    heldBack.add(job);
    _heldBackJobs[job.runKey] = job;
  }

  void _requeueHeldBack(List<WakeJob> heldBack) {
    for (final job in heldBack) {
      _heldBackJobs.remove(job.runKey);
      queue.requeue(job);
    }
    heldBack.clear();
  }

  void _forgetDrainOwnedJob(WakeJob job) {
    _drainOwnedJobs.remove(job.runKey);
    _cancelledDrainOwnedRunReasons.remove(job.runKey);
  }

  String? _takeDrainOwnedCancellation(WakeJob job) {
    final reason = _cancelledDrainOwnedRunReasons.remove(job.runKey);
    if (reason != null) _drainOwnedJobs.remove(job.runKey);
    return reason;
  }

  bool _discardCancelledDrainOwnedJob(
    int generation,
    WakeJob job, {
    WakeRunnerLease? lease,
  }) {
    if (_takeDrainOwnedCancellation(job) == null) return false;
    _settleIntent(job);
    if (lease != null) _releaseDrainLease(generation, lease);
    if (_drainGeneration != generation) unawaited(processNext());
    return true;
  }

  Future<void> _dropDrainOwnedJob(
    WakeJob job, {
    required String reason,
    required bool emitUnpersistedCompletion,
    required Object error,
  }) async {
    _forgetDrainOwnedJob(job);
    _settleIntent(job);
    if (_persistedWakeRunKeys.remove(job.runKey)) {
      await _abortPersistedWake(
        job,
        reason: reason,
        emitCompletion: true,
        error: error,
      );
    } else if (emitUnpersistedCompletion) {
      _emitRunCompletion(job, WakeRunStatus.aborted, error: error);
    }
  }

  void _handOffSupersededJob(
    int generation,
    WakeJob job, {
    WakeRunnerLease? lease,
  }) {
    if (_discardCancelledDrainOwnedJob(
      generation,
      job,
      lease: lease,
    )) {
      return;
    }
    if (lease != null) _releaseDrainLease(generation, lease);
    _forgetDrainOwnedJob(job);
    queue.requeue(job);
    unawaited(processNext());
  }

  /// Bounded dispatch pass: execute ready jobs up to the configured limit.
  ///
  /// [generation] is the drain generation at the time this pass was started.
  /// If a newer generation supersedes us (via stale-lock recovery), the loop
  /// bails out early to avoid overlapping mutations.
  Future<void> _drain(int generation) async {
    final deferred = <WakeJob>[];
    final activeExecutions = <String, Future<String>>{};
    Completer<void>? ownedWakeSignal;

    try {
      while (true) {
        // Bail out if a newer drain superseded us.
        if (_drainGeneration != generation) return;

        final concurrency = AiRuntimeSettings.normalizeAgentWakeConcurrency(
          maxConcurrentWakes(),
        );
        final jobsToInspect = queue.length;
        var inspectedJobs = 0;

        while (inspectedJobs < jobsToInspect &&
            runner.activeAgentIds.length < concurrency) {
          if (_drainGeneration != generation) return;

          final job = queue.dequeueFirstWhere(
            (candidate) {
              // Single flight: neither a lease holder nor an executor an
              // abort detached from its lease (Dart futures cannot be
              // cancelled) may overlap a new run of the same agent.
              if (runner.isRunning(candidate.agentId) ||
                  _hasLiveExecutor(candidate.agentId)) {
                return false;
              }
              if (candidate.reason != WakeReason.subscription.name) {
                return true;
              }
              final suppressed = _isSuppressed(
                candidate.agentId,
                candidate.triggerTokens,
              );
              final preRegistered = _isPreRegisteredSuppressed(
                candidate.agentId,
                candidate.triggerTokens,
              );
              // The throttle is per-agent but the drain policy is per-job:
              // an immediate-drain job dispatches past a deadline that a
              // deferred job for the SAME agent legitimately armed.
              // A peer's run may cover a job whose countdown still runs:
              // it is checked, and held back again unless covered.
              return suppressed ||
                  preRegistered ||
                  candidate.drainImmediately ||
                  !_isThrottled(candidate.agentId) ||
                  _peerCoverageChecks.contains(candidate.agentId);
            },
          );
          if (job == null) break;
          _trackDrainOwnedJob(job);
          inspectedJobs++;

          final decision = await _currentPolicyDecision(job);
          if (_discardCancelledDrainOwnedJob(generation, job)) {
            if (_drainGeneration != generation) return;
            continue;
          }
          if (_drainGeneration != generation) {
            _handOffSupersededJob(generation, job);
            return;
          }
          if (!decision.allowed) {
            await _dropDrainOwnedJob(
              job,
              reason: 'wake refused: ${decision.cause.name}',
              emitUnpersistedCompletion: true,
              error: WakeRefusedError(decision.cause),
            );
            _auditDecision(job, decision, stage: 'dispatch');
            continue;
          }

          final lease = await runner.tryAcquireLease(
            job.agentId,
            workspaceKey: job.workspaceKey,
          );
          if (_discardCancelledDrainOwnedJob(
            generation,
            job,
            lease: lease,
          )) {
            if (_drainGeneration != generation) return;
            continue;
          }
          if (_drainGeneration != generation) {
            _handOffSupersededJob(generation, job, lease: lease);
            return;
          }
          if (lease == null) {
            // Keep same-agent work queued while its active wake executes. The
            // active wake uses queue visibility to decide whether to arm its
            // existing follow-up throttle deadline.
            _forgetDrainOwnedJob(job);
            _holdBack(deferred, job);
            continue;
          }
          _trackDrainLease(generation, lease);

          // Re-check suppression and throttle for subscription jobs that were
          // enqueued during an agent's execution — before the throttle
          // deadline or recordMutatedEntities was set.
          if (job.reason == WakeReason.subscription.name) {
            // Self-notification: drop the job entirely.
            final suppressed = _isSuppressed(job.agentId, job.triggerTokens);
            final preRegSuppressed = _isPreRegisteredSuppressed(
              job.agentId,
              job.triggerTokens,
            );
            if (suppressed || preRegSuppressed) {
              _log(
                'drain re-check: dropped '
                '(suppressed=$suppressed, preReg=$preRegSuppressed) '
                'for ${DomainLogger.sanitizeId(job.agentId)}',
                subDomain: 'drain',
              );
              const reason = 'wake dropped by suppression re-check';
              await _dropDrainOwnedJob(
                job,
                reason: reason,
                emitUnpersistedCompletion: false,
                error: StateError(reason),
              );
              _releaseDrainLease(generation, lease);
              continue;
            }

            // Throttled: defer the job so the deferred drain timer can pick
            // it up after the throttle window expires. Immediate-drain jobs
            // ignore the agent-level deadline (see the candidate filter).
            if (!job.drainImmediately && _isThrottled(job.agentId)) {
              // A peer completed, or is running, a wake covering this job
              // while its countdown runs: drop it now, and the countdown with
              // it, rather than when the countdown runs out.
              if (_peerCoverageChecks.remove(job.agentId)) {
                final coordinatedAt = clock.now();
                final coordination = await _coordinate(job);
                if (_discardCancelledDrainOwnedJob(
                  generation,
                  job,
                  lease: lease,
                )) {
                  if (_drainGeneration != generation) return;
                  continue;
                }
                if (_drainGeneration != generation) {
                  _handOffSupersededJob(generation, job, lease: lease);
                  return;
                }
                if (coordination is WakeCoordinationCancel) {
                  await _dropCoveredJob(
                    generation,
                    job,
                    lease: lease,
                    coverage: coordination,
                    coordinatedAt: coordinatedAt,
                    deferred: deferred,
                  );
                  continue;
                }
              }
              _log(
                'drain re-check: throttled=true '
                'for ${DomainLogger.sanitizeId(job.agentId)}',
                subDomain: 'drain',
              );
              _forgetDrainOwnedJob(job);
              _releaseDrainLease(generation, lease);
              _holdBack(deferred, job);
              continue;
            }
          }

          // Content-gating: agents auto-assigned from category defaults wait
          // for the task to have meaningful content before their first run.
          final shouldSkipForAwaitingContent =
              await _shouldSkipForAwaitingContent(job);
          if (_discardCancelledDrainOwnedJob(
            generation,
            job,
            lease: lease,
          )) {
            if (_drainGeneration != generation) return;
            continue;
          }
          if (_drainGeneration != generation) {
            _handOffSupersededJob(generation, job, lease: lease);
            return;
          }
          if (shouldSkipForAwaitingContent) {
            const reason = 'wake skipped while awaiting content';
            await _dropDrainOwnedJob(
              job,
              reason: reason,
              emitUnpersistedCompletion: false,
              error: StateError(reason),
            );
            _releaseDrainLease(generation, lease);
            continue;
          }

          // Cross-device coordination (specs/tla/AgentWakeCoordination.tla):
          // a peer that completed a wake reading everything this one would
          // covers the job; a peer running one holds it back until its claim
          // ends or lapses.
          _peerCoverageChecks.remove(job.agentId);
          final coordinatedAt = clock.now();
          final coordination = await _coordinate(job);
          if (_discardCancelledDrainOwnedJob(
            generation,
            job,
            lease: lease,
          )) {
            if (_drainGeneration != generation) return;
            continue;
          }
          if (_drainGeneration != generation) {
            _handOffSupersededJob(generation, job, lease: lease);
            return;
          }
          switch (coordination) {
            case WakeCoordinationCancel():
              await _dropCoveredJob(
                generation,
                job,
                lease: lease,
                coverage: coordination,
                coordinatedAt: coordinatedAt,
                deferred: deferred,
              );
              continue;
            case WakeCoordinationProceed(:final coverage):
              // This run refreshes the report itself.
              _handedToPeer.remove(job.agentId);
              coordinator?.claim(
                agentId: job.agentId,
                runKey: job.runKey,
                coverage: coverage,
              );
          }

          activeExecutions[job.runKey] =
              _executeJob(
                job,
                lease: lease,
                generation: generation,
              ).then(
                (_) => job.runKey,
                onError: (Object error, StackTrace stackTrace) {
                  // `_executeJob` owns its normal error boundary and lock release,
                  // but keep the scheduler resilient if an unexpected failure
                  // escapes that boundary (for example, a logging implementation
                  // throwing before `_executeJob` enters its outer try/finally).
                  _forgetDrainOwnedJob(job);
                  _releaseDrainLease(generation, lease);
                  coordinator?.settle(job.runKey);
                  logError(
                    'unexpected wake execution failure for '
                    '${DomainLogger.sanitizeId(job.runKey)}',
                    error: error,
                    stackTrace: stackTrace,
                  );
                  return job.runKey;
                },
              );
          if (_drainGeneration == generation) {
            _drainLastProgressAt = clock.now();
          }
        }

        // Requeue skipped busy/throttled jobs before waiting. Active wakes use
        // these queued follow-ups to preserve existing throttle semantics.
        _requeueHeldBack(deferred);

        if (activeExecutions.isEmpty) break;

        if (_drainRequested) {
          _drainRequested = false;
          continue;
        }

        final wakeSignal = Completer<void>();
        ownedWakeSignal = wakeSignal;
        _drainWakeSignal = wakeSignal;
        final wakeSentinel = Object();
        final completedRunKey = await Future.any<Object>([
          Future.any(activeExecutions.values),
          wakeSignal.future.then((_) => wakeSentinel),
        ]);
        if (identical(completedRunKey, wakeSentinel)) {
          _drainRequested = false;
          continue;
        }
        final completedExecution = activeExecutions.remove(
          completedRunKey as String,
        );
        if (completedExecution != null) {
          await completedExecution;
          if (_drainGeneration == generation) {
            _drainLastProgressAt = clock.now();
          }
        }
      }
    } finally {
      final wakeSignal = ownedWakeSignal;
      if (wakeSignal != null && identical(_drainWakeSignal, wakeSignal)) {
        _drainWakeSignal = null;
      }

      // Re-enqueue deferred jobs without dedup checks.
      _requeueHeldBack(deferred);

      // A stale generation can supersede this scheduler while several wakes
      // are still active. Keep awaiting those futures so this drain never
      // leaks errors or loses their lock-release finalizers.
      if (activeExecutions.isNotEmpty) {
        await Future.wait(activeExecutions.values);
      }

      // Clear run-key history only when the queue is fully drained (no
      // deferred jobs left). This prevents stale keys from blocking future
      // wakes while avoiding premature clearing that could allow duplicates.
      if (_drainGeneration == generation &&
          queue.isEmpty &&
          _drainOwnedJobs.isEmpty) {
        _log('run-key history cleared (queue empty)', subDomain: 'drain');
        queue.clearHistory();
      }
    }
  }

  /// Drops [job], which a peer's completed or running wake covers.
  ///
  /// A completed run that refreshed its report leaves this device's report
  /// fresh as of [coordinatedAt], when the job's inputs were read. A running
  /// one is trusted to finish — one that fails stays owed on its own device,
  /// and its retry covers this job's inputs — so the agent is remembered as
  /// handed over, and [settleHandOver] marks the report fresh once a covering
  /// `done` arrives. A countdown still running for the agent goes with the
  /// job.
  Future<void> _dropCoveredJob(
    int generation,
    WakeJob job, {
    required WakeRunnerLease lease,
    required WakeCoordinationCancel coverage,
    required DateTime coordinatedAt,
    required List<WakeJob> deferred,
  }) async {
    // Recorded before anything yields, and settled again once the job is
    // gone: the peer's done may already have arrived since [coverage] was
    // decided, and its notification finds a hand-over only once it exists.
    if (!coverage.completed) _handedToPeer.add(job.agentId);
    const reason = 'wake covered by a peer device';
    await _dropDrainOwnedJob(
      job,
      reason: reason,
      emitUnpersistedCompletion: false,
      error: StateError(reason),
    );
    _releaseDrainLease(generation, lease);
    if (!coverage.completed) {
      await settleHandOver(job.agentId);
    } else if (coverage.reportUpdated) {
      await _markReportFresh(job.agentId, refreshStartedAt: coordinatedAt);
    }
    // After the fresh mark: both rewrite the agent state, and neither may
    // write back the other's old value.
    if (_isThrottled(job.agentId) &&
        !queue.hasQueuedJobForAgent(job.agentId) &&
        !deferred.any((held) => held.agentId == job.agentId)) {
      clearThrottle(job.agentId);
    }
    _log(
      'wake dropped: peer ${DomainLogger.sanitizeId(coverage.peerHostId)} '
      '${coverage.completed ? 'completed' : 'is running'} a covering wake of '
      '${DomainLogger.sanitizeId(job.agentId)}',
      subDomain: 'drain',
    );
  }

  /// Settles a wake of [agentId] handed to a peer's running wake: once a
  /// covering `done` is known, the hand-over ends, and the report is fresh if
  /// that run refreshed it. Until then the report stays outdated — also while
  /// a failed run waits for its retry on the peer. A wake this device runs
  /// itself ends the hand-over too (see the drain's dispatch).
  Future<void> settleHandOver(String agentId) async {
    final coordinator = this.coordinator;
    if (coordinator == null || !_handedToPeer.contains(agentId)) return;
    final checkedAt = clock.now();
    final decision = await coordinator.evaluate(agentId);
    if (decision case WakeCoordinationCancel(
      completed: true,
      :final reportUpdated,
    )) {
      _handedToPeer.remove(agentId);
      if (reportUpdated) {
        await _markReportFresh(agentId, refreshStartedAt: checkedAt);
      }
    }
  }

  /// Asks the [WakeOrchestrator.coordinator], if any, whether [job] may run.
  /// A wake the user asked for explicitly is never deferred or cancelled.
  Future<WakeCoordinationDecision> _coordinate(WakeJob job) async {
    final coordinator = this.coordinator;
    if (coordinator == null) return const WakeCoordinationProceed(null);
    return coordinator.evaluate(
      job.agentId,
      deferrable: job.initiator != WakeInitiator.user,
    );
  }
}
