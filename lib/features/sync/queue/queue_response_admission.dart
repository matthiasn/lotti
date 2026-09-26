part of 'queue_pipeline_coordinator.dart';

/// Admits the payloads of one complete SDK response after claiming its gap.
/// Attachment descriptors remain on the immediate timeline path. A synthetic
/// SDK update can therefore neither release nor hold another response's events.
extension QueueResponseAdmission on QueuePipelineCoordinator {
  void _admitSyncResponse(SyncUpdate sync) {
    _maybePostLoadCurrentRoom();
    final roomId = _roomManager.currentRoomId;
    if (roomId == null) return;
    final timeline = sync.rooms?.join?[roomId]?.timeline;
    if (timeline == null || (timeline.events?.isEmpty ?? true)) return;
    // Snapshot before another SDK pass or a queued response mutates content.
    final events = [
      for (final event in timeline.events ?? <MatrixEvent>[])
        MatrixEvent.fromJson(
          jsonDecode(jsonEncode(event.toJson())) as Map<String, dynamic>,
        ),
    ];
    final limited = timeline.limited == true;
    final admission = _syncAdmissionTail.then((_) async {
      if (_roomManager.currentRoomId != roomId) return;
      if (limited) await _claimCatchUpRange(roomId);
      final room = await _resolveRoom();
      if (room == null || room.id != roomId) {
        // Keep the whole uncaptured response recoverable if room resolution
        // is temporarily unavailable; no payload may move the anchor past it.
        await _claimCatchUpRange(roomId);
        return;
      }
      for (final raw in events) {
        if (_roomManager.currentRoomId != roomId) return;
        var event = Event.fromMatrixEvent(raw, room);
        // SDK local echoes also emit onSync; never decrypt or admit them.
        if (event.status != EventStatus.synced) continue;
        if (event.type == EventTypes.Encrypted) {
          final encryption = _sessionManager.client.encryption;
          if (encryption != null) {
            event = await encryption.decryptRoomEvent(event);
          }
        }
        // The SDK already emitted descriptors on its timeline stream. Only
        // payloads (or a still-unresolved ciphertext floor) belong here.
        if (event.type == EventTypes.Encrypted ||
            MatrixEventClassifier.isSyncPayloadEvent(event)) {
          await _handleLiveEvent(event);
        }
      }
    });
    _syncAdmissionTail = admission.catchError((
      Object error,
      StackTrace stack,
    ) async {
      _logging.error(
        LogDomain.sync,
        error,
        stackTrace: stack,
        subDomain: '$_logSub.responseAdmission',
      );
      // A failed response may have more events after the failing decrypt or
      // room lookup. Keep its entire range recoverable before the next
      // response can enqueue anything. lowerResumeFloor retains a failed
      // write in memory and retries it before any later queue insertion.
      final oldest = events
          .map((event) => event.originServerTs.millisecondsSinceEpoch)
          .reduce(math.min);
      try {
        await _queue.lowerResumeFloor(roomId: roomId, originTs: oldest);
      } catch (floorError, floorStack) {
        _logging.error(
          LogDomain.sync,
          floorError,
          stackTrace: floorStack,
          subDomain: '$_logSub.responseAdmission.floor',
        );
      }
      if (_roomManager.currentRoomId == roomId) {
        unawaited(
          _bridge.bridgeNow().catchError((
            Object repairError,
            StackTrace repairStack,
          ) {
            _logging.error(
              LogDomain.sync,
              repairError,
              stackTrace: repairStack,
              subDomain: '$_logSub.responseAdmission.repair',
            );
          }),
        );
      }
    });
    _trackEnqueue(_syncAdmissionTail);
  }
}
