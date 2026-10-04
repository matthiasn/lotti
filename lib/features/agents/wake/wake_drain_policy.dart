part of 'wake_orchestrator.dart';

/// The policy, budget and execution half of the wake drain: coordinating a claimed job, deciding whether it may run, and executing it.
extension WakeDrainPolicy on WakeOrchestrator {
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
    // The only automatic work a project agent does is an update slot,
    // fired on one device by the slot's lease (ProjectWakeGovernor.tla,
    // StaleDoesNotTriggerWork). Whatever else queued an automatic wake —
    // a subscription, a transcript, a restored intent — is refused here.
    if (job.initiator == WakeInitiator.automation &&
        !job.triggerTokens.contains(ProjectUpdateSlots.triggerToken)) {
      return const WakePolicyDecision(WakeDecisionCause.notAnUpdateSlot);
    }
    // A slot over a report an "Update now" or a peer's run already
    // freshened has nothing to do (ProjectWakeGovernor.tla, NoWorkWhenFresh);
    // refused before the budget is read or claimed, so it costs nothing.
    if (job.initiator == WakeInitiator.automation &&
        await _reportAlreadyFresh(job.agentId)) {
      return const WakePolicyDecision(WakeDecisionCause.reportAlreadyFresh);
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

  /// Whether [agentId]'s report is already fresh. A state that cannot be
  /// read is treated as stale: the budget claim that follows decides.
  Future<bool> _reportAlreadyFresh(String agentId) async {
    try {
      final state = await repository.getAgentState(agentId);
      return state != null && !state.isReportStale;
    } catch (error, stackTrace) {
      logError(
        'failed to read report freshness for '
        '${DomainLogger.sanitizeId(agentId)}',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
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
      _emitRunCompletion(job, WakeRunStatus.aborted, error: error);
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
