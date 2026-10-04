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
  }) async {
    if (resolvedEntity == null) {
      return;
    }
    if (agentRepository != null) {
      // One pure decision (ADR 0068): keep the stored row, or the row to
      // write — the incoming version, or a merge that joins agent-state
      // G-counters, head, nudge accumulators and change-set items so neither
      // side's progress is lost.
      //
      // Every entity is read, resolved and written in one transaction. A
      // local write that committed between the read and the write would be
      // overwritten: an append moving the head (ADR 0076), a claim on a
      // change set (`ChangeSetLifecycle.tla`), an approval completing an
      // evolution session (ADR 0081), and any other local write, which is
      // the case ADR 0081's addendum closes for the remaining types. The
      // stored row is read with its tombstone, so a removal is never
      // replaced by a late copy of the live entity it removed.
      //
      // A write about an agent this device deleted is refused in the same
      // transaction: its rows are gone, and inserting them again would bring
      // the agent back (ADR 0108, `TaskAgentAssignment.tla`
      // DeletedStaysDeleted).
      final outcome = await agentRepository!.runInTransaction(
        () async =>
            await refusesWriteAboutDeletedAgent(agentRepository!, {
              resolvedEntity.agentId,
            })
            ? null
            : await _resolveAndPersistAgentEntity(
                incoming: resolvedEntity,
                jsonPath: msg.jsonPath,
                pendingProjectActivityAtWasPresent:
                    pendingProjectActivityAtWasPresent,
              ),
      );
      if (outcome == null) {
        _trace(
          'apply.agentEntity.refusedDeletedAgent id=${resolvedEntity.id}',
          subDomain: 'processor.apply',
        );
        // Receipt first: if it fails, the queue retries the event, which
        // must still find its JSON.
        await _recordReceivedAgentEntity(msg: msg, entity: resolvedEntity);
        await _discardReceivedAgentJson(msg.jsonPath, kind: 'agentEntity');
        return;
      }
      final entityToApply = outcome.written;
      if (entityToApply == null) {
        AgentIdentityEntity? projectIdentity;
        if (wakeOrchestrator != null) {
          if (resolvedEntity is AgentIdentityEntity &&
              resolvedEntity.kind == AgentKinds.projectAgent) {
            projectIdentity = resolvedEntity;
          } else if (resolvedEntity is AgentStateEntity) {
            final identity = await agentRepository!.getEntity(
              resolvedEntity.agentId,
            );
            if (identity is AgentIdentityEntity &&
                identity.kind == AgentKinds.projectAgent) {
              projectIdentity = identity;
            }
          }
        }
        if (projectIdentity != null) {
          final scheduleChanged = await _reconcileProjectAgentRuntime(
            projectIdentity,
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

      if (outcome.projectActivityWasConsumed) {
        wakeOrchestrator?.cancelPendingAutomaticWakes(
          entityToApply.agentId,
        );
      }
      await _projectAgentAttribution(entityToApply);
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
            // A pause on another device halts this device's work as well.
            if (appliedIdentity.lifecycle != AgentLifecycle.active) {
              wakeOrchestrator!.haltAgent(appliedIdentity.agentId);
            }
          } else {
            wakeOrchestrator!.mirrorTaskWakeCadence(appliedIdentity);
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
      // A task agent's identity can arrive after its link: only now does the
      // retirement pass rank that link (ADR 0104).
      if (appliedIdentity != null &&
          appliedIdentity.kind == AgentKinds.taskAgent) {
        await _retireSupersededTaskAgents(
          () async => [
            for (final link in await agentRepository!.getLinksFrom(
              appliedIdentity.agentId,
              type: AgentLinkTypes.agentTask,
            ))
              link.toId,
          ],
        );
      }
      // The identity may already be present when its state arrives. Sync
      // notifications do not enter the local project-update stream, so repair
      // the device-local fallback here instead of waiting for a restart.
      if (wakeOrchestrator != null && entityToApply is AgentStateEntity) {
        final identity = await agentRepository!.getEntity(
          entityToApply.agentId,
        );
        if (identity is AgentIdentityEntity &&
            identity.kind == AgentKinds.projectAgent) {
          await _reconcileProjectAgentRuntime(identity);
        } else if (identity is AgentIdentityEntity &&
            identity.kind == AgentKinds.relationshipAgent &&
            entityToApply.lastWakeMayHaveFailed) {
          // A retry can arrive before the state that marks it as backed off.
          // Read as the maintenance pass reads it: a row written before the
          // failed watermark existed still counts by its failure count.
          await _offerIdentityToRuntimeMaintenance(identity);
        }
      }
      // Ordering: creation bundles emit the identity BEFORE its spec rows,
      // so the identity-time mirror can find no criteria yet. When the
      // spec head lands, offer the (already persisted) identity again —
      // this is what makes a goal synced in mid-session actually live.
      // Relationship retry/cadence rows can likewise follow their identity
      // and link, so let maintenance see the now-persisted prerequisite.
      if (wakeOrchestrator != null &&
          (entityToApply is GoalSpecHeadEntity ||
              entityToApply is ScheduledWakeEntity)) {
        final identity = await agentRepository!.getEntity(
          entityToApply.agentId,
        );
        if (identity is AgentIdentityEntity &&
            (entityToApply is GoalSpecHeadEntity ||
                identity.kind == AgentKinds.relationshipAgent)) {
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
      _agentRepositoryNotWired('agentEntity');
    }
  }

  /// Fails the apply of an agent record that arrived before the agent
  /// repository was wired (`wireAgentSyncRepository`). A failed apply is
  /// retried and, past the retry cap, kept as a skipped event that can be
  /// retried again — dropping it instead lost another device's agent data
  /// for as long as the agent runtime had not started.
  Never _agentRepositoryNotWired(String kind) => throw StateError(
    '$kind arrived before the agent repository was wired',
  );

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
  ///
  /// [local] is the version stored under the identity's id, as the receive
  /// read it.
  AgentIdentityEntity _preserveLocalAgentConfigFields({
    required AgentIdentityEntity incoming,
    required AgentDomainEntity? local,
  }) {
    if ((incoming.kind != 'task_agent' && incoming.kind != 'project_agent') ||
        (incoming.config.automaticUpdatesEnabled != null &&
            incoming.config.inferenceSetup != null &&
            incoming.config.maxWakesPerDay != null &&
            incoming.config.updateIntervalMinutes != null)) {
      return incoming;
    }
    if (local is! AgentIdentityEntity) return incoming;

    final automaticUpdatesEnabled =
        incoming.config.automaticUpdatesEnabled ??
        local.config.automaticUpdatesEnabled;
    final inferenceSetup =
        incoming.config.inferenceSetup ?? local.config.inferenceSetup;
    // An older client cannot carry the daily wake budget; dropping it would
    // silently reset a user's lower limit to the default on every device.
    final maxWakesPerDay =
        incoming.config.maxWakesPerDay ?? local.config.maxWakesPerDay;
    final updateIntervalMinutes =
        incoming.config.updateIntervalMinutes ??
        local.config.updateIntervalMinutes;
    if (automaticUpdatesEnabled == incoming.config.automaticUpdatesEnabled &&
        inferenceSetup == incoming.config.inferenceSetup &&
        maxWakesPerDay == incoming.config.maxWakesPerDay &&
        updateIntervalMinutes == incoming.config.updateIntervalMinutes) {
      return incoming;
    }
    return incoming.copyWith(
      config: incoming.config.copyWith(
        automaticUpdatesEnabled: automaticUpdatesEnabled,
        inferenceSetup: inferenceSetup,
        maxWakesPerDay: maxWakesPerDay,
        updateIntervalMinutes: updateIntervalMinutes,
      ),
    );
  }
}
