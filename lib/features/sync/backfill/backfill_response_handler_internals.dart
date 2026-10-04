part of 'backfill_response_handler.dart';

/// Private helpers of [BackfillResponseHandler] that hold no state of their own; kept beside the class as an extension so the library stays readable.
extension _BackfillResponseHandlerInternals on BackfillResponseHandler {
  /// Log a backfill trace message to the sync domain logger (separate file).
  void _trace(String message, {String? subDomain}) {
    _domainLogger?.log(
      LogDomain.sync,
      message,
      subDomain: subDomain ?? 'backfill',
    );
  }

  bool _payloadStoreWired(SyncSequencePayloadType type) => switch (type) {
    SyncSequencePayloadType.journalEntity ||
    SyncSequencePayloadType.entryLink => true,
    SyncSequencePayloadType.agentEntity ||
    SyncSequencePayloadType.agentLink => _agentRepository != null,
    SyncSequencePayloadType.notification ||
    SyncSequencePayloadType.notificationStateUpdate => _notificationsDb != null,
    SyncSequencePayloadType.consumptionEvent => _consumptionRepository != null,
  };

  void _retrySettlementAwaitingStore() {
    if (!_settlementAwaitsStore) return;
    unawaited(
      settleOrphanedOwnCounters().catchError((
        Object error,
        StackTrace stackTrace,
      ) {
        _loggingService.error(
          LogDomain.sync,
          error,
          message: 'own counter settlement retry failed',
          stackTrace: stackTrace,
          subDomain: 'backfill.settle',
        );
      }),
    );
  }

  /// Answer a request for `(hostId, counter)` from the payload [entry] names:
  /// resend the payload (once per batch, tracked in [sentPayloads]) plus a
  /// mapping hint when the payload's clock does not carry the exact counter,
  /// or a `deleted` response when the payload is gone.
  ///
  /// With [durable], a failure to enqueue the payload propagates instead of
  /// being logged and swallowed, so settlement can bind the counter only once
  /// the resend is durably queued.
  Future<bool> _answerFromEntry({
    required String hostId,
    required int counter,
    required SyncSequenceLogItem entry,
    required Set<VcPayloadRef> sentPayloads,
    bool durable = false,
  }) async {
    final resolvedLogEntry = entry;
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
        // A soft-deleted entry is served like any version: a deletion the
        // requester lost must reach it (ADR 0083). So is a purge's tombstone
        // of one, which keeps the deletion's clock (ADR 0095). Only a row
        // that is gone altogether — purged by an older build — is answered
        // `deleted`.
        final journalEntry = await _journalDb.journalEntityByIdIncludingDeleted(
          payloadId,
        );

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
        if (!sentPayloads.contains((type: payloadType, id: payloadId))) {
          final jsonPath = relativeEntityPath(journalEntry);

          await _enqueuePayload(
            durable: durable,
            SyncMessage.journalEntity(
              id: journalEntry.meta.id,
              jsonPath: jsonPath,
              vectorClock: journalEntry.meta.vectorClock,
              status: SyncEntryStatus.update,
              originatingHostId: originatingHostId,
              // The requester is missing this entry entirely, so it is also
              // missing any media the entry references — send the blob with
              // the JSON rather than leaving an unrenderable entry behind.
              includeAttachments: true,
            ),
          );
          sentPayloads.add((type: payloadType, id: payloadId));
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
        if (!sentPayloads.contains((type: payloadType, id: payloadId))) {
          await _enqueuePayload(
            durable: durable,
            SyncMessage.entryLink(
              entryLink: link,
              status: SyncEntryStatus.update,
              originatingHostId: originatingHostId,
            ),
          );
          sentPayloads.add((type: payloadType, id: payloadId));
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
          durable: durable,
          loadPayload: () =>
              agentRepository!.getEntityIncludingDeleted(payloadId),
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
          durable: durable,
          loadPayload: () =>
              agentRepository!.getLinkByIdIncludingDeleted(payloadId),
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

        if (!sentPayloads.contains((type: payloadType, id: payloadId))) {
          await _outboxService.enqueueNotification(
            notification,
            originatingHostId: originatingHostId,
            rethrowFailure: durable,
          );
          sentPayloads.add((type: payloadType, id: payloadId));
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

        if (!sentPayloads.contains((type: payloadType, id: payloadId))) {
          await _outboxService.enqueueNotificationStateUpdate(
            id: notification.meta.id,
            seenAt: notification.meta.seenAt,
            actedOnAt: notification.meta.actedOnAt,
            deletedAt: notification.meta.deletedAt,
            vectorClock: notification.meta.vectorClock,
            originatingHostId: originatingHostId,
            rethrowFailure: durable,
          );
          sentPayloads.add((type: payloadType, id: payloadId));
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
      case SyncSequencePayloadType.consumptionEvent:
        if (consumptionRepository == null) {
          _trace(
            'consumptionRepository not wired, skipping consumptionEvent '
            '$payloadId',
            subDomain: 'backfill.processEntry',
          );
          return false;
        }
        // Reuses the generic agent-backfill helper (immutable payload, inline
        // re-enqueue) — the "Agent" name is historical; it is type-generic.
        return _processAgentBackfillEntry<AiConsumptionEvent>(
          hostId: hostId,
          counter: counter,
          payloadId: payloadId,
          payloadType: payloadType,
          originatingHostId: originatingHostId,
          sentPayloads: sentPayloads,
          durable: durable,
          loadPayload: () => consumptionRepository!.getEvent(payloadId),
          getVectorClock: (event) => event.vectorClock,
          buildSyncMessage: (event) => SyncMessage.consumptionEvent(
            status: SyncEntryStatus.update,
            event: event,
            originatingHostId: originatingHostId,
          ),
          typeName: 'consumptionEvent',
        );
    }
  }
}
