part of 'wake_orchestrator.dart';

/// Notification-batch routing of [WakeOrchestrator]: token matching,
/// suppression checks, and the awaiting-content gate.
extension WakeBatchRouter on WakeOrchestrator {
  void _onBatch(Set<String> tokens) {
    if (_subscriptions.isEmpty) {
      _log(
        'batch: ${tokens.length} token(s), 0 subscriptions — ignoring',
        subDomain: 'onBatch',
      );
      return;
    }
    for (final sub in _subscriptions) {
      // 1. Check whether any token matches the subscription's entity IDs.
      //    A "direct" match means the agent's own entity was edited
      //    (token in tokens AND propagated::token NOT in tokens). A
      //    "propagated" match means the token only arrived via parent
      //    fan-out or a link side-effect (propagated::token in tokens).
      //    Pure-propagated matches can opt into daily-digest deferral; any
      //    direct match, and task-agent subscriptions that disable the
      //    propagated deferral policy, keep the existing fast-throttle
      //    behaviour.
      final matched = tokens.intersection(sub.matchEntityIds);
      final propagatedMatched = sub.matchEntityIds
          .where((id) => tokens.contains(propagatedNotification(id)))
          .toSet();
      // The same id present in both raw and wrapped form means the raw
      // emission was just bookkeeping for legacy listeners — treat the
      // match as propagated for the agent's deferral decision.
      final trueDirect = matched.difference(propagatedMatched);
      final allMatched = matched.union(propagatedMatched);
      if (allMatched.isEmpty) continue;

      _log(
        'matched ${allMatched.length} token(s) for '
        '${DomainLogger.sanitizeId(sub.agentId)} '
        '(sub: ${DomainLogger.sanitizeId(sub.id)}, '
        'direct=${trueDirect.length}, '
        'propagated=${propagatedMatched.length})',
        subDomain: 'onBatch',
      );

      // 2. Apply post-execution self-notification suppression.
      if (_isSuppressed(sub.agentId, allMatched)) {
        _log(
          'suppressed self-notification for '
          '${DomainLogger.sanitizeId(sub.agentId)} '
          'matched=${allMatched.map(DomainLogger.sanitizeId)}',
          subDomain: 'suppression',
        );
        continue;
      }
      _log(
        'not suppressed for ${DomainLogger.sanitizeId(sub.agentId)} '
        'matched=${allMatched.map(DomainLogger.sanitizeId)} '
        'suppression=${_suppression.debugState(sub.agentId)}',
        subDomain: 'suppression',
      );

      // 3. Apply optional fine-grained predicate before any queueing path.
      final predicate = sub.predicate;
      if (predicate != null && !predicate(allMatched)) continue;

      // The fast-drain bit drives both the queued job's [hasDirectMatch] flag
      // and the throttle-gate escalation below. Task-agent subscriptions
      // deliberately treat propagated child updates as fast-drain updates so
      // task titles/summaries do not wait until the next daily digest slot.
      final usesFastThrottle =
          trueDirect.isNotEmpty || !sub.deferPropagatedMatches;

      // 4. During-execution gate: when the agent is actively executing,
      //    silently queue the notification for the drain re-check instead
      //    of going through the throttle/defer path. The drain re-check
      //    uses _isPreRegisteredSuppressed (with actual subscription IDs)
      //    and _isSuppressed (with actual mutation records) to distinguish
      //    the agent's own writes from legitimate external changes.
      //    This avoids creating spurious countdown timers and prevents
      //    the double-run race where the safety-net dequeues a job during
      //    its async gap.
      if (runner.isRunning(sub.agentId)) {
        final merged = queue.mergeTokens(
          sub.agentId,
          allMatched,
          isDirect: usesFastThrottle,
        );
        if (!merged) {
          final counter = _wakeCounters[sub.agentId] ?? 0;
          _wakeCounters[sub.agentId] = counter + 1;
          queue.enqueue(
            WakeJob(
              runKey: RunKeyFactory.forSubscription(
                agentId: sub.agentId,
                subscriptionId: sub.id,
                batchTokens: allMatched,
                wakeCounter: counter,
                timestamp: clock.now(),
              ),
              agentId: sub.agentId,
              reason: WakeReason.subscription.name,
              triggerTokens: Set<String>.from(allMatched),
              reasonId: sub.id,
              createdAt: clock.now(),
              hasDirectMatch: usesFastThrottle,
            ),
          );
        }
        _log(
          '${DomainLogger.sanitizeId(sub.agentId)} executing — '
          '${merged ? 'merged tokens into queued job' : 'queued for drain re-check'} '
          '(fastThrottle=$usesFastThrottle)',
          subDomain: 'running',
        );
        continue;
      }

      // 5. Throttle gate: when the agent is throttled (but not executing),
      //    merge tokens into the queued job or enqueue a new one so the
      //    deferred drain timer can pick it up.
      if (_isThrottled(sub.agentId)) {
        final deadline = _throttle.deadlineFor(sub.agentId);
        final merged = queue.mergeTokens(
          sub.agentId,
          allMatched,
          isDirect: usesFastThrottle,
        );
        // Escalate the deadline when a direct match arrives on top of a
        // morning-deferred slot — leaving the user's edit waiting until
        // 06:00 because earlier propagation already armed a long timer
        // would defeat the entire policy.
        if (usesFastThrottle && deadline != null) {
          final immediate = clock.now().add(WakeOrchestrator.throttleWindow);
          if (immediate.isBefore(deadline)) {
            _log(
              'escalating ${DomainLogger.sanitizeId(sub.agentId)} '
              'deadline from $deadline to $immediate '
              '(fast-throttle match arrived during propagated deferral)',
              subDomain: 'throttle',
            );
            unawaited(_setThrottleDeadline(sub.agentId));
          }
        }
        _log(
          '${DomainLogger.sanitizeId(sub.agentId)} throttled until $deadline — '
          '${merged ? 'merged tokens' : 'enqueuing for deferred drain'}',
          subDomain: 'throttle',
        );
        if (merged) continue;
        // Fall through to enqueue a new job for the deferred drain.
      }

      // 6. Derive a deterministic run key and enqueue.
      final counter = _wakeCounters[sub.agentId] ?? 0;
      _wakeCounters[sub.agentId] = counter + 1;

      final now = clock.now();
      final runKey = RunKeyFactory.forSubscription(
        agentId: sub.agentId,
        subscriptionId: sub.id,
        batchTokens: allMatched,
        wakeCounter: counter,
        timestamp: now,
      );

      final job = WakeJob(
        runKey: runKey,
        agentId: sub.agentId,
        reason: WakeReason.subscription.name,
        triggerTokens: Set<String>.from(allMatched),
        reasonId: sub.id,
        createdAt: clock.now(),
        hasDirectMatch: usesFastThrottle,
      );

      // Attempt to merge tokens into an existing queued job for this agent
      // before enqueuing a new one; this coalesces rapid-fire notifications.
      if (!queue.mergeTokens(
        sub.agentId,
        allMatched,
        isDirect: usesFastThrottle,
      )) {
        queue.enqueue(job);
      }

      // Awaiting-content agents (newly-created task agents on blank tasks)
      // do not get a throttle deadline — surfacing a 2-minute countdown for
      // a task with nothing to analyze is just noise. The job stays in the
      // queue and the content gate will skip it until real content arrives.
      // Once content does arrive, _shouldSkipForAwaitingContent clears the
      // flag and from then on the normal throttle applies.
      if (_agentsAwaitingContent.contains(sub.agentId)) {
        _log(
          'skipping throttle deadline for '
          '${DomainLogger.sanitizeId(sub.agentId)} '
          '(awaiting content, no countdown surfaced)',
          subDomain: 'awaitContent',
        );
        continue;
      }

      // Defer-first: instead of dispatching immediately, set a throttle
      // deadline and schedule a deferred drain. Fast-throttle matches use the
      // standard 120 s coalescing window; pure-propagated matches from
      // subscriptions that opted into digest deferral use the next 06:00 so
      // project agents do not burn LLM tokens on every incidental fan-out.
      final DateTime? morningDeadline;
      if (!usesFastThrottle) {
        morningDeadline = nextOccurrenceOf(
          now,
          hour: AgentSchedules.projectDailyDigestHour,
        );
      } else {
        morningDeadline = null;
      }
      unawaited(
        _setThrottleDeadline(sub.agentId, customDeadline: morningDeadline),
      );

      _log(
        'deferred wake for ${DomainLogger.sanitizeId(sub.agentId)}: '
        '${morningDeadline == null ? 'drain scheduled in ${WakeOrchestrator.throttleWindow.inSeconds}s' : 'drain scheduled at $morningDeadline (morning)'}, '
        'reason=subscription, '
        'sub=${DomainLogger.sanitizeId(sub.id)}, '
        'triggers=${allMatched.map(DomainLogger.sanitizeId).join(',')}',
        subDomain: 'defer',
      );
    }
  }

  /// Returns `true` when all [matchedTokens] are covered by the agent's
  /// recently mutated entries (i.e., the agent wrote those entities itself)
  /// and the mutation record has not expired.
  bool _isSuppressed(String agentId, Set<String> matchedTokens) {
    return _suppression.isSuppressed(agentId, matchedTokens);
  }

  /// Returns `true` when all [matchedTokens] are covered by the agent's
  /// pre-registered suppression (conservative over-approximation set before
  /// execution starts).
  ///
  /// Only used during the drain re-check, NOT during `_onBatch`.
  ///
  /// No TTL — the suppression is explicitly cleared in [_executeJob] after
  /// the executor returns (both success and failure paths). Using a TTL would
  /// cause the suppression to expire mid-execution for long-running agents,
  /// allowing their own writes to trigger spurious follow-up wakes.
  bool _isPreRegisteredSuppressed(
    String agentId,
    Set<String> matchedTokens,
  ) {
    return _suppression.isPreRegisteredSuppressed(agentId, matchedTokens);
  }

  // ── Content-gating ────────────────────────────────────────────────────────

  /// Returns `true` if the job should be skipped because the agent is in
  /// content-awaiting mode and the task doesn't have content yet.
  ///
  /// When content IS found, clears the `awaitingContent` flag on the agent
  /// state so subsequent wakes proceed normally.
  ///
  /// Whenever this method returns `false` because the persisted state shows
  /// the agent is no longer awaiting content (state missing, flag already
  /// cleared, or no active task to gate on), the in-memory mirror is dropped
  /// so it cannot stay falsely `true` and silence countdowns indefinitely.
  /// Truly indeterminate paths (no `taskContentChecker`, exceptions) leave
  /// the mirror untouched — they fail open without lying about state.
  Future<bool> _shouldSkipForAwaitingContent(WakeJob job) async {
    try {
      final state = await repository.getAgentState(job.agentId);
      if (state == null || !state.awaitingContent) {
        // Persisted state says not awaiting — drop any stale mirror entry
        // so future notifications surface the normal countdown.
        _agentsAwaitingContent.remove(job.agentId);
        return false;
      }

      final taskId = state.slots.activeTaskId;
      if (taskId == null) {
        // Awaiting flag is set but there is no task to gate on. The agent
        // is about to run; drop the mirror so subsequent notifications use
        // the normal throttle.
        _agentsAwaitingContent.remove(job.agentId);
        return false;
      }

      final checker = taskContentChecker;
      if (checker == null) {
        // Indeterminate — we can't verify content state. Fail open and
        // leave the mirror as-is so the persisted flag still drives the
        // countdown suppression.
        return false;
      }

      final hasContent = await checker(taskId);
      if (!hasContent) {
        _log(
          'content-gate: skipping wake for '
          '${DomainLogger.sanitizeId(job.agentId)} '
          '(task has no content yet)',
          subDomain: 'contentGate',
        );
        return true;
      }

      // Content found — clear the flag and let the wake proceed.
      // Use syncEntityWriter so the transition propagates to other devices.
      _log(
        'content-gate: activating '
        '${DomainLogger.sanitizeId(job.agentId)} '
        '(task now has content)',
        subDomain: 'contentGate',
      );
      final cleared = state.copyWith(
        awaitingContent: false,
        updatedAt: clock.now(),
      );
      final writer = syncEntityWriter;
      if (writer != null) {
        await writer(cleared);
      } else {
        await repository.upsertEntity(cleared);
      }
      // Drop the in-memory mirror so subsequent subscription notifications
      // get the normal throttle countdown.
      _agentsAwaitingContent.remove(job.agentId);
      return false;
    } catch (e, s) {
      // Don't let content-check errors block the wake — proceed normally.
      // Mirror is intentionally left untouched: we don't know whether the
      // persisted flag still applies, so we fail open without rewriting
      // local state.
      _logError(
        'content-gate: error checking content for '
        '${DomainLogger.sanitizeId(job.agentId)}',
        error: e,
        stackTrace: s,
      );
      return false;
    }
  }
}
