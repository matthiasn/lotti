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
  /// Fix B: If a drain has been in progress for longer than [WakeOrchestrator._drainTimeout],
  /// force-reset the guard to recover from a stuck drain.
  Future<void> processNextImpl() async {
    if (_isDraining) {
      // Fix B: force-reset stale drain lock after timeout.
      if (_drainStartedAt != null &&
          clock.now().difference(_drainStartedAt!) >
              WakeOrchestrator._drainTimeout) {
        _log(
          'force-resetting stale drain lock '
          '(started ${clock.now().difference(_drainStartedAt!).inSeconds}s ago)',
          subDomain: 'drain',
        );
        // Increment generation so the old drain's loop bails out.
        _drainGeneration++;
        final wakeSignal = _drainWakeSignal;
        if (wakeSignal != null && !wakeSignal.isCompleted) {
          wakeSignal.complete();
        }
        _isDraining = false;
        _drainStartedAt = null;
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
    _drainStartedAt = clock.now();
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
        _drainStartedAt = null;
      }
    }
  }

  /// Bounded dispatch pass: execute ready jobs up to the configured limit.
  ///
  /// [generation] is the drain generation at the time this pass was started.
  /// If a newer generation supersedes us (via stale-lock recovery), the loop
  /// bails out early to avoid overlapping mutations.
  Future<void> _drain(int generation) async {
    final deferred = <WakeJob>[];
    final activeExecutions = <String, Future<String>>{};

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
              return suppressed ||
                  preRegistered ||
                  !_isThrottled(candidate.agentId);
            },
          );
          if (job == null) break;
          inspectedJobs++;

          if (!await _wakeAllowedByCurrentPolicy(job)) {
            _log(
              'drain policy dropped automatic/disabled wake for '
              '${DomainLogger.sanitizeId(job.agentId)}',
              subDomain: 'drain',
            );
            continue;
          }

          final acquired = await runner.tryAcquire(job.agentId);
          if (!acquired) {
            // Keep same-agent work queued while its active wake executes. The
            // active wake uses queue visibility to decide whether to arm its
            // existing follow-up throttle deadline.
            deferred.add(job);
            continue;
          }

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
              runner.release(job.agentId);
              continue;
            }

            // Throttled: defer the job so the deferred drain timer can pick
            // it up after the throttle window expires.
            if (_isThrottled(job.agentId)) {
              _log(
                'drain re-check: throttled=true '
                'for ${DomainLogger.sanitizeId(job.agentId)}',
                subDomain: 'drain',
              );
              runner.release(job.agentId);
              deferred.add(job);
              continue;
            }
          }

          // Content-gating: agents auto-assigned from category defaults wait
          // for the task to have meaningful content before their first run.
          if (await _shouldSkipForAwaitingContent(job)) {
            runner.release(job.agentId);
            continue;
          }

          activeExecutions[job.runKey] = _executeJob(job).then(
            (_) => job.runKey,
            onError: (Object error, StackTrace stackTrace) {
              // `_executeJob` owns its normal error boundary and lock release,
              // but keep the scheduler resilient if an unexpected failure
              // escapes that boundary (for example, a logging implementation
              // throwing before `_executeJob` enters its outer try/finally).
              runner.release(job.agentId);
              _logError(
                'unexpected wake execution failure for '
                '${DomainLogger.sanitizeId(job.runKey)}',
                error: error,
                stackTrace: stackTrace,
              );
              return job.runKey;
            },
          );
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
        _drainWakeSignal = wakeSignal;
        final wakeSentinel = Object();
        final completedRunKey = await Future.any<Object>([
          Future.any(activeExecutions.values),
          wakeSignal.future.then((_) => wakeSentinel),
        ]);
        if (identical(_drainWakeSignal, wakeSignal)) {
          _drainWakeSignal = null;
        }
        if (identical(completedRunKey, wakeSentinel)) {
          _drainRequested = false;
          continue;
        }
        final completedExecution = activeExecutions.remove(
          completedRunKey as String,
        );
        if (completedExecution != null) await completedExecution;
      }
    } finally {
      _drainWakeSignal = null;

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
      _logError(
        'failed to load agent policy; allowing wake to proceed',
        error: error,
        stackTrace: stackTrace,
      );
      return true;
    }
    if (entity is! AgentIdentityEntity || entity.kind != AgentKinds.taskAgent) {
      return true;
    }
    return taskAgentWakeAllowed(
      config: entity.config,
      lifecycle: entity.lifecycle,
      initiator: job.initiator,
    );
  }

  /// Execute a single wake job: persist → run executor → update status.
  ///
  /// All exceptions are caught and logged so that a single failing job does
  /// not abort the drain loop and starve other queued jobs.
  Future<void> _executeJob(WakeJob job) async {
    final threadId = job.runKey;

    _log(
      'executing runKey=${DomainLogger.sanitizeId(job.runKey)}, '
      'agent=${DomainLogger.sanitizeId(job.agentId)}, '
      'reason=${job.reason}, '
      'triggers=${job.triggerTokens.map(DomainLogger.sanitizeId).join(',')}',
      subDomain: 'execute',
    );

    try {
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
      } catch (e, s) {
        _logError(
          'insertWakeRun failed for ${DomainLogger.sanitizeId(job.runKey)}',
          error: e,
          stackTrace: s,
        );
        return;
      }

      final executor = wakeExecutor;
      if (executor == null) {
        _logError('no wakeExecutor set — marking run as failed');
        await _safeUpdateStatus(
          job.runKey,
          WakeRunStatus.failed.name,
          errorMessage: 'No wake executor registered',
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
          _logError(
            'pre-wake hook failed for ${DomainLogger.sanitizeId(job.agentId)}',
            error: e,
            stackTrace: s,
          );
        }
      }

      final startTime = clock.now();
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
          if (runner.abort(job.agentId)) {
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
        final abortFuture = runner.abortFuture(job.agentId);
        final completed = Completer<Map<String, VectorClock>?>();
        final aborted = Completer<void>();
        final abortSentinel = Object();

        unawaited(
          runZoned(
            () => executor(
              job.agentId,
              job.runKey,
              job.triggerTokens,
              threadId,
            ),
            zoneValues: {agentExecutionZoneKey: true},
          ).then(
            (value) {
              if (!completed.isCompleted) completed.complete(value);
            },
            onError: (Object e, StackTrace s) {
              if (!completed.isCompleted) completed.completeError(e, s);
            },
          ),
        );

        if (abortFuture != null) {
          unawaited(
            abortFuture.then((_) {
              if (!aborted.isCompleted) aborted.complete();
            }),
          );
        }

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
      } catch (e) {
        _suppression.clearPreRegistered(job.agentId);
        final elapsed = clock.now().difference(startTime);
        _logError(
          'wake failed in ${elapsed.inMilliseconds}ms '
          'for ${DomainLogger.sanitizeId(job.runKey)}',
          error: e,
        );
        await _safeUpdateStatus(
          job.runKey,
          WakeRunStatus.failed.name,
          errorMessage: 'Wake failed (${e.runtimeType})',
        );
      } finally {
        timeoutTimer?.cancel();
      }
    } finally {
      runner.release(job.agentId);
    }
  }

  /// Update wake run status, swallowing any DB errors so they don't escape
  /// `_executeJob` / `_drain` / `processNext`.
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
    } catch (e, s) {
      _logError(
        'failed to update wake run status '
        'for ${DomainLogger.sanitizeId(runKey)} to $status',
        error: e,
        stackTrace: s,
      );
    }
  }
}
