part of 'sync_event_processor.dart';

/// Normalizes a raw `jsonPath` into the lookup key used by [AttachmentIndex].
/// Lives at top level so the shared descriptor-fetch infrastructure (used by
/// both [_AgentHandlers._fetchFromDescriptor] and the outbox bundle resolver)
/// can reach it from any part of the library.
String _buildAgentIndexKey(String rawPath) =>
    normalizeAttachmentIndexKey(rawPath);

/// Resolution + apply-phase handlers for agent entity / agent link sync
/// messages, plus the shared descriptor-fetch infrastructure (also consumed
/// by [_OutboxBundleHandler._resolveOutboxBundleManifest]).
extension _AgentHandlers on SyncEventProcessor {
  Future<T> _withPrefetchedAgentEntities<T>({
    required PreparedOutboxSyncBundle bundle,
    required Future<T> Function(
      Map<String, AgentDomainEntity?> prefetchedAgentEntitiesById,
    )
    apply,
  }) async {
    final repository = agentRepository;
    if (repository == null) return apply(const <String, AgentDomainEntity?>{});

    final ids = <String>{};
    for (final child in bundle.children) {
      final entity = child.resolvedAgentEntity;
      if (entity?.vectorClock != null) {
        ids.add(entity!.id);
      }
    }
    if (ids.isEmpty) return apply(const <String, AgentDomainEntity?>{});

    final localEntities = await repository.getEntitiesByIds(ids);
    final prefetchedAgentEntitiesById = <String, AgentDomainEntity?>{
      for (final id in ids) id: localEntities[id],
    };
    return apply(prefetchedAgentEntitiesById);
  }

  /// Resolves an agent payload from a sync message: inline first, then
  /// fetches from [AttachmentIndex] descriptor (like [SmartJournalEntityLoader]
  /// does for journal entities), falling back to disk.
  ///
  /// Agent entity files can be updated in-place (e.g. ChangeSetEntity
  /// pending → resolved), so reading from disk alone risks stale data when
  /// the file download hasn't completed yet. Fetching from the descriptor
  /// ensures we always get the version that matches this text event.
  ///
  /// Path-validation errors from [resolveJsonCandidateFile] (e.g. path
  /// traversal) are permanent — logged and skipped. File-read
  /// [FileSystemException]s are rethrown so the pipeline retries (attachment
  /// may not have arrived yet). Other exceptions (corrupt JSON, parse errors)
  /// are logged and return null to skip permanently.
  Future<T?> _resolveAgentPayload<T>({
    required T? inline,
    required String? jsonPath,
    required T Function(Map<String, dynamic>) fromJson,
    required String typeName,
  }) async {
    if (inline != null) return inline;
    final jp = jsonPath;
    if (jp == null) {
      _trace(
        '$typeName.skipped no payload and no jsonPath',
        subDomain: 'processor.resolve',
      );
      return null;
    }
    // Validate path first — throws FileSystemException for path traversal.
    // This is a permanent error (malformed jsonPath), so catch and skip.
    final File file;
    try {
      file = resolveJsonCandidateFile(jp);
    } on FileSystemException catch (e, st) {
      _loggingService.captureException(
        e,
        domain: 'AGENT_SYNC',
        subDomain: 'resolve.$typeName.invalidPath',
        stackTrace: st,
      );
      return null;
    }

    // Fetch from the AttachmentIndex descriptor first to avoid reading
    // stale data from disk. Agent entity files can be updated in-place
    // (e.g. ChangeSetEntity pending → resolved), and the background
    // download may not have completed yet when this text event arrives.
    final fetched = await _fetchFromDescriptor(
      jsonPath: jp,
      targetFile: file,
      typeName: typeName,
    );
    if (fetched != null) {
      try {
        return fromJson(json.decode(fetched) as Map<String, dynamic>);
      } catch (e, st) {
        _loggingService.captureException(
          e,
          domain: 'AGENT_SYNC',
          subDomain: 'resolve.$typeName.parseFetched',
          stackTrace: st,
        );
        return null;
      }
    }

    // No descriptor available — fall back to disk.
    try {
      final jsonString = await file.readAsString();
      return fromJson(json.decode(jsonString) as Map<String, dynamic>);
    } on FileSystemException {
      // Attachment file not yet available — rethrow so the pipeline retries
      // and registers the pending descriptor path for catch-up.
      rethrow;
    } catch (e, st) {
      _loggingService.captureException(
        e,
        domain: 'AGENT_SYNC',
        subDomain: 'resolve.$typeName',
        stackTrace: st,
      );
      return null;
    }
  }

  /// Fetches fresh JSON from the [AttachmentIndex] descriptor and writes it
  /// to [targetFile]. Returns the JSON string on success, or null if no
  /// descriptor is available (index missing or not initialized).
  ///
  /// When a descriptor IS found but download/decode fails, throws
  /// [FileSystemException] to prevent falling back to potentially stale
  /// disk data.
  Future<String?> _fetchFromDescriptor({
    required String jsonPath,
    required File targetFile,
    required String typeName,
  }) async {
    final index = _attachmentIndex;
    if (index == null) return null;

    final indexKey = _buildAgentIndexKey(jsonPath);
    final descriptorEvent = index.find(indexKey);
    if (descriptorEvent == null) {
      _trace(
        '$typeName.descriptor.miss path=$jsonPath key=$indexKey',
        subDomain: 'processor.resolve',
      );
      return null;
    }

    final dedupeKey = '$indexKey@${descriptorEvent.eventId}';
    final existing = _inFlightDescriptorFetches[dedupeKey];
    if (existing != null) {
      return existing;
    }

    final future = _runDescriptorFetch(
      jsonPath: jsonPath,
      targetFile: targetFile,
      typeName: typeName,
      descriptorEvent: descriptorEvent,
    );
    _inFlightDescriptorFetches[dedupeKey] = future;
    return future.whenComplete(() {
      _inFlightDescriptorFetches.remove(dedupeKey);
    });
  }

  Future<String?> _runDescriptorFetch({
    required String jsonPath,
    required File targetFile,
    required String typeName,
    required Event descriptorEvent,
  }) async {
    try {
      final matrixFile = await downloadAttachmentWithTimeout(
        descriptorEvent,
        pathForError: jsonPath,
      );
      final downloadedBytes = matrixFile.bytes;
      if (downloadedBytes.isEmpty) {
        throw const FileSystemException('empty attachment bytes');
      }
      final bytes = await decodeAttachmentBytes(
        event: descriptorEvent,
        downloadedBytes: downloadedBytes,
        relativePath: jsonPath,
        logging: _loggingService,
      );
      final jsonString = utf8.decode(bytes);
      await saveJson(targetFile.path, jsonString);
      _trace(
        '$typeName.descriptor.fetched path=$jsonPath bytes=${bytes.length}',
        subDomain: 'processor.resolve',
      );
      return jsonString;
    } catch (e, st) {
      _loggingService.captureException(
        e,
        domain: 'AGENT_SYNC',
        subDomain: 'resolve.$typeName.descriptorFetch',
        stackTrace: st,
      );
      // Descriptor was found but download/decode failed — throw to prevent
      // falling back to potentially stale disk data. The pipeline will retry.
      throw FileSystemException(
        '$typeName descriptor fetch failed',
        jsonPath,
      );
    }
  }

  Future<AgentDomainEntity?> _resolveAgentEntity(
    SyncAgentEntity msg,
  ) => _resolveAgentPayload(
    inline: msg.agentEntity,
    jsonPath: msg.jsonPath,
    fromJson: AgentDomainEntity.fromJson,
    typeName: 'agentEntity',
  );

  Future<AgentLink?> _resolveAgentLink(SyncAgentLink msg) =>
      _resolveAgentPayload(
        inline: msg.agentLink,
        jsonPath: msg.jsonPath,
        fromJson: AgentLink.fromJson,
        typeName: 'agentLink',
      );

  Future<void> _applyAgentEntityMessage({
    required SyncAgentEntity msg,
    required AgentDomainEntity? resolvedEntity,
    Map<String, AgentDomainEntity?>? prefetchedAgentEntitiesById,
  }) async {
    if (resolvedEntity == null) {
      return;
    }
    if (agentRepository != null) {
      if (await _localAgentEntityDominates(
        incoming: resolvedEntity,
        jsonPath: msg.jsonPath,
        prefetchedAgentEntitiesById: prefetchedAgentEntitiesById,
      )) {
        await _recordReceivedAgentEntity(msg: msg, entity: resolvedEntity);
        return;
      }

      await agentRepository!.upsertEntity(resolvedEntity);
      if (prefetchedAgentEntitiesById?.containsKey(resolvedEntity.id) ??
          false) {
        prefetchedAgentEntitiesById![resolvedEntity.id] = resolvedEntity;
      }
      // Remove wake subscriptions when an agent is paused or destroyed
      // remotely — mirrors what AgentService.pauseAgent/destroyAgent do
      // locally.
      if (wakeOrchestrator != null &&
          resolvedEntity is AgentIdentityEntity &&
          resolvedEntity.lifecycle != AgentLifecycle.active) {
        wakeOrchestrator!.removeSubscriptions(resolvedEntity.agentId);
      }
      // Restore wake subscriptions when an agent is resumed remotely —
      // mirrors what TaskAgentService.restoreSubscriptionsForAgent does
      // locally after AgentService.resumeAgent.
      if (wakeOrchestrator != null &&
          resolvedEntity is AgentIdentityEntity &&
          resolvedEntity.lifecycle == AgentLifecycle.active &&
          resolvedEntity.kind == 'task_agent') {
        final links = await agentRepository!.getLinksFrom(
          resolvedEntity.agentId,
          type: 'agent_task',
        );
        for (final link in links) {
          wakeOrchestrator!.addSubscription(
            AgentSubscription(
              id: '${resolvedEntity.agentId}_task_${link.toId}',
              agentId: resolvedEntity.agentId,
              matchEntityIds: {link.toId},
              deferPropagatedMatches: false,
            ),
          );
        }
      }
      _updateNotifications.notify(
        {
          resolvedEntity.agentId,
          // Include templateId so template-level aggregate providers
          // refresh when token usage or reports arrive from other devices.
          if (resolvedEntity is WakeTokenUsageEntity &&
              resolvedEntity.templateId != null)
            resolvedEntity.templateId!,
          agentNotification,
        },
        fromSync: true,
      );
      _trace(
        'apply agentEntity id=${resolvedEntity.id}',
        subDomain: 'processor.apply',
      );

      await _recordReceivedAgentEntity(msg: msg, entity: resolvedEntity);
    } else {
      _trace(
        'agentEntity.ignored no repository',
        subDomain: 'processor.apply',
      );
    }
  }

  Future<void> _applyAgentLinkMessage({
    required SyncAgentLink msg,
    required AgentLink? resolvedLink,
  }) async {
    if (resolvedLink == null) {
      return;
    }
    if (agentRepository != null) {
      if (await _localAgentLinkDominates(
        incoming: resolvedLink,
        jsonPath: msg.jsonPath,
      )) {
        await _recordReceivedAgentLink(msg: msg, link: resolvedLink);
        return;
      }

      await agentRepository!.upsertLink(resolvedLink);
      // Mirror remote agent_task link lifecycle in the wake orchestrator.
      // A non-deleted link restores the per-link subscription for active
      // task_agents (this handles the case where the link arrives after
      // the identity — the SyncAgentEntity handler queries existing links,
      // which may be empty if the link hasn't been synced yet;
      // addSubscription is idempotent). A deleted link removes the matching
      // subscription so this device stops waking an agent that was already
      // unlinked elsewhere.
      if (wakeOrchestrator != null && resolvedLink is AgentTaskLink) {
        final subscriptionId =
            '${resolvedLink.fromId}_task_${resolvedLink.toId}';
        if (resolvedLink.deletedAt != null) {
          wakeOrchestrator!.removeSubscription(subscriptionId);
        } else {
          final agent = await agentRepository!.getEntity(resolvedLink.fromId);
          if (agent is AgentIdentityEntity &&
              agent.lifecycle == AgentLifecycle.active &&
              agent.kind == 'task_agent') {
            wakeOrchestrator!.addSubscription(
              AgentSubscription(
                id: subscriptionId,
                agentId: resolvedLink.fromId,
                matchEntityIds: {resolvedLink.toId},
                deferPropagatedMatches: false,
              ),
            );
          }
        }
      }
      _updateNotifications.notify(
        {resolvedLink.fromId, resolvedLink.toId, agentNotification},
        fromSync: true,
      );
      _trace(
        'apply agentLink id=${resolvedLink.id}',
        subDomain: 'processor.apply',
      );

      await _recordReceivedAgentLink(msg: msg, link: resolvedLink);
    } else {
      _trace(
        'agentLink.ignored no repository',
        subDomain: 'processor.apply',
      );
    }
  }

  Future<bool> _localAgentEntityDominates({
    required AgentDomainEntity incoming,
    required String? jsonPath,
    Map<String, AgentDomainEntity?>? prefetchedAgentEntitiesById,
  }) async {
    final incomingVc = incoming.vectorClock;
    if (incomingVc == null) return false;

    final local = prefetchedAgentEntitiesById?.containsKey(incoming.id) ?? false
        ? prefetchedAgentEntitiesById![incoming.id]
        : await agentRepository!.getEntity(incoming.id);
    final localVc = local?.vectorClock;
    if (local == null || localVc == null) return false;

    return _localAgentPayloadDominates(
      localVc: localVc,
      incomingVc: incomingVc,
      localUpdatedAt: () => local.effectiveUpdatedAt,
      incomingUpdatedAt: () => incoming.effectiveUpdatedAt,
      kind: 'agentEntity',
      id: incoming.id,
      jsonPath: jsonPath,
      restoreLocalJson: () => jsonEncode(local.toJson()),
    );
  }

  Future<bool> _localAgentLinkDominates({
    required AgentLink incoming,
    required String? jsonPath,
  }) async {
    final incomingVc = incoming.vectorClock;
    if (incomingVc == null) return false;

    final local = await agentRepository!.getLinkById(incoming.id);
    final localVc = local?.vectorClock;
    if (local == null || localVc == null) return false;

    return _localAgentPayloadDominates(
      localVc: localVc,
      incomingVc: incomingVc,
      localUpdatedAt: () => local.updatedAt,
      incomingUpdatedAt: () => incoming.updatedAt,
      kind: 'agentLink',
      id: incoming.id,
      jsonPath: jsonPath,
      restoreLocalJson: () => jsonEncode(local.toJson()),
    );
  }

  Future<bool> _localAgentPayloadDominates({
    required VectorClock localVc,
    required VectorClock incomingVc,
    required DateTime Function() localUpdatedAt,
    required DateTime Function() incomingUpdatedAt,
    required String kind,
    required String id,
    required String? jsonPath,
    required String Function() restoreLocalJson,
  }) async {
    try {
      final status = VectorClock.compare(localVc, incomingVc);
      // Causal dominance decides first; the genuinely `concurrent` branch is
      // resolved by a deterministic LWW + vector-clock tiebreak so two devices
      // converge regardless of arrival order (the timestamp closures are only
      // evaluated on that branch).
      final keepLocal = switch (status) {
        VclockStatus.a_gt_b || VclockStatus.equal => true,
        VclockStatus.b_gt_a => false,
        VclockStatus.concurrent =>
          resolveConcurrent(
                localVc: localVc,
                incomingVc: incomingVc,
                localUpdatedAt: localUpdatedAt(),
                incomingUpdatedAt: incomingUpdatedAt(),
              ) ==
              ConcurrentWinner.local,
      };
      if (!keepLocal) return false;

      await _restoreDominantAgentCache(
        jsonPath: jsonPath,
        kind: kind,
        id: id,
        jsonString: restoreLocalJson(),
      );
      _trace(
        'apply.$kind.skippedLocalWins id=$id status=$status',
        subDomain: 'processor.apply',
      );
      return true;
    } catch (e, st) {
      _loggingService.captureException(
        e,
        domain: 'AGENT_SYNC',
        subDomain: 'apply.$kind.vectorClockCompare',
        stackTrace: st,
      );
      return false;
    }
  }

  Future<void> _restoreDominantAgentCache({
    required String? jsonPath,
    required String kind,
    required String id,
    required String jsonString,
  }) async {
    if (jsonPath == null) return;
    try {
      final file = resolveJsonCandidateFile(jsonPath);
      await saveJson(file.path, jsonString);
    } on FileSystemException catch (e, st) {
      _loggingService.captureException(
        e,
        domain: 'AGENT_SYNC',
        subDomain: 'apply.$kind.restoreDominantCache',
        stackTrace: st,
      );
      _trace(
        'apply.$kind.restoreDominantCacheFailed id=$id path=$jsonPath',
        subDomain: 'processor.apply',
      );
    }
  }

  Future<void> _recordReceivedAgentEntity({
    required SyncAgentEntity msg,
    required AgentDomainEntity entity,
  }) async {
    if (_sequenceLogService == null ||
        entity.vectorClock == null ||
        msg.originatingHostId == null) {
      return;
    }
    try {
      final gaps = await _sequenceLogService.recordReceivedEntry(
        entryId: entity.id,
        vectorClock: entity.vectorClock!,
        originatingHostId: msg.originatingHostId!,
        coveredVectorClocks: msg.coveredVectorClocks,
        payloadType: SyncSequencePayloadType.agentEntity,
        jsonPath: msg.jsonPath,
      );
      if (gaps.isNotEmpty) {
        _trace(
          'apply.agentEntity.gapsDetected count=${gaps.length} '
          'for entity=${entity.id}',
          subDomain: 'processor.gapDetection',
        );
      }
    } catch (e, st) {
      _loggingService.captureException(
        e,
        domain: 'SYNC_SEQUENCE',
        subDomain: 'recordReceived',
        stackTrace: st,
      );
    }
  }

  Future<void> _recordReceivedAgentLink({
    required SyncAgentLink msg,
    required AgentLink link,
  }) async {
    if (_sequenceLogService == null ||
        link.vectorClock == null ||
        msg.originatingHostId == null) {
      return;
    }
    try {
      final gaps = await _sequenceLogService.recordReceivedEntry(
        entryId: link.id,
        vectorClock: link.vectorClock!,
        originatingHostId: msg.originatingHostId!,
        coveredVectorClocks: msg.coveredVectorClocks,
        payloadType: SyncSequencePayloadType.agentLink,
        jsonPath: msg.jsonPath,
      );
      if (gaps.isNotEmpty) {
        _trace(
          'apply.agentLink.gapsDetected count=${gaps.length} '
          'for link=${link.id}',
          subDomain: 'processor.gapDetection',
        );
      }
    } catch (e, st) {
      _loggingService.captureException(
        e,
        domain: 'SYNC_SEQUENCE',
        subDomain: 'recordReceived',
        stackTrace: st,
      );
    }
  }
}
