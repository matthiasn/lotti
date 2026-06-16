part of 'outbox_enqueue_writer.dart';

/// Agent entity/link/payload enqueue and sent-record bookkeeping for
/// [OutboxEnqueueWriter]. Public extension so cross-library callers keep
/// invoking these on an [OutboxEnqueueWriter] instance.
extension OutboxEnqueueAgent on OutboxEnqueueWriter {
  // ---------------------------------------------------------------------------
  // Agent entity/link enqueue + sent-record bookkeeping
  // ---------------------------------------------------------------------------

  Future<bool> enqueueAgentEntity({
    required SyncAgentEntity msg,
    required OutboxCompanion commonFields,
  }) async {
    final entity = msg.agentEntity;
    if (entity == null) {
      _loggingService.log(
        LogDomain.sync,
        'enqueue.skip agentEntity is null',
        subDomain: 'enqueueMessage',
      );
      return false;
    }
    return enqueueAgentPayload(
      id: entity.id,
      payloadJson: json.encode(entity.toJson()),
      relativePath: relativeAgentEntityPath(entity.id),
      enrichedMessage: msg.copyWith(
        jsonPath: relativeAgentEntityPath(entity.id),
      ),
      subjectPrefix: 'agentEntity',
      typeName: 'SyncAgentEntity',
      commonFields: commonFields,
      vectorClock: entity.vectorClock,
      payloadType: SyncSequencePayloadType.agentEntity,
    );
  }

  Future<bool> enqueueAgentLink({
    required SyncAgentLink msg,
    required OutboxCompanion commonFields,
  }) async {
    final link = msg.agentLink;
    if (link == null) {
      _loggingService.log(
        LogDomain.sync,
        'enqueue.skip agentLink is null',
        subDomain: 'enqueueMessage',
      );
      return false;
    }
    return enqueueAgentPayload(
      id: link.id,
      payloadJson: json.encode(link.toJson()),
      relativePath: relativeAgentLinkPath(link.id),
      enrichedMessage: msg.copyWith(jsonPath: relativeAgentLinkPath(link.id)),
      subjectPrefix: 'agentLink',
      typeName: 'SyncAgentLink',
      commonFields: commonFields,
      vectorClock: link.vectorClock,
      payloadType: SyncSequencePayloadType.agentLink,
    );
  }

  /// Shared implementation for enqueuing agent entities and links.
  /// Saves [payloadJson] to disk, builds an enriched outbox message from
  /// [enrichedMessage], and either merges into an existing pending item or
  /// creates a new one. Records sent entries in the sequence log when a
  /// [vectorClock] is provided.
  Future<bool> enqueueAgentPayload({
    required String id,
    required String payloadJson,
    required String relativePath,
    required SyncMessage enrichedMessage,
    required String subjectPrefix,
    required String typeName,
    required OutboxCompanion commonFields,
    required VectorClock? vectorClock,
    required SyncSequencePayloadType payloadType,
  }) async {
    final relativeJoined = p.joinAll(
      relativePath.split('/').where((part) => part.isNotEmpty),
    );
    final docsRoot = p.normalize(_documentsDirectory.path);
    final fullPath = p.normalize(p.join(docsRoot, relativeJoined));
    final subject = '$subjectPrefix:$id';

    if (!p.isWithin(docsRoot, fullPath)) {
      _loggingService.log(
        LogDomain.sync,
        'enqueue.skip invalid agent payload path: $relativePath',
        subDomain: 'enqueueMessage',
      );
      return false;
    }

    try {
      await _saveJson(fullPath, payloadJson);
    } catch (error, stackTrace) {
      _loggingService.error(
        LogDomain.sync,
        error,
        stackTrace: stackTrace,
        subDomain: 'enqueueMessage.saveAgentPayload',
      );
      // Fallback: enqueue with inline payload so the sender's legacy
      // enrichment path can write the file and upload on retry.
      await _syncDatabase.addOutboxItem(
        commonFields.copyWith(
          subject: Value(subject),
          outboxEntryId: Value(id),
        ),
      );
      return false;
    }

    final existingItem = await _syncDatabase.findPendingByEntryId(id);

    if (existingItem != null) {
      // Merge: extract old VC and add to coveredVectorClocks so receivers
      // can mark the old counter as covered instead of creating a gap.
      var mergedMessage = enrichedMessage;
      try {
        final oldMessage = SyncMessage.fromJson(
          json.decode(existingItem.message) as Map<String, dynamic>,
        );

        final VectorClock? oldVc;
        final List<VectorClock>? oldCovered;
        if (oldMessage is SyncAgentEntity) {
          oldVc = oldMessage.agentEntity?.vectorClock;
          oldCovered = oldMessage.coveredVectorClocks;
        } else if (oldMessage is SyncAgentLink) {
          oldVc = oldMessage.agentLink?.vectorClock;
          oldCovered = oldMessage.coveredVectorClocks;
        } else {
          oldVc = null;
          oldCovered = null;
        }

        final List<VectorClock>? newCovered;
        if (mergedMessage case final SyncAgentEntity entity) {
          newCovered = entity.coveredVectorClocks;
        } else if (mergedMessage case final SyncAgentLink link) {
          newCovered = link.coveredVectorClocks;
        } else {
          newCovered = null;
        }

        final coveredClocks = VectorClock.mergeUniqueClocks([
          ...?oldCovered,
          ...?newCovered,
          oldVc,
          vectorClock,
        ]);

        if (mergedMessage case final SyncAgentEntity entity) {
          mergedMessage = entity.copyWith(
            coveredVectorClocks: coveredClocks,
          );
          logVectorClockAssignment(
            _loggingService,
            subDomain: 'enqueue.merge',
            action: 'assign',
            type: 'SyncAgentEntity',
            entryId: id,
            jsonPath: entity.jsonPath,
            reason: 'pending_merge_cover',
            previous: oldVc,
            assigned: vectorClock,
            coveredVectorClocks: coveredClocks,
          );
        } else if (mergedMessage case final SyncAgentLink link) {
          mergedMessage = link.copyWith(
            coveredVectorClocks: coveredClocks,
          );
          logVectorClockAssignment(
            _loggingService,
            subDomain: 'enqueue.merge',
            action: 'assign',
            type: 'SyncAgentLink',
            entryId: id,
            jsonPath: link.jsonPath,
            reason: 'pending_merge_cover',
            previous: oldVc,
            assigned: vectorClock,
            coveredVectorClocks: coveredClocks,
          );
        }

        final coveredVcStrings = coveredClocks?.map((vc) => vc.vclock).toList();
        _loggingService.log(
          LogDomain.sync,
          'enqueue MERGED type=$typeName id=$id '
          'coveredClocks=${coveredClocks?.length ?? 0} '
          'covered=$coveredVcStrings',
          subDomain: 'enqueueMessage',
        );
      } catch (e, st) {
        _loggingService
          ..error(
            LogDomain.sync,
            e,
            stackTrace: st,
            subDomain: 'enqueueMessage.agentMerge',
          )
          // Fallback: proceed without merging covered clocks
          ..log(
            LogDomain.sync,
            'enqueue MERGED type=$typeName id=$id (no VC merge)',
            subDomain: 'enqueueMessage',
          );
      }

      final mergedJson = json.encode(mergedMessage.toJson());
      final mergedSize = utf8.encode(mergedJson).length;
      final mergedPriority = math.min(
        existingItem.priority,
        commonFields.priority.value,
      );
      final affectedRows = await _syncDatabase.updateOutboxMessage(
        itemId: existingItem.id,
        newMessage: mergedJson,
        newSubject: subject,
        payloadSize: mergedSize,
        priority: mergedPriority,
      );

      if (affectedRows == 0) {
        // Row was no longer pending (sent or in-flight between lookup and
        // update). Insert a fresh row with the merged message so nothing is
        // lost.
        _loggingService.log(
          LogDomain.sync,
          'enqueue MERGE-MISS type=$typeName id=$id '
          '(row no longer pending, inserting fresh)',
          subDomain: 'enqueueMessage',
        );
        await _syncDatabase.addOutboxItem(
          commonFields.copyWith(
            subject: Value(subject),
            message: Value(mergedJson),
            payloadSize: Value(mergedSize),
            priority: Value(mergedPriority),
            outboxEntryId: Value(id),
          ),
        );
      }

      // Still record in sequence log for the new counter
      await recordAgentSent(
        entryId: id,
        vectorClock: vectorClock,
        payloadType: payloadType,
      );

      unawaited(_enqueueNextSendRequest(delay: const Duration(seconds: 1)));
      return true;
    }

    // Enrich covered VCs from the sequence log for already-sent predecessors.
    final initialCovered = switch (enrichedMessage) {
      final SyncAgentEntity e => e.coveredVectorClocks,
      final SyncAgentLink l => l.coveredVectorClocks,
      _ => null,
    };
    final enrichedAgentCovered = await enrichCoveredVcsFromSequenceLog(
      id,
      initialCovered,
    );
    var outboxAgentMsg = enrichedMessage;
    if (enrichedAgentCovered != initialCovered) {
      outboxAgentMsg = switch (outboxAgentMsg) {
        final SyncAgentEntity e => e.copyWith(
          coveredVectorClocks: enrichedAgentCovered,
        ),
        final SyncAgentLink l => l.copyWith(
          coveredVectorClocks: enrichedAgentCovered,
        ),
        _ => outboxAgentMsg,
      };
    }
    final outboxAgentJson = json.encode(outboxAgentMsg.toJson());
    final outboxAgentSize = utf8.encode(outboxAgentJson).length;
    await _syncDatabase.addOutboxItem(
      commonFields.copyWith(
        subject: Value(subject),
        message: Value(outboxAgentJson),
        outboxEntryId: Value(id),
        payloadSize: Value(outboxAgentSize),
      ),
    );
    _loggingService.log(
      LogDomain.sync,
      'enqueue type=$typeName subject=$subject',
      subDomain: 'enqueueMessage',
    );

    // Record in sequence log for backfill support (self-healing sync)
    await recordAgentSent(
      entryId: id,
      vectorClock: vectorClock,
      payloadType: payloadType,
    );

    return false;
  }

  /// Records an agent entity or link in the sequence log.
  Future<void> recordAgentSent({
    required String entryId,
    required VectorClock? vectorClock,
    required SyncSequencePayloadType payloadType,
  }) async {
    if (_sequenceLogService != null && vectorClock != null) {
      try {
        await _sequenceLogService.recordSentEntry(
          entryId: entryId,
          vectorClock: vectorClock,
          payloadType: payloadType,
        );
      } catch (e, st) {
        _loggingService.error(
          LogDomain.sync,
          e,
          stackTrace: st,
          subDomain: 'recordSent',
        );
      }
    }
  }

  Future<void> recordNotificationSent({
    required String entryId,
    required VectorClock vectorClock,
    required SyncSequencePayloadType payloadType,
  }) async {
    if (_sequenceLogService == null) return;
    try {
      await _sequenceLogService.recordSentEntry(
        entryId: entryId,
        vectorClock: vectorClock,
        payloadType: payloadType,
      );
    } catch (e, st) {
      _loggingService.error(
        LogDomain.sync,
        e,
        stackTrace: st,
        subDomain: 'recordSent',
      );
    }
  }
}
