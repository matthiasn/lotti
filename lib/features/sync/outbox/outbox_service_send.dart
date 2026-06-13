part of 'outbox_service.dart';

/// Send/runner/backoff pipeline of [OutboxService]. Extracted into a
/// part-file mixin to keep the service file under the size limit; shared
/// state is reached through the [_OutboxServiceBase] accessors that the
/// concrete service satisfies with its own fields.
mixin _OutboxSend on _OutboxServiceBase {
  // Backoff gate + coalesced-log state — private to the send pipeline.
  DateTime? _nextSendAllowedAt;
  DateTime? _backoffScheduledAt;
  String? _lastLoggedSendNextState;
  DateTime? _lastLoggedSendNextStateAt;

  void _startRunner() {
    _clientRunner = ClientRunner<int>(
      callback: (event) async {
        // clock.now() so fakeAsync-driven tests can advance the measured
        // wait deterministically (fake_async patches package:clock).
        final started = clock.now();
        await _activityGate.waitUntilIdle();
        final waitedMs = clock.now().difference(started).inMilliseconds;
        if (waitedMs > 50) {
          // Light instrumentation to correlate potential stalls.
          _loggingService.log(
            LogDomain.sync,
            'activityGate.wait ms=$waitedMs',
            subDomain: 'activityGate',
          );
        }
        await sendNext();
      },
    );

    // Safety watchdog: if there are pending items and we appear idle (no
    // queued work), periodically nudge the runner. This recovers from missed
    // signals or platform-specific timer quirks after reconnects/resumes.
    // Prune `sent` outbox rows older than [SyncTuning.outboxSentRetention]
    // on startup (after a short grace window so it doesn't race init) and
    // then at [SyncTuning.outboxPruneInterval]. Error rows are kept forever
    // for forensic inspection. Without this, sent rows accumulate
    // indefinitely (observed: 395k on desktop, 265k on mobile) and slow
    // every outbox enqueue / dedup lookup.
    _pruneTimer?.cancel();
    Future<void> runPrune() async {
      if (_isDisposed) return;
      try {
        // Chunked DELETE so the writer lock is released between batches.
        // The unbounded variant held the writer for many seconds on
        // devices where the table had grown to hundreds of thousands of
        // sent rows (observed up to ~1M), stalling concurrent enqueue
        // and claim work for the duration of the delete. VACUUM is
        // skipped here because it rewrites the whole DB file on every
        // run and the periodic prune typically only releases a day's
        // worth of rows; the user-triggered Maintenance action enables
        // VACUUM for one-shot cleanup of large backlogs.
        final deleted = await _repository.pruneSentOutboxItemsChunked(
          retention: SyncTuning.outboxSentRetention,
        );
        if (deleted > 0) {
          _loggingService.log(
            LogDomain.sync,
            'prune.sent removed=$deleted '
            'retentionDays=${SyncTuning.outboxSentRetention.inDays}',
            subDomain: 'prune',
          );
        }
      } catch (e, st) {
        _loggingService.error(
          LogDomain.sync,
          e,
          stackTrace: st,
          subDomain: 'prune',
        );
      }
    }

    // Kickoff once on startup. Delay so init and first-send paths do
    // not contend with the DELETE. Stored in a field so `dispose()` can
    // cancel it if the service is torn down before the 30s elapses —
    // otherwise the one-shot callback would pin the service instance
    // past disposal (retained by the Timer) and, without the internal
    // `_isDisposed` short-circuit, would race a closed DB.
    _startupPruneTimer?.cancel();
    _startupPruneTimer = Timer(const Duration(seconds: 30), () {
      _startupPruneTimer = null;
      unawaited(runPrune());
    });
    _pruneTimer = Timer.periodic(SyncTuning.outboxPruneInterval, (_) {
      unawaited(runPrune());
    });

    _watchdogTimer?.cancel();
    _watchdogTimer = Timer.periodic(SyncTuning.outboxWatchdogInterval, (
      Timer _,
    ) async {
      if (_isDisposed) return;
      try {
        final loggedIn = _matrixService?.isLoggedIn() ?? true;
        if (!loggedIn) {
          _loggingService.log(
            LogDomain.sync,
            'watchdog.skip notLoggedIn',
            subDomain: 'watchdog',
          );
          return;
        }
        final hasPending = (await _repository.fetchPending(
          limit: 1,
        )).isNotEmpty;
        final idleQueue = _clientRunner.queueSize == 0;
        if (hasPending && loggedIn && idleQueue) {
          _loggingService.log(
            LogDomain.sync,
            'watchdog: pending+loggedIn idleQueue → enqueue',
            subDomain: 'watchdog',
          );
          unawaited(enqueueNextSendRequest(delay: Duration.zero));
        }
      } catch (e, st) {
        _loggingService.error(
          LogDomain.sync,
          e,
          stackTrace: st,
          subDomain: 'watchdog',
        );
      }
    });
  }

  /// Test seam for [_recordBackoff] — drives the zero/negative
  /// short-circuit and the monotonic-candidate logic directly.
  @visibleForTesting
  void debugRecordBackoff(Duration delay) => _recordBackoff(delay);

  /// Test seam pinning the backoff gate so [computeEnqueueDelay]'s
  /// past/future branches can be exercised without real waiting.
  @visibleForTesting
  DateTime? get debugNextSendAllowedAt => _nextSendAllowedAt;

  @visibleForTesting
  set debugNextSendAllowedAt(DateTime? value) => _nextSendAllowedAt = value;

  void _recordBackoff(Duration delay) {
    if (delay <= Duration.zero) return;
    final now = DateTime.now();
    _nextSendAllowedAt = extendBackoffGate(
      delay: delay,
      current: _nextSendAllowedAt,
      now: now,
    );
    _scheduleBackoffAt(_nextSendAllowedAt!);
  }

  void _scheduleBackoffAt(DateTime when) {
    if (_isDisposed) return;
    final scheduled = _backoffScheduledAt;
    if (scheduled != null && !when.isAfter(scheduled)) {
      return;
    }
    _backoffScheduledAt = when;
    final delay = when.difference(DateTime.now());
    unawaited(
      enqueueNextSendRequest(
        delay: delay.isNegative ? Duration.zero : delay,
      ),
    );
  }

  @visibleForTesting
  Duration computeEnqueueDelay(Duration delay) => resolveEnqueueDelay(
    requested: delay,
    nextAllowedAt: _nextSendAllowedAt,
    now: DateTime.now(),
  );

  Future<bool> _drainOutbox() async {
    for (var pass = 0; pass < _maxDrainPasses; pass++) {
      if (_isDisposed) return false;
      if (!_activityGate.canProcess) {
        _loggingService.log(
          LogDomain.sync,
          'drain.paused activityGate.canProcess=false',
          subDomain: 'activityGate',
        );
        _recordBackoff(SyncTuning.outboxRetryDelay);
        return false;
      }
      final result = await _processor.processQueue();
      if (!result.shouldSchedule) {
        // Queue appears drained for now.
        return true;
      }
      final delay = result.nextDelay ?? Duration.zero;
      if (delay == Duration.zero) {
        // Immediate continue to the next item.
        continue;
      }
      // Non-zero delay indicates retry/error backoff; schedule and exit.
      _recordBackoff(delay);
      return false;
    }

    // Reached pass cap; proactively schedule an immediate continuation to avoid
    // stalling large backlogs on environments where external nudges are rare.
    // We attempt to check for pending items for observability, but schedule the
    // follow-up regardless as a safety net.
    try {
      final stillPending = (await _repository.fetchPending(
        limit: 1,
      )).isNotEmpty;
      _loggingService.log(
        LogDomain.sync,
        'drain.passCap stillPending=$stillPending → enqueueImmediate',
        subDomain: 'drain',
      );
    } catch (_) {
      // best-effort logging only
    }
    await enqueueNextSendRequest(delay: Duration.zero);
    return false;
  }

  Future<void> sendNext() async {
    try {
      final enableMatrix = await _journalDb.getConfigFlag(
        enableMatrixFlag,
      );

      if (!enableMatrix) {
        return;
      }

      // State snapshot to aid debugging of stuck outbox scenarios. Only
      // log when the tuple changes (transitions matter, steady state does
      // not), or after a long quiet period so the line does not disappear
      // entirely when the state is stable. The `pending` probe is a DB
      // query, so skip it entirely on ticks where the cheaper
      // (loggedIn, canProc) pair is unchanged and the quiet window has
      // not elapsed.
      try {
        // When no Matrix service is wired (a custom `messageSender` was
        // injected instead), `sendNext` can still deliver, so treat the
        // absence as "logged in" for this diagnostic line. The actual
        // login-gate short-circuit below still uses the strict check.
        final loggedIn = _matrixService?.isLoggedIn() ?? true;
        final canProc = _activityGate.canProcess;
        final partialKey = 'li=$loggedIn cp=$canProc';
        final now = DateTime.now();
        final lastAt = _lastLoggedSendNextStateAt;
        final lastState = _lastLoggedSendNextState;
        final partialChanged =
            lastState == null || !lastState.startsWith('$partialKey ');
        final elapsedOk =
            lastAt == null ||
            now.difference(lastAt) >= _coalescedLogMinInterval;
        if (partialChanged || elapsedOk) {
          final hasPending = (await _repository.fetchPending(
            limit: 1,
          )).isNotEmpty;
          _lastLoggedSendNextState = '$partialKey p=$hasPending';
          _lastLoggedSendNextStateAt = now;
          _loggingService.log(
            LogDomain.sync,
            'sendNext.state loggedIn=$loggedIn canProcess=$canProc pending=$hasPending',
            subDomain: 'sendNext',
          );
        }
      } catch (_) {
        // best-effort only
      }

      // Pause processing while not logged in. Do not schedule immediate retries
      // from here to avoid spin while logged out. Normal triggers (enqueue,
      // connectivity regain, UI actions) will re-nudge the outbox after login.
      if (_matrixService != null && !_matrixService.isLoggedIn()) {
        _loggingService.log(
          LogDomain.sync,
          'sendNext.loginGate.notLoggedIn',
          subDomain: 'sendNext',
        );
        // Notify listeners only when meaningful and outside startup grace:
        // - There are pending outbox items
        // - We are past the initial startup window
        final withinGrace =
            clock.now().difference(_createdAt) < _loginGateStartupGrace;
        if (!withinGrace && !_loginGateEventsController.isClosed) {
          final hasPending = (await _repository.fetchPending(
            limit: 1,
          )).isNotEmpty;
          if (hasPending) {
            _loginGateEventsController.add(null);
          }
        }
        return;
      }

      final nextAllowed = _nextSendAllowedAt;
      final now = DateTime.now();
      if (nextAllowed != null) {
        if (now.isBefore(nextAllowed)) {
          _scheduleBackoffAt(nextAllowed);
          return;
        }
        _nextSendAllowedAt = null;
        _backoffScheduledAt = null;
      }

      // Drain the outbox in a single runner callback to avoid leaving the
      // latest item unsent (which can manifest as receivers being one behind).
      final firstDrained = await _drainOutbox();
      if (!firstDrained) return;

      // Allow recent enqueues to settle then attempt one more drain.
      await Future<void>.delayed(_postDrainSettle);
      if (_isDisposed) return;
      if (!_activityGate.canProcess) {
        _loggingService.log(
          LogDomain.sync,
          'sendNext.postSettle.paused activityGate.canProcess=false',
          subDomain: 'activityGate',
        );
        _recordBackoff(SyncTuning.outboxRetryDelay);
        return;
      }
      await _drainOutbox();
    } catch (exception, stackTrace) {
      _loggingService.error(
        LogDomain.sync,
        exception,
        stackTrace: stackTrace,
        subDomain: 'sendNext',
      );
      _recordBackoff(const Duration(seconds: 15));
    }
  }

  Future<void> enqueueNextSendRequest({
    Duration delay = const Duration(milliseconds: 1),
  }) async {
    if (_isDisposed) return;
    final adjustedDelay = computeEnqueueDelay(delay);
    unawaited(
      Future<void>.delayed(adjustedDelay).then((_) {
        if (_isDisposed) return;
        _clientRunner.enqueueRequest(DateTime.now().millisecondsSinceEpoch);
      }),
    );
  }
}

/// Max number of drain passes in a single sendNext before yielding.
const int _maxDrainPasses = 2000;

/// Startup grace before the not-logged-in gate notifies listeners.
const Duration _loginGateStartupGrace = Duration(seconds: 5);

/// Minimum interval between repeated coalesced observability logs.
const Duration _coalescedLogMinInterval = Duration(seconds: 30);
