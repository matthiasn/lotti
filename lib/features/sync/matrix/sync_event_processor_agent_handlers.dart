part of 'sync_event_processor.dart';

/// Normalizes a raw `jsonPath` into the lookup key used by [AttachmentIndex].
/// Lives at top level so the shared descriptor-fetch infrastructure (used by
/// both `_DescriptorCache._fetchFromDescriptor` and the outbox bundle resolver)
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
      _loggingService.error(
        LogDomain.sync,
        e,
        stackTrace: st,
        subDomain: 'resolve.$typeName.invalidPath',
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
        _loggingService.error(
          LogDomain.sync,
          e,
          stackTrace: st,
          subDomain: 'resolve.$typeName.parseFetched',
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
      _loggingService.error(
        LogDomain.sync,
        e,
        stackTrace: st,
        subDomain: 'resolve.$typeName',
      );
      return null;
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
      // AgentStateEntity carries per-host G-counters that must converge under
      // concurrent edits: merge them element-wise rather than letting whole-row
      // LWW drop one side's increments. On a concurrent clock this returns the
      // merged state to persist (counters joined, non-counter fields from the
      // LWW winner) and bypasses the keep-local skip below; otherwise it returns
      // null and the standard dominance path applies (causal dominance already
      // implies counter-domination, so no merge is needed there).
      final mergedState = resolvedEntity is AgentStateEntity
          ? await _mergeConcurrentAgentState(
              incoming: resolvedEntity,
              prefetchedAgentEntitiesById: prefetchedAgentEntitiesById,
            )
          : null;

      if (mergedState == null &&
          await _localAgentEntityDominates(
            incoming: resolvedEntity,
            jsonPath: msg.jsonPath,
            prefetchedAgentEntitiesById: prefetchedAgentEntitiesById,
          )) {
        await _recordReceivedAgentEntity(msg: msg, entity: resolvedEntity);
        return;
      }

      var entityToApply = mergedState ?? resolvedEntity;
      // Scheduling is device-local (PR 4 B4): each device schedules its own
      // wakes, so a remote AgentStateEntity must never overwrite this device's
      // nextWakeAt / sleepUntil / scheduledWakeAt. Overlay the local values onto
      // the row about to be persisted; everything else still syncs as usual.
      if (entityToApply is AgentStateEntity) {
        entityToApply = await _preserveLocalScheduling(
          incoming: entityToApply,
          prefetchedAgentEntitiesById: prefetchedAgentEntitiesById,
        );
      }
      await agentRepository!.upsertEntity(entityToApply);
      if (prefetchedAgentEntitiesById?.containsKey(entityToApply.id) ?? false) {
        prefetchedAgentEntitiesById![entityToApply.id] = entityToApply;
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
      // Type-specific monotonic rules (ADR 0022): retraction is terminal;
      // a future-reschedule beats a past consume. Deferred to LWW otherwise.
      concurrentOverride: () => resolveConcurrentAgentEntityOverride(
        local: local,
        incoming: incoming,
      ),
    );
  }

  /// On a **concurrent** clock conflict, returns the merged [AgentStateEntity]:
  /// the per-host G-counters joined element-wise (lossless) via
  /// [mergeAgentStateCounters], with non-counter fields from the deterministic
  /// [resolveConcurrent] winner. Returns null when there is no comparable local
  /// state, a clock is missing, or the clocks are **not** concurrent — in those
  /// cases causal dominance already implies counter-domination, so the standard
  /// [_localAgentEntityDominates] path is correct.
  Future<AgentStateEntity?> _mergeConcurrentAgentState({
    required AgentStateEntity incoming,
    Map<String, AgentDomainEntity?>? prefetchedAgentEntitiesById,
  }) async {
    final incomingVc = incoming.vectorClock;
    if (incomingVc == null) return null;

    final local =
        (prefetchedAgentEntitiesById?.containsKey(incoming.id) ?? false)
        ? prefetchedAgentEntitiesById![incoming.id]
        : await agentRepository!.getEntity(incoming.id);
    if (local is! AgentStateEntity) return null;
    final localVc = local.vectorClock;
    if (localVc == null) return null;

    final VclockStatus status;
    try {
      status = VectorClock.compare(localVc, incomingVc);
    } catch (_) {
      // Invalid clock — let the standard dominance path log and fall through.
      return null;
    }
    if (status != VclockStatus.concurrent) return null;

    final winner =
        resolveConcurrent(
              localVc: localVc,
              incomingVc: incomingVc,
              localUpdatedAt: local.effectiveUpdatedAt,
              incomingUpdatedAt: incoming.effectiveUpdatedAt,
            ) ==
            ConcurrentWinner.local
        ? local
        : incoming;

    final merged = mergeAgentStateCounters(
      winner: winner,
      local: local,
      incoming: incoming,
    );
    // Only diverge from the standard whole-row path when the merge actually
    // recovers a counter the LWW winner lacked. When the winner already carries
    // the joined counters, the standard path is correct (keep local / apply
    // incoming) and we avoid a redundant write — and stay behaviour-compatible
    // with the non-counter concurrent resolution.
    return merged == winner ? null : merged;
  }

  /// Overlays this device's local scheduling fields onto an [incoming]
  /// `AgentStateEntity` about to be applied from sync, so device-local
  /// scheduling (`nextWakeAt` / `sleepUntil` / `scheduledWakeAt`) is never
  /// clobbered by a peer's row (PR 4 B4). When there is no local state row yet
  /// (a brand-new agent on this device) the incoming values are kept as the
  /// bootstrap schedule; the device reschedules itself from there.
  Future<AgentStateEntity> _preserveLocalScheduling({
    required AgentStateEntity incoming,
    Map<String, AgentDomainEntity?>? prefetchedAgentEntitiesById,
  }) async {
    final local =
        (prefetchedAgentEntitiesById?.containsKey(incoming.id) ?? false)
        ? prefetchedAgentEntitiesById![incoming.id]
        : await agentRepository!.getEntity(incoming.id);
    if (local is! AgentStateEntity) return incoming;
    return incoming.copyWith(
      nextWakeAt: local.nextWakeAt,
      sleepUntil: local.sleepUntil,
      scheduledWakeAt: local.scheduledWakeAt,
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
    ConcurrentWinner? Function()? concurrentOverride,
  }) async {
    try {
      final status = VectorClock.compare(localVc, incomingVc);
      // Causal dominance decides first; the genuinely `concurrent` branch is
      // resolved by an optional type-specific monotonic rule, then a
      // deterministic LWW + vector-clock tiebreak so two devices converge
      // regardless of arrival order (the closures are only evaluated there).
      final keepLocal = switch (status) {
        VclockStatus.a_gt_b || VclockStatus.equal => true,
        VclockStatus.b_gt_a => false,
        VclockStatus.concurrent =>
          (concurrentOverride?.call() ??
                  resolveConcurrent(
                    localVc: localVc,
                    incomingVc: incomingVc,
                    localUpdatedAt: localUpdatedAt(),
                    incomingUpdatedAt: incomingUpdatedAt(),
                  )) ==
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
      _loggingService.error(
        LogDomain.sync,
        e,
        stackTrace: st,
        subDomain: 'apply.$kind.vectorClockCompare',
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
      _loggingService.error(
        LogDomain.sync,
        e,
        stackTrace: st,
        subDomain: 'apply.$kind.restoreDominantCache',
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
      _loggingService.error(
        LogDomain.sync,
        e,
        stackTrace: st,
        subDomain: 'recordReceived',
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
      _loggingService.error(
        LogDomain.sync,
        e,
        stackTrace: st,
        subDomain: 'recordReceived',
      );
    }
  }
}
