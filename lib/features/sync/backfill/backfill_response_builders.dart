part of 'backfill_response_handler.dart';

/// Response-building helpers for [BackfillResponseHandler]: send deleted /
/// unresolvable responses, load a payload's vector clock, find a verified
/// covering sequence-log entry, and send a covering hint (or fall back to
/// unresolvable). A private extension (not a helper class) because they use
/// the handler's private deps and are invoked from its public handle* methods.
extension _BackfillResponseBuilders on BackfillResponseHandler {
  /// Send a "deleted" backfill response indicating the payload no longer exists.
  Future<void> _sendDeletedResponse({
    required String hostId,
    required int counter,
    required SyncSequencePayloadType payloadType,
  }) async {
    await _outboxService.enqueueMessage(
      SyncMessage.backfillResponse(
        hostId: hostId,
        counter: counter,
        deleted: true,
        payloadType: payloadType,
      ),
    );
  }

  /// Send an "unresolvable" backfill response indicating the originating host
  /// cannot resolve its own counter (e.g., it was superseded before being
  /// recorded, burnt, or the payload VC regressed below the counter).
  ///
  /// Always called on our own host — the callers in [_processBackfillEntry]
  /// and [_sendHintOrUnresolvable] gate on `hostId == myHost`. Enqueue the
  /// outbound marker before terminalizing the local sequence row so a failed
  /// outbox write leaves a retryable reservation/miss instead of silently
  /// dropping the proactive repair signal.
  Future<void> _sendUnresolvableResponse({
    required String hostId,
    required int counter,
    SyncSequencePayloadType? payloadType,
  }) async {
    await _outboxService.enqueueMessage(
      SyncMessage.backfillResponse(
        hostId: hostId,
        counter: counter,
        deleted: false,
        unresolvable: true,
        payloadType: payloadType,
      ),
    );
    await _sequenceLogService.markOwnCounterUnresolvable(
      hostId: hostId,
      counter: counter,
      payloadType: payloadType ?? SyncSequencePayloadType.journalEntity,
    );

    _trace(
      'sendUnresolvableResponse hostId=$hostId counter=$counter payloadType=$payloadType',
      subDomain: 'backfill.unresolvable',
    );
  }

  /// Load the vector clock for a payload by type and ID.
  /// Used to verify covering entries before using them.
  Future<VectorClock?> _loadPayloadVectorClock({
    required String payloadId,
    required SyncSequencePayloadType payloadType,
  }) async {
    switch (payloadType) {
      case SyncSequencePayloadType.journalEntity:
        final entry = await _journalDb.journalEntityById(payloadId);
        return entry?.meta.vectorClock;
      case SyncSequencePayloadType.entryLink:
        final link = await _journalDb.entryLinkById(payloadId);
        return link?.vectorClock;
      case SyncSequencePayloadType.agentEntity:
        return (await agentRepository?.getEntity(payloadId))?.vectorClock;
      case SyncSequencePayloadType.agentLink:
        return (await agentRepository?.getLinkById(payloadId))?.vectorClock;
      case SyncSequencePayloadType.notification:
      case SyncSequencePayloadType.notificationStateUpdate:
        return (await _notificationsDb?.notificationById(
          payloadId,
        ))?.meta.vectorClock;
    }
  }

  Future<SyncSequenceLogItem?> _findVerifiedCoveringEntry({
    required String hostId,
    required int requestedCounter,
    required int searchFromCounter,
  }) async {
    var nextCounter = searchFromCounter;

    while (true) {
      final covering = await _sequenceLogService.getNearestCoveringEntry(
        hostId,
        nextCounter,
      );

      if (covering == null || covering.entryId == null) {
        return null;
      }

      final payloadType = SyncSequencePayloadType.values.elementAt(
        covering.payloadType,
      );
      final coveringVc = await _loadPayloadVectorClock(
        payloadId: covering.entryId!,
        payloadType: payloadType,
      );
      final coveringVcCounter = coveringVc?.vclock[hostId];

      if (coveringVcCounter != null && coveringVcCounter >= requestedCounter) {
        _trace(
          'using verified covering entry '
          'hostId=$hostId requestedCounter=$requestedCounter '
          'coveringCounter=${covering.counter} '
          'coveringVcCounter=$coveringVcCounter '
          'payloadId=${covering.entryId}',
          subDomain: 'backfill.coveringFallback',
        );
        return covering;
      }

      _trace(
        'covering entry VC does not cover counter, skipping to next '
        'hostId=$hostId requestedCounter=$requestedCounter '
        'coveringCounter=${covering.counter} '
        'payloadId=${covering.entryId} '
        'coveringVcCounter=$coveringVcCounter',
        subDomain: 'backfill.coveringRejected',
      );

      nextCounter = covering.counter + 1;
    }
  }

  /// When the VC doesn't contain the exact counter, decide whether to send
  /// a hint (VC is ahead, so the entry supersedes the counter) or an
  /// unresolvable response (VC is behind, so the mapping is permanently
  /// wrong and will never self-heal).
  Future<void> _sendHintOrUnresolvable({
    required String hostId,
    required int counter,
    required String payloadId,
    required SyncSequencePayloadType payloadType,
    required int? vcCounter,
    String? legacyEntryId,
  }) async {
    final myHost = await _vectorClockService.getHost();
    if (myHost != null &&
        hostId == myHost &&
        (vcCounter == null || vcCounter < counter)) {
      _trace(
        'VC permanently behind counter, sending unresolvable '
        'hostId=$hostId counter=$counter '
        'payloadId=$payloadId vcCounter=$vcCounter',
        subDomain: 'backfill.vcBehind',
      );
      await _sendUnresolvableResponse(
        hostId: hostId,
        counter: counter,
        payloadType: payloadType,
      );
      return;
    }

    await _outboxService.enqueueMessage(
      SyncMessage.backfillResponse(
        hostId: hostId,
        counter: counter,
        deleted: false,
        entryId: legacyEntryId,
        payloadType: payloadType,
        payloadId: payloadId,
      ),
    );
  }

  /// Attempt to verify a payload exists locally and mark as backfilled.
  /// Loads the payload using [loadPayload], extracts its vector clock using
  /// [getVectorClock], and verifies/marks backfilled if found.
  Future<void> _tryVerifyAndMarkBackfilled<T>({
    required String hostId,
    required int counter,
    required String payloadId,
    required SyncSequencePayloadType payloadType,
    required Future<T?> Function() loadPayload,
    required VectorClock? Function(T) getVectorClock,
    required String payloadTypeName,
  }) async {
    final payload = await loadPayload();

    if (payload != null) {
      final vc = getVectorClock(payload);
      if (vc != null) {
        await _sequenceLogService.verifyAndMarkBackfilled(
          hostId: hostId,
          counter: counter,
          entryId: payloadId,
          entryVectorClock: vc,
          payloadType: payloadType,
        );
      }
    } else {
      _trace(
        '$payloadTypeName $payloadId not found locally, hint stored for when payload arrives',
        subDomain: 'backfill.response',
      );
    }
  }
}

/// Per-(host, counter) response cooldown + global rate-limit bookkeeping for
/// [BackfillResponseHandler]. Private extension: reads/writes the handler's
/// `recentlyResponded` / window fields, used by its public handle* methods.
extension _BackfillCooldown on BackfillResponseHandler {
  /// Build the cooldown cache key for a (hostId, counter) pair.
  static String _cooldownKey(String hostId, int counter) => '$hostId:$counter';

  /// Check if a (hostId, counter) pair was recently responded to.
  /// Returns true if the pair is within the cooldown period.
  bool _isRecentlyResponded(String hostId, int counter) {
    final lastResponse = recentlyResponded[_cooldownKey(hostId, counter)];
    if (lastResponse == null) return false;
    return clock.now().difference(lastResponse) < _responseCooldown;
  }

  /// Record that a (hostId, counter) pair was responded to.
  void _recordResponse(String hostId, int counter) {
    recentlyResponded[_cooldownKey(hostId, counter)] = clock.now();
  }

  /// Periodically clean expired entries from the cooldown cache.
  /// Called at the start of each request batch.
  void _cleanExpiredCooldowns() {
    final now = clock.now();
    recentlyResponded.removeWhere(
      (_, timestamp) => now.difference(timestamp) >= _responseCooldown,
    );
  }

  /// Check if the rate limit has been reached for the current time window.
  bool _isRateLimited() {
    final now = clock.now();
    if (windowStart == null ||
        now.difference(windowStart!) >= SyncTuning.backfillResponseRateWindow) {
      // Start a new window
      windowStart = now;
      responsesInWindow = 0;
      return false;
    }
    return responsesInWindow >= SyncTuning.backfillResponseRateLimit;
  }
}
