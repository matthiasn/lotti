part of 'queue_pipeline_coordinator.dart';

/// Seals live arrivals once the real `/sync` loop has finished a response,
/// releasing the marker hold ([LiveAnchorHold]). `SyncEnd` and `SealDone` in
/// `specs/tla/InboundQueue.tla`.
///
/// The seal runs on [SyncStatus.cleaningUp] — or, conservatively, on
/// [SyncStatus.error] — because only `Client._sync` emits those statuses,
/// after the response's timeline events and its `onSync`. The SDK also runs
/// synthetic `handleSync` passes (a late Megolm key re-decrypting a room's
/// last event, history, send and redaction fake syncs) that emit
/// `processing` and `onSync` in the middle of a real response, with an
/// empty or a pagination `nextBatch`; none of them emits `cleaningUp`, so
/// none can release the hold without the response's `limited` flag.
extension QueueLiveSeal on QueuePipelineCoordinator {
  /// The arrival counter's own `onTimelineEvent` listener. It must not sit in
  /// the live handler's `asyncMap` chain: `asyncMap` pauses its upstream
  /// while a handler awaits I/O, and an event buffered there would be counted
  /// only after the response's seal, holding the marker until another
  /// `/sync` completes. This subscription is never paused, and the broadcast
  /// stream delivers every event to it before the response's `cleaningUp`.
  void _countLiveArrival(Event _) => _liveHold.noteArrival();

  /// `onSync` listener: remembers the room whose timeline was limited until
  /// the next seal claims it — the room that reported it, not whichever is
  /// current when the seal runs. A synthetic pass reporting it only causes an
  /// extra claim.
  void _observeSyncMetadata(SyncUpdate sync) {
    final roomId = _roomManager.currentRoomId;
    if (roomId != null &&
        sync.rooms?.join?[roomId]?.timeline?.limited == true) {
      _limitedRoomsSinceSeal.add(roomId);
    }
    _maybePostLoadCurrentRoom();
  }

  /// `onSyncStatus` listener: seals once per finished real response.
  void _observeSyncStatus(SyncStatusUpdate update) {
    switch (update.status) {
      case SyncStatus.cleaningUp:
        _scheduleSeal(conservative: false);
      case SyncStatus.error:
        // The response may have delivered part of a limited slice before
        // failing; its onSync never came to say so.
        _scheduleSeal(conservative: true);
      case SyncStatus.waitingForResponse:
      case SyncStatus.processing:
      case SyncStatus.finished:
        break;
    }
  }

  /// Snapshots what this seal covers — the arrivals, the current room and the
  /// rooms to claim, synchronously, so arrivals after this point wait for the
  /// next one — and runs it after any seal in flight.
  void _scheduleSeal({required bool conservative}) {
    final upTo = _liveHold.arrived;
    final generation = _liveHold.generation;
    final roomId = _roomManager.currentRoomId;
    final claimRooms = {
      ..._limitedRoomsSinceSeal,
      if (conservative && roomId != null) roomId,
    };
    _limitedRoomsSinceSeal.clear();
    final seal = _sealChain.then(
      (_) => _seal(
        roomId: roomId,
        claimRooms: claimRooms,
        upTo: upTo,
        generation: generation,
      ),
    );
    _sealChain = seal.catchError((Object _) {});
    _trackEnqueue(seal);
  }

  /// Claims the gap of every room in [claimRooms], or makes any retained
  /// claim or floor for [roomId] durable, then covers [upTo] and — when
  /// nothing newer arrived meanwhile — moves [roomId]'s marker over what
  /// settled while it was held. A failed claim or floor write leaves the
  /// arrivals unsealed, and the claims owed to the next seal.
  Future<void> _seal({
    required String? roomId,
    required Set<String> claimRooms,
    required int upTo,
    required int generation,
  }) async {
    try {
      for (final room in claimRooms) {
        await _claimCatchUpRange(room);
      }
      if (roomId != null && !claimRooms.contains(roomId)) {
        await _queue.ensureResumeFloorPersisted(roomId);
      }
    } catch (error, stackTrace) {
      _limitedRoomsSinceSeal.addAll(claimRooms);
      _logging.error(
        LogDomain.sync,
        error,
        stackTrace: stackTrace,
        subDomain: '$_logSub.seal',
      );
      return;
    }
    _liveHold.seal(upTo, generation: generation);
    if (roomId == null || !_liveHold.isSealed) return;
    try {
      await _queue.catchUpMarker(roomId);
    } catch (error, stackTrace) {
      // The next seal or commit moves the marker; nothing waits on it.
      _logging.error(
        LogDomain.sync,
        error,
        stackTrace: stackTrace,
        subDomain: '$_logSub.seal.catchUp',
      );
    }
  }
}
