part of 'queue_pipeline_coordinator.dart';

/// One SDK response's metadata barrier. Processing progress notifications
/// share a barrier; a later response may start while the prior claim awaits IO.
class _SyncBatch {
  final ready = Completer<void>();
  bool releasing = false;
}

extension QueueSyncBatch on QueuePipelineCoordinator {
  void _observeSyncStatus(SyncStatusUpdate update) {
    if (_syncIngressStopped) return;
    if (update.status == SyncStatus.processing) {
      if (_syncBatch == null || _syncBatch!.releasing) {
        final batch = _SyncBatch();
        _syncBatch = batch;
        _syncBatches.add(batch);
      }
      return;
    }
    // onSync normally releases the batch first. If we attached mid-response
    // or the SDK failed before emitting metadata, protect the unknown range
    // before releasing its events and request catch-up explicitly.
    if (update.status == SyncStatus.cleaningUp ||
        update.status == SyncStatus.finished ||
        update.status == SyncStatus.error) {
      final batch = _syncBatch;
      if (batch != null && !batch.releasing) {
        _trackEnqueue(
          _releaseSyncBatch(batch, claimGap: true, retryBridge: true),
        );
      }
    }
  }

  void _observeSyncMetadata(SyncUpdate sync) {
    if (_syncIngressStopped) return;
    final batch = _syncBatch;
    if (batch != null) {
      final roomId = _roomManager.currentRoomId;
      final limited = sync.rooms?.join?[roomId]?.timeline?.limited == true;
      _trackEnqueue(_releaseSyncBatch(batch, claimGap: limited));
    }
    _maybePostLoadCurrentRoom();
  }

  Future<void> _releaseSyncBatch(
    _SyncBatch batch, {
    required bool claimGap,
    bool retryBridge = false,
  }) async {
    if (batch.releasing) return;
    batch.releasing = true;
    try {
      final roomId = _roomManager.currentRoomId;
      if (claimGap && roomId != null) {
        await _claimCatchUpRange(roomId);
      }
    } catch (error, stackTrace) {
      // The queue retains failed claims and retries them before any insertion.
      _logging.error(
        LogDomain.sync,
        error,
        stackTrace: stackTrace,
        subDomain: '$_logSub.syncBatch.claim',
      );
    } finally {
      _syncBatches.remove(batch);
      if (identical(_syncBatch, batch)) _syncBatch = null;
      if (!batch.ready.isCompleted) batch.ready.complete();
    }
    if (retryBridge && !_syncIngressStopped) {
      unawaited(_safeStartupBridge());
    }
  }

  Future<void> _admitAfterSyncBatch(Event event) async {
    // asyncMap may already hold the first event when another response starts.
    // Recheck after each await so buffered events cannot cross a newer barrier.
    while (_syncBatches.isNotEmpty && !_syncIngressStopped) {
      await Future.wait(_syncBatches.map((batch) => batch.ready.future));
    }
    if (_syncIngressStopped) return;
    await _handleLiveEvent(event);
  }

  void _stopSyncBatchIngress() {
    _syncIngressStopped = true;
    // Drop held events without moving the durable marker. Startup catch-up
    // will recover them. Claims already writing remain tracked and are drained.
    for (final batch in _syncBatches) {
      if (!batch.ready.isCompleted) batch.ready.complete();
    }
    _syncBatches.clear();
    _syncBatch = null;
  }
}
