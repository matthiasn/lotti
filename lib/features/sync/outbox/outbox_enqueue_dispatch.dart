part of 'outbox_service.dart';

/// Enqueue dispatch of [OutboxService]: per-message-type preparation and
/// persistence helpers behind [OutboxService.enqueueMessage]. All members
/// are library-private, so no mock delegators are required.
extension OutboxEnqueueDispatch on OutboxService {
  /// Prepares a SyncJournalEntity by adding originatingHostId, attaching entry
  /// links, and merging covered vector clocks.
  Future<SyncJournalEntity> _prepareJournalEntity(
    SyncJournalEntity msg,
    String? host,
  ) async {
    var journalMsg = msg;

    // Add originating host ID (this device) for sequence tracking
    if (journalMsg.originatingHostId == null && host != null) {
      journalMsg = journalMsg.copyWith(originatingHostId: host);
    }

    // Attach entry links if available
    try {
      final links = await _journalDb.linksForEntryIdsBidirectional({
        journalMsg.id,
      });
      if (links.isNotEmpty) {
        final fromCount = links
            .where((link) => link.fromId == journalMsg.id)
            .length;
        final toCount = links
            .where((link) => link.toId == journalMsg.id)
            .length;
        // Cap embedded links to prevent oversized envelopes. Remaining
        // links still sync independently as SyncEntryLink messages.
        final capped = links.length > SyncTuning.maxEmbeddedEntryLinks
            ? links.sublist(links.length - SyncTuning.maxEmbeddedEntryLinks)
            : links;
        _loggingService.log(
          LogDomain.sync,
          'enqueueMessage.attachedLinks id=${journalMsg.id} '
          'count=${links.length} embedded=${capped.length} '
          'from=$fromCount to=$toCount',
          subDomain: 'enqueueMessage.attachLinks',
        );
        journalMsg = journalMsg.copyWith(entryLinks: capped);
      } else {
        _loggingService.log(
          LogDomain.sync,
          'enqueueMessage.noLinks id=${journalMsg.id}',
          subDomain: 'enqueueMessage.attachLinks',
        );
      }
    } catch (e, st) {
      _loggingService.error(
        LogDomain.sync,
        e,
        stackTrace: st,
        subDomain: 'enqueueMessage.fetchLinks',
      );
      // Continue with original message without links on error
    }

    final coveredClocks = VectorClock.mergeUniqueClocks([
      ...?journalMsg.coveredVectorClocks,
      journalMsg.vectorClock,
    ]);
    if (coveredClocks != journalMsg.coveredVectorClocks) {
      journalMsg = journalMsg.copyWith(coveredVectorClocks: coveredClocks);
      logVectorClockAssignment(
        _loggingService,
        subDomain: 'prepare.ensureCovered',
        action: 'assign',
        type: 'SyncJournalEntity',
        entryId: journalMsg.id,
        jsonPath: journalMsg.jsonPath,
        reason: 'ensure_current_clock_covered',
        assigned: journalMsg.vectorClock,
        coveredVectorClocks: coveredClocks,
      );
    }

    return journalMsg;
  }

  /// Prepares a SyncEntryLink by adding originatingHostId and merging covered
  /// vector clocks.
  Future<SyncEntryLink> _prepareEntryLink(
    SyncEntryLink msg,
    String? host,
  ) async {
    var linkMsg = msg;
    if (linkMsg.originatingHostId == null && host != null) {
      linkMsg = linkMsg.copyWith(originatingHostId: host);
    }
    final coveredClocks = VectorClock.mergeUniqueClocks([
      ...?linkMsg.coveredVectorClocks,
      linkMsg.entryLink.vectorClock,
    ]);
    if (coveredClocks != linkMsg.coveredVectorClocks) {
      linkMsg = linkMsg.copyWith(coveredVectorClocks: coveredClocks);
      logVectorClockAssignment(
        _loggingService,
        subDomain: 'prepare.ensureCovered',
        action: 'assign',
        type: 'SyncEntryLink',
        entryId: linkMsg.entryLink.id,
        reason: 'ensure_current_clock_covered',
        assigned: linkMsg.entryLink.vectorClock,
        coveredVectorClocks: coveredClocks,
      );
    }
    return linkMsg;
  }

  /// Prepares a SyncAgentEntity by adding originatingHostId and merging covered
  /// vector clocks.
  SyncAgentEntity _prepareAgentEntity(SyncAgentEntity msg, String? host) {
    var agentMsg = msg;
    if (agentMsg.originatingHostId == null && host != null) {
      agentMsg = agentMsg.copyWith(originatingHostId: host);
    }
    final vc = agentMsg.agentEntity?.vectorClock;
    final coveredClocks = VectorClock.mergeUniqueClocks([
      ...?agentMsg.coveredVectorClocks,
      vc,
    ]);
    if (coveredClocks != agentMsg.coveredVectorClocks) {
      agentMsg = agentMsg.copyWith(coveredVectorClocks: coveredClocks);
      logVectorClockAssignment(
        _loggingService,
        subDomain: 'prepare.ensureCovered',
        action: 'assign',
        type: 'SyncAgentEntity',
        entryId: agentMsg.agentEntity?.id,
        jsonPath: agentMsg.jsonPath,
        reason: 'ensure_current_clock_covered',
        assigned: vc,
        coveredVectorClocks: coveredClocks,
      );
    }
    return agentMsg;
  }

  /// Prepares a SyncAgentLink by adding originatingHostId and merging covered
  /// vector clocks.
  SyncAgentLink _prepareAgentLink(SyncAgentLink msg, String? host) {
    var linkMsg = msg;
    if (linkMsg.originatingHostId == null && host != null) {
      linkMsg = linkMsg.copyWith(originatingHostId: host);
    }
    final vc = linkMsg.agentLink?.vectorClock;
    final coveredClocks = VectorClock.mergeUniqueClocks([
      ...?linkMsg.coveredVectorClocks,
      vc,
    ]);
    if (coveredClocks != linkMsg.coveredVectorClocks) {
      linkMsg = linkMsg.copyWith(coveredVectorClocks: coveredClocks);
      logVectorClockAssignment(
        _loggingService,
        subDomain: 'prepare.ensureCovered',
        action: 'assign',
        type: 'SyncAgentLink',
        entryId: linkMsg.agentLink?.id,
        jsonPath: linkMsg.jsonPath,
        reason: 'ensure_current_clock_covered',
        assigned: vc,
        coveredVectorClocks: coveredClocks,
      );
    }
    return linkMsg;
  }

  /// Routes message preparation based on type.
  Future<SyncMessage> _prepareMessage(SyncMessage message, String? host) async {
    return switch (message) {
      final SyncJournalEntity msg => await _prepareJournalEntity(msg, host),
      final SyncEntryLink msg => await _prepareEntryLink(msg, host),
      final SyncAgentEntity msg => _prepareAgentEntity(msg, host),
      final SyncAgentLink msg => _prepareAgentLink(msg, host),
      final SyncConfigFlag msg =>
        msg.originatingHostId == null && host != null
            ? msg.copyWith(originatingHostId: host)
            : msg,
      _ => message,
    };
  }

  // ---------------------------------------------------------------------------
  // Per-type enqueue helpers
  // ---------------------------------------------------------------------------

  /// Enqueues a SyncJournalEntity. Returns true if merge happened (caller
  /// should not call enqueueNextSendRequest again).
  Future<bool> _enqueueJournalEntity({
    required SyncJournalEntity msg,
    required OutboxCompanion commonFields,
    required String? host,
    required String? hostHash,
  }) async {
    // Refresh JSON from DB before reading descriptor
    try {
      final latest = await _journalDb.journalEntityById(msg.id);
      if (latest != null) {
        final canonicalPath = entityPath(latest, _documentsDirectory);
        await _saveJson(canonicalPath, jsonEncode(latest));
      } else {
        _loggingService.log(
          LogDomain.sync,
          'enqueueMessage.missingEntity id=${msg.id}',
          subDomain: 'enqueueMessage',
        );
      }
    } catch (error, stackTrace) {
      _loggingService.error(
        LogDomain.sync,
        error,
        stackTrace: stackTrace,
        subDomain: 'enqueueMessage.refreshJson',
      );
    }

    final fullPath = '${_documentsDirectory.path}${msg.jsonPath}';
    final journalEntity = await readEntityFromJson(fullPath);

    File? attachment;
    final localCounter = journalEntity.meta.vectorClock?.vclock[host];

    journalEntity.maybeMap(
      journalAudio: (JournalAudio journalAudio) {
        if (msg.status == SyncEntryStatus.initial) {
          attachment = File(
            AudioUtils.getAudioPath(journalAudio, _documentsDirectory),
          );
        }
      },
      journalImage: (JournalImage journalImage) {
        if (msg.status == SyncEntryStatus.initial) {
          attachment = File(
            getFullImagePath(
              journalImage,
              documentsDirectory: _documentsDirectory.path,
            ),
          );
        }
      },
      orElse: () {},
    );

    var fileLength = 0;
    if (attachment != null) {
      try {
        fileLength = await attachment!.length();
      } catch (_) {
        fileLength = 0;
      }
    }
    final embeddedLinksCount = msg.entryLinks?.length ?? 0;

    // Check for existing pending outbox item for this entry (merge logic)
    final existingItem = await _syncDatabase.findPendingByEntryId(msg.id);

    if (existingItem != null) {
      // Merge: extract old VC and add to coveredVectorClocks
      try {
        final oldMessage = SyncMessage.fromJson(
          json.decode(existingItem.message) as Map<String, dynamic>,
        );

        if (oldMessage is SyncJournalEntity) {
          final latestVc = journalEntity.meta.vectorClock;
          final coveredClocks = VectorClock.mergeUniqueClocks([
            ...?oldMessage.coveredVectorClocks,
            ...?msg.coveredVectorClocks,
            oldMessage.vectorClock,
            // Also capture the current enqueue call's VC if it differs from
            // the latest. This handles the race condition where multiple
            // enqueue calls are in flight concurrently - each intermediate
            // VC must be captured to prevent false gaps.
            if (msg.vectorClock != null && msg.vectorClock != latestVc)
              msg.vectorClock,
            latestVc,
          ]);

          // Create merged message with updated VC and covered clocks
          final mergedMessage = msg.copyWith(
            vectorClock: latestVc,
            coveredVectorClocks: coveredClocks,
          );
          logVectorClockAssignment(
            _loggingService,
            subDomain: 'enqueue.merge',
            action: 'assign',
            type: 'SyncJournalEntity',
            entryId: msg.id,
            jsonPath: msg.jsonPath,
            reason: 'pending_merge_refresh',
            previous: msg.vectorClock,
            assigned: latestVc,
            coveredVectorClocks: coveredClocks,
            extras: {'oldVc': oldMessage.vectorClock?.vclock},
          );

          final mergedJson = json.encode(mergedMessage.toJson());
          final mergedPayloadSize = utf8.encode(mergedJson).length + fileLength;
          final mergedPriority = math.min(
            existingItem.priority,
            commonFields.priority.value,
          );
          final affectedRows = await _syncDatabase.updateOutboxMessage(
            itemId: existingItem.id,
            newMessage: mergedJson,
            newSubject: '$hostHash:$localCounter',
            payloadSize: mergedPayloadSize,
            priority: mergedPriority,
          );

          if (affectedRows == 0) {
            // Row was no longer pending — insert fresh row with merged data
            _loggingService.log(
              LogDomain.sync,
              'enqueue MERGE-MISS type=SyncJournalEntity id=${msg.id} '
              '(row no longer pending, inserting fresh)',
              subDomain: 'enqueueMessage',
            );
            await _syncDatabase.addOutboxItem(
              commonFields.copyWith(
                subject: Value('$hostHash:$localCounter'),
                message: Value(mergedJson),
                payloadSize: Value(mergedPayloadSize),
                outboxEntryId: Value(msg.id),
                priority: Value(mergedPriority),
              ),
            );
          }

          // Log covered clocks for debugging
          final coveredVcStrings = coveredClocks
              ?.map((vc) => vc.vclock)
              .toList();
          _loggingService.log(
            LogDomain.sync,
            'enqueue MERGED type=SyncJournalEntity id=${msg.id} '
            'coveredClocks=${coveredClocks?.length ?? 0} covered=$coveredVcStrings '
            'latest=${latestVc?.vclock}',
            subDomain: 'enqueueMessage',
          );

          // Still record in sequence log for the new counter
          if (_sequenceLogService != null &&
              journalEntity.meta.vectorClock != null) {
            try {
              await _sequenceLogService.recordSentEntry(
                entryId: journalEntity.meta.id,
                vectorClock: journalEntity.meta.vectorClock!,
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

          unawaited(enqueueNextSendRequest(delay: const Duration(seconds: 1)));
          return true; // Merge happened - don't create new item
        }
      } catch (e, st) {
        _loggingService.error(
          LogDomain.sync,
          e,
          stackTrace: st,
          subDomain: 'enqueueMessage.merge',
        );
        // Fall through to create new item on merge error
      }
    }

    // No existing item or merge failed - create new outbox item with entryId.
    // Enrich covered VCs from the sequence log so receivers can resolve
    // intermediate counters even when the predecessor was already sent.
    final enrichedCovered = await _enrichCoveredVcsFromSequenceLog(
      msg.id,
      msg.coveredVectorClocks,
    );
    var outboxMsg = msg;
    if (enrichedCovered != msg.coveredVectorClocks) {
      outboxMsg = msg.copyWith(coveredVectorClocks: enrichedCovered);
    }
    final outboxJson = json.encode(outboxMsg.toJson());
    final outboxSize = utf8.encode(outboxJson).length + fileLength;
    await _syncDatabase.addOutboxItem(
      commonFields.copyWith(
        filePath: Value(
          (fileLength > 0) ? getRelativeAssetPath(attachment!.path) : null,
        ),
        subject: Value('$hostHash:$localCounter'),
        outboxEntryId: Value(msg.id),
        message: Value(outboxJson),
        payloadSize: Value(outboxSize),
      ),
    );
    _loggingService.log(
      LogDomain.sync,
      'enqueue type=SyncJournalEntity subject=${'$hostHash:$localCounter'} '
      'id=${msg.id} attachBytes=$fileLength embeddedLinks=$embeddedLinksCount',
      subDomain: 'enqueueMessage',
    );

    // Record in sequence log for backfill support (self-healing sync)
    if (_sequenceLogService != null && journalEntity.meta.vectorClock != null) {
      try {
        await _sequenceLogService.recordSentEntry(
          entryId: journalEntity.meta.id,
          vectorClock: journalEntity.meta.vectorClock!,
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

    return false; // No merge - caller should call enqueueNextSendRequest
  }

  /// Looks up the last sent vector clock for [entryId] from the sequence log
  /// and merges it into [existingCovered].  Returns [existingCovered] unchanged
  /// when no previous send is found or the sequence log service is absent.
  Future<List<VectorClock>?> _enrichCoveredVcsFromSequenceLog(
    String entryId,
    List<VectorClock>? existingCovered,
  ) async {
    if (_sequenceLogService == null) return existingCovered;
    try {
      final lastSentVc = await _sequenceLogService
          .getLastSentVectorClockForEntry(entryId);
      if (lastSentVc == null) return existingCovered;
      return VectorClock.mergeUniqueClocks([
        ...?existingCovered,
        lastSentVc,
      ]);
    } catch (e, st) {
      _loggingService.error(
        LogDomain.sync,
        e,
        stackTrace: st,
        subDomain: 'enrichCoveredVcs',
      );
      return existingCovered;
    }
  }
}
