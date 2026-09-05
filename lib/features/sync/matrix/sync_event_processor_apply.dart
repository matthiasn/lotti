part of 'sync_event_processor.dart';

/// The apply phase of [SyncEventProcessor] — persists a prepared sync event —
/// together with its diagnostics and prepared-event result models. Split from
/// the main file for size.
extension SyncEventProcessorApply on SyncEventProcessor {
  Future<SyncApplyDiagnostics?> _applyMessage({
    required PreparedSyncEvent prepared,
    required JournalDb journalDb,
    Map<String, AgentDomainEntity?>? prefetchedAgentEntitiesById,
  }) async {
    final event = prepared.event;
    final syncMessage = prepared.syncMessage;
    // Self-echo short-circuit. Prepare flagged this event as one the local
    // host originated; the journal/agent/outbox payload was written locally
    // before the message was sent, so apply has nothing to do for any
    // family. Returning null commits the queue row cleanly (marker
    // advances, no skip count, no retry) and — critically — avoids
    // dereferencing the unpopulated `journalEntity` / `resolvedOutboxBundle`
    // slots that would otherwise null-bang in the per-family branches
    // below.
    if (prepared.isSelfEcho) {
      _trace(
        'apply selfEcho.skip type=${syncMessage.runtimeType} '
        'eventId=${event.eventId}',
        subDomain: 'processor.apply',
      );
      return null;
    }
    switch (syncMessage) {
      case final SyncJournalEntity msg:
        return _applyJournalEntity(
          event: event,
          syncMessage: msg,
          preloaded: prepared.journalEntity,
          isDuplicate: prepared.isDuplicateJournalEntity,
          deferredStaleError: prepared.deferredStaleDescriptorError,
          journalDb: journalDb,
        );
      case final SyncEntryLink msg:
        return _handleEntryLink(
          event: event,
          syncMessage: msg,
          journalDb: journalDb,
        );
      case SyncEntityDefinition(:final entityDefinition):
        final measurable = entityDefinition is MeasurableDataType
            ? entityDefinition
            : null;
        final fts5Db = _fts5Db;
        final previousMeasurable = measurable != null && fts5Db != null
            ? await journalDb.getMeasurableDataTypeById(measurable.id)
            : null;
        final linesAffected = await journalDb.upsertEntityDefinition(
          entityDefinition,
        );
        if (linesAffected == 0) {
          // The journal kept a newer copy. Nothing changed locally, so there
          // is nothing to reindex or announce — reindexing from this stale
          // copy would rewrite search rows with labels the app no longer
          // shows.
          _loggingService.log(
            LogDomain.sync,
            'Skipped older definition ${entityDefinition.id}',
            subDomain: 'processor.apply.entityDefinition.skipped',
          );
          return null;
        }
        if (measurable != null &&
            fts5Db != null &&
            measurementDefinitionAffectsFts(previousMeasurable, measurable)) {
          try {
            final entries = await journalDb.getMeasurementsByType(
              type: measurable.id,
              rangeStart: DateTime(1),
              rangeEnd: DateTime(9999, 12, 31, 23, 59, 59, 999),
            );
            await fts5Db.reindexMeasurements(measurable, entries);
          } catch (exception, stackTrace) {
            // Search rows are derived. Keep the synced definition even if its
            // local index cannot be refreshed right now.
            _loggingService.error(
              LogDomain.sync,
              exception,
              stackTrace: stackTrace,
              subDomain: 'processor.apply.entityDefinition.reindex',
            );
          }
        }
        final typeNotification = switch (entityDefinition) {
          CategoryDefinition() => categoriesNotification,
          HabitDefinition() => habitsNotification,
          DashboardDefinition() => dashboardsNotification,
          MeasurableDataType() => measurablesNotification,
          LabelDefinition() => labelsNotification,
        };
        _updateNotifications.notify(
          {entityDefinition.id, typeNotification},
          fromSync: true,
        );
        return null;
      case SyncAiConfig(:final aiConfig):
        await _aiConfigRepository.saveConfig(
          aiConfig,
          fromSync: true,
        );
        return null;
      case SyncAiConfigDelete(:final id, :final hardDelete):
        // Current builds only send this envelope for hard deletes — an
        // orphaned-seed prune or a provider cascade — and mark it. Applying
        // those softly would leave a tombstone that stops the peer re-seeding
        // a profile the sender merely pruned, and keep cascaded rows as hidden
        // records.
        //
        // An absent flag is a *legacy* user deletion from 0.9.1068 or earlier,
        // which had no other way to express one. Hard-deleting it would let
        // seeding recreate the row, undoing that user's deletion, so it
        // becomes a tombstone instead.
        if (hardDelete ?? false) {
          await _aiConfigRepository.hardDeleteConfig(id, fromSync: true);
        } else {
          await _aiConfigRepository.deleteConfig(id, fromSync: true);
        }
        return null;
      case SyncSavedTaskFilter(:final filter):
        await _savedTaskFiltersRepository.upsert(
          filter,
          fromSync: true,
        );
        return null;
      case SyncSavedTaskFilterDelete(:final id):
        await _savedTaskFiltersRepository.delete(
          id,
          fromSync: true,
        );
        return null;
      case SyncConfigFlag(:final name, :final description, :final status):
        final configFlag = ConfigFlag(
          name: name,
          description: description,
          status: status,
        );
        await journalDb.upsertConfigFlag(configFlag);
        if (configFlag.name == 'private') {
          _updateNotifications.notify(
            {privateToggleNotification},
            fromSync: true,
          );
        }
        return null;
      case SyncThemingSelection(
        :final lightThemeName,
        :final darkThemeName,
        :final themeMode,
        :final updatedAt,
      ):
        try {
          // Check if incoming update is newer than local
          final localUpdatedAtStr = await _settingsDb.itemByKey(
            themePrefsUpdatedAtKey,
          );
          final localUpdatedAt = localUpdatedAtStr != null
              ? int.tryParse(localUpdatedAtStr)
              : 0;

          if (updatedAt < (localUpdatedAt ?? 0)) {
            _trace(
              'themingSync.ignored.stale incoming=$updatedAt local=$localUpdatedAt',
              subDomain: 'processor.apply',
            );
            _loggingService.log(
              LogDomain.theming,
              'themingSync.ignored.stale incoming=$updatedAt local=$localUpdatedAt',
              subDomain: 'apply',
            );
            return null;
          }

          // Normalize themeMode value
          final normalizedMode =
              EnumToString.fromString(
                ThemeMode.values,
                themeMode,
              ) ??
              ThemeMode.system;

          // Apply all three settings
          await _settingsDb.saveSettingsItem(
            lightSchemeNameKey,
            lightThemeName,
          );
          await _settingsDb.saveSettingsItem(
            darkSchemeNameKey,
            darkThemeName,
          );
          await _settingsDb.saveSettingsItem(
            themeModeKey,
            EnumToString.convertToString(normalizedMode),
          );
          await _settingsDb.saveSettingsItem(
            themePrefsUpdatedAtKey,
            updatedAt.toString(),
          );

          _updateNotifications.notify(
            {settingsNotification},
            fromSync: true,
          );

          _trace(
            'apply themingSelection light=$lightThemeName dark=$darkThemeName mode=$themeMode',
            subDomain: 'processor.apply',
          );
          _loggingService.log(
            LogDomain.theming,
            'apply themingSelection light=$lightThemeName dark=$darkThemeName mode=$themeMode',
            subDomain: 'apply',
          );
        } catch (e, st) {
          _loggingService.error(
            LogDomain.theming,
            e,
            stackTrace: st,
            subDomain: 'apply',
          );
        }
        return null;
      case SyncDailyOsUserName(:final userName, :final updatedAt):
        try {
          // Last-write-wins on the persisted timestamp, mirroring theming.
          final localUpdatedAtStr = await _settingsDb.itemByKey(
            dailyOsUserNameUpdatedAtSettingsKey,
          );
          final localUpdatedAt = localUpdatedAtStr != null
              ? int.tryParse(localUpdatedAtStr)
              : 0;

          if (updatedAt < (localUpdatedAt ?? 0)) {
            _trace(
              'dailyOsUserNameSync.ignored.stale incoming=$updatedAt '
              'local=$localUpdatedAt',
              subDomain: 'processor.apply',
            );
            return null;
          }

          await _settingsDb.saveSettingsItem(
            dailyOsUserNameSettingsKey,
            userName,
          );
          await _settingsDb.saveSettingsItem(
            dailyOsUserNameUpdatedAtSettingsKey,
            updatedAt.toString(),
          );
          // A name received from another device is already published; mark it
          // synced so this device does not bootstrap-republish it.
          await _settingsDb.saveSettingsItem(
            dailyOsUserNameSyncedAtSettingsKey,
            updatedAt.toString(),
          );

          _updateNotifications.notify(
            {settingsNotification},
            fromSync: true,
          );

          // Content-free: never log the greeting name itself.
          _trace(
            'apply dailyOsUserName updatedAt=$updatedAt',
            subDomain: 'processor.apply',
          );
        } catch (e, st) {
          _loggingService.error(
            LogDomain.dailyOs,
            e,
            stackTrace: st,
            subDomain: 'apply',
          );
        }
        return null;
      case SyncOnboardingSnapshotBegin() ||
          SyncOnboardingSnapshotAccepted() ||
          SyncOnboardingTerminalCounters() ||
          SyncOnboardingSnapshotEnd():
        await onboardingSyncService?.handleMessage(syncMessage);
        return null;
      case SyncBackfillRequest():
        // Handle backfill request - another device is asking for a missing entry
        await backfillResponseHandler.handleBackfillRequest(syncMessage);
        return null;
      case final SyncMediaRequest msg:
        // A peer is missing blobs for entries it already holds. Answering is
        // best-effort: the request is broadcast, and a device that lacks the
        // file simply stays quiet.
        await mediaRequestHandler?.handleMediaRequest(msg);
        return null;
      case SyncBackfillResponse():
        // Handle backfill response - another device responded to our request
        await backfillResponseHandler.handleBackfillResponse(syncMessage);
        return null;
      // Agent entities and links are file-backed often enough that stale
      // descriptors can arrive after a newer local write. The handlers compare
      // local vs incoming vector clocks before upsert and skip dominated
      // payloads while still recording the sequence receipt.
      case final SyncAgentEntity msg:
        await _applyAgentEntityMessage(
          msg: msg,
          resolvedEntity: prepared.resolvedAgentEntity,
          pendingProjectActivityAtWasPresent:
              prepared.pendingProjectActivityAtWasPresent,
          prefetchedAgentEntitiesById: prefetchedAgentEntitiesById,
        );
        return null;
      case final SyncConsumptionEvent msg:
        await _applyConsumptionEventMessage(msg: msg);
        return null;
      case final SyncAgentLink msg:
        await _applyAgentLinkMessage(
          msg: msg,
          resolvedLink: prepared.resolvedAgentLink,
        );
        return null;
      case final SyncNotification msg:
        await _applyNotificationMessage(
          msg: msg,
          resolvedNotification: prepared.resolvedNotification,
        );
        return null;
      case final SyncNotificationStateUpdate msg:
        await _applyNotificationStateUpdateMessage(msg);
        return null;
      case SyncAgentBundle():
        // Legacy wire variant — already logged + skipped in prepare. Apply
        // is a no-op so the inbound queue marker advances; missing
        // children resurface via the per-(host, counter) backfill path.
        return null;
      case SyncOutboxBundle():
        final bundle = prepared.resolvedOutboxBundle;
        if (bundle == null) return null;
        await _withPrefetchedAgentEntities(
          bundle: bundle,
          apply: (prefetchedAgentEntitiesById) => _outboxBundleUnpacker.apply(
            bundle: bundle,
            applyChild: (child) => _applyMessage(
              prepared: child,
              journalDb: journalDb,
              prefetchedAgentEntitiesById: prefetchedAgentEntitiesById,
            ),
          ),
        );
        return null;
      case SyncSyncNodeProfile(:final profile):
        final repo = _syncNodeProfileRepository;
        if (repo != null) {
          try {
            final changed = await repo.upsertNode(profile);
            _trace(
              'apply syncNodeProfile hostId=${profile.hostId} '
              'name=${profile.displayName} caps=${profile.capabilities.length} '
              'changed=$changed',
              subDomain: 'processor.apply.syncNodeProfile',
            );
          } catch (error, stackTrace) {
            // Log AND rethrow: an upsert failure (e.g. SettingsDb write
            // refused, JSON encode glitch) must leave the inbound event
            // eligible for retry. Swallowing here would silently drop peer
            // profile updates, which the pinning UI relies on to surface
            // capable devices.
            _loggingService.error(
              LogDomain.sync,
              error,
              stackTrace: stackTrace,
              subDomain: 'apply.upsert',
            );
            rethrow;
          }
        }
        return null;
    }
  }
}

class SyncApplyDiagnostics {
  SyncApplyDiagnostics({
    required this.eventId,
    required this.payloadType,
    required this.conflictStatus,
    required this.applied,
    this.skipReason,
  });

  final String eventId;
  final String payloadType;
  final String conflictStatus;
  final bool applied;
  final JournalUpdateSkipReason? skipReason;
}

/// Output of [SyncEventProcessor.prepare]: the decoded envelope plus any
/// file-backed payload that was resolved outside the writer transaction.
/// [SyncEventProcessor.apply] consumes this and runs the DB writes.
class PreparedSyncEvent {
  @visibleForTesting
  PreparedSyncEvent.forTesting({
    required this.event,
    required this.syncMessage,
    this.journalEntity,
    this.isDuplicateJournalEntity = false,
    this.isSelfEcho = false,
    this.deferredStaleDescriptorError,
    this.resolvedAgentEntity,
    this.pendingProjectActivityAtWasPresent,
    this.resolvedAgentLink,
    this.resolvedNotification,
    this.resolvedOutboxBundle,
  });

  PreparedSyncEvent._({
    required this.event,
    required this.syncMessage,
    this.journalEntity,
    this.isDuplicateJournalEntity = false,
    this.isSelfEcho = false,
    this.deferredStaleDescriptorError,
    this.resolvedAgentEntity,
    this.pendingProjectActivityAtWasPresent,
    this.resolvedAgentLink,
    this.resolvedNotification,
    this.resolvedOutboxBundle,
  });

  final Event event;
  final SyncMessage syncMessage;

  /// Loaded journal entity when [syncMessage] is a [SyncJournalEntity] that
  /// was not a duplicate and whose descriptor resolved cleanly. Null for
  /// duplicates, stale-descriptor deferrals, and every other message family.
  final JournalEntity? journalEntity;

  /// True when prepare detected a duplicate by (id, vectorClock) fingerprint
  /// and skipped the loader call. Apply still records the duplicate in the
  /// sequence log so hint resolution runs.
  final bool isDuplicateJournalEntity;

  /// True when prepare identified the event as a self-echo (its
  /// `originatingHostId` matches the local host). Self-echoes are events the
  /// local host already wrote before sending; apply has nothing to do for
  /// any message family. The flag is the explicit contract that the
  /// per-family apply branches in `SyncEventProcessor._applyMessage` check
  /// before they expect their resolved-payload slots to be populated. None
  /// of the other slots (`journalEntity`, `resolvedOutboxBundle`, …) are
  /// populated when this is true, so per-family apply must short-circuit
  /// rather than dereference them.
  final bool isSelfEcho;

  /// Captured stale-descriptor error from the loader. Apply first checks
  /// whether the local version already supersedes the incoming one; if not,
  /// this error is rethrown so the pipeline schedules a retry.
  final FileSystemException? deferredStaleDescriptorError;

  /// Resolved entity when [syncMessage] is a [SyncAgentEntity]. Null means
  /// the prepare call returned null (inline missing, no jsonPath, invalid
  /// path, or descriptor-miss without a local file) — apply will treat it as
  /// a terminal skip.
  final AgentDomainEntity? resolvedAgentEntity;

  /// Whether the raw incoming agent-state payload explicitly carried the
  /// `pendingProjectActivityAt` slot. Null means the defensive fallback
  /// fired: prepare found no usable raw JSON to inspect (envelope missing
  /// or malformed). Top-level events and both outbox-bundle delivery paths
  /// (inline children and sidecar manifests) normally carry raw envelopes.
  final bool? pendingProjectActivityAtWasPresent;

  /// Resolved link when [syncMessage] is a [SyncAgentLink]. Same null
  /// semantics as [resolvedAgentEntity].
  final AgentLink? resolvedAgentLink;

  /// Resolved notification when [syncMessage] is a [SyncNotification].
  /// Null means prepare could not materialize a payload and apply will skip it.
  final NotificationEntity? resolvedNotification;

  /// Resolved dequeue-time outbox bundle when [syncMessage] is a
  /// [SyncOutboxBundle]. Each child carries its own [PreparedSyncEvent] so
  /// apply can recurse through the existing per-type pipeline. Null means
  /// the bundle payload could not be resolved and apply will skip it.
  final PreparedOutboxSyncBundle? resolvedOutboxBundle;
}
