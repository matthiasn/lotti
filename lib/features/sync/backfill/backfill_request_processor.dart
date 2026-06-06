part of 'backfill_response_handler.dart';

/// Inbound backfill-request processing of [BackfillResponseHandler]:
/// decides what to re-send (full payload, hint, deleted, or
/// unresolvable) for journal, link, and agent entries. The class keeps a
/// thin [BackfillResponseHandler.handleBackfillRequest] delegator so
/// mocks keep intercepting the public API.
extension BackfillRequestProcessor on BackfillResponseHandler {
  /// Handle an incoming batched backfill request from another device.
  /// Iterates over all requested entries and for each:
  /// - If we have the entry: re-send it via normal sync
  /// - If the entry was deleted/purged: send a deleted response
  /// - If we don't have it in our log: ignore (another device may have it)
  ///
  /// Note: If backfill is disabled, requests are silently ignored to conserve
  /// bandwidth on metered/slow networks.
  Future<void> handleBackfillRequestImpl(SyncBackfillRequest request) async {
    try {
      // Skip our own backfill requests — they echo back via the Matrix room
      // after the SentEventRegistry TTL expires. Without this guard, we'd
      // process our own requests in a hot-loop.
      await _vectorClockService.initialized;
      final myHost = await _vectorClockService.getHost();
      if (myHost != null && request.requesterId == myHost) {
        _trace(
          'skipping own request (${request.entries.length} entries)',
          subDomain: 'backfill.skipSelf',
        );
        return;
      }

      // Check if backfill is enabled
      final enabled = await isBackfillEnabled();
      if (!enabled) {
        _trace(
          'backfill disabled, ignoring ${request.entries.length} entries from=${request.requesterId}',
          subDomain: 'backfill.disabled',
        );
        return;
      }

      // Clean expired cooldown entries at the start of each batch
      _cleanExpiredCooldowns();

      // Check rate limit before processing
      if (_isRateLimited()) {
        _trace(
          'rate limited, ignoring ${request.entries.length} entries from=${request.requesterId} ($responsesInWindow responses in current window)',
          subDomain: 'backfill.rateLimited',
        );
        return;
      }

      // Limit entries to process to prevent outbox flooding
      final entriesToProcess =
          request.entries.length > SyncTuning.maxBackfillResponseBatchSize
          ? request.entries
                .take(SyncTuning.maxBackfillResponseBatchSize)
                .toList()
          : request.entries;

      final truncated =
          request.entries.length > SyncTuning.maxBackfillResponseBatchSize;

      _trace(
        'handleRequest: processing ${entriesToProcess.length} of ${request.entries.length} entries from=${request.requesterId}${truncated ? ' (truncated)' : ''} cooldownCache=${recentlyResponded.length}',
        subDomain: 'backfill.request',
      );

      var responded = 0;
      var skipped = 0;
      var cooldownSkipped = 0;
      var rateLimitSkipped = 0;
      // Track payloads already sent in this batch to avoid sending the same
      // entry multiple times when multiple counters map to the same payload.
      final sentPayloads = <String>{};

      for (final entry in entriesToProcess) {
        // Skip if recently responded to this (hostId, counter)
        if (_isRecentlyResponded(entry.hostId, entry.counter)) {
          cooldownSkipped++;
          _trace(
            'cooldown skip hostId=${entry.hostId} counter=${entry.counter}',
            subDomain: 'backfill.cooldownSkip',
          );
          continue;
        }

        // Stop if rate limit reached mid-batch
        if (_isRateLimited()) {
          rateLimitSkipped =
              entriesToProcess.length - responded - skipped - cooldownSkipped;
          _trace(
            'rate limited, stopping batch. rateLimitSkipped=$rateLimitSkipped',
            subDomain: 'backfill.rateLimitStop',
          );
          break;
        }

        final result = await _processBackfillEntry(
          hostId: entry.hostId,
          counter: entry.counter,
          sentPayloads: sentPayloads,
        );
        if (result) {
          responded++;
          _recordResponse(entry.hostId, entry.counter);
          responsesInWindow++;
        } else {
          skipped++;
        }
      }

      _trace(
        'handleRequest: responded=$responded skipped=$skipped cooldownSkipped=$cooldownSkipped rateLimitSkipped=$rateLimitSkipped of ${request.entries.length} dedupedPayloads=${sentPayloads.length}',
        subDomain: 'backfill.request',
      );
    } catch (e, st) {
      _loggingService.error(
        LogDomain.sync,
        e,
        stackTrace: st,
        subDomain: 'handleRequest',
      );
    }
  }

  /// Process a single backfill entry request.
  /// Returns true if we responded, false if skipped.
  ///
  /// [sentPayloads] tracks payloads already sent in this batch to avoid
  /// sending the same entry multiple times when multiple counters map to
  /// the same payload.
  Future<bool> _processBackfillEntry({
    required String hostId,
    required int counter,
    required Set<String> sentPayloads,
  }) async {
    // Look up in our sequence log
    var logEntry = await _sequenceLogService.getEntryByHostAndCounter(
      hostId,
      counter,
    );

    // Own-host requests can ONLY be answered from a direct exact-match row
    // whose payload VC currently covers the requested counter. Covering by a
    // later entity is unsound for own-host burns: a burnt counter has no
    // recorded entity, so any "covering" candidate is necessarily a
    // DIFFERENT entity and its payload does not carry whatever the burnt
    // write would have mutated. Attributing that payload to the burnt
    // counter silently mis-maps state on the requester's side. For own-host
    // misses we therefore send `unresolvable` immediately — our sequence
    // log is authoritative for our own counters, so any miss is
    // definitively a burn.
    final myHost = await _vectorClockService.getHost();
    final isOwnHost = myHost != null && hostId == myHost;

    if (logEntry != null && logEntry.entryId != null) {
      final payloadType = SyncSequencePayloadType.values.elementAt(
        logEntry.payloadType,
      );
      final payloadVc = await _loadPayloadVectorClock(
        payloadId: logEntry.entryId!,
        payloadType: payloadType,
      );
      final vcCounter = payloadVc?.vclock[hostId];

      // An exact row is only safe to answer from when the current payload VC
      // still covers the requested counter. Otherwise the row is stale.
      if (payloadVc != null && (vcCounter == null || vcCounter < counter)) {
        _trace(
          'exact entry VC does not cover counter, rejecting '
          'hostId=$hostId requestedCounter=$counter '
          'logCounter=${logEntry.counter} payloadId=${logEntry.entryId} '
          'vcCounter=$vcCounter',
          subDomain: 'backfill.exactRejected',
        );
        if (isOwnHost) {
          // Own-host: do not attempt covering. The stale row means the VC
          // regressed or the payload is orphaned — either way, the
          // counter is unresolvable from our authoritative position.
          await _sendUnresolvableResponse(
            hostId: hostId,
            counter: counter,
            payloadType: payloadType,
          );
          return true;
        }
        logEntry = await _findVerifiedCoveringEntry(
          hostId: hostId,
          requestedCounter: counter,
          searchFromCounter: counter + 1,
        );

        if (logEntry == null) {
          return false;
        }
      }
    }

    if (logEntry == null || logEntry.entryId == null) {
      final payloadType = logEntry == null
          ? null
          : SyncSequencePayloadType.values.elementAt(logEntry.payloadType);
      _trace(
        'directLookup miss hostId=$hostId counter=$counter '
        'exists=${logEntry != null} entryId=${logEntry?.entryId} '
        'status=${logEntry?.status} payloadType=$payloadType',
        subDomain: 'backfill.directLookup',
      );

      if (isOwnHost) {
        // Burn: our sequence log has no entry for this own-host counter,
        // so no write ever carried it. Covering by a later (necessarily
        // different) entity would misattribute unrelated state to this
        // counter on the requester's side — always wrong for own-host
        // burns. Send unresolvable so the requester marks `status=5` and
        // skips the covering lookup entirely.
        _trace(
          'own-host miss → unresolvable (no covering attempted) '
          'hostId=$hostId counter=$counter payloadType=$payloadType',
          subDomain: 'backfill.unresolvable',
        );
        await _sendUnresolvableResponse(
          hostId: hostId,
          counter: counter,
          payloadType: payloadType,
        );
        return true;
      }

      // Foreign-host counter: we are only a relay, not the originator. A
      // best-effort covering hint can still help the requester close the
      // gap if the covering entity coincidentally matches; otherwise skip.
      final covering = await _findVerifiedCoveringEntry(
        hostId: hostId,
        requestedCounter: counter,
        searchFromCounter: counter,
      );

      if (covering != null) {
        logEntry = covering;
      } else {
        _trace(
          'foreign-host counter not found, skipping '
          'hostId=$hostId counter=$counter myHost=$myHost',
          subDomain: 'backfill.notFound',
        );
        return false;
      }
    }

    final resolvedLogEntry = logEntry;
    final payloadId = resolvedLogEntry.entryId!;
    final payloadType = SyncSequencePayloadType.values.elementAt(
      resolvedLogEntry.payloadType,
    );

    // Use the originatingHostId from the sequence log entry, or fall back to
    // the requested hostId.
    final originatingHostId = resolvedLogEntry.originatingHostId ?? hostId;

    _trace(
      'found logEntry hostId=$hostId counter=$counter '
      'payloadId=$payloadId payloadType=$payloadType '
      'logCounter=${resolvedLogEntry.counter} origHost=$originatingHostId',
      subDomain: 'backfill.found',
    );

    switch (payloadType) {
      case SyncSequencePayloadType.journalEntity:
        // Check if entry exists in journal
        final journalEntry = await _journalDb.journalEntityById(payloadId);

        if (journalEntry == null) {
          _trace(
            'journal entry deleted '
            'hostId=$hostId counter=$counter payloadId=$payloadId',
            subDomain: 'backfill.deleted',
          );
          await _sendDeletedResponse(
            hostId: hostId,
            counter: counter,
            payloadType: payloadType,
          );
          return true;
        }

        // Only send the entry if not already sent in this batch.
        // This avoids sending the same entry multiple times when multiple
        // requested counters map to the same payload.
        if (!sentPayloads.contains(payloadId)) {
          sentPayloads.add(payloadId);
          final jsonPath = relativeEntityPath(journalEntry);

          await _outboxService.enqueueMessage(
            SyncMessage.journalEntity(
              id: journalEntry.meta.id,
              jsonPath: jsonPath,
              vectorClock: journalEntry.meta.vectorClock,
              status: SyncEntryStatus.update,
              originatingHostId: originatingHostId,
            ),
          );
        }

        // Check if the entry's current VC contains the exact requested counter.
        // If yes, the entry arrival will automatically resolve this counter
        // via recordReceivedEntry, so we don't need to send a BackfillResponse.
        // Note: We check for exact match (==) not >= because recordReceivedEntry
        // only records counters that ARE in the VC, not historical counters.
        // This optimization significantly reduces redundant network traffic.
        final vcCounter = journalEntry.meta.vectorClock?.vclock[hostId];
        final vcContainsCounter = vcCounter != null && vcCounter == counter;

        if (!vcContainsCounter) {
          await _sendHintOrUnresolvable(
            hostId: hostId,
            counter: counter,
            payloadId: payloadId,
            payloadType: payloadType,
            vcCounter: vcCounter,
            legacyEntryId: payloadId,
          );
        }

        return true;
      case SyncSequencePayloadType.entryLink:
        final link = await _journalDb.entryLinkById(payloadId);

        if (link == null) {
          await _sendDeletedResponse(
            hostId: hostId,
            counter: counter,
            payloadType: payloadType,
          );
          return true;
        }

        // Only send the link if not already sent in this batch.
        if (!sentPayloads.contains(payloadId)) {
          sentPayloads.add(payloadId);

          await _outboxService.enqueueMessage(
            SyncMessage.entryLink(
              entryLink: link,
              status: SyncEntryStatus.update,
              originatingHostId: originatingHostId,
            ),
          );
        }

        // Check if the link's current VC contains the exact requested counter.
        // If yes, skip the BackfillResponse as entry arrival handles it.
        final vcCounter = link.vectorClock?.vclock[hostId];
        final vcContainsCounter = vcCounter != null && vcCounter == counter;

        if (!vcContainsCounter) {
          await _sendHintOrUnresolvable(
            hostId: hostId,
            counter: counter,
            payloadId: payloadId,
            payloadType: payloadType,
            vcCounter: vcCounter,
          );
        }

        return true;
      case SyncSequencePayloadType.agentEntity:
        if (agentRepository == null) {
          _trace(
            'agentRepository not wired, skipping agentEntity $payloadId',
            subDomain: 'backfill.processEntry',
          );
          return false;
        }
        return _processAgentBackfillEntry<AgentDomainEntity>(
          hostId: hostId,
          counter: counter,
          payloadId: payloadId,
          payloadType: payloadType,
          originatingHostId: originatingHostId,
          sentPayloads: sentPayloads,
          loadPayload: () => agentRepository!.getEntity(payloadId),
          getVectorClock: (entity) => entity.vectorClock,
          buildSyncMessage: (entity) => SyncMessage.agentEntity(
            status: SyncEntryStatus.update,
            agentEntity: entity,
            originatingHostId: originatingHostId,
          ),
          typeName: 'agentEntity',
        );
      case SyncSequencePayloadType.agentLink:
        if (agentRepository == null) {
          _trace(
            'agentRepository not wired, skipping agentLink $payloadId',
            subDomain: 'backfill.processEntry',
          );
          return false;
        }
        return _processAgentBackfillEntry<AgentLink>(
          hostId: hostId,
          counter: counter,
          payloadId: payloadId,
          payloadType: payloadType,
          originatingHostId: originatingHostId,
          sentPayloads: sentPayloads,
          loadPayload: () => agentRepository!.getLinkById(payloadId),
          getVectorClock: (link) => link.vectorClock,
          buildSyncMessage: (link) => SyncMessage.agentLink(
            status: SyncEntryStatus.update,
            agentLink: link,
            originatingHostId: originatingHostId,
          ),
          typeName: 'agentLink',
        );
      case SyncSequencePayloadType.notification:
        final db = _notificationsDb;
        if (db == null) {
          _trace(
            'notificationsDb not wired, skipping notification $payloadId',
            subDomain: 'backfill.processEntry',
          );
          return false;
        }
        final notification = await db.notificationById(payloadId);
        if (notification == null) {
          await _sendDeletedResponse(
            hostId: hostId,
            counter: counter,
            payloadType: payloadType,
          );
          return true;
        }

        if (!sentPayloads.contains(payloadId)) {
          sentPayloads.add(payloadId);
          await _outboxService.enqueueNotification(
            notification,
            originatingHostId: originatingHostId,
          );
        }

        final vcCounter = notification.meta.vectorClock.vclock[hostId];
        final vcContainsCounter = vcCounter != null && vcCounter == counter;

        if (!vcContainsCounter) {
          await _sendHintOrUnresolvable(
            hostId: hostId,
            counter: counter,
            payloadId: payloadId,
            payloadType: payloadType,
            vcCounter: vcCounter,
          );
        }

        return true;
      case SyncSequencePayloadType.notificationStateUpdate:
        final db = _notificationsDb;
        if (db == null) {
          _trace(
            'notificationsDb not wired, skipping notificationStateUpdate $payloadId',
            subDomain: 'backfill.processEntry',
          );
          return false;
        }
        final notification = await db.notificationById(payloadId);
        if (notification == null) {
          await _sendDeletedResponse(
            hostId: hostId,
            counter: counter,
            payloadType: payloadType,
          );
          return true;
        }

        if (!sentPayloads.contains('state:$payloadId')) {
          sentPayloads.add('state:$payloadId');
          await _outboxService.enqueueNotificationStateUpdate(
            id: notification.meta.id,
            seenAt: notification.meta.seenAt,
            actedOnAt: notification.meta.actedOnAt,
            deletedAt: notification.meta.deletedAt,
            vectorClock: notification.meta.vectorClock,
            originatingHostId: originatingHostId,
          );
        }

        final vcCounter = notification.meta.vectorClock.vclock[hostId];
        final vcContainsCounter = vcCounter != null && vcCounter == counter;

        if (!vcContainsCounter) {
          await _sendHintOrUnresolvable(
            hostId: hostId,
            counter: counter,
            payloadId: payloadId,
            payloadType: payloadType,
            vcCounter: vcCounter,
          );
        }

        return true;
    }
  }

  /// Shared helper for processing agent entity/link backfill entries.
  /// Follows the same pattern as journalEntity/entryLink cases.
  Future<bool> _processAgentBackfillEntry<T>({
    required String hostId,
    required int counter,
    required String payloadId,
    required SyncSequencePayloadType payloadType,
    required String originatingHostId,
    required Set<String> sentPayloads,
    required Future<T?> Function() loadPayload,
    required VectorClock? Function(T) getVectorClock,
    required SyncMessage Function(T) buildSyncMessage,
    required String typeName,
  }) async {
    final payload = await loadPayload();

    if (payload == null) {
      await _sendDeletedResponse(
        hostId: hostId,
        counter: counter,
        payloadType: payloadType,
      );
      return true;
    }

    if (!sentPayloads.contains(payloadId)) {
      sentPayloads.add(payloadId);
      await _outboxService.enqueueMessage(buildSyncMessage(payload));
    }

    final vc = getVectorClock(payload);
    final vcCounter = vc?.vclock[hostId];
    final vcContainsCounter = vcCounter != null && vcCounter == counter;

    if (!vcContainsCounter) {
      await _sendHintOrUnresolvable(
        hostId: hostId,
        counter: counter,
        payloadId: payloadId,
        payloadType: payloadType,
        vcCounter: vcCounter,
      );
    }

    return true;
  }
}
