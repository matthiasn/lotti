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
    Object? error,
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
      _emitRunCompletion(
        job,
        WakeRunStatus.aborted,
        error: error ?? StateError(reason),
      );
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
              await _dropDrainOwnedJob(
                job,
                reason: 'wake dropped by suppression re-check',
                emitUnpersistedCompletion: false,
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
            await _dropDrainOwnedJob(
              job,
              reason: 'wake skipped while awaiting content',
              emitUnpersistedCompletion: false,
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
    await _dropDrainOwnedJob(
      job,
      reason: 'wake covered by a peer device',
      emitUnpersistedCompletion: false,
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

  /// The current policy's decision on [job], with the cause of a refusal.
  ///
  /// Identity policy first: lifecycle, disabled inference and the automatic
  /// updates preference. A policy that cannot be read fails closed for
  /// automatic work — an unreadable row must not become a licence to bill —
  /// and open for an explicit request, which the user is watching.
  ///
  /// Project agents then answer to their daily wake budget. With
  /// [claimBudget] false this only reads the ledger (the pre-dispatch check);
  /// with it true the read, the verdict and the increment run in one state
  /// transaction (the pre-executor check), and a run key claims at most once,
  /// so a superseded drain handing the run back cannot count it twice.
  Future<WakePolicyDecision> _currentPolicyDecision(
    WakeJob job, {
    bool claimBudget = false,
  }) async {
    late final AgentDomainEntity? entity;
    try {
      entity = await repository.getEntity(job.agentId);
    } catch (error, stackTrace) {
      logError(
        'failed to load agent policy for '
        '${DomainLogger.sanitizeId(job.agentId)}',
        error: error,
        stackTrace: stackTrace,
      );
      return job.initiator == WakeInitiator.user
          ? WakePolicyDecision.allowedUnbudgeted
          : const WakePolicyDecision(WakeDecisionCause.policyUnreadable);
    }
    if (entity is! AgentIdentityEntity) {
      return WakePolicyDecision.allowedUnbudgeted;
    }
    final identityCause = _identityPolicyCause(entity, job.initiator);
    if (identityCause != null) return WakePolicyDecision(identityCause);
    if (entity.kind != AgentKinds.projectAgent) {
      return WakePolicyDecision.allowedUnbudgeted;
    }
    final maxPerDay = effectiveMaxWakesPerDay(entity.config);
    if (claimBudget) return _claimWakeBudget(job, maxPerDay);
    try {
      final state = await repository.getAgentState(job.agentId);
      final used = state == null
          ? 0
          : wakesUsedOn(state.dailyWakes, wakeBudgetDay(clock.now()));
      return WakePolicyDecision.fromBudget(
        evaluateWakeBudget(
          used: used,
          maxPerDay: maxPerDay,
          initiator: job.initiator,
        ),
        used: used,
        max: maxPerDay,
      );
    } catch (error, stackTrace) {
      // The claim before the executor decides for real; a failed read here
      // only defers that decision.
      logError(
        'failed to read wake budget for '
        '${DomainLogger.sanitizeId(job.agentId)}',
        error: error,
        stackTrace: stackTrace,
      );
      return WakePolicyDecision.allowedUnbudgeted;
    }
  }

  WakeDecisionCause? _identityPolicyCause(
    AgentIdentityEntity identity,
    WakeInitiator initiator,
  ) {
    final bool allowed;
    if (identity.kind == AgentKinds.projectAgent) {
      allowed = projectAgentWakeAllowed(
        config: identity.config,
        lifecycle: identity.lifecycle,
        initiator: initiator,
      );
    } else if (identity.kind == AgentKinds.taskAgent) {
      allowed = taskAgentWakeAllowed(
        config: identity.config,
        lifecycle: identity.lifecycle,
        initiator: initiator,
      );
    } else {
      allowed = identity.lifecycle == AgentLifecycle.active;
    }
    if (allowed) return null;
    if (identity.lifecycle != AgentLifecycle.active) {
      return WakeDecisionCause.agentInactive;
    }
    if (identity.config.inferenceSetup?.mode ==
        AgentInferenceSetupMode.disabled) {
      return WakeDecisionCause.inferenceDisabled;
    }
    return WakeDecisionCause.automaticUpdatesOff;
  }

  /// Claims one wake of [job]'s agent against today's budget of [maxPerDay].
  ///
  /// Claim-then-execute: the increment is persisted and synced before the
  /// executor starts, so a wake that fails or is aborted still counts — it
  /// may have spent tokens. A claim that cannot be persisted refuses the wake.
  Future<WakePolicyDecision> _claimWakeBudget(
    WakeJob job,
    int maxPerDay,
  ) async {
    if (_budgetClaimedRunKeys.contains(job.runKey)) {
      return WakePolicyDecision.allowedUnbudgeted;
    }
    final updater = syncAgentStateUpdater;
    if (updater == null) {
      // Worlds without sync (tests, guest previews) enforce nothing durable.
      return WakePolicyDecision.allowedUnbudgeted;
    }
    try {
      final host = await localHostId?.call() ?? _unknownBudgetHost;
      final day = wakeBudgetDay(clock.now());
      var verdict = WakeBudgetVerdict.allowed;
      var used = 0;
      await updater(job.agentId, (current) {
        used = wakesUsedOn(current.dailyWakes, day);
        verdict = evaluateWakeBudget(
          used: used,
          maxPerDay: maxPerDay,
          initiator: job.initiator,
        );
        if (!verdict.isAllowed) return null;
        return current.copyWith(
          dailyWakes: recordWake(current.dailyWakes, day: day, host: host),
        );
      });
      if (verdict.isAllowed) {
        _budgetClaimedRunKeys.add(job.runKey);
        used++;
      }
      return WakePolicyDecision.fromBudget(verdict, used: used, max: maxPerDay);
    } catch (error, stackTrace) {
      logError(
        'failed to claim wake budget for '
        '${DomainLogger.sanitizeId(job.agentId)}',
        error: error,
        stackTrace: stackTrace,
      );
      return const WakePolicyDecision(WakeDecisionCause.budgetClaimFailed);
    }
  }

  void _auditDecision(
    WakeJob job,
    WakePolicyDecision decision, {
    required String stage,
  }) {
    _log(
      formatWakeAudit(
        stage: stage,
        agentId: job.agentId,
        cause: decision.cause,
        reason: job.reason,
        initiator: job.initiator,
        reasonId: job.reasonId,
        tokenCount: job.triggerTokens.length,
        budgetUsed: decision.budgetUsed,
        budgetMax: decision.budgetMax,
      ),
      subDomain: 'wakeAudit',
    );
  }

  Future<void> _abortPersistedWake(
    WakeJob job, {
    required String reason,
    required bool emitCompletion,
    Object? error,
  }) async {
    await _safeUpdateStatus(
      job.runKey,
      WakeRunStatus.aborted.name,
      completedAt: clock.now(),
      errorMessage: reason,
    );
    if (emitCompletion) {
      _emitRunCompletion(
        job,
        WakeRunStatus.aborted,
        error: error ?? StateError(reason),
      );
    }
  }

  /// Execute a single wake job: persist → run executor → update status.
  ///
  /// All exceptions are caught and logged so that a single failing job does
  /// not abort the drain loop and starve other queued jobs.
  Future<void> _executeJob(
    WakeJob job, {
    required WakeRunnerLease lease,
    required int generation,
  }) async {
    final threadId = job.runKey;

    _log(
      'executing runKey=${DomainLogger.sanitizeId(job.runKey)}, '
      'agent=${DomainLogger.sanitizeId(job.agentId)}, '
      'reason=${job.reason}, '
      'triggers=${job.triggerTokens.map(DomainLogger.sanitizeId).join(',')}',
      subDomain: 'execute',
    );

    try {
      final runAlreadyPersisted = _persistedWakeRunKeys.remove(job.runKey);
      if (!runAlreadyPersisted) {
        final entry = WakeRunLogData(
          runKey: job.runKey,
          agentId: job.agentId,
          reason: job.reason,
          reasonId: job.reasonId,
          threadId: threadId,
          status: WakeRunStatus.running.name,
          createdAt: job.createdAt,
          startedAt: clock.now(),
        );

        // Fix C: Log insertWakeRun failures at ERROR level.
        try {
          await repository.insertWakeRun(entry: entry);
        } catch (error, stackTrace) {
          final cancellation = _takeDrainOwnedCancellation(job);
          logError(
            'insertWakeRun failed for ${DomainLogger.sanitizeId(job.runKey)}',
            error: error,
            stackTrace: stackTrace,
          );
          if (cancellation == null) {
            _forgetDrainOwnedJob(job);
            _emitRunCompletion(job, WakeRunStatus.failed, error: error);
          }
          return;
        }
      }

      final postInsertCancellation = _takeDrainOwnedCancellation(job);
      if (postInsertCancellation != null) {
        await _abortPersistedWake(
          job,
          reason: postInsertCancellation,
          emitCompletion: false,
        );
        return;
      }
      if (_drainGeneration != generation) {
        _persistedWakeRunKeys.add(job.runKey);
        _handOffSupersededJob(generation, job, lease: lease);
        return;
      }

      final executor = wakeExecutor;
      if (executor == null) {
        _forgetDrainOwnedJob(job);
        logError('no wakeExecutor set — marking run as failed');
        await _safeUpdateStatus(
          job.runKey,
          WakeRunStatus.failed.name,
          errorMessage: 'No wake executor registered',
        );
        _emitRunCompletion(
          job,
          WakeRunStatus.failed,
          error: StateError('No wake executor registered'),
        );
        return;
      }

      // Pre-wake fork healing (ADR 0018 rule 8): collapse a surviving multi-head
      // fork into one continuation node before the wake acts. Best-effort and
      // non-fatal — healing is an optimization, so a failure here must never
      // abort the wake; log and continue.
      final wakeStart = onWakeStart;
      if (wakeStart != null) {
        try {
          await wakeStart(
            job.agentId,
            job.runKey,
            threadId,
          ).timeout(WakeOrchestrator.wakeStartHookTimeout);
        } catch (e, s) {
          logError(
            'pre-wake hook failed for ${DomainLogger.sanitizeId(job.agentId)}',
            error: e,
            stackTrace: s,
          );
        }
      }

      // Policy may change while this job awaits runner acquisition, content
      // gating, run persistence, or the pre-wake hook. Re-read immediately
      // before executor setup so disabling automation cannot launch paid work
      // from a job that has already left the queue.
      //
      // The daily budget is claimed here, last: every wake path — subscription,
      // fallback, restored intent, manual — reaches the executor only through
      // this point, so this is the one place a bound on paid inference holds.
      final decision = await _currentPolicyDecision(job, claimBudget: true);
      final finalPolicyCancellation = _takeDrainOwnedCancellation(job);
      if (finalPolicyCancellation != null) {
        await _abortPersistedWake(
          job,
          reason: finalPolicyCancellation,
          emitCompletion: false,
        );
        return;
      }
      if (_drainGeneration != generation) {
        _persistedWakeRunKeys.add(job.runKey);
        _handOffSupersededJob(generation, job, lease: lease);
        return;
      }
      if (!decision.allowed) {
        _forgetDrainOwnedJob(job);
        _auditDecision(job, decision, stage: 'execute');
        await _safeUpdateStatus(
          job.runKey,
          WakeRunStatus.aborted.name,
          completedAt: clock.now(),
          errorMessage: 'wake refused: ${decision.cause.name}',
        );
        _emitRunCompletion(
          job,
          WakeRunStatus.aborted,
          error: WakeRefusedError(decision.cause),
        );
        return;
      }
      _auditDecision(job, decision, stage: 'execute');

      _forgetDrainOwnedJob(job);
      final startTime = clock.now();
      if (_drainGeneration == generation) {
        _drainLastProgressAt = startTime;
        if (_drainLeaseProgressAt.containsKey(lease)) {
          _drainLeaseProgressAt[lease] = startTime;
        }
      }
      Timer? timeoutTimer;
      try {
        // Pre-register suppression for the trigger tokens BEFORE executing.
        // This prevents a race where the executor writes to the DB, the
        // stream emits a notification, and _onBatch enqueues a self-wake
        // before the executor returns and recordMutatedEntities is called.
        _preRegisterSuppression(job.agentId, job.triggerTokens);

        // Hard cap: arm the timeout before we start the executor so the
        // run cannot exceed [WakeOrchestrator.wakeRunMaxDuration]. The timer fires the same
        // abort signal the user-initiated cancel button triggers, so both
        // paths take the same shutdown branch below.
        var timedOut = false;
        timeoutTimer = Timer(WakeOrchestrator.wakeRunMaxDuration, () {
          timedOut = true;
          if (runner.abortLease(lease)) {
            _log(
              'wake timed out after ${WakeOrchestrator.wakeRunMaxDuration.inSeconds}s '
              'for ${DomainLogger.sanitizeId(job.agentId)} — aborting',
              subDomain: 'timeout',
            );
          }
        });

        // Race the executor against the abort signal. The executor future
        // cannot actually be cancelled in Dart — when abort wins we simply
        // stop awaiting it and let it run to completion in the background.
        // Its mutations land via the normal DB path; the pre-registered
        // suppression is cleared below so the agent can re-trigger on its
        // next legitimate notification.
        //
        // The two race futures are tagged with an explicit sentinel so we
        // can disambiguate "executor returned null" from "abort fired" —
        // checking `aborted.isCompleted && !completed.isCompleted` after
        // the await is racy because the executor can settle in between
        // microtasks (e.g. `aborted` wins, then the executor finishes its
        // own then-handler before we reach the branch), which previously
        // misclassified an aborted run as `completed`.
        final abortFuture = lease.abortFuture;
        final completed = Completer<Map<String, VectorClock>?>();
        final aborted = Completer<void>();
        final abortSentinel = Object();

        final executorFuture = runZoned(
          () => executor(
            job.agentId,
            job.runKey,
            job.triggerTokens,
            threadId,
          ),
          zoneValues: {
            agentExecutionZoneKey: true,
            // Read by the conversation loop before each model turn, so an
            // abort stops further paid turns instead of only being ignored.
            agentWakeAbortedZoneKey: () => aborted.isCompleted,
          },
        );
        _trackExecutor(job, executorFuture);
        unawaited(
          executorFuture.then(
            (value) {
              if (!completed.isCompleted) completed.complete(value);
            },
            onError: (Object e, StackTrace s) {
              if (!completed.isCompleted) completed.completeError(e, s);
            },
          ),
        );

        unawaited(
          abortFuture.then((_) {
            if (!aborted.isCompleted) aborted.complete();
          }),
        );

        final winner = await Future.any<Object?>([
          completed.future,
          aborted.future.then((_) => abortSentinel),
        ]);
        timeoutTimer.cancel();

        if (identical(winner, abortSentinel)) {
          _suppression.clearPreRegistered(job.agentId);
          final elapsed = clock.now().difference(startTime);
          _log(
            'wake aborted after ${elapsed.inMilliseconds}ms '
            'for ${DomainLogger.sanitizeId(job.agentId)}',
            subDomain: 'execute',
          );
          await _safeUpdateStatus(
            job.runKey,
            WakeRunStatus.aborted.name,
            completedAt: clock.now(),
            errorMessage: timedOut ? 'timeout' : 'cancelled',
          );
          _emitRunCompletion(
            job,
            WakeRunStatus.aborted,
            error: TimeoutException(timedOut ? 'timeout' : 'cancelled'),
          );
          // Aborted wakes do not arm the throttle deadline — re-allowing
          // the agent to wake on the next notification keeps the system
          // responsive after an unstuck cycle.
          return;
        }

        final mutated = winner as Map<String, VectorClock>?;
        final reportUpdated =
            mutated is! WakeExecutorResult || mutated.reportUpdated;
        coordinator?.complete(job.runKey, reportUpdated: reportUpdated);

        // Clear pre-registered suppression and record only the actual
        // mutations.  The zone-based isAgentExecution in PersistenceLogic
        // prevents self-notifications, so the pre-registered superset is
        // no longer needed after execution completes.
        _suppression.clearPreRegistered(job.agentId);
        if (mutated != null && mutated.isNotEmpty) {
          recordMutatedEntities(job.agentId, mutated);
        } else {
          _suppression.clearConfirmed(job.agentId);
        }

        final elapsed = clock.now().difference(startTime);
        _log(
          'wake completed in ${elapsed.inMilliseconds}ms '
          'for ${DomainLogger.sanitizeId(job.agentId)}',
          subDomain: 'execute',
        );

        await _safeUpdateStatus(
          job.runKey,
          WakeRunStatus.completed.name,
          completedAt: clock.now(),
        );
        _emitRunCompletion(
          job,
          WakeRunStatus.completed,
          startedAt: startTime,
          // Only goal wakes report the tri-state today; a plain map result
          // stays null ("unknown") rather than claiming an update happened.
          reportUpdated: mutated is WakeExecutorResult
              ? mutated.reportUpdated
              : null,
        );

        if (reportUpdated) {
          await _markReportFresh(job.agentId, refreshStartedAt: startTime);
        }

        // Only arm a follow-up throttle deadline when work remains queued;
        // otherwise the persisted `nextWakeAt` surfaces in the Wake Cycles
        // sidebar as a cooldown row with nothing left to execute.
        //
        // For queued follow-ups, a digest-deferred propagated-only queue
        // (e.g. project fan-outs that arrived while the executor was
        // running) defers the drain to the next 06:00. A fast-bearing job
        // — direct edit or task-agent propagated child update — keeps the
        // standard 120 s drain so user-visible task edits land promptly.
        if (job.reason == WakeReason.subscription.name &&
            queue.hasQueuedJobFor(
              job.agentId,
              workspaceKey: job.workspaceKey,
            )) {
          // The policy lives on the queued jobs, not on the agent: a mixed
          // queue (deferred follow-up beside an immediate one) arms the
          // deadline for the deferred job AND dispatches the immediate one
          // now — the job-level check in the candidate filter lets it pass
          // the deadline the deferred job still honours.
          if (queue.hasDeferredQueuedJobFor(
            job.agentId,
            workspaceKey: job.workspaceKey,
          )) {
            final hasDirectQueued = queue.hasDirectQueuedJobFor(
              job.agentId,
              workspaceKey: job.workspaceKey,
            );
            final morningDeadline = !hasDirectQueued
                ? nextOccurrenceOf(
                    clock.now(),
                    hour: AgentSchedules.projectDailyDigestHour,
                  )
                : null;
            await _setThrottleDeadline(
              job.agentId,
              customDeadline: morningDeadline,
            );
          }
          if (queue.hasImmediateQueuedJobFor(
            job.agentId,
            workspaceKey: job.workspaceKey,
          )) {
            unawaited(processNext());
          }
        }
      } catch (e) {
        _suppression.clearPreRegistered(job.agentId);
        final elapsed = clock.now().difference(startTime);
        // The reason rides in the message: the PII-safe error log keeps
        // only message and error type, and a bare type says nothing about
        // which workflow reason it was.
        logError(
          'wake failed in ${elapsed.inMilliseconds}ms '
          'for ${DomainLogger.sanitizeId(job.runKey)}'
          '${e is WakeFailedException ? ' kind=${e.kind} reason=${e.reason}' : ''}',
          error: e,
        );
        await _safeUpdateStatus(
          job.runKey,
          WakeRunStatus.failed.name,
          errorMessage: 'Wake failed (${e.runtimeType})',
        );
        _emitRunCompletion(
          job,
          WakeRunStatus.failed,
          error: e,
          startedAt: startTime,
        );
      } finally {
        timeoutTimer?.cancel();
      }
    } finally {
      _releaseDrainLease(generation, lease);
      // Releases the claim of a run that did not complete: failed, aborted,
      // or handed back before its executor started. No-op after complete.
      coordinator?.settle(job.runKey);
      // A started executor settles its intent when it actually settles —
      // after an abort, that is later than this — and a job handed back to
      // the queue is still owed. Otherwise the job ended here, without one.
      if (!_activeExecutors.containsKey(job.runKey) && !queue.contains(job)) {
        _settleIntent(job);
      }
    }
  }

  Future<void> _markReportFresh(
    String agentId, {
    required DateTime refreshStartedAt,
  }) => _serializeFreshnessWrite(
    agentId,
    () => _persistReportFresh(
      agentId,
      refreshStartedAt: refreshStartedAt,
    ),
  );

  Future<void> _persistReportFresh(
    String agentId, {
    required DateTime refreshStartedAt,
  }) async {
    try {
      final state = await repository.getAgentState(agentId);
      if (state == null || state.reportStaleAt == null) return;
      final persisted = state.reportFreshAt;
      if (persisted != null && !refreshStartedAt.isAfter(persisted)) return;

      final updated = state.copyWith(
        reportFreshAt: refreshStartedAt,
        updatedAt: clock.now(),
      );
      final writer = syncEntityWriter;
      if (writer != null) {
        await writer(updated);
      } else {
        await repository.upsertEntity(updated);
      }
      onPersistedStateChanged?.call(agentId);
    } catch (error, stackTrace) {
      logError(
        'failed to persist fresh report watermark for '
        '${DomainLogger.sanitizeId(agentId)}',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
