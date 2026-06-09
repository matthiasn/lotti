part of 'queue_pipeline_coordinator.dart';

/// Start / drain / stop lifecycle of [QueuePipelineCoordinator]. Extracted
/// into a part-file extension to keep the coordinator under the size limit;
/// the class keeps thin public delegators so mocks keep intercepting them.
extension QueueLifecycle on QueuePipelineCoordinator {
  /// Implementation of [QueuePipelineCoordinator.start]; see [QueueLifecycle].
  Future<void> startImpl() async {
    if (_started) return;

    final roomId = _roomManager.currentRoomId;
    if (roomId != null) {
      // Seed + prune are best-effort one-shots. If they throw (e.g. a
      // transient SQLite error) the worker + bridge should still come
      // up — next call to `start()` re-runs seed/prune, and a future
      // session sweep can catch up. A throw that aborts `start()`
      // would leave `_started = false` and every subsequent caller
      // would get the same behaviour; swallow-and-log keeps the
      // pipeline from being dead-in-the-water.
      try {
        await _seeder.seedIfAbsent(roomId);
        await _queue.pruneStrandedEntries(roomId);
      } catch (error, stackTrace) {
        _logging.error(
          LogDomain.sync,
          error,
          stackTrace: stackTrace,
          subDomain: '$_logSub.start.seed',
        );
      }
    } else {
      _logging.log(
        LogDomain.sync,
        'queue.coordinator.start.noRoom',
        subDomain: _logSub,
      );
    }

    // Flip `_started` only after the live subscription, bridge and
    // worker are fully attached, so a throw from any of them leaves
    // the coordinator in the "not started" state and a caller can
    // retry `start()`. The unwind catch below mops up whatever did
    // come up before the failure.
    try {
      _liveSub = _sessionManager.timelineEvents.listen(_handleLiveEvent);
      // Subscribe to onSync so we can un-partial the current room
      // (via `room.postLoad()`) the first time we see it. Without
      // this, Matrix SDK skips `RoomMember` state events on partial
      // rooms — so `_trackedUserIds` never grows to include new
      // joiners, `updateUserDeviceKeys` never queries their keys,
      // and SAS / E2EE cannot discover them. The legacy signal
      // binder relied on `room.getTimeline(onNewEvent: …)` for this
      // side effect; the queue pipeline replicates the un-partial
      // step on its own, independent of timeline subscriptions.
      _syncSub = _sessionManager.client.onSync.stream.listen(
        (_) => _maybePostLoadCurrentRoom(),
        onError: (Object error, StackTrace stackTrace) {
          _logging.error(
            LogDomain.sync,
            error,
            stackTrace: stackTrace,
            subDomain: '$_logSub.syncSub',
          );
        },
      );
      _bridge.start();
      await _worker.start();
      // Signal-driven resurrection of abandoned ledger rows. These
      // subscriptions convert out-of-band events (attachment JSON
      // landed, journal-db entry updated) into `resurrect*` calls so
      // a row that was retired by the worker's retry cap becomes
      // drainable again the instant its blocking dependency is
      // available — no polling, no user action required for the
      // common cases.
      _attachmentPathSub = _attachmentIndex?.pathRecorded.listen(
        _onAttachmentPathRecorded,
        onError: (Object error, StackTrace stackTrace) {
          _logging.error(
            LogDomain.sync,
            error,
            stackTrace: stackTrace,
            subDomain: '$_logSub.pathRecorded',
          );
        },
      );
      _journalUpdateSub = _updateNotifications?.updateStream.listen(
        (_) async {
          try {
            await _queue.resurrectByReason('missingBase');
          } catch (error, stackTrace) {
            _logging.error(
              LogDomain.sync,
              error,
              stackTrace: stackTrace,
              subDomain: '$_logSub.resurrectByReason',
            );
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          _logging.error(
            LogDomain.sync,
            error,
            stackTrace: stackTrace,
            subDomain: '$_logSub.journalUpdates',
          );
        },
      );
      _started = true;
      // Phase-2 equivalent of the legacy pipeline's 300 ms startup
      // `forceRescan`. `connect()` runs before `_maybeStartQueuePipeline`
      // in `MatrixService.init`, so events delivered during the login
      // round trip land on a coordinator that was not yet subscribed.
      // The bridge otherwise only fires on organic `limited=true` syncs;
      // on reconnects where the server does not flag the timeline as
      // limited, those events would be silently missed. Fire-and-forget
      // so `start()` does not block on a slow /messages walk.
      if (roomId != null) {
        unawaited(_safeStartupBridge());
      }
    } catch (error, stackTrace) {
      _logging.error(
        LogDomain.sync,
        error,
        stackTrace: stackTrace,
        subDomain: '$_logSub.start',
      );
      await _liveSub?.cancel();
      _liveSub = null;
      await _syncSub?.cancel();
      _syncSub = null;
      await _attachmentPathSub?.cancel();
      _attachmentPathSub = null;
      _attachmentPathFlushTimer?.cancel();
      _attachmentPathFlushTimer = null;
      _pendingPathResurrections.clear();
      // Wait for any flush already in flight before tearing the
      // queue down further — `resurrectByPaths` opens a writer
      // transaction and we must not race it against `_queue` /
      // `_worker` disposal on the error path.
      final pendingFlush = _attachmentPathFlushInFlight;
      _attachmentPathFlushInFlight = null;
      if (pendingFlush != null) {
        try {
          await pendingFlush;
        } catch (_) {
          // Already logged on the flush side.
        }
      }
      await _journalUpdateSub?.cancel();
      _journalUpdateSub = null;
      try {
        await _bridge.stop();
      } catch (_) {
        // Already logged on the bridge side; no recovery available.
      }
      try {
        await _worker.stop();
      } catch (_) {
        // Same: log-and-continue so unwind always completes.
      }
      rethrow;
    }

    _logging.log(
      LogDomain.sync,
      'queue.coordinator.started roomId=${roomId ?? 'null'}',
      subDomain: _logSub,
    );
  }

  /// Implementation of [QueuePipelineCoordinator.drainUntilEmpty]; see [QueueLifecycle].
  /// Drains the queue until every persisted row has applied (or has
  /// been permanently skipped), or the [timeout] elapses.
  ///
  /// Unlike [InboundWorker.drainToCompletion], this does sleep through
  /// retry leases and pen attempts: the F7 contract of
  /// `stop(drainFirst: true)` is "don't strand rows on restart", so a
  /// single ready-at-call-time pass is not enough. Rows with a future
  /// `nextDueAt`/`leaseUntil`, rows held by [PendingDecryptionPen], and
  /// rows the worker is currently looping through a `noRoom` retry on
  /// all survive a single `drainToCompletion()` — this loop closes that
  /// gap by flushing the pen, sleeping until the next ready timestamp,
  /// and re-peeking until the queue is empty or time runs out.
  Future<void> drainUntilEmptyImpl({Duration? timeout}) async {
    final deadline = clock.now().add(
      timeout ?? QueuePipelineCoordinator.drainUntilEmptyTimeout,
    );
    while (true) {
      // 1. Flush the pen first so any event the SDK has decrypted
      //    since the last sweep lands in the queue before we ask it
      //    for stats — otherwise the loop can declare the queue empty
      //    while held events are waiting to enter it.
      final room = await _resolveRoom();
      if (room != null) {
        try {
          await _pen.flushInto(queue: _queue, room: room);
        } catch (error, stackTrace) {
          _logging.error(
            LogDomain.sync,
            error,
            stackTrace: stackTrace,
            subDomain: '$_logSub.drainUntilEmpty.pen',
          );
        }
      }

      // 2. Apply every row that is ready right now.
      try {
        await _worker.drainToCompletion();
      } catch (error, stackTrace) {
        _logging.error(
          LogDomain.sync,
          error,
          stackTrace: stackTrace,
          subDomain: '$_logSub.drainUntilEmpty.drain',
        );
      }

      final stats = await _queue.stats();
      if (stats.total == 0 && _pen.size == 0) {
        _logging.log(
          LogDomain.sync,
          'queue.coordinator.drainUntilEmpty.done',
          subDomain: _logSub,
        );
        return;
      }

      final remaining = deadline.difference(clock.now());
      if (!remaining.isNegative && remaining > Duration.zero) {
        // Prefer the queue's own scheduling signal over a fixed poll.
        final readyAtMs = await _queue.earliestReadyAt();
        Duration wait;
        if (readyAtMs == null) {
          // Nothing in the queue but the pen is non-empty — the pen has
          // its own sweep interval, so back off for a short tick and
          // re-flush rather than busy-loop.
          wait = const Duration(milliseconds: 200);
        } else {
          final nowMs = clock.now().millisecondsSinceEpoch;
          wait = Duration(milliseconds: math.max(0, readyAtMs - nowMs));
        }
        final capped = wait > remaining ? remaining : wait;
        if (capped > Duration.zero) {
          await Future<void>.delayed(capped);
        }
      }

      if (!clock.now().isBefore(deadline)) {
        _logging.log(
          LogDomain.sync,
          'queue.coordinator.drainUntilEmpty.timeout '
          'remaining=${stats.total} penSize=${_pen.size}',
          subDomain: _logSub,
        );
        return;
      }
    }
  }

  /// Implementation of [QueuePipelineCoordinator.stop]; see [QueueLifecycle].
  /// Stops every collaborator in the reverse order they were started.
  /// If [drainFirst] is true (the flag-off flow), the coordinator waits
  /// until the persisted queue is empty (bounded by
  /// [drainUntilEmptyTimeout]) before tearing down — this closes the F7
  /// data-loss hole the design review flagged. Unlike the legacy
  /// "drain ready rows once" primitive, rows with future retry leases,
  /// decryption-pending rows, and rows stuck in the noRoom loop are all
  /// waited out up to the timeout.
  ///
  /// Every teardown step is wrapped in its own try/catch so a throw
  /// from one stage cannot orphan the stages that follow. `_started`
  /// is flipped only after the full best-effort cleanup so a thrown
  /// teardown leaves the coordinator in a state a caller can retry
  /// `stop()` against, rather than a half-dismantled one where the
  /// second `stop()` is a no-op.
  Future<void> stopImpl({bool drainFirst = false}) async {
    if (!_started) return;

    Future<void> tryRun(
      String stage,
      Future<void> Function() action,
    ) async {
      try {
        await action();
      } catch (error, stackTrace) {
        _logging.error(
          LogDomain.sync,
          error,
          stackTrace: stackTrace,
          subDomain: '$_logSub.stop.$stage',
        );
      }
    }

    try {
      await tryRun('liveSub', () async {
        await _liveSub?.cancel();
        _liveSub = null;
      });
      await tryRun('syncSub', () async {
        await _syncSub?.cancel();
        _syncSub = null;
      });
      await tryRun('attachmentPathSub', () async {
        await _attachmentPathSub?.cancel();
        _attachmentPathSub = null;
        // Cancel the debounce timer so no new flush is scheduled, and
        // drop the still-pending accumulator since the subscription is
        // gone. Any flush *already in flight* is awaited below so its
        // `resurrectByPaths` writer transaction settles before
        // `_queue` / `_worker` disposal — otherwise teardown can race
        // a flush still mid-transaction and trip drift's "used after
        // close" guard.
        _attachmentPathFlushTimer?.cancel();
        _attachmentPathFlushTimer = null;
        _pendingPathResurrections.clear();
      });
      final pendingPathFlush = _attachmentPathFlushInFlight;
      _attachmentPathFlushInFlight = null;
      if (pendingPathFlush != null) {
        await tryRun(
          'attachmentPathFlush',
          () async => pendingPathFlush,
        );
      }
      await tryRun('journalUpdateSub', () async {
        await _journalUpdateSub?.cancel();
        _journalUpdateSub = null;
      });
      // Wait for fire-and-forget enqueues spawned from the now-
      // cancelled subscription before we tear the queue down.
      if (_inFlightEnqueues.isNotEmpty) {
        await tryRun(
          'inFlightEnqueues',
          () async => Future.wait(_inFlightEnqueues.toList()),
        );
      }
      await tryRun('bridge', _bridge.stop);

      final gapRecovery = _gapRecoveryInFlight;
      if (gapRecovery != null) {
        await tryRun('gapRecovery', () async => gapRecovery);
      }

      if (drainFirst) {
        await tryRun('drain', drainUntilEmpty);
      }

      await tryRun('worker', _worker.stop);
      await tryRun('pen', _pen.stop);
      await tryRun('queue', _queue.dispose);
    } finally {
      _started = false;
    }

    _logging.log(
      LogDomain.sync,
      'queue.coordinator.stopped drainFirst=$drainFirst',
      subDomain: _logSub,
    );
  }
}
