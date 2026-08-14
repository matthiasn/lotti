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
  /// does for journal entities). Envelopes carrying an [attachmentEventId]
  /// require that exact descriptor; legacy envelopes may fall back to disk.
  ///
  /// Agent entity files can be updated in-place (e.g. ChangeSetEntity
  /// pending → resolved), so reading from disk alone risks stale data when
  /// the file download hasn't completed yet. Fetching from the descriptor
  /// ensures we always get the version that matches this text event.
  ///
  /// Path-validation errors from [resolveJsonCandidateFile] (e.g. path
  /// traversal) are permanent — logged and surfaced as
  /// [UnrecoverableSyncPayloadException]. File-read [FileSystemException]s are
  /// rethrown so the pipeline retries (attachment may not have arrived yet).
  /// Other exceptions (corrupt JSON, parse errors) are logged and receive the
  /// same permanent classification.
  Future<T?> _resolveAgentPayload<T>({
    required T? inline,
    required String? jsonPath,
    required String? attachmentEventId,
    required T Function(Map<String, dynamic>) fromJson,
    required String typeName,
    void Function(Map<String, dynamic>)? inspectJson,
  }) async {
    if (inline != null) return inline;
    final jp = jsonPath;
    if (jp == null) {
      _trace(
        '$typeName.skipped no payload and no jsonPath',
        subDomain: 'processor.resolve',
      );
      throw UnrecoverableSyncPayloadException(typeName);
    }
    // Validate path first — throws FileSystemException for path traversal.
    // This is a permanent error (malformed jsonPath), so catch and skip.
    final File file;
    try {
      file = _resolveJsonCandidateFile(jp);
    } on FileSystemException catch (e, st) {
      _loggingService.error(
        LogDomain.sync,
        e,
        stackTrace: st,
        subDomain: 'resolve.$typeName.invalidPath',
      );
      throw UnrecoverableSyncPayloadException(typeName);
    }

    // Fetch from the AttachmentIndex descriptor first to avoid reading
    // stale data from disk. Agent entity files can be updated in-place
    // (e.g. ChangeSetEntity pending → resolved), and the background
    // download may not have completed yet when this text event arrives.
    final fetched = await _fetchFromDescriptor(
      jsonPath: jp,
      targetFile: file,
      typeName: typeName,
      attachmentEventId: attachmentEventId,
      writeToDisk: attachmentEventId == null,
    );
    if (fetched != null) {
      try {
        final decoded = json.decode(fetched) as Map<String, dynamic>;
        inspectJson?.call(decoded);
        return fromJson(decoded);
      } catch (e, st) {
        _loggingService.error(
          LogDomain.sync,
          e,
          stackTrace: st,
          subDomain: 'resolve.$typeName.parseFetched',
        );
        throw UnrecoverableSyncPayloadException(typeName);
      }
    }

    if (attachmentEventId != null) {
      throw FileSystemException(
        'attachment descriptor not yet available for exact $typeName payload',
        jp,
      );
    }

    // No descriptor available on a legacy envelope — fall back to disk.
    try {
      final jsonString = await file.readAsString();
      final decoded = json.decode(jsonString) as Map<String, dynamic>;
      inspectJson?.call(decoded);
      return fromJson(decoded);
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
      throw UnrecoverableSyncPayloadException(typeName);
    }
  }

  Future<
    ({
      AgentDomainEntity? entity,
      bool? pendingProjectActivityAtWasPresent,
    })
  >
  _resolveAgentEntity(
    SyncAgentEntity msg, {
    Map<String, dynamic>? rawMessageJson,
  }) async {
    bool? pendingProjectActivityAtWasPresent;
    if (msg.agentEntity != null) {
      pendingProjectActivityAtWasPresent = _pendingProjectActivityAtWasPresent(
        rawMessageJson?['agentEntity'],
      );
    }
    final entity = await _resolveAgentPayload(
      inline: msg.agentEntity,
      jsonPath: msg.jsonPath,
      attachmentEventId: msg.attachmentEventId,
      fromJson: AgentDomainEntity.fromJson,
      typeName: 'agentEntity',
      inspectJson: (decoded) {
        pendingProjectActivityAtWasPresent =
            _pendingProjectActivityAtWasPresent(decoded);
      },
    );
    return (
      entity: entity,
      pendingProjectActivityAtWasPresent: pendingProjectActivityAtWasPresent,
    );
  }

  bool? _pendingProjectActivityAtWasPresent(Object? entityJson) {
    if (entityJson is! Map<String, dynamic>) return null;
    final slots = entityJson['slots'];
    if (slots is! Map<String, dynamic>) return null;
    return slots.containsKey('pendingProjectActivityAt');
  }

  Future<AgentLink?> _resolveAgentLink(SyncAgentLink msg) =>
      _resolveAgentPayload(
        inline: msg.agentLink,
        jsonPath: msg.jsonPath,
        attachmentEventId: msg.attachmentEventId,
        fromJson: AgentLink.fromJson,
        typeName: 'agentLink',
      );

  Future<void> _applyAgentEntityMessage({
    required SyncAgentEntity msg,
    required AgentDomainEntity? resolvedEntity,
    bool? pendingProjectActivityAtWasPresent,
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
      final AgentDomainEntity? mergedState;
      if (resolvedEntity is AgentStateEntity) {
        mergedState = await _mergeConcurrentAgentState(
          incoming: resolvedEntity,
          prefetchedAgentEntitiesById: prefetchedAgentEntitiesById,
        );
      } else if (resolvedEntity is GoalNudgeEntity) {
        // Goal nudges accumulate exposure counters and rating history
        // across years of activations (ADR 0055); like the agent-state
        // counters, a concurrent conflict must join them element-wise
        // instead of letting whole-row LWW erase one device's outcomes.
        mergedState = await _mergeConcurrentGoalNudge(
          incoming: resolvedEntity,
          prefetchedAgentEntitiesById: prefetchedAgentEntitiesById,
        );
      } else {
        mergedState = null;
      }

      if (mergedState == null &&
          await _localAgentEntityDominates(
            incoming: resolvedEntity,
            jsonPath: msg.jsonPath,
            prefetchedAgentEntitiesById: prefetchedAgentEntitiesById,
          )) {
        if (wakeOrchestrator != null &&
            resolvedEntity is AgentIdentityEntity &&
            resolvedEntity.kind == AgentKinds.projectAgent) {
          final scheduleChanged = await _reconcileProjectAgentRuntime(
            resolvedEntity,
          );
          if (scheduleChanged) {
            _updateNotifications.notify(
              {resolvedEntity.agentId, agentNotification},
              fromSync: true,
            );
          }
        }
        await _projectAgentAttribution(resolvedEntity);
        await _recordReceivedAgentEntity(msg: msg, entity: resolvedEntity);
        return;
      }

      var entityToApply = mergedState ?? resolvedEntity;
      // Scheduling is device-local (PR 4 B4): each device schedules its own
      // wakes, so a remote AgentStateEntity must never overwrite this device's
      // nextWakeAt / sleepUntil / scheduledWakeAt. Overlay the local values onto
      // the row about to be persisted; everything else still syncs as usual.
      var projectActivityWasConsumed = false;
      if (entityToApply is AgentStateEntity) {
        final preserved = await _preserveLocalScheduling(
          incoming: entityToApply,
          pendingProjectActivityAtWasPresent:
              pendingProjectActivityAtWasPresent,
          prefetchedAgentEntitiesById: prefetchedAgentEntitiesById,
        );
        entityToApply = preserved.entity;
        projectActivityWasConsumed = preserved.projectActivityWasConsumed;
      } else if (entityToApply is AgentIdentityEntity) {
        entityToApply = await _preserveLocalAgentConfigFields(
          incoming: entityToApply,
          prefetchedAgentEntitiesById: prefetchedAgentEntitiesById,
        );
      }
      await agentRepository!.upsertEntity(entityToApply);
      if (projectActivityWasConsumed) {
        wakeOrchestrator?.cancelPendingAutomaticWakes(
          entityToApply.agentId,
        );
      }
      await _projectAgentAttribution(entityToApply);
      if (prefetchedAgentEntitiesById?.containsKey(entityToApply.id) ?? false) {
        prefetchedAgentEntitiesById![entityToApply.id] = entityToApply;
      }
      // Mirror runtime subscriptions after a remote identity update. Task
      // agents retain observation when automation is off, while project agents
      // restore their direct-project subscription. This also closes the
      // link-before-identity ordering gap during sync.
      final appliedIdentity = entityToApply is AgentIdentityEntity
          ? entityToApply
          : null;
      if (wakeOrchestrator != null && appliedIdentity != null) {
        if (appliedIdentity.kind == 'task_agent') {
          final activeAndConfigured =
              appliedIdentity.lifecycle == AgentLifecycle.active &&
              appliedIdentity.config.inferenceSetup?.mode !=
                  AgentInferenceSetupMode.disabled;
          if (!activeAndConfigured) {
            wakeOrchestrator!
              ..removeSubscriptions(appliedIdentity.agentId)
              ..disableAutomaticUpdatesRuntime(appliedIdentity.agentId);
          } else {
            if (appliedIdentity.config.automaticUpdatesEnabledEffective) {
              wakeOrchestrator!.enableAutomaticUpdatesRuntime(
                appliedIdentity.agentId,
              );
            } else {
              wakeOrchestrator!.disableAutomaticUpdatesRuntime(
                appliedIdentity.agentId,
              );
            }
            final links = await agentRepository!.getLinksFrom(
              appliedIdentity.agentId,
              type: 'agent_task',
            );
            for (final link in links) {
              wakeOrchestrator!.addSubscription(
                AgentSubscription(
                  id: '${appliedIdentity.agentId}_task_${link.toId}',
                  agentId: appliedIdentity.agentId,
                  matchEntityIds: {link.toId},
                  deferPropagatedMatches: false,
                ),
              );
            }
          }
        } else if (appliedIdentity.kind == AgentKinds.projectAgent) {
          await _reconcileProjectAgentRuntime(appliedIdentity);
        }
        // Plug-in kinds (goal agents today): offer the identity to each
        // registered runtime-maintenance contributor, so the owning
        // feature mirrors its subscriptions without this file hard-coding
        // another kind branch. Contributors contain their own failures.
        await _offerIdentityToRuntimeMaintenance(appliedIdentity);
      }
      // The identity may already be present when its state arrives. Sync
      // notifications do not enter the local project-update stream, so repair
      // the device-local fallback here instead of waiting for a restart.
      if (wakeOrchestrator != null && entityToApply is AgentStateEntity) {
        final identity = await _localAgentEntityFor(
          entityToApply.agentId,
          prefetchedAgentEntitiesById,
        );
        if (identity is AgentIdentityEntity &&
            identity.kind == AgentKinds.projectAgent) {
          await _reconcileProjectAgentRuntime(identity);
        }
      }
      // Ordering: creation bundles emit the identity BEFORE its spec rows,
      // so the identity-time mirror can find no criteria yet. When the
      // spec head lands, offer the (already persisted) identity again —
      // this is what makes a goal synced in mid-session actually live.
      if (wakeOrchestrator != null && entityToApply is GoalSpecHeadEntity) {
        final identity = await agentRepository!.getEntity(
          entityToApply.agentId,
        );
        if (identity is AgentIdentityEntity) {
          await _offerIdentityToRuntimeMaintenance(identity);
        }
      }
      // Task-scoped report consumers subscribe to the task ID, not the agent
      // ID. Resolve active task links so a report or report-head received from
      // another device refreshes an already-open header and task list.
      final reportTaskIds = <String>{};
      if (resolvedEntity is AgentReportEntity ||
          resolvedEntity is AgentReportHeadEntity) {
        final taskLinks = await agentRepository!.getLinksFrom(
          resolvedEntity.agentId,
          type: 'agent_task',
        );
        reportTaskIds.addAll(
          taskLinks
              .whereType<AgentTaskLink>()
              .where((link) => link.deletedAt == null)
              .map((link) => link.toId),
        );
      }
      _updateNotifications.notify(
        {
          resolvedEntity.agentId,
          ...reportTaskIds,
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

  Future<void> _projectAgentAttribution(AgentDomainEntity entity) async {
    final repository = consumptionRepository;
    if (repository == null) return;
    await AttributionCarrierProjector(repository).projectAgentEntity(entity);
  }

  /// Keeps explicit task/project-agent fields when an older client sends a
  /// rewrite that omitted keys it could not deserialize.
  ///
  /// Explicit incoming true/false and configured/disabled values always win;
  /// only null (field absent in old JSON) is overlaid from the local row.
  Future<AgentIdentityEntity> _preserveLocalAgentConfigFields({
    required AgentIdentityEntity incoming,
    Map<String, AgentDomainEntity?>? prefetchedAgentEntitiesById,
  }) async {
    if ((incoming.kind != 'task_agent' && incoming.kind != 'project_agent') ||
        (incoming.config.automaticUpdatesEnabled != null &&
            incoming.config.inferenceSetup != null)) {
      return incoming;
    }
    final prefetched = prefetchedAgentEntitiesById?[incoming.id];
    final localEntity =
        prefetched ??
        (prefetchedAgentEntitiesById?.containsKey(incoming.id) ?? false
            ? null
            : await agentRepository!.getEntity(incoming.id));
    if (localEntity is! AgentIdentityEntity) return incoming;

    final automaticUpdatesEnabled =
        incoming.config.automaticUpdatesEnabled ??
        localEntity.config.automaticUpdatesEnabled;
    final inferenceSetup =
        incoming.config.inferenceSetup ?? localEntity.config.inferenceSetup;
    if (automaticUpdatesEnabled == incoming.config.automaticUpdatesEnabled &&
        inferenceSetup == incoming.config.inferenceSetup) {
      return incoming;
    }
    return incoming.copyWith(
      config: incoming.config.copyWith(
        automaticUpdatesEnabled: automaticUpdatesEnabled,
        inferenceSetup: inferenceSetup,
      ),
    );
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
      // Mirror remote agent_task and agent_project link lifecycles in the wake
      // orchestrator. A non-deleted link restores the corresponding runtime
      // subscription after the startup snapshot, while a deleted link removes
      // it. The identity handler performs the inverse reconciliation when the
      // link arrives first; addSubscription is idempotent in either order.
      if (wakeOrchestrator != null && resolvedLink is AgentTaskLink) {
        final subscriptionId =
            '${resolvedLink.fromId}_task_${resolvedLink.toId}';
        if (resolvedLink.deletedAt != null) {
          wakeOrchestrator!.removeSubscription(subscriptionId);
        } else {
          final agent = await agentRepository!.getEntity(resolvedLink.fromId);
          if (agent is AgentIdentityEntity &&
              agent.lifecycle == AgentLifecycle.active &&
              agent.config.inferenceSetup?.mode !=
                  AgentInferenceSetupMode.disabled &&
              agent.kind == 'task_agent') {
            if (agent.config.automaticUpdatesEnabledEffective) {
              wakeOrchestrator!.enableAutomaticUpdatesRuntime(agent.agentId);
            } else {
              wakeOrchestrator!.disableAutomaticUpdatesRuntime(agent.agentId);
            }
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
      } else if (wakeOrchestrator != null && resolvedLink is AgentProjectLink) {
        final subscriptionId = _projectSubscriptionId(resolvedLink);
        if (resolvedLink.deletedAt != null) {
          wakeOrchestrator!.removeSubscription(subscriptionId);
        } else {
          final agent = await agentRepository!.getEntity(resolvedLink.fromId);
          if (agent is AgentIdentityEntity &&
              agent.kind == AgentKinds.projectAgent) {
            await _reconcileProjectAgentRuntime(agent);
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

  String _projectSubscriptionId(AgentProjectLink link) =>
      '${link.fromId}_project_direct_${link.toId}';

  /// Reconciles receiver-local project scheduling and runtime after sync.
  Future<bool> _reconcileProjectAgentRuntime(
    AgentIdentityEntity identity,
  ) async {
    var policy = (active: false, automaticWakesAllowed: false);
    var scheduleChanged = false;
    await agentRepository!.runInTransaction(() async {
      final currentIdentity = await agentRepository!.getEntity(identity.id);
      final currentProjectIdentity =
          currentIdentity is AgentIdentityEntity &&
              currentIdentity.kind == AgentKinds.projectAgent
          ? currentIdentity
          : null;
      final active = currentProjectIdentity?.lifecycle == AgentLifecycle.active;
      final automaticWakesAllowed =
          currentProjectIdentity != null &&
          projectAgentAutomaticWakesAllowed(
            config: currentProjectIdentity.config,
            lifecycle: currentProjectIdentity.lifecycle,
          );
      policy = (
        active: active,
        automaticWakesAllowed: automaticWakesAllowed,
      );
      final state = await agentRepository!.getAgentState(identity.agentId);
      if (state == null || state.deletedAt != null) {
        return;
      }

      final shouldArm =
          automaticWakesAllowed &&
          state.slots.pendingProjectActivityAt != null &&
          state.scheduledWakeAt == null;
      final shouldClear =
          !automaticWakesAllowed && state.scheduledWakeAt != null;
      if (!shouldArm && !shouldClear) {
        return;
      }

      // Scheduling fields are device-local. Keep synced LWW metadata intact
      // so this repair cannot win a peer conflict for unrelated state fields.
      await agentRepository!.upsertEntity(
        state.copyWith(
          scheduledWakeAt: shouldArm
              ? nextOccurrenceOf(
                  clock.now(),
                  hour: AgentSchedules.projectDailyDigestHour,
                )
              : null,
        ),
      );
      scheduleChanged = true;
    });

    if (!policy.active) {
      wakeOrchestrator!
        ..removeSubscriptions(identity.agentId)
        ..disableAutomaticUpdatesRuntime(identity.agentId);
      return scheduleChanged;
    }
    if (policy.automaticWakesAllowed) {
      wakeOrchestrator!.enableAutomaticUpdatesRuntime(identity.agentId);
    } else {
      wakeOrchestrator!.disableAutomaticUpdatesRuntime(identity.agentId);
    }
    final links = await agentRepository!.getLinksFrom(
      identity.agentId,
      type: AgentLinkTypes.agentProject,
    );
    for (final link in links.whereType<AgentProjectLink>()) {
      if (link.deletedAt == null) _addProjectSubscription(link);
    }
    return scheduleChanged;
  }

  void _addProjectSubscription(AgentProjectLink link) {
    wakeOrchestrator?.addSubscription(
      AgentSubscription(
        id: _projectSubscriptionId(link),
        agentId: link.fromId,
        matchEntityIds: {projectEntityUpdateNotification(link.toId)},
      ),
    );
  }

  /// Offers a synced-in identity to every runtime-maintenance contributor,
  /// containing each contributor's failures (one feature's bad spec must
  /// not stall the sync apply loop).
  Future<void> _offerIdentityToRuntimeMaintenance(
    AgentIdentityEntity identity,
  ) async {
    for (final maintenance in runtimeMaintenance) {
      try {
        await maintenance.onIdentityReceived(identity);
      } catch (error, stackTrace) {
        _loggingService.error(
          LogDomain.sync,
          error,
          subDomain: 'processor.identityMirror',
          message:
              'runtime maintenance identity mirror failed for '
              '${identity.agentId}',
          stackTrace: stackTrace,
        );
      }
    }
  }

  /// Local counterpart of an incoming entity: the prefetched bundle map
  /// when the id was bulk-loaded (including a cached null), the repository
  /// otherwise. One helper because five call sites carried this branch.
  Future<AgentDomainEntity?> _localAgentEntityFor(
    String id,
    Map<String, AgentDomainEntity?>? prefetchedAgentEntitiesById,
  ) async => (prefetchedAgentEntitiesById?.containsKey(id) ?? false)
      ? prefetchedAgentEntitiesById![id]
      : await agentRepository!.getEntity(id);

  Future<bool> _localAgentEntityDominates({
    required AgentDomainEntity incoming,
    required String? jsonPath,
    Map<String, AgentDomainEntity?>? prefetchedAgentEntitiesById,
  }) async {
    final incomingVc = incoming.vectorClock;
    if (incomingVc == null) return false;

    final local = await _localAgentEntityFor(
      incoming.id,
      prefetchedAgentEntitiesById,
    );
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

    final local = await _localAgentEntityFor(
      incoming.id,
      prefetchedAgentEntitiesById,
    );
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

  /// The [GoalNudgeEntity] analogue of [_mergeConcurrentAgentState]: on a
  /// **concurrent** clock conflict, returns the nudge with exposure
  /// counters joined, ratings unioned and watermarks widened via
  /// [mergeGoalNudgeAccumulators], with non-accumulator fields from the
  /// deterministic winner — which honours the dismissal-terminal override
  /// before generic LWW, so a concurrent bookkeeping write can never
  /// resurrect a dismissed ad. Returns null when clocks are missing or
  /// not concurrent (causal dominance already carries the accumulators).
  Future<GoalNudgeEntity?> _mergeConcurrentGoalNudge({
    required GoalNudgeEntity incoming,
    Map<String, AgentDomainEntity?>? prefetchedAgentEntitiesById,
  }) async {
    final incomingVc = incoming.vectorClock;
    if (incomingVc == null) return null;

    final local = await _localAgentEntityFor(
      incoming.id,
      prefetchedAgentEntitiesById,
    );
    if (local is! GoalNudgeEntity) return null;
    final localVc = local.vectorClock;
    if (localVc == null) return null;

    final VclockStatus status;
    try {
      status = VectorClock.compare(localVc, incomingVc);
    } catch (_) {
      return null;
    }
    if (status != VclockStatus.concurrent) return null;

    final overrideWinner = resolveConcurrentAgentEntityOverride(
      local: local,
      incoming: incoming,
    );
    final winnerSide =
        overrideWinner ??
        resolveConcurrent(
          localVc: localVc,
          incomingVc: incomingVc,
          localUpdatedAt: local.effectiveUpdatedAt,
          incomingUpdatedAt: incoming.effectiveUpdatedAt,
        );
    final winner = winnerSide == ConcurrentWinner.local ? local : incoming;

    final merged = mergeGoalNudgeAccumulators(
      winner: winner,
      local: local,
      incoming: incoming,
    );
    // As with agent state: only diverge from the standard whole-row path
    // when the join actually recovers something the winner lacked.
    return merged == winner ? null : merged;
  }

  /// Overlays this device's local scheduling fields onto an [incoming]
  /// `AgentStateEntity` about to be applied from sync, so device-local
  /// scheduling (`nextWakeAt` / `sleepUntil` / `scheduledWakeAt`) is never
  /// clobbered by a peer's row (PR 4 B4). When there is no local state row yet
  /// (a brand-new agent on this device), non-project agents keep the incoming
  /// bootstrap schedule. Project fallback deadlines are instead cleared and
  /// rebuilt below from this device's automation policy and local clock.
  Future<({AgentStateEntity entity, bool projectActivityWasConsumed})>
  _preserveLocalScheduling({
    required AgentStateEntity incoming,
    bool? pendingProjectActivityAtWasPresent,
    Map<String, AgentDomainEntity?>? prefetchedAgentEntitiesById,
  }) async {
    final local = await _localAgentEntityFor(
      incoming.id,
      prefetchedAgentEntitiesById,
    );
    final identity = await _localAgentEntityFor(
      incoming.agentId,
      prefetchedAgentEntitiesById,
    );
    if (local is! AgentStateEntity) {
      final isProjectState =
          (identity is AgentIdentityEntity &&
              identity.kind == AgentKinds.projectAgent) ||
          incoming.slots.activeProjectId != null;
      return (
        entity: isProjectState
            ? incoming.copyWith(
                nextWakeAt: null,
                sleepUntil: null,
                scheduledWakeAt: null,
              )
            : incoming,
        projectActivityWasConsumed: false,
      );
    }
    final isProjectState =
        (identity is AgentIdentityEntity &&
            identity.kind == AgentKinds.projectAgent) ||
        local.slots.activeProjectId != null ||
        incoming.slots.activeProjectId != null;
    final preserveLegacyPendingActivity =
        isProjectState && pendingProjectActivityAtWasPresent == false;
    final projectActivityWasConsumed =
        isProjectState &&
        !preserveLegacyPendingActivity &&
        local.slots.pendingProjectActivityAt != null &&
        incoming.slots.pendingProjectActivityAt == null;
    return (
      entity: incoming.copyWith(
        slots: preserveLegacyPendingActivity
            ? incoming.slots.copyWith(
                pendingProjectActivityAt: local.slots.pendingProjectActivityAt,
              )
            : incoming.slots,
        nextWakeAt: local.nextWakeAt,
        sleepUntil: local.sleepUntil,
        scheduledWakeAt: projectActivityWasConsumed
            ? null
            : local.scheduledWakeAt,
      ),
      projectActivityWasConsumed: projectActivityWasConsumed,
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
      final file = _resolveJsonCandidateFile(jsonPath);
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
      final isExact = msg.attachmentEventId != null;
      final canonicalVectorClock = isExact
          ? (await agentRepository!.getEntity(entity.id))?.vectorClock
          : null;
      final gaps = await _sequenceLogService.recordReceivedEntry(
        entryId: entity.id,
        vectorClock: entity.vectorClock!,
        originatingHostId: msg.originatingHostId!,
        coveredVectorClocks: msg.coveredVectorClocks,
        payloadType: SyncSequencePayloadType.agentEntity,
        jsonPath: msg.jsonPath,
        payloadVectorClock: isExact ? entity.vectorClock : null,
        canonicalPayloadVectorClock: canonicalVectorClock,
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
      final isExact = msg.attachmentEventId != null;
      final canonicalVectorClock = isExact
          ? (await agentRepository!.getLinkById(link.id))?.vectorClock
          : null;
      final gaps = await _sequenceLogService.recordReceivedEntry(
        entryId: link.id,
        vectorClock: link.vectorClock!,
        originatingHostId: msg.originatingHostId!,
        coveredVectorClocks: msg.coveredVectorClocks,
        payloadType: SyncSequencePayloadType.agentLink,
        jsonPath: msg.jsonPath,
        payloadVectorClock: isExact ? link.vectorClock : null,
        canonicalPayloadVectorClock: canonicalVectorClock,
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
