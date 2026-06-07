part of 'sync_actor.dart';

/// Outbox drain machinery of [SyncActorCommandHandler]: retries,
/// transient sync pauses, queue kick/drain/dispose.
extension SyncActorOutbox on SyncActorCommandHandler {
  Future<T> _sendWithTransientSyncPause<T>(
    Future<T> Function() operation,
  ) async {
    final wasSyncing = _state == SyncActorState.syncing;
    if (!wasSyncing) {
      return operation();
    }

    await _pauseSyncLoopForSend();
    try {
      return await operation();
    } finally {
      if (_state == SyncActorState.syncing) {
        _gateway?.client.backgroundSync = true;
        await _startSyncStreamListening();
      }
    }
  }

  bool _isRetryableSqliteError(Object error) {
    final message = error.toString();
    return message.contains('SqliteException(21)') ||
        message.contains('SqliteFfiException') ||
        message.contains('bad parameter or other API misuse');
  }

  /// Test seam for [_runWithRetries] — exposes the retry/backoff loop for
  /// direct property testing.
  @visibleForTesting
  Future<T> debugRunWithRetries<T>(
    Future<T> Function() operation, {
    int maxRetries = 5,
    Duration? baseDelay,
    bool Function(Object)? isRetryable,
  }) => _runWithRetries(
    operation,
    maxRetries: maxRetries,
    baseDelay: baseDelay,
    isRetryable: isRetryable,
  );

  Future<T> _runWithRetries<T>(
    Future<T> Function() operation, {
    int maxRetries = 5,
    Duration? baseDelay,
    bool Function(Object)? isRetryable,
  }) async {
    final effectiveDelay = baseDelay ?? _retryBaseDelay;
    for (var attempt = 0; ; attempt++) {
      try {
        return await operation();
      } on Object catch (e, stackTrace) {
        if (isRetryable == null || !isRetryable(e)) {
          Error.throwWithStackTrace(e, stackTrace);
        }
        if (attempt >= maxRetries - 1) {
          Error.throwWithStackTrace(e, stackTrace);
        }

        await Future<void>.delayed(
          Duration(
            milliseconds: effectiveDelay.inMilliseconds * (1 << attempt),
          ),
        );
      }
    }
  }

  void _kickOutboxQueue({Duration delay = Duration.zero}) {
    if (_outboundQueue == null) {
      return;
    }

    _outboxPumpTimer?.cancel();
    _outboxPumpTimer = Timer(delay, () {
      unawaited(_drainOutboxQueue());
    });
  }

  Future<void> _drainOutboxQueue() async {
    final queue = _outboundQueue;
    if (queue == null || _outboxPumpActive) {
      return;
    }
    if (_state == SyncActorState.disposed ||
        _state == SyncActorState.stopping) {
      return;
    }

    _outboxPumpActive = true;
    try {
      while (true) {
        if (_outboundQueue == null ||
            _state == SyncActorState.disposed ||
            _state == SyncActorState.stopping) {
          return;
        }

        final nextDelay = await queue.drain();
        if (_outboundQueue == null ||
            _state == SyncActorState.disposed ||
            _state == SyncActorState.stopping) {
          return;
        }

        if (nextDelay == null) {
          return;
        }
        if (nextDelay != Duration.zero) {
          _kickOutboxQueue(delay: nextDelay);
          return;
        }
      }
    } finally {
      _outboxPumpActive = false;
    }
  }

  Future<void> _disposeOutboundQueue() async {
    _outboxPumpTimer?.cancel();
    _outboxPumpTimer = null;
    _outboxPumpActive = false;

    final queue = _outboundQueue;
    _outboundQueue = null;
    queue?.dispose();

    final db = _syncDatabase;
    _syncDatabase = null;
    await db?.close();
  }
}
