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
  /// a stuck drain.
  Future<void> processNextImpl() async {
    if (_isDraining) {
      // Fix B: force-reset stale drain lock after timeout.
      if (_drainLastProgressAt != null &&
          clock.now().difference(_drainLastProgressAt!) >
              WakeOrchestrator._drainTimeout) {
        final stalledFor = clock.now().difference(_drainLastProgressAt!);
        _log(
          'force-resetting stale drain lock '
          '(last progress ${stalledFor.inSeconds}s ago)',
          subDomain: 'drain',
        );
        // Increment generation so the old drain's loop bails out, then free
        // only the runner slots owned by that superseded generation.
        final staleGeneration = _drainGeneration;
        _drainGeneration++;
        _releaseDrainGenerationLeases(staleGeneration);
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
  }

  void _releaseDrainLease(int generation, WakeRunnerLease lease) {
    final leases = _drainLeasesByGeneration[generation];
    leases?.remove(lease);
    if (leases != null && leases.isEmpty) {
      _drainLeasesByGeneration.remove(generation);
    }
    runner.releaseLease(lease);
  }

  void _releaseDrainGenerationLeases(int generation) {
    final leases = _drainLeasesByGeneration.remove(generation);
    if (leases == null) return;
    leases.forEach(runner.releaseLease);
  }

  void _trackDrainOwnedJob(WakeJob job) {
    _drainOwnedJobs[job.runKey] = job;
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
    if (lease != null) _releaseDrainLease(generation, lease);
    if (_drainGeneration != generation) unawaited(processNext());
    return true;
  }

  Future<void> _dropDrainOwnedJob(
    WakeJob job, {
    required String reason,
    required bool emitUnpersistedCompletion,
  }) async {
    _forgetDrainOwnedJob(job);
    if (_persistedWakeRunKeys.remove(job.runKey)) {
      await _abortPersistedWake(
        job,
        reason: reason,
        emitCompletion: true,
      );
    } else if (emitUnpersistedCompletion) {
      _emitRunCompletion(
        job,
        WakeRunStatus.aborted,
        error: StateError(reason),
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
              if (runner.isRunning(candidate.agentId)) return false;
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
              return suppressed ||
                  preRegistered ||
                  candidate.drainImmediately ||
                  !_isThrottled(candidate.agentId);
            },
          );
          if (job == null) break;
          _trackDrainOwnedJob(job);
          inspectedJobs++;

          final wakeAllowed = await _wakeAllowedByCurrentPolicy(job);
          if (_discardCancelledDrainOwnedJob(generation, job)) {
            if (_drainGeneration != generation) return;
            continue;
          }
          if (_drainGeneration != generation) {
            _handOffSupersededJob(generation, job);
            return;
          }
          if (!wakeAllowed) {
            const reason = 'wake dropped by current automation policy';
            await _dropDrainOwnedJob(
              job,
              reason: reason,
              emitUnpersistedCompletion: true,
            );
            _log(
              'drain policy dropped automatic/disabled wake for '
              '${DomainLogger.sanitizeId(job.agentId)}',
              subDomain: 'drain',
            );
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
            deferred.add(job);
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
              _log(
                'drain re-check: throttled=true '
                'for ${DomainLogger.sanitizeId(job.agentId)}',
                subDomain: 'drain',
              );
              _forgetDrainOwnedJob(job);
              _releaseDrainLease(generation, lease);
              deferred.add(job);
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
        deferred
          ..forEach(queue.requeue)
          ..clear();

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
      deferred.forEach(queue.requeue);

      // A stale generation can supersede this scheduler while several wakes
      // are still active. Keep awaiting those futures so this drain never
      // leaks errors or loses their lock-release finalizers.
      if (activeExecutions.isNotEmpty) {
        await Future.wait(activeExecutions.values);
      }

      // Clear run-key history only when the queue is fully drained (no
      // deferred jobs left). This prevents stale keys from blocking future
      // wakes while avoiding premature clearing that could allow duplicates.
      if (_drainGeneration == generation && queue.isEmpty) {
        _log('run-key history cleared (queue empty)', subDomain: 'drain');
        queue.clearHistory();
      }
    }
  }

  Future<bool> _wakeAllowedByCurrentPolicy(WakeJob job) async {
    late final AgentDomainEntity? entity;
    try {
      entity = await repository.getEntity(job.agentId);
    } catch (error, stackTrace) {
      logError(
        'failed to load agent policy; allowing wake to proceed',
        error: error,
        stackTrace: stackTrace,
      );
      return true;
    }
    if (entity is! AgentIdentityEntity) {
      return true;
    }
    if (entity.kind == AgentKinds.projectAgent) {
      return projectAgentWakeAllowed(
        config: entity.config,
        lifecycle: entity.lifecycle,
        initiator: job.initiator,
      );
    }
    if (entity.kind != AgentKinds.taskAgent) {
      return entity.lifecycle == AgentLifecycle.active;
    }
    return taskAgentWakeAllowed(
      config: entity.config,
      lifecycle: entity.lifecycle,
      initiator: job.initiator,
    );
  }

  Future<void> _abortPersistedWake(
    WakeJob job, {
    required String reason,
    required bool emitCompletion,
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
        error: StateError(reason),
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
          _forgetDrainOwnedJob(job);
          logError(
            'insertWakeRun failed for ${DomainLogger.sanitizeId(job.runKey)}',
            error: error,
            stackTrace: stackTrace,
          );
          _emitRunCompletion(job, WakeRunStatus.failed, error: error);
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
      final wakeAllowed = await _wakeAllowedByCurrentPolicy(job);
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
      if (!wakeAllowed) {
        _forgetDrainOwnedJob(job);
        _log(
          'pre-execution policy dropped automatic/disabled wake for '
          '${DomainLogger.sanitizeId(job.agentId)}',
          subDomain: 'drain',
        );
        await _safeUpdateStatus(
          job.runKey,
          WakeRunStatus.aborted.name,
        );
        _emitRunCompletion(job, WakeRunStatus.aborted);
        return;
      }

      _forgetDrainOwnedJob(job);
      final startTime = clock.now();
      if (_drainGeneration == generation) {
        _drainLastProgressAt = startTime;
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
          zoneValues: {agentExecutionZoneKey: true},
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
        _emitRunCompletion(job, WakeRunStatus.completed);

        final reportUpdated =
            mutated is! WakeExecutorResult || mutated.reportUpdated;
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
        logError(
          'wake failed in ${elapsed.inMilliseconds}ms '
          'for ${DomainLogger.sanitizeId(job.runKey)}',
          error: e,
        );
        await _safeUpdateStatus(
          job.runKey,
          WakeRunStatus.failed.name,
          errorMessage: 'Wake failed (${e.runtimeType})',
        );
        _emitRunCompletion(job, WakeRunStatus.failed, error: e);
      } finally {
        timeoutTimer?.cancel();
      }
    } finally {
      _releaseDrainLease(generation, lease);
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
